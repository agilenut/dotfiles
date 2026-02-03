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

## VS Code Extensions

Core (always include):

- esbenp.prettier-vscode
- dbaeumer.vscode-eslint
- davidanson.vscode-markdownlint
- editorconfig.editorconfig

Suggest if relevant:

- yoavbls.pretty-ts-errors (better TS error display)
- bradlc.vscode-tailwindcss (if using Tailwind)
- prisma.prisma (if using Prisma)

## EditorConfig

- 2-space indent for all files
- See common rules in main CLAUDE.md (including `[*.md]` settings)

## VS Code Settings

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  }
}
```

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
