---
name: gitignore
description: Create/update .gitignore with language and OS patterns
compatibility: git
---

# Gitignore

## Context

!pwd
!test -f .gitignore && echo "exists" || echo "no .gitignore"

## Process

1. Detect languages → Generate: `dotnet new gitignore`, `npx gitignore <lang>`
2. Multi-language: merge, dedupe
3. Append missing from assets/ : ide.txt, secrets.txt, macos.txt, windows.txt
4. Prune legacy, dedupe

## Section Order

Lang/Framework → Testing → IDE → Secrets → OS
