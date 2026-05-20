---
name: review-plan
description: "Use when user says /review-plan, asks to review a plan, or wants feedback on an implementation plan before coding"
user-invocable: true
argument-hint: "[plan-filename]"
---

# Plan Review Orchestrator

Mirrors `/review`'s pipeline against a plan markdown file: spawn reviewers, verify, auto-fix obvious, auto-skip obvious mistakes, dialog the ambiguous middle one finding at a time, persist reasoning to a triage file.

Invoked from `/plan` Step 9 as an opt-in fresh-eyes pass, or directly by the user.

## Step 1: Find the Plan

1. Resolve plans directory per "Plans Directory Resolution" in CLAUDE.md
2. If argument provided, look for it in the resolved directory
3. Otherwise, find the most recently modified `.md` file in the resolved directory
4. If no plan found, tell user and stop

## Step 2: Gather Context

Read for the orchestrator's own use AND to pass to reviewers:

- `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md` (conventions) — read full contents; passed to reviewers
- **Read the full plan file at the resolved path.** The plan IS the spec being reviewed and is authoritative. The plan's Goal, Approach, Decisions, and Commits sections represent the refined thinking; reviewers must treat the plan as the source of truth and check its internal quality.
- **Optional background context** (pass to reviewers as supplementary; reviewers must NOT defer to it over the plan):
  - Issue body, ONLY if the plan's frontmatter `stories:` field lists one or more issues. Use the first entry: `gh issue view <stories[0]> --json body,title`. Issues are often idea-generators rather than specs; the plan is the refined version. Mark as "background only" in the spawn prompt.
- **Review preferences** (orchestrator-only, never passed to reviewers):
  - `~/.claude/review-preferences.md` (user-scope, if it exists)
  - `<project-root>/.claude/review-preferences.md` (project-scope, if it exists)
- **Prior triage** for carry-over: scan `.reviews/plans/` for triage files whose frontmatter `plan:` or `plan-path:` matches this plan. Pick the most recent. Read it if found.

## Step 3: Spawn Reviewers (MUST use Agent tool — do NOT inline)

You MUST use the Agent tool. Do NOT perform the review yourself.

**Determine if the plan involves UI.** Scan the plan for references to components, pages, routes, views, CSS, styling, design, frontend, or UI frameworks. If yes, include `ux-reviewer`.

Subagents:

- `subagent_type: "plan-reviewer"` (always)
- `subagent_type: "ux-reviewer"` (if plan involves UI)

Spawn in parallel.

Each Agent prompt receives:

- **Plan file path** — the authoritative spec; what's being reviewed
- **CLAUDE.md contents** (`~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md`) — for convention checks
- **Issue body (if any) — mark explicitly as "background only. If the issue and the plan disagree, the plan wins."** Reviewers must treat the issue as supplementary, never as the spec.
- Project root path (for codebase exploration)
- Output path: `.reviews/plans/<YYYY-MM-DD>-<HHMMSS>-<plan-name>-<type>.md` where `<type>` is one of `plan` | `ux`. Run `date +%Y-%m-%d-%H%M%S` for the timestamp; do NOT hardcode it.
- **Mandatory write rule** (verbatim, in every spawn prompt): `MANDATORY: Your final action MUST be a Write tool call writing your findings to the output path above. Text-only return will be rejected — file MUST contain a heading matching '^# .+ Review:' or '## Findings'.`

Wait for all agents to complete.

## Step 4: Post-Spawn Enforcement (salvage-first)

For each spawned reviewer: Read the expected output path. **Structure-presence is the discriminator** — file contains `^# .+ Review:` on a single line OR a `## Findings` heading → accept. If file is missing/malformed but the Agent tool's text return contains that structure → **salvage**: write the returned text to the expected path; buffer salvage note in memory, emit when triage file is initialized at Step 8: `<reviewer> output salvaged from text return — did not call Write tool.` Neither path has structure → **re-spawn ONCE** with the original spawn prompt verbatim, prepended by: `Your previous attempt did not write valid output to <path>. The file MUST contain a heading matching '^# .+ Review:' or '## Findings'. Your final action MUST be a Write tool call to that exact path.` Still failing → hard-fail the reviewer, log `Reviewer <name> failed after retry; findings unavailable.`, continue with others.

