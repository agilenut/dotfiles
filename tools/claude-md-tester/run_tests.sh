#!/usr/bin/env bash
# A/B test CLAUDE.md instructions using claude -p (print mode).
# For each instruction, runs targeted prompts with and without it to measure behavioral impact.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS="$SCRIPT_DIR/test_definitions.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
BACKUP_FILE="$HOME/.claude/CLAUDE.md.backup.$$"
RESULTS_DIR="$SCRIPT_DIR/results"
SOURCE_MD="$SCRIPT_DIR/../../home/dot_claude/CLAUDE.md"

# Configurable parameters
MODEL="${MODEL:-opus}"
RUNS="${RUNS:-5}"
CONCURRENCY="${CONCURRENCY:-3}"
DRY_RUN="${DRY_RUN:-false}"
FILTER="${FILTER:-}" # Run only this instruction ID if set

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { printf "${BLUE}[%s]${NC} %s\n" "$(date +%H:%M:%S)" "$*"; }
warn() { printf "${YELLOW}[%s] WARN:${NC} %s\n" "$(date +%H:%M:%S)" "$*"; }
err() { printf "${RED}[%s] ERROR:${NC} %s\n" "$(date +%H:%M:%S)" "$*" >&2; }
ok() { printf "${GREEN}[%s] OK:${NC} %s\n" "$(date +%H:%M:%S)" "$*"; }

usage() {
  cat <<'EOF'
Usage: run_tests.sh [OPTIONS]

Options:
  --model MODEL       Claude model to use (default: opus)
  --runs N            Number of runs per condition (default: 5)
  --concurrency N     Parallel claude -p calls per batch (default: 3)
  --filter ID         Run only the instruction with this ID
  --dry-run           Show what would run without executing
  --clean             Remove previous results before running
  -h, --help          Show this help

Environment variables:
  MODEL, RUNS, CONCURRENCY, DRY_RUN, FILTER

Examples:
  ./run_tests.sh --filter concise --runs 2     # Quick test of one instruction
  ./run_tests.sh --dry-run                     # Preview all test runs
  ./run_tests.sh --model sonnet --runs 3       # Cheaper full run with Sonnet
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --runs)
      RUNS="$2"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    --filter)
      FILTER="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --clean)
      rm -rf "$RESULTS_DIR"
      shift
      ;;
    -h | --help) usage ;;
    *)
      err "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate dependencies
for cmd in claude jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "Required command not found: $cmd"
    exit 1
  fi
done

if [[ ! -f "$DEFINITIONS" ]]; then
  err "Test definitions not found: $DEFINITIONS"
  exit 1
fi

if [[ ! -f "$SOURCE_MD" ]]; then
  err "Source CLAUDE.md not found: $SOURCE_MD"
  exit 1
fi

# Read the source CLAUDE.md content
FULL_CONTENT="$(cat "$SOURCE_MD")"

# Backup and restore logic
backup_claude_md() {
  if [[ -f "$CLAUDE_MD" ]]; then
    cp "$CLAUDE_MD" "$BACKUP_FILE"
    log "Backed up $CLAUDE_MD to $BACKUP_FILE"
  else
    # Mark that there was no original file
    touch "$BACKUP_FILE.was_missing"
    log "No existing $CLAUDE_MD (will remove after tests)"
  fi
}

restore_claude_md() {
  if [[ -f "$BACKUP_FILE" ]]; then
    cp "$BACKUP_FILE" "$CLAUDE_MD"
    rm -f "$BACKUP_FILE"
    ok "Restored $CLAUDE_MD from backup"
  elif [[ -f "$BACKUP_FILE.was_missing" ]]; then
    rm -f "$CLAUDE_MD" "$BACKUP_FILE.was_missing"
    ok "Removed $CLAUDE_MD (was not present before tests)"
  fi
}

# Ensure restoration on exit (tmpdir cleanup added in main)
TMPDIR_CLEANUP=""
cleanup() {
  restore_claude_md
  if [[ -n "$TMPDIR_CLEANUP" && -d "$TMPDIR_CLEANUP" ]]; then
    rm -rf "$TMPDIR_CLEANUP"
  fi
}
trap cleanup EXIT

# Generate ablated CLAUDE.md (remove one instruction line)
generate_ablated() {
  local line_num="$1"
  local content="$FULL_CONTENT"
  # Remove the specific line (1-indexed) from the content
  echo "$content" | sed "${line_num}d"
}

# Run a single claude -p call and save the result
run_claude() {
  local prompt="$1"
  local output_file="$2"
  local tmpdir="$3"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo '{"type":"dry_run","result":"[DRY RUN] would call claude -p"}' >"$output_file"
    return 0
  fi

  local start_time
  start_time="$(date +%s)"

  # Run from temp directory to avoid loading project CLAUDE.md
  # Use --output-format json for structured output
  local raw_output
  if raw_output=$(cd "$tmpdir" && claude -p "$prompt" --model "$MODEL" --output-format json 2>/dev/null); then
    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))

    # Wrap in our metadata envelope
    jq --arg dur "$duration" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{timestamp: $ts, duration_seconds: ($dur | tonumber), claude_response: .}' \
      <<<"$raw_output" >"$output_file"
  else
    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    # Save error
    jq -n --arg dur "$duration" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg err "claude -p failed" \
      '{timestamp: $ts, duration_seconds: ($dur | tonumber), error: $err}' >"$output_file"
    warn "claude -p failed for prompt: ${prompt:0:60}..."
    return 1
  fi
}

