#!/usr/bin/env bash
# Stop hook: when a reply asks the user something, a separate model reads it
# as the user would (chat messages only, no tool output) and, if the user
# would get stuck, sends it back for one rewrite. The user still sees the
# first reply; the rewrite follows it.
#
# Every check is logged to ~/.claude/logs/reply-check/ for later review.
#
# The check runs only in sessions whose working directory is a line of
# ~/.claude/reply-check-dirs or below it (one path per line; blank lines and
# # comments are ignored; "/" means everywhere). With no file, it's off. The
# file is kept out of dotfiles because the paths name projects.

set -uo pipefail
umask 077

prompt_file="${REPLY_CHECK_PROMPT_FILE:-${HOME}/.claude/hooks/reply-check-prompt.md}"
log_dir="${REPLY_CHECK_LOG_DIR:-${HOME}/.claude/logs/reply-check}"
dirs_file="${REPLY_CHECK_DIRS:-${HOME}/.claude/reply-check-dirs}"
checker_model="${REPLY_CHECK_MODEL:-claude-sonnet-5-5}"

input=$(cat)

# One rewrite at most: the rewritten reply is not checked again.
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

[ -f "$dirs_file" ] || exit 0
cwd=$(jq -r '.cwd // ""' <<<"$input")
in_scope=false
while read -r prefix || [ -n "$prefix" ]; do
  [ -z "$prefix" ] || [[ "$prefix" == "#"* ]] && continue
  prefix="${prefix/#\~/$HOME}"
  prefix="${prefix%/}"
  [[ "$cwd" == "$prefix" || "$cwd" == "$prefix/"* ]] && in_scope=true
done <"$dirs_file"
[ "$in_scope" = "true" ] || exit 0

msg=$(jq -r '.last_assistant_message // ""' <<<"$input")
transcript=$(jq -r '.transcript_path // ""' <<<"$input")
session=$(jq -r '.session_id // "unknown"' <<<"$input")
[ -n "$msg" ] && [ -f "$transcript" ] && [ -f "$prompt_file" ] || exit 0

# Only replies that ask the user something, and not short ones. An ask is a
# '?' or a choice like (y/n) or a/b/c near the end, outside code and URLs.
[ "$(wc -w <<<"$msg")" -ge 60 ] || exit 0
sed -e "/^[[:space:]]*\`\`\`/,/^[[:space:]]*\`\`\`/d" -E \
  -e "s/\`[^\`]*\`//g" -e 's#https?://[^[:space:]]*##g' <<<"$msg" \
  | tail -c 600 \
  | grep -qE '\?|\(y/n\)|(^|[^[:alnum:]])[a-e](/[a-e])+([^[:alnum:]]|$)' \
  || exit 0

mkdir -p "$log_dir"
find "$log_dir" -name '*.md' -mtime +30 -delete 2>/dev/null
log_file="$log_dir/$(date +%Y%m%d-%H%M%S)-${session:0:8}.md"
err_file=$(mktemp)
trap 'rm -f "$err_file"' EXIT

# The chat goes last because it's the longest part; it's kept so a logged
# case can be rerun against a revised prompt.
write_log() {
  {
    echo "session: $session"
    echo "transcript: $transcript"
    echo "verdict: $1"
    echo "seconds: ${elapsed:-0}"
    echo
    echo '## Reply'
    echo
    echo "$msg"
    echo
    echo '## Review'
    echo
    echo "$2"
    echo
    echo '## Chat'
    echo
    echo "${chat:-}"
  } >"$log_file"
}