## Step 5: Build Atomic Findings

For each accepted reviewer output:

1. Extract each bullet/finding. Capture the verbatim reviewer text alongside the atomic finding (Step 12's `c`-for-context reads from this, not from the reviewer file).
2. **Composite split:** only when a bullet has 2+ distinct plan-section refs AND the recommendations don't share a single fix. Otherwise treat as one.
3. **Dedupe across reviewers:** same finding from plan-reviewer + ux-reviewer becomes one entry, attribute both `(plan, ux)`. Match by `same plan section + same root issue (paraphrase equivalence)`.

## Step 6: Verify-First Per Finding

For every atomic finding, BEFORE assigning a bucket:

1. Open the plan file at the cited section via Read.
2. Read enough surrounding context to verify the reviewer's factual claim against what the plan actually says.
3. **Articulate in the triage file (mandatory):**

   ```text
   Claim: <reviewer's claim about the plan>
   Plan reality: <what the plan actually says>
   Verified: yes | no
   ```

4. **Invalid citation:** if the cited plan section doesn't exist or doesn't match the claim's premise, set `Verified: no — citation invalid`. Auto-skip with reason `unverifiable citation` (maps to Step 7's "Reviewer clearly wrong" auto-skip criterion). Do not re-spawn the reviewer; the log line itself signals reviewer unreliability for this run.

The `Claim:` / `Verified:` lines are mandatory evidence. Missing them is self-evident protocol violation.

**Verify-first self-check before Step 7:** scan the draft triage. If any finding lacks the Claim / Plan reality / Verified triplet, STOP and return to Step 6 before bucketing.

## Step 7: Bucket Each Finding

For each verified finding, run pre-bucket skip checks first; on no match, apply bucket criteria; finally run second-pass flags.

### Pre-bucket skip checks (terminal — if matched, bucket is set, skip rest)

Match by `same plan section + same root issue (paraphrase equivalence)`.

- **Carry-over from prior triage:**
  - User-driven skip (`skipped (user redirected)` or `skipped (user accepted SKIP)`) → carry as auto-skip: `previously skipped by user: <reason>; reference: <prior-triage-path>`
  - `auto-skipped` / `fixed` / `pending` → do NOT carry. Re-bucket fresh.
