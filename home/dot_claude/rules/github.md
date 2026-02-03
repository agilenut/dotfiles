# GitHub Rules

## Pull Requests

### Test Plan

Before submitting a PR, attempt to execute each test step yourself:

- Mark completed items with `[x]`
- Leave unchecked `[ ]` only for steps requiring manual interaction, GUI verification, or user-specific context
- If a test step fails, fix the issue before submitting

### Merging

- Default to squash merge: `gh pr merge --squash`
- Use merge commit only when preserving individual commits matters (e.g., large features with meaningful commit history)

## Issues

- Use `gh issue` for creating and managing issues
- Link PRs to issues with "Fixes #123" or "Closes #123" in PR description

## CLI Patterns

- Prefer `gh` CLI over web UI for automation
- For API access: `gh api repos/{owner}/{repo}/...`
- For file contents: use `raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` directly
