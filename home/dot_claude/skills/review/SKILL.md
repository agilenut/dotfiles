---
name: review
description: "Use when reviewing code: before committing, before merging, when user says /review, or when user asks to review changes or a PR"
user-invocable: true
---

# Review Orchestrator

Spawn reviewers, verify, auto-fix obvious, auto-skip obvious mistakes, dialog the ambiguous middle one finding at a time, persist reasoning to a triage file.

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
5. Else → `gh pr view --json number,title,baseRefName,headRefName`
6. If PR exists → PR mode
7. Else → branch mode (`main..HEAD`)
8. If on main with no changes → nothing to review

### PR-mode pre-check (branch match)

In PR mode, before any other work: confirm `git branch --show-current` equals `gh pr view --json headRefName --jq .headRefName`. **Detached HEAD edge case:** if `git branch --show-current` returns empty (detached HEAD), surface: `Detached HEAD detected. Check out the PR's branch first.` and stop. Otherwise on mismatch, surface error and stop:

> `PR #<N> is on branch <X>; you're on <Y>. Switch branches first.`

Do NOT auto-switch.

### Reviewer selection

Arguments can include reviewer names: `security`, `ux`, `ai`. These combine with scope arguments in any order.

- `/review ai` → auto-detect scope + force AI reviewer on (in addition to base + auto-detected)
- `/review branch security ai` → branch mode + force security and AI on
- `/review only ai` → auto-detect scope + run ONLY the AI reviewer
- `/review only security ai` → run ONLY security and AI reviewers
- `/review pr only ux` → PR mode + run ONLY the UX reviewer

Rules:

- Without `only`: named reviewers add to defaults (base always included, others auto-detected from diff)
- With `only`: run ONLY the explicitly named reviewers — skip base and auto-detection
- Reviewer arguments and scope arguments can appear in any order

## Step 2: Gather Context

Read for the orchestrator's own use AND to pass to reviewers:

- `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md` (conventions)
- **Intent context, in precedence order:**
  1. Plan file matching the current branch slug, or the most recently modified plan touching files in the diff. Resolve plans directory per CLAUDE.md "Plans Directory Resolution".
  2. PR body in PR mode: `gh pr view <number> --json body --jq .body`
  3. Full commit message bodies on the branch: `git log main..HEAD --format=%B`
  4. None found → emit a chat note **before the chat opener (or unconditionally at end of Step 14 if no items need review)**: `No plan/PR/commit bodies — criteria applied with reduced confidence; more findings will land in needs-review.` Don't gate the note behind dialog flow.
- **Diff, per mode:**
  - Local: `git diff` + `git diff --cached`
  - Unreviewed: `git diff <sha>..HEAD` (sha from `.last-reviewed.json`)
  - Branch: `git diff main..HEAD`
  - PR: `gh pr diff <number>`
- **Review preferences** (orchestrator-only, never passed to reviewers):
  - `~/.claude/review-preferences.md` (user-scope, if it exists)
  - `<project-root>/.claude/review-preferences.md` (project-scope, if it exists)
- **Prior triage** for carry-over: scan `.reviews/code/` for the most recent file matching `<timestamp>-<branch>-triage.md` where the frontmatter `branch:` equals the current branch. Read it if found.

## Step 3: Spawn Reviewers (MUST use Agent tool — do NOT inline)

You MUST use the Agent tool. Do NOT perform the reviews yourself.

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

Subagent types: `base-reviewer`, `security-reviewer`, `ux-reviewer`, `ai-reviewer`.

Spawn all selected reviewers in parallel (one message, multiple Agent calls).

Each Agent prompt receives:

- Branch name
- Output path: `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-<type>.md` — run `date +%Y-%m-%d-%H%M%S` to get the timestamp; do NOT hardcode it
- Full diff
- CLAUDE.md contents
- **Plan file PATH** (not content) if intent context found one — reviewer reads it directly to understand goals and respect Decisions
- **Mandatory write rule** (verbatim, in every spawn prompt): `MANDATORY: Your final action MUST be a Write tool call writing your findings to the output path above. Text-only return will be rejected — file MUST contain a heading matching '# .* Review:' or '## Findings'.`

Wait for all agents to complete.

## Step 4: Post-Spawn Enforcement (salvage-first)

For each spawned reviewer, verify output before triage:

