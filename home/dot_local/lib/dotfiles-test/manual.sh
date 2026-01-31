#!/usr/bin/env bash
# Interactive manual tests with tmux-based inline testing

# =============================================================================
# TEST DEFINITIONS (name|instruction)
# =============================================================================

COMPLETIONS_TESTS=(
  "fzf-tab completion|git c<TAB> → fzf menu with clone, commit, etc."
  "cd completion|cd ~/<TAB> → fzf shows directories"
  "wildcard completion|cd **<TAB> → fzf shows directories"
  "cp wildcard|cp **<TAB> → fzf shows files"
  "flag completion|ls -<TAB> → shows ls/eza flags"
)

FZF_TESTS=(
  "CTRL-T file picker|CTRL-T → file picker with preview (? toggles)"
  "CTRL-R history|CTRL-R → history search with command preview"
)

COLORS_TESTS=(
  "eza/ls colors|ls or eza → directories blue, executables green/red"
  "bat highlighting|bat ~/.zshrc → syntax highlighting appears"
  "Prompt colors|path blue, git branch green, prompt char cyan"
)

PROMPT_TESTS=(
  "Git status|cd into git repo → branch and status indicators appear"
  "Error indicator|Run 'false' → next prompt's ❯ should be pink"
  "Execution time|Run 'sleep 1' → time should appear on right"
)

ZOXIDE_TESTS=(
  "Zoxide jump|cd + partial path (e.g., 'cd Dow') → fuzzy-match and jump"
  "Zoxide interactive|cdi → interactive directory selection"
)

AUTOSUGGESTIONS_TESTS=(
  "Command suggestions|Start typing previous command → grey suggestion appears"
  "Accept suggestion|Right arrow or END → accepts grey suggestion"
)

SYNTAX_TESTS=(
  "String highlighting|Type 'echo \"hello\"' (don't run) → string highlighted"
  "Invalid command|Type 'notarealcmd' (don't run) → appears red"
  "Valid command|Type 'ls' (don't run) → appears green"
)

# =============================================================================
# TMUX PANE MANAGEMENT
# =============================================================================

# Global variable for test pane
TEST_PANE_ID=""

# Create or reuse the test pane
setup_test_pane() {
  # Kill any existing test pane first
  cleanup_test_pane

  # Create new pane on the right
  TEST_PANE_ID=$(tmux split-window -h -d -P -F "#{pane_id}" "exec zsh -i")
}

# Clean up the test pane
cleanup_test_pane() {
  if [[ -n "$TEST_PANE_ID" ]]; then
    tmux kill-pane -t "$TEST_PANE_ID" 2>/dev/null || true
    TEST_PANE_ID=""
  fi
}

