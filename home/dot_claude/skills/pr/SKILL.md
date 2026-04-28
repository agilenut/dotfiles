---
name: pr
description: "Use when user says /pr, asks about PR status, wants to create/merge a PR, or needs help with CI failures on a PR"
user-invocable: true
argument-hint: "[pr-number]"
---

# PR Lifecycle Skill

Manage the full PR lifecycle based on current state. Optionally accepts a PR number as argument.

## Step 1: Determine State

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

To distinguish CI_PASSED vs PRE_MERGE_TESTING and POST_MERGE_TESTING vs MERGED_DONE: read the PR body and check for unchecked items (`- [ ]`) in the relevant test plan section.

## Step 2: Act on State

### DIRTY

- Show `git diff --stat`, ask if user wants to commit and push
- If yes: craft commit message, commit, push (use `-u origin <branch>` if no upstream)
- Re-run state detection

### NO_PR

- `git log --oneline main..HEAD` to summarize commits
- Select one label based on the primary nature of the change. Check which labels exist in the repo (`gh label list --json name`) and use the best match:
  - `enhancement` — new feature, new capability, new test suite
  - `bug` — something was broken and this fixes it
  - `security` — security fix or hardening
  - `infrastructure` — CI/CD, workflows, deploy, infra scripts, Bicep, test maintenance (if label exists)
  - `documentation` — docs-only changes (if label exists)
  - No label if none of the above apply
- Draft PR: short title (<70 chars), `## Summary` bullets
- `## Test Plan` — only include if there are items. Items are things not already covered by CI (don't list "tests pass", "build succeeds", "deploy succeeds").
  - `### Pre-merge` — only include if there are pre-merge items
  - `### Post-merge` — only include if there are post-merge items
  - Omit `## Test Plan` entirely if neither section has items
- Link issue: "Part of #N" (NEVER Closes/Fixes)
- `gh pr create` (include `--label <label>` if a label was selected), then re-run state detection

### CI_RUNNING

1. `gh pr checks <number>`
2. No checks reported → poll once after 30s → if still none, transition to CI_PASSED
3. In progress → poll up to 5× with 30s sleep
4. Still running → suggest `/pr` later
5. Done → transition to CI_PASSED/PRE_MERGE_TESTING or CI_FAILED

### CI_FAILED

1. `gh pr checks <number>` to identify failures
2. `gh run view <run-id> --log-failed` for logs
3. Summarize what failed and why
4. Offer to investigate and fix

### PRE_MERGE_TESTING

1. **Re-verify checks complete.** `gh pr checks <number>` — confirm all passed/skipped. If any still running, transition to CI_RUNNING.
2. Read PR body, process `### Pre-merge` items:
   - Verify locally if possible (run script, check file) → check off
   - Needs deploy → leave for post-merge
   - Needs manual human action → leave unchecked
3. NEVER check off `### Post-merge` items
4. Update PR body: `gh pr edit <number> --body`
5. Report which items still need manual testing. Tell user to test them and run `/pr` again.

### CI_PASSED

1. **Re-verify checks complete.** `gh pr checks <number>` — confirm all passed/skipped. If any still running, transition to CI_RUNNING.
2. All pre-merge items verified (or no pre-merge section). Offer to merge.
3. If user approves: `gh pr merge <number> --squash --delete-branch` → re-run state detection

### MERGED_CI_RUNNING

1. `gh run list --branch main` filtered to runs created after `mergedAt` — `gh pr checks` only shows branch checks, not post-merge workflows
2. No runs → poll once after 30s → if still none, transition to POST_MERGE_TESTING or MERGED_DONE
3. In progress → poll up to 5× (30s interval)
4. Still running → suggest `/pr <number>` later
5. Done → transition to MERGED_CI_FAILED, POST_MERGE_TESTING, or MERGED_DONE

### MERGED_CI_FAILED

1. `gh run view <run-id> --log-failed`
2. Investigate, comment on PR with failure details and run link
3. Offer to fix: create `fix/<branch>-ci`, push, new PR, update PR comment with fix link
4. Comment on linked issue: "PR #N merged, post-merge CI failed: `<summary>`. Fix PR: #M"

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
   - Remind user: "Link this PR in the issue's Development sidebar (no API for this)"
3. **Acceptance criteria**:
   - Fetch the issue body: `gh issue view <number> --json body`
   - Look for acceptance criteria checkboxes (`- [ ]` / `- [x]`)
   - If any AC are unchecked:
     - For each, determine if this PR's changes satisfy it → check off with `gh issue edit <number> --body`
     - If any still unchecked after this, report them. Do NOT move the issue. STOP.
   - If all AC are checked: remind user to update the board manually

## Rules

- Terminal output (status, CI summaries): use plain `path:line` format for file references
- GitHub content (PR body, comments, issue edits): use markdown links `[file.cs:42](path/to/file.cs#L42)`
- **Test plan re-verification**: If code changes after a test plan item was checked off, uncheck it and re-verify before offering to merge.
