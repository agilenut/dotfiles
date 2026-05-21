---
name: review
description: "Use when reviewing code: before committing, before merging, when user says /review, or when user asks to review changes or a PR"
user-invocable: true
---

# Review Orchestrator

Spawn reviewers, verify, auto-fix obvious, auto-skip obvious mistakes,
dialog the ambiguous middle one finding at a time, persist reasoning to a
triage file.

## Invariants

These don't bend, regardless of step:

- **Verify-first.** Articulate `Claim: / Code reality: / Verified:` in
  the triage file before bucketing any finding. Missing those lines is
  self-evident protocol violation.
- **Triage file is the audit trail.** Every decision lands in
  `.reviews/code/<timestamp>-<branch>-triage.md` with reasoning.
- **Plan is the contract.** If a plan governs the diff, respect its
  Decisions. Only challenge with specific new information (fresh API
  change, security implication) — not a rephrased tradeoff.
- **Hesitation → escalate.** Uncertain which auto-bucket fits (either
  direction)? Surface it. Auto-buckets are for unambiguous cases.
- **Edits only in Step 10 / Step 12.** All other steps are read-only.

## Step 1: Detect Scope and Reviewer Selection

_Figure out what to review and which reviewers to spawn._

### Scope

Explicit arg (first non-reviewer argument wins):

- `branch` → branch mode: `main..HEAD`
- `pr` → PR mode: PR diff
- `unreviewed` → diff since `.last-reviewed.json` entry (fail if no entry)

Default precedence (no arg):

1. Run `git status` and `git diff --stat`
2. Uncommitted changes → **local mode**
3. Clean tree → read `.reviews/code/.last-reviewed.json`; if entry exists
   and `git log <sha>..HEAD` has commits → **unreviewed mode**
4. Else → `gh pr view --json number,title,baseRefName,headRefName`
5. PR exists → **PR mode**
6. Else → **branch mode** (`main..HEAD`)
7. On main with no changes → nothing to review

### PR-mode pre-check

Confirm `git branch --show-current` equals
`gh pr view --json headRefName --jq .headRefName`.

- Empty (detached HEAD) → surface
  `Detached HEAD detected. Check out the PR's branch first.` and stop.
- Mismatch → surface
  `PR #<N> is on branch <X>; you're on <Y>. Switch branches first.`
  and stop.

Do NOT auto-switch.

### Reviewer selection

Args: `security`, `ux`, `ai` (any order; combinable with scope arg).

- Without `only`: named reviewers add to defaults (base always; others
  auto-detected from the diff).
- With `only`: run only the named reviewers; skip base and auto-detection.

## Step 2: Gather Context

_Read everything the orchestrator AND reviewers need before spawning._

