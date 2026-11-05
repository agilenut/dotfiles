---
name: wrap
description: "Use when the user says /wrap, asks whether now is a good time to wrap or start a new session, or asks to update plans, the board, and open threads before ending a session. Also cleans up merged branches, worktrees, and their Compose projects."
user-invocable: true
argument-hint: "[all]"
---

# Wrap Skill

_Close a session so no work is lost and nothing is left undone._

The user runs `/wrap` when they want to end a session and start the next
one fresh. After it, everything that lived only in the related sessions is
written somewhere durable (plans, the board, issues). Finished branches,
worktrees, and Compose projects are gone, and the next session has a
ready-to-paste first line. It fails the user in two ways: work stays stuck
in a plan or a chat and is forgotten, or cleanup destroys work the user
still needed. When a case isn't covered below, choose the action that
avoids both.

Related sessions are this session plus the sessions it continued from or
that continued it; Step 2 finds them through the plans they share. When
the user says "this session's work", they mean all related sessions.
"This session" alone means the current one.

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
against other checkouts, and Steps 3-7 need both. Before Step 2, call
`ExitWorktree` with `action: "keep"` (it changes nothing on disk), then
copy this session's edits in the worktree's `.plans/` and `.reviews/` to
the main tree per Step 7's copy-back rule, and work on the main tree's
copies from then on. Ask about a copy-back conflict here, before Step 2,
since Step 3 edits that file. Step 7 then skips copy-back for this
worktree, since the main tree's copies already hold its edits.

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
wait for one confirming reply, even when only one plan turned up. The
user may add or drop a plan. Steps 3 and 4 update only confirmed plans,
so a plan missed here is work the wrap leaves behind. With no plans
found, say so and go on without waiting.

Confirming the plans settles which sessions are related: this session
plus the ones that touched a confirmed plan. A session other than this
one whose transcript changed in the last 10 minutes may still be running
in another window. It stays related, and Step 3 still updates the plans
it shares (say so in "Done without asking", since that session may edit
them too), but don't delete its scratchpad or remove its branch or
worktree.

## Step 3: Update without asking

_Bookkeeping the global rules already require; asking about each change
only slows the wrap._

- **Plans.** For each confirmed plan, record done steps and commits,
  update the PR table, and keep Open items current (the plan skill's rules
  for a merged PR's notes apply). Then, for an active plan (frontmatter
  `status: active`, or no `status:`), set its status, since other skills
  treat only active plans as current:

  - Finished, by the test in the `board` skill's closeout step 5: `done`.
    That closeout usually sets it after the last merge; this catches a
    plan it missed.
  - The user gave up on the goal in a related session: `abandoned`.
  - Otherwise leave it `active`, with its Open items / Next section naming
    the next step.

  Leave a plan with any other status as it is. A confirmed `superseded`
  plan points to its replacement in its `## Superseded` section; add that
  plan to the confirmed ones if Step 2 missed it.

  A status change follows the plan skill's Step 8: the dated section it
  describes, and the reason as a comment on `status:`. Add the section
  first and change `status:` last, so a run that stops partway leaves the
  plan active and the next wrap finishes it.

- **Board.** Move cards for the issues the related sessions worked, within
  the global `### Board` rules and the `board` skill's steps. Run the
  last-column check only through the board skill.
- **Knowledge base.** When the repo's memory or CLAUDE.md names a
  knowledge base for this work, add what the related sessions learned
  (decisions, findings, open threads) following that knowledge base's own
  conventions. Write the notes only; committing them is an action for
  Step 6. When none is named, skip this without comment.

## Step 4: Integrity checks

_Planned work needs an issue so the board shows it, and no plan should
sit untouched._

A number from a branch name counts only once the tracker shows that issue
exists and covers this work; an unchecked number may name an unrelated
issue or none. When the repo has no GitHub remote, there is no tracker to
check: skip the issue and board checks and say so in "Done without
asking"; the checks on Open items, finished plans, and stale plans still
run. There, a planned PR counts as merged when its branch tip is in
`origin/main` (local `main` when the repo has no remote), and an Open item
is resolved only when joined or dropped. Any other `gh` failure is an
error to report, not a missing tracker.

