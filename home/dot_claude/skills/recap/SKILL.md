---
name: recap
description: "Use when user says /recap, wants a work summary, timesheet notes, or daily log of what they accomplished"
user-invocable: true
argument-hint: "[today | week | last week | mon-fri | YYYY-MM-DD] [section]"
---

# Recap Skill

Generate a daily work summary for personal notes and timesheet entries. Output is grouped by section (client/project), broken into time blocks of active work, and written to one Markdown file per day.

## Step 1: Load Config

Read `~/.claude/skills/recap/recap.toml`. If missing, tell the user to create it and stop. Schema:

```toml
output_dir = "~/Documents/recaps"

[sections]
# Section name → list of repo paths. Multi-repo sections collapse into one
# output section. Names are arbitrary; keep them short — they appear as
# H2 headings in the output (`## <section>`).
acme = ["~/work/acme-platform"]
widgets = ["~/work/widgets/api", "~/work/widgets/web"]
personal = ["~/projects/dotfiles"]
```

- `output_dir`: where per-day MD files are written (tilde-expanded).
- `[sections]`: each entry is a section name → list of repo paths. A transcript's `cwd` is matched against every section path via **longest-prefix match**: if `cwd` matches multiple paths, the section with the longest matching prefix wins. (Example: with `personal = ["~/projects"]` and `acme = ["~/projects/acme"]`, a `cwd` of `~/projects/acme/foo` belongs to `acme`, not `personal`.) Match against the literal `cwd` field — symlinked or worktree paths may not match. **Substitute your real section names from the config — don't use the names in this example.**
- The config is local-only — don't commit it to dotfiles.

Anything matched in transcripts/git but not under any section's paths goes into a default `Other` section.

If a second argument is given (e.g., `/recap last week <section>`), filter output to that section only. The section filter applies to all output (file, day-header total, sections rendered).

If the config is missing in **headless** invocation (`claude --print`), exit non-zero with a clear log line — there is no user to "tell".

## Step 2: Parse Date Range

Determine the date range from the argument (relative to today's local date):

| Argument     | Range                                                             |
| ------------ | ----------------------------------------------------------------- |
| (none)       | Today only                                                        |
| `week`       | Monday of current week through today                              |
| `last week`  | Monday through Friday of previous week                            |
| Day names    | Resolve to current week: `mon-fri`, `tue-thu`, `wed` (single day) |
| `M/D`        | Specific date (current year): `3/20`                              |
| `M/D-M/D`    | Date range: `3/18-3/20`                                           |
| `YYYY-MM-DD` | ISO date, also supports ranges with `-` between two dates         |

All date boundaries are in the user's local timezone.

**Detect the local timezone first** — required for every subsequent date calculation (range parsing, transcript clustering, midnight splitting). In headless `--print` mode there is no implicit local time, so this must be explicit:

```bash
date +%z   # numeric offset, e.g. -0400
date +%Z   # name, e.g. EDT
```

Use the offset for math (`fromdateiso8601` minus offset seconds) and the name only for display. If `date +%z` returns `+0000` the harness is running in UTC — proceed but note the gap (any midnight splits will be UTC midnight, not user's local midnight).

If the argument is ambiguous, ask for clarification.

## Step 3: Gather Data

For each (section, date), gather data across all repos in that section.

### 3a. User identity

```bash
git -C <repo> config --get user.email
```

Use as `--author` for git queries.

### 3b. Merged commits to default branch

```bash
git -C <repo> log <default-branch> --author="<email>" --since="<date> 00:00" --until="<date+1> 00:00" --format="%H|%ad|%s" --date=iso-strict
```

### 3c. PRs merged on that date

```bash
gh pr list -R <owner>/<name> --author="@me" --state merged --search "merged:<date>" --json number,title,url,mergedAt
```

### 3d. PRs reviewed on that date

```bash
gh api "search/issues?q=reviewed-by:@me+repo:<owner>/<name>+type:pr+merged:<date>" --method GET --jq '.items[] | "\(.number)|\(.title)|\(.html_url)"'
```

If `gh api` fails, skip and note the gap.

### 3e. Branch (unmerged) commits

```bash
git -C <repo> log --all --not <default-branch> --author="<email>" --since="<date> 00:00" --until="<date+1> 00:00" --format="%H|%ad|%s|%D" --date=iso-strict
```

### 3f. Uncommitted work (today only)

```bash
git -C <repo> status --short
git -C <repo> diff --stat
```

### 3g. Plans

For each repo in the section, resolve its plans dir relative to **that repo's root** (not the launcher's cwd — in headless mode the launcher's cwd is `~/.local/bin/` or similar, not a repo). Use the plans-resolution rule from CLAUDE.md: check `<repo>/.claude/settings.local.json` then `<repo>/.claude/settings.json` for `plansDirectory`; fall back to `<repo>/.plans` if it exists; otherwise `<repo>/.claude/plans`. Resolve the path relative to the repo, then find files modified on the date:

```bash
find <repo>/<plans-dir> -name "*.md" -newermt "<date> 00:00" ! -newermt "<date+1> 00:00"
```

Read the first heading of each matching plan for context.

### 3h. Active windows from transcripts

Transcripts live at `~/.claude/projects/<encoded-cwd>/*.jsonl`, where `<encoded-cwd>` is the repo path with every `/` replaced by `-` (so the leading `/` becomes a leading `-`). Example: `/Users/me/work/acme-platform` → `-Users-me-work-acme-platform`. The cwd field in transcripts is matched literally; symlinked or worktree-different paths may not match.

**Important — timestamp parsing:** transcripts use millisecond-precision ISO timestamps like `2026-05-02T12:34:56.789Z`. jq's `fromdateiso8601` only accepts second-precision and returns `null` for fractional seconds, silently zeroing every duration. **Strip the fraction before converting**:

```jq
.timestamp[:19] + "Z" | fromdateiso8601
```

Without this, the entire window-clustering step produces empty output. The `[:19] + "Z"` form is correct for the common `...Z` shape; if you ever see `+00:00`-style timestamps, use `sub("\\.[0-9]+"; "")` instead.

**Procedure (run in this exact order — order matters):**

1. **Filter** turns from each transcript file in the section's matching `<encoded-cwd>` directories:

   - `.cwd` matches one of the section's paths via **longest-prefix match** (see Step 1)
   - `.timestamp` falls within the date's local-timezone window (convert the local-day boundaries `00:00`–`24:00` to UTC using the offset detected in Step 2, then compare epoch-to-epoch)
   - `.isMeta != true`, `.isSidechain != true`
   - `.type == "user"` or `"assistant"`

2. **Sort** filtered turns by timestamp ascending.

3. **Cluster** into windows: a gap > 30 minutes between consecutive turns starts a new window. Window start = first turn's timestamp; end = last turn's timestamp.

4. **Split at local midnight** (do this BEFORE rounding): if a window spans local midnight, cut it into two halves at the midnight boundary. The first half stays on its original date; the second half is labeled `(continued)` and routes to the **next** date's output file.

5. **Round** each (possibly-split) half's start/end to the nearest `:00 / :15 / :30 / :45` in local time.

6. **Drop** any rounded half that is under 5 minutes. (Note: this can drop both halves of a tiny midnight-spanning window — that's correct, the activity was negligible.)

7. **Label** each surviving window: find the first `user` turn in it whose content is a real prompt (not a `<command-name>`, `<bash-input>`, `<local-command-stdout>`, or tool_result wrapping). Use it only as a hint when synthesizing bullets — not as the final label.

**Bash-call note:** the `jq -s` filter for this step uses `|` extensively as jq's pipe operator. That's allowed — the no-chaining rule (see Rules) is about **shell-level** chaining between processes, not operators inside a single tool's argument.

## Step 4: Synthesize

For each (section, date), produce:

### Time blocks

One time block per window. The repo is **always shown**; how it's shown depends on how many repos had activity in the block.

- **One repo** in the block — include the repo name in the time-block header parenthetical, then list bullets directly:

  ```markdown
  - HH:MM-HH:MM (Xh Ym, <repo-name>):
    - <description>
    - <description>
  ```

- **Two or more repos** in the block — plain time-block header, nest bullets under each repo as a sub-group with the repo name in **bold**:

  ```markdown
  - HH:MM-HH:MM (Xh Ym):
    - **<repo-name>**:
      - <description>
      - <description>
    - **<repo-name>**:
      - <description>
  ```

This way the repo is unambiguous in either case, with no repetition for single-repo blocks.

**Description style — client-facing, intended for copy-paste into a client's system:**

The bar: **someone who doesn't know your codebase should understand what changed in the world**. The block bullets are deliverable-quality summaries, not internal task lists.

- 1–2 full sentences per bullet. Lead with the outcome (what changed for the user / business / system), then add the technical hook at the end.
- Past tense, active voice. Specific verbs ("Shipped", "Reviewed and merged", "Wrote", "Diagnosed and fixed", "Designed and implemented").
- Inline refs at the end with **markdown links when URLs are known**: `(PR [#123](https://github.com/owner/repo/pull/123) merged)`, `Reviewed PR [#232](https://github.com/owner/repo/pull/232): <one-clause description>`. The `gh` queries return URLs — use them. If no URL is known, fall back to plain text: `(#456)`.
- `(in progress)` for branch work not yet merged.
- One bullet per arc of related work — combine 5 commits for the same feature into one bullet.
- **De-dup across sources**: if a commit and a transcript window describe the same work, write a single bullet that captures it.

**Avoid in client-facing bullets:**

- Internal codenames or shorthand for projects/efforts (e.g. "Build-once", "ci-pass workflow", "build-mode") without explanation.
- Acronyms unless universally known.
- File names, class names, function names, package names, CLI commands.
- Colon-prefixed labels that compress meaning (`X: Y + Z` style).

**Anti-pattern → better, side by side** (illustrative — the rules above are the source of truth, apply them across all domains, not just the patterns shown here):

| ❌ Don't                                                                | ✅ Do                                                                                                                                                                                           |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Build-once: API + Grading + tag-protected promotion (PR #388 merged)`  | `Set up automated deployment for the API and grading services so production only receives builds that already passed staging, eliminating the risk of shipping untested code (PR #388 merged).` |
| `Fix api-push / grading-push skip propagation on main (PR #390 merged)` | `Fixed a bug where main-branch deployments were skipping the build step in some cases, ensuring every merge to main now produces a fresh deployable image (PR #390 merged).`                    |
| `Set explicit CodeQL build-mode across all language workflows`          | `Configured the security scanner to run reliably across all the codebases — was previously failing intermittently for some languages.`                                                          |

**Self-check (single pass, not a loop):** does this bullet name a deliverable or business outcome? If it only names a code artifact, rewrite once. If it already does both, leave it. Don't repeatedly second-guess prose that's already passing.

### Section header

`## <Section> (<duration>[, <N> PRs merged][, <M> in progress][, <K> reviewed])`

- `<duration>` is the **sum of block durations**, not gross start-to-end.
- Append parenthetical stats only when non-zero: PRs merged, branches with unmerged commits, PRs the user reviewed. Skip a stat that's zero.
- Pluralize correctly: `1 PR merged` (singular), `2 PRs merged` (plural). Same for `in progress` and `reviewed`.
- Examples:
  - `## acme (3h 30m, 2 PRs merged)` — only merges, no in-progress or reviews
  - `## widgets (10h 45m, 6 PRs merged, 1 in progress, 2 reviewed)` — full
  - `## personal (45m, 1 PR merged)` — singular form
  - `## Other (2h)` — no PR activity at all

### Notes

A `### Notes` subsection for **observations** — what was discovered, decided, or surprising. Personal/technical, not client-facing.

- 2–4 sentences per bullet.
- Lead with the insight, decision, or surprise. Then explain **why it matters** — what it enables, what it blocks, what to revisit.
- Free to use technical detail (paths, PR numbers, package names, file references).
- Cap 5–7 notes. Omit the section if nothing rises to the bar.

Surface:

- Gotchas or surprising behavior discovered
- Important past decisions with brief rationale
- Things that took unexpectedly long, and why

### Follow-ups

A `### Follow-ups` subsection for **forward-looking actionable items** — things to revisit, decide, or finish. Separated from Notes so the user can triage actions without re-reading observations.

- Each bullet is a specific item to act on later. Include enough context to act without re-reading the recap.
- Cap 5–7 items. Omit the section if nothing pending.

Surface:

- Loose ends or branches not yet merged
- Decisions still pending
- Friction points worth a future skill, allowlist entry, or memory entry
- TODOs surfaced during the day

Don't pad. Short Notes / Follow-ups sections are fine. Tone is reflective and forward-looking — not a status report.

## Step 5: Output

For each date in the range, write a Markdown file at `<output_dir>/<YYYY-MM-DD>.md`. Overwrite if the file exists. Also echo the content to stdout.

Create `<output_dir>` if it doesn't exist.

### Day header

The file starts with `# <Day>, <Month> <DD> <YYYY> (<Xh Ym> total)` where the total is the **sum of all section durations** for the day. Example: `# Mon, April 21 2026 (8h 45m total)`.

### File format

```markdown
# Mon, April 21 2026 (8h 45m total)

## acme (3h 30m, 2 PRs merged, 1 reviewed)

- 09:00-10:30 (1h 30m, api-service):
  - Reviewed and merged the logger fix that had been blocking CI for the team, unblocking everyone else's PRs (PR [#232](https://example.com/owner/api-service/pull/232) merged).
  - Started building the lint and test workflow so code-quality checks run automatically on every PR instead of being run by hand each time.
- 14:00-16:00 (2h):
  - **api-service**:
    - Shipped the lint and CI workflow — every PR now runs checks before merge (PR [#2](https://example.com/owner/api-service/pull/2) merged).
    - Wrote developer onboarding docs covering local setup and common workflows so new contributors can get productive without 1:1 walkthroughs.
  - **admin-app**:
    - Mirrored the new CI workflow over so both repos share the same quality gates.

### Notes

- Three nullable-reference warnings parked as `// TODO` to keep the CI PR scope clean. Worth a 30-min cleanup pass before the next release branch — they'll cause noise on every diff until then.
- Credential helper caches per-host even after explicit reject — relevant if we ever need to fully sign out a service account. Documented in the runbook.

### Follow-ups

- Decide whether maintainers should be exempt from the new branch-protection self-approval gate. Today's solo merges required overrides; the gate is right for the team but adds friction for solo work.
- Clean up the parked nullable-reference warnings before the next release branch.

## widgets (5h 15m, 3 PRs merged)

...

### Notes

...

### Follow-ups

...
```

### Empty cases

- A section is **included** if it has any of: time blocks (windows), commits, or merged/reviewed PRs that date. Notes/Follow-ups alone (e.g. observations carried over from yesterday) are not enough to render a section — those have nothing to attach to.
- Section with none of the above → omit it (along with its Notes / Follow-ups, if any).
- Date with zero activity across all sections → write a file containing only `No activity recorded.`

### gh-failure notation

If `gh api` (or `gh pr list`) fails for a section, render the failure inline at the section level rather than fabricating data:

```markdown
## acme (2h, gh: PR data unavailable)
```

…and continue with the rest of the section using whatever data did succeed (commits, transcripts).

## Rules

- Read-only except for writing per-day files to `output_dir`.
- If `gh` fails (not authenticated, no remote), skip PR data and note the gap inline at the section header (see "gh-failure notation").
- Deduplicate commits across main and branch logs.
- All times in user's local timezone, 24h format.
- **NEVER chain commands at the shell level** with `&&`, `|`, `;`, `for` loops, or subshells. Each Bash call must be a single simple command. **Operators inside a single tool's argument are fine** — jq filter `|`, awk pipes inside `-v`, regex alternation, etc. — because they don't spawn a second process. Use parallel Bash tool calls for independent queries (one call per repo per data source).

## Headless invocation note

When invoked from `~/.local/bin/recap-daily` (launchd, daily 06:00), the skill runs in `claude --print` mode with `--dangerously-skip-permissions` because `--allowed-tools="Bash(<pattern>)"` patterns get mangled by the argument parser on whitespace, and `settings.json`'s `permissions.allow` is not consulted in `--print` mode. This was settled after exhausting alternatives — don't relitigate it without re-checking whether headless permission gating has improved.
