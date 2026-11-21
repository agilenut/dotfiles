#!/usr/bin/env bash
# Claude Code permission rule tests (~/.claude/settings.json)
# shellcheck shell=bash

# Ask rules for commands whose arguments can send a request to a host Claude
# picks. The matching allow rules (`gh api -X GET *`, `git fetch *`, ...) end
# in a wildcard that also takes a URL or host flag.
CLAUDE_PERMISSIONS_ASK=(
  'Bash(dotnet *--source*)'
  'Bash(gh *--hostname*)'
  'Bash(gh api *://*)'
  'Bash(git fetch *://*)'
  'Bash(git ls-remote *://*)'
  'Bash(git pull *://*)'
  'Bash(npm *--registry*)'
  'Bash(pnpm *--registry*)'
  'Bash(uv *--*index*)'
)

# Deny rules for shapes an allow rule would otherwise approve:
# - gh uses the last -X/--method, so `gh api -X GET <path> -X DELETE` ran as
#   a DELETE. No space after the flag, so `--method=DELETE` and `-XDELETE`
#   match too.
# - git accepts any unique prefix of a long option, so `git fetch
#   --upl=<cmd>` is `--upload-pack=<cmd>`.
CLAUDE_PERMISSIONS_DENY=(
  'Bash(gh api *-X*-X*)'
  'Bash(gh api *--method*--method*)'
  'Bash(gh api *-X*--method*)'
  'Bash(gh api *--method*-X*)'
  'Bash(git *--upl*)'
)

test_claude_permissions() {
  section "Claude Code permission rules"

  local settings="${HOME}/.claude/settings.json"
  if ! command -v jq &>/dev/null; then
    skip "permission rule checks (jq not installed)"
    return
  fi
  if ! jq -e . "$settings" >/dev/null 2>&1; then
    fail "cannot parse $settings; run 'chezmoi apply'"
    return
  fi

  # Claude Code decides Bash permissions itself; a PreToolUse hook that
  # approves commands would skip the auto-mode classifier for them.
  if jq -e '[.hooks.PreToolUse[]? | select(.matcher == "Bash")] | length == 0' \
    "$settings" >/dev/null 2>&1; then
    pass "no PreToolUse hook decides Bash permissions"
  else
    fail "a PreToolUse hook on Bash is configured"
  fi

  # `*` matches spaces too, so a wildcard before a subcommand matches any
  # subcommand: Bash(git -C * add *) matched a `git commit` whose message
  # said "add". Claude Code 2.1.246+ warns about the shape at startup.
  if jq -e '.permissions.allow | map(select(test("\\*[^ )]* +[^-*)]"))) | length == 0' \
    "$settings" >/dev/null 2>&1; then
    pass "no allow rule has a wildcard before a subcommand"
  else
    fail "an allow rule has a wildcard before a subcommand, so it matches any subcommand"
  fi

  # Both reach whatever host their argument names, so data can leave in the
  # URL or hostname; they stay with the classifier.
  if jq -e '.permissions.allow | (index("WebFetch") == null) and (index("Bash(dig *)") == null)' \
    "$settings" >/dev/null 2>&1; then
    pass "WebFetch and dig have no allow rule"
  else
    fail "WebFetch or dig has an allow rule, so it can send data to any host without a check"
  fi

  local rule
  for rule in "${CLAUDE_PERMISSIONS_ASK[@]}"; do
    if jq -e --arg r "$rule" '.permissions.ask | index($r) != null' \
      "$settings" >/dev/null 2>&1; then
      pass "ask: $rule"
    else
      fail "missing ask rule: $rule"
    fi
  done

  for rule in "${CLAUDE_PERMISSIONS_DENY[@]}"; do
    if jq -e --arg r "$rule" '.permissions.deny | index($r) != null' \
      "$settings" >/dev/null 2>&1; then
      pass "deny: $rule"
    else
      fail "missing deny rule: $rule"
    fi
  done
}
