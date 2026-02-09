#!/usr/bin/env bash
# Analyze A/B test results from run_tests.sh and generate a report.
# Scores each instruction's impact using automated metrics and side-by-side comparisons.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS="$SCRIPT_DIR/test_definitions.json"
RESULTS_DIR="$SCRIPT_DIR/results"
REPORT="$RESULTS_DIR/report.md"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { printf "${BLUE}[analyze]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[analyze] WARN:${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[analyze] OK:${NC} %s\n" "$*"; }

# Validate
if ! command -v jq &>/dev/null; then
  echo "Required: jq" >&2
  exit 1
fi

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "No results found. Run run_tests.sh first." >&2
  exit 1
fi

# Extract response text from a result JSON file.
# Handles both --output-format json (has .result) and raw text responses.
extract_text() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return
  fi
  # Try to get text from claude's JSON output format
  # The structure is: {claude_response: {result: "text"}} or {claude_response: {result: [{type: "text", text: "..."}]}}
  local text
  text=$(jq -r '
        .claude_response //  . |
        if .result then
            if (.result | type) == "string" then .result
            elif (.result | type) == "array" then
                [.result[] | select(.type == "text") | .text] | join("\n")
            else .result | tostring
            end
        elif .text then .text
        else tostring
        end
    ' "$file" 2>/dev/null || cat "$file")
  echo "$text"
}

# Count words in response text
word_count() {
  echo "$1" | wc -w | tr -d ' '
}

# Check if text contains a pattern (case-insensitive)
contains_pattern() {
  local text="$1"
  local pattern="$2"
  echo "$text" | grep -iq "$pattern" && echo "1" || echo "0"
}

# Count fenced code blocks without language tags
count_untagged_blocks() {
  local text="$1"
  # Match ``` at start of line not followed by a language identifier
  echo "$text" | grep -cE '^\s*```\s*$' || true
}

# Count total fenced code blocks
count_total_blocks() {
  local text="$1"
  echo "$text" | grep -cE '^\s*```' || true
}

# Compute mean of space-separated numbers
mean() {
  local nums="$1"
  local sum=0
  local count=0
  for n in $nums; do
    sum=$((sum + n))
    count=$((count + 1))
  done
  if ((count > 0)); then
    echo $((sum / count))
  else
    echo 0
  fi
}