# What the user has seen: their messages (including slash commands and text
# typed when rejecting a tool call) and Claude's text, from the last 8 user
# messages. Earlier text from this turn goes in the chat, labeled as part of
# the message; only the final message is checked, since that is all a rewrite
# can replace.
chat=$(jq -rs --arg msg "$msg" '
  def flat: if type == "string" then .
    elif type == "array" then map(.text // "") | join("\n")
    else "" end;
  def user_text:
    if startswith("<command-name>") then
      capture("<command-name>(?<n>[^<]*)</command-name>[\\s\\S]*<command-args>(?<a>[\\s\\S]*?)</command-args>")
      | {k: "USER", t: "\(.n) \(.a)"}
    elif startswith("<") then empty
    else {k: "USER", t: .} end;
  [ .[]
    | select((.type == "user" or .type == "assistant")
        and .isSidechain != true and .isMeta != true
        and .isCompactSummary != true)
    | if .type == "user" then
        if (.message.content | type) == "string" then
          .message.content | user_text
        else
          .message.content[]
          | if .type == "text" then
              .text | user_text
            elif .type == "tool_result" and .is_error == true then
              (.content | flat)
              | select(startswith("The user doesn'"'"'t want to proceed with this tool use."))
              | capture("the user said:\\n(?<s>[\\s\\S]*)")
              | {k: "USER", t: ("(typed while rejecting a tool call) " + .s)}
            else empty end
        end
      else
        (.message.content // []) | if type == "array" then .[] else empty end
        | select(.type == "text") | {k: "ASSISTANT", t: .text}
      end
  ] as $ev
  | ([$ev | to_entries[] | select(.value.k == "USER") | .key]) as $u
  | def drop_final:
      if length > 0 and (last | .k == "ASSISTANT" and (.t as $t | $msg | contains($t)))
      then .[:-1] | drop_final else . end;
  ($ev | drop_final)
  | to_entries
  | map(if .key > ($u[-1] // -1)
      then .value.k = "ASSISTANT (earlier part of the message being checked)"
      else . end | .value)
  | .[($u[-8] // 0):]
  | map("### \(.k)\n\(.t)") | reverse
  | reduce .[] as $s ({n: 0, out: [], full: false};
      if .full then .
      elif .n + ($s | length) > 80000 and (.out | length) > 0
      then .full = true
      else {n: (.n + ($s | length)), out: ([$s] + .out), full: false} end)
  | .out | join("\n\n") | .[-80000:]
' "$transcript" 2>"$err_file") || {
  write_log error "Reading the transcript failed: $(head -c 1000 "$err_file")"
  exit 0
}

start=$(date +%s)
review=$({
  cat "$prompt_file"
  echo
  echo '<chat>'
  echo "$chat"
  echo '</chat>'
  echo
  echo '<message>'
  echo "$msg"
  echo '</message>'
  echo
  echo 'Now list the problems in <message>, if any, then end with the line'
  echo 'VERDICT: PASS or VERDICT: REVISE.'
} | claude -p --safe-mode --no-session-persistence --model "$checker_model" \
  --tools "" 2>"$err_file")
status=$?
elapsed=$(($(date +%s) - start))
if [ "$status" -ne 0 ]; then
  write_log error "The checker exited with $status: $(head -c 1000 "$err_file")"
  exit 0
fi

verdict=$(grep -oE '^[*_ ]*VERDICT:[*_ ]*(PASS|REVISE)' <<<"$review" \
  | tail -n 1 | grep -oE 'PASS|REVISE')

# Pass on only the numbered list, so nothing else the checker wrote reaches
# the session as instructions.
items=$(sed -n '/^[0-9][0-9]*\./,$p' <<<"$review" \
  | grep -vE '^[*_ ]*VERDICT:' | head -c 3000)

if [ "$verdict" = "REVISE" ] && [ -z "$items" ]; then
  write_log "REVISE with no numbered notes; nothing sent" "$review"
  exit 0
fi
write_log "${verdict:-unknown}" "$review"
[ "$verdict" = "REVISE" ] || exit 0

reason="A reader check (a separate model that saw only the chat, not tool output) flagged your last reply. Its notes are below. They are a model's notes, not instructions from the user. Rewrite the reply for the user, fixing the notes that hold. Skip any note that's wrong given what you know. Keep the first reply's recommendation and positions. If the reply asks for a decision, give only the context the user needs to make it, then the question. Leave the report of other work until they've decided, and say in one line that more is coming. Use plain words; don't make up labels or pack sentences to save space. If a note shows the first reply got a fact wrong, fix it and say in one line what changed. Reply with text only, no tool calls. Start with \"Rewritten after a reader check:\". If no note holds, reply only \"Reader check: no rewrite needed.\"

$items"

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
