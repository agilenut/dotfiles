#!/usr/bin/env bash
# Scheduled topgrade run tests. topgrade-daily runs against stubbed topgrade,
# gtimeout, claude, date, and osascript, with a fake HOME so zsh reads no real
# ~/.zshenv and nothing real is upgraded, logged, or notified.
# Captures end in `|| true`: the runner uses `set -e`, so a crashing script
# would otherwise abort the whole suite instead of failing its test.

TOPGRADE_DAILY="${HOME}/.local/bin/topgrade-daily"

test_topgrade_daily() {
  section "Scheduled topgrade run"

  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi
  if [ ! -x "$TOPGRADE_DAILY" ]; then
    fail "topgrade-daily not installed (or not executable) at $TOPGRADE_DAILY"
    return
  fi
  local plist="$HOME/Library/LaunchAgents/dotfiles.topgrade.plist"
  if [[ -f "$plist" ]] && [[ "$(plutil -extract Label raw -o - "$plist" 2>/dev/null)" = dotfiles.topgrade ]]; then
    pass "launchd plist installed at $plist"
  else
    fail "launchd plist missing or mislabeled at $plist (run \`chezmoi apply\`)"
  fi
  # Longer than the wrapper's 45s stop grace, so launchd never SIGKILLs the
  # wrapper before it has killed topgrade.
  local exit_timeout
  exit_timeout=$(plutil -extract ExitTimeOut raw -o - "$plist" 2>/dev/null || echo 0)
  if [ "$exit_timeout" -gt 45 ]; then
    pass "launchd waits ${exit_timeout}s before SIGKILL on stop"
  else
    fail "plist ExitTimeOut must exceed the wrapper's 45s stop grace (got: $exit_timeout)"
  fi

  local stubdir fakehome state logs calls notes
  stubdir=$(mktemp -d)
  fakehome="$stubdir/home"
  state="$stubdir/state/topgrade"
  logs="$fakehome/Library/Logs"
  calls="$stubdir/calls"
  notes="$stubdir/notifications"
  mkdir -p "$stubdir/bin" "$stubdir/config" "$logs"
  : >"$stubdir/config/topgrade.toml"

  # topgrade stub: a dry run prints $STUB_DRYRUN (by default the custom
  # command the real config defines) and exits $STUB_DRYRUN_RC; a real run
  # prints $STUB_OUTPUT, copies $STUB_DRIFT_AFTER over the drift state, and
  # exits $STUB_RC. With STUB_HANG it waits until stopped, logging the TERM.
  cat >"$stubdir/bin/topgrade" <<'STUB'
#!/bin/sh
printf 'topgrade %s\n' "$*" >>"$CALL_LOG"
case " $* " in
  *" --dry-run "*)
    printf '%s\n' "${STUB_DRYRUN-Dry running: zsh -c dotfiles-drift}"
    exit "${STUB_DRYRUN_RC:-0}"
    ;;
esac
if [ -n "$STUB_STUBBORN" ]; then
  trap '' TERM
  echo "topgrade running" >>"$CALL_LOG"
  sleep 31
fi
if [ -n "$STUB_HANG" ]; then
  sleep 10 &
  trap 'kill $!; echo "topgrade got TERM" >>"$CALL_LOG"; exit 143' TERM
  echo "topgrade running" >>"$CALL_LOG"
  wait
fi
[ -n "$STUB_OUTPUT" ] && cat "$STUB_OUTPUT"
[ -n "$STUB_DRIFT_AFTER" ] && cp "$STUB_DRIFT_AFTER" "$XDG_STATE_HOME/topgrade/drift"
exit "${STUB_RC:-0}"
STUB
  # gtimeout stub: STUB_TIMEOUT exits 124 as a timeout does; otherwise drops
  # the two option/duration args and runs the command in its own process
  # group, as the real gtimeout does.
  cat >"$stubdir/bin/gtimeout" <<'STUB'
#!/bin/sh
printf 'gtimeout %s\n' "$*" >>"$CALL_LOG"
[ -n "$STUB_TIMEOUT" ] && exit 124
shift 2
exec /usr/bin/perl -e 'setpgrp(0, 0); exec @ARGV or die' "$@"
STUB
  # claude stub: prints $STUB_CLAUDE_BEFORE the first time, then
  # $STUB_CLAUDE_AFTER.
  cat >"$stubdir/bin/claude" <<'STUB'
