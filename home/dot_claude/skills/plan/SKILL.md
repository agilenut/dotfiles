---
name: plan
description: "Use when user signals new work — story / issue / 'let's build X'. Walks the open decisions in dialogue (grill mode); the plan artifact falls out of the dialogue. For listing or loading existing plans, use /plans."
user-invocable: true
argument-hint: "[issue# | keyword]"
---

# Plan Skill

Reach shared understanding via interactive dialogue, then capture the landing as a plan artifact (file or conversation-only).

**Grill mode:** one question per turn with a recommended answer; walk decisions in dependency order; the plan is what the dialogue produced, not a pre-written report.

## Step 1: Resolve Topic

- Issue# arg, or user mentions issue/story by number → `gh issue view <N> --json title,body`
- Keyword arg AND user mentions "issue" or "story" → `gh issue list --search <kw> --state open --limit 5`; show titles; ask which (or none)
- Otherwise → no issue; topic = user's stated idea

Treat GH issue criteria as draft, not spec — re-derive scope from this conversation. Don't offer to create an issue.

## Step 2: Restate Goal

State the goal in 1 sentence. Ask y/n confirm only when real ambiguity exists; otherwise restate and proceed.

## Step 3: Ground in Reality (no chat commentary until grounding completes)

Silently before dialogue:

- Codebase: read related files; grep patterns
- APIs / libraries: Context7
- "How do people solve X" questions: web search
- Existing patterns: search before proposing new
- Current branch (`git branch --show-current`) and uncommitted state (`git status --short`) — Step 9's worktree / branch decisions need both

**Codebase-first rule.** If you'd ask a factual question, check the code first. Don't waste the dialogue on what you can answer yourself.

If grounding fails, say so. Don't guess.

If grounding reveals the topic is too fuzzy to plan, pause back to dialogue. If the right move is to _spike_ (try something quick to learn), propose that instead of forcing a plan.

**Tier read-ahead.** Based on grounding, form a working hypothesis about file-tier vs conversation-only (see Step 7). If file-tier looks likely, you'll write the plan inline during the walk; lock the call at Step 7. If it's clearly trivial, plan to capture in chat only.

## Step 4: Walk the Decisions (the heart of the skill)

Identify the open decisions in this plan. Walk them one at a time:

1. **Pose the question concretely.** One question per turn — no batches, no option matrices.
2. **Give your recommended answer + 1-line principled reason.** Don't ask "what should we do?" — say "I'd do X because Y, agree?"
3. **Wait for user response.** They affirm, redirect, or ask for more.
4. **Resolve dependencies as you go.** Earlier decisions often pivot later ones — walk in dependency order.
5. **Codebase-check, don't ask** when the answer's in the code or docs.

**Surface these during the walk:**

- **Sharpen fuzzy language.** When the user uses overloaded terms ("user", "account", "session"), propose a precise canonical alternative inline. "You're saying 'user' — Customer or AuthenticatedUser? Those behave differently."
- **Stress-test boundaries with scenarios.** When decisions involve relationships, edge cases, or where things break down, invent a concrete scenario that probes it. "What happens when X expires while Y is mid-request?" Force precision.
- **Cross-reference with code.** If the user states how something works, check whether the code agrees. Surface contradictions immediately.
- **Structural concerns.** Architectural mismatch, layer violations, migration risk, pattern reuse opportunities, test gaps, dependency justification, overwrite safety. Example: "You're proposing a new service — but `AuthService` already does 80% of this. Wrap or replace?" See `~/.claude/agents/plan-reviewer.md` for the full checks table.

**Before declaring the walk done**, scan the structural-concerns list one more time and surface any unraised items as additional grill questions. Don't skip this — the structural pass is the absorbed `plan-reviewer` discipline.

**Fast path (user-gated).** If after grounding it looks like there are <2 real open decisions, don't self-elect to skip. Propose: "I see only 1 real open decision: X (rec: Y). Fast-path with direct proposal, or full walk? y/n" — let the user choose.

**Options on demand.** If the user asks "show me options for X", present What / Pros / Cons / Best when per option (≤3). After presenting, return to grill mode — don't keep dumping option matrices for follow-ups.

## Step 5: Stress-Test the Landing

After the walk resolves, run these against the _agreed direction_ — not the abstract problem:

- Hidden assumptions in what we landed on?
- What would you actually do first, and is it the riskiest? (see Reference: Commit Boundaries — front-load risk)
- What would a skeptic ask of THIS plan?
- Scope still right — too big, too small, missing something?

Internal pass. Surface only material concerns in chat (one line each). If a concern is material enough to change direction, loop back to Step 4 to grill it.

## Step 6: Confirm Direction

Summarize the landing in 1–2 lines. If file-tier, point at the plan file path; the file is the source of truth, not the chat summary. Ask "approve?".

On refine:

