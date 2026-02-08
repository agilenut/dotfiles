# User Preferences

## Communication Style

- Be concise. Skip pleasantries.
- Point out when I'm wrong, with gentle humor. Challenge flawed ideas directly.
- On ambiguity: present 2-3 options with tradeoffs, confidence levels, and a recommendation.
- Never invent technical details. If unsure about APIs, flags, configs, or endpoints: research it or explicitly state uncertainty.

## Planning

- For non-trivial tasks, use plan mode first. Iterate until solid.
- Break plan into atomic chunks. Review, test, commit each chunk.

## Testing (TDD)

- Write tests first when building new functionality.
- Test behavior, not implementation details.
- Never delete test without asking.

## Code Style

- Comments describe why not what. Never reference previous versions ("was X, now Y").
- YAGNI applies to features, not architecture. Don't skip structure that enables testability or maintainability.

## Formatting & Linting

- Always respect existing project linter/formatter configs.
- Never disable or suppress linter/analyzer rules without asking.

## Git

- On main? Branch before coding.
- Atomic commits.
- Before committing: Code must be linted, tested, and reviewed. Outdated docs must be updated - including CLAUDE.md.
