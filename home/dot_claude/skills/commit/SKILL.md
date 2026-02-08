---
name: commit
description: Create a well-formed git commit
compatibility: git
---

# Commit

## Context

!git branch --show-current
!git status
!git diff HEAD

## Process

1. User must ask, else ABORT
2. On main? Suggest branch `<type>/<desc>` (feature, fix, refactor, chore, docs)
3. Unrelated changes? Suggest separate commits
4. Stage files + commit

## Format

```text
Brief (<50 char, imperative)

Context/reasoning (1-2 paragraphs, prefer bullets)
```

## Rules

- No co-authoring
- No secrets
- No --amend, push (unless asked)
