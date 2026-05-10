# Rules

- When I ask a question, just answer it — do not take action unless I ask
- When a constraint drives complexity, verify it still holds before building workarounds
- NEVER use inline scripts (`bash -c`, `python -c`, `node -e`, heredocs, here-strings, or any `<lang> -c/-e` form) — use Read/Edit/Grep/Glob; if no built-in fits, ask first
- Never dismiss review findings based on project size, MVP status, or user count — evaluate each on its own merit
- Format questions for single-keystroke answers: y/n, or a/b/c lettered options. Avoid open-ended "do you want X or Y?" phrasings.

## Bash

- PreToolUse hook splits on `&&`, `||`, `;`, `|`, and newlines and checks each segment independently. Pipelines and chains auto-approve when every segment is allow-listed — compose freely (e.g. `gh pr list --json … | jq …`, `git log --oneline | head`).
- Allow-listed text tools to compose with: jq, grep, sed, head, tail, sort, uniq, wc, cut, diff.
- Wrapper commands `time`, `nice`, `env` (binary form), `command`, `exec`, `ionice`, `taskset` are peeled — the inner command is what's checked. `sudo`/`doas` are not peeled (privilege escalation always prompts).
- `xargs [FLAGS] CMD` is peeled — `CMD` is what's checked, with positional args attached. `xargs sh -c '…'` / `bash -c` / `python -c` / `awk` still prompt (the executor is what's checked). Unknown long flags bail rather than mis-parse.
- Forms that still always prompt: `sh -c '…'`, `bash -c '…'`, `python -c '…'`/`python -m …`, `node -e '…'`, heredocs feeding an interpreter, here-strings. The _executor_ is what's checked, not the heredoc/string.
- Native ASK overrides hook-allow. If an all-allow-listed chain still prompts, check `~/.claude/settings.json` `ask` for a broader pattern catching one segment.
- Debug with `SMART_APPROVE_VERBOSE=1` — appends per-segment match info to `~/.claude/logs/smart_approve.log`. `tail`/`grep` it to see which segment didn't match. Note: command previews land in the log unredacted, so don't enable while running commands with secrets in args.
- `gh api` reads must include `-X GET` or `--method GET` — bare `gh api PATH` prompts.
- Quiet flags only on builds/tests where success is the only signal: dotnet build -v quiet, dotnet test -v quiet, npm run --silent. Failures still surface errors. Default verbosity while iterating.
- Don't pre-truncate exploratory output with `head -n 5` / `tail -n 20` — too-small first window forces a re-run, paying twice. Read full output once; truncate once you know the shape.
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
