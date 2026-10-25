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
- User names the work instead of a number ("the billing epic") → find it with the `board` skill's Find named work
- Keyword arg AND user mentions "issue" or "story" → `gh issue list --search <kw> --state open --limit 5`; show titles; ask which (or none)
- Otherwise → topic = user's stated idea; before planning, look for an open issue that already owns the work (`gh issue list --search "<key words from the idea>" --state open --limit 5`). Matches → show them and ask which owns the work, or none.

Treat GH issue criteria as draft, not spec: re-derive scope from this conversation. If no issue owns the work, the plan files one at step 0 (global CLAUDE.md `## Issues and board` says when an issue is needed).

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

When a contested choice resolves, note it in the plan file's **Decisions** section on the spot (file-tier only — see Step 8).

**Surface these during the walk:**

- **Sharpen fuzzy language.** When the user uses overloaded terms ("user", "account", "session"), propose a precise canonical alternative inline. "You're saying 'user' — Customer or AuthenticatedUser? Those behave differently."
- **Stress-test boundaries with scenarios.** When decisions involve relationships, edge cases, or where things break down, invent a concrete scenario that probes it. "What happens when X expires while Y is mid-request?" Force precision.
- **Cross-reference with code.** If the user states how something works, check whether the code agrees. Surface contradictions immediately.
- **Structural concerns.** Architectural mismatch, layer violations, migration risk, pattern reuse opportunities, test gaps, dependency justification, overwrite safety. Example: "You're proposing a new service — but `AuthService` already does 80% of this. Wrap or replace?" See `~/.claude/agents/plan-reviewer.md` for the full checks table.
- **Draft the ACs.** As scope settles, draft each issue's acceptance criteria per the global AC rules (outcomes, satisfiable by that issue, checkable within a day of merging). Map each AC to the PR that meets it.
- **Size the PRs.** Apply Reference: PR Sizing. A PR heading past the guideline is a grill question: split at an existing boundary, or keep it whole with a reason.

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

Path: `<plansDirectory>/<YYYY-MM-DD>-<brief-description>.md` - date plus a brief description; no story numbers in the filename, never auto-generated or random. Resolve `<plansDirectory>` per CLAUDE.md "Plans Directory Resolution".

Frontmatter:

```yaml
---
work: "<work-stream or empty>"
branch: "<branch-name or null>" # primary branch; null when multi-PR
stories: [<issue#s> or empty]
worktree: <true | false>
---
```

Sections, in order (single-PR default):

- **Step 0** - the board steps from the `board` skill. Single-PR plan: the issue (existing `#N` or new); file it if new, add it to the board, move it to In Progress, assign. Multi-PR plan: name every workstream's issue (usually one per PR) and, when there are two or more, the epic's parent issue (existing or new); file all of them now (as sub-issues of the parent, when there is one), in Backlog or Up next per the board skill's column rules, with their ACs; then move only PR 1's issue to In Progress. Each later PR's issue moves to In Progress at its kickoff (Step 10). Until an issue is filed, its draft ACs live here.
- **Goal** — 1–2 sentences
- **Approach** — chosen direction + why (1–2 lines)
- **Decisions** (when the walk had contested sub-choices): each entry: decision + 1-line reason. Include when the choice was contested in the walk, diverges from a convention or default, or its reason isn't self-evident from Approach. Skip no-brainers. When a decision changes, rewrite its entry in place (with "was X; changed because Y" if the history matters) instead of appending a correction.

  Example: `Pure Prettier defaults over .prettierrc.json — user accepts wholesale style flip for ecosystem alignment; CLAUDE.md bullets updated same PR`

- **Glossary** (when terms were sharpened during the walk) — canonical term → 1-line meaning. Only include the terms that actually got resolved.
- **Commits** — numbered; each with title (verb-led, ≤8 words), scope (1-line description), review timing (`per-commit` | `end-of-PR`), manual test (`none` | `<steps>`). Apply Reference: Commit Boundaries and Reference: Review & Test Defaults.

  Example: `1. Add user_role column — expand-contract migration with backfill — review: per-commit — manual: none`

- **Manual test (PR-level)** — when applicable
- **Edges / risks** — items to weigh
- **Open items / Next** (living) - follow-ups, discoveries, and loose threads surfaced during the walk or implementation; keep current as work proceeds. Once a note's PR merges, record the outcome on that PR's line in the PR section (e.g. "DONE `<sha>`") and delete the note. Before the plan's last PR merges, each follow-up joins a planned PR, gets an issue the user agrees to, or is dropped with the user's OK (global CLAUDE.md `## Issues and board`).

Multi-PR variant: replace `## Commits` with `## PRs`. Use when: foundational refactor + feature on top; scope too large for one review (Reference: PR Sizing); can't test until PR + CI runs (common for CI / infra work). Open the `## PRs` section with the worktree note below, substituting the real work-stream and branch names (no literal placeholders), so any later session follows it without this skill loaded.

Detail only the next PR's commits. Every other PR carries its goal, issue, the ACs it covers, what it depends on, and its open decisions; its commits are written at its kickoff (Step 10), when earlier PRs have shown what it needs. "ACs covered" names ACs by issue and position (`#127 AC 3`), so they stay unambiguous across issues. Before step 0 files them, label new issues in Step 0 (`new-A`, `new-B`) and write `new-A AC 2`; step 0 replaces each label with the real number.

