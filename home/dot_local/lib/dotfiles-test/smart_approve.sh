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

  # find -execdir hits the deny pattern.
  d=$(decision_for '"find . -execdir rm {} \\;"')
  if [ "$d" = "deny" ]; then
    pass "find -execdir → deny"
  else
    fail "'find . -execdir' should match deny pattern (got: $d)"
  fi

  # find -delete is intentionally NOT in deny — should still match Bash(find *)
  # allow per user policy ("ok with find remove in allowed folders").
  d=$(decision_for '"find /tmp -name foo -delete"')
  if [ "$d" = "allow" ]; then
    pass "find -delete → allow (intentional, not in deny)"
  else
    fail "'find -delete' should still allow (got: $d)"
  fi

  # Narrow uv allow wins: Bash(uv pip list *) is in allow, Bash(uv *) is in
  # ask. The hook only checks allow/deny, so the narrow allow wins for
  # non-chained read-only uv commands.
  d=$(decision_for '"uv pip list"')
  if [ "$d" = "allow" ]; then
    pass "uv pip list → allow (narrow allow wins over broader ask)"
  else
    fail "'uv pip list' should allow via narrow pattern (got: $d)"
  fi

  # Non-narrow uv (e.g. uv run, uv pip install) is not in allow → hook falls
  # through → Claude Code native sees Bash(uv *) in ask → prompts.
  d=$(decision_for '"uv run script.py"')
  if [ "$d" = "fallthrough" ]; then
    pass "uv run → fall-through (broader ask handles)"
  else
    fail "'uv run' should fall through to native matcher (got: $d)"
  fi

  # Demoted patterns (curl, rm, docker run, etc.) fall through to native ask.
  d=$(decision_for '"curl https://example.com"')
  if [ "$d" = "fallthrough" ]; then
    pass "curl → fall-through (demoted from allow)"
  else
    fail "'curl ...' should fall through (got: $d)"
  fi

  d=$(decision_for '"rm /tmp/foo"')
  if [ "$d" = "fallthrough" ]; then
    pass "rm → fall-through (demoted from allow)"
  else
    fail "'rm ...' should fall through (got: $d)"
  fi

  # Mixed chain (allow + ask) → silent fall-through (hook doesn't honor ask).
  d=$(decision_for '"git status && git config core.editor vim"')
  if [ "$d" = "fallthrough" ]; then
    pass "mixed chain (allow + ask) → silent fall-through"
  else
    fail "mixed chain should fall through to native matcher (got: $d)"
  fi

  # Chain mixing allowed + demoted command falls through.
  d=$(decision_for '"git status && curl https://example.com"')
  if [ "$d" = "fallthrough" ]; then
    pass "chain (allow + demoted) → fall-through"
  else
    fail "chain with demoted command should fall through (got: $d)"
  fi

  # Deny applies even when the rest of the chain is allowed.
  d=$(decision_for '"git status && find . -exec rm {} \\;"')
  if [ "$d" = "deny" ]; then
    pass "chain containing deny pattern → deny"
  else
    fail "chain with find -exec should deny (got: $d)"
  fi
}
