#!/usr/bin/env bash
# smart_approve hook tests
# shellcheck shell=bash

SMART_APPROVE_HOOK="${HOME}/.claude/hooks/smart_approve.py"

test_smart_approve() {
  section "Smart Approve Hook"

  if [ ! -f "$SMART_APPROVE_HOOK" ]; then
    skip_with_followup "smart_approve.py not installed" \
      "Run 'chezmoi apply' to install the smart_approve hook"
    return
  fi

  if ! command -v python3 &>/dev/null; then
    skip "python3 not installed (required by smart_approve)"
    return
  fi

  # Hook must contain the dotfiles patch marker. If it doesn't, the install
  # script silently downloaded an unpatched copy or upstream refactored the
  # function the patch targets — both are bugs.
  if grep -q "PATCHED (dotfiles fork)" "$SMART_APPROVE_HOOK"; then
    pass "patch marker present in installed hook"
  else
    fail "patch marker missing — install script may have skipped the patch"
  fi

  # Helper: pipe a PreToolUse JSON envelope through the hook and extract
  # the permissionDecision (defaults to "fallthrough" for empty/silent output).
  decision_for() {
    local cmd="$1"
    local out
    out=$(printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$cmd}}" \
      | python3 "$SMART_APPROVE_HOOK" 2>/dev/null)
    if [ -z "$out" ]; then
      printf 'fallthrough'
    else
      printf '%s' "$out" | python3 -c \
        "import json,sys; print(json.load(sys.stdin).get('hookSpecificOutput',{}).get('permissionDecision','fallthrough'))" \
        2>/dev/null
    fi
  }

  # Bare command matches Bash(prefix *) — proves the parser patch works.
  # Without the patch, fnmatch("git status", "git status *") is False because
  # the pattern requires a literal space + something after it.
  local d
  d=$(decision_for '"git status"')
  if [ "$d" = "allow" ]; then
    pass "bare command matches Bash(prefix *) (parser patch active)"
  else
    fail "bare 'git status' should match Bash(git status *) via patched parser (got: $d)"
  fi

  # Chained allowlisted commands — explicit allow.
  d=$(decision_for '"git status && git diff"')
  if [ "$d" = "allow" ]; then
    pass "chained allowlisted commands → allow"
  else
    fail "chained 'git status && git diff' should allow (got: $d)"
  fi

  # find -exec hits the deny pattern — explicit deny.
  d=$(decision_for '"find . -exec rm {} \\;"')
  if [ "$d" = "deny" ]; then
    pass "find -exec → deny"
  else
    fail "'find . -exec rm {} ;' should match deny pattern (got: $d)"
  fi

  # Mixed chain (allow + ask) → silent fall-through (hook doesn't honor ask).
  d=$(decision_for '"git status && git config core.editor vim"')
  if [ "$d" = "fallthrough" ]; then
    pass "mixed chain (allow + ask) → silent fall-through"
  else
    fail "mixed chain should fall through to native matcher (got: $d)"
  fi
}
