#!/usr/bin/env bash
# Claude tmux session-restore wrapper tests
# shellcheck shell=bash

CLAUDE_RESTORE="${HOME}/.local/bin/claude-restore"

# Asserts the claude-restore title-parse contract. The send-keys delivery and
# real tmux-resurrect restore paths are inherently interactive — they live in
# the manual checklist; here we cover the parse/classify branches only.
test_claude_restore() {
  section "Claude tmux session restore"

  if [ ! -f "$CLAUDE_RESTORE" ]; then
    skip "claude-restore not installed"
    return
  fi

  # Run each assertion in its own subshell so the sourced functions don't leak
  # into the test runner; do pass/fail in the parent so the counters update.
  local result

  # ---- named session → resume with the name ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify '⠐ restart')
  if [ "$result" = "$(printf 'resume\trestart')" ]; then
    pass "named title resumes the session name"
  else
    fail "named title misparsed: '$result'"
  fi

  # ---- idle glyph (✳) resumes the same way as the spinner ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify '✳ images3')
  if [ "$result" = "$(printf 'resume\timages3')" ]; then
    pass "idle-glyph title resumes the session name"
  else
    fail "idle-glyph title misparsed: '$result'"
  fi

  # ---- session name with spaces is preserved whole ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify '⠐ my feature work')
  if [ "$result" = "$(printf 'resume\tmy feature work')" ]; then
    pass "spaced session name preserved whole"
  else
    fail "spaced name misparsed: '$result'"
  fi

  # ---- unnamed sentinel → leave the shell ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify '⠂ Claude Code')
  if [ "$result" = "shell" ]; then
    pass "unnamed 'Claude Code' leaves the shell"
  else
    fail "unnamed sentinel should leave shell: '$result'"
  fi

  # ---- no glyph, single word → leave the shell ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify 'zsh')
  if [ "$result" = "shell" ]; then
    pass "no-glyph single word leaves the shell"
  else
    fail "no-glyph word should leave shell: '$result'"
  fi

  # ---- arbitrary manual title (ASCII words) → leave the shell ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify 'my notes here')
  if [ "$result" = "shell" ]; then
    pass "manual ASCII title leaves the shell"
  else
    fail "manual title should leave shell: '$result'"
  fi

  # ---- empty title → leave the shell ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify '')
  if [ "$result" = "shell" ]; then
    pass "empty title leaves the shell"
  else
    fail "empty title should leave shell: '$result'"
  fi

  # ---- glyph with empty remainder → leave the shell ----
  # shellcheck source=/dev/null
  result=$(source "$CLAUDE_RESTORE" && claude_restore_classify '⠐ ')
  if [ "$result" = "shell" ]; then
    pass "glyph with empty name leaves the shell"
  else
    fail "glyph + empty remainder should leave shell: '$result'"
  fi
}
