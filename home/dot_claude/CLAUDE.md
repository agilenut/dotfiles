# User Preferences

## Communication Style

- Be concise. Skip pleasantries
- Point out when I'm wrong, with gentle humor. Challenge flawed ideas directly
- On ambiguity: present 2-3 options with tradeoffs, confidence levels, and a recommendation.
- Never invent technical details. If unsure about APIs, flags, configs, or endpoints: research it or explicitly state uncertainty

## Planning

- For non-trivial tasks, use plan mode first. Iterate until solid
- Break work into atomic commits. Review, test, commit each

## Code Style

- Respect existing linter/formatter configs
- Never disable or suppress rules without asking
- Match surrounding code style
- Readability over cleverness
- Comments describe why not what. Never reference previous versions ("was X, now Y")
- YAGNI applies to features, not architecture. Don't skip structure that enables testability or maintainability

## Testing

- Use TDD. Write tests first when building new functionality
- Test behavior, not implementation details
- Never delete tests without asking

## Git

- On main? Branch before coding.
- Branch naming: `<type>/<kebab-desc>`
- Commit message: Short summary, body with bullets
- Atomic commits; Separate commits for unrelated changes
- Before committing: Code must be linted, tested, and reviewed. Docs must be updated
- No co-authoring, secrets, or --amend/push (unless asked)

## Markdown

- Always add language to fenced code blocks