# Clear the test pane for next group (send clear command)
clear_test_pane() {
  if [[ -n "$TEST_PANE_ID" ]]; then
    tmux send-keys -t "$TEST_PANE_ID" "clear" Enter
  fi
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Validate result string (must be correct length with only p/f/s chars)
validate_results() {
  local result="$1"
  local expected_len="$2"

  # Check length
  if [[ ${#result} -ne $expected_len ]]; then
    return 1
  fi

  # Check each character
  local i
  for ((i = 0; i < ${#result}; i++)); do
    local char="${result:$i:1}"
    if [[ ! "$char" =~ ^[pPfFsS]$ ]]; then
      return 1
    fi
  done

  return 0
}

# Tally results from a result string like "pppfs"
tally_results() {
  local result="$1"
  local i char

  for ((i = 0; i < ${#result}; i++)); do
    char="${result:$i:1}"
    case "$char" in
      p | P) ((MANUAL_PASSED++)) ;;
      f | F) ((MANUAL_FAILED++)) ;;
      s | S) ((MANUAL_SKIPPED++)) ;;
    esac
  done
}

# Display tests in a group
display_tests() {
  local group_name="$1"
  shift
  local tests=("$@")

  echo ""
  echo -e "${BOLD}══ $group_name (${#tests[@]} tests) ══${RESET}"
  local i=1
  for test in "${tests[@]}"; do
    local name="${test%%|*}"
    local instruction="${test#*|}"
    echo -e "  ${i}. ${BOLD}$name${RESET}"
    echo -e "     ${BLUE}→${RESET} $instruction"
    ((i++))
  done
  echo ""
}

# Collect and validate results
collect_results() {
  local test_count="$1"
  local result

  while true; do
    read -rp "Results? (${test_count} chars, e.g. $(printf 'p%.0s' $(seq 1 "$test_count"))): " result
    if validate_results "$result" "$test_count"; then
      echo "$result"
      return 0
    fi
    echo -e "${RED}Enter exactly $test_count chars (p/f/s)${RESET}"
  done
}

# Show group summary
show_group_summary() {
  local group_name="$1"
  local result="$2"
  local test_count=${#result}
  local group_passed=0 group_failed=0 group_skipped=0

  for ((i = 0; i < ${#result}; i++)); do
    case "${result:$i:1}" in
      p | P) ((group_passed++)) ;;
      f | F) ((group_failed++)) ;;
      s | S) ((group_skipped++)) ;;
    esac
  done

  if [[ $group_failed -eq 0 ]]; then
    echo -e "${GREEN}✓ $group_name: $group_passed/$test_count passed${RESET}"
  else
    echo -e "${RED}✗ $group_name: $group_passed/$test_count passed ($group_failed failed)${RESET}"
  fi
}

# =============================================================================
# TMUX-BASED TEST RUNNER
# =============================================================================

run_test_group_tmux() {
  local group_name="$1"
  shift
  local tests=("$@")
  local test_count=${#tests[@]}

  # Clear the test pane for this group
  clear_test_pane

  # Display tests in left pane
  display_tests "$group_name" "${tests[@]}"

  echo -e "${DIM}Alt+Right → test pane | Alt+Left → return here${RESET}"
  echo -e "${DIM}Mouse copy: hold Shift while selecting${RESET}"
  echo "───────────────────────────────────────"

  # Collect results
  local result
  result=$(collect_results "$test_count")

  # Tally and show summary
  tally_results "$result"
  show_group_summary "$group_name" "$result"
}

# =============================================================================
# FALLBACK (NON-TMUX) RUNNER
# =============================================================================

run_test_group_fallback() {
  local group_name="$1"
  shift
  local tests=("$@")
  local test_count=${#tests[@]}

  # Display tests
  display_tests "$group_name" "${tests[@]}"

  echo "Opening interactive shell. Test the above, then type 'exit'."
  echo "───────────────────────────────────────"

  # Drop into interactive zsh
  zsh -i

  echo "───────────────────────────────────────"

  # Collect results
  local result
  result=$(collect_results "$test_count")

  # Tally and show summary
  tally_results "$result"
  show_group_summary "$group_name" "$result"
}

# =============================================================================
# MAIN RUNNER
# =============================================================================

run_manual_tests() {
  MANUAL_PASSED=0
  MANUAL_FAILED=0
  MANUAL_SKIPPED=0

  echo ""
  echo "================================================================================"
  echo -e "${BOLD}                    INTERACTIVE MANUAL TESTS${RESET}"
  echo "================================================================================"

  # Choose runner based on environment
  local runner="run_test_group_fallback"
  local using_tmux=false

  if [[ -n "${TMUX:-}" ]]; then
    runner="run_test_group_tmux"
    using_tmux=true
    echo ""
    echo "Running in tmux. Use Alt+Arrow to switch between panes."

    # Set up cleanup trap for tmux mode
    trap cleanup_test_pane EXIT INT TERM

    # Create the test pane once
    setup_test_pane
  else
    echo ""
    echo -e "${YELLOW}Tip: Run inside tmux for inline testing (tmux new-session)${RESET}"
    echo ""
    read -rp "Continue without tmux? [Y/n]: " response
    if [[ "$response" =~ ^[nN] ]]; then
      echo "Exiting. Start tmux and try again."
      return 0
    fi
  fi

  echo ""
  echo "For each group, test all items then enter results as a string."
  echo "Example: 'pppfs' = tests 1-3 pass, test 4 fails, test 5 skipped"

  # Run all test groups
  $runner "COMPLETIONS" "${COMPLETIONS_TESTS[@]}"
  $runner "FZF KEYBINDINGS" "${FZF_TESTS[@]}"
  $runner "COLORS" "${COLORS_TESTS[@]}"
  $runner "PROMPT BEHAVIOR" "${PROMPT_TESTS[@]}"
  $runner "ZOXIDE" "${ZOXIDE_TESTS[@]}"
  $runner "AUTOSUGGESTIONS" "${AUTOSUGGESTIONS_TESTS[@]}"
  $runner "SYNTAX HIGHLIGHTING" "${SYNTAX_TESTS[@]}"

  # Clean up tmux pane
  if [[ "$using_tmux" == true ]]; then
    cleanup_test_pane
    trap - EXIT INT TERM
  fi

  # Summary
  echo ""
  echo "================================================================================"
  local total=$((MANUAL_PASSED + MANUAL_FAILED + MANUAL_SKIPPED))
  if [[ $MANUAL_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}MANUAL RESULTS: $MANUAL_PASSED/$total passed${RESET}"
  else
    echo -e "${RED}${BOLD}MANUAL RESULTS: $MANUAL_PASSED/$total passed ($MANUAL_FAILED failed)${RESET}"
  fi
  if [[ $MANUAL_SKIPPED -gt 0 ]]; then
    echo -e "${YELLOW}($MANUAL_SKIPPED skipped)${RESET}"
  fi
  echo "================================================================================"
}
