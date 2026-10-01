#!/usr/bin/env bash
# Claude tmux wrapper tests (restore + refresh)
# shellcheck shell=bash

CLAUDE_RESTORE="${HOME}/.local/bin/claude-restore"
CLAUDE_REFRESH="${HOME}/.local/bin/claude-refresh"

# Asserts the claude-restore title-parse contract, plus the tmux.conf options
# the replay depends on. The send-keys delivery and real tmux-resurrect restore
# paths are inherently interactive, so they live in the manual checklist.
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

# Asserts the guard that keeps claude's pane title readable by claude-restore.
# oh-my-zsh's termsupport writes the pane title (OSC 2) from every precmd under
# TERM=tmux-*, which erases the `<glyph> <session>` title resurrect restored -
# every pane then classifies as "shell" and no session resumes. The failure is
# silent, and the guard is a $TMUX-conditional assignment, so assert the derived
# value rather than the text: only running it proves the condition's direction.
test_claude_pane_title() {
  section "Claude tmux pane title guard"

  local tmux_zsh="${ZDOTDIR:-$HOME/.config/zsh}/zshrc.d/tmux.zsh"
  if [ ! -f "$tmux_zsh" ]; then
    skip "zshrc.d/tmux.zsh not installed"
    return
  fi

  # Source the guard in a non-interactive zsh and print what it derived. The
  # auto-attach block in the same file needs `[[ -o interactive ]]`, false under
  # `zsh -c`, so sourcing can't launch tmux.
  #   $1 = value for $TMUX (empty to unset it)
  derive_auto_title() {
    local -a env_args=(-u TMUX)
    [ -n "$1" ] && env_args=("TMUX=$1")
    env "${env_args[@]}" zsh -c \
      "source '$tmux_zsh'; print -r -- \${DISABLE_AUTO_TITLE:-unset}"
  }

  local result

  # ---- inside tmux: auto-title off, so claude's pane title survives ----
  result="$(derive_auto_title fake)"
  if [ "$result" = "true" ]; then
    pass "inside tmux: oh-my-zsh auto-title disabled"
  else
    fail "inside tmux: DISABLE_AUTO_TITLE is '$result' (pane titles clobbered, silent resume break)"
  fi

  # ---- outside tmux: left alone, so a bare Alacritty still gets a title ----
  result="$(derive_auto_title "")"
  if [ "$result" = "unset" ]; then
    pass "outside tmux: auto-title left alone"
  else
    fail "outside tmux: DISABLE_AUTO_TITLE is '$result' (should be unset)"
  fi
}

# Asserts claude-refresh's pane-listing → action mapping. The send-keys
# exit/resume delivery is inherently interactive, so verify live by running
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
  # command substitution: that subshell keeps the sourced functions from
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

  # ---- the TCC prune runs after the refresh, and cannot mask its status ----
  # These execute the script rather than sourcing it, because the prune call
  # lives in the direct-run guard.
  #
  # HOME is redirected for every case. The script appends
  # `$HOME/.local/bin:/opt/homebrew/bin` to PATH, so a stub on a prepended PATH
  # wins for resolution but does NOT stop the installed claude-tcc-prune being
  # found when the stub is absent. Without a fake HOME the "not installed" case
  # runs the real prune against the real TCC database, and `killall tccd` is
  # skipped only when CLAUDE_TCC_DB is set. It passes on a machine without Full
  # Disk Access and deletes rows on one with it.
  local stubdir fakehome log rc out
  stubdir=$(mktemp -d)
  fakehome="$stubdir/home"
  log="$stubdir/calls"
  mkdir -p "$fakehome/.local/bin"

  # tmux stub: logs the subcommand, reports one named claude pane, and returns
  # empty for display-message so the pane reads as vanished. That reaches the
  # restart path (no other test does) and makes the refresh exit non-zero,
  # which is what lets the ordering and status assertions below mean something.
  cat >"$stubdir/tmux" <<'TMUXSTUB'
#!/bin/sh
printf 'tmux %s\n' "$1" >>"$CALL_LOG"
case "$1" in
  list-panes) printf '%%9\tclaude\t/tmp\t✳ probe\n' ;;
  *) : ;;
