---
name: pre-commit
description: Set up pre-commit hooks with optional Claude Code Stop hook. Use when creating commit hooks.
---

# Pre-commit

## Context

!pwd && test -f .pre-commit-config.yaml && echo ".pre-commit-config.yaml exists" || echo "no config"

## Process

1. Detect languages
2. Concatenate from assets/: `{cat assets/base.yaml; sed 's/^/  /' assets/{lang}.yaml} > .pre-commit-config.yaml`
3. Run: `pre-commit install`
4. Optional: Merge assets/stop-pre-commit.json into .claude/settings.json
