---
name: review-plan
description: "Use when user says /review-plan, asks to review a plan, or wants feedback on an implementation plan before coding"
user-invocable: true
argument-hint: "[plan-filename]"
---

# Plan Review Orchestrator

Mirrors `/review`'s pipeline against a plan markdown file: spawn reviewers,
verify, auto-fix obvious, auto-skip obvious mistakes, dialog the ambiguous
middle one finding at a time, persist reasoning to a triage file.

Invoked from `/plan` Step 9 as an opt-in fresh-eyes pass, or directly by
the user.

## Invariants

These don't bend, regardless of step:

- **Verify-first.** Articulate `Claim: / Plan reality: / Verified:` in
  the triage file before bucketing any finding. Missing those lines is
  self-evident protocol violation.
- **Triage file is the audit trail.** Every decision lands in
  `.reviews/plans/<timestamp>-<plan-name>-triage.md` with reasoning.
- **The plan is authoritative.** The plan IS the spec being reviewed.
  Issue bodies and other background context are supplementary; if they
  disagree with the plan, the plan wins.
- **Hesitation → escalate.** Uncertain which auto-bucket fits (either
  direction)? Surface it. Auto-buckets are for unambiguous cases.
- **Edits only in Step 10 / Step 12.** All other steps are read-only.

## Step 1: Find the Plan

_Resolve the plan file to review._

1. Resolve plans directory per "Plans Directory Resolution" in CLAUDE.md
2. If argument provided, look for it in the resolved directory
3. Otherwise, find the most recently modified `.md` file in the resolved
   directory
4. If no plan found, tell user and stop

## Step 2: Gather Context

_Read everything the orchestrator AND reviewers need before spawning._

- `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md` (read full
  contents; passed to reviewers)
- **Read the full plan file at the resolved path.** It IS the spec
  being reviewed. The plan's Goal, Approach, Decisions, and Commits
  sections represent the refined thinking; reviewers must treat the
  plan as the source of truth.
- **Optional background context** (pass to reviewers as supplementary;
  reviewers must NOT defer to it over the plan):
  - Issue body, ONLY if the plan's frontmatter `stories:` field lists
    one or more issues. Use the first entry:
    `gh issue view <stories[0]> --json body,title`. Mark as
    "background only" in the spawn prompt.
- **Review preferences** (orchestrator-only, never sent to reviewers):
  - `~/.claude/review-preferences.md` (user-scope, if exists)
  - `<project-root>/.claude/review-preferences.md` (project-scope, if
    exists)
- **Prior triage** (for carry-over): scan `.reviews/plans/` for triage
  files whose frontmatter `plan:` or `plan-path:` matches this plan.
  Pick the most recent.

## Step 3: Spawn Reviewers (MUST use Agent tool — do NOT inline)

_Run reviewers in parallel; each writes its own findings file._

You MUST use the Agent tool. Do NOT perform the review yourself.

**Determine if the plan involves UI.** Scan the plan for references to
components, pages, routes, views, CSS, styling, design, frontend, or UI
frameworks. If yes, include `ux-reviewer`.

Subagent types (full strings):

- `plan-reviewer` — always
- `ux-reviewer` — if plan involves UI

Spawn in parallel. Each Agent prompt receives:

- **Plan file path** — the authoritative spec being reviewed
- **CLAUDE.md contents** (`~/.claude/CLAUDE.md` and project
  `.claude/CLAUDE.md`) — for convention checks
- **Issue body** (if any) — mark explicitly as
  `background only; if the issue and the plan disagree, the plan wins`
- Project root path (for codebase exploration)
- Output path:
  `.reviews/plans/<YYYY-MM-DD>-<HHMMSS>-<plan-name>-<type>.md`
  where `<type>` is `plan` or `ux`. Run `date +%Y-%m-%d-%H%M%S` for
  timestamp — never hardcode.
- **Mandatory write rule** (verbatim):
  `MANDATORY: Your final action MUST be a Write tool call writing your findings to the output path above. Text-only return will be rejected — file MUST contain a heading matching '^# .+ Review:' or '## Findings'.`

Review-preferences are NEVER sent to reviewers; they live
orchestrator-only.

Wait for all agents.

## Step 4: Post-Spawn Enforcement (salvage-first)

_Verify each reviewer wrote a valid output file; salvage from text return
if not; re-spawn or hard-fail._

For each reviewer, in order:

