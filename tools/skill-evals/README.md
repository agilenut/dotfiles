# Skill evals

Headless tests for skill and CLAUDE.md text. Each case puts the model at
one decision point, gives it the facts earlier steps would have produced,
and checks its decision with jq. They exist so a rewrite can be run
against the same cases as the text it replaces.

- `review/` tests the `/review` skill. Run it without `--safe-mode`, so
  the global CLAUDE.md loads as it does in a real session.
- `claude-md/` tests the global CLAUDE.md itself: how a session acts on
  review-gate's refusals and on `/review`'s `Recorded:` and
  `Not recorded` lines. Run it with `--safe-mode`, so the deployed copy
  doesn't load next to the text under test.

Each call runs with no built-in tools (`--tools ""`), no MCP servers
(`--strict-mcp-config`), and no hooks, from an empty temporary directory.
No project `CLAUDE.md` or memory reaches the model; the global
`~/.claude/CLAUDE.md` loads unless `--safe-mode` is set. By default the
text under test goes at the start of the user message, as a skill arrives
in a real session. `--placement system` puts it in the system prompt
instead (after Claude Code's own), so every case shares it in the prompt
cache: cheaper while iterating, but placement can change an answer, so a
full run in the default placement is the check before a change ships.
`review/baseline.md` has the results for each placement.

## What a pass shows

A case that passes 3 of 3 runs shows the text produces that decision
reliably enough to catch a large regression. It doesn't show the decision
is always right: a case that passes 90% of the time goes 3/3 about 73% of
the time. Run a case more times when a change targets its behavior.

The cases give the model facts already classified in the skill's terms
(Step 6's `Verified:` lines, "the fix changed behavior"). So they test
whether the model applies the skill's rules to those facts, not:

- whether it classifies a raw reviewer finding correctly
- whether it keeps a rule in mind deep into a long real run
- whether it does the steps in order, with real tool calls and files

With no tools, Claude Code's own Bash tool guidance (which may say, for
example, to commit only when the user asks) isn't in context. So a
`claude-md/` pass doesn't show that CLAUDE.md wins over that guidance.

## Run

```bash
# The text at a commit (here HEAD) into the ignored .runs/ folder
mkdir -p tools/skill-evals/.runs
git show HEAD:home/dot_claude/skills/review/SKILL.md > tools/skill-evals/.runs/review-SKILL-HEAD.md

# All cases, 3 runs each
bash tools/skill-evals/run.sh tools/skill-evals/.runs/review-SKILL-HEAD.md tools/skill-evals/review

# Some cases, 5 runs each
bash tools/skill-evals/run.sh <skill file> tools/skill-evals/review --runs 5 end-round4 dialog-pause

# Some cases with the skill in the system prompt, cheaper while iterating
bash tools/skill-evals/run.sh <skill file> tools/skill-evals/review --placement system end-round4

# The CLAUDE.md suite, on the source copy
bash tools/skill-evals/run.sh home/dot_claude/CLAUDE.md tools/skill-evals/claude-md --safe-mode

# Check the case files only (no model calls)
bash tools/skill-evals/run.sh <skill file> tools/skill-evals/review --check
```

`run.sh` prints PASS or FAIL for each run of each case, with the names of
the failed checks, then the total cost, and exits 1 if any run failed.
Everything it saw is in
`tools/skill-evals/.runs/<suite>-<placement>-<timestamp>-<suffix>/`:
the skill text it used, `summary.tsv` (result, cost, time to first token,
tokens), for each case the prompt, and for each run the raw response, the
extracted answer, and its failures.

A case that doesn't pass every run doesn't pass. Run it more times to see
whether the case or the skill text is at fault before changing either.

## Cost

Each call sends the whole text under test, plus the global `CLAUDE.md`
unless `--safe-mode` is set. A case's first run writes its prompt to the
prompt cache and its later runs read it, so most of a case's cost is its
first run. A full `/review` suite of 3 runs per case takes about 20
minutes (2026-11). `run.sh` prints the total cost when it finishes;
`summary.tsv` has each call's cost, and `review/baseline.md` has the
measured numbers.

## Layout

- `run.sh`: the runner (the text under test and the suite folder are
  arguments)
- `<suite>/preamble.md`: framing shared by a suite's cases
- `<suite>/cases/<name>.md`: the scenario and the JSON shape to answer in
- `<suite>/cases/<name>.jq`: checks; prints the names of those that failed
- `review/behaviors.md`: what the `/review` skill must keep doing, where
  in the skill it does it, and the cases that cover it
- `<suite>/baseline.md`: pass counts on each text the suite has run on

## Writing a case

- One purpose per case. Add a check only when a reasonable reviewer
  wouldn't dispute its expected result under the skill's text.
- Give the facts the earlier steps produced (Step 6's verified lines, the
  starting state, what `review-gate` prints). Don't ask the model to infer
  them.
- Ask for the decision, not what deterministic code derives from it.
- The answer template never carries the expected value: use a neutral
  placeholder (`"<true | false>"`, `"<number>"`), or a model that copies
  the template passes whatever the skill says.
- A check on an absent value (`null`, "records nothing") also checks the
  field is present, so an empty answer can't pass it.
- Keep fixed strings other code depends on in the checks verbatim, so a
  rewrite that changes them fails.
- Use fictional names (`acme-widgets`, `widget-export`); this repo is
  public.
