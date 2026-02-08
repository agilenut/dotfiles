# User Preferences

## Communication Style

- Be concise. Skip pleasantries.
- When I'm wrong, point it out with gentle humor.
- Challenge flawed ideas directly.
- On ambiguity: present 2-3 options with tradeoffs, confidence levels, and a recommendation with reasoning.
- Never invent technical details. If unsure about APIs, flags, configs, or endpoints: research it or explicitly state uncertainty.

## Planning

- For non-trivial tasks, use plan mode first. Iterate on the plan until the approach is solid before writing code.
- Break complex work into smaller, verifiable steps.
- When uncertain about approach, present options with tradeoffs rather than guessing.

## Definition of Done

Before considering development tasks complete:

1. **Pre-commit checks**: Run `pre-commit run --all-files`
2. **Tests**: Run relevant tests. Write new tests for new functionality.
3. **Documentation**: Update README.md and code comments if behavior changed.
4. **Project knowledge**: Update project CLAUDE.md with patterns/gotchas.
5. **Test integrity**: Never remove/skip failing tests without permission.
6. **Self-review**: Re-read changes for logic errors, security, complexity.

### Session Completion

- **Session notes**: Write/append NOTES.md with learnings and suggestions.
- **Retro consideration**: For significant sessions with lessons learned, suggest /retro. User can trigger manually at any time.

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

### Linting & Static Analysis

- Never disable, suppress, or modify EditorConfig, StyleCop, ESLint, or analyzer rules without asking first.
- If a build fails due to linting errors, fix the code—don't suppress the warning.
- Approved suppressions (apply without asking):
  - Markdown: MD013 (line length)

### Comments

- Explain _why_, not _what_.
- Never reference previous versions ("was X, now Y").

## Data Safety

- Avoid data loss. Confirm before destructive operations.
- Prefer soft deletes or backups where appropriate.
- **Files outside current repo** (not under source control): Show proposed diff and get approval before editing.

## Debugging

- Find the root cause. Never fix symptoms or add workarounds.

## New Project Setup

When creating a new repository:

1. Initialize git with language-appropriate .gitignore (`/gitignore` skill)
2. Create `.editorconfig` (`/editorconfig` skill)
3. Create `.vscode/extensions.json` and `.vscode/settings.json` (`/vscode` skill)
4. Set up linting (ESLint, StyleCop, shellcheck as appropriate)
5. Set up formatting (Prettier, CSharpier, shfmt as appropriate)
6. Create `.pre-commit-config.yaml` (`/pre-commit` skill)
7. Create `.markdownlint.yaml` with `MD013: false`
