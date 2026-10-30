---
name: wrap
description: "Use when the user says /wrap, asks whether now is a good time to wrap or start a new session, or asks to update plans, the board, and open threads before ending a session. Also cleans up merged branches, worktrees, and their Docker projects."
user-invocable: true
argument-hint: "[all]"
---

# Wrap Skill

_Close a session so no work is lost and nothing is left undone._

The user runs `/wrap` when they want to end a session and start the next
one fresh. After it, everything that lived only in the related sessions is
written somewhere durable (plans, the board, issues). Finished branches,
worktrees, and Docker projects are gone, and the next session has a
ready-to-paste first line. It fails the user in two ways: work stays stuck
in a plan or a chat and is forgotten, or cleanup destroys work the user
still needed. When a case isn't covered below, choose the action that
avoids both.

Related sessions are this session plus the sessions it continued from or
that continued it. When the user says "this session's work", they mean all
related sessions. "This session" alone means the current one.

An open thread is one item that needs an action: something that would be
lost or left behind if the session ended now.

Bare `/wrap` covers the related sessions' plans, branches, worktrees, and
open threads. `/wrap all` also covers every branch and worktree in the
current repo, never other repos.

## Step 1: Readiness verdict

_The first line of output says stop now or finish something first._

Check what is half done: staged or unstaged changes without a review the
plan requires, a commit or PR step in progress, CI or another background
task still running, a question to the user still unanswered. Then say
either "Good time to wrap" or "Finish `<X>` first: `<reason>`", with a
recommendation. If finishing first is better, stop there unless the user
says to wrap anyway. A wrap that runs over half-done work turns it into an
open thread the next session has to rediscover.

**Worktree isolation.** If this session entered a worktree with
`EnterWorktree`, the harness refuses writes outside it and git commands
against other checkouts, and Steps 3-5 need both. Before Step 2, call
`ExitWorktree` with `action: "keep"` (it changes nothing on disk), then
copy this session's edits in the worktree's `.plans/` and `.reviews/` to
the main tree per Step 7's copy-back rule, and work on the main tree's
copies from then on. Step 7 then skips copy-back for this worktree, since
its copies are now older than the main tree's.

## Step 2: Find the related sessions' plans

_Plans are the source of truth for the work, so find all of them first._

No harness field links continued sessions, so link them through the plan
files they share.

1. Start with the plan files this session read or wrote.
2. Find transcripts from the last 14 days in
   `~/.claude/projects/<encoded-repo>*/*.jsonl` with the Glob tool, which
   lists newest first; the trailing `*` also matches worktree folders
   (`<encoded-repo>--<slug>`). Stop at the first file whose last change is
   older than 14 days. The recap skill's Step 3 explains the folder
   encoding and why to read `cwd` from the file instead of decoding the
   folder name.
3. Search those files for the plan file names with the Grep tool in
   `files_with_matches` mode, since content mode returns whole transcript
   lines, which are very large.
4. Add the plans the matching sessions read or wrote, search once more for
   those, then stop. Search on plan file names, which are unique; an issue
   number only confirms a match, since an epic's number appears in many
   unrelated sessions.

Show the plans found (name, last change, sessions that touched them) and
wait for one confirming reply. The user may add or drop a plan.

## Step 3: Update without asking

_Bookkeeping the global rules already require; asking about each change
only slows the wrap._

