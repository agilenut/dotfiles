# Rules

- When I ask a question, just answer it — do not take action unless I ask
- When a constraint drives complexity, verify it still holds before building workarounds
- NEVER use inline scripts (`bash -c`, `python -c`, `node -e`, heredocs, here-strings, or any `<lang> -c/-e` form) — use Read/Edit/Grep/Glob; if no built-in fits, ask first
- Never dismiss review findings based on project size, MVP status, or user count — evaluate each on its own merit

## Bash

- NEVER chain commands with && or | — always use separate Bash tool calls, even when the hook permits the chain
- `gh api` reads must include `-X GET` or `--method GET` — bare `gh api PATH` prompts
- Use quiet output flags: dotnet build -v quiet, dotnet test -v quiet, npm run --silent
- No global installs: `npx` for one-off commands, `pip` only inside a venv, `pipx` for CLI tools, `npm install` only in a project (never `-g`), `dotnet tool` use `--local` in projects or `--global` only outside a project

## Planning

- Break work into small, independently committable steps — one commit per step
- After completing each step, stop and ask before continuing to the next
- If implementation diverges from the plan, update the plan file before proceeding
- NEVER write out full plan content in chat — use Edit for targeted changes, then summarize what changed

### Plan Naming

- Format: `{YYYY-MM-DD}-{brief-description}.md`
- Never include story numbers in filenames
- Never use auto-generated or random filenames

### Plan Frontmatter

```yaml
---
work: "<work-stream-name>"
branch: "<branch-name-or-null>"
stories: [82, 86]
---
```

## Code

- ALWAYS look up current APIs and versions on Context7 before using a library; use web search for broader approach questions
- NEVER suppress compiler warnings or analyzer rules without asking first
- No committed secrets or credentials

## Dotnet

- Prefer 1 type per file unless they really go together (e.g. static LoggerMessages)

## Git

- Never work on main — create a feature branch first
- Never commit/push/merge/amend/force-push unless asked
- Before committing: stage files, run `pre-commit run`, re-stage if it modified anything, repeat until clean — only then `git commit`
- Each commit must build, test, and pass independently, no dead code or forward refs
- ALWAYS update docs in the same commit as code — never a separate commit
- Commit message: short summary, body with bullets explaining why
- NEVER add Co-Authored-By lines to commits
- NEVER add "Generated with Claude Code" to PRs
- NEVER use Closes/Fixes in PRs — use "Part of #123" (issue stays open for board review)
- Post merge CI failure: comment on failed PR (what broke, fix PR link) and update the issue with a running failure log

## Workspace

### Plans Directory Resolution

1. `plansDirectory` from `.claude/settings.local.json`, then `.claude/settings.json`
2. If not found and in a worktree: main tree's `.claude/settings.local.json`, then `.claude/settings.json`
3. If not found: `~/.claude/settings.json`
4. If found at any step, resolve relative to main worktree's project root (or project root if not in a worktree)
5. If not found and in a repo, check for `.plans/` at main worktree root — use if it exists
6. If not found, use `.claude/plans` at main worktree root
7. If not in a repo, use `~/.claude/plans`

### Reviews Directory

All review output goes to `.reviews/` relative to main worktree's project root: `.reviews/code/` for code reviews, `.reviews/plans/` for plan reviews. Branch review state is tracked in `.reviews/code/.last-reviewed.json`.

## Database

- EF migrations must be backward-compatible — never rename or drop columns in one step; use expand/contract

## Testing

- TDD: write test first, run it, see it FAIL, then write minimum code to pass, run again
- Arrange / Act / Assert comments
- Always build and test changes before reporting completion
- If a required tool is unavailable (e.g., Docker), fix or ask — don't skip
- NEVER change a test just to make it pass — if a test breaks, fix the code or ask me

## Context

- When editing CLAUDE.md, MEMORY.md, skills, or agents: be terse — minimum words, no explanations
- Only add or suggest rules/memory/config that genuinely change behavior — if it won't change what Claude does, don't propose it
