#!/usr/bin/env bash
# Interactive manual tests

manual_test() {
  local description="$1"
  local instruction="$2"

  echo ""
  echo -e "${BOLD}TEST:${RESET} $description"
  echo -e "${BLUE}→${RESET} $instruction"
  echo ""

  local response
  while true; do
    read -r -p "Result? [p]ass / [f]ail / [s]kip: " response
    case "$response" in
      p | P | pass)
        ((MANUAL_PASSED++))
        echo -e "  ${GREEN}✓${RESET} Passed"
        break
        ;;
      f | F | fail)
        ((MANUAL_FAILED++))
        echo -e "  ${RED}✗${RESET} Failed"
        break
        ;;
      s | S | skip)
        ((MANUAL_SKIPPED++))
        echo -e "  ${YELLOW}○${RESET} Skipped"
        break
        ;;
      *)
        echo "Please enter p, f, or s"
        ;;
    esac
  done
}

run_manual_tests() {
  MANUAL_PASSED=0
  MANUAL_FAILED=0
  MANUAL_SKIPPED=0

  echo ""
  echo "================================================================================"
  echo -e "${BOLD}                    INTERACTIVE MANUAL TESTS${RESET}"
  echo "================================================================================"
  echo ""
  echo "For each test, try the action in your terminal and report the result."
  echo "Press Enter after each response to continue."

  # Completions
  echo ""
  echo -e "${BOLD}── COMPLETIONS ──${RESET}"

  manual_test "fzf-tab completion" \
    "Type 'git c<TAB>' - fzf menu should appear with clone, commit, checkout, etc."

  manual_test "Change directory completion" \
    "Type 'cd ~/<TAB>' - fzf menu should show directories (TAB triggers fzf)"

  manual_test "Change directory wildcard completion" \
    "Type 'cd **' - fzf menu should show directories (TAB triggers fzf)"

  manual_test "Move wildcard completion" \
    "Type 'cp **' - fzf menu should show files (TAB triggers fzf)"

  manual_test "Flag completion" \
    "Type 'ls -<TAB>' - completion menu should show ls/eza flags"

  # FZF Keybindings
  echo ""
  echo -e "${BOLD}── FZF KEYBINDINGS ──${RESET}"

  manual_test "CTRL-T file picker" \
    "Press CTRL-T - file picker with preview (? toggles, CTRL-F/B scrolls preview)"

  manual_test "CTRL-R history search" \
    "Press CTRL-R - history search should appear with command preview"

  # Colors
  echo ""
  echo -e "${BOLD}── COLORS ──${RESET}"

  manual_test "eza/ls colors" \
    "Run 'ls' or 'eza' - directories blue, executables green/red"

  manual_test "bat syntax highlighting" \
    "Run 'bat ~/.zshrc' - syntax highlighting should appear"

  manual_test "Prompt colors" \
    "Check prompt - path blue, git branch green, prompt char cyan"

  # Prompt Behavior
  echo ""
  echo -e "${BOLD}── PROMPT BEHAVIOR ──${RESET}"

  manual_test "Git status in prompt" \
    "cd into a git repo - branch and status indicators should appear"

  manual_test "Error status indicator" \
    "Run 'false' - the NEXT prompt's ❯ should be pink (not teal). Type something without running to see it."

  manual_test "Execution time" \
    "Run 'sleep 1' - execution time should appear on right side"

  # Zoxide
  echo ""
  echo -e "${BOLD}── ZOXIDE ──${RESET}"

  manual_test "Zoxide jump" \
    "Type 'cd' + partial path you've visited before (e.g., 'cd Dow' for Downloads) - should fuzzy-match and jump"

  manual_test "Zoxide interactive" \
    "Type 'cdi' - interactive directory selection should appear"

  # Autosuggestions
  echo ""
  echo -e "${BOLD}── AUTOSUGGESTIONS ──${RESET}"

  manual_test "Command suggestions" \
    "Start typing a previous command - grey suggestion should appear"

  manual_test "Accept suggestion" \
    "Press right arrow or END to accept the grey suggestion"

  # Syntax Highlighting
  echo ""
  echo -e "${BOLD}── SYNTAX HIGHLIGHTING ──${RESET}"

  manual_test "String highlighting" \
    "Type 'echo \"hello\"' (don't run) - string should be highlighted"

  manual_test "Invalid command" \
    "Type 'notarealcmd' (don't run) - should appear red"

  manual_test "Valid command" \
    "Type 'ls' (don't run) - should appear green"

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