# Score a single instruction's results
score_instruction() {
  local id="$1"
  local idx="$2"
  local inst_dir="$RESULTS_DIR/$id"

  if [[ ! -d "$inst_dir" ]]; then
    echo "SKIP|No results collected"
    return
  fi

  # Collect all response texts per variant
  local full_texts=()
  local ablated_texts=()
  local bare_texts=()

  for variant_dir in "$inst_dir"/full/*/; do
    [[ -d "$variant_dir" ]] || continue
    for run_file in "$variant_dir"run_*.json; do
      [[ -f "$run_file" ]] || continue
      full_texts+=("$(extract_text "$run_file")")
    done
  done

  for variant_dir in "$inst_dir"/ablated/*/; do
    [[ -d "$variant_dir" ]] || continue
    for run_file in "$variant_dir"run_*.json; do
      [[ -f "$run_file" ]] || continue
      ablated_texts+=("$(extract_text "$run_file")")
    done
  done

  for variant_dir in "$inst_dir"/bare/*/; do
    [[ -d "$variant_dir" ]] || continue
    for run_file in "$variant_dir"run_*.json; do
      [[ -f "$run_file" ]] || continue
      bare_texts+=("$(extract_text "$run_file")")
    done
  done

  local full_count=${#full_texts[@]}
  local ablated_count=${#ablated_texts[@]}

  if ((full_count == 0 || ablated_count == 0)); then
    echo "SKIP|Incomplete results (full=$full_count, ablated=$ablated_count)"
    return
  fi

  # Run scoring based on instruction type
  local metrics_report=""
  local effect="Unknown"

  case "$id" in
    concise)
      # Compare word counts
      local full_wc="" ablated_wc=""
      for t in "${full_texts[@]}"; do full_wc+="$(word_count "$t") "; done
      for t in "${ablated_texts[@]}"; do ablated_wc+="$(word_count "$t") "; done
      local full_mean ablated_mean
      full_mean=$(mean "$full_wc")
      ablated_mean=$(mean "$ablated_wc")

      # Check for pleasantries in ablated vs full
      local full_greetings=0 ablated_greetings=0
      for t in "${full_texts[@]}"; do
        for pat in "Sure!" "Great question" "Absolutely" "Happy to" "I'd be happy" "Of course"; do
          full_greetings=$((full_greetings + $(contains_pattern "$t" "$pat")))
        done
      done
      for t in "${ablated_texts[@]}"; do
        for pat in "Sure!" "Great question" "Absolutely" "Happy to" "I'd be happy" "Of course"; do
          ablated_greetings=$((ablated_greetings + $(contains_pattern "$t" "$pat")))
        done
      done

      metrics_report="Words: full=$full_mean, ablated=$ablated_mean (delta=$((ablated_mean - full_mean)))"
      metrics_report+="\nPleasantries: full=$full_greetings, ablated=$ablated_greetings"

      if ((ablated_mean > full_mean + 20 || ablated_greetings > full_greetings)); then
        effect="High"
      elif ((ablated_mean > full_mean + 5)); then
        effect="Medium"
      else
        effect="Low"
      fi
      ;;

    ambiguity_options)
      # Check for numbered options and recommendation keywords
      local full_opts=0 ablated_opts=0
      local full_recs=0 ablated_recs=0
      for t in "${full_texts[@]}"; do
        local opts
        opts=$(echo "$t" | grep -cE '^\s*[0-9]+\.' || true)
        full_opts=$((full_opts + opts))
        full_recs=$((full_recs + $(contains_pattern "$t" "recommend")))
      done
      for t in "${ablated_texts[@]}"; do
        local opts
        opts=$(echo "$t" | grep -cE '^\s*[0-9]+\.' || true)
        ablated_opts=$((ablated_opts + opts))
        ablated_recs=$((ablated_recs + $(contains_pattern "$t" "recommend")))
      done
      metrics_report="Numbered options: full=$full_opts, ablated=$ablated_opts"
      metrics_report+="\nRecommendation keyword: full=$full_recs, ablated=$ablated_recs"

      if ((full_opts > ablated_opts + 2 || full_recs > ablated_recs)); then
        effect="High"
      elif ((full_opts > ablated_opts)); then
        effect="Medium"
      else
        effect="Low"
      fi
      ;;

    no_suppress_rules)
      # Check for eslint-disable / ts-ignore in responses
      local full_suppress=0 ablated_suppress=0
      for t in "${full_texts[@]}"; do
        full_suppress=$((full_suppress + $(contains_pattern "$t" "eslint-disable")))
        full_suppress=$((full_suppress + $(contains_pattern "$t" "@ts-ignore")))
      done
      for t in "${ablated_texts[@]}"; do
        ablated_suppress=$((ablated_suppress + $(contains_pattern "$t" "eslint-disable")))
        ablated_suppress=$((ablated_suppress + $(contains_pattern "$t" "@ts-ignore")))
      done
      metrics_report="Rule suppression: full=$full_suppress, ablated=$ablated_suppress"
      if ((ablated_suppress > full_suppress)); then
        effect="High"
      else
        effect="Low"
      fi
      ;;

    tdd)
      # Check if tests appear before implementation
      local full_tdd=0 ablated_tdd=0
      for t in "${full_texts[@]}"; do
        # Find position of "test" and "def "/"function " keywords
        local test_pos impl_pos
        test_pos=$(echo "$t" | grep -n -iE '(test_|describe\(|it\()' | head -1 | cut -d: -f1)
        impl_pos=$(echo "$t" | grep -n -E '(^def |^function |^class )' | head -1 | cut -d: -f1)
        if [[ -n "$test_pos" && -n "$impl_pos" && "$test_pos" -lt "$impl_pos" ]]; then
          full_tdd=$((full_tdd + 1))
        fi
      done
      for t in "${ablated_texts[@]}"; do
        local test_pos impl_pos
        test_pos=$(echo "$t" | grep -n -iE '(test_|describe\(|it\()' | head -1 | cut -d: -f1)
        impl_pos=$(echo "$t" | grep -n -E '(^def |^function |^class )' | head -1 | cut -d: -f1)
        if [[ -n "$test_pos" && -n "$impl_pos" && "$test_pos" -lt "$impl_pos" ]]; then
          ablated_tdd=$((ablated_tdd + 1))
        fi
      done
      metrics_report="Tests-first: full=$full_tdd/$full_count, ablated=$ablated_tdd/$ablated_count"
      if ((full_tdd > ablated_tdd + 1)); then
        effect="High"
      elif ((full_tdd > ablated_tdd)); then
        effect="Medium"
      else
        effect="Low"
      fi
      ;;

    branch_naming)
      # Check for type/kebab-case pattern
      local full_match=0 ablated_match=0
      for t in "${full_texts[@]}"; do
        full_match=$((full_match + $(echo "$t" | grep -cE '\b(fix|feat|feature|bug|chore|refactor|docs|test|style|perf|ci|build)/[a-z][a-z0-9-]+' || true)))
      done
      for t in "${ablated_texts[@]}"; do
        ablated_match=$((ablated_match + $(echo "$t" | grep -cE '\b(fix|feat|feature|bug|chore|refactor|docs|test|style|perf|ci|build)/[a-z][a-z0-9-]+' || true)))
      done
      metrics_report="Branch pattern match: full=$full_match, ablated=$ablated_match"
      if ((full_match > ablated_match)); then
        effect="High"
      else
        effect="Low"
      fi
      ;;

    commit_format)
      # Check for short first line + bullets
      local full_bullets=0 ablated_bullets=0
      for t in "${full_texts[@]}"; do
        full_bullets=$((full_bullets + $(echo "$t" | grep -cE '^\s*[-*] ' || true)))
      done
      for t in "${ablated_texts[@]}"; do
        ablated_bullets=$((ablated_bullets + $(echo "$t" | grep -cE '^\s*[-*] ' || true)))
      done
      metrics_report="Bullet points: full=$full_bullets, ablated=$ablated_bullets"
      if ((full_bullets > ablated_bullets + 2)); then
        effect="High"
      elif ((full_bullets > ablated_bullets)); then
        effect="Medium"
      else
        effect="Low"
      fi
      ;;

    atomic_commits_git | atomic_commits_planning)
      # Check for "separate" / "two" / "split" / "atomic" keywords
      local full_sep=0 ablated_sep=0
      for t in "${full_texts[@]}"; do
        for pat in "separate" "two commit" "split" "atomic" "individual"; do
          full_sep=$((full_sep + $(contains_pattern "$t" "$pat")))
        done
      done
      for t in "${ablated_texts[@]}"; do
        for pat in "separate" "two commit" "split" "atomic" "individual"; do
          ablated_sep=$((ablated_sep + $(contains_pattern "$t" "$pat")))
        done
      done
      metrics_report="Separation advice: full=$full_sep, ablated=$ablated_sep"
      if ((full_sep > ablated_sep + 2)); then
        effect="High"
      elif ((full_sep > ablated_sep)); then
        effect="Medium"
      else
        effect="Low"
      fi
      ;;

    no_coauthor)
      # Check for Co-Authored-By, --amend, force push
      local full_coauth=0 ablated_coauth=0
      for t in "${full_texts[@]}"; do
        full_coauth=$((full_coauth + $(contains_pattern "$t" "Co-[Aa]uthored-[Bb]y")))
        full_coauth=$((full_coauth + $(contains_pattern "$t" "\-\-amend")))
      done
      for t in "${ablated_texts[@]}"; do
        ablated_coauth=$((ablated_coauth + $(contains_pattern "$t" "Co-[Aa]uthored-[Bb]y")))
        ablated_coauth=$((ablated_coauth + $(contains_pattern "$t" "\-\-amend")))
      done
      metrics_report="Co-author/amend: full=$full_coauth, ablated=$ablated_coauth"
      if ((ablated_coauth > full_coauth)); then
        effect="High"
      else
        effect="Low"
      fi
      ;;

    code_block_lang)
      # Check for untagged code blocks
      local full_untagged=0 ablated_untagged=0
      local full_total=0 ablated_total=0
      for t in "${full_texts[@]}"; do
        full_untagged=$((full_untagged + $(count_untagged_blocks "$t")))
        full_total=$((full_total + $(count_total_blocks "$t")))
      done
      for t in "${ablated_texts[@]}"; do
        ablated_untagged=$((ablated_untagged + $(count_untagged_blocks "$t")))
        ablated_total=$((ablated_total + $(count_total_blocks "$t")))
      done
      metrics_report="Untagged blocks: full=$full_untagged/$full_total, ablated=$ablated_untagged/$ablated_total"
      if ((ablated_untagged > full_untagged)); then
        effect="High"
      else
        effect="Low"
      fi
      ;;

    *)
      # Generic pattern-based scoring
      local patterns_present patterns_absent
      patterns_present=$(jq -r ".[$idx].scoring.patterns_present // [] | .[]" "$DEFINITIONS" 2>/dev/null)
      patterns_absent=$(jq -r ".[$idx].scoring.patterns_absent // [] | .[]" "$DEFINITIONS" 2>/dev/null)

      local full_present_hits=0 ablated_present_hits=0
      local full_absent_hits=0 ablated_absent_hits=0

      if [[ -n "$patterns_present" ]]; then
        while IFS= read -r pat; do
          for t in "${full_texts[@]}"; do
            full_present_hits=$((full_present_hits + $(contains_pattern "$t" "$pat")))
          done
          for t in "${ablated_texts[@]}"; do
            ablated_present_hits=$((ablated_present_hits + $(contains_pattern "$t" "$pat")))
          done
        done <<<"$patterns_present"
      fi

      if [[ -n "$patterns_absent" ]]; then
        while IFS= read -r pat; do
          for t in "${full_texts[@]}"; do
            full_absent_hits=$((full_absent_hits + $(contains_pattern "$t" "$pat")))
          done
          for t in "${ablated_texts[@]}"; do
            ablated_absent_hits=$((ablated_absent_hits + $(contains_pattern "$t" "$pat")))
          done
        done <<<"$patterns_absent"
      fi

      metrics_report="Patterns present: full=$full_present_hits, ablated=$ablated_present_hits"
      metrics_report+="\nPatterns absent: full=$full_absent_hits, ablated=$ablated_absent_hits"

      local diff=$((full_present_hits - ablated_present_hits + ablated_absent_hits - full_absent_hits))
      if ((diff > 3)); then
        effect="High"
      elif ((diff > 0)); then
        effect="Medium"
      else
        effect="Low"
      fi
      ;;
  esac

  echo "${effect}|${metrics_report}"
}

# Generate side-by-side comparison for an instruction
generate_comparison() {
  local id="$1"
  local idx="$2"
  local inst_dir="$RESULTS_DIR/$id"

  echo "### $id"
  echo ""
  echo "**Instruction:** $(jq -r ".[$idx].instruction" "$DEFINITIONS")"
  echo ""

  # Show first prompt's first run from each variant
  local first_prompt_dir
  first_prompt_dir=$(ls -d "$inst_dir/full/"*/ 2>/dev/null | head -1)

  if [[ -z "$first_prompt_dir" ]]; then
    echo "No results collected."
    echo ""
    return
  fi

  local prompt_hash
  prompt_hash=$(basename "$first_prompt_dir")

  # Use fenced code blocks with 'text' language tag to satisfy markdownlint
  echo "With instruction (full):"
  echo ""
  echo '```text'
  local full_file="$inst_dir/full/$prompt_hash/run_1.json"
  if [[ -f "$full_file" ]]; then
    extract_text "$full_file" | head -30
    local full_lines
    full_lines=$(extract_text "$full_file" | wc -l | tr -d ' ')
    if ((full_lines > 30)); then
      echo "... (truncated, $full_lines lines total)"
    fi
  else
    echo "(no data)"
  fi
  echo '```'
  echo ""

  echo "Without instruction (ablated):"
  echo ""
  echo '```text'
  local ablated_file="$inst_dir/ablated/$prompt_hash/run_1.json"
  if [[ -f "$ablated_file" ]]; then
    extract_text "$ablated_file" | head -30
    local ablated_lines
    ablated_lines=$(extract_text "$ablated_file" | wc -l | tr -d ' ')
    if ((ablated_lines > 30)); then
      echo "... (truncated, $ablated_lines lines total)"
    fi
  else
    echo "(no data)"
  fi
  echo '```'
  echo ""
}

