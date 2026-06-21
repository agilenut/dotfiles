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

  # ---- resurrect replay strategy (tmux.conf @resurrect-processes) ----
  local tmux_conf="${HOME}/.config/tmux/tmux.conf"
  if [ ! -f "$tmux_conf" ]; then
    skip "tmux.conf not installed"
    return
  fi

  # The claude entry must be wrapped in double quotes ("claude->claude-restore").
  # resurrect runs `eval set $(restore_list)`, so without the inner quotes the `>`
  # is parsed as a shell redirect and the match silently fails - panes never
  # replay. Match the double-quoted token regardless of what follows (other
  # entries like lazygit may trail it), since the failure mode is silent.
  if grep -qE '@resurrect-processes .*"claude->claude-restore"' "$tmux_conf"; then
    pass "resurrect strategy keeps embedded double quotes"
  else
    fail "resurrect strategy missing embedded double quotes (silent resume break)"
  fi

  # lazygit must be in the replay list so a full-pane lazygit reopens on its repo
  # (it's a plain word - resurrect re-runs it in the restored cwd, no wrapper).
  if grep -qE "@resurrect-processes .*\blazygit\b" "$tmux_conf"; then
    pass "resurrect replays lazygit panes"
  else
    fail "resurrect strategy missing lazygit (full-pane lazygit won't restore)"
  fi
}
