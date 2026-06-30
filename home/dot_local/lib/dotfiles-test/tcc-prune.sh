#!/usr/bin/env bash
# claude-tcc-prune orphan-selection tests
# shellcheck shell=bash

CLAUDE_TCC_PRUNE="${HOME}/.local/bin/claude-tcc-prune"

# Unit coverage for path classification, orphan selection, the in-use guard, and
# the --list labels, plus an end-to-end prune and --list against throwaway sqlite
# fixtures (via the CLAUDE_TCC_DB / CLAUDE_TCC_DB_SYS overrides, so no Full Disk
# Access or real upgrade history is needed). What stays manual: the lsof-based
# in-use detection and pruning the real system TCC.db.
test_claude_tcc_prune() {
  section "Claude TCC prune"

  if [ ! -f "$CLAUDE_TCC_PRUNE" ]; then
    skip "claude-tcc-prune not installed"
    return
  fi

  # ---- managed-path classification ----
  # shellcheck source=/dev/null
  if (source "$CLAUDE_TCC_PRUNE" \
    && claude_tcc_is_managed_path '/opt/homebrew/Caskroom/claude-code/2.1.181/claude'); then
    pass "versioned Caskroom binary is a managed path"
  else
    fail "versioned Caskroom binary should be managed"
  fi

  # The stable symlink resolves to the Caskroom, but its own path must never be
  # treated as a deletable client - we'd nuke the live grant.
  # shellcheck source=/dev/null
  if (source "$CLAUDE_TCC_PRUNE" \
    && claude_tcc_is_managed_path '/opt/homebrew/bin/claude'); then
    fail "bin symlink path must not be managed"
  else
    pass "bin symlink path is not managed"
  fi

  # An unrelated Caskroom tool sharing the prefix must not match.
  # shellcheck source=/dev/null
  if (source "$CLAUDE_TCC_PRUNE" \
    && claude_tcc_is_managed_path '/opt/homebrew/Caskroom/other-tool/1.0/other'); then
    fail "unrelated Caskroom tool must not be managed"
  else
    pass "unrelated Caskroom tool is not managed"
  fi

  # ---- orphan selection (live vs dead paths) ----
  local tmp live orphan unmanaged result
  tmp="$(mktemp -d)"
  live="$tmp/Caskroom/claude-code/9.9.9/claude"
  orphan="$tmp/Caskroom/claude-code/0.0.1/claude"
  unmanaged="$tmp/some/other/binary"
  mkdir -p "$(dirname "$live")"
  : >"$live" # live binary exists; orphan path is never created

  # shellcheck source=/dev/null
  result="$(source "$CLAUDE_TCC_PRUNE" \
    && printf '%s\n%s\n%s\n' "$live" "$orphan" "$unmanaged" | claude_tcc_select_orphans)"
  rm -rf "$tmp"

  if [ "$result" = "$orphan" ]; then
    pass "selects only the dead claude-code path"
  else
    fail "orphan selection wrong: '$result'"
  fi

  # ---- live-process guard: keep paths a running session still holds ----
  local a b c inuse
  a='/opt/homebrew/Caskroom/claude-code/1.0.0/claude'
  b='/opt/homebrew/Caskroom/claude-code/2.0.0/claude'
  c='/opt/homebrew/Caskroom/claude-code/3.0.0/claude'
  inuse="$b" # version 2 still has a running session
  # shellcheck source=/dev/null
  result="$(source "$CLAUDE_TCC_PRUNE" \
    && printf '%s\n%s\n%s\n' "$a" "$b" "$c" | claude_tcc_drop_inuse "$inuse" | tr '\n' ' ')"
  if [ "$result" = "$a $c " ]; then
    pass "drops in-use path, keeps the rest for pruning"
  else
    fail "in-use guard wrong: '$result'"
  fi

  # Empty in-use list must keep every candidate (nothing running to protect).
  # shellcheck source=/dev/null
  result="$(source "$CLAUDE_TCC_PRUNE" \
    && printf '%s\n%s\n' "$a" "$b" | claude_tcc_drop_inuse "" | tr '\n' ' ')"
  if [ "$result" = "$a $b " ]; then
    pass "empty in-use list keeps all candidates"
  else
    fail "empty in-use guard wrong: '$result'"
  fi

  # ---- service -> pane labels (drives the --list report) ----
  # shellcheck source=/dev/null
  result="$(source "$CLAUDE_TCC_PRUNE" && claude_tcc_service_label kTCCServiceSystemPolicyAllFiles)"
  if [ "$result" = "Full Disk Access" ]; then
    pass "AllFiles maps to Full Disk Access pane"
  else
    fail "AllFiles label wrong: '$result'"
  fi

  # A service with no UI surface must say so, not look like a real pane.
  # shellcheck source=/dev/null
  result="$(source "$CLAUDE_TCC_PRUNE" && claude_tcc_service_label kTCCServiceFileProviderDomain)"
  if [ "$result" = "File Provider (no UI pane)" ]; then
    pass "FileProvider flagged as having no UI pane"
  else
    fail "FileProvider label wrong: '$result'"
  fi

  # ---- client-state classification (path vs bundle, live vs dead) ----
  local statedir
  statedir="$(mktemp -d)"
  : >"$statedir/live"

  # shellcheck source=/dev/null
  result="$(source "$CLAUDE_TCC_PRUNE" \
    && printf '%s|%s|%s\n' \
      "$(claude_tcc_client_state 1 "$statedir/live")" \
      "$(claude_tcc_client_state 1 "$statedir/gone")" \
      "$(claude_tcc_client_state 0 com.anthropic.claudefordesktop)")"
  rm -rf "$statedir"

  if [ "$result" = "live|orphan|bundle" ]; then
    pass "client state: live path, dead path, and bundle id"
  else
    fail "client state wrong: '$result'"
  fi

  # ---- integration: prune + list against throwaway sqlite fixtures ----
  # Drives the real claude_tcc_prune_main flow (DELETE, quote escaping,
  # transaction) and the --list renderer end to end through the db overrides, no
  # Full Disk Access needed. The prune is macOS-gated, so run it on Darwin only.
  if [[ "$OSTYPE" != darwin* ]]; then
    skip "prune integration (macOS only)"
    return
  fi

  local fixdir userdb sysdb livebin orphan qorphan qorphan_sql unrelated expect
  fixdir="$(mktemp -d)"
  userdb="$fixdir/user.db"
  sysdb="$fixdir/sys.db"
  livebin="$fixdir/Caskroom/claude-code/9.9.9/claude"
  orphan="$fixdir/Caskroom/claude-code/0.0.1/claude"
  qorphan="$fixdir/Caskroom/claude-code/1.2.3'q/claude" # exercises quote escaping
  qorphan_sql=${qorphan//"'"/"''"}
  unrelated="/Applications/Other.app"
  mkdir -p "$(dirname "$livebin")"
  : >"$livebin" # only the live version exists on disk

  sqlite3 "$userdb" "CREATE TABLE access (service TEXT, client TEXT, client_type INTEGER, auth_value INTEGER);"
  sqlite3 "$userdb" "INSERT INTO access VALUES \
    ('kTCCServiceSystemPolicyAppData', '$livebin', 1, 2), \
    ('kTCCServiceSystemPolicyAppData', '$orphan', 1, 2), \
    ('kTCCServiceSystemPolicyAppData', '$qorphan_sql', 1, 2), \
    ('kTCCServiceFileProviderDomain', '$unrelated', 0, 2);"

  CLAUDE_TCC_DB="$userdb" bash "$CLAUDE_TCC_PRUNE" --quiet >/dev/null 2>&1

  result="$(sqlite3 "$userdb" "SELECT client FROM access;" | sort)"
  expect="$(printf '%s\n%s\n' "$livebin" "$unrelated" | sort)"
  if [ "$result" = "$expect" ]; then
    pass "prune deletes orphans (incl. quoted path), keeps live and unrelated"
  else
    fail "prune integration wrong; remaining: '$result'"
  fi

  # --list must render the system FDA orphan with its pane label.
  sqlite3 "$sysdb" "CREATE TABLE access (service TEXT, client TEXT, client_type INTEGER, auth_value INTEGER);"
  sqlite3 "$sysdb" "INSERT INTO access VALUES ('kTCCServiceSystemPolicyAllFiles', '$orphan', 1, 2);"
  result="$(CLAUDE_TCC_DB="$userdb" CLAUDE_TCC_DB_SYS="$sysdb" bash "$CLAUDE_TCC_PRUNE" --list 2>/dev/null)"
  rm -rf "$fixdir"
  if printf '%s' "$result" | grep -q "Full Disk Access" \
    && printf '%s' "$result" | grep -qF "$orphan"; then
    pass "--list renders the system FDA orphan with its pane label"
  else
    fail "--list output missing expected row: '$result'"
  fi
}
