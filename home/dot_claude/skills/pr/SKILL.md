---
name: pr
description: "Use when user says /pr, asks about PR status, wants to create/merge a PR, or needs help with CI failures on a PR"
user-invocable: true
argument-hint: "[pr-number]"
---

# PR Lifecycle Skill

_Detect current PR state and act on it._

## Step 1: Determine State

_Inspect git and PR data; classify into a state from the table._

1. If PR number provided as argument, use that. Otherwise:
2. Run `git status`, `git branch --show-current`
3. Run `gh pr view --json number,state,title,body,baseRefName,mergedAt,mergeCommit 2>&1`

| State              | Condition                                                                   |
| ------------------ | --------------------------------------------------------------------------- |
| DIRTY              | Uncommitted changes exist                                                   |
| NO_PR              | Clean, on feature branch, no open PR                                        |
| CI_RUNNING         | PR open, checks still running                                               |
| CI_FAILED          | PR open, checks failed                                                      |
| CI_PASSED          | PR open, all checks passed, no `### Pre-merge` section or all items checked |
| PRE_MERGE_TESTING  | PR open, all checks passed, unchecked `### Pre-merge` items exist           |
| MERGED_CI_RUNNING  | PR merged, post-merge checks still running                                  |
| MERGED_CI_FAILED   | PR merged, post-merge checks failed                                         |
| POST_MERGE_TESTING | PR merged, CI passed, unchecked `### Post-merge` items exist                |
| MERGED_DONE        | PR merged, CI passed, no `### Post-merge` section or all items checked      |

To distinguish CI_PASSED vs PRE_MERGE_TESTING and POST_MERGE_TESTING vs
MERGED_DONE: read the PR body and check for unchecked items (`- [ ]`) in the
relevant test plan section.

## Step 2: Act on State

### DIRTY

- Show `git diff --stat`. `git add` the relevant files; run `pre-commit`
  and re-stage until clean. Apply the stale-index gate before committing
  (CLAUDE.md `## Git`): `git status --short`, re-`git add` any file with a
  second-column change (`MM`/`AM`/`MD`/`RM`) even if it looks already staged — a
  prior `/review` may have edited the working tree after staging. Craft a
  commit message; announce, then run
  `git commit -m "<message>" && git push` as one Bash call (add
  `-u origin <branch>` if no upstream) — one prompt covers commit and push.
- Re-run state detection.

### NO_PR

- `git log --oneline main..HEAD` to summarize commits
- Select one label based on the primary nature of the change. Check which
  labels exist in the repo (`gh label list --json name`) and use the best
  match:
  - `enhancement` — new feature, new capability, new test suite
  - `bug` — something was broken and this fixes it
  - `security` — security fix or hardening
  - `infrastructure` — CI/CD, workflows, deploy, infra scripts, Bicep, test
    maintenance (if label exists)
  - `documentation` — docs-only changes (if label exists)
  - No label if none of the above apply
- Draft PR: short title (<70 chars), `## Summary` bullets
- `## Test Plan` — only include if there are items. Items must be
  not already covered by CI (don't list "tests pass", "build succeeds",
  "deploy succeeds"). For each candidate, walk this decision tree:

  - Runnable now in this session? → run it, list under `### Pre-merge`
    as checked
  - Needs deploy or post-merge state? → list under `### Post-merge`
    unchecked
  - Manual but pre-merge possible (human action, no automation)? →
    list under `### Pre-merge` unchecked
  - None of the above (e.g., Linux-only check on a macOS-only
    machine, or "verify on next clean install") → omit

  Include `### Pre-merge` / `### Post-merge` only if they have items;
  omit `## Test Plan` entirely if neither section has items.

- Link issue per CLAUDE.md `## Git` issue-reference rules.
- `gh pr create` (include `--label <label>` if a label was selected), then
  re-run state detection

### CI_RUNNING

1. **Fire-and-forget; do not poll.** `gh pr checks <number> --watch` via
   Bash with `run_in_background: true` — the system notifies on process
   exit; you stay free to chat.
