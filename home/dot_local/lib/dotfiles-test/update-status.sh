#!/usr/bin/env bash
# update-status tests: the status-bar marker and the details, against fixture
# state files.

UPDATE_STATUS="${HOME}/.local/bin/update-status"

test_update_status() {
  section "Update status"

  # The scheduled run is macOS-only, and the fixtures use BSD `date -v`.
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi
  if [ ! -x "$UPDATE_STATUS" ]; then
    fail "update-status not installed (or not executable) at $UPDATE_STATUS"
    return
  fi

  # The output abbreviates $HOME as a literal ~. The marker's icon is Nerd
  # Font's warning sign, U+F071.
  local tmp state out today tilde='~' icon=$'\xef\x81\xb1'
  tmp=$(mktemp -d)
  state="$tmp/state/topgrade"
  today=$(date +%Y-%m-%d)
  us_fresh_state() {
    rm -rf "$tmp/state"
    mkdir -p "$state"
    echo "$today" >"$state/last-day"
    echo "$HOME/Library/Logs/topgrade-daily-$today.log" >"$state/last-log"
    : >"$state/drift"
    : >"$state/stale-containers"
    : >"$state/outdated-casks"
    : >"$state/new-steps"
  }
  us_status() { XDG_STATE_HOME="$tmp/state" "$UPDATE_STATUS" "$@" 2>&1; }

  rm -rf "$tmp/state"
  out=$(us_status --tmux) || true
  if [ -z "$out" ] && us_status | grep -q 'All clear'; then
    pass "no state yet: no marker, and the details say all clear"
  else
    fail "no-state output wrong: '$out'"
  fi

  us_fresh_state
  out=$(us_status --tmux) || true
  if [ -z "$out" ] && us_status | grep -q 'All clear'; then
    pass "a clean recent run: no marker"
  else
    fail "clean-state marker should be empty: '$out'"
  fi

  us_fresh_state
  printf '%s\n' 'Brew (ARM)' 'npm' >"$state/failed"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=red]$icon 1#[default]" ]; then
    pass "a failed run shows a red marker"
  else
    fail "failed marker wrong: '$out'"
  fi
  out=$(us_status) || true
  if grep -Fq 'Update failed: Brew (ARM), npm' <<<"$out" \
    && grep -Fq "$tilde/Library/Logs/topgrade-daily-$today.log" <<<"$out"; then
    pass "details name the failed steps and the log"
  else
    fail "failed details wrong: $(tr '\n' '|' <<<"$out")"
  fi

  # One count per kind of item, however many files or apps it lists.
  us_fresh_state
  printf '%s\n' .config/git/config .config/karabiner/karabiner.json >"$state/drift"
  printf '%s\t%s\t%s\n' shop-db-1 postgres:18 shop >"$state/stale-containers"
  printf '%s\n' visual-studio-code warp >"$state/outdated-casks"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=brightblack]$icon 3#[default]" ]; then
    pass "drift, stale containers, and waiting casks: a yellow marker counting 3"
  else
    fail "attention marker wrong: '$out'"
  fi
  out=$(us_status) || true
  if grep -Fq "$tilde/.config/karabiner/karabiner.json" <<<"$out" && grep -Fq 'chezmoi re-add' <<<"$out" \
    && grep -Fq 'shop-db-1 (shop)' <<<"$out" && grep -Fq 'docker compose up -d' <<<"$out" \
    && grep -Fq 'visual-studio-code, warp' <<<"$out"; then
    pass "details list each item with what to run"
  else
    fail "attention details wrong: $(tr '\n' '|' <<<"$out")"
  fi

  us_fresh_state
  echo npm >"$state/new-steps"
  echo '2.1.1 → 2.1.2' >"$state/claude-upgrade"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=brightblack]$icon 2#[default]" ] && us_status | grep -Fq 'Claude Code 2.1.1 → 2.1.2' \
    && us_status | grep -Fq 'claude-refresh' && us_status | grep -Fq 'New topgrade step: npm'; then
    pass "a new step and a Claude Code upgrade count, with what to run"
  else
    fail "notice output wrong: '$out' / $(us_status | tr '\n' '|')"
  fi

  # A held lock or an unloaded job stops the run without failing it.
  us_fresh_state
  date -v-3d +%Y-%m-%d >"$state/last-day"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=red]$icon 1#[default]" ] && us_status | grep -q "hasn't run since $(date -v-3d +%Y-%m-%d)"; then
    pass "no run in over 2 days shows a red marker"
  else
    fail "stale-run marker wrong: '$out'"
  fi
  date -v-2d +%Y-%m-%d >"$state/last-day"
  out=$(us_status --tmux) || true
  if [ -z "$out" ]; then
    pass "a run 2 days ago (one missed day) isn't flagged yet"
  else
    fail "2-day-old run flagged: '$out'"
  fi

  # `failed` holds one reason line when the run itself failed.
  us_fresh_state
  echo 'update failed, see log' >"$state/failed"
  rm "$state/last-log"
  out=$(us_status) || true
  if grep -Fq 'Update failed: update failed, see log.' <<<"$out" && ! grep -Fq ',  ' <<<"$out"; then
    pass "a one-line failure reason keeps its comma, and a missing log path doesn't break it"
  else
    fail "reason line wrong: $(tr '\n' '|' <<<"$out")"
  fi

  us_fresh_state
  printf '%s\t%s\t%s\n' scratch alpine:3 '' >"$state/stale-containers"
  out=$(us_status) || true
  if grep -Fq 'Containers on an older image: scratch. ' <<<"$out"; then
    pass "a container outside any compose project is listed by name alone"
  else
    fail "project-less container wrong: $(tr '\n' '|' <<<"$out")"
  fi

  us_fresh_state
  echo mise >"$state/failed"
  date -v-3d +%Y-%m-%d >"$state/last-day"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=red]$icon 2#[default]" ]; then
    pass "a failure and a stale run together: red, counting 2"
  else
    fail "failed + stale marker wrong: '$out'"
  fi

  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  # Last, because tmux truncates status-right from the left.
  if grep -Eq "^set -g status-right '.*#\(~/.local/bin/update-status --tmux\)'$" "$conf"; then
    pass "the marker ends the tmux status bar"
  else
    fail "tmux status-right doesn't end with the update-status marker"
  fi

  rm -rf "$tmp"
}