1. Read the expected output path.
2. **File exists AND contains the required heading structure** (matches `^# .+ Review:` on a single line, OR contains a `## Findings` heading) → accept.
3. **File missing/empty OR malformed**, but the Agent tool's return string (the orchestrator's previous Agent tool call result for this reviewer) contains the required heading structure → salvage: write that returned text to the expected path. Log in triage (buffer in memory; emit when triage file is initialized in Step 8 under `## Salvage / failure log`): `<reviewer> output salvaged from text return — did not call Write tool.`
4. **Neither path has structure** → re-spawn ONCE. Compose the new Agent prompt as: **the original spawn prompt verbatim** (diff, CLAUDE.md, plan path, output path, all of it) **prepended** by this reminder: `Your previous attempt did not write valid output to <path>. The file MUST contain a heading matching '# .* Review:' or '## Findings'. Your final action MUST be a Write tool call to that exact path.` Do not send only the reminder — the agent needs the full original context to redo the review.
5. **Still failing after re-spawn** → hard-fail that reviewer. Log in triage: `Reviewer <name> failed to produce output after retry; findings unavailable.` Continue with other reviewers.

Structure-presence is the discriminator, not byte count.

## Step 5: Build Atomic Findings

For each accepted reviewer output:

1. Extract each bullet/finding. Capture the verbatim reviewer text alongside the atomic finding (Step 12's `c`-for-context reads from this, not from the reviewer file).
2. **Composite split:** only when a bullet has 2+ distinct file:line refs AND the recommendations don't share a single fix. Otherwise treat as one.
3. **Dedupe across reviewers:** same finding from multiple reviewers → one entry, attribute both `(security, base)`. Match by `same file + same root issue (paraphrase equivalence)`.

## Step 6: Verify-First Per Finding

For every atomic finding, BEFORE assigning a bucket:

1. Open the cited file at the cited line via Read.
2. Read enough surrounding code to verify the reviewer's factual claim.
3. **Articulate in the triage file (mandatory):**

   ```text
   Claim: <reviewer's claim>
   Code reality: <what the code actually does>
   Verified: yes | no
   ```

4. **Invalid citation:** if the cited file does not exist, the line is out of range, or the cited code clearly does not match the claim's premise (reviewer hallucinated), set `Verified: no — citation invalid`. Auto-skip with reason `unverifiable citation` (this maps to Step 7's "Reviewer clearly wrong" auto-skip criterion). Do not re-spawn the reviewer; the log line itself signals reviewer unreliability for this run.

The `Claim:` / `Verified:` lines are mandatory evidence. Missing them is self-evident protocol violation — never skip this step.

**Verify-first self-check before Step 7:** scan the draft triage. If any finding lacks the `Claim:` / `Code reality:` / `Verified:` triplet, STOP and return to Step 6 for that finding before bucketing. This converts the "mandatory" norm into a checkable gate.

## Step 7: Bucket Each Finding

For each verified finding, run pre-bucket skip checks first; on no match, apply bucket criteria; finally run second-pass flags.

### Pre-bucket skip checks (terminal — if matched, bucket is set, skip rest)

Match by `same file + same root issue (paraphrase equivalence)`. Line number is a soft signal only.