# Main analysis
main() {
  log "Analyzing results..."

  local num_instructions
  num_instructions=$(jq length "$DEFINITIONS")

  # Build summary table
  local summary_rows=()
  local detail_sections=()

  for ((i = 0; i < num_instructions; i++)); do
    local id instruction section
    id=$(jq -r ".[$i].id" "$DEFINITIONS")
    instruction=$(jq -r ".[$i].instruction" "$DEFINITIONS")
    section=$(jq -r ".[$i].section" "$DEFINITIONS")

    log "Scoring: $id"
    local result
    result=$(score_instruction "$id" "$i")

    local effect="${result%%|*}"

    # Determine recommendation
    local recommendation
    case "$effect" in
      High) recommendation="Keep" ;;
      Medium) recommendation="Review" ;;
      Low) recommendation="Consider removing" ;;
      SKIP) recommendation="Re-run" ;;
      *) recommendation="Manual review" ;;
    esac

    summary_rows+=("| $instruction | $section | $effect | $recommendation |")
    detail_sections+=("$(generate_comparison "$id" "$i")")
  done

  # Write report
  {
    echo "# CLAUDE.md A/B Test Report"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Instruction | Section | Effect | Recommendation |"
    echo "| ----------- | ------- | ------ | -------------- |"
    for row in "${summary_rows[@]}"; do
      echo "$row"
    done
    echo ""
    echo "### Legend"
    echo ""
    echo "- **High**: Clear behavioral difference when instruction is removed"
    echo "- **Medium**: Some difference detected but inconsistent"
    echo "- **Low**: No measurable difference (instruction may be redundant with defaults)"
    echo ""
    echo "### Not Tested (require interactive/agentic mode)"
    echo ""
    echo "- Use plan mode first (line 12)"
    echo "- Match surrounding code style (line 19)"
    echo "- Never delete tests without asking (line 28)"
    echo "- On main? Branch before coding (line 32)"
    echo "- Before committing: lint, test, review (line 36)"
    echo ""
    echo "## Detailed Comparisons"
    for section in "${detail_sections[@]}"; do
      echo ""
      echo "$section"
    done
  } >"$REPORT"

  ok "Report written to: $REPORT"
  echo ""

  # Print summary to terminal
  printf "\n${BOLD}Summary:${NC}\n\n"
  printf "| %-55s | %-7s | %-17s |\n" "Instruction" "Effect" "Recommendation"
  printf "| %-55s | %-7s | %-17s |\n" "$(printf '%0.s-' {1..55})" "-------" "-----------------"

  for ((i = 0; i < num_instructions; i++)); do
    local id instruction
    id=$(jq -r ".[$i].id" "$DEFINITIONS")
    instruction=$(jq -r ".[$i].instruction" "$DEFINITIONS")

    local result
    result=$(score_instruction "$id" "$i")
    local effect="${result%%|*}"

    local recommendation color
    case "$effect" in
      High)
        recommendation="Keep"
        color="$GREEN"
        ;;
      Medium)
        recommendation="Review"
        color="$YELLOW"
        ;;
      Low)
        recommendation="Consider removing"
        color="$RED"
        ;;
      SKIP)
        recommendation="Re-run"
        color="$YELLOW"
        ;;
      *)
        recommendation="Manual review"
        color="$YELLOW"
        ;;
    esac

    printf "| %-55s | ${color}%-7s${NC} | %-17s |\n" "${instruction:0:55}" "$effect" "$recommendation"
  done
  echo ""
}

main "$@"
