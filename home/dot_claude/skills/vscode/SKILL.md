---
name: vscode
description: Create/update .vscode/settings.json and extensions.json
---

# VSCode

## Context

!pwd && test -d .vscode && echo ".vscode exists" || echo "no .vscode"

## Process

1. Detect languages
2. Merge JSON (requires jq) from assets/:
   - Settings: `jq -s '.[0] * .[1]' assets/base-settings.json assets/{lang}-settings.json`
   - Extensions: `jq -s '{recommendations: (.[].recommendations | add | unique)}' assets/*-extensions.json`
3. Multi-language: merge all