- **Plans.** For each confirmed plan, record done steps and commits,
  update the PR table, and keep Open items current (the plan skill's rules
  for a merged PR's notes apply).
- **Board.** Move cards for the issues the related sessions worked, within
  the global `### Board` rules and the `board` skill's steps. Run the
  last-column check only through the board skill.
- **Knowledge base.** Not built yet; say "Skipped: knowledge-base step".

## Step 4: Integrity checks

_Every planned PR needs an issue, or the board doesn't show the work._

- Each unmerged planned PR in the confirmed plans has an open issue on the
  board. The plan names the issue (PR table and `stories:`), and the issue
  names the plan file in its body or a comment. A gap becomes an open
  thread whose fix is to file the issue or add the reference.
- Every other active plan in the repo gets the same check. Active means
  it has an unmerged planned PR, an unresolved Open item, or a `stories:`
  issue still open. Also check that each of its Open items is filed,
  joined to a planned PR, or dropped.
- Flag an active plan untouched for over 7 days as stale. Recommend
  resuming it, filing issues for its remaining work and archiving the
  plan, or dropping it. The user wants plans to stop sitting for months.

## Step 5: Collect open threads

_List everything the session would leave behind, each with a
recommendation._

Check each source below; verify what you report (run the command, read
the file) instead of assuming. Give every thread a recommended action and
a one-line reason.

| Source                                                    | Usual recommendation                                                                                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plan Open items not yet filed, joined, or dropped         | join a planned PR, file an issue, or drop                                                                                                               |
| Integrity gaps (Step 4)                                   | file the issue or add the reference                                                                                                                     |
| Work for another repo or a separate session               | a handoff (below)                                                                                                                                       |
| Handoff plans from earlier sessions                       | delete each one a later session picked up; otherwise it stays an open thread                                                                            |
| Uncommitted changes                                       | review then commit, or stash (`git stash push -u -m <tag>`; the stash stack is shared)                                                                  |
| Unpushed commits                                          | push, or name why not                                                                                                                                   |
| Branches and worktrees                                    | Step 7's rules                                                                                                                                          |
| Compose projects left from this repo's removed worktrees  | Step 7's Docker rule                                                                                                                                    |
| Learnings not yet saved (corrections, stated preferences) | memory, a rule change, or nothing                                                                                                                       |
| Files the related sessions wrote to scratchpad or `/tmp`  | delete, listing each path, especially anything with secrets or personal data; list other `/tmp` files that look related to this work, never delete them |
| Actions waiting on the user (drafts, UI settings, tests)  | list them; they can't be done here                                                                                                                      |
| Sibling repos needing the same change                     | a handoff, only when a related session raised it                                                                                                        |
| Done work that isn't Live yet                             | name it (global Definition of Done)                                                                                                                     |
| The repo's CLAUDE.md `## Before a wrap` section           | run each check it lists now; each failure is an open thread                                                                                             |

**Handoffs.** Same work, next session: the plan is the handoff; make sure
its Open items / Next section names the step. Other work (another repo, or work no related
session planned): an issue in the target repo, with no private details if
that repo is public, plus a handoff plan (a draft plan with the full
context) in the target repo's gitignored plans folder, named in the issue.

## Step 6: Present and run the pick

_The user picks once; nothing is filed, committed, or deleted before
that._

Show two blocks:

1. **Done without asking:** plans updated, cards moved, checks that
   passed.
2. **Your pick:** numbered open threads, each with its recommendation.

Replies: a bare `y` runs every recommendation; numbers run only those;
`3 drop` overrides one. Two kinds of action never run on a bare `y` and
each gets its own y/n after the pick, with exactly what would be lost:
removing a worktree that holds uncommitted changes, unpushed commits, or
files that can't be rebuilt; and deleting a branch with commits that are
neither on the remote nor in a merged PR.

Run only what was picked. Doing more than asked (removing a worktree when
asked to delete a branch) is the mistake users correct most. A picked
commit follows the global commit rules and the plan's review tag; `/wrap`
never commits on its own. Report each failure with its error.

## Step 7: Branch, worktree, and Docker cleanup

_Exact steps, because a mistake here deletes work._

**Merged branch.** `/pr` squash-merges and deletes the remote branch, so
a merged branch is never in main's history and `git branch -d` refuses
it. Look up its merged PR:

```bash
gh pr list --state merged --head <branch> --json number,headRefOid
gh pr view <number> --json commits --jq '.commits[].oid'
```

The branch is merged when its local tip equals `headRefOid` or is one of
the PR's commits (the local branch is behind the PR). Then delete it with
`git branch -D <branch>`. A tip with commits past `headRefOid` has unpushed
work: list the commits and treat the branch as unmerged. If a kept
worktree has the branch checked out, first switch that worktree to
`origin/main` (detached) or to the next PR's branch.

**Other branch states.**

- Tip already in `origin/main`, such as a branch that never got a commit
  (`git merge-base --is-ancestor <branch> origin/main` succeeds):
  recommend `git branch -d`.
- Open PR: keep it, with no open thread unless the PR has had no activity
  for over 7 days.
- No PR, or a closed unmerged PR: list what it holds (commits not in
  main, last commit date, any closed PR). Recommend filing an issue if the
  work looks worth keeping, keeping it if recent (it shows up again next
  wrap), or keeping it as reference (later wraps skip it). Never recommend
  deleting it. "Keep as reference" runs
  `git config branch.<branch>.description "reference: <why>"`; later
  wraps skip branches whose description starts with `reference:`, and
  `/wrap all` counts them in one line.

**Worktree.** Worktrees usually span sessions. Recommend removal only when
its plan is closed out (every planned PR merged and every Open item
dropped, filed, or done) or, when no plan uses it, when its branch is
merged or its tip is in `origin/main`. Before removing:

1. Commits. On a branch: no commits past the PR's `headRefOid` (the
   merged test above), or the tip is in `origin/main`. Detached:
   `git -C <worktree> merge-base --is-ancestor HEAD origin/main`, or HEAD
   is on a remote branch; commits on a detached HEAD live only in that
   worktree and are deleted with it.