- Each unmerged planned PR in the confirmed plans has an open issue on the
  board. The plan names the issue (PR table and `stories:`), and the issue
  names the plan file in its body or a comment. A gap becomes an open
  thread whose fix is to file the issue or add the reference.
- Every other active plan in the repo (`status: active`, or no `status:`)
  gets the same check. Also check that each of its Open items is filed,
  joined to a planned PR, or dropped. An item that a planned PR's work
  will settle, such as a decision inside its next commit, already counts
  as joined and needs no edit. An active plan that passes Step 3's
  finished test is an open thread whose fix is to set it `done`. Skip
  plans with any other status; a `parked` plan gets one unnumbered line in
  "Leaving alone" with the reason from its `## Parked` section.
- Flag an active plan untouched for over 7 days as stale, and choose one:
  resume it (a "Leaving alone" line, and Step 8's next step names it),
  file issues for its remaining work and set it `done`, set it `parked`,
  or set it `abandoned`. Each status change adds its section as in Step 3.
  The user wants plans to stop sitting for months.

## Step 5: Collect open threads

_Find everything the session would leave behind and decide what to do
with each._

Check each source below; verify what you find (run the command, read the
file) instead of assuming. The usual action is a starting point; decide
from the context, such as whether the plan continues or is done.

| Source                                                     | Usual action                                                                                                                         |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Plan Open items not yet filed, joined, or dropped          | join a planned PR, file an issue, or drop                                                                                            |
| Integrity gaps (Step 4)                                    | file the issue or add the reference                                                                                                  |
| Work for another repo or a separate session                | a handoff (below)                                                                                                                    |
| Handoff plans from earlier sessions                        | delete each one a later session picked up (each with its own y/n in Step 6's "Asking separately"); otherwise it stays an open thread |
| Uncommitted changes                                        | review then commit, or stash (`git stash push -u -m <tag>`; the stash stack is shared)                                               |
| Unpushed commits                                           | push, or name why not                                                                                                                |
| Branches and worktrees                                     | Step 7's rules                                                                                                                       |
| Compose projects left from this repo's removed worktrees   | Step 7's Docker leftovers rule                                                                                                       |
| Learnings not yet saved (corrections, stated preferences)  | memory, a rule change, or nothing                                                                                                    |
| Related sessions' scratchpads, and `/tmp` files they wrote | Scratchpads, below                                                                                                                   |
| Actions waiting on the user (drafts, UI settings, tests)   | Step 8's output; they can't be done here                                                                                             |
| Sibling repos needing the same change                      | a handoff, only when a related session raised it                                                                                     |
| Done work that isn't Live yet                              | Step 8's output (global Definition of Done)                                                                                          |
| The repo's CLAUDE.md `## Before a wrap` section            | run each check it lists now; each failure is an open thread unless the check says otherwise                                          |

**Handoffs.** Same work, next session: the plan is the handoff; make sure
its Open items / Next section names the step. Other work (another repo,
or work no related session planned): an issue in the target repo, with no
private details if that repo is public, plus a handoff plan (a draft plan
with the full context) in the target repo's gitignored plans folder,
named in the issue.

**Scratchpads.** Delete each ended related session's folder
(`/private/tmp/claude-*/*/<session-id>/`; a session's ID is its
transcript's file name without `.jsonl`). For this session, delete only
its `scratchpad/` folder, just before Step 8's output: the harness
recreates the rest of the session folder while the session runs, and a
later wrap deletes that folder. Describe the folders by session and size, never
by path. Flag any session whose files hold secrets or personal data. List
other `/tmp` files that look related; never delete them.

## Step 6: Show what you'll do and run it

_The user approves the list with one short reply; nothing is filed,
committed, or deleted before that._

Show what you will do, not an inventory of what you found. The user
should learn exactly what a bare `y` runs by reading one list, without
working out an action from a description. Use these blocks, leaving out
any that are empty:

1. **Done without asking:** plans updated, cards moved, checks that
   passed. One line per area.
2. **I'll do:** numbered actions, each a verb and its object with a short
   reason ("Delete branch `feat/12-export`: merged as PR #969"). On an
   indented line under an action, name what it destroys (volumes, files).
3. **Leaving alone:** one line each with the reason, such as a worktree
   and its Compose project kept for the plan's next PR. When a line has
   an action the user could pick instead, number it, continuing from the
   "I'll do" numbers, and name the action ("Keep worktree `X` for the
   plan's next PR; pick to remove"); without a number, the user has no
   short reply that picks it.
   A worktree kept for its plan always has such an action (removing it),
   so its line is always numbered, unless a session that may still be
   running uses it. Picking a removal that would lose work still leads to
   its own y/n. Nothing here runs unless the user picks it.
4. **Asking separately:** every action that destroys or rewrites
   something with no other copy, such as removing a worktree with
   uncommitted changes, unpushed commits, or files that can't be rebuilt;
   deleting a branch with commits neither on the remote nor in a merged
   PR; dropping a stash, a gitignored plan, or a handoff plan; rewriting
   pushed history. Each gets its own y/n with exactly what would be lost.
   This holds however the action came up, including a user's override.
   An ended session's scratchpad isn't one of these: it is temporary by
   design, so deleting it goes in "I'll do". Nor are the volumes of a
   Compose project tied to a worktree by its compose file, its `.env`, or
   a recorded config path under a removed worktree: they certainly belong
   to that worktree, so removing them goes in "I'll do" with the line
   naming them. Copy-back conflicts (Step 7) are asks here, since
   overwriting either copy loses the other.

Decide each thread yourself. When the right action is unclear, pick one
anyway and give the reason, since the user can override it. List only
actions that change something; rewording what a plan already records is
not a thread, and each extra item costs the user a read. Every thread
goes in exactly one block, or in Step 8's output when Step 5 sends it
there. Anything that changes something, such as "keep as reference",
goes in "I'll do".

Replies: a bare `y` runs the "I'll do" list; numbers run only those "I'll
do" items, or a "Leaving alone" line's named action; a short note changes
one ("3 skip", "7 remove"). Then ask each "Asking separately" y/n.

Run only what was approved. Doing more than asked (removing a worktree
when asked to delete a branch) is the mistake users correct most. An
approved commit follows the global commit rules and the plan's review
tag; `/wrap` never commits on its own. Report each failure with its
error.

## Step 7: Branch, worktree, and Docker cleanup

_Exact steps, because a mistake here deletes work._

Run these checks, lookups, and copy-back comparisons while collecting
threads in Step 5, since Step 6's list needs their results. Run removals
and the copy-back for a worktree being removed in Step 6, after approval.
Three writes run elsewhere: Step 1's copy-back, the final copy to a kept
worktree (below), and removing this session's own worktree (last
section).

With no GitHub remote, there are no merged PRs to look up: only the
ancestor test below applies, against the branch Step 4 names.

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
  (`git merge-base --is-ancestor <branch> origin/main` succeeds): delete
  it with `git branch -d`.
- Open PR: keep it, with no open thread unless the PR has had no activity
  for over 7 days.
- No PR, or a closed unmerged PR: list what it holds (commits not in
  main, last commit date, any closed PR). Choose one: file an issue if the
  work looks worth keeping, keep it if recent (it shows up again next
  wrap), or keep it as reference (later wraps skip it). Never choose
  deleting it. "Keep as reference" runs
  `git config branch.<branch>.description "reference: <why>"`; later
  wraps skip branches whose description starts with `reference:`, and
  `/wrap all` counts them in one line.

**Worktree.** Worktrees usually span sessions. Recommend removing one
only when its plan's status is `done`, `abandoned`, or `superseded`
after Step 3, or will be after an "I'll do" action in the same list, or, when no plan uses it, when its branch is merged or its
tip is in `origin/main`. A kept worktree keeps its Compose project too,
since the next PR uses its data. When the user picks removing a kept
one, run the same steps. Before removing:

1. Commits: on a branch, no commits past the PR's `headRefOid` (the
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
3. Docker: when the worktree has a compose file, read the project name
   `<name>` (`COMPOSE_PROJECT_NAME`) from its `.env`. For that project and its
   `<name>-e2e` project (the script removes both), list the volumes and
   images with
   `docker volume ls --filter label=com.docker.compose.project=<name>`
   and `docker images --filter label=com.docker.compose.project=<name>`.
   The action's line names what these return, minus any image a service
   names with `image:`, since removal keeps those.
4. Remove with `~/.claude/hooks/cleanup-worktree.sh <worktree>`, adding
   `--force` only after its y/n. The script removes the worktree, then its
   Compose projects (containers, volumes, networks, built images), and
   exits non-zero on any failure.

Never use `ExitWorktree` with `discard_changes: true`. Its check for
uncommitted work fails on the hook-created sibling worktrees, and the flag
skips the check, so changes are lost without a listing.

**Copy-back of `.plans/` and `.reviews/`.** Another session may have
edited the main tree's copy while this worktree existed, and a two-file
diff can't show which side changed a line. For each file in the
worktree's folders, first compare the two copies as they are now
(`diff`). Transcripts can explain a difference the diff shows, but they
record past states, so never report a conflict the current files don't
show.

- Missing from the main tree: copy it.
- Identical: nothing to do.
- The main tree's copy hasn't changed since the worktree was created (it
  is older than the worktree's `.git` file): copy the worktree's over it.
- Every line of the main tree's copy is in the worktree's copy, and a
  related session wrote each line only the worktree's copy has (check its
  transcript): copy the worktree's over it. Without that check, a line
  only in the worktree may be one another session deleted from the main
  tree, such as a closed Open item.
- `.last-reviewed.json`: merge the two as JSON objects, keeping every
  branch's entry. When both name a different commit for one branch, keep
  the one that descends from the other (`git merge-base --is-ancestor`);
  when neither does, such as after a rebase, ask in "Asking separately".
- Anything else: merge when each side only added lines, in different
  places, and a related session wrote the worktree's; otherwise show the
  diff in "Asking separately" and ask which to keep.

When the worktree stays (Step 1's isolated worktree, or a removal that
didn't happen), copy the main tree's final versions of these files to the
worktree after the wrap's last edit to them, Step 6 actions included.
Otherwise the worktree's copy falls behind, and the next wrap raises a
difference that no session made.

**Docker leftovers.** `docker compose ls --all --format json` lists every
project on the machine. Consider only projects whose config path is under
this repo's worktree paths (`<parent>/<repo>--*`) and no longer exists.
List each in "I'll do" with its volumes and images (the two lookups
above, minus `image:`-named images). On approval, remove it from `/`, so
no local compose file is loaded:

```bash
(cd / && docker compose -p <name> down -v --rmi local --remove-orphans)
```

`docker compose ls` misses a project whose containers are gone but whose
volumes remain. Find those by the project label on volumes
(`docker volume ls --format '{{.Label "com.docker.compose.project"}}'`),
keeping names with no container
(`docker ps -a -q --filter label=com.docker.compose.project=<name>` is
empty) that start with this repo's name or with the main tree's
`COMPOSE_PROJECT_NAME`. A volume records no path, so it may belong to
another project whose name matches: put each in
"Asking separately" with its volumes, and remove it with the same
command on a yes.

**This session's own worktree.** When this session started inside the
worktree, `ExitWorktree` can't leave it. Run the same checks and asks, then
remove it as the very last action, after Step 8's output:
`cd <main repo> && ~/.claude/hooks/cleanup-worktree.sh <worktree>`.

## Step 8: Next session and last output

_The user starts the next session from this output._

End with:

- What changed (one line per area).
- What is left: the user's own actions, plus one line per item kept in
  "Leaving alone".
- Done work that isn't Live yet.
- The next step and a ready-to-paste first line for a fresh session, such
  as `/plans widgets - start the plan's fifth PR`.
- Where the plans live, if any edits are still only in a kept worktree.
