---
name: plans
description: "Use when user says /plans, wants to list/search/select plans, or references a plan by number or keyword"
user-invocable: true
argument-hint: "[search-term]"
---

# Plans Skill

List, search, and select plans. Discovers the plans directory per project settings, with fallback to `~/.claude/plans/`.

## Behavior

### No argument: `/plans`

List plans, grouped and sorted as below. For each plan show:

```markdown
## Plans

| #   | Modified | Status | Summary                      | File                         |
| --- | -------- | ------ | ---------------------------- | ---------------------------- |
| 1   | 2/19     | active | Add student response grading | happy-conjuring-quokka.md    |
| 2   | 2/18     | parked | Migrate auth to JWT          | serene-spinning-lightning.md |
```

- Status = the frontmatter `status:` value (`active`, `parked`, `done`, `superseded`, `abandoned`), or `active` when the field is missing
- Summary = first heading or first non-empty line of the file, skipping a `Done`, `Parked`, `Superseded` or `Abandoned` heading
- Show up to 15 plans: active and parked first, then done, superseded and abandoned (kept only as records), each group newest first
- After listing, tell the user they can say "use plan 3" or "review plan 2"

### With argument: `/plans auth`

Search plan content for the term. Show matching plans with the matched line for context:

```markdown
## Plans matching "auth"

| #   | Modified | Status | Summary             | Match                                 |
| --- | -------- | ------ | ------------------- | ------------------------------------- |
| 1   | 2/18     | parked | Migrate auth to JWT | "Add JWT middleware to auth pipeline" |
```

### Selection: "use plan N"

When user says "use plan N" (or "start plan N", "load plan N"):

1. Read the full plan file. If its `status:` isn't `active` (missing counts as active), say so and stop there instead of presenting it as work to continue:
   - `done`, `superseded` or `abandoned`: it's a record. Say what its section records: where the remaining work went, which plan took over, or why it stopped.
   - `parked`: tell the user to resume it with `/plan <issue>`, naming the issue from its `stories:`, or with `/plan` and this file's name when `stories:` is empty. `/plan` re-checks its Decisions and sets it active; this skill doesn't modify plan files.
2. Present:
   - Brief summary (goal, scope)
   - List of steps/commits with status: mark steps that appear completed (check git log for matching commits or existing code) vs remaining
   - Current position: "You appear to be at step 3 of 5"
3. Ask: "Continue from step N, or something else?"

### Review: "review plan N"

When user says "review plan N": invoke the `/review-plan` skill with that plan's filename.

## Implementation

### 1. Discover plans directory

Resolve per "Plans Directory Resolution" in CLAUDE.md.

### 2. List/search plans

1. `ls -lt {plans-dir}/*.md` via Bash to get sorted file list
2. For each file: `Read(file, limit=15)` to extract the frontmatter `status:` and the Summary as defined above (frontmatter can run past 10 lines when `stories:` wraps)
3. If search term provided: Grep across plan files for the term
4. Present the table

## Rules

- Use Glob, Read, and Grep tools — NEVER use bash loops, head, cat, or for to read plan files
- Do NOT modify any plan files
- Do NOT read full plan content during listing — only first few lines for summary
- Paths shown should be filenames only (not full paths) to keep the table clean