esac
exit 0
TMUXSTUB
  printf '#!/bin/sh\nprintf "prune %%s\\n" "$*" >>"$CALL_LOG"\nexit 0\n' >"$stubdir/claude-tcc-prune"
  chmod +x "$stubdir/tmux" "$stubdir/claude-tcc-prune"

  : >"$log"
  rc=0
  PATH="$stubdir:/usr/bin:/bin" HOME="$fakehome" CALL_LOG="$log" \
    CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE" \
    bash "$CLAUDE_REFRESH" >/dev/null 2>&1 || rc=$?

  if grep -q '^prune --quiet$' "$log"; then
    pass "refresh invokes claude-tcc-prune --quiet"
  else
    fail "prune not invoked with --quiet (log: $(tr '\n' ' ' <"$log"))"
  fi
  # The ordering is the entire point of the change: before the refresh the
  # old-version processes still hold their TCC rows and the prune spares them.
  if [ "$(tail -1 "$log")" = "prune --quiet" ] && grep -q '^tmux send-keys$' "$log"; then
    pass "prune runs after the panes are restarted, not before"
  else
    fail "prune must be the last step (log: $(tr '\n' ' ' <"$log"))"
  fi
  # A pane that vanished makes the refresh itself fail; the status must survive.
  if [ "$rc" -ne 0 ]; then
    pass "a failing refresh still reports its own non-zero status"
  else
    fail "refresh should have failed on a vanished pane (got: $rc)"
  fi

  # A prune that fails (no Full Disk Access is the usual case) must not change
  # the refresh's status in either direction.
  printf '#!/bin/sh\nexit 1\n' >"$stubdir/claude-tcc-prune"
  chmod +x "$stubdir/claude-tcc-prune"
  cat >"$stubdir/tmux" <<'TMUXOK'
#!/bin/sh
exit 0
TMUXOK
  chmod +x "$stubdir/tmux"
  rc=0
  PATH="$stubdir:/usr/bin:/bin" HOME="$fakehome" CALL_LOG="$log" \
    CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE" \
    bash "$CLAUDE_REFRESH" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "a failing prune does not turn a clean refresh into a failure"
  else
    fail "prune failure leaked into the exit status (got: $rc)"
  fi

  # No prune anywhere is not an error, and must stay silent: `|| true` absorbs
  # a 127 either way, so the guard is only observable on stderr.
  rm -f "$stubdir/claude-tcc-prune"
  rc=0
  out=$(PATH="$stubdir:/usr/bin:/bin" HOME="$fakehome" CALL_LOG="$log" \
    CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE" \
    bash "$CLAUDE_REFRESH" 2>&1 >/dev/null) || rc=$?
  if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'claude-tcc-prune'; then
    pass "a missing prune is skipped by the guard, with nothing on stderr"
  else
    fail "missing prune should be silently skipped (rc=$rc, stderr: '$out')"
  fi

  # The refresh summary must stay the last line on stdout: Raycast compact mode
  # shows only that line, and the prune prints when it removes rows. Needs the
  # pane-reporting tmux stub, so the summary is the "Restarted ..." counter line
  # rather than the no-panes notice.
  printf '#!/bin/sh\necho "claude-tcc-prune: removed 1 orphaned claude-code TCC entry"\nexit 0\n' \
    >"$stubdir/claude-tcc-prune"
  cat >"$stubdir/tmux" <<'TMUXPANE'
#!/bin/sh
case "$1" in
  list-panes) printf '%%9\tclaude\t/tmp\t✳ probe\n' ;;
  *) : ;;
