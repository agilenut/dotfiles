---
name: review
description: "Use when reviewing code: before committing, before merging, when user says /review, or when user asks to review changes or a PR"
user-invokable: true
---

# Review Orchestrator

Spawn isolated reviewer agents, collect findings, present consolidated summary.

## Step 1: Detect Scope

Explicit overrides (argument provided):

- `/review branch` → branch mode: `main..HEAD`
- `/review pr` → PR mode: PR diff
- `/review unreviewed` → unreviewed mode: `_last-reviewed..HEAD` (fail if no marker)

Default precedence (no argument):

1. Run `git status` and `git diff --stat`
2. If uncommitted changes → local mode
3. If clean → check for marker file `.claude/.local/reviews/<branch>-last-reviewed`
4. If marker exists and `git log <marker-sha>..HEAD` has commits → unreviewed mode
5. Else → `gh pr view --json number,title,baseRefName`
6. If PR exists → PR mode
7. Else → branch mode (`main..HEAD`)
8. If on main with no changes → nothing to review

## Step 2: Gather Context

Collect these to pass to reviewers in the Task prompt:

- Read `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md` (conventions)
- `git log --oneline -10` (intent context)

PR mode additionally:

- `gh pr view <number> --json body`
- `gh pr diff <number>`

Local mode:

- `git diff` + `git diff --cached`

Unreviewed mode:

- Read SHA from `.claude/.local/reviews/<branch>-last-reviewed`
- `git diff <sha>..HEAD`

Branch mode:

- `git diff main..HEAD`

## Step 3: Spawn Reviewers (MUST use Task tool — do NOT inline)

You MUST use the Task tool here. Do NOT perform the reviews yourself.

**Determine if UI files are in the diff.** Check if the diff contains `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, or `.html` files. If yes, include the UX reviewer.

**Always spawn** (two Task calls in one message):

- `subagent_type: "base-reviewer"` — pass conventions, git log, and diff in the prompt
- `subagent_type: "security-reviewer"` — pass conventions and diff in the prompt

**Additionally spawn if UI files are in the diff** (add a third parallel Task call):

- `subagent_type: "ux-reviewer"` — pass conventions and diff in the prompt

Include in each Task prompt:

- The branch name and output path: `.claude/.local/reviews/<branch>-<YYYYMMDD-HHMMSS>-<type>.md`
- The full diff
- The CLAUDE.md contents

Wait for all Tasks to complete before proceeding.

## Step 4: Consolidate and Triage

After all subagents finish:

1. Read review files from `.claude/.local/reviews/`
2. Triage: read the actual code around each finding and form your own opinion on which are worth fixing
3. Present using this exact format. Use markdown links for all file references.

```markdown
## Review: <branch> (<mode>)

**Base:** <VERDICT> — <N> critical, <N> important, <N> suggestions
**Security:** <VERDICT> — <N> critical, <N> warnings
**UX:** <VERDICT> — <N> critical, <N> important, <N> suggestions, <N> commendations ← only if UX reviewer ran

### Findings

1. **[Critical]** [file:line](path#L) (reviewer)
   Description of what's wrong and why it matters.
   **Fix:** why this needs action

2. **[Important]** [file:line](path#L) (reviewer)
   Description of what's wrong and why it matters.
   **Skip:** why this is acceptable as-is

...continue single continuous numbering across all severities and reviewers...

Recommended: 1, 3, 5

Full reports: [base](path) | [security](path) | [ux](path)
```

Format rules:

- ONE continuous numbered list — never restart numbering
- Order: critical first, then important, then suggestions
- Each finding is a mini-block: severity + location + reviewer on line 1, description on line 2, Fix/Skip verdict on line 3
- **Fix** = you recommend acting on it. **Skip** = noted but not worth fixing, with reason
- Recommended line at the end lists only the Fix item numbers
- Omit UX verdict line and report link if UX reviewer was not spawned
- Use markdown link syntax for ALL file references: `[file.cs:42](path/to/file.cs#L42)`

## Step 5: Update Review Marker

After presenting findings, write the current HEAD SHA to `.claude/.local/reviews/<branch>-last-reviewed` so subsequent `/review` calls only cover new changes.

## Rules

- NEVER make code changes — only analyze and report
- Do NOT run mkdir for output directories — Write creates intermediate directories automatically
- If diff >500 lines, tell user and offer to focus on specific files
- PR mode: check `gh pr checks <number>` and mention failures
