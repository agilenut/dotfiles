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
- **Local checks** (see Reference: Local Checks). A failing check stops PR
  creation: one fix attempt under CI_FAILED step 2's stop conditions,
  commit (DIRTY), and re-run state detection.
- **The issue.** Take its number from the plan's `stories:` or PR table,
  the branch name, or the commits; if none, ask. A PR the global rules
  exempt from needing an issue (small doc or text fix, security patch,
  dependency update) skips the AC status step and says "No issue
  (exempt: dependency update)" or similar in the body.
- **AC status.** Read the issue's ACs (`gh issue view <N> --json body`)
  and give each one status: met by this PR (name the test or behavior),
  covered by a later PR (name it), or uncovered. An uncovered AC stops PR
  creation: add the work to this PR, or propose a split or an AC change
  under the global AC rules, then re-run state detection once the user
  decides. If the issue has no ACs, propose some first.
- **Plan follow-ups.** If a plan governs this PR and it is the plan's last
  unmerged PR, read the plan's Open items. Each follow-up must already
  have joined a planned PR, have an issue the user agreed to, or have been
  dropped with the user's OK. Any left → raise them before creating the
  PR.
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
- Draft PR: short title (<70 chars), `## Summary` bullets, and an
  `## Acceptance criteria status` table (each AC and its status from
  above; omit for an exempt PR)
- `## Test Plan` — only include if there are items. Items must be
  not already covered by CI (don't list "tests pass", "build succeeds",
  "deploy succeeds"), and checkable within a day of merging; evidence
  that needs days (prod metrics, someone's feedback) becomes its own
  issue, not a test-plan item. The project's `board-settings` memory
  (`Staging/device testing`) says how it verifies after merge; use it for
  post-merge items. For each candidate, walk this decision tree:

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

- Link the issue per CLAUDE.md `## Issues and board` referencing rules:
  "Closes #N" when the user asks, or where the project's `board-settings`
  memory says auto-close on merge is off (it links the PR without closing
  the issue); otherwise "Part of #N". No `board-settings` yet → the
  `board` skill's Step 1 creates it.
- `gh pr create` (include `--label <label>` if a label was selected), then
  re-run state detection

### CI_RUNNING

1. **Fire-and-forget; do not poll.** `gh pr checks <number> --watch` via
   Bash with `run_in_background: true`. System notifies on exit.
2. **Read the verdict, not the exit code.** On notification, run
   `gh pr checks <number> --json bucket --jq '[.[].bucket] | unique'`.
   The watch is a wake-up trigger only.
   - `[]` (no checks) → CI_PASSED (treat as no CI)
   - Contains `fail` or `cancel` → CI_FAILED
   - Contains `pending` → re-fire the watch. After 3 consecutive pending
     re-fires, surface to user.
   - Only `pass` / `skipping` → CI_PASSED/PRE_MERGE_TESTING
   - Anything else (unrecognized values, read errors) → surface to user

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
   clean; auto-runs where allow-listed, may prompt in other repos), then
   the Local Checks (Reference below); none found → note "local checks:
   none found".
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

1. `gh run list --branch main --created '><mergedAt>' --json databaseId,name` —
   substitute `<mergedAt>` with the ISO timestamp from step 1's JSON
   (post-merge workflows don't show in `gh pr checks`).
2. No runs → transition to POST_MERGE_TESTING or MERGED_DONE.
3. **Fire-and-forget; do not poll.** For each `databaseId` from step 1:
   `gh run watch <id> --exit-status` via Bash with `run_in_background: true`.
   Spawn in parallel; system notifies per process exit.
4. **Read the verdict, not the exit code.** On each notification, run
   `gh run view <id> --json status,conclusion --jq '{status,conclusion}'`.
   The watch is a wake-up trigger only.
   - `status != "completed"` → re-fire the watch. After 3 consecutive
     re-fires, surface to user.
   - `conclusion` is `success`, `skipped`, or `neutral` → remove from
     pending. When empty, transition to POST_MERGE_TESTING or MERGED_DONE.
   - `conclusion` is `failure`, `cancelled`, `timed_out`, `startup_failure`,
     or `stale` → MERGED_CI_FAILED. Other watches keep running; their
     notifications can be ignored. Dump per-job conclusions to name the
     failure:
     `gh run view <id> --json jobs --jq '.jobs[] | select(.conclusion != "skipped") | {name, conclusion}'`
   - Anything else (`action_required`, unknown values, read errors) →
     surface to user

### MERGED_CI_FAILED

1. `gh run view <run-id> --log-failed`; diagnose root cause.
2. Post initial failure comment on the original PR with details and run
   link — announce, then `gh pr comment`.
3. **One attempt.** Stop (end turn; user re-invokes `/pr`) on the same
   conditions as CI_FAILED step 2.
4. `git checkout -b fix/<branch>-ci`; apply the fix via Edit/Write.
5. **Verify** (same rule as CI_FAILED step 3): `pre-commit` mandatory,
   then the Local Checks.
6. Post the summary block (same format as CI_FAILED step 4).
7. Announce, then run `git commit -m "<message>" && git push -u origin fix/<branch>-ci && gh pr create --title "<title>" --body "<body>"`
   as one Bash call, so one prompt covers commit, push, and PR create. The body
   references the original PR's issue the same way the original PR did
   ("Closes" or "Part of #N") and skips the AC status table: the fix
   restores CI for work already reviewed.
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

MERGED_DONE can be re-entered (`/pr` run again on a merged PR); skip any
step whose comment already exists.

1. Comment on PR: "All checks passed post-merge, all test plan items
   verified." Skip if that comment is already on the PR.
2. For each issue the PR references ("Closes", "Fixes", or "Resolves #N",
   or "Part of #N"), run the `board` skill's "Close out after a PR
   merges", in this session. On re-entry it skips the parts already done
   and still runs the last-column check.
3. For each issue, compare its ACs with this PR's "Acceptance criteria
   status" table. Report only the ACs this PR was meant to meet that are
   still unchecked, and any AC no PR covers. ACs a later PR covers are not
   gaps. A PR with no status table (opened before it existed): report the
   unchecked ACs and ask which belong to this PR.
4. **Sidebar reminder**, only when the PR isn't already linked (it used
   "Part of", not a closing keyword). One line, naming both sides:
   `Reminder: link PR #<pr> to issue #<N> in the sidebar if wanted.`
   (list several PRs or issues with commas). Say nothing about the API.

## Reference: Local Checks

_The repo's own checks, used by NO_PR, CI_FAILED, and MERGED_CI_FAILED._

In the repo's CLAUDE.md, use the first that exists:

1. The fenced bash block under `## Before a PR`.
2. A fenced bash block under `## Testing`, `## Build`, or
   `## Development` that runs tests, lint, or a build. Skip commands that
   start servers, watchers, or bootstrap steps.
3. None → note "local checks: none found" and continue; CI is the gate.

This skill never names a project's commands; the repo's CLAUDE.md does.

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