esac
exit 0
TMUXPANE
  chmod +x "$stubdir/claude-tcc-prune" "$stubdir/tmux"
  # `|| true`: the refresh exits non-zero here (the stub pane reads as
  # vanished) and the runner sets -e, so an unguarded substitution would abort
  # the suite rather than reach the assertion.
  out=$(PATH="$stubdir:/usr/bin:/bin" HOME="$fakehome" CALL_LOG="$log" \
    CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE" \
    bash "$CLAUDE_REFRESH" 2>/dev/null | tail -1) || true
  case "$out" in
    Restarted*) pass "refresh summary stays the last line on stdout" ;;
    *) fail "prune output displaced the summary (last stdout line: '$out')" ;;
  esac

  # ---- stuck pane: the log has to say what it was stuck on ----
  # Raycast compact mode shows only the summary line, so before the log existed
  # a timeout reported that a pane didn't exit and nothing about why. The usual
  # why is a permission prompt, which eats the exit keys. The stub never lets
  # display-message report anything but `claude`, which is the only way to reach
  # the timeout branch; CLAUDE_REFRESH_EXIT_TIMEOUT keeps that from taking 30s.
  local reflog
  reflog="$stubdir/refresh.log"
  rm -f "$stubdir/claude-tcc-prune"
  cat >"$stubdir/tmux" <<'TMUXSTUCK'
#!/bin/sh
case "$1" in
  list-panes) printf '%%9\tclaude\t/tmp\t✳ probe\n' ;;
  display-message) printf 'claude\n' ;;
  capture-pane) printf '\n> 1. Yes\n\nDo you want to commit these changes?\n' ;;
  *) : ;;
esac
exit 0
TMUXSTUCK
  chmod +x "$stubdir/tmux"
  out=$(PATH="$stubdir:/usr/bin:/bin" HOME="$fakehome" CALL_LOG="$log" \
    CLAUDE_REFRESH_LOG="$reflog" CLAUDE_REFRESH_EXIT_TIMEOUT=1 \
    CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE" \
    bash "$CLAUDE_REFRESH" 2>/dev/null | tail -1) || true

  if grep -qF 'Do you want to commit these changes?' "$reflog"; then
    pass "a stuck pane's screen is captured into the log"
  else
    fail "timeout capture missing from the log (log: $(tr '\n' ' ' <"$reflog"))"
  fi
  # Exactly the two non-blank lines the stub pane shows. Asserting the count
  # rather than the absence of blanks keeps this from passing vacuously if the
  # capture stops being written at all - a real pane is mostly blank, and those
  # blanks would otherwise push the content out of the tail window.
  if [ "$(grep -c '^  | ' "$reflog")" -eq 2 ]; then
    pass "capture keeps the pane's content and drops its blank lines"
  else
    fail "capture should hold 2 content lines (log: $(tr '\n' ' ' <"$reflog"))"
  fi
  # The summary is all Raycast shows, so on a failure it must name the log.
  case "$out" in
    "Restarted 0, skipped 0, failed 1. Detail: $reflog")
      pass "a failing summary points at the log"
      ;;
    *) fail "summary should name the log on failure (got: '$out')" ;;
  esac

  # A clean run must not advertise a log nobody needs to read.
  cat >"$stubdir/tmux" <<'TMUXCLEAN'
#!/bin/sh
case "$1" in
  list-panes) printf '%%9\tclaude\t/tmp\t✳ probe\n' ;;
  display-message) printf 'zsh\n' ;;
  *) : ;;
esac
exit 0
TMUXCLEAN
  chmod +x "$stubdir/tmux"
  out=$(PATH="$stubdir:/usr/bin:/bin" HOME="$fakehome" CALL_LOG="$log" \
    CLAUDE_REFRESH_LOG="$reflog" CLAUDE_REFRESH_EXIT_TIMEOUT=1 \
    CLAUDE_RESTORE_BIN="$CLAUDE_RESTORE" \
    bash "$CLAUDE_REFRESH" 2>/dev/null | tail -1) || true
  if [ "$out" = "Restarted 1, skipped 0, failed 0." ]; then
    pass "a clean summary stays bare"
  else
    fail "clean summary should not name the log (got: '$out')"
  fi
  # Truncated per run: stale detail from an earlier failure reads as current.
  if ! grep -qF 'Do you want to commit these changes?' "$reflog"; then
    pass "the log is truncated at the start of each run"
  else
    fail "previous run's capture survived into a new run"
  fi

  rm -rf "$stubdir"
}
