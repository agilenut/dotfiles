---
name: review
description: "Use when reviewing code: before committing, before merging, when user says /review, or when user asks to review changes or a PR"
user-invocable: true
---

# Review Orchestrator

Spawn isolated reviewer agents, collect findings, present consolidated summary.

## Step 1: Detect Scope and Reviewer Selection

### Scope (first non-reviewer argument wins)

- `/review branch` → branch mode: `main..HEAD`
- `/review pr` → PR mode: PR diff
- `/review unreviewed` → unreviewed mode: uses `.last-reviewed.json` entry (fail if no entry for branch)

Default precedence (no scope argument):

1. Run `git status` and `git diff --stat`
2. If uncommitted changes → local mode
3. If clean → read `.reviews/code/.last-reviewed.json` and check for current branch entry
4. If entry exists and `git log <sha>..HEAD` has commits → unreviewed mode
5. Else → `gh pr view --json number,title,baseRefName`
6. If PR exists → PR mode
7. Else → branch mode (`main..HEAD`)
8. If on main with no changes → nothing to review

### Reviewer selection

Arguments can include reviewer names: `security`, `ux`, `ai`. These combine with scope arguments in any order.

- `/review ai` → auto-detect scope + force AI reviewer on (in addition to base + auto-detected)
- `/review branch security ai` → branch mode + force security and AI on
- `/review only ai` → auto-detect scope + run ONLY the AI reviewer
- `/review only security ai` → run ONLY security and AI reviewers
- `/review pr only ux` → PR mode + run ONLY the UX reviewer

Rules:

- Without `only`: named reviewers are added to the defaults (base is always included, others are auto-detected from the diff)
- With `only`: run ONLY the explicitly named reviewers — skip base and auto-detection
- Reviewer arguments and scope arguments can appear in any order

## Step 2: Gather Context

Collect these to pass to reviewers in the Agent prompt:

- Read `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md` (conventions)
- `git log --oneline -10` (intent context)

PR mode additionally:

- `gh pr view <number> --json body`
- `gh pr diff <number>`

Local mode:

- `git diff` + `git diff --cached`

Unreviewed mode:

- Read current branch's SHA from `.reviews/code/.last-reviewed.json`
- `git diff <sha>..HEAD`

Branch mode:

- `git diff main..HEAD`

## Step 3: Spawn Reviewers (MUST use Agent tool — do NOT inline)

You MUST use the Agent tool here. Do NOT perform the reviews yourself.

### Auto-detection (skip if `only` was used)

Scan the diff to determine which reviewers to auto-include. Base is always included.

**Security — include if the diff touches any of:**