- **File-tier:** dialogue first (load relevant code / docs / Context7 into context); once resolved, Edit the plan file — never rewrite full plan in chat.
- **Conversation-only:** dialogue updates the shared understanding. If refinements add real structure, promote to file-tier (= run Step 8 now).

## Step 7: Pick Output Tier

File-tier when ANY:

- Multi-step (>1 commit)
- Cross-session (likely to span a break)
- Upfront-obvious complexity

State explicitly which criterion triggered file-tier. Conversation-only otherwise.

- **Promote** (conversation → file): run Step 8 now and capture the agreed direction in the file.
- **Demote** (file → conversation): ask user before deleting the plan file, then delete and continue in chat.

## Step 8: Plan File (file-tier only)

Path: `<plansDirectory>/<YYYY-MM-DD>-<brief-description>.md` per CLAUDE.md "Plan Naming". Resolve `<plansDirectory>` per CLAUDE.md "Plans Directory Resolution".

Frontmatter (matches CLAUDE.md "Plan Frontmatter"):

```yaml
---
work: "<work-stream or empty>"
branch: "<branch-name or null>" # primary branch; null when multi-PR
stories: [<issue#s> or empty]
worktree: <true | false>
---
```

Sections, in order (single-PR default):

- **Goal** — 1–2 sentences
- **Approach** — chosen direction + why (1–2 lines)
- **Glossary** (when terms were sharpened during the walk) — canonical term → 1-line meaning. Only include the terms that actually got resolved.
- **Commits** — numbered; each with title (verb-led, ≤8 words), scope (1-line description), review timing (`per-commit` | `end-of-PR`), manual test (`none` | `<steps>`). Apply Reference: Commit Boundaries and Reference: Review & Test Defaults.

  Example: `1. Add user_role column — expand-contract migration with backfill — review: per-commit — manual: none`

- **Manual test (PR-level)** — when applicable
- **Edges / risks** — items to weigh

Multi-PR variant — replace `## Commits` with `## PRs`. Use when: foundational refactor + feature on top; scope too large for one review; can't test until PR + CI runs (common for CI / infra work).

```markdown
## PRs

### PR 1: <title> (branch: <name>)

1. Commit title — scope — review: per-commit — manual: none
2. ...

### PR 2: <title> (branch: <name>)

3. ...
```

No "considered / rejected" section in the file — that lives in chat.

## Step 9: Lock & Handoff

After Step 8 (or after Step 6 for conversation-only), execute:

- **Worktree.** Set `worktree: true` if any of: uncommitted changes in main tree, or in-flight feature branch you'd want to keep separate; Docker / port conflict with main-tree services; exploratory work that may be abandoned; user says so.

  When `true`:

  1. Invoke `ToolSearch select:EnterWorktree`, then call `EnterWorktree({name: "<feature-branch>"})`. The harness updates cwd to the worktree; the hook creates the branch off main (or attaches if it exists) and checks it out. Do not `cd` or `git -C`.

  When `false`: create the feature branch in main tree. If currently on a different feature branch, surface that first ("you're on `<branch>` — switch to main first?") then `git switch main && git switch -c <feature-branch>`. Plain `git` — don't `cd` or `git -C`.

- **`/review-plan`.** Always ask: "Run `/review-plan` for a fresh-eyes pass? y/n" — recommend `n` for clear-bounds plans, `y` for high-complexity or uncertain. Asking always means the question doesn't get silently skipped.

- **Plan files are gitignored** — no commit step. Don't add to Git muscle memory here.

- **Begin implementation at commit 1.**

## Rules

- Plan files are local-only — gitignored by convention; no "commit the plan" step
- One question at a time during the walk. Don't batch. Don't dump option matrices unless asked.
- If a question is answerable by reading code, don't ask — answer it and surface the answer with your recommendation.
- Capture decisions as they're made: when the walk settles a non-obvious choice, update the plan file with a 1-line reason on the spot (file-tier only). Conversation-only relies on chat history.
- Mid-work changes (tactical revisions, scope shifts): see CLAUDE.md `## Planning`.
- Never write full plan content in chat — use Edit on the plan file, then summarize what changed.

## Reference: Commit Boundaries

- Unit is the logical change, not the file
- Same logical change across multiple files / apps = 1 commit
- Code + tests + docs together in the same commit
- Don't split mechanical setup from the change that needs it
- Split pre-refactor from new behavior only when pre-refactor stands alone (compiles + tests pass)
- Too-fine smell: would each commit make sense to a reader without the others? If no, merge
- Too-coarse smell: description contains "and"? Consider splitting
- Order to front-load risk: the commit whose failure would invalidate the rest of the plan goes first; cheap mechanical work that depends on nothing goes last

## Reference: Review & Test Defaults

- Review timing: `per-commit` for non-trivial; `end-of-PR` for a series of small mechanical commits in one PR
- Default toward review; skip only for truly trivial (typo, dep bump)
- Manual test: only when something can't be fully automated (UX/CSS/runtime behavior). Honestly distinguish "testable in CI" from "I can't verify without you"