2. On notification: exit 0 → CI_PASSED/PRE_MERGE_TESTING (includes "no
   checks reported" — treat as no CI). Non-zero → CI_FAILED.

### CI_FAILED

1. `gh pr checks <number>` and `gh run view <run-id> --log-failed` to
   identify failures and read logs. **Don't reach for `gh run rerun`
   as a first response** — flakes are confirmed by evidence (compare
   logs to prior runs, check timestamps), not assumed.
2. Diagnose root cause; apply the fix via Edit/Write. **One attempt.**
   Stop (end turn; user re-invokes `/pr`) if: log doesn't name a touched
   file; fix would touch >1 conceptual area; multiple plausible causes;
   failing test asserts behavior the change inverts (never edit a test
   to make it pass).
3. **Verify**: run `pre-commit` (mandatory — re-stage and repeat until
   clean; auto-runs where allow-listed, may prompt in other repos). If
   CLAUDE.md has a fenced bash block under `## Testing`, `## Build`, or
   `## Development`, run it too; else note "build/test: unavailable".
4. Post a summary block — sections in this order, use `(none)` /
   `(unavailable)` for empty (never omit): **What failed** /
   **Root cause** / **Fix** / **Files** / **Local verification**.
5. Apply the stale-index gate (CLAUDE.md `## Git`): `git status --short`,
   re-`git add` any second-column change so the Edit's fix is in the index.
   Announce, then run `git commit -m "<message>" && git push` as one Bash
   call — one prompt covers commit and push.
6. Re-run state detection. Expect CI_RUNNING; if `gh pr checks` still
   shows the old failed run, look for a newer run id.

### PRE_MERGE_TESTING

1. **Re-verify checks complete.** `gh pr checks <number>` — one-shot read
   (not `--watch`; need result inline). Confirm all passed/skipped; if any
   still running, transition to CI_RUNNING.
2. Read PR body, process `### Pre-merge` items:
   - Verify locally if possible (run script, check file) → check off
   - Needs deploy → leave for post-merge
   - Needs manual human action → leave unchecked
3. NEVER check off `### Post-merge` items
4. Update PR body: `gh pr edit <number> --body`
5. Report which items still need manual testing. Tell user to test them and
   run `/pr` again.

### CI_PASSED

1. **Re-verify checks complete.** `gh pr checks <number>` — one-shot read
   (not `--watch`; need result inline). Confirm all passed/skipped; if any
   still running, transition to CI_RUNNING.
2. Check `~/.claude/skills/pr/ask-before-merge.txt` (one `owner/repo` per
   line; `#` for comments; skip if missing). If current repo
   (`gh repo view --json nameWithOwner --jq .nameWithOwner`) is listed,
   ask in chat ("Merge PR #N? y/n") and wait for `y` before proceeding.
   Announce with full pre-merge summary (PR #N `<title>`; target `<base>`;
   squash; delete `<head>`), then run
   `gh pr merge <number> --squash --delete-branch`.
3. Re-run state detection.

### MERGED_CI_RUNNING

1. `gh run list --branch main --created '><mergedAt>' --json databaseId,name`
   — substitute `<mergedAt>` with the ISO timestamp from step 1's JSON
   (post-merge workflows don't show in `gh pr checks`).
2. No runs → transition to POST_MERGE_TESTING or MERGED_DONE (no post-merge
   workflows configured).
3. **Fire-and-forget; do not poll.** For each `databaseId` from step 1:
   `gh run watch <id> --exit-status` via Bash with `run_in_background: true`
   — spawn in parallel. System notifies per process exit.
4. Track outstanding watches by `databaseId`. On each notification:
   - Non-zero exit → MERGED_CI_FAILED. Other watches keep running in
     background; their notifications can be ignored (already failed).
   - Zero exit → remove from pending set. When set is empty, transition
     to POST_MERGE_TESTING or MERGED_DONE.

### MERGED_CI_FAILED

1. `gh run view <run-id> --log-failed`; diagnose root cause.
2. Post initial failure comment on the original PR with details and run
   link — announce, then `gh pr comment`.
3. **One attempt.** Stop (end turn; user re-invokes `/pr`) on the same
   conditions as CI_FAILED step 2.
4. `git checkout -b fix/<branch>-ci`; apply the fix via Edit/Write.
5. **Verify** (same rule as CI_FAILED step 3): `pre-commit` mandatory;
   build/test if CLAUDE.md fenced block present.
6. Post the summary block (same format as CI_FAILED step 4).
7. Announce, then run `git commit -m "<message>" && git push -u origin fix/<branch>-ci && gh pr create --title "<title>" --body "<body>"`
   as one Bash call — one prompt covers commit, push, PR create.
8. Post fix-PR follow-up comment on the original PR (link to fix PR) —
   announce, then `gh pr comment`.
9. Comment on linked issue: "PR #N merged, post-merge CI failed:
   `<summary>`. Fix PR: #M" — announce, then `gh issue comment`.

### POST_MERGE_TESTING

1. Process `### Post-merge` items:
   - Verify remotely if possible (query endpoint, check logs) → check off
   - Needs manual human action → leave unchecked
2. Update PR body: `gh pr edit <number> --body`
3. Report which items still need manual testing. Tell user to test them and run `/pr <number>` again.

### MERGED_DONE

1. Comment on PR: "All checks passed post-merge, all test plan items verified."
2. Identify linked issue ("Part of #N"). If found:
   - Comment: "PR #N merged, all post-merge checks passed."
   - Remind user: "Link this PR in the issue's Development sidebar (no API
     for this)"
3. **Acceptance criteria**:
   - Fetch the issue body: `gh issue view <number> --json body`
   - Look for acceptance criteria checkboxes (`- [ ]` / `- [x]`)
   - If any AC are unchecked:
     - For each, determine if this PR's changes satisfy it → check off with
       `gh issue edit <number> --body`
     - If any still unchecked after this, report them. Do NOT move the
       issue. STOP.
   - If all AC are checked: remind user to update the board manually

## Rules

_Output, prompt announcements, re-verification._

- **Announce before prompting commands.** For commands that trigger native
  prompts (commits, pushes, merges, PR/issue create / edit / comment),
  output a one-line intent announcement immediately before the Bash call
  so the prompt has full context (e.g. "Merging PR #NNN — approve prompt").
- Terminal output (status, CI summaries): use plain `path:line` format for
  file references
- GitHub content (PR body, comments, issue edits): use markdown links
  `[file.cs:42](path/to/file.cs#L42)`
- **Test plan re-verification**: If code changes after a test plan item was
  checked off, uncheck it and re-verify before offering to merge.