- Paths/filenames containing: `auth`, `login`, `session`, `token`, `credential`, `permission`, `policy`, `middleware`, `security`, `crypto`
- Dependency manifests: `package.json`, `package-lock.json`, `*.csproj`, `pyproject.toml`, `requirements.txt`, `Gemfile`, `go.mod`
- Infrastructure: Dockerfiles, CI/CD workflows, deployment configs
- Config: `.env*`, `appsettings*.json`, connection strings, CORS/CSP/header settings
- Database: migrations, schema changes
- Middleware pipeline: `Program.cs`, `Startup.cs`
- Diff text containing: `password`, `secret`, `api_key`, `encrypt`, `hash`, `salt`, `certificate`
- Auth in diff: `[Authorize]`, `[AllowAnonymous]`, `ClaimsPrincipal`, `HttpContext.User`, `AddAuthentication`, `AddAuthorization`, `UseAuthentication`, `UseAuthorization`
- Input handling in diff: `req.body`, `req.params`, `req.query`, `FromBody`, `FromQuery`, `request.form`, `request.json`, `IFormFile`
- Unsafe patterns in diff: `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `Html.Raw`, `HtmlString`, `raw(`, `eval(`, `exec(`, `deserialize`, `pickle`
- SQL in diff: `SqlCommand`, `FromSqlRaw`, `ExecuteSqlRaw`, `execute(`, raw query construction
- File/URL handling in diff: `upload`, `multipart`, `redirect(`, `DataProtection`, path construction from user input

**UX — include if any UI files in the diff:**

`.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.html`

**AI — include if any AI files in the diff:**

- Agent definitions (`agents/*.md`) or skill definitions (`skills/**/SKILL.md`)
- Prompt templates: `.yaml`/`.yml` files with keys like `prompts:`, `system:`, `temperature:`, `max_tokens:`, `messages:`, `model:`
- Files in directories named `prompt*`, `eval*`, `llm*`
- Python/JS/TS files importing `openai`, `anthropic`, `claude_agent_sdk`
- Files containing `response_format`, `structured_output`, or `ChatCompletion` in the diff
- LLM test case files (YAML/JSON with scoring assertions, tolerance bands)

### Spawn

Based on the reviewer selection (auto-detection, or `only` list):

- `subagent_type: "base-reviewer"` — pass conventions, git log, and diff
- `subagent_type: "security-reviewer"` — pass conventions and diff
- `subagent_type: "ux-reviewer"` — pass conventions and diff
- `subagent_type: "ai-reviewer"` — pass conventions, git log, and diff

Spawn all selected reviewers in one message (parallel Agent calls).

Include in each Agent prompt:

- The branch name and output path: `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-<type>.md` — run `date +%Y-%m-%d-%H%M%S` to get the timestamp, do NOT hardcode it
- The full diff
- The CLAUDE.md contents

Wait for all agents to complete before proceeding.

## Step 4: Consolidate and Triage

After all subagents finish:

1. Read review files from `.reviews/code/`
2. Triage: read the actual code around each finding and form your own opinion on which are worth fixing
3. Present using this exact format. Use plain `path:line` format for all file references (not markdown links).

```markdown
## Review: <branch> (<mode>)

**Base:** <VERDICT> — <N> critical, <N> important, <N> suggestions
**Security:** <VERDICT> — <N> critical, <N> warnings
**UX:** <VERDICT> — <N> critical, <N> important, <N> suggestions, <N> commendations
**AI:** <VERDICT> — <N> critical, <N> important, <N> suggestions

### Findings

1. **[Critical]** path/to/file.cs:42 (reviewer)
   Description of what's wrong and why it matters.
   **Fix:** why this needs action

2. **[Important]** path/to/file.cs:42 (reviewer)
   Description of what's wrong and why it matters.
   **Skip:** why this is acceptable as-is

...continue single continuous numbering across all severities and reviewers...

Recommended: 1, 3, 5

Full reports:
.reviews/code/<timestamp>-<branch>-base.md
.reviews/code/<timestamp>-<branch>-security.md
.reviews/code/<timestamp>-<branch>-ux.md
.reviews/code/<timestamp>-<branch>-ai.md
```

Format rules:

- ONE continuous numbered list — never restart numbering
- Order: critical first, then important, then suggestions
- Each finding is a mini-block: severity + location + reviewer on line 1, description on line 2, Fix/Skip verdict on line 3
- Separate findings with a blank line so they render as a loose list (paragraph spacing between items)
- **Fix** = you recommend acting on it. **Skip** = noted but not worth fixing, with reason
- Recommended line at the end lists only the Fix item numbers
- Only show verdict lines and report links for reviewers that actually ran
- Use plain `path:line` format for ALL file references — repo-relative for project files (e.g. `api/src/Foo.cs:42`), `~/` for files outside the repo (e.g. `~/.claude/hooks/foo.sh:10`). Never use markdown link syntax.

## Step 5: Update Review Marker

After presenting findings, update `.reviews/code/.last-reviewed.json` — a single JSON object mapping branch names to SHAs. Read the existing file first (if it exists), add or update the current branch's entry, and write back. Create the file if it doesn't exist.

## Rules

- NEVER make code changes — only analyze and report
- Do NOT run mkdir for output directories — Write creates intermediate directories automatically
- If diff >500 lines, tell user and offer to focus on specific files
- PR mode: check `gh pr checks <number>` and mention failures
