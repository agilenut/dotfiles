---
name: shell-conventions
description: Shell scripting conventions. Use when writing, editing, or reviewing .sh, .bash, .zsh files, Makefiles, CI scripts, or shell one-liners.
user-invocable: true
disable-model-invocation: false
---

# Shell Scripts

## Design

- `set -euo pipefail` at the top of every bash script.
- Prefer functions over inline logic for anything beyond 10 lines.
- Use `local` for function variables.
- Quote all variable expansions: `"${var}"` not `$var`.
- Use `[[` over `[` for conditionals.

## Linting

- shellcheck does not fully support zsh. Exclude zsh files or accept limitations.
- shfmt with project `.editorconfig` settings.
- No inline shellcheck disables without a comment explaining why.
