# GitHub Rules

## Pull Requests

### Format

- **What** -- brief summary of the change.
- **Why** -- motivation or linked issue (`Closes #123`).
- **How** -- notable implementation details, only if non-obvious.

### Test Plan

The PR test plan documents verifications already performed during commits:

- Identify test steps based on what changed (build, tests, config apply, scripts, etc.)
- Execute verifiable steps before committing
- Mark completed items `[x]`, leave `[ ]` only for manual/GUI/user-specific verification
- If a test fails, fix before committing -- don't document failures in the PR

### Merging

- Squash and merge: `gh pr merge --squash --delete-branch`
- Use merge commit only when preserving individual commits matters

## Issues

- Title: concise, imperative mood (e.g., "Add rate limiting to auth endpoint").
- Use `gh issue` for creating and managing issues.
- Apply labels when applicable.

## CLI Patterns

- Prefer `gh` CLI over web UI for automation.
- For API access: `gh api repos/{owner}/{repo}/...`
- For file contents: use `raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` directly
