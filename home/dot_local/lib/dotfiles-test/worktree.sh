#!/usr/bin/env bash
# Worktree hook tests
# shellcheck shell=bash

WORKTREE_LIB="${HOME}/.claude/hooks/worktree-lib.sh"
WORKTREE_CREATE="${HOME}/.claude/hooks/create-worktree.sh"

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

  # shellcheck source=/dev/null
  if (source "$WORKTREE_LIB" && ! is_worktree /tmp); then
    pass "is_worktree returns false for non-worktree dir"
  else
    fail "is_worktree returned true for /tmp"
  fi

  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && pick_offset)
  if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null; then
    pass "pick_offset returns value in 1..99 (got $result)"
  else
    fail "pick_offset returned invalid value: '$result'"
  fi
}

test_worktree_e2e() {
  section "Worktree Hook End-to-End"

  if [ ! -f "$WORKTREE_CREATE" ] || [ ! -f "$WORKTREE_LIB" ]; then
    skip "worktree hooks not installed"
    return
  fi

  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
    return
  fi

  # Use a parent temp dir so both the test repo and its sibling worktree
  # path land inside one cleanable root.
  local root repo wt_path
  root=$(mktemp -d -t dotfiles-wt-test.XXXXXX)
  repo="$root/repo"

  cleanup_e2e() {
    if [ -d "$root/repo--main" ] && [ -f "$repo/.git" ]; then
      git -C "$repo" worktree remove --force "$root/repo--main" 2>/dev/null || true
    fi
    rm -rf "$root"
  }
  trap cleanup_e2e RETURN

  git init --quiet --initial-branch=main "$repo"
  git -C "$repo" -c user.email=test@example.invalid -c user.name=Test \
    commit --allow-empty -m "init" --quiet

  wt_path=$(printf '{"cwd":"%s"}' "$repo" | "$WORKTREE_CREATE" 2>/dev/null)

  if [ -z "$wt_path" ]; then
    fail "create-worktree.sh produced no output"
    return
  fi

  if [ ! -d "$wt_path" ]; then
    fail "create-worktree.sh did not create dir at $wt_path"
    return
  fi

  if [ ! -f "$wt_path/.git" ]; then
    fail "$wt_path is missing .git file (not a worktree)"
    return
  fi

  pass "create-worktree.sh created worktree at $(basename "$wt_path")"

  # Exercise teardown_worktree (docker block skipped — no .env/compose)
  # shellcheck source=/dev/null
  (source "$WORKTREE_LIB" && teardown_worktree "$wt_path")

  if [ ! -d "$wt_path" ]; then
    pass "teardown_worktree removed the worktree"
  else
    fail "teardown_worktree did not remove $wt_path"
  fi
}
