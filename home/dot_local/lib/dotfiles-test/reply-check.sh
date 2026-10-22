#!/usr/bin/env bash
# Reply-check Stop hook tests
# shellcheck shell=bash

# Overridable so the tests can run against the source files before an apply.
REPLY_CHECK_HOOK="${REPLY_CHECK_HOOK:-${HOME}/.claude/hooks/reply-check.sh}"
REPLY_CHECK_PROMPT_FILE="${REPLY_CHECK_PROMPT_FILE:-${HOME}/.claude/hooks/reply-check-prompt.md}"

test_reply_check() {
  section "Reply Check Hook"

  if [ ! -f "$REPLY_CHECK_HOOK" ] || [ ! -f "$REPLY_CHECK_PROMPT_FILE" ]; then
    skip "reply-check hook not installed"
    return
  fi
  if ! command -v jq &>/dev/null; then
    skip "jq not installed (required by the reply-check hook)"
    return
  fi

  local fx=""
  reply_check_cleanup() {
    [ -n "$fx" ] && rm -rf "$fx"
  }
  trap reply_check_cleanup EXIT
  fx="$(mktemp -d)"

  # A fake checker: saves what it was sent, prints $STUB_OUT, exits $STUB_EXIT.
  mkdir -p "$fx/bin"
  cat >"$fx/bin/claude" <<'EOF'
#!/bin/sh
cat >"$STUB_DIR/input"
cat "$STUB_DIR/out"
exit "${STUB_EXIT:-0}"
EOF
  chmod +x "$fx/bin/claude"

  local words final
  words="$(printf 'word %.0s' $(seq 70))"
  final="$words FINALTOKEN Want me to apply it?"

  # Transcript: what the chat extraction must keep and drop.
  jq -nc --arg final "$final" '
    {type: "user", message: {content: "OLDQUESTION"}},
    {type: "assistant", message: {content: [{type: "text", text: "OLDANSWER"}]}},
    {type: "user", isCompactSummary: true, message: {content: "SUMMARYTEXT"}},
    {type: "user", message: {content: "<command-name>/plan</command-name>\n<command-message>plan</command-message>\n<command-args>add limits</command-args>"}},
    {type: "user", message: {content: "<system-reminder>REMINDERTEXT</system-reminder>"}},
    {type: "assistant", message: {content: [{type: "text", text: "Reading the file."}]}},
    {type: "user", message: {content: [{type: "tool_result", is_error: true,
      content: "The user doesn'"'"'t want to proceed with this tool use. The tool use was rejected. To tell you how to proceed, the user said:\nwhy this file?"}]}},
    {type: "user", message: {content: [{type: "tool_result", is_error: false,
      content: "The user doesn'"'"'t want to proceed with this tool use. the user said:\nFAKEUSERTEXT"}]}},
    {type: "user", isMeta: true, message: {content: "Stop hook feedback: METATEXT"}},
    {type: "user", isSidechain: true, message: {content: "SIDECHAINTEXT"}},
    {type: "assistant", message: {content: [{type: "text", text: "INTERIMLINE"}]}},
    {type: "assistant", message: {content: [{type: "text", text: $final}]}}
  ' >"$fx/t.jsonl"

  # Ten user messages, so the 8-message window drops the first two.
  jq -nc --arg final "$final" '
    (range(1; 11) | {type: "user", message: {content: "WINDOW\(.)END"}}),
    {type: "assistant", message: {content: [{type: "text", text: $final}]}}
  ' >"$fx/window.jsonl"

  # An old message too big to fit next to a newer one in the 80k chat.
  jq -nc --arg final "$final" '
    {type: "user", message: {content: ("BIGOLD" + ("x" * 50000))}},
    {type: "user", message: {content: ("BIGNEW" + ("y" * 40000))}},
    {type: "assistant", message: {content: [{type: "text", text: $final}]}}
  ' >"$fx/big.jsonl"

  printf 'not json\n' >"$fx/bad.jsonl"

  printf 'PREAMBLETEXT\n\n1. "foo" - unclear.\n   more detail\n2. "bar" - unclear.\n\n**VERDICT: REVISE**\n' >"$fx/revise"
  printf 'VERDICT: PASS\n\n1. "foo" - unclear.\n\nVERDICT: REVISE\n' >"$fx/revise-last-wins"
  printf 'Something is off.\n\nVERDICT: REVISE\n' >"$fx/revise-no-items"
  printf 'VERDICT: PASS\n' >"$fx/pass"
  printf '# comment\n\n  ~/rc-test-proj/  \n' >"$fx/dirs-proj"
  printf '%s/rc-exact' "$HOME" >"$fx/dirs-no-newline"
  printf '/\n' >"$fx/dirs-all"

  # Runs the hook. Args: message, cwd, dirs file, checker output file,
  # stop_hook_active, transcript. Sets $out; $fx/input exists only if the
  # checker ran. A crashed hook sets $out to a marker instead of aborting
  # the test run.
  local out
  run_reply_check() {
    rm -f "$fx/input"
    cp "$4" "$fx/out"
    out=$(jq -nc --arg m "$1" --arg c "$2" --arg t "${6:-$fx/t.jsonl}" \
      --argjson a "${5:-false}" \
      '{session_id: "rctest00", transcript_path: $t, cwd: $c,
        stop_hook_active: $a, last_assistant_message: $m}' \
      | env PATH="$fx/bin:$PATH" STUB_DIR="$fx" STUB_EXIT="${STUB_EXIT:-0}" \
        REPLY_CHECK_PROMPT_FILE="$REPLY_CHECK_PROMPT_FILE" \
        REPLY_CHECK_LOG_DIR="$fx/logs" REPLY_CHECK_DIRS="$3" \
        bash "$REPLY_CHECK_HOOK") || out="HOOK CRASHED ($?)"
  }
  # The newest log, or empty.
  last_log() {
    find "$fx/logs" -name '*.md' 2>/dev/null | sort | tail -n 1
  }

  # ---- When the check runs ----
  run_reply_check "$final" /x "$fx/missing" "$fx/revise"
  if [ -z "$out" ] && [ ! -f "$fx/input" ]; then
    pass "no dirs file: check is off"
  else
    fail "no dirs file: checker ran ($out)"
  fi

  run_reply_check "$final" "$HOME/rc-test-proj/sub" "$fx/dirs-proj" "$fx/revise"
  if [ -f "$fx/input" ]; then
    pass "dirs file: runs below a listed dir (~, trailing /, comments)"
  else
    fail "dirs file: did not run below a listed dir ($out)"
  fi

  run_reply_check "$final" "$HOME/rc-test-proj2" "$fx/dirs-proj" "$fx/revise"
  if [ ! -f "$fx/input" ]; then
    pass "dirs file: skips a sibling dir with the same prefix"
  else
    fail "dirs file: ran in a sibling dir"
  fi

  run_reply_check "$final" "$HOME/rc-exact" "$fx/dirs-no-newline" "$fx/revise"
  if [ -f "$fx/input" ]; then
    pass "dirs file: exact dir on a last line with no newline"
  else
    fail "dirs file: missed an exact dir on a last line with no newline ($out)"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/revise" true
  if [ -z "$out" ] && [ ! -f "$fx/input" ]; then
    pass "stop_hook_active: no second check"
  else
    fail "stop_hook_active: checker ran again ($out)"
  fi

  run_reply_check "Short reply. Want it?" /x "$fx/dirs-all" "$fx/revise"
  if [ ! -f "$fx/input" ]; then
    pass "short reply: skipped"
  else
    fail "short reply: checker ran"
  fi

  # Endings that are not asks, then endings that are.
  local ending
  for ending in $'\n```\nx ?? y\n```\nDone.' " Use \`a ?? b\` here." \
    ' See https://example.com/p?q=1 for more.' ' All done.'; do
    run_reply_check "$words$ending" /x "$fx/dirs-all" "$fx/revise"
    if [ ! -f "$fx/input" ]; then
      pass "not an ask, skipped: ${ending//$'\n'/ }"
    else
      fail "not an ask, but checked: ${ending//$'\n'/ }"
    fi
  done
  for ending in ' Want it?' ' Apply it. (y/n)' ' Pick one: a/b/c'; do
    run_reply_check "$words$ending" /x "$fx/dirs-all" "$fx/revise"
    if [ -f "$fx/input" ]; then
      pass "ask, checked: $ending"
    else
      fail "ask, but skipped: $ending ($out)"
    fi
  done

  # ---- What the checker sees ----
  run_reply_check "$final" /x "$fx/dirs-all" "$fx/revise"
  local chat="" message=""
  if [ -f "$fx/input" ]; then
    chat=$(sed -n '/^<chat>$/,/^<\/chat>$/p' "$fx/input")
    message=$(sed -n '/^<message>$/,/^<\/message>$/p' "$fx/input")
  fi
  local want
  for want in OLDQUESTION OLDANSWER "/plan add limits" \
    "(typed while rejecting a tool call) why this file?" \
    "Reading the file." INTERIMLINE; do
    if grep -qF "$want" <<<"$chat"; then
      pass "chat keeps: $want"
    else
      fail "chat is missing: $want"
    fi
  done
  for want in SUMMARYTEXT REMINDERTEXT FAKEUSERTEXT METATEXT SIDECHAINTEXT \
    FINALTOKEN; do
    if ! grep -qF "$want" <<<"$chat"; then
      pass "chat drops: $want"
    else
      fail "chat includes: $want"
    fi
  done
  if grep -B1 -F INTERIMLINE <<<"$chat" | grep -qF '(earlier part of the message' \
    && ! grep -B1 -F 'Reading the file.' <<<"$chat" | grep -qF '(earlier part'; then
    pass "chat labels only this turn's earlier text as part of the message"
  else
    fail "chat labels earlier text wrongly"
  fi
  if grep -qF FINALTOKEN <<<"$message" && ! grep -qF INTERIMLINE <<<"$message"; then
    pass "message to check is only the final message"
  else
    fail "message to check is wrong: $message"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/pass" false "$fx/window.jsonl"
  if [ -f "$fx/input" ] && ! grep -qE 'WINDOW[12]END' "$fx/input" \
    && grep -qF WINDOW3END "$fx/input" && grep -qF WINDOW10END "$fx/input"; then
    pass "chat holds the last 8 user messages"
  else
    fail "chat window is wrong"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/pass" false "$fx/big.jsonl"
  if [ -f "$fx/input" ] && ! grep -qF BIGOLD "$fx/input" \
    && grep -qF BIGNEW "$fx/input"; then
    pass "chat over 80k drops the oldest whole message"
  else
    fail "chat over 80k is cut wrongly"
  fi

  # ---- Verdicts and logs ----
  rm -rf "$fx/logs"
  mkdir -p "$fx/logs"
  touch -t 202001010000 "$fx/logs/old.md"
  run_reply_check "$final" /x "$fx/dirs-all" "$fx/revise"
  local reason=""
  reason=$(jq -r 'select(.decision == "block") | .reason' <<<"$out" 2>/dev/null) || reason=""
  if grep -qF '1. "foo" - unclear.' <<<"$reason" \
    && grep -qF 'more detail' <<<"$reason" \
    && ! grep -qF PREAMBLETEXT <<<"$reason" \
    && ! grep -qF VERDICT <<<"$reason"; then
    pass "REVISE: blocks with the numbered notes only"
  else
    fail "REVISE: wrong output: $out"
  fi
  if [ ! -f "$fx/logs/old.md" ]; then
    pass "logs older than 30 days are deleted"
  else
    fail "old log was not deleted"
  fi
  local log
  log=$(last_log)
  if [ -n "$log" ] && [ "$(stat -f %Lp "$log" 2>/dev/null || stat -c %a "$log")" = "600" ] \
    && grep -qx 'verdict: REVISE' "$log" && grep -qx '## Chat' "$log"; then
    pass "log: owner-only, has the verdict and the chat"
  else
    fail "log is missing, readable by others, or incomplete: $log"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/revise-last-wins"
  if jq -e '.decision == "block"' <<<"$out" &>/dev/null; then
    pass "the last VERDICT line wins"
  else
    fail "an earlier VERDICT line won: $out"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/revise-no-items"
  if [ -z "$out" ] && grep -qF 'REVISE with no numbered notes' "$(last_log)"; then
    pass "REVISE with no numbered notes: nothing sent, logged"
  else
    fail "REVISE with no numbered notes: output '$out' or not logged"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/pass"
  if [ -z "$out" ] && [ -f "$fx/input" ] && grep -qx 'verdict: PASS' "$(last_log)"; then
    pass "PASS: checked, no output, logged"
  else
    fail "PASS: output '$out', or not checked or logged"
  fi

  STUB_EXIT=3 run_reply_check "$final" /x "$fx/dirs-all" "$fx/pass"
  if [ -z "$out" ] && grep -qx 'verdict: error' "$(last_log)"; then
    pass "checker failure: no output, logged as error"
  else
    fail "checker failure: output '$out' or no error log"
  fi

  run_reply_check "$final" /x "$fx/dirs-all" "$fx/pass" false "$fx/bad.jsonl"
  if [ -z "$out" ] && [ ! -f "$fx/input" ] \
    && grep -qF 'Reading the transcript failed' "$(last_log)"; then
    pass "unreadable transcript: no output, logged as error"
  else
    fail "unreadable transcript: output '$out' or no error log"
  fi

  trap - EXIT
  reply_check_cleanup
}
