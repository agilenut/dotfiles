---
name: pr
description: Pull request conventions. Use when creating, updating, or merging pull requests.
user-invocable: true
disable-model-invocation: false
---

# Pull Requests

## Format

**What** -- brief summary
**Why** -- motivation or linked issue (`Closes #123`)
**How** -- only if non-obvious
No "Generated with Claude Code" or similar footers

## Test Plan

Documents verifications performed during commits
Mark completed `[x]`, leave `[ ]` for manual/user-specific
Fix failures before committing

## Merging

Default: `gh pr merge --squash --delete-branch`
