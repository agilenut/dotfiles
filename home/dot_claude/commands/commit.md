---
description: Create a well-formed git commit
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

Create a commit for the current changes.

## Process

1. Run `git status` and `git diff` to understand changes
2. Run `git log -5 --oneline` to match commit style
3. Stage appropriate files (ask if unclear what to include)
4. Write commit message following this format:

```
Brief summary (imperative mood, <50 chars)

Context and reasoning in 1-2 short paragraphs.
```

## Rules

- Never commit secrets, .env files, or credentials
- Ask before committing if changes seem unrelated
- Don't use --amend unless explicitly requested
- Don't push unless explicitly requested
