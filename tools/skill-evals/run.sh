#!/usr/bin/env bash
# Runs a skill's eval cases headless and checks each answer with jq.
#
#   run.sh <skill file> <suite dir> [--runs N] [--model ID] [--placement system|user] [--safe-mode] [--check] [case ...]
#
# Each case is <suite>/cases/<name>.md (the scenario) plus <name>.jq (a jq
# program that reads the model's JSON answer and prints the names of the
# checks that failed, as an array; [] is a pass). The user message is
# <suite>/preamble.md, then the scenario. With --placement user (the
# default), the skill text goes at the start of the user message, as a skill
# arrives in a real session; a user-placement run is the check before a
# skill change ships. With --placement system, the skill goes in the system
# prompt, so every case shares it as a cached prefix: cheaper for iterating,
# but placement can change an answer.
#
# --safe-mode keeps the user's CLAUDE.md, skills, and plugins out of the
# session. Use it when the text under test is CLAUDE.md itself, so the
# deployed file can't supply a rule that the copy under test deleted.
#
# The model gets no built-in tools and no MCP servers. Every run of every
# case is reported; a failure doesn't stop the others. Exits 1 when any run
# fails.

set -euo pipefail

usage() {
  echo "usage: run.sh <skill file> <suite dir> [--runs N] [--model ID] [--placement system|user] [--safe-mode] [--check] [case ...]" >&2
  exit 2
}

[ $# -ge 2 ] || usage
skill=$1
suite=${2%/}
shift 2
runs=3
model=claude-opus-5-5
check_only=false
safe_mode=()
placement=user
cases=()
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs=$2 && shift 2 ;;
    --model) model=$2 && shift 2 ;;
    --placement) placement=$2 && shift 2 ;;
    --safe-mode) safe_mode=(--safe-mode) && shift ;;
    --check) check_only=true && shift ;;
    -*) usage ;;
    *) cases+=("$1") && shift ;;
  esac
done
[ -f "$skill" ] || {
  echo "skill file not found: $skill" >&2
  exit 2
}
[ -f "$suite/preamble.md" ] || {
  echo "no preamble.md in $suite" >&2
  exit 2
}
case "$placement" in
  system | user) ;;
  *) usage ;;