# Run a batch of claude -p calls with concurrency control
run_batch() {
  local tmpdir="$1"
  shift
  # Remaining args are pairs: "prompt" "output_file" "prompt" "output_file" ...
  local pids=()
  local count=0

  while [[ $# -gt 0 ]]; do
    local prompt="$1"
    local output_file="$2"
    shift 2

    run_claude "$prompt" "$output_file" "$tmpdir" &
    pids+=($!)
    count=$((count + 1))

    # Throttle concurrency
    if ((count >= CONCURRENCY)); then
      wait "${pids[0]}" 2>/dev/null || true
      pids=("${pids[@]:1}")
      count=$((count - 1))
    fi
  done

  # Wait for remaining
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done
}

# Main test loop
main() {
  local num_instructions
  num_instructions=$(jq length "$DEFINITIONS")

  log "CLAUDE.md A/B Tester"
  log "Model: $MODEL | Runs: $RUNS | Concurrency: $CONCURRENCY"
  log "Instructions to test: $num_instructions"
  if [[ -n "$FILTER" ]]; then
    log "Filter: only testing '$FILTER'"
  fi
  echo

  # Create temp working directory (no project CLAUDE.md)
  local tmpdir
  tmpdir=$(mktemp -d)
  TMPDIR_CLEANUP="$tmpdir"

  mkdir -p "$RESULTS_DIR"

  # Step 0: Backup
  backup_claude_md

  # Step 1: Bare baseline (empty CLAUDE.md)
  log "Phase 0: Bare baseline (empty CLAUDE.md)"
  mkdir -p "$HOME/.claude"
  : >"$CLAUDE_MD" # empty file

  for ((i = 0; i < num_instructions; i++)); do
    local id
    id=$(jq -r ".[$i].id" "$DEFINITIONS")

    if [[ -n "$FILTER" && "$id" != "$FILTER" ]]; then
      continue
    fi

    local num_prompts
    num_prompts=$(jq -r ".[$i].prompts | length" "$DEFINITIONS")

    local batch_args=()
    for ((p = 0; p < num_prompts; p++)); do
      local prompt
      prompt=$(jq -r ".[$i].prompts[$p]" "$DEFINITIONS")
      local prompt_hash
      prompt_hash=$(echo -n "$prompt" | md5 -q 2>/dev/null || echo -n "$prompt" | md5sum | cut -d' ' -f1)

      local out_dir="$RESULTS_DIR/$id/bare/$prompt_hash"
      mkdir -p "$out_dir"

      # Only 1 bare run per prompt (baseline)
      local out_file="$out_dir/run_1.json"
      if [[ -f "$out_file" && "$DRY_RUN" != "true" ]]; then
        continue # Skip if already collected
      fi
      batch_args+=("$prompt" "$out_file")
    done

    if ((${#batch_args[@]} > 0)); then
      run_batch "$tmpdir" "${batch_args[@]}"
    fi
  done
  ok "Bare baseline complete"
  echo

  # Step 2: For each instruction, run with-full and with-ablated
  for ((i = 0; i < num_instructions; i++)); do
    local id line instruction
    id=$(jq -r ".[$i].id" "$DEFINITIONS")
    line=$(jq -r ".[$i].line" "$DEFINITIONS")
    instruction=$(jq -r ".[$i].instruction" "$DEFINITIONS")

    if [[ -n "$FILTER" && "$id" != "$FILTER" ]]; then
      continue
    fi

    local num_prompts
    num_prompts=$(jq -r ".[$i].prompts | length" "$DEFINITIONS")

    log "[$((i + 1))/$num_instructions] Testing: $id"
    log "  Instruction (line $line): ${instruction:0:70}"

    # --- Variant: full (all instructions present) ---
    log "  Variant: full"
    echo "$FULL_CONTENT" >"$CLAUDE_MD"

    local batch_args=()
    for ((p = 0; p < num_prompts; p++)); do
      local prompt
      prompt=$(jq -r ".[$i].prompts[$p]" "$DEFINITIONS")
      local prompt_hash
      prompt_hash=$(echo -n "$prompt" | md5 -q 2>/dev/null || echo -n "$prompt" | md5sum | cut -d' ' -f1)

      for ((r = 1; r <= RUNS; r++)); do
        local out_dir="$RESULTS_DIR/$id/full/$prompt_hash"
        mkdir -p "$out_dir"
        local out_file="$out_dir/run_${r}.json"

        if [[ -f "$out_file" && "$DRY_RUN" != "true" ]]; then
          continue
        fi
        batch_args+=("$prompt" "$out_file")
      done
    done

    if ((${#batch_args[@]} > 0)); then
      run_batch "$tmpdir" "${batch_args[@]}"
    fi
    ok "  full variant done (${#batch_args[@]} calls)"

    # --- Variant: ablated (instruction removed) ---
    log "  Variant: ablated (line $line removed)"
    generate_ablated "$line" >"$CLAUDE_MD"

    batch_args=()
    for ((p = 0; p < num_prompts; p++)); do
      local prompt
      prompt=$(jq -r ".[$i].prompts[$p]" "$DEFINITIONS")
      local prompt_hash
      prompt_hash=$(echo -n "$prompt" | md5 -q 2>/dev/null || echo -n "$prompt" | md5sum | cut -d' ' -f1)

      for ((r = 1; r <= RUNS; r++)); do
        local out_dir="$RESULTS_DIR/$id/ablated/$prompt_hash"
        mkdir -p "$out_dir"
        local out_file="$out_dir/run_${r}.json"

        if [[ -f "$out_file" && "$DRY_RUN" != "true" ]]; then
          continue
        fi
        batch_args+=("$prompt" "$out_file")
      done
    done

    if ((${#batch_args[@]} > 0)); then
      run_batch "$tmpdir" "${batch_args[@]}"
    fi
    ok "  ablated variant done (${#batch_args[@]} calls)"
    echo
  done

  ok "All tests complete. Results in: $RESULTS_DIR"
  log "Run analyze.sh to generate the report."
}

main "$@"
