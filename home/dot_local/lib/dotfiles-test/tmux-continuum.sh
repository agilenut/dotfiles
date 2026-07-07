#!/usr/bin/env bash
# Tmux continuum auto-save health tests
# shellcheck shell=bash

# Continuum auto-saves only while a "#(.../continuum_save.sh)" segment sits in
# status-right. A config reload rewrites status-right without it, and
# continuum's own re-add is skipped when its another-server guard miscounts a
# transient tmux process — auto-save then dies silently until server restart
# (bit us 2026-07-07: a reboot restored a 10-day-stale save from 06-27).
# continuum-ensure-save-segment.sh repairs the segment after every reload;
# these tests guard the script, its wiring, and the live server's save health.
test_continuum_autosave() {
  section "Tmux continuum auto-save"

  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  config_home="${config_home%/}"
  local ensure_script="$config_home/tmux/continuum-ensure-save-segment.sh"
  local tmux_conf="$config_home/tmux/tmux.conf"
  local save_script="$config_home/tmux/plugins/tmux-continuum/scripts/continuum_save.sh"

  if ! command -v tmux >/dev/null 2>&1; then
    skip "tmux not installed"
    return
  fi

  # ---- repair script installed ----
  if [ -x "$ensure_script" ]; then
    pass "continuum-ensure-save-segment.sh installed and executable"
  else
    fail "continuum-ensure-save-segment.sh missing or not executable"
    return
  fi

  # ---- fresh-machine guard: no plugin → quiet exit ----
  # A regression here makes every tmux.conf reload flash a run-shell error
  # on machines that haven't installed plugins yet (prefix I).
  # TMUX points at a dead socket: if the script's plugin guard ever breaks,
  # its tmux calls fail loudly here instead of mutating the live server.
  if XDG_CONFIG_HOME=/nonexistent TMUX=/nonexistent/dt-sock,0,0 "$ensure_script"; then
    pass "exits quietly when the plugin is missing"
  else
    fail "nonzero exit without plugin (reload error flash on fresh machines)"
  fi

  # ---- tmux.conf runs the repair, and only after TPM ----
  # Ordering matters: run before TPM and the repair races continuum's own
  # (possibly skipped) re-add instead of fixing its aftermath.
  if [ ! -f "$tmux_conf" ]; then
    skip "tmux.conf not installed"
    return
  fi
  local tpm_line run_line
  # `|| true` spans the pipeline: a no-match grep exits 1 and, under the
  # runner's errexit+pipefail, would abort the whole suite exactly when
  # this check should fail instead.
  tpm_line=$(grep -n -m1 "plugins/tpm/tpm" "$tmux_conf" | cut -d: -f1 || true)
  run_line=$(grep -n -m1 "continuum-ensure-save-segment.sh" "$tmux_conf" | cut -d: -f1 || true)
  if [ -z "$run_line" ]; then
    fail "tmux.conf does not run continuum-ensure-save-segment.sh (reload kills auto-save)"
  elif [ -n "$tpm_line" ] && [ "$run_line" -gt "$tpm_line" ]; then
    pass "tmux.conf repairs the save segment after TPM"
  else
    fail "continuum-ensure-save-segment.sh must run after the TPM line"
  fi

  # ---- repair behavior, on an isolated tmux server ----
  if [ ! -x "$save_script" ]; then
    # note, not skip: plugins are a per-machine bootstrap step (prefix I)
    # that CI never runs — a skip would exit-2 the suite there.
    note_with_followup "tmux-continuum plugin not installed (repair test not run)" \
      "Install tmux plugins (start tmux, press C-a I), then re-run dotfiles-test"
  else
    local sock="dt-continuum-$$"
    local segment="#(${save_script})"
    # Trap BEFORE new-session so an errexit abort can't leak the server —
    # a lingering tmux process is exactly what trips continuum's guard.
    trap 'tmux -L "$sock" kill-server 2>/dev/null || true' EXIT INT TERM
    tmux -L "$sock" -f /dev/null new-session -d -x 80 -y 24
    local sock_path
    sock_path=$(tmux -L "$sock" display-message -p '#{socket_path}')
    # Point the script's bare tmux calls at the isolated server, not the
    # user's live one ($TMUX's first component is the socket path).
    local tmux_env="${sock_path},0,0"

    tmux -L "$sock" set-option -g status-right 'wiped-by-reload'
    # `if !` guards: a nonzero script exit must fail this test, not abort
    # the whole suite via the runner's errexit.
    if ! TMUX="$tmux_env" "$ensure_script"; then
      fail "repair script exited nonzero on wiped status-right"
    fi
    local sr
    sr=$(tmux -L "$sock" show-option -gqv status-right)
    if [ "$sr" = "${segment}wiped-by-reload" ]; then
      pass "repairs a wiped save segment (prepends, preserves the rest)"
    else
      fail "wiped segment not repaired: '$sr'"
    fi

    # Idempotent: a second run (the normal already-present case) must not
    # stack a duplicate segment.
    if ! TMUX="$tmux_env" "$ensure_script"; then
      fail "repair script exited nonzero on intact status-right"
    fi
    sr=$(tmux -L "$sock" show-option -gqv status-right)
    local rest="${sr/"$segment"/}"
    if [ "$sr" != "$rest" ] && [[ "$rest" != *"$segment"* ]]; then
      pass "already-present segment left alone (no duplicate)"
    else
      fail "segment duplicated or lost on second run: '$sr'"
    fi

    tmux -L "$sock" kill-server
    trap - EXIT INT TERM
  fi

  # ---- live server: segment present and saves actually happening ----
  local live_sr
  if ! live_sr=$(tmux show-option -gqv status-right 2>/dev/null); then
    # note, not skip: CI has no live server — a skip would exit-2 the suite.
    note_with_followup "no live tmux server (segment + save-freshness checks not run)" \
      "Run dotfiles-test while tmux is running to verify continuum auto-save health"
    return
  fi
  if [[ "$live_sr" == *"continuum_save.sh"* ]]; then
    pass "live status-right carries the save segment"
  else
    fail "live status-right lost the save segment (auto-save is dead right now)"
  fi

  # Freshness: continuum stamps @continuum-save-last-timestamp on every save
  # launch. Give it two intervals plus slack before calling it stale, and
  # only judge servers old enough to have owed us a save (a fresh server
  # deliberately delays its first save by one interval).
  local interval last_save start_time now threshold
  interval=$(tmux show-option -gqv '@continuum-save-interval')
  interval="${interval:-15}"
  if [ "$interval" -eq 0 ]; then
    skip "continuum auto-save disabled (@continuum-save-interval 0)"
    return
  fi
  threshold=$(((interval * 2 + 5) * 60))
  last_save=$(tmux show-option -gqv '@continuum-save-last-timestamp')
  start_time=$(tmux display-message -p '#{start_time}')
  now=$(date +%s)
  if [ -z "$last_save" ] || [ $((now - start_time)) -lt "$threshold" ]; then
    skip "server too young to judge save freshness"
  elif [ $((now - last_save)) -le "$threshold" ]; then
    pass "auto-save ran within the last $((threshold / 60)) minutes"
  else
    fail "last auto-save was $(((now - last_save) / 60)) minutes ago (stale — segment likely gone)"
  fi
}