```markdown
## PRs

Worktree: run all PRs from ONE working tree (substitute the real `work:` name). Do NOT call EnterWorktree per PR; for each PR, fetch then `git switch -c <pr-branch> origin/main`.

| PR  | Goal   | Issue     | ACs covered | Depends on |
| --- | ------ | --------- | ----------- | ---------- |
| 1   | <goal> | #N or new | #N AC 1-2   | none       |
| 2   | <goal> | #N or new | #N AC 1-3   | PR 1       |

### PR 1: <title> (branch: <name>)

1. Commit title — scope — review: per-commit — manual: none
2. ...

### PR 2: <title> (branch: <name>)

Goal, open decisions. Before starting: run the PR kickoff (`/plan` Step 10: confirm the previous PR's closeout, re-read, update the plan, write commits, `/review-plan --pr 2`, show the outline, then step 0).
```

No "considered / rejected" section in the file — that lives in chat.

## Step 9: Lock & Handoff

After Step 8 (or after Step 6 for conversation-only), execute in this order:

1. **`/review-plan`.** Multi-PR plan: announce and run `/review-plan --outline` (structure across PRs plus the first PR's commits); skip only if the user says so. Single-PR file-tier plan: ask "Run `/review-plan` for a fresh-eyes pass? y/n", recommending `n` for clear-bounds plans, `y` for high-complexity or uncertain.
2. **Step 0** (conversation-only plans too): the issue and board steps from the plan's Step 0. Write each newly filed issue's number into `stories:`, the PR table, and the branch names (`branch:` frontmatter and each `(branch: <name>)` PR heading).
3. **Branch or worktree**, named with the issue number (Git rules in CLAUDE.md).
4. **Commit 1.**

Plan files are gitignored, so there is no commit step for the plan.

- **Worktree.** Set `worktree: true` if any of: uncommitted changes in main tree, or a feature branch in progress you'd want to keep separate; Docker / port conflict with main-tree services; exploratory work that may be abandoned; user says so. (Multi-PR plans carry their own worktree note in the `## PRs` section - follow it.)

  When `true`:

  1. Invoke `ToolSearch select:EnterWorktree`, then call `EnterWorktree({name: "<feature-branch>"})`. The harness updates cwd to the worktree; the hook creates the branch off main (or attaches if it exists) and checks it out. Do not `cd` or `git -C`.

  When `false`: create the feature branch in main tree. If currently on a different feature branch, surface that first ("you're on `<branch>` — switch to main first?") then `git switch main && git switch -c <feature-branch>`. Plain `git` — don't `cd` or `git -C`.

## Step 10: PR Kickoff (multi-PR plans, before each later PR)

Before starting PR N (N > 1):

1. Confirm the previous PR's closeout ran for each issue it worked (ACs checked, closing comment, card moved per the `board` skill).
2. Re-read the plan's Decisions and Open items, and what merged PRs actually changed: their PR bodies, `.reviews/plans/*-pr<M>-*` triage, and `.reviews/code/*` triage for their branches.
3. Update the plan before writing commits: rewrite any Decision a merged PR changed, update the PR table, and propose AC changes on PR N's issue per the global AC rules.
4. Write PR N's commits in the plan file, numbering on from the previous PR's last commit.
5. Announce and run `/review-plan --pr N`; skip only if the user says so.
6. Show the user a short outline of PR N (the commits, one line each, plus anything that changed since planning) and wait for a go.
7. PR N's step 0 (its issue to In Progress, assigned), then its branch, then its first commit.

## Rules

- Plan files are local-only — gitignored by convention; no "commit the plan" step
- One question at a time during the walk. Don't batch. Don't dump option matrices unless asked.
- If a question is answerable by reading code, don't ask — answer it and surface the answer with your recommendation.
- Capture decisions as they're made: when the walk settles a contested choice, add to the plan file's **Decisions** section with a 1-line reason on the spot (file-tier only). Conversation-only relies on chat history.
- Mid-work changes (tactical revisions, scope shifts): see CLAUDE.md `## Planning`.
- Before implementing a plan item, search the plan's Decisions for its nouns. The item is the task; the Decision that settles it usually sits above. A settled call isn't re-made on judgment; if it looks wrong, say so and ask.
- Never write full plan content in chat — use Edit on the plan file, then summarize what changed.

## Reference: Commit Boundaries

- Unit is the logical change, not the file
- Same logical change across multiple files / apps = 1 commit
- Code + tests together in the same commit; docs can wait for the commit that finishes the behavior they describe, but a PR never merges without its docs
- Don't split mechanical setup from the change that needs it
- Split pre-refactor from new behavior only when pre-refactor stands alone (compiles + tests pass)
- Too-fine smell: would each commit make sense to a reader without the others? If no, merge
- Too-coarse smell: description contains "and"? Consider splitting
- Order to front-load risk: the commit whose failure would invalidate the rest of the plan goes first; cheap mechanical work that depends on nothing goes last

## Reference: PR Sizing

- One intent per PR.
- Aim for about 400 lines of non-test code (generated files, docs, and tests excluded).
- Above about 1,000, look for separable intents and split at existing boundaries (e.g. a standalone refactor first). Size triggers the question; cohesion decides the split.
- An indivisible or mechanical change (rename, codemod, schema squash) stays whole, with a short reviewer's guide in the PR body.
- 10+ commits is a soft signal to split, not a rule.

## Reference: Review & Test Defaults

- Review timing: `per-commit` for non-trivial; `end-of-PR` for a series of small mechanical commits in one PR
- Default toward review; skip only for truly trivial (typo, dep bump). A change to the instructions in files an agent or a person follows as steps (skills, agents, prompts, CLAUDE.md, AGENTS.md, runbooks) is never trivial; a typo fix in them still is.
- Manual test: only when something can't be fully automated (UX/CSS/runtime behavior). Distinguish "testable in CI" from "I can't verify without you"
