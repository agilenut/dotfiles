---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/package.json"
  - "**/tsconfig.json"
---

# TypeScript / JavaScript Archetype

## New Project Setup

When creating a new TS/JS project, always set up:

- `.editorconfig` (2-space indent, no Makefile section)
- `.vscode/extensions.json` and `.vscode/settings.json`
- `.prettierrc`
- `eslint.config.js` (v9 flat config)
- `.markdownlint.yaml` (MD013: false)
- `.pre-commit-config.yaml` (NOT Husky)
- `.gitignore` (per gitignore management rules)

## Formatting & Linting

- Formatter: Prettier
- Linter: ESLint (v9+ flat config)

## Pre-commit Hooks

Use pre-commit (Python), not Husky:

- prettier
- eslint
- tsc --noEmit (type check)
- npm run build (if build script exists)
- npm run test (if test script exists)
- markdownlint
- gitleaks

## Testing

- Use Vitest or Jest
- File patterns: `*.test.ts`, `*.spec.ts`, `__tests__/`
- Prefer describe/it blocks
