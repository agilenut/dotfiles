#!/usr/bin/env bash
# Recap skill / wrapper installation tests.

test_recap_wrapper() {
  section "Recap daily wrapper"

  # macOS-only — the wrapper is the launchd-driven daily entry point and
  # the plist only makes sense on Darwin.
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi

  local wrapper="$HOME/.local/bin/recap-daily"

  if [[ -f "$wrapper" ]]; then
    pass "recap-daily wrapper installed at $wrapper"
  else
    fail "recap-daily wrapper not found at $wrapper"
    return
  fi

  if [[ -x "$wrapper" ]]; then
    pass "recap-daily wrapper is executable"
  else
    fail "recap-daily wrapper not executable"
  fi

  local plist="$HOME/Library/LaunchAgents/dotfiles.recap.plist"
  if [[ -f "$plist" ]]; then
    pass "launchd plist installed at $plist"
  else
    fail "launchd plist not found at $plist (run \`chezmoi apply\`)"
  fi

  # ~/Documents/recaps doesn't have to exist yet — the wrapper creates it.
  # Only fail if it exists but is unwritable.
  local recaps_dir="$HOME/Documents/recaps"
  if [[ -d "$recaps_dir" ]] && [[ ! -w "$recaps_dir" ]]; then
    fail "$recaps_dir exists but is not writable"
  else
    pass "$recaps_dir is writable (or will be created on first run)"
  fi

  # The wrapper must decide what to generate from its state file, never by
  # listing $RECAP_DIR. Under launchd its TCC identity is plain /bin/bash with
  # no Documents access, so such a listing comes back empty and the wrapper
  # regenerates the same day on every hourly fire.
  if grep -qE '\$\{?RECAP_DIR\}?"?/\?\?\?\?-' "$wrapper"; then
    fail "recap-daily globs \$RECAP_DIR — TCC denies that listing under launchd"
  else
    pass "recap-daily does not glob \$RECAP_DIR to pick the next day"
  fi

  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/recap"
  local state_file="$state_dir/last-day"

  if [[ -d "$state_dir" ]] && [[ ! -w "$state_dir" ]]; then
    fail "$state_dir exists but is not writable"
  else
    pass "$state_dir is writable (or will be created on first run)"
  fi

  # Absent is fine — the wrapper falls back to yesterday and writes it. Present
  # but malformed is not: the wrapper ignores it and re-runs yesterday daily.
  if [[ ! -f "$state_file" ]]; then
    pass "no last-day state yet (wrapper seeds it on first run)"
  elif [[ "$(cat "$state_file")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    pass "last-day state is an ISO date ($(cat "$state_file"))"
  else
    fail "last-day state is not an ISO date: $(cat "$state_file")"
  fi
}