2. Changes: `git -C <worktree> status --porcelain --ignored`.
   - Tracked or untracked changes: the user's own y/n, then `--force`.
   - Ignored files that can't be rebuilt (`.env`, local config, notes):
     list them; the user's own y/n, without `--force` (git removes ignored
     files on its own). Dependency and build output (`node_modules/`,
     `.venv/`, `dist/`) needs no ask.
   - `.plans/` and `.reviews/`: run the copy-back rule below.
3. Remove with `~/.claude/hooks/cleanup-worktree.sh <worktree>`, adding
   `--force` only after its y/n. The script removes the worktree, then its
   Compose projects (containers, volumes, networks, built images), and
   exits non-zero on any failure.

Never use `ExitWorktree` with `discard_changes: true`. Its check for
uncommitted work fails on the hook-created sibling worktrees, and the flag
skips the check, so changes are lost without a listing.

**Copy-back of `.plans/` and `.reviews/`.** Another session may have
edited the main tree's copy while this worktree existed, so never let a
newer timestamp decide alone. For each file in the worktree's folders:

- Missing from the main tree: copy it.
- Identical: nothing to do.
- Different, and the main tree's copy hasn't changed since the worktree
  was created (its mtime is older than the worktree's `.git` file): copy
  it.
- Otherwise: show the diff and ask which to keep.

**Docker leftovers.** `docker compose ls --all --format json` lists every
project on the machine. Consider only projects whose config path is under
this repo's worktree paths (`<parent>/<repo>--*`) and no longer exists.
List each with its volumes
(`docker volume ls --filter label=com.docker.compose.project=<name>`) and
recommend removal, run from `/` so no local compose file is loaded:

```bash
(cd / && docker compose -p <name> down -v --rmi local --remove-orphans)
```

**This session's own worktree.** When this session started inside the
worktree, `ExitWorktree` can't leave it. Run the same checks and asks, then
remove it as the very last action, after Step 8's output:
`cd <main repo> && ~/.claude/hooks/cleanup-worktree.sh <worktree>`.

## Step 8: Handoff and last output

_The user starts the next session from this output._

End with:

- What changed (one line per area).
- What is left, which should be nothing besides the user's own actions.
- Done work that isn't Live yet.
- The next step and a ready-to-paste first line for a fresh session, such
  as `/plans widgets - start the plan's fifth PR`.
- Where the plans live, if any edits are still only in a kept worktree.
