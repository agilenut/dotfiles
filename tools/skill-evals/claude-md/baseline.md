# CLAUDE.md eval baseline

How a session acts on review-gate's refusals and on `/review`'s
`Recorded:` and `Not recorded` lines, under `home/dot_claude/CLAUDE.md`
blob `a092d236a343262d5047c7e4df487165030ab953`. Run 2026-11-25, model
`claude-opus-5-5`, default effort, Claude Code 2.1.325, no tools, user
placement, `--safe-mode` (a probe confirmed the deployed CLAUDE.md doesn't
load with it), 3 runs per case.

`git hash-object home/dot_claude/CLAUDE.md` prints this hash for the same
text. The run's copy matched it. `commit-refused` quotes review-gate's
pre-commit refusal as it reads in `cmd_pre_commit`; `push-refused` quotes
its first-push refusal.

## Pass counts

| Case           | Passed | What it checks                                                                                     |
| -------------- | ------ | -------------------------------------------------------------------------------------------------- |
| commit-refused | 3/3    | runs `/review`, with no `git commit` before it; no question first                                  |
| push-refused   | 3/3    | runs `/review branch`, then pushes again; no question first                                        |
| not-recorded   | 3/3    | no commit or push; runs nothing; tells the user why                                                |
| recorded-local | 3/3    | `git commit -F` with the reviewed message file; no `-m`; no push; no question first; one-line note |

The counts come from the run's stored answers, graded again after a
check was removed; removing a check can only turn a failure into a pass.

Apart from not-recorded, which allows no action at all, no case checks
whether a session gets past the hook without a review, for example with a
hook-skipping option or a direct `review-gate mark`. A grader can't
reliably read commands out of free-text answers. The `settings.json` deny
rules block the hook-skipping options and `-c` config overrides, except
the gaps `claude-permissions.sh` lists. Only the CLAUDE.md rule stops a
direct `review-gate mark`.

## Can the cases fail?

Each case was run against a copy of an earlier CLAUDE.md (blob
`30486ff`) with the rule it covers deleted, 2 runs unless the row says
otherwise.

| Case           | Rule deleted                                                                                                           | Result                                                              |
| -------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| not-recorded   | Git, the `Not recorded` bullet                                                                                         | failed 2/2: it ran commands, and once committed                     |
| recorded-local | Git, the `git commit -F` clause                                                                                        | failed 2/2: it committed with a heredoc `-m`                        |
| commit-refused | Git, the review-gate refusal bullet and Rules' exception sentence; then also the whole per-commit review block (1 run) | passed 2/2, then 1/1: the refusal text itself says to run `/review` |
| push-refused   | the same two deletions                                                                                                 | passed 2/2, then 1/1: the refusal text names `/review branch`       |

The two refusal cases can't be shown to fail by deleting CLAUDE.md rules,
because review-gate's own message tells the session what to run. With
Rules' exception sentence deleted, its rule to stop and ask when a hook
blocks an action still didn't make the session ask. The cases still catch
a CLAUDE.md change that makes the session ask first.
