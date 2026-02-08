---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.zsh"
---

# Shell Archetype

## New Project Setup

When creating a shell-focused project:

- `.editorconfig` (2-space indent, shfmt settings)
- `.vscode/extensions.json` and `.vscode/settings.json`
- `.pre-commit-config.yaml`
- `.markdownlint.yaml` (MD013: false)
- `.gitignore` (per gitignore management rules)

## Linting Notes

- shellcheck does not fully support zsh
- Exclude zsh files from shellcheck or accept limitations