- **Preferences match** → auto-skip with `matches review-preference: "<rule>"`
- **CLAUDE.md / plan Decisions match** (finding contradicts an explicit rule OR contradicts a Decision in the plan's Decisions section without offering new information shifting the tradeoff weight) → auto-skip citing it.

**"New information" examples:** _Is_ new info: reviewer cites a fresh library API change since the plan was written, or surfaces an implication the plan didn't consider. _Is NOT_ new info: rephrasing a tradeoff the plan already discussed.

### Bucket criteria

- **Auto-fix** (ALL): verified yes; mechanical plan edit (typo, missing test-step mention the reviewer flagged AND verified, Decisions-section addition capturing a discussed point, step-ordering fix that's clearly correct); no semantic change to the plan's Approach; doesn't substantively expand the plan's scope (small boyscouting OK). Multi-section fine if aligned. Examples: typo in a step title; missing the `chezmoi diff && chezmoi apply` line in a commit description that already mentions chezmoi-managed files.

- **Auto-skip** (ANY): reviewer clearly wrong (`unverifiable citation`); diminishes the plan's Goal with no alternative path that preserves both Goal and correctness (if there IS an alternative, escalate to needs-review); proposes scope expansion the plan explicitly defers; large architectural / maintenance burden; significantly more complexity for little gain. Examples: reviewer "invents" a gap not actually present in the plan; suggests rewriting the plan around a different stack.

- **Needs-review** (everything else): close tradeoffs; reviewer proposes a different approach for the plan (foundational candidate — see second-pass flags); important contract decisions (data model, API shape) where the plan and reviewer differ; reviewer found new info shifting tradeoff weight. Examples: reviewer proposes a different decomposition into commits (foundational-candidate — see second-pass flags); suggests a different ordering of steps.

### Escalation rules (override auto-skip → force needs-review)

If any apply, the finding goes to needs-review regardless of other reasoning. Better to ask one extra question than silently skip an important call.

- **Hesitation → escalate.** Uncertain whether auto-fix or auto-skip cleanly fits? Escalate.
- **No thought-terminator labels.** "Cosmetic", "defensible", "minor", "stylistic", "nit" need a concrete harm-avoided named next to them. If none exists, escalate.
- **Name-vs-meaning check.** If the plan introduces or renames a contract (API endpoint, DTO field, schema) → any reviewer finding about an identifier whose name now embeds a stale concept must surface as needs-review.
- **Plan internal consistency.** When a reviewer flags inconsistency between the plan's Goal / Approach / Decisions / Commits sections → force needs-review. The plan is the contract; internal contradictions need explicit resolution. _Anti-example:_ reviewer notes Approach mentions JSON but Step 2 says YAML — force needs-review even if it looks like a typo, because the Goal anchors the choice and an auto-fix to either side might be wrong.
- **Don't adopt reviewer hedges wholesale.** Reviewer's own skip-reasoning ("just cosmetic", "not blocking") is not your bucket call. Re-verify; if it holds, document why; if not, escalate.

### Second-pass flags (after all findings are bucketed)

- **Foundational** — mark `foundational: true` when accepting the finding would moot or reshape 2+ other findings. Most common for plan reviews: reviewer proposes a different overall approach, different decomposition, or different anchor decision. Changes dialog ordering (Step 9 / Step 12); does NOT change bucket. Default false. _Example:_ reviewer suggests splitting commit 1 into three commits — moots ordering/scope findings about commit 1's bundle.

- **Pattern-wide** — runs only when the reviewer's recommendation is a **rename** of a plan-internal contract (endpoint, field, glossary term), a **convention change** across plan steps ("every commit description should declare `review: per-commit`"), or **pattern substitution** in the plan's structure. Phrasing signals: "rename", "every commit", "consistency", "across the plan". Local fixes (typo in one step, single missing detail) → skip.

  When triggered: grep the plan file for the cited token (length ≥ 4, not in the plan-context denylist below). 2+ other occurrences → `pattern-wide: true`, force needs-review. Per-finding card: `Pattern: same token in N other places in the plan.`

  Plan-context denylist: `step`, `plan`, `goal`, `note`, `todo`, `commit`, `the`, `and`, `for`, `with`, `from`, `into`, any token < 4 chars. Semantic patterns (no literal token): use reviewer phrasing — "this pattern appears elsewhere" → treat as pattern-wide.

## Step 8: Initialize Triage File

Before any dialog or auto-fix, write the triage file at `.reviews/plans/<YYYY-MM-DD>-<HHMMSS>-<plan-name>-triage.md` (same timestamp as Step 3). Use the canonical structure defined in Step 13 with these initial values:

- Frontmatter: `snapshot-copy: null` (filled at Step 10), other fields populated
- Summary: `pending: N-needs-review`, `fixed: 0`, `skipped: N-auto-skipped`
- Auto-fixed section: empty placeholder
- Auto-skipped section: full entries (already known from Step 7)
- Needs-review section: full entries with `Status: pending`, foundational/pattern-wide flags set
- Salvage / failure log: all buffered entries from Step 4 (empty if none)

Steps 9, 10, and 12 update in place. Step 13 finalizes.

## Step 9: Foundational Dialog (if any)

Foundational items must dialog with the user BEFORE any auto-fix is applied. Auto-fix is a commitment within a direction; don't commit while direction is in flux.

For each foundational item (in severity order), present the per-finding card (Step 12 format) with the addition:

```text
Heads up — this is foundational. If you take it, items #X, #Y, #Z may
not apply; I'll re-evaluate them after your decision.
```

After resolution:

- **Accepted** → re-run verify-and-bucket on the listed dependent items. Some may flip to auto-skip with reason `superseded by item #<N>`. Update the triage file in place.
- **Skipped** → dependent items stay in their original buckets.

If no foundational items exist, skip directly to Step 10.

## Step 10: Apply Auto-Fixes

Triage file exists from Step 8; update in place.

1. **Before the first fix**, copy the plan to `.reviews/plans/<timestamp>-<plan-name>-pre-fix.md` and set triage frontmatter `snapshot-copy: <pre-fix-path>`. If no auto-fixes run, `snapshot-copy` stays `null`. The snapshot copy is the only recovery primitive — plan files are gitignored, so `git checkout`/`git diff` don't apply.
2. For each auto-fix: apply via `Edit`; move the entry into triage `## Auto-fixed` with `Status: fixed (auto)`.
3. Inspect during session: `diff <pre-fix-path> <plan-path>`. Revert all: `cp <pre-fix-path> <plan-path>` (coarse — reverts all fixes from this run; re-run `/review-plan` after).
4. No build/test — markdown doesn't compile.

## Step 11: Chat Opener

After auto-fix completes, print the opener:

```text
Auto-fixed: <N> | Auto-skipped: <N> | Triage: .reviews/plans/<timestamp>-<plan-name>-triage.md
Needs your review: <N> — let's start with #<first>.
```

If no items need review, skip to Step 13.

## Step 12: Needs-Review Dialog (One at a Time)

Present findings in this order: critical → important → suggestions. Within each tier, pattern-wide candidates ordered by codebase-echo count (highest first). Foundational items were already dialogged in Step 9; any user-undecided ones reach this step at their natural severity.

### Per-finding card format

```text
Review item <i> of <N> — needs your call

[<Severity>] <plan-section-or-line-ref> (<reviewer>)

Claim: <one short paragraph quoting / paraphrasing the reviewer>

Verified: <yes | no> — <one-line plan-reality summary>

Risk if skipped: <one line, ONLY when not self-evident from Claim>

[Pattern: same token in <N> other places in the plan (full list in triage).]   <-- only for pattern-wide candidates

My take: <FIX | SKIP> — <reasoning>

[Why surfacing this: <one line>]   <-- ONLY when My take is SKIP but item is surfaced anyway

y fix / n skip / c more / or type
```

### Input parsing

- `y` → accept the recommendation (whichever it proposed).
- `n` → opposite. If `My take: SKIP`, ask how to fix (or accept inline freeform). If `My take: FIX`, mark skipped with the user's reason.
- Any input containing `c` (`c`, `yc`, `nc`) → show expanded context first; re-prompt with the user's leaning noted. Honors CLAUDE.md combination-answer preference.
- Anything else → freeform. Orchestrator answers, then re-offers `y/n/c`.
- `yn` / `ny` → invalid (no coherent meaning); re-prompt.

### `c` for context

Cap response at ~40 lines. Priority order if space is tight:

1. Verbatim reviewer quote (captured in Step 5)
2. ~20-line window from the plan around the cited section
3. The plan's Decisions section (if the finding touches a Decision — highest-leverage context for plan reviews)
4. Tradeoffs: fix-as-recommended / alternative / skip
5. Related findings on the same plan section (if any)

### After resolution

For each item, update the triage entry's Status:

- `y` against `FIX` → apply via Edit; `Status: fixed (user-confirmed)`
- `n` against `FIX` → `Status: skipped (user redirected: "<reason>")`
- `y` against `SKIP` → `Status: skipped (user accepted SKIP)`
- Freeform fix → apply via Edit; `Status: fixed (user freeform)`

### Opt-in preference capture (on user redirect)

**Trigger (AND of):** (1) user pressed `n` against `My take: FIX` AND (2) redirect reason contains a generalizing signal ("we always", "this codebase prefers", "don't flag this category"). **OR:** user typed `remember` / `capture`. Ask ONCE per finding:

```text
Capture as preference?

Drafted: "<rule based on the user's redirect reason>"
Why: <project pattern / user redirect>; captured <date>.

Save to project / user / no? p / u / n
```

`p` → append to `<project-root>/.claude/review-preferences.md`. `u` → append to `~/.claude/review-preferences.md`. `n` → skip; reasoning stays in triage only.

### Abort / pause

If the user types `stop`, `pause`, `quit`, or sends an interrupt: update remaining items as `Status: pending` in the triage file (the file already exists from Step 8), print:

```text
Paused at item #<i>/<N>. Resume with /review-plan — re-invocation reads the latest triage and resumes from pending items.
```

Then exit cleanly. Re-invocation of `/review-plan` on the same plan will find this triage in Step 2's prior-triage scan and (when pending items exist) offer to resume the dialog from where it stopped before re-running reviewers.

## Step 13: Finalize Triage File

The triage file was created in Step 8 and updated in place during Steps 9, 10, and 12. Finalize: recompute Summary counts, ensure Salvage / failure log section is present (even if empty), confirm every needs-review entry has a terminal `Status:`.

Path: `.reviews/plans/<YYYY-MM-DD>-<HHMMSS>-<plan-name>-triage.md` (same timestamp as Step 3).

Frontmatter:

```yaml
---
plan: <plan-name>
plan-path: <absolute-path-to-plan>
snapshot-copy: <path-to-pre-fix-copy or null> # parallel to /review's snapshot-sha
reviewers-ran: [plan, ux]
issue: <issue-number or null>
timestamp: <iso>
---
```

Sections (in order):

```markdown
## Summary

Auto-fixed: <N>
Auto-skipped: <N>
Needs-review: <N> (pending: 0, fixed: <x>, skipped: <y>)

## Auto-fixed

### #<i> — [<Severity>] <plan-section> (<reviewer>)

- Claim: ...
- Plan reality: ...
- Verified: yes
- Action: FIX — <one-line summary of plan edit>
- Reasoning: <why this met auto-fix criteria>

## Auto-skipped

### #<i> — [<Severity>] <plan-section> (<reviewer>)

- Claim: ...
- Plan reality: ...
- Verified: <yes | no — citation invalid | ...>
- Action: SKIP
- Reasoning: <which auto-skip criterion applied>

## Needs-review

### #<i> — [<Severity>] <plan-section> (<reviewer>)

- Claim: ...
- Plan reality: ...
- Verified: yes
- Recommendation: <FIX | SKIP>
- Foundational: <true | false>
- Pattern-wide: <true | false; if true, N occurrences>
- Status: <fixed (user-confirmed) | fixed (user freeform) | skipped (user redirected: "...") | skipped (user accepted SKIP) | pending | superseded by item #<N>>

## Salvage / failure log

- <reviewer> output salvaged from text return — did not call Write tool. (if any)
- Reviewer <name> failed after retry; findings unavailable. (if any)
```

Single continuous numbering across all sections.

## Step 14: End Reminder

Print the end-of-review reminder:

```text
Plan updated. Re-read before starting implementation.
```

No `.last-reviewed.json` analog — carry-over via prior triage handles dedup. "When was this plan last reviewed?" requires listing `.reviews/plans/` and matching by plan-name prefix.

## Rules

- Edits to the plan file ONLY during Step 10 (auto-fix) and Step 12 (user-confirmed fix or freeform fix). All other steps are read-only.
- Do NOT run mkdir for output directories — Write creates intermediate directories.
- Triage file's `Claim:` / `Plan reality:` / `Verified:` lines per finding are mandatory evidence — never skip verify-first.
- Reviewer agents receive the plan file PATH (not content); review-preferences are orchestrator-only (never passed to reviewers).
- Salvage log entries in triage are monitoring data — recurring salvages indicate the reviewer agent prompt needs further tightening.
