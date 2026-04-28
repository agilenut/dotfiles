---
name: recap
description: "Use when user says /recap, wants a work summary, timesheet notes, or daily log of what they accomplished"
user-invocable: true
argument-hint: "[today | week | mon-fri | 3/20 | 3/18-3/20]"
---

# Recap Skill

Generate a concise daily work summary suitable for personal notes and timesheet entries.

## Step 1: Parse Date Range

Determine the date range from the argument (all dates relative to today's date):

| Argument     | Range                                                               |
| ------------ | ------------------------------------------------------------------- |
| (none)       | Today only                                                          |
| `week`       | Monday of current week through today                                |
| `last week`  | Monday through Friday of previous week                              |
| Day names    | Resolve to current week: `mon-fri`, `tue-thu`, `wed` (single day)   |
| `M/D`        | Specific date (current year): `3/20`                                |
| `M/D-M/D`    | Date range: `3/18-3/20`                                             |
| `YYYY-MM-DD` | ISO date, also supports ranges with `-` separator between two dates |

If the argument is ambiguous, ask for clarification.

## Step 2: Gather Data

For each date in the range, collect from the **current repo**:

### 2a. Detect user identity

```bash
git config user.email
```

Use this as `--author` for all git queries.

### 2b. Merged work (main)

Commits by the user merged to main on that date:

```bash
git log main --author="<email>" --since="<date> 00:00" --until="<date+1> 00:00" --format="%h %s"
```

### 2c. PRs merged on that date

```bash
gh pr list --author="<email>" --state merged --search "merged:<date>" --json number,title,url
```

### 2d. PRs reviewed on that date

```bash
gh api "search/issues?q=reviewed-by:@me+repo:{owner}/{repo}+type:pr+merged:{date}" --jq '.items[] | "\(.number) \(.title)"'
```

If the API query fails, fall back to:

```bash
gh api "repos/{owner}/{repo}/pulls?state=all&per_page=50" --jq '.[] | select(.merged_at != null) | select(.merged_at | startswith("<date>"))'
```

and check review comments. It's okay to skip reviews if neither approach works — just note it.

### 2e. Branch work (not yet merged)

Commits by the user on local branches (not main) on that date:

```bash
git log --all --not main --author="<email>" --since="<date> 00:00" --until="<date+1> 00:00" --format="%h %s (%D)"
```

### 2f. Uncommitted work (today only)

Only if the date is today:

```bash
git status --short
git diff --stat
```

Summarize what files are being worked on, grouped by area.

### 2g. Plans

Resolve plans directory per "Plans Directory Resolution" in CLAUDE.md. Check for files modified on that date:

```bash
find <plans-dir> -name "*.md" -newermt "<date> 00:00" ! -newermt "<date+1> 00:00"
```

Read the first heading of each matching plan for context.

## Step 3: Generate Summary

For each date, produce a summary section:

```markdown
### Friday, March 20

- Implemented speech-to-text for student test responses
- Set up AI-powered grading with rubric-based feedback
- Created answer display component for the test-taking flow
- Reviewed PR #232: fix for email logger tests
- Planning: grading service integration (in progress)
```

### Writing style

- **3-5 bullets per day** as a baseline. If the day was genuinely busy, go over — but don't pad.
- **Lead with what was accomplished**, not how. "Added student login flow" not "Modified AuthController.cs, added routes, wrote tests".
- **Plain language** a non-technical reader can understand. Avoid file names, class names, CLI commands. Slightly technical is okay when the work is inherently technical (e.g., "Fixed database migration for new column").
- **Group related commits** into a single bullet. Five commits for one feature = one bullet.
- **Distinguish merged vs in-progress**: use "(in progress)" suffix for branch work not yet merged.
- **Distinguish reviewed vs authored**: "Reviewed PR #N: description" for reviews.
- If a day has no activity, say "No activity found for `<date>`."

### Output format

- If single day: no date header, just bullets
- If multiple days: `### Day, Month Date` header per day, then bullets
- End with a blank line — no trailing commentary

## Rules

- Do NOT modify any files
- Do NOT create any files
- Read-only skill: gather data, produce output, done
- If `gh` commands fail (not authenticated, no remote), skip PR data and note the gap
- Deduplicate: if a commit appears in both main and a branch log, only count it once
- **NEVER chain commands** with `&&`, `|`, `;`, `for` loops, or subshells. Each Bash call must be a single simple command. Use parallel Bash tool calls for independent queries (e.g., one call per date per data source). This ensures commands match the user's permission patterns.
