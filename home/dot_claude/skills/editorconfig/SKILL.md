---
name: editorconfig
description: Create/update .editorconfig for detected languages
---

# EditorConfig

## Context

!pwd
!test -f .editorconfig && echo ".editorconfig exists" || echo "no .editorconfig"

## Process

1. Detect languages from files (.cs, .ts, .sh, etc.)
2. Concatenate base + language templates: `cat assets/base.ini assets/{lang}.ini > .editorconfig`
3. Only add sections for file types that exist