#!/bin/sh
if [ -e "$CLAUDE_SEEN" ]; then echo "$STUB_CLAUDE_AFTER"; else : >"$CLAUDE_SEEN"; echo "$STUB_CLAUDE_BEFORE"; fi
STUB
  # brew stub: `outdated` prints $STUB_OUTDATED (comma-separated casks), or
  # fails with STUB_BREW_FAIL.
  cat >"$stubdir/bin/brew" <<'STUB'
#!/bin/sh
printf 'brew %s\n' "$*" >>"$CALL_LOG"
[ -n "$STUB_BREW_FAIL" ] && exit 1
[ -n "$STUB_OUTDATED" ] && printf '%s\n' "$STUB_OUTDATED" | tr ',' '\n'
exit 0
STUB
  cat >"$stubdir/bin/date" <<'STUB'
#!/bin/sh
case "$1" in
  +%Y-%m-%d) echo "$STUB_DAY" ;;
  +%H) echo "$STUB_HOUR" ;;
  *) exec /bin/date "$@" ;;
esac
STUB
  # osascript stub: logs the title, message, and sound the script passes last.
  cat >"$stubdir/bin/osascript" <<'STUB'
#!/bin/sh
while [ $# -gt 3 ]; do shift; done
printf 'notify|%s|%s|%s\n' "$1" "$2" "$3" >>"$NOTIFY_LOG"
STUB
  chmod +x "$stubdir/bin/"*

  # 17.14.1 summary shape: a "―― <time> - Summary ――" header, then one
  # "<step>: <status>" line per step.
  printf '%s\n' '―― 05:00:01 - Brew ――' 'Error: download failed' \
    '―― 05:09:12 - Summary ――' 'Brew (ARM): FAILED' 'mise: OK' \
    'Brew Cask (ARM): FAILED' 'npm: IGNORED' >"$stubdir/out-failed"
  printf '%s\n' '―― 05:09:12 - Summary ――' 'Brew (ARM): OK' 'mise: OK' \
    'Brew Cask (ARM): OK' 'npm: OK' >"$stubdir/out-ok"

  reset_run() {
    rm -rf "$stubdir/state" "${logs:?}"/* "$stubdir/claude-seen"
    mkdir -p "$state"
    : >"$calls"
    : >"$notes"
  }
  # exec, so a backgrounded call's $! is the wrapper itself. Only call it in a
  # subshell: `$(run_daily)` or `run_daily &`.
  run_daily() {
    exec env -i HOME="$fakehome" PATH="$stubdir/bin:/usr/bin:/bin" \
      XDG_STATE_HOME="$stubdir/state" XDG_CONFIG_HOME="$stubdir/config" \
      CALL_LOG="$calls" NOTIFY_LOG="$notes" CLAUDE_SEEN="$stubdir/claude-seen" \
      STUB_DAY="${STUB_DAY:-2026-10-25}" STUB_HOUR="${STUB_HOUR:-06}" \
      STUB_CLAUDE_BEFORE="${STUB_CLAUDE_BEFORE:-2.1.1 (Claude Code)}" \
      STUB_CLAUDE_AFTER="${STUB_CLAUDE_AFTER:-2.1.1 (Claude Code)}" \
      ${STUB_OUTPUT+STUB_OUTPUT="$STUB_OUTPUT"} ${STUB_RC+STUB_RC="$STUB_RC"} \
      ${STUB_TIMEOUT+STUB_TIMEOUT="$STUB_TIMEOUT"} ${STUB_DRYRUN+STUB_DRYRUN="$STUB_DRYRUN"} \
      ${STUB_DRYRUN_RC+STUB_DRYRUN_RC="$STUB_DRYRUN_RC"} ${STUB_HANG+STUB_HANG="$STUB_HANG"} \
      ${STUB_STUBBORN+STUB_STUBBORN="$STUB_STUBBORN"} \
      ${STUB_OUTDATED+STUB_OUTDATED="$STUB_OUTDATED"} ${STUB_BREW_FAIL+STUB_BREW_FAIL="$STUB_BREW_FAIL"} \
      ${TOPGRADE_DAILY_STOP_GRACE+TOPGRADE_DAILY_STOP_GRACE="$TOPGRADE_DAILY_STOP_GRACE"} \
      ${STUB_DRIFT_AFTER+STUB_DRIFT_AFTER="$STUB_DRIFT_AFTER"} \
      "$TOPGRADE_DAILY" 2>&1
  }
  ran_topgrade() { grep -q '^gtimeout ' "$calls"; }

  # A PID whose process has exited: the owner of a lock a killed run left.
  local rc out dead
  sh -c 'exit 0' &
  dead=$!
  wait "$dead"

  # ---- gates: nothing runs ----
  reset_run
  echo 2026-10-25 >"$state/last-day"
  rc=0
  out=$(run_daily) || rc=$?
  if [ "$rc" -eq 0 ] && ! ran_topgrade; then
    pass "already ran today: exits without running topgrade"
  else
    fail "ran despite today's stamp (rc=$rc, calls: $(tr '\n' '|' <"$calls"))"
  fi

  reset_run
  rc=0
  out=$(STUB_HOUR=04 run_daily) || rc=$?
  if [ "$rc" -eq 0 ] && ! ran_topgrade && [ ! -e "$state/last-day" ]; then
    pass "before 05:00: waits for a later hourly fire"
  else
    fail "ran before 05:00 (rc=$rc)"
  fi

  # The test runner is a live owner for held locks.
  reset_run
  mkdir "$logs/recap-daily.lock"
  echo $$ >"$logs/recap-daily.lock/pid"
  rc=0
  out=$(run_daily) || rc=$?
  if [ "$rc" -eq 0 ] && ! ran_topgrade && [ ! -e "$state/last-day" ]; then
    pass "recap running: skips this hour without marking the day"
  else
    fail "ran while recap held its lock (rc=$rc)"
  fi
  echo "$dead" >"$logs/recap-daily.lock/pid"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" run_daily) || rc=$?
  if ran_topgrade; then
    pass "a recap lock left by a killed recap doesn't block the run"
  else
    fail "stale recap lock blocked the run (rc=$rc)"
  fi
  rm -rf "$logs/recap-daily.lock"

  reset_run
  mkdir "$logs/topgrade.lock"
  echo $$ >"$logs/topgrade.lock/pid"
  rc=0
  out=$(run_daily) || rc=$?
  if [ "$rc" -eq 0 ] && ! ran_topgrade && [ -d "$logs/topgrade.lock" ]; then
    pass "another update holds the lock: skips this hour"
  else
    fail "ran while the lock was held (rc=$rc)"
  fi

  # A lock left by a killed run would otherwise block every later day.
  echo "$dead" >"$logs/topgrade.lock/pid"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" run_daily) || rc=$?
  if ran_topgrade && [ ! -e "$logs/topgrade.lock" ]; then
    pass "a lock whose owner is gone is cleared and the run goes ahead"
  else
    fail "stale lock not cleared (rc=$rc, out: $out)"
  fi

  # ---- config not loaded: never run unattended without it ----
  reset_run
  rc=0
  out=$(STUB_DRYRUN="" run_daily) || rc=$?
  if [ "$rc" -ne 0 ] && ! ran_topgrade && grep -q 'config' "$state/failed" 2>/dev/null \
    && grep -q 'Update failed' "$notes"; then
    pass "config not loaded: fails and notifies without running topgrade"
  else
    fail "config check wrong (rc=$rc, failed: $(cat "$state/failed" 2>/dev/null))"
  fi

  reset_run
  rc=0
  out=$(STUB_DRYRUN_RC=101 run_daily) || rc=$?
  if [ "$rc" -ne 0 ] && ! ran_topgrade && grep -q 'dry run failed' "$state/failed" 2>/dev/null; then
    pass "a failing dry run is reported as such, not as a missing config"
  else
    fail "dry-run failure wrong (rc=$rc, failed: $(cat "$state/failed" 2>/dev/null))"
  fi

  # ---- success ----
  reset_run
  echo stale >"$state/failed"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" run_daily) || rc=$?
  local args
  args=$(grep '^gtimeout ' "$calls")
  if [ "$rc" -eq 0 ] && [ "$(cat "$state/last-day")" = 2026-10-25 ] \
    && [ ! -e "$state/failed" ] && [ ! -e "$logs/topgrade.lock" ] && [ ! -s "$notes" ] \
    && [ ! -e "$state/claude-upgrade" ]; then
    pass "success: marks the day, clears an old failure, releases the lock, no notification"
  else
    fail "success run wrong (rc=$rc, notes: $(cat "$notes"), out: $out)"
  fi
  if grep -q -- '--disable system mas brew_cask shell tmux vim' <<<"$args" \
    && grep -q -- '--no-ask-retry' <<<"$args" && grep -q -- '--notify-end never' <<<"$args" \
    && grep -q -- '--yes' <<<"$args" && grep -q -- "--config $stubdir/config/topgrade.toml" <<<"$args"; then
    pass "runs topgrade unattended with the scheduled-run flags"
  else
    fail "topgrade flags wrong: $args"
  fi
  if grep -q 'Brew (ARM): OK' "$logs/topgrade-daily-2026-10-25.log" 2>/dev/null \
    && [ "$(cat "$state/last-log")" = "$logs/topgrade-daily-2026-10-25.log" ]; then
    pass "output goes to the day's log, and its path to state"
  else
    fail "day log or last-log wrong"
  fi
  if [ "$(cat "$state/steps-known" 2>/dev/null)" = "$(printf '%s\n' 'Brew (ARM)' 'Brew Cask (ARM)' mise npm)" ] \
    && [ ! -s "$state/new-steps" ]; then
    pass "first run records the step list without calling every step new"
  else
    fail "first-run step state wrong: known '$(tr '\n' ',' <"$state/steps-known" 2>/dev/null)'"
  fi

  # ---- failures ----
  reset_run
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-failed" STUB_RC=1 run_daily) || rc=$?
  if [ "$rc" -ne 0 ] && [ "$(cat "$state/failed")" = "$(printf '%s\n' 'Brew (ARM)' 'Brew Cask (ARM)')" ] \
    && [ "$(cat "$state/last-day")" = 2026-10-25 ]; then
    pass "failure: records the failed steps (not ignored ones) and still marks the day"
  else
    fail "failure state wrong (rc=$rc): '$(tr '\n' ',' <"$state/failed" 2>/dev/null)'"
  fi
  if grep -Fqx 'notify|Update failed|Brew (ARM), Brew Cask (ARM). Log: ~/Library/Logs/topgrade-daily-2026-10-25.log|Basso' "$notes"; then
    pass "failure notification names the steps and the day's log, with a sound"
  else
    fail "failure notification wrong: $(cat "$notes")"
  fi

  reset_run
  : >"$stubdir/out-empty"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-empty" STUB_RC=1 run_daily) || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'see log' "$state/failed" 2>/dev/null; then
    pass "failure with no summary: falls back to 'see log'"
  else
    fail "no-summary failure wrong: '$(cat "$state/failed" 2>/dev/null)'"
  fi

  reset_run
  printf '%s\n' mise >"$state/steps-known"
  printf '%s\n' npm >"$state/new-steps"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-empty" STUB_RC=1 run_daily) || rc=$?
  if [ -f "$state/new-steps" ] && [ ! -s "$state/new-steps" ]; then
    pass "a run with no summary clears the previous run's new steps"
  else
    fail "new-steps carried over: '$(tr '\n' ',' <"$state/new-steps" 2>/dev/null)'"
  fi

  # ---- stopped mid-run (a launchd reload): topgrade stops too ----
  reset_run
  local pid tries=0
  STUB_HANG=1 run_daily >/dev/null &
  pid=$!
  until grep -q '^topgrade running' "$calls" || [ "$tries" -ge 10 ]; do
    sleep 0.2
    tries=$((tries + 1))
  done
  local stop_started=$SECONDS
  kill -TERM "$pid"
  rc=0
  wait "$pid" || rc=$?
  # topgrade stops at once here, so the wrapper must not sit out the 45s
  # grace before exiting.
  if [ "$rc" -eq 143 ] && [ $((SECONDS - stop_started)) -lt 10 ] \
    && grep -q '^topgrade got TERM' "$calls" \
    && [ ! -e "$logs/topgrade.lock" ] && [ ! -e "$state/last-day" ]; then
    pass "TERM stops topgrade, releases the lock, and leaves the day for a retry"
  else
    fail "stop handling wrong (rc=$rc, calls: $(tr '\n' '|' <"$calls"))"
  fi

  # A topgrade that ignores TERM is killed with its whole process group after
  # the grace period, before launchd would SIGKILL the wrapper alone.
  reset_run
  tries=0
  STUB_STUBBORN=1 TOPGRADE_DAILY_STOP_GRACE=1 run_daily >/dev/null &
  pid=$!
  until grep -q '^topgrade running' "$calls" || [ "$tries" -ge 10 ]; do
    sleep 0.2
    tries=$((tries + 1))
  done
  local started=$SECONDS
  kill -TERM "$pid"
  rc=0
  wait "$pid" || rc=$?
  # Without the group kill the wrapper would wait out the stub's 31s sleep.
  if [ "$rc" -eq 143 ] && [ $((SECONDS - started)) -lt 10 ] \
    && ! pgrep -f 'sleep 31' >/dev/null && [ ! -e "$logs/topgrade.lock" ]; then
    pass "a topgrade that ignores TERM is killed with its children after the grace period"
  else
    fail "stubborn topgrade survived the stop (rc=$rc, sleep 31 running: $(pgrep -f 'sleep 31' || echo no))"
    pkill -f 'sleep 31' || true
  fi

  reset_run
  rc=0
  out=$(STUB_TIMEOUT=1 run_daily) || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'timed out' "$state/failed" 2>/dev/null; then
    pass "timeout counts as a failure"
  else
    fail "timeout not recorded: '$(cat "$state/failed" 2>/dev/null)'"
  fi

  # ---- notices ----
  # Casks are skipped (they can prompt for sudo) but counted.
  reset_run
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" STUB_OUTDATED="visual-studio-code,warp" run_daily) || rc=$?
  if [ "$(cat "$state/outdated-casks" 2>/dev/null)" = "$(printf '%s\n' visual-studio-code warp)" ] \
    && grep -Fqx 'brew outdated --cask --quiet' "$calls"; then
    pass "casks waiting for update are recorded"
  else
    fail "outdated-casks wrong: '$(tr '\n' ',' <"$state/outdated-casks" 2>/dev/null)'"
  fi
  rm "$state/last-day"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" STUB_BREW_FAIL=1 run_daily) || rc=$?
  if [ "$(wc -l <"$state/outdated-casks" | tr -d ' ')" = 2 ] && [ "$rc" -eq 0 ]; then
    pass "a failing brew outdated keeps the last list and doesn't fail the run"
  else
    fail "brew failure handling wrong (rc=$rc)"
  fi
  rm "$state/last-day"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" run_daily) || rc=$?
  if [ -f "$state/outdated-casks" ] && [ ! -s "$state/outdated-casks" ]; then
    pass "no outdated casks empties the list"
  else
    fail "outdated-casks not emptied: '$(tr '\n' ',' <"$state/outdated-casks")'"
  fi

  reset_run
  printf '%s\n' 'Brew (ARM)' mise >"$state/steps-known"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" run_daily) || rc=$?
  if [ "$(cat "$state/new-steps")" = "$(printf '%s\n' 'Brew Cask (ARM)' npm)" ] \
    && grep -Fqx 'npm' "$state/steps-known"; then
    pass "a step seen for the first time is recorded as new"
  else
    fail "new-step state wrong: '$(tr '\n' ',' <"$state/new-steps" 2>/dev/null)'"
  fi

  reset_run
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" STUB_CLAUDE_AFTER="2.1.2 (Claude Code)" run_daily) || rc=$?
  if [ "$(cat "$state/claude-upgrade" 2>/dev/null)" = "2.1.1 → 2.1.2" ]; then
    pass "a Claude Code upgrade is recorded old → new"
  else
    fail "claude-upgrade wrong: '$(cat "$state/claude-upgrade" 2>/dev/null)'"
  fi

  # Sessions not yet refreshed still run the first old version.
  reset_run
  echo '2.1.0 → 2.1.1' >"$state/claude-upgrade"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" STUB_CLAUDE_AFTER="2.1.2 (Claude Code)" run_daily) || rc=$?
  if [ "$(cat "$state/claude-upgrade" 2>/dev/null)" = "2.1.0 → 2.1.2" ]; then
    pass "a second upgrade before claude-refresh keeps the oldest version"
  else
    fail "second upgrade wrong: '$(cat "$state/claude-upgrade" 2>/dev/null)'"
  fi

  reset_run
  printf '%s\n' .config/a >"$state/drift"
  printf '%s\n' .config/a .config/b >"$stubdir/drift-after"
  rc=0
  out=$(STUB_OUTPUT="$stubdir/out-ok" STUB_DRIFT_AFTER="$stubdir/drift-after" run_daily) || rc=$?
  if [ "$(cat "$notes")" = 'notify|Dotfiles drift|~/.config/b|' ]; then
    pass "a newly drifted file gets one silent notification naming only it"
  else
    fail "drift notification wrong: $(cat "$notes")"
  fi

  rm -rf "$stubdir"
}
