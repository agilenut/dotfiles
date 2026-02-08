# GitHub Rules

## Pull Requests

### Formatting

- No "Generated with Claude Code" or similar footers

### Test Plan

The PR test plan documents verifications already performed during commits:

- Identify test steps based on what changed (build, tests, config apply, scripts, etc.)
- Execute verifiable steps before committing (per git.md pre-commit verification)
- In PR description: mark completed items `[x]`, leave `[ ]` only for manual/GUI/user-specific verification
- If a test fails, fix before committing - don't document failures in the PR

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