- **Carry-over from prior triage:**
  - User-driven skip (status `skipped (user redirected)` or `skipped (user accepted SKIP)`) → carry as auto-skip: `previously skipped by user: <reason>; reference: <prior-triage-path>`
  - `auto-skipped` / `fixed` / `pending` → do NOT carry. Re-bucket fresh (auto-skipped reproduces deterministically; fixed re-surfacing means fix didn't stick; pending means user bailed)
- **Preferences match** (rule in user or project `review-preferences.md`) → auto-skip with `matches review-preference: "<rule>"`
- **CLAUDE.md / plan Decisions match** (finding contradicts an explicit rule or settled Decision) → auto-skip citing it. "New information" exception: if reviewer cites a fresh library API change or security implication the plan didn't consider, that's new info — proceed to bucket criteria. Restating a tradeoff the plan already discussed is NOT new info.

### Bucket criteria

- **Auto-fix** (ALL): verified yes; mechanical (typo, missing import, single-line correction, missing test case for a path the diff introduced); no behavior change beyond the fix's scope; no test rewriting; doesn't substantively expand scope (small boyscouting OK); fixes a gap from current work OR addresses a clear UX risk. Multi-file fine if correct + aligned + small-scoped.

- **Auto-skip** (ANY): reviewer clearly wrong (`unverifiable citation` from Step 6 counts here); diminishes plan goal with no alt path that preserves both; large architectural / maintenance / developer burden; significantly more complexity for little gain. Examples: reviewer cites nonexistent file:line; finding proposes rewriting an unrelated module as async; suggests adopting an alternative library that's a multi-day spike.

- **Needs-review** (everything else): close tradeoffs; diverts from plan approach; scope outside planned work exceeding boyscouting; important contract changes (API shape differs from plan); reviewer found new info shifting tradeoff weight; OR diminishes goal but a viable alt path exists. Examples: `IEnumerable` vs `List` return-type tradeoff; API contract drift from plan endpoint table; `Result<T>` instead of throwing for one function; rename of a method appearing in 6 other call sites.

### Escalation rules (override auto-skip → force needs-review)

If any apply, the finding goes to needs-review regardless of other reasoning. Better to ask one extra question than silently skip an important call.

- **Hesitation → escalate.** Uncertain whether auto-fix or auto-skip cleanly fits? Escalate. Auto-buckets are for unambiguous cases.
- **No thought-terminator labels.** "Cosmetic", "defensible", "minor", "stylistic", "nit" need a concrete harm-avoided named next to them. If none exists, escalate.
- **Name-vs-meaning check.** Diff reshapes a URL/route/DTO/contract → any identifier whose name embeds the removed concept must surface as needs-review. Stale names compound across siblings — never auto-skip.
- **Plan deviation → escalate.** Implementation diverges from plan's endpoint table / Decisions / glossary / named contract → needs-review, even if divergence looks defensible. Plan is the contract.
- **Don't adopt reviewer hedges wholesale.** Reviewer's own skip-reasoning ("not blocking", "just cosmetic") is not your bucket call. Re-verify under your own analysis; if it holds, document why; if not, escalate.

### Second-pass flags (after all findings are bucketed)

- **Foundational** — mark `foundational: true` when accepting the finding would moot or reshape 2+ other findings in this run. Signals: "consider X instead", "could be replaced with", "challenges the plan's chosen approach". Changes dialog ordering (Step 9 / Step 12) and triggers re-evaluation after acceptance; does NOT change bucket. Default false when in doubt. _Anti-example:_ additional test case (no reshape). _Example:_ changing storage from JSON to YAML (moots all JSON-parsing findings).

- **Pattern-wide** — runs only when the reviewer's recommendation is a **rename**, **pattern substitution** ("use X instead of Y"), or **convention change** ("always parameterize queries"). Phrasing signals: "rename", "use X instead", "consistency", "always", "across", "every occurrence". Local fixes (missing null check, single-site bug, off-by-one) → skip the check.

  When triggered: grep for the cited literal token (length ≥ 4, not in denylist `if/for/get/set/var/let/null/true/false/new/use/try`), excluding the file/lines under review and `*/test/*`, `*/__snapshots__/*`, `*/fixtures/*`, `vendor/`, `node_modules/`. 2+ other occurrences → `pattern-wide: true`, force needs-review even if criteria would otherwise auto-skip. Per-finding card carries `Pattern: same token in N other places.` User decides propagate / here-only / skip in dialog.

  For semantic patterns (no literal token), use reviewer phrasing alone — if they wrote "this pattern appears elsewhere", treat as pattern-wide.

## Step 8: Initialize Triage File

Before any dialog or auto-fix, write the triage file at `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-triage.md` (same timestamp as Step 3). Use the canonical structure defined in Step 13 with these initial values:

- Frontmatter: `snapshot-sha: null` (filled at Step 10), other fields populated
- Summary: `pending: N-needs-review`, `fixed: 0`, `skipped: N-auto-skipped`
- Auto-fixed section: empty placeholder
- Auto-skipped section: full entries (already known from Step 7)
- Needs-review section: full entries with `Status: pending`, foundational/pattern-wide flags set
- Salvage / failure log: all buffered entries from Step 4 (empty if none)

Steps 9, 10, and 12 update in place. Step 13 finalizes.

## Step 9: Foundational Dialog (if any)

Foundational items must dialog with the user BEFORE any auto-fix is applied. Auto-fix is a commitment within a direction; don't commit while direction is in flux.

For each foundational item (in severity order), present the per-finding card (see Step 12 format) with the addition:

```text
Heads up — this is foundational. If you take it, items #X, #Y, #Z may
not apply; I'll re-evaluate them after your decision.
```

After resolution:

- **Accepted** → re-run verify-and-bucket on the listed dependent items. Some may flip to auto-skip with reason `superseded by item #<N>`. Update the triage file in place.
- **Skipped** → dependent items stay in their original buckets.

If no foundational items exist, skip directly to Step 10.

## Step 10: Apply Auto-Fixes

The triage file already exists from Step 8; update it in place.

1. **Before the first fix lands**, update triage frontmatter with `snapshot-sha: <git rev-parse HEAD>`.
2. **Resolve verifier commands once, upfront** (build for non-test fixes; targeted-test for test fixes). Resolution ladder, applied to both:
   1. Explicit `build-command:` / `test-command:` in CLAUDE.md
   2. Detect by project marker: `package.json` → `npm run build --silent` / `npx vitest run <file>` (or similar); `*.csproj` → `dotnet build -v quiet` / `dotnet test --filter <TestClass>`; `pyproject.toml` → typically no compile; `pytest <path>` for tests; markdown-only diff → no build/test needed
   3. None detected → **pause and ask the user before the first auto-fix:** `No <build|test> command detected. Options: (a) name a command, (b) skip and verify manually before commit, (c) abort auto-fix and review everything together. a/b/c?` Do NOT silent-skip — applies the hesitation → escalate rule to the safety net.
3. **Test-fix detection:** file path contains `/test`, `_test.`, `.spec.`, `.test.`, `Tests/`, `tests/`, or matches the project's test conventions → test fix; else non-test.
4. For each auto-fix:
   - Apply via `Edit` (writes unstaged).
   - Move finding into the triage's `## Auto-fixed` section with `Status: fixed (auto)`.
   - Run the matching verifier (build for non-test; targeted-test for test fixes).
   - **On failure:** `git checkout -- <file>`, re-bucket as needs-review with reason `auto-fix failed build/test: <summary>`, move the entry to the Needs-review section.

Do not run the full test suite — the end-of-review reminder cues that.

## Step 11: Chat Opener

After auto-fix completes, print the opener:

```text
Auto-fixed: <N> | Auto-skipped: <N> | Triage: .reviews/code/<timestamp>-<branch>-triage.md
Needs your review: <N> — let's start with #<first>.
```

If no items need review, skip to Step 13.

## Step 12: Needs-Review Dialog (One at a Time)

Present findings in this order: critical → important → suggestions. Within each tier, pattern-wide candidates ordered by codebase-echo count (highest first). Foundational items were already dialogged in Step 9; any that the user left undecided there reach this step as ordinary needs-review items at their natural severity.

### Per-finding card format

```text
Review item <i> of <N> — needs your call

[<Severity>] <path/to/file.ext>:<line> (<reviewer>)

Claim: <one short paragraph quoting / paraphrasing the reviewer>

Verified: <yes | no> — <one-line code-reality summary>

Risk if skipped: <one line, ONLY when not self-evident from Claim>

[Pattern: same shape in <N> other places (full list in triage).]   <-- only for pattern-wide candidates

My take: <FIX | SKIP> — <reasoning>

[Why surfacing this: <one line>]   <-- ONLY when My take is SKIP but item is surfaced anyway (foundational or pattern-wide)

y fix / n skip / c more / or type
```

### Input parsing

- `y` → accept the recommendation (whichever was proposed — fix or skip).
- `n` → take the opposite. If `My take: SKIP`, ask the user how to fix (or accept their inline freeform fix); if `My take: FIX`, mark skipped with the user's reason.
- `c` → expanded context (see below); re-prompt the menu after.
- **Any input containing `c` (`c`, `yc`, `nc`)** → show expanded context first; then re-prompt the menu with the user's leaning noted (e.g., `Context shown. Still leaning y/n? — re-prompt y/n/c.`). This honors the user's CLAUDE.md preference for combination answers.
- Anything else → freeform. Orchestrator answers, then re-offers `y/n/c`.
- `yn` / `ny` (no `c`) → invalid (no coherent meaning); re-prompt.

### `c` for context

Cap response at ~40 lines. Priority order if space is tight:

1. Verbatim reviewer quote (from the reviewer's report file)
2. ~20-line code window around the cited line
3. Tradeoffs: fix-as-recommended / alternative / skip
4. Related findings in same file (if any)

If user needs more, they ask freeform.

### After resolution

For each item:

- **User-confirmed fix** (user pressed `y` against `My take: FIX`): apply via Edit, build/test as in Step 10, update triage `Status: fixed (user-confirmed)`.
- **User-redirected to skip** (user pressed `n` against `My take: FIX`): update triage `Status: skipped (user redirected: "<reason>")`.
- **User accepted skip** (user pressed `y` against `My take: SKIP`): update triage `Status: skipped (user accepted SKIP)`.
- **Fixed via freeform** (user proposed a different fix): apply via Edit; update triage `Status: fixed (user freeform)` with the user's reasoning.

### Opt-in preference capture (on user redirect)

**Trigger condition (AND of):** (1) user redirected — pressed `n` against `My take: FIX` (now skipped) — AND (2) the redirect reason contains a generalizing signal. **OR**: user explicitly typed `remember` / `capture`. Ask ONCE per finding only when these hold:

```text
Capture as preference?

Drafted: "<rule based on the user's redirect reason>"
Why: <project pattern / user redirect>; captured <date>.

Save to project / user / no? p / u / n
```

ONLY offer when the redirect reason contains a generalizing signal: "we always", "this codebase prefers", "middleware validates these", "don't flag this category", or a clear pattern phrase. For one-off / case-specific redirects, do not offer — the reasoning lives only in the triage file.

On `p`: append the rule to `<project-root>/.claude/review-preferences.md` via Edit.
On `u`: append to `~/.claude/review-preferences.md` via Edit.
On `n`: skip; reasoning stays in triage only.

If the user edits the draft inline, use their text as the rule body.

### Abort / pause

If the user types `stop`, `pause`, `quit`, or sends an interrupt mid-dialog: update remaining items as `Status: pending` in the triage file (the file already exists from Step 8, so this update lands cleanly), print:

```text
Paused at item #<i>/<N>. Resume with /review — re-invocation reads the latest triage and resumes from pending items.
```

Then exit cleanly. Re-invocation of `/review` on the same branch will find this triage in Step 2's prior-triage scan and (when pending items exist) offer to resume the dialog from where it stopped before re-running reviewers.

## Step 13: Finalize Triage File

The triage file was created in Step 8 and updated in place during Steps 9, 10, and 12. Finalize now: recompute the Summary section's counts, ensure the Salvage / failure log section is present (even if empty), confirm every needs-review entry has a terminal `Status:` (no leftover `pending` unless the user aborted in Step 12).

Path: `.reviews/code/<YYYY-MM-DD>-<HHMMSS>-<branch>-triage.md` (same timestamp as Step 3).

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
- Reasoning: <which auto-skip criterion applied; cite CLAUDE.md/preference/Decision if relevant>

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

Single continuous numbering across all sections (matches the dialog ordering).

## Step 14: Update Review Marker + End Reminder

After triage file write:

1. Update `.reviews/code/.last-reviewed.json` — single JSON object mapping branch names to SHAs. Read existing file if present (parse mentally; no trailing commas, no comments), add or update current branch's entry, write back as one well-formed JSON object. Create if missing.
2. PR mode additionally: check `gh pr checks <number> --json name,state --jq '.[] | select(.state != "SUCCESS" and .state != "PENDING")'` and mention any failures in the chat output. Filter to failures only — avoids noise from all-passing checks.
3. Print the end-of-review reminder:

   ```text
   Build green. Stage, run `pre-commit run`, re-stage if modified, then commit.
   Re-build and run full test suite if pre-commit touched code.
   ```

   PR mode additionally append:

   ```text
   Auto-fixes applied locally. Commit+push to update PR; CI will re-run.
   ```

## Rules

- Edits to code/markdown ONLY during Step 10 (eager auto-fix, including foundational-acceptance edits initiated from Step 9) and Step 12 (user-confirmed fix or user-proposed freeform fix). All other steps are read-only.
- Do NOT run mkdir for output directories — Write creates intermediate directories.
- If diff >500 lines, tell user and offer to focus on specific files.
- Triage file's `Claim:` / `Verified:` lines per finding are mandatory evidence — never skip the verify-first step.
- Reviewer agents receive plan file PATH (not content); review-preferences are orchestrator-only (never passed to reviewers).
- Salvage log lines in triage are monitoring data — recurring salvages indicate the reviewer agent prompt needs further tightening.