- `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md`
- **Intent context**, in precedence order:
  1. Plan file matching branch slug, or most recently modified plan
     touching diff files (resolve plans dir per CLAUDE.md "Plans Directory
     Resolution").
  2. PR body in PR mode: `gh pr view <N> --json body --jq .body`
  3. Commit message bodies: `git log main..HEAD --format=%B`
  4. None found → note in Step 14's final summary:
     `No plan/PR/commit bodies — reduced confidence; more findings landed in needs-review.`
- **Diff** per mode:

  - Local: `git diff` + `git diff --cached`
  - Unreviewed: `git diff <sha>..HEAD`
  - Branch: `git diff main..HEAD`
  - PR: `gh pr diff <number>`

  If the diff is >500 lines, tell the user and offer to focus on specific
  files before continuing.

- **Review preferences** (orchestrator-only, never sent to reviewers):
  - `~/.claude/review-preferences.md` (user-scope, if exists)
  - `<project-root>/.claude/review-preferences.md` (project-scope, if
    exists)
- **Prior triage** (for carry-over): scan `.reviews/code/` for the most
  recent triage with frontmatter `branch:` matching current branch.

## Step 3: Spawn Reviewers (MUST use Agent tool — do NOT inline)

_Run reviewers in parallel; each writes its own findings file._

You MUST use the Agent tool. Do NOT perform the reviews yourself.

### Auto-detection (skip if `only` was used)

Base is always included. Scan the diff for these signals to add others:

**Security — include if diff touches any of:**

- Paths/filenames containing: `auth`, `login`, `session`, `token`,
  `credential`, `permission`, `policy`, `middleware`, `security`, `crypto`
- Dependency manifests: `package.json`, `package-lock.json`, `*.csproj`,
  `pyproject.toml`, `requirements.txt`, `Gemfile`, `go.mod`
- Infrastructure: Dockerfiles, CI/CD workflows, deployment configs
- Config: `.env*`, `appsettings*.json`, connection strings, CORS/CSP/header
  settings
- Database: migrations, schema changes
- Middleware pipeline: `Program.cs`, `Startup.cs`
- Diff text containing: `password`, `secret`, `api_key`, `encrypt`, `hash`,
  `salt`, `certificate`
- Auth attributes: `[Authorize]`, `[AllowAnonymous]`, `ClaimsPrincipal`,
  `HttpContext.User`, `AddAuthentication`, `AddAuthorization`,
  `UseAuthentication`, `UseAuthorization`
- Input handling: `req.body`, `req.params`, `req.query`, `FromBody`,
  `FromQuery`, `request.form`, `request.json`, `IFormFile`
- Unsafe patterns: `innerHTML`, `dangerouslySetInnerHTML`, `v-html`,
  `Html.Raw`, `HtmlString`, `raw(`, `eval(`, `exec(`, `deserialize`,
  `pickle`
- SQL: `SqlCommand`, `FromSqlRaw`, `ExecuteSqlRaw`, `execute(`, raw query
  construction
- File/URL handling: `upload`, `multipart`, `redirect(`, `DataProtection`,
  path construction from user input

**UX — include if any UI files in the diff:**

`.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.html`

**AI — include if diff touches any of:**

- Agent definitions (`agents/*.md`) or skill definitions
  (`skills/**/SKILL.md`)
- Prompt templates: `.yaml`/`.yml` with keys like `prompts:`, `system:`,
  `temperature:`, `max_tokens:`, `messages:`, `model:`
- Files in directories named `prompt*`, `eval*`, `llm*`
- Python/JS/TS importing `openai`, `anthropic`, `claude_agent_sdk`
- Files containing `response_format`, `structured_output`, or
  `ChatCompletion`
- LLM test case files (YAML/JSON with scoring assertions, tolerance bands)

### Spawn

Subagent types (full strings): `base-reviewer`, `security-reviewer`,
`ux-reviewer`, `ai-reviewer`. Spawn all selected in parallel (one message,
multiple Agent calls).

Each Agent prompt receives:

- Branch name
- Output path:
  `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-<type>.md`
  (run `date +%Y-%m-%d-%H%M%S` for timestamp — never hardcode)
- Full diff
- CLAUDE.md contents
- Plan file PATH (not content) if intent context found one — reviewer
  reads it directly. Review-preferences are NEVER sent to reviewers; they
  live orchestrator-only.
- **Mandatory write rule** (verbatim):
  `MANDATORY: Your final action MUST be a Write tool call writing your findings to the output path above. Text-only return will be rejected — file MUST contain a heading matching '^# .+ Review:' or '## Findings'.`

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
   prompt verbatim (diff, CLAUDE.md, plan path, output path) PREPENDED with:
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
2. **Composite split**: only when 2+ distinct file:line refs AND
   recommendations don't share a single fix. Otherwise one.
3. **Dedupe across reviewers**: same finding → one entry, attribute both
   `(security, base)`. Match by `same file + same root issue (paraphrase equivalence)`.

## Step 6: Verify-First Per Finding

_Open the cited code; confirm or deny the reviewer's claim before
bucketing. Non-negotiable._

For every finding, BEFORE bucketing:

1. Read the cited file at the cited line.
2. Read enough surrounding code to verify the reviewer's factual claim.
3. **Articulate in the triage file (mandatory)**:

   ```text
   Claim: <reviewer's claim>
   Code reality: <what the code actually does>
   Verified: yes | no
   ```

4. **Invalid citation**: file/line doesn't exist, or the code doesn't
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

Match by `same file + same root issue (paraphrase equivalence)`. Line
number is a soft signal only.

- **Carry-over from prior triage**: user-driven skip status
  (`skipped (user redirected)` / `skipped (user accepted SKIP)`) → carry
  as auto-skip with
  `previously skipped by user: <reason>; reference: <prior-triage-path>`.
  Other prior statuses (`auto-skipped` / `fixed` / `pending`) → do NOT
  carry; re-bucket fresh.
- **Preferences match** (rule in either `review-preferences.md`) →
  auto-skip with `matches review-preference: "<rule>"`.
- **CLAUDE.md / plan Decisions match**: finding contradicts an explicit
  rule or settled Decision → auto-skip citing it. Exception: reviewer
  cites a fresh library API change or implication the plan didn't
  consider → that's new info, proceed to bucket criteria. Rephrasing a
  tradeoff the plan already discussed is NOT new info.

### Bucket criteria

**Auto-fix** — ALL of:

- Verified yes
- Mechanical (typo, missing import, single-line fix, missing test for a
  path the diff introduced, closing an unfenced code block adjacent to
  fenced ones in a touched file)
- No behavior change beyond the fix's scope
- No test rewriting
- Doesn't substantively expand scope (small boyscouting OK)
- Fixes a gap from current work OR addresses a clear UX risk
- Multi-file fine if correct + aligned + small-scoped

_Examples:_ typo in error message; missing `using` directive; off-by-one
in a comment; rename a misspelled local variable; small-boyscout
markdown fix.

**Auto-skip** — ANY of:

- Reviewer clearly wrong (`unverifiable citation` counts)
- Diminishes plan goal with no alt path that preserves both
- Large architectural / maintenance / developer burden
- Significantly more complexity for little gain

_Examples:_ reviewer cites a nonexistent file:line; rewrite unrelated
module as async; adopt alternative library (multi-day spike).

**Needs-review** — everything else:

- Close tradeoffs
- Diverts from plan approach
- Scope outside planned work exceeding boyscouting
- Important contract changes (API shape differs from plan)
- Reviewer found new info shifting tradeoff weight
- Diminishes goal but viable alt path exists

_Examples:_ `IEnumerable` vs `List` return-type tradeoff; API contract
drift from plan endpoint table; `Result<T>` instead of throwing for one
function; rename of a method in 6 call sites; missing test requires
mocking an external service.

### Escalation rules (override auto-skip → force needs-review)

- **Hesitation → escalate.** Uncertain which auto-bucket fits (either
  direction)? Escalate.
- **Scope-creep hedging is hesitation.** Writing any of `"out of scope"`,
  `"separate PR"`, `"pre-existing not our concern"`,
  `"we'd be piggybacking"`, `"convention sweep deserves its own decision"`
  in your reasoning → escalate. Two cases that LOOK like scope creep but
  are small-boyscout when confident:

  - **Pre-existing mechanical defects in touched files** — unfenced code
    blocks, typos, missing language tags, broken syntax. Confident →
    auto-fix. Hedging → escalate with `My take: FIX`. Split judgment-laden
    parts (heading restructures, content rewrites) into needs-review.
  - **Convention sweeps with one obvious winner** — 80%+ of codebase or
    the branch's own work already aligned. Confident → auto-fix. Hedging
    → escalate. Reserve "separate PR for convention" for genuinely
    contested choices.

  When escalating from hedging, render `Why surfacing this:` showing the
  prior hesitation.

- **No dismissive labels.** `"cosmetic"`, `"defensible"`, `"minor"`,
  `"stylistic"`, `"nit"`, `"MVP"`, `"small project"`, `"low user count"`,
  or similar shorthand are not skip reasons — they end thinking. Each
  needs a concrete harm-avoided named alongside. If none exists, escalate.
- **Stale-name check.** Diff reshapes a URL / route / DTO / contract →
  any identifier whose name embeds the removed concept → needs-review.
  Stale names compound across siblings.
- **Plan deviation.** Implementation diverges from plan's endpoint table
  / Decisions / glossary / named contract → needs-review even if
  defensible. Plan is the contract.
- **Don't adopt reviewer hedges wholesale.** Reviewer's skip-reasoning
  (`"not blocking"`, `"just cosmetic"`) is not your bucket call.
  Re-verify; if it holds, document why; otherwise escalate.

### Second-pass flags (after all findings bucketed)

- **Foundational**: mark `foundational: true` when accepting would moot
  or reshape 2+ other findings. Signals: `"consider X instead"`,
  `"could be replaced with"`, `"challenges the plan's approach"`. Changes
  dialog order (Step 9 / Step 12); does NOT change bucket. Default false.
  _Example:_ changing storage from JSON to YAML (moots all JSON-parsing
  findings).

- **Pattern-wide**: only when reviewer's recommendation is a **rename**,
  **pattern substitution** ("use X instead of Y"), or **convention change**
  ("always parameterize queries"). Signals: `"rename"`, `"use X instead"`,
  `"consistency"`, `"always"`, `"across"`, `"every occurrence"`. Local
  fixes (missing null check, single-site bug) → skip.

  When triggered: grep the cited literal token (length ≥ 4, not in
  denylist `if/for/get/set/var/let/null/true/false/new/use/try`), excluding
  file/lines under review + `*/test/*`, `*/__snapshots__/*`,
  `*/fixtures/*`, `vendor/`, `node_modules/`. 2+ other occurrences →
  `pattern-wide: true`, force needs-review. Card carries
  `Pattern: same token in N other places.`

  Semantic patterns (no literal token): use reviewer phrasing — "this
  pattern appears elsewhere" → treat as pattern-wide.

## Step 8: Initialize Triage File

_Create the persistent audit file before any auto-fix or dialog._

Write `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-triage.md` (same
timestamp as Step 3) using the canonical structure from Step 13 with these
initial values:

- Frontmatter: `snapshot-sha: null` (set at Step 10); other fields
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

_Apply mechanical fixes; verify each via build / targeted test._

1. Before the first fix, set triage frontmatter
   `snapshot-sha: <git rev-parse HEAD>`.
2. **Resolve verifier commands upfront** — build for non-test fixes,
   targeted-test for test fixes. Resolution ladder, applied to both:
   1. Explicit `build-command:` / `test-command:` in CLAUDE.md
   2. Project marker detection:
      - `package.json` → `npm run build --silent` /
        `npx vitest run <file>` (or similar)
      - `*.csproj` → `dotnet build -v quiet` /
        `dotnet test --filter <TestClass>`
      - `pyproject.toml` → no compile typically; `pytest <path>` for tests
      - markdown-only diff → no build/test needed
   3. None detected → pause and ask:
      `No <build|test> command detected. Options: (a) name a command, (b) skip and verify manually, (c) abort auto-fix. a/b/c?`
      Do NOT silent-skip — applies the hesitation → escalate rule to the
      safety net.
3. **Test-fix detection**: file path contains `/test`, `_test.`,
   `.spec.`, `.test.`, `Tests/`, `tests/`, or matches project conventions
   → test fix; else non-test.
4. For each auto-fix:
   - Apply via `Edit` (writes unstaged).
   - Move finding into triage `## Auto-fixed` with `Status: fixed (auto)`.
   - Run the matching verifier.
   - On failure: `git checkout -- <file>`, re-bucket as needs-review with
     reason `auto-fix failed build/test: <summary>`, move entry to
     Needs-review.

Do not run the full test suite — Step 14 reminder cues that.

## Step 11: Dialog Intro (only when needs-review items exist)

_Brief intro before the per-finding dialog. Skipped when no items
need review._

If `N` needs-review items > 0, print:

```text
Needs your review: <N> findings. Starting with #<first>.
```

If `N` = 0, skip directly to Step 13. The final summary at Step 14 is the
user's only chat output for this run.

## Step 12: Needs-Review Dialog (one at a time)

_Walk findings with the user, one at a time, applying chosen fixes._

Order: critical → important → suggestions. Within each tier, pattern-wide
candidates first (by codebase-echo count). Foundational items already
handled in Step 9; user-undecided ones land here at natural severity.

### Per-finding card format

```text
Review item <i> of <N> — needs your call

[<Severity>] <path/to/file.ext>:<line> (<reviewer>)

Claim: <one short paragraph quoting / paraphrasing the reviewer>

Verified: <yes | no> — <one-line code-reality summary>

Risk if skipped: <one line, ONLY when not self-evident from Claim>

[Pattern: same shape in <N> other places (full list in triage).]   <-- only for pattern-wide candidates

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
2. ~20-line code window around the cited line
3. Tradeoffs: fix-as-recommended / alternative / skip
4. Related findings in same file

If user needs more, they ask freeform.

### After resolution (Status updates)

- `y` against `FIX` → apply via Edit, run verifier per Step 10,
  `Status: fixed (user-confirmed)`.
- `n` against `FIX` → `Status: skipped (user redirected: "<reason>")`.
- `y` against `SKIP` → `Status: skipped (user accepted SKIP)`.
- Freeform fix → apply via Edit, `Status: fixed (user freeform)` with the
  user's reasoning captured in the entry.

### Opt-in preference capture (on user redirect)

**Trigger** (AND of):

1. User redirected — EITHER `n` against `FIX` OR `n` against `SKIP`. Both
   directions count:
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
  to this codebase's conventions, technology, or patterns. Examples:
  `"we always validate at middleware"`,
  `"models use TableName attribute"`.
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
Paused at item #<i>/<N>. Resume with /review — re-invocation reads the
latest triage and resumes from pending items.
```

Exit cleanly. Re-invocation finds the triage via Step 2's prior-triage
scan; if pending items exist, offer to resume the dialog before re-running
reviewers.

## Step 13: Finalize Triage File

_Recompute summary counts; ensure structure is complete._

Triage was created Step 8, updated Steps 9/10/12. Finalize:

- Recompute Summary counts
- Ensure Salvage / failure log section is present (empty if none)
- Confirm every needs-review entry has a terminal `Status:` (no leftover
  `pending` unless user aborted)

Path: `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-triage.md` (same
timestamp as Step 3).

Frontmatter:

```yaml
---
branch: <branch>
mode: <local | branch | unreviewed | pr>
snapshot-sha: <sha> # captured before first auto-fix
reviewers-ran: [base, security, ux, ai]
plan-file: <path or null>
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

### #<i> — [<Severity>] <file>:<line> (<reviewer>)

- Claim: ...
- Code reality: ...
- Verified: yes
- Action: FIX — <one-line summary of change>
- Reasoning: <why this met auto-fix criteria>

(... more entries ...)

## Auto-skipped

### #<i> — [<Severity>] <file>:<line> (<reviewer>)

- Claim: ...
- Code reality: ...
- Verified: <yes | no — citation invalid | ...>
- Action: SKIP
- Reasoning: <which criterion; cite CLAUDE.md/preference/Decision if relevant>

(... more entries ...)

## Needs-review

### #<i> — [<Severity>] <file>:<line> (<reviewer>)

- Claim: ...
- Code reality: ...
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

## Step 14: Update Review Marker + Final Summary

_Silent file updates first, then one combined summary as the last chat
output._

1. Update `.reviews/code/.last-reviewed.json` — single JSON object mapping
   branch → SHA. Read existing if present (parse mentally; no trailing
   commas / comments), add or update current branch's entry, write back as
   one well-formed JSON object. Create if missing.
2. PR mode: `gh pr checks <number> --json name,state --jq '.[] | select(.state != "SUCCESS" and .state != "PENDING")'` —
   note any failures for the summary.
3. Print the final summary as the LAST chat output (no further chat from
   this skill after this). Per-item enriched format with counts and item
   numbers so the user can reference items by number for follow-up (e.g.,
   "actually fix #4"):

   ```text
   Auto-fixed (<N>/<total>): #<i> (<5-word descriptor>), #<j> (<descriptor>), ...
   Auto-skipped (<N>/<total>): #<i> (<descriptor>), ...
   Needs-review (<N>/<total>; fixed: <x>, skipped: <y>, pending: <z>):
     #<i> — <status>: <5-word user reason or descriptor>
     ...

   Triage: .reviews/code/<timestamp>-<branch>-triage.md

   Build green. Stage, run `pre-commit run`, re-stage if modified, then commit.
   Re-build and run full test suite if pre-commit touched code.
   ```

   `<total>` is the total count of findings across all buckets. Omit a
   section if its count is 0. Descriptor format: short (≤6 words),
   action-or-content focused. Examples: `typo in error msg`,
   `missing using directive`, `matches review-preference`,
   `parameterize SqlCommand`, `covered by middleware upstream`.

   PR mode appends:

   ```text
   Auto-fixes applied locally. Commit+push to update PR; CI will re-run.
   Failed checks: <list> (or "none")
   ```
