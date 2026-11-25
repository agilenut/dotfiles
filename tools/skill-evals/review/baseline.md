# /review eval baseline

Runs of `home/dot_claude/skills/review/SKILL.md`, 2026-11-25, model
`claude-opus-5-5` (confirmed in each response's `modelUsage`), default
effort, Claude Code 2.1.325, 3 runs per case.

Texts:

- **bf786dc**: the text before the rewrite, at commit `bf786dc` on the
  PR branch (GitHub keeps the PR's commits after a squash merge), blob
  `5533d8b99447a0de738ee90b98ff61530375fb51`
- **rewrite**: the goal-first rewrite as committed, blob
  `8063ab4003a66bed085d4cf7532c372d9cb3586d`

`git hash-object home/dot_claude/skills/review/SKILL.md` prints this hash
for the same text. Each run's copy of the skill matched it.

Placements (`run.sh --placement`):

- **user**: the skill at the start of the user message, as a skill
  arrives in a real session (the default)
- **system**: the skill in the system prompt, after Claude Code's own, so
  every case can share it in the prompt cache

## Pass counts

| Case                      | bf786dc, user | rewrite, user | bf786dc, system | rewrite, system |
| ------------------------- | ------------- | ------------- | --------------- | --------------- |
| route-round1              | 3/3           | 3/3           |                 | 3/3             |
| route-skip-checks         | 3/3           | 3/3           |                 | 3/3             |
| route-later-round         | 3/3           | 3/3           |                 | 3/3             |
| route-round1-polish       | 3/3           | 3/3           |                 | 3/3             |
| route-opposite-fixes      | 3/3           | 3/3           |                 | 3/3             |
| route-made-commit-message | 3/3           | 3/3           |                 | 3/3             |
| flags-pattern-wide        | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| flags-foundational        | 3/3           | 3/3           |                 | 3/3             |
| flags-settled             | 3/3           | 3/3           |                 | 3/3             |
| end-record-local          | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| end-next-round            | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| end-round4                | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| end-reviewer-failed       | 3/3           | 3/3           |                 | 3/3             |
| end-record-branch         | 3/3           | 3/3           |                 | 3/3             |
| end-branch-staged-start   | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| dialog-pause              | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| dialog-first-card         | 3/3           | 3/3           |                 | 3/3             |
| spawn-reviewers           | 3/3 \*        | 3/3           | 3/3             | 3/3             |
| triage-init               | 3/3           | 3/3           |                 | 3/3             |
| triage-init-round2        | 3/3           | 3/3           |                 | 3/3             |
| triage-path               | 1/3, 1/3      | 3/3           | 3/3             | 3/3             |

A blank cell: not run.

\* With the answer templates as first written, which carried the
expected values (below). The bf786dc, system column reran those cases
with neutral placeholders.

The bf786dc, user column came from three batches:

- most cases: the first runner, which ran all three runs of a case in
  parallel and left MCP servers and hooks on
- `triage-path` and `triage-init`: an early batch that ran a case's first
  run alone
- `flags-settled`, `triage-init-round2`, and the second `triage-path`
  count: the current runner

## The triage-path gap

bf786dc writes `.reviews/code/<timestamp>-<branch>-triage.md` and never
says to replace the `/` in a branch name. `review-gate mark` accepts only
`<timestamp>-<branch with / as ->-triage.md` directly in `.reviews/code/`.
With the skill in the user message, the model wrote
`2026-11-25-101500-feat/42-widget-export-triage.md` (a subfolder `mark`
refuses) in 2 of 3 runs, in the early batch and again on the current
runner. On the current runner with the skill in the system prompt, it
wrote the dashed name 3 of 3, so the placement likely changed this
answer (3 runs per placement is too few to show it). The
rewrite, which names every file in full in Step 2 with
`<branch-dashed>`, passed 3/3 in both placements.

## Changes to the cases

The first answer templates of seven cases carried the value their check
expected (`"next_round_due": true` and the like), so a model that copied
the template would pass whatever the skill said. They now use neutral
placeholders, and checks on an absent value also check the field is
present.

Two cases were added after the rewrite's reviews, and both pass on
bf786dc too, so they pin behavior the rewrite kept:

- `flags-settled`: a finding the user already skipped keeps its auto-skip
  and gets no pattern-wide flag.
- `triage-init-round2`: a later round's frontmatter (its `round:`,
  `rerun-of:` naming the previous triage file, round 1's `reviewed-tree:`,
  and no `outcome:`).

## Can the cases fail?

Ten cases were each run against a copy of the skill with the rule they
cover deleted. Unless the row says otherwise, the copy was an earlier
draft of the rewrite, run once in the system placement. A pass on one
run can't show the case never fails, so each pass's reason below is
likely, not shown.

| Case                    | Rule deleted                                                                                                | Result                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| route-later-round       | Step 7, Later-round sort (bf786dc, 2 runs, user placement)                                                  | failed 2/2: the typo fix went to logged polish                       |
| dialog-pause            | Step 12, Pause                                                                                              | failed: no fix pass, no pause message                                |
| end-next-round          | Step 14 item 1's next-round bullet and its record line                                                      | failed: wrong record line                                            |
| end-round4              | Step 14 item 1's round-4 bullet                                                                             | failed: wrong record line                                            |
| flags-settled           | the committed text's Second-pass flags limit (2 runs), then also Step 7's "settled there" sentence (3 runs) | passed 2/2, then failed 3/3: the skipped rename was flagged          |
| end-record-local        | Step 14 item 2, sub-item 4 (the `mark` commands)                                                            | passed: `review-gate mark` is named elsewhere in the skill           |
| end-branch-staged-start | Step 14 item 2's staged-start example                                                                       | passed: the "reviewers saw everything" rule above it covers the case |
| flags-pattern-wide      | Step 7, Second-pass flags, Pattern-wide                                                                     | passed: the card's `Pattern:` line and Step 12's order still cue it  |
| spawn-reviewers         | Step 3, the AI reviewer's auto-detection list                                                               | passed: a skill file still drew the AI reviewer                      |
| triage-init-round2      | the committed text's later-round sentence (2 runs), then also the Outcome paragraph's "leave out" (1 run)   | passed 2/2, then 1/1: the round-in-progress block has no `outcome:`  |

The cases that passed still guard their fixed strings and results, but
they can't show that the deleted rule, rather than other text, produced
the decision.

## Runner checks

- With the runner's flags, one session's init event listed no tools and
  no MCP servers.
- A probe run from inside the repo, before hooks were turned off, showed
  a Stop hook's output reaching the model. Every call in the suite's runs
  took one turn, so no case result was affected.

## Cost and time per call

Cost is `total_cost_usd` as the CLI reports it, at list prices.

**bf786dc, user, 54 calls** (first runner: all three runs of a case in
parallel). Every call was cold: each wrote the prompt to the cache and
read back only the first ~7k tokens of the system prompt.

| Measure                            | Mean   | Range         |
| ---------------------------------- | ------ | ------------- |
| Cost (USD)                         | 0.363  | 0.354-0.384   |
| Time to first token (ms)           | 4,722  | 2,175-9,824   |
| Total time (ms)                    | 8,943  | 4,896-14,815  |
| Cache-write tokens                 | 43,270 | 42,961-44,845 |
| Cache-read tokens                  | 6,987  | 5,303-7,086   |
| Output tokens (including thinking) | 785    | 398-1,422     |
| Thinking tokens                    | 243    | 0-746         |

Whole run: $19.62, about 20 minutes.

**rewrite, 63 calls per placement** (current runner: a case's first run
alone, then the rest in parallel). Uncached input was 2 tokens on every
call. In the system placement each case's first run read a shared ~21k
prefix from the cache; in the user placement each case's first run wrote
its whole prompt.

| Measure                            | system mean | system range | user mean | user range   |
| ---------------------------------- | ----------- | ------------ | --------- | ------------ |
| Cost (USD)                         | 0.083       | 0.011-0.362  | 0.132     | 0.012-0.361  |
| Time to first token (ms)           | 4,500       | 2,772-8,115  | 4,220     | 2,293-7,195  |
| Total time (ms)                    | 7,124       | 2,837-12,567 | 7,204     | 2,818-10,383 |
| Cache-write tokens                 | 8,037       | 0-43,347     | 14,225    | 0-43,355     |
| Cache-read tokens                  | 36,065      | 658-44,474   | 29,876    | 649-44,473   |
| Output tokens (including thinking) | 596         | 112-1,079    | 616       | 139-1,017    |
| Thinking tokens                    | 171         | 0-602        | 175       | 0-480        |

Whole run: $5.26 (system) and $8.32 (user), about 20 minutes each. Output
and thinking tokens are close to bf786dc's, so the cost drop comes from
the runner, not the text.
