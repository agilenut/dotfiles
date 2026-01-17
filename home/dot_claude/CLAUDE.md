# User Preferences

## Communication Style

- Be concise. Skip pleasantries.
- When I'm wrong, point it out with gentle humor.
- Challenge flawed ideas directly.
- On ambiguity: present 2-3 options with tradeoffs, confidence levels, and a recommendation with reasoning.
- Never invent technical details. If unsure about APIs, flags, configs, or endpoints: research it or explicitly state uncertainty.

## Code Quality

### General

- Clean, readable code. Follow SOLID where appropriate. Keep code DRY.
- YAGNI applies to features, not architecture. Don't add unused functionality, but don't skip structure that enables testability, maintainability, or readability.
- Easily testable design (dependency injection, pure functions where practical).
- Fail fast with explicit errors. No silent failures.
- Make the smallest reasonable changes to achieve the goal. Don't over-engineer.
- If additional features or steps seem needed, suggest them but don't automatically do them.

### Style

- Follow project's editorconfig/linting when present.
- Match surrounding code style even if it differs from standard guides. Consistency within a file trumps external standards.
- If no enforced conventions exist, suggest enforcing them (e.g., .editorconfig or linting).

### Comments

- Explain *why*, not *what*.
- Never reference previous versions ("was X, now Y").

### Testing

- Write tests for non-trivial code. Aim for high code coverage.
- Never delete tests without asking first and explaining why.

## Security

- Treat security issues as urgent. Fix immediately.
- Never embed secrets in plain text. Use env vars, secret managers, or encrypted config.
- Never expose PII.
- Flag potential vulnerabilities during review.

## Data Safety

- Avoid data loss. Confirm before destructive operations.
- Prefer soft deletes or backups where appropriate.

## Debugging

- Find the root cause. Never fix symptoms or add workarounds.

## Git

### Workflow

- **New projects**: Suggest a repo name (allow override), init with language-appropriate .gitignore.
- **Existing folders without git**: Suggest initializing before making changes.
- **Protected branches** (main, master, develop, dev): Never commit directly. Create a feature branch first.
- **Branch naming**: Use prefixes (feature/, fix/, refactor/, etc.) and suggest a name for approval.
- **On a feature branch**:
  - Related work: continue on current branch.
  - Unrelated work: suggest committing current changes, then create a new branch.
- **Uncommitted changes before switching**: Suggest commit first.
- **Atomic progress**: When work is tested and functional, suggest committing to the feature branch.

### Rules

- No co-authoring attribution.
- Never modify history unless explicitly instructed.

### Commit Format

```text
Brief summary of change

One to two short paragraphs with context, reasoning, or details.
```

## Languages

Primary: C#, React, TypeScript, zsh, PowerShell
