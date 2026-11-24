#!/usr/bin/env bash
# Claude Code permission rule tests (~/.claude/settings.json)
# shellcheck shell=bash

# Ask rules that prompt even in auto mode.
CLAUDE_PERMISSIONS_ASK=(
  # Commands whose arguments can send a request to a host Claude picks. The
  # matching allow rules (`gh api -X GET *`, `git fetch *`, ...) end in a
  # wildcard that also takes a URL or host flag.
  'Bash(auth0 api *://*)'
  'Bash(aws *--endpoint-url*)'
  'Bash(dotnet *--source*)'
  'Bash(gh *--hostname*)'
  'Bash(gh api *://*)'
  'Bash(git fetch *://*)'
  'Bash(git ls-remote *://*)'
  'Bash(git pull *://*)'
  'Bash(npm *--registry*)'
  'Bash(pnpm *--registry*)'
  'Bash(uv *--*index*)'
  # Commands that print a secret or download stored files. The auto-mode
  # classifier sometimes lets these run on its own. The `aws` rules have a
  # wildcard before the service because global options such as `--profile`
  # can come first.
  'Bash(aws *ecs describe-task-definition*)'
  'Bash(aws *lambda get-function-configuration*)'
  'Bash(aws *s3 cp *)'
  'Bash(aws *s3 sync *)'
  'Bash(aws *s3api get-object*)'
  'Bash(aws *secretsmanager *get-secret-value*)'
  'Bash(aws *ssm get-parameter*)'
  'Bash(az cognitiveservices account keys list *)'
  'Bash(az functionapp config appsettings list *)'
  'Bash(az keyvault secret download *)'
  'Bash(az keyvault secret show *)'
  'Bash(az storage account keys list *)'
  'Bash(az storage account show-connection-string *)'
  'Bash(az webapp config appsettings list *)'
  'Bash(az webapp config connection-string list *)'
  'Bash(az webapp deployment list-publishing-profiles *)'
  # Pushes, merges, and PR creation need the user's approval; local commits
  # don't, since the review-gate git hook checks them.
  'Bash(git push *)'
  'Bash(git -C * push *)'
  'Bash(git merge *)'
  'Bash(git -C * merge *)'
  'Bash(gh pr create *)'
  'Bash(gh pr merge *)'
)

# Deny rules for shapes an allow rule would otherwise approve:
# - gh uses the last -X/--method, so `gh api -X GET <path> -X DELETE` ran as
#   a DELETE. No space after the flag, so `--method=DELETE` and `-XDELETE`
#   match too.
# - git accepts any unique prefix of a long option, so `git fetch
#   --upl=<cmd>` is `--upload-pack=<cmd>`.
# - `git commit` is allowed because the review-gate git hook checks it, so
#   the ways to skip or turn off that hook are denied: `--no-verify`
#   (`--no-veri` is its shortest unique prefix), `git commit -n`, and
#   config changes to `hook.*` or `claude.reviewHook` (both spellings of
#   `reviewHook`, since git config keys ignore case; other spellings, such
#   as `Hook.`, aren't matched). No allow rule approves those config
#   writes; the deny rules stop them in auto mode too. A combined short
#   flag such as `-an` isn't matched. Message text after `-m` can match a
#   deny rule, so a commit message that mentions `--no-verify` is denied.
CLAUDE_PERMISSIONS_DENY=(
  'Bash(gh api *-X*-X*)'
  'Bash(gh api *--method*--method*)'
  'Bash(gh api *-X*--method*)'
  'Bash(gh api *--method*-X*)'
  'Bash(git *--upl*)'
  'Bash(git *--no-veri*)'
  'Bash(git commit -n*)'
  'Bash(git commit * -n*)'
  'Bash(git -C * commit -n*)'
  'Bash(git -C * commit * -n*)'
  'Bash(git config *hook.*)'
  'Bash(git -C * config *hook.*)'
  'Bash(git config *claude.reviewHook*)'
  'Bash(git -C * config *claude.reviewHook*)'
  'Bash(git config *claude.reviewhook*)'
  'Bash(git -C * config *claude.reviewhook*)'
  # The hook runs only when CLAUDECODE=1, so clearing or changing it in
  # the same command turns the gate off (`unset` has an allow rule).
  'Bash(unset *CLAUDECODE*)'
  'Bash(export *CLAUDECODE*)'
  'Bash(env *CLAUDECODE*)'
  'Bash(*CLAUDECODE=*)'
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

  # Each can call any URL or endpoint its arguments name, and an allow rule
  # would approve every call with no classifier check, secret reads
  # included. The autoMode allow entry lets the classifier approve their
  # configuration reads instead.
  if jq -e '.permissions.allow | map(select(test("^Bash\\((az rest|auth0 api|aws)[ :)]"))) | length == 0' \
    "$settings" >/dev/null 2>&1; then
    pass "az rest, auth0 api, and aws have no allow rule"
  else
    fail "az rest, auth0 api, or aws has an allow rule, so its calls skip the classifier"
  fi

  # A list set without "$defaults" replaces the built-in list instead of
  # adding to it.
  if jq -e '.autoMode | [.environment, .allow, .soft_deny, .hard_deny] | map(select(. != null and index("$defaults") == null)) | length == 0' \
    "$settings" >/dev/null 2>&1; then
    pass "autoMode lists keep the built-in entries"
  else
    fail "an autoMode list has no \"\$defaults\" entry, so it drops the built-in entries"
  fi

  # Claude commits and records reviews without a prompt in every mode; the
  # review-gate git hook refuses commits no review covers.
  if jq -e '(.permissions.allow | index("Bash(git commit *)") != null)
      and (.permissions.ask | map(select(test("^Bash\\(git (-C \\* )?commit"))) | length == 0)
      and (.permissions.allow | index("Bash(review-gate mark *)") != null)
      and (.permissions.allow | index("Bash(review-gate defer *)") != null)
      and (.permissions.allow | index("Bash(review-gate last)") != null)' \
    "$settings" >/dev/null 2>&1; then
    pass "git commit and review-gate run without a prompt"
  else
    fail "git commit or review-gate isn't allowed, or git commit still has an ask rule"
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
