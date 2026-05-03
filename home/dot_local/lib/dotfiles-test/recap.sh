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
}