esac
if [ ${#cases[@]} -eq 0 ]; then
  for f in "$suite"/cases/*.md; do
    cases+=("$(basename "$f" .md)")
  done
fi

for name in "${cases[@]}"; do
  [ -f "$suite/cases/$name.md" ] && [ -f "$suite/cases/$name.jq" ] \
    || {
      echo "missing $name.md or $name.jq in $suite/cases" >&2
      exit 2
    }
  # An empty answer must fail at least one check without a jq error, so a
  # check file that errors or passes on nothing is caught before any call.
  if ! echo '{}' | jq -c -f "$suite/cases/$name.jq" | jq -e 'length > 0' >/dev/null; then
    echo "$name.jq errors or passes on an empty answer" >&2
    exit 2
  fi
done
if [ "$check_only" = true ]; then
  echo "${#cases[@]} cases checked"
  exit 0
fi

here=$(cd "$(dirname "$0")" && pwd -P)
mkdir -p "$here/.runs"
# mktemp's suffix keeps two runs started in the same second apart.
out=$(mktemp -d "$here/.runs/$(basename "$suite")-$placement-$(date +%Y-%m-%d-%H%M%S)-XXXX")
# Every case runs on this copy, so an edit to the skill file during a run
# (a formatter, another session) can't split the run across two texts.
cp "$skill" "$out/skill.md"
skill="$out/skill.md"
# An empty working directory outside the repo, so no project CLAUDE.md,
# memory, or git state reaches the model. The user's global CLAUDE.md loads,
# as it does when a skill runs for real, unless --safe-mode is set.
workdir=$(mktemp -d)
trap 'rmdir "$workdir" 2>/dev/null || true' EXIT

# extract_last_json: the last ```json fenced block on stdin.
extract_last_json() {
  awk '/^```json[[:space:]]*$/ { buf = ""; inblock = 1; next }
       /^```[[:space:]]*$/ { if (inblock) { last = buf; inblock = 0 }; next }
       inblock { buf = buf $0 "\n" }
       END { printf "%s", last }'
}

run_one() {
  local name=$1 n=$2 prompt=$3 dir="$out/$1/run$2" api_error
  local -a skill_args=()
  [ "$placement" = system ] && skill_args=(--append-system-prompt-file "$skill")
  mkdir -p "$dir"
  # --exclude-dynamic-system-prompt-sections keeps per-run details (cwd, date)
  # out of the system prompt, so its cached copy is reused across calls.
  # --strict-mcp-config with no --mcp-config loads no MCP servers. Hooks are
  # off: a Stop hook's feedback would start a second turn the case didn't ask
  # for.
  (cd "$workdir" && claude -p --model "$model" --tools "" --strict-mcp-config \
    --settings '{"disableAllHooks": true}' \
    --no-session-persistence --permission-prompts none \
    --exclude-dynamic-system-prompt-sections \
    ${skill_args[@]+"${skill_args[@]}"} ${safe_mode[@]+"${safe_mode[@]}"} \
    --output-format json <"$prompt") >"$dir/response.json" \
    2>"$dir/stderr.txt" || true
  jq -r '.result // ""' "$dir/response.json" >"$dir/result.md" 2>/dev/null || : >"$dir/result.md"
  extract_last_json <"$dir/result.md" >"$dir/answer.json"
  # An API or CLI error isn't a skill failure, so name it as such.
  api_error=$(jq -r 'select(.is_error == true) | "API error: \(.api_error_status // .subtype // "unknown")"' \
    "$dir/response.json" 2>/dev/null || echo "no response from claude")
  if [ -n "$api_error" ]; then
    jq -cn --arg e "$api_error" '[$e]' >"$dir/failures.json"
  elif ! jq -e . "$dir/answer.json" >/dev/null 2>&1; then
    echo '["answer is not a JSON block"]' >"$dir/failures.json"
  elif ! jq -c -f "$suite/cases/$name.jq" "$dir/answer.json" >"$dir/failures.json" 2>"$dir/jq-error.txt"; then
    echo '["jq check errored"]' >"$dir/failures.json"
  fi
}

printf 'case\trun\tresult\tfailures\tcost_usd\tttft_ms\tduration_ms\tinput\tcache_write\tcache_read\toutput\tthinking\n' \
  >"$out/summary.tsv"

for name in "${cases[@]}"; do
  mkdir -p "$out/$name"
  prompt="$out/$name/prompt.md"
  {
    if [ "$placement" = user ]; then
      cat "$skill"
      printf '\n\n---\n\n'
    fi
    cat "$suite/preamble.md"
    printf '\n'
    cat "$suite/cases/$name.md"
  } >"$prompt"
  # The first run writes this case's prompt to the cache; the rest then run
  # in parallel and read it. Cases run one after another.
  run_one "$name" 1 "$prompt"
  n=2
  while [ "$n" -le "$runs" ]; do
    run_one "$name" "$n" "$prompt" &
    n=$((n + 1))
  done
  wait
  for n in $(seq 1 "$runs"); do
    dir="$out/$name/run$n"
    failures=$(cat "$dir/failures.json")
    result=PASS
    [ "$failures" = "[]" ] || result=FAIL
    stats=$(jq -r '[.total_cost_usd, .ttft_ms, .duration_ms,
        .usage.input_tokens, .usage.cache_creation_input_tokens,
        .usage.cache_read_input_tokens, .usage.output_tokens,
        ([.modelUsage[]?.thinkingTokens] | add)] | map(. // "") | @tsv' \
      "$dir/response.json" 2>/dev/null || printf '\t\t\t\t\t\t\t')
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$n" "$result" "$failures" "$stats" >>"$out/summary.tsv"
    printf '%-28s run %s  %s  %s\n' "$name" "$n" "$result" "$failures"
  done
done

echo
jq -Rr 'split("\t") | select(.[0] != "case") | .[2]' "$out/summary.tsv" | sort | uniq -c
cost=$(jq -Rn '[inputs | split("\t") | select(.[0] != "case") | .[4] | tonumber? // empty] | add // 0' \
  "$out/summary.tsv")
echo "total cost: \$$cost"
echo "results: $out"
! cut -f3 "$out/summary.tsv" | grep -x FAIL >/dev/null