1. Read the expected output path.
2. File has the required heading (`^# .+ Review:` on a single line OR
   `## Findings` heading) → **accept**.
3. File missing/malformed BUT the Agent's text return has the structure →
   **salvage**: write that text to the path; buffer log line for Step 8:
   `<reviewer> output salvaged from text return — did not call Write tool.`
4. Neither has structure → **re-spawn ONCE**. New prompt = original spawn
   prompt verbatim (plan path, CLAUDE.md, issue body, output path)
   PREPENDED with:
   `Your previous attempt did not write valid output to <path>. The file MUST contain a heading matching '^# .+ Review:' or '## Findings'. Your final action MUST be a Write tool call to that exact path.`
5. Still failing after re-spawn → **hard-fail** that reviewer. Log:
   `Reviewer <name> failed to produce output after retry; findings unavailable.`
   Continue with others.

Structure-presence is the discriminator, not byte count. Salvage log
entries are monitoring data — if salvages recur across runs, the reviewer
agent prompt needs tightening.

## Step 5: Build Atomic Findings

_Extract bullets from reviewer reports; dedupe across reviewers._

For each accepted reviewer output:

1. Extract each bullet. Capture verbatim reviewer text alongside the
   finding (Step 12's `c`-for-context reads from this).
2. **Composite split**: only when 2+ distinct plan-section refs AND
   recommendations don't share a single fix. Otherwise one.
3. **Dedupe across reviewers**: same finding → one entry, attribute both
   `(plan, ux)`. Match by
   `same plan section + same root issue (paraphrase equivalence)`.

## Step 6: Verify-First Per Finding

_Open the cited plan section; confirm or deny the reviewer's claim
against what the plan actually says._

For every finding, BEFORE bucketing:

1. Read the plan file at the cited section.
2. Read enough surrounding context to verify the reviewer's factual
   claim against what the plan actually says.
3. **Articulate in the triage file (mandatory)**:

   ```text
   Claim: <reviewer's claim about the plan>
   Plan reality: <what the plan actually says>
   Verified: yes | no
   ```

4. **Invalid citation**: cited plan section doesn't exist or doesn't
   match the claim's premise → `Verified: no — citation invalid`;
   auto-skip with reason `unverifiable citation` (maps to Step 7's
   "Reviewer clearly wrong"). Don't re-spawn.

Missing `Claim:` / `Verified:` lines = protocol violation. Self-check
before Step 7: scan the draft triage; any finding missing the triplet →
return to Step 6 before bucketing.

## Step 7: Bucket Each Finding

_Decide what to do with each finding: auto-fix, auto-skip, or surface
to the user._

Run in order: pre-bucket skip checks → bucket criteria → escalation
rules → second-pass flags.

### Pre-bucket skip checks (terminal — if matched, bucket is set)

Match by `same plan section + same root issue (paraphrase equivalence)`.

- **Carry-over from prior triage**: user-driven skip status
  (`skipped (user redirected)` / `skipped (user accepted SKIP)`) → carry
  as auto-skip with
  `previously skipped by user: <reason>; reference: <prior-triage-path>`.
  Other prior statuses (`auto-skipped` / `fixed` / `pending`) → do NOT
  carry; re-bucket fresh.
- **Preferences match** (`review-preferences.md`, user or project) →
  auto-skip with `matches review-preference: "<rule>"`.
- **CLAUDE.md / plan Decisions match**: finding contradicts an explicit
  CLAUDE.md rule, OR contradicts a Decision in the plan's Decisions
  section without offering new information shifting the tradeoff weight
  → auto-skip citing it. Exception: reviewer cites a fresh library API
  change or implication the plan didn't consider — that's new info,
  proceed to bucket criteria. Rephrasing a tradeoff the plan already
  discussed is NOT new info.

### Bucket criteria

**Auto-fix** — ALL of:

- Verified yes
- Mechanical plan edit (typo, malformed markdown, missing language tags,
  Decisions-section addition capturing a discussed point, step-ordering
  fix that's clearly correct)
- No semantic change to the plan's Approach
- Doesn't substantively expand the plan's scope (small boyscouting OK)
- Multi-section fine if aligned

_Examples:_ typo in a step title; missing the `chezmoi diff && chezmoi apply`
line in a commit description that already mentions chezmoi-managed files.

**Auto-skip** — ANY of:

- Reviewer clearly wrong (`unverifiable citation` counts)
- Diminishes the plan's Goal with no alternative path that preserves
  both Goal and correctness (if there IS an alternative, escalate to
  needs-review)
- Proposes scope expansion the plan explicitly defers
- Large architectural / maintenance burden for little gain
- Significantly more complexity for little gain

_Examples:_ reviewer invents a gap not actually in the plan; suggests
rewriting the plan around a different stack.

**Needs-review** — everything else:

- Close tradeoffs
- Reviewer proposes a different approach for the plan (foundational
  candidate — see second-pass flags)
- Important contract decisions (data model, API shape) where the plan
  and reviewer differ
- Reviewer found new info shifting tradeoff weight

_Examples:_ reviewer proposes a different decomposition into commits
(foundational candidate); suggests a different ordering of steps.

### Escalation rules (override auto-skip → force needs-review)

- **Hesitation → escalate.** Uncertain which auto-bucket fits (either
  direction)? Escalate.
- **Scope-creep hedging is hesitation.** Writing any of `"out of scope"`,
  `"separate plan revision"`, `"we'd be piggybacking"`,
  `"convention sweep deserves its own decision"` in your reasoning →
  escalate. Two cases that LOOK like scope creep but are small-boyscout
  when confident:

  - **Pre-existing mechanical defects in the plan being reviewed** —
    typos, malformed markdown, missing language tags, broken
    cross-references. Confident → auto-fix. Hedging → escalate with
    `My take: FIX`. Split judgment-laden parts (heading restructures,
    content rewrites, Decision rewordings) into needs-review.
  - **Convention sweeps across plan steps with one obvious winner** —
    e.g., every commit row declares `review: per-commit` except one.
    Confident → auto-fix. Hedging → escalate.

  When escalating from hedging, render `Why surfacing this:` showing the
  prior hesitation.

- **No thought-terminator labels.** `"cosmetic"`, `"defensible"`,
  `"minor"`, `"stylistic"`, `"nit"` need a concrete harm-avoided
  alongside. If none exists, escalate.
- **Stale-name check.** If the plan introduces or renames a contract
  (API endpoint, DTO field, schema) → any reviewer finding about an
  identifier whose name embeds a stale concept must surface as
  needs-review.
- **Plan internal consistency.** Reviewer flags inconsistency between
  the plan's Goal / Approach / Decisions / Commits sections → force
  needs-review. _Anti-example:_ reviewer notes Approach mentions JSON
  but Step 2 says YAML — force needs-review even if it looks like a
  typo, because the Goal anchors the choice.
- **Don't adopt reviewer hedges wholesale.** Reviewer's skip-reasoning
  (`"just cosmetic"`, `"not blocking"`) is not your bucket call.
  Re-verify; if it holds, document why; otherwise escalate.

### Second-pass flags (after all findings bucketed)

- **Foundational**: mark `foundational: true` when accepting would moot
  or reshape 2+ other findings. Most common for plan reviews: reviewer
  proposes a different overall approach, decomposition, or anchor
  decision. Changes dialog order (Step 9 / Step 12); does NOT change
  bucket. Default false. _Example:_ reviewer suggests splitting commit
  1 into three commits — moots ordering/scope findings about commit
  1's bundle.

- **Pattern-wide**: only when reviewer's recommendation is a **rename**
  of a plan-internal contract (endpoint, field, glossary term), a
  **convention change** across plan steps ("every commit description
  should declare `review: per-commit`"), or **pattern substitution** in
  the plan's structure. Signals: `"rename"`, `"every commit"`,
  `"consistency"`, `"across the plan"`. Local fixes (typo in one step,
  single missing detail) → skip.

  When triggered: grep the plan file for the cited literal token
  (length ≥ 4, not in plan-context denylist below). 2+ other occurrences
  → `pattern-wide: true`, force needs-review. Card carries
  `Pattern: same token in N other places in the plan.`

  Plan-context denylist: `step`, `plan`, `goal`, `note`, `todo`,
  `commit`, `the`, `and`, `for`, `with`, `from`, `into`, any token
  < 4 chars.

  Semantic patterns (no literal token): use reviewer phrasing — "this
  pattern appears elsewhere" → treat as pattern-wide.

## Step 8: Initialize Triage File

_Create the persistent audit file before any auto-fix or dialog._

Write `.reviews/plans/<YYYY-MM-DD>-<HHMMSS>-<plan-name>-triage.md` (same
timestamp as Step 3) using the canonical structure from Step 13 with:

- Frontmatter: `snapshot-copy: null` (set at Step 10); other fields
  populated
- Summary: `pending: N-needs-review`, `fixed: 0`, `skipped: N-auto-skipped`
- Auto-skipped section: full entries (known from Step 7)
- Needs-review section: full entries with `Status: pending`,
  foundational/pattern-wide flags
- Auto-fixed section: empty
- Salvage log: buffered entries from Step 4 (empty if none)

Steps 9, 10, 12 update in place. Step 13 finalizes.

## Step 9: Foundational Dialog (if any)

_For findings that would reshape other findings, dialog with the user
before auto-fix._

Foundational items dialog BEFORE auto-fix — direction is in flux; don't
commit until it's settled. For each (severity order), present the Step-12
card with this addition:

```text
Heads up — this is foundational. If you take it, items #X, #Y, #Z may
not apply; I'll re-evaluate them after your decision.
```

- **Accepted** → re-run verify-and-bucket on dependents; flip superseded
  ones to auto-skip with reason `superseded by item #<N>`; update triage.
- **Skipped** → dependents stay in original buckets.

No foundationals → skip to Step 10.

## Step 10: Apply Auto-Fixes

_Apply mechanical plan edits via Edit; snapshot the plan first so changes
can be inspected or reverted._

1. Before the first fix, copy the plan to
   `.reviews/plans/<timestamp>-<plan-name>-pre-fix.md` and set triage
   frontmatter `snapshot-copy: <pre-fix-path>`. If no auto-fixes run,
   `snapshot-copy` stays `null`. The snapshot copy is the only recovery
   primitive — plan files are gitignored, so `git checkout`/`git diff`
   don't apply.
2. For each auto-fix:
   - Apply via `Edit` to the plan file.
   - Move the entry into triage `## Auto-fixed` with `Status: fixed (auto)`.
3. Inspect during session: `diff <pre-fix-path> <plan-path>`.
4. Revert all: `cp <pre-fix-path> <plan-path>` (coarse — reverts all
   fixes from this run; re-run `/review-plan` after).
5. No build/test — markdown doesn't compile.

## Step 11: Dialog Intro (only when needs-review items exist)

_Brief intro before the per-finding dialog. Skipped when no items
need review._

If `N` needs-review items > 0, print:

```text
Needs your review: <N> findings. Starting with #<first>.
```

If `N` = 0, skip directly to Step 13. The final summary at Step 14 is
the user's only chat output for this run.

## Step 12: Needs-Review Dialog (one at a time)

_Walk findings with the user, one at a time, applying chosen fixes to
the plan._

Order: critical → important → suggestions. Within each tier, pattern-wide
candidates first (by codebase-echo count). Foundational items already
handled in Step 9; user-undecided ones land here at natural severity.

### Per-finding card format

```text
Review item <i> of <N> — needs your call

[<Severity>] <plan-section-or-line-ref> (<reviewer>)

Claim: <one short paragraph quoting / paraphrasing the reviewer>

Verified: <yes | no> — <one-line plan-reality summary>

Risk if skipped: <one line, ONLY when not self-evident from Claim>

[Pattern: same token in <N> other places in the plan (full list in triage).]   <-- only for pattern-wide candidates

My take: <FIX | SKIP> — <reasoning>

[Why surfacing this: <one line>]   <-- ONLY when surfacing despite a SKIP take (foundational, pattern-wide, or escalated-from-hedging)

y fix / n skip / c more / or type
```

### Input parsing

- `y` → accept the recommendation (whichever was proposed).
- `n` → take the opposite:
  - Against `SKIP`: ask how to fix or accept inline freeform.
  - Against `FIX`: mark skipped with the user's reason.
- Any input containing `c` (`c`, `yc`, `nc`) → show expanded context
  first, then re-prompt with the user's leaning noted. Honors CLAUDE.md
  combination-answer preference.
- Anything else → freeform; orchestrator answers, re-offers `y/n/c`.
- `yn` / `ny` (no `c`) → invalid; re-prompt.

### `c` for context

Cap ~40 lines. Priority order if space is tight:

1. Verbatim reviewer quote (from Step 5 capture)
2. ~20-line window from the plan around the cited section
3. The plan's Decisions section (if the finding touches a Decision —
   highest-leverage context for plan reviews)
4. Tradeoffs: fix-as-recommended / alternative / skip
5. Related findings on the same plan section

### After resolution (Status updates)

- `y` against `FIX` → apply via Edit, `Status: fixed (user-confirmed)`.
- `n` against `FIX` → `Status: skipped (user redirected: "<reason>")`.
- `y` against `SKIP` → `Status: skipped (user accepted SKIP)`.
- Freeform fix → apply via Edit, `Status: fixed (user freeform)` with the
  user's reasoning captured in the entry.

### Opt-in preference capture (on user redirect)

**Trigger** (AND of):

1. User redirected — EITHER `n` against `FIX` OR `n` against `SKIP`.
   Both directions count:
   - FIX→SKIP generates a "don't flag this category" preference
   - SKIP→FIX generates a "lean toward FIX for this category" preference
2. Redirect reason contains a generalizing signal: `"we always"`,
   `"this codebase prefers"`, `"we lean toward"`,
   `"don't flag this category"`, `"treat X as Y"`.

**OR** user typed `remember` / `capture` explicitly.

Ask ONCE per finding. For one-off / case-specific redirects, do not
offer — reasoning stays in triage only.

Always propose the drafted rule upfront — never ask without showing text.
If user edits the draft inline, use their text.

```text
Capture as preference?

Drafted: "<rule>"
Why: <project pattern / user redirect>; captured <date>.

Save to project / user / no? p / u / n
```

**Scope guidance** (recommend a default before asking):

- **Project** (`<project-root>/.claude/review-preferences.md`): specific
  to this codebase's conventions / stack / patterns. Examples:
  `"we always validate at middleware"`,
  `"plans always use stories: frontmatter, never inline issue refs"`.
- **User** (`~/.claude/review-preferences.md`): general process or
  bucketing calibration that applies across projects. Examples:
  `"bias toward FIX for pre-existing mechanical defects in touched files"`,
  `"treat plan deviations as needs-review even if defensible"`.

Actions: `p` → append to project file via Edit. `u` → append to user
file via Edit. `n` → skip.

### Abort / pause

User types `stop` / `pause` / `quit` / interrupt → mark remaining items
`Status: pending` in triage, print:

```text
Paused at item #<i>/<N>. Resume with /review-plan — re-invocation reads
the latest triage and resumes from pending items.
```

Exit cleanly. Re-invocation finds the triage via Step 2's prior-triage
scan; if pending items exist, offer to resume the dialog before
re-running reviewers.

## Step 13: Finalize Triage File

_Recompute summary counts; ensure structure is complete._

Triage was created Step 8, updated Steps 9/10/12. Finalize:

- Recompute Summary counts
- Ensure Salvage / failure log section is present (empty if none)
- Confirm every needs-review entry has a terminal `Status:` (no leftover
  `pending` unless user aborted)

Path: `.reviews/plans/<YYYY-MM-DD>-<HHMMSS>-<plan-name>-triage.md` (same
timestamp as Step 3).

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

(... more entries ...)

## Auto-skipped

### #<i> — [<Severity>] <plan-section> (<reviewer>)

- Claim: ...
- Plan reality: ...
- Verified: <yes | no — citation invalid | ...>
- Action: SKIP
- Reasoning: <which criterion applied>

(... more entries ...)

## Needs-review

### #<i> — [<Severity>] <plan-section> (<reviewer>)

- Claim: ...
- Plan reality: ...
- Verified: yes
- Recommendation: <FIX | SKIP>
- Foundational: <true | false>
- Pattern-wide: <true | false; if true, N occurrences>
- Status: <fixed (user-confirmed) | fixed (user freeform) | skipped (user redirected: "...") | skipped (user accepted SKIP) | pending | superseded by item #<N>>

(... more entries ...)

## Salvage / failure log

- <reviewer> output salvaged from text return — did not call Write tool. (if any)
- Reviewer <name> failed after retry; findings unavailable. (if any)
```

Single continuous numbering across all sections.

## Step 14: Final Summary

_One combined summary as the last chat output._

Print the final summary as the LAST chat output (no further chat from
this skill after this):

```text
Auto-fixed: <N> | Auto-skipped: <N> | Needs-review: <N> (fixed: <x>, skipped: <y>)
Triage: .reviews/plans/<timestamp>-<plan-name>-triage.md

Plan updated. Re-read before starting implementation.
```

No `.last-reviewed.json` analog — carry-over via prior triage handles
dedup. "When was this plan last reviewed?" requires listing
`.reviews/plans/` and matching by plan-name prefix.
