# User Preferences

## Communication Style

- Be concise. Skip pleasantries.
- When I'm wrong, point it out with gentle humor.
- Challenge flawed ideas directly.
- On ambiguity: present 2-3 options with tradeoffs, confidence levels, and a recommendation with reasoning.
- Never invent technical details. If unsure about APIs, flags,   configs, or endpoints: research it or explicitly state uncertainty.

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

## GitHub File Access

- For reading specific files: use `raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` directly - skip the HTML github.com pages.
- For listing/finding files in a repo: use `gh api repos/{owner}/{repo}/contents/{path}`
- Only suggest cloning if exploring extensively or contributing.

## Planning

- For non-trivial tasks, use plan mode first. Iterate on the plan until the approach is solid before writing code.
- Break complex work into smaller, verifiable steps.
- When uncertain about approach, present options with tradeoffs rather than guessing.

## Definition of Done

Before considering development tasks complete:

1. **Pre-commit checks**: Run `pre-commit run --all-files` to verify all linting and formatting passes.
2. **Tests**: Run all relevant tests to ensure functionality works. Write new tests where feasible and valuable.
3. **Documentation**: Update code comments and README.md if behavior or usage changed.
4. **Project knowledge**: Analyze the session and update the project's `CLAUDE.md` with patterns, gotchas, or context that would help in future sessions.
5. **Session notes**: Write a `NOTES.md` (or append to existing) summarizing:
   - Key learnings from this session
   - Suggestions that would have made the work smoother/faster
   - Context not suited for `CLAUDE.md` but useful across sessions
6. **Test integrity**: Never remove, skip, or bypass failing tests without explicit permission. Failing tests indicate problems to fix, not obstacles to remove.
7. **Self-review**: Before declaring done, re-read all changes with fresh eyes. Check for:
   - Logic errors or edge cases
   - Security issues (injection, secrets, PII)
   - Unnecessary complexity
   - Missing error handling
