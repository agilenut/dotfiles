#!/usr/bin/env bash
# Claude tmux wrapper tests (restore + refresh)
# shellcheck shell=bash

CLAUDE_RESTORE="${HOME}/.local/bin/claude-restore"
CLAUDE_REFRESH="${HOME}/.local/bin/claude-refresh"

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

  # The post-restore-all hook signals cold-start launchers (tmux-coldstart) that
  # restore - and its end-of-restore switch-client - has finished. Guard the full
  # contract: the hook is present AND sets @restore-complete. A dropped hook or a
  # wrong option name silently reintroduces the launch race (no error, the client
  # just lands on the wrong session).
  if grep -qE '@resurrect-hook-post-restore-all .*@restore-complete' "$tmux_conf"; then
    pass "restore-complete hook signals cold-start launchers"
  else
    fail "missing @resurrect-hook-post-restore-all -> @restore-complete (cold-start race returns)"
  fi
}

# Asserts claude-refresh's pane-listing → action mapping. The send-keys
# exit/resume delivery is inherently interactive — verify live by running
# claude-refresh after a claude update; here we cover the plan branches only.
test_claude_refresh() {
  section "Claude tmux session refresh"

  if [ ! -f "$CLAUDE_REFRESH" ] || [ ! -f "$CLAUDE_RESTORE" ]; then
    skip "claude-refresh or claude-restore not installed"
    return
  fi

  # Runs claude_refresh_plan ($1 = invoking pane id) from a fresh source of
  # the installed script, with CLAUDE_RESTORE_BIN pinning the title parser to
  # the installed claude-restore instead of a PATH lookup. Only call inside a
  # command substitution — that subshell keeps the sourced functions from
  # leaking into the test runner; do pass/fail in the parent so the counters
  # update.
  refresh_plan() {
    export CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE"
    # shellcheck source=/dev/null
    source "$CLAUDE_REFRESH" && claude_refresh_plan "$1"
  }

  local result expected

  # ---- named claude pane → restart with the session name ----
  result=$(printf '%%3\tclaude\t/tmp\t✳ images4\n' | refresh_plan '')
  if [ "$result" = "$(printf 'restart\t%%3\timages4')" ]; then
    pass "named claude pane restarts with the session name"
  else
    fail "named pane misplanned: '$result'"
  fi

  # ---- session name with spaces survives the pipeline whole ----
  result=$(printf '%%3\tclaude\t/tmp\t⠐ my feature work\n' | refresh_plan '')
  if [ "$result" = "$(printf 'restart\t%%3\tmy feature work')" ]; then
    pass "spaced session name preserved whole"
  else
    fail "spaced name misplanned: '$result'"
  fi

  # ---- the invoking pane is never restarted ----
  result=$(printf '%%9\tclaude\t/tmp\t✳ voice\n' | refresh_plan '%9')
  if [ "$result" = "$(printf 'skip-self\t%%9')" ]; then
    pass "invoking pane is skipped"
  else
    fail "self pane misplanned: '$result'"
  fi

  # ---- deleted cwd (removed worktree) → left running, not stranded ----
  result=$(printf '%%6\tclaude\t/nonexistent/worktree-gone\t✳ images4\n' | refresh_plan '')
  if [ "$result" = "$(printf 'skip-cwd\t%%6\t/nonexistent/worktree-gone')" ]; then
    pass "deleted-cwd pane is left running"
  else
    fail "deleted-cwd pane misplanned: '$result'"
  fi

  # ---- unnamed session (default title) → left running ----
  result=$(printf '%%5\tclaude\t/tmp\t⠂ Claude Code\n' | refresh_plan '')
  if [ "$result" = "$(printf 'skip-unnamed\t%%5\t⠂ Claude Code')" ]; then
    pass "unnamed session is left running"
  else
    fail "unnamed pane misplanned: '$result'"
  fi

  # ---- non-claude panes emit nothing; mixed listing keeps order ----
  result=$(printf '%%1\tzsh\t/tmp\tsome title\n%%2\tclaude\t/tmp\t✳ reviews3\n%%3\tnvim\t/tmp\tMac.local\n%%4\tclaude\t/tmp\thostname.local\n' \
    | refresh_plan '')
  expected="$(printf 'restart\t%%2\treviews3\nskip-unnamed\t%%4\thostname.local')"
  if [ "$result" = "$expected" ]; then
    pass "non-claude panes ignored, claude panes planned in order"
  else
    fail "mixed listing misplanned: '$result'"
  fi
}
