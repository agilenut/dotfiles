#!/usr/bin/env bash
# launchd job reload tests. dotfiles-reload-launchd runs against a stub
# launchctl and a fixture LaunchAgents directory, so nothing real is loaded.
# Captures end in `|| true`: the runner uses `set -e`, so a crashing script
# would otherwise abort the whole suite instead of failing its test.

RELOAD_LAUNCHD="${HOME}/.local/bin/dotfiles-reload-launchd"

test_reload_launchd() {
  section "launchd job reload"

  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi
  if [ ! -f "$RELOAD_LAUNCHD" ]; then
    fail "dotfiles-reload-launchd not installed at $RELOAD_LAUNCHD"
    return
  fi

  local stubdir jobs_dir log rc out domain
  stubdir=$(mktemp -d)
  jobs_dir="$stubdir/LaunchAgents"
  log="$stubdir/calls"
  domain="gui/$(id -u)"
  mkdir -p "$jobs_dir"
  local label
  for label in dotfiles.alpha dotfiles.beta other.gamma; do
    plutil -create xml1 "$jobs_dir/$label.plist"
    plutil -insert Label -string "$label" "$jobs_dir/$label.plist"
  done

  # launchctl stub: logs every call. `print <domain>` fails with PRINT_FAIL
  # (no GUI session); `print <domain>/<label>` succeeds only for labels in
  # LOADED. BOOTOUT_FAIL and BOOTSTRAP_FAIL fail those commands for the
  # target they name.
  cat >"$stubdir/launchctl" <<'LAUNCHCTLSTUB'
#!/bin/sh
printf '%s\n' "$*" >>"$CALL_LOG"
case "$1 $2" in
  print\ gui/*/*) case " $LOADED " in *" ${2##*/} "*) exit 0 ;; *) exit 113 ;; esac ;;
  print\ *) [ -z "$PRINT_FAIL" ] ;;
  bootout\ *) [ "$2" != "$BOOTOUT_FAIL" ] ;;
  bootstrap\ *) [ "$3" != "$BOOTSTRAP_FAIL" ] ;;
esac
LAUNCHCTLSTUB
  chmod +x "$stubdir/launchctl"

  run_reload() {
    env -u CI PATH="$stubdir:$PATH" CALL_LOG="$log" \
      LAUNCH_AGENTS_DIR="$jobs_dir" "$@" bash "$RELOAD_LAUNCHD" 2>&1
  }

  # ---- CI: skip without touching launchd ----
  : >"$log"
  rc=0
  out=$(run_reload CI=true) || rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$log" ]; then
    pass "CI: skips without calling launchctl"
  else
    fail "CI run misbehaved (rc=$rc, log: $(tr '\n' '|' <"$log"))"
  fi

  # ---- no GUI session: skip after the check ----
  : >"$log"
  rc=0
  out=$(run_reload PRINT_FAIL=1) || rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q bootstrap "$log"; then
    pass "no GUI session: skips without loading anything"
  else
    fail "no-GUI run misbehaved (rc=$rc, log: $(tr '\n' '|' <"$log"))"
  fi

  # ---- normal run: alpha is loaded and gets unloaded first; beta isn't ----
  : >"$log"
  rc=0
  out=$(run_reload LOADED=dotfiles.alpha) || rc=$?
  local unload_line load_line
  unload_line=$(grep -Fnx "bootout $domain/dotfiles.alpha" "$log" | cut -d: -f1)
  load_line=$(grep -Fnx "bootstrap $domain $jobs_dir/dotfiles.alpha.plist" "$log" | cut -d: -f1)
  if [ "$rc" -eq 0 ] \
    && [ -n "$unload_line" ] && [ -n "$load_line" ] \
    && [ "$unload_line" -lt "$load_line" ] \
    && ! grep -Fq "bootout $domain/dotfiles.beta" "$log" \
    && grep -Fqx "bootstrap $domain $jobs_dir/dotfiles.beta.plist" "$log"; then
    pass "loads every dotfiles.* job, unloading only the ones already loaded"
  else
    fail "reload run wrong (rc=$rc, out: $out, log: $(tr '\n' '|' <"$log"))"
  fi
  if ! grep -q 'other.gamma' "$log"; then
    pass "leaves jobs outside dotfiles.* alone"
  else
    fail "touched a non-dotfiles job: $(tr '\n' '|' <"$log")"
  fi

  # ---- one job fails to load: the rest still load, exit is nonzero ----
  : >"$log"
  rc=0
  out=$(run_reload BOOTSTRAP_FAIL="$jobs_dir/dotfiles.alpha.plist") || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'FAILED  dotfiles.alpha' <<<"$out" \
    && grep -Fqx "bootstrap $domain $jobs_dir/dotfiles.beta.plist" "$log"; then
    pass "a failed load is reported, the rest still load, and the run fails"
  else
    fail "failed-load run wrong (rc=$rc, out: $out)"
  fi

  # ---- a loaded job that won't unload: reported, not loaded twice ----
  : >"$log"
  rc=0
  out=$(run_reload LOADED=dotfiles.alpha BOOTOUT_FAIL="$domain/dotfiles.alpha") || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'FAILED  dotfiles.alpha' <<<"$out" \
    && ! grep -Fq "bootstrap $domain $jobs_dir/dotfiles.alpha.plist" "$log" \
    && grep -Fqx "bootstrap $domain $jobs_dir/dotfiles.beta.plist" "$log"; then
    pass "a failed unload is reported and the run fails"
  else
    fail "failed-unload run wrong (rc=$rc, out: $out)"
  fi

  # ---- a plist with no Label: reported, the rest still load ----
  plutil -create xml1 "$jobs_dir/dotfiles.broken.plist"
  : >"$log"
  rc=0
  out=$(run_reload) || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'FAILED  dotfiles.broken.plist' <<<"$out" \
    && grep -Fqx "bootstrap $domain $jobs_dir/dotfiles.beta.plist" "$log"; then
    pass "a plist without a Label is reported and the rest still load"
  else
    fail "missing-Label run wrong (rc=$rc, out: $out)"
  fi

  rm -rf "$stubdir"
}
