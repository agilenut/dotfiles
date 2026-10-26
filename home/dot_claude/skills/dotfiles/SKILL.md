---
name: dotfiles
description: "Use when the user asks to change their global Claude config (CLAUDE.md, settings, keybindings), a skill, agent, or hook under ~/.claude, or a shell, terminal, editor, or git config (zsh, tmux, nvim, alacritty, Karabiner, launchd jobs, themes), from any project. Also before running chezmoi apply, add, edit, or update, and when a deployed file has drifted from its source."
user-invocable: true
argument-hint: "[file or change]"
---

# Dotfiles Skill

_The steps behind the `## Dotfiles` rules in global CLAUDE.md: find the
source, edit it in the dotfiles repo, deploy only what changed, and recover
an edit made to a deployed copy._

`docs/deployment.md` in the dotfiles repo explains why each step exists.
The repo's `.claude/CLAUDE.md` has its own rules and commands (what to ask
before applying, tests, pre-commit, theme regeneration); read it before
deploying or committing.

## Step 1: Find the source

_Work out whether chezmoi deploys the file and where its source is._

- `chezmoi source-path` with no target prints the source directory: the
  main checkout's `home/`. The repo is its parent. "The main checkout"
  below means that repo.
- `chezmoi source-path <target>` prints the source of a managed file. It
  exits non-zero when chezmoi doesn't manage the target.
- Not managed (memory, logs, plans, `recap.toml`, `review-preferences.md`,
  skills in `~/.claude/skills/synced/`): edit it in place and stop here.
- A new file: put it in the source folder for its target folder
  (`chezmoi source-path <target folder>`). A new top-level folder follows
  chezmoi's naming (`dot_`, `executable_`, `private_`).
- Source ends in `.tmpl`: edit the template, then check what it renders
  with `chezmoi cat <target>`.
- Source ends in `.age` (encrypted): you can't edit it. Ask the user to run
  `chezmoi edit <target>` (with the `-S`/`-W` flags from Step 3 when the
  work is in a worktree); don't decrypt it or re-add it yourself.

## Step 2: Edit in the dotfiles repo

_The change is dotfiles work, not an edit in the current project._

- In a session in the dotfiles repo: work on this session's branch or
  worktree, per the repo's workflow.
- From another project: leave the main checkout alone. It is the
  configured chezmoi source for every session, so switching its branch
  changes what every apply deploys. Make a worktree instead, after a
  `git -C <repo> fetch`:
  `git -C <repo> worktree add --no-track -b <branch> <repo>--<branch-slug> origin/main`.
  Use absolute paths (`<repo>` is absolute, so `<repo>--<branch-slug>` is
  its sibling) and name the branch per the global Git rules. After the
  branch merges, remove it with `git -C <repo> worktree remove <path>`.
- Edit the source with the Edit tool.
- Edit a deployed copy only when the user explicitly asks for that. Use
  the Edit tool, not Bash: Claude Code prompts before an Edit under
  `~/.claude` or outside the project, which leaves the user the choice,
  and an auto-mode Bash write may not prompt at all. Then ask "Bring this
  into the source now? y/n" (recommend y: the next apply reverts it), and
  if yes, follow Recover, below.

## Step 3: Deploy

_Apply only the files you changed, after checking for changes you didn't
make._

From a worktree, add `-S <worktree>/home -W <worktree>` to `diff` and
`apply`; without them chezmoi reads the main checkout. Ask the user before
applying scripts, macOS defaults, or system-wide changes.

1. Check the main checkout with `git -C <repo> status`:
   - On main and clean: `git -C <repo> pull`, so merged work doesn't show
     up as a difference.
   - On this session's own branch: its diff includes your change; read it
     that way.
   - On another branch, or dirty: its diff mixes in work that was never
     deployed. Don't switch it, since another session may own it. Ask the
     user whether to wait, or go on and judge only by the worktree diff
     (step 3).
2. Run `chezmoi diff <target>` from the main checkout (no `-S`/`-W`). Skip
   this for a new target; there is nothing to compare. Any difference you
   didn't make is an edit to the deployed copy or another branch's change
   that was applied before it merged, and applying would revert it. Stop,
   say which you think it is, and offer:
   - (a) bring it into the source first (Recover, below) - recommend for
     an edit to the deployed copy
   - (b) wait until the other branch merges - recommend for another
     branch's applied change
   - (c) apply anyway and lose it
3. From a worktree, run the same diff with `-S`/`-W` and check it shows
   only your change.
4. Apply named targets only: `chezmoi apply -v <target>...`. A bare
   `chezmoi apply` deploys everything that differs, and with no terminal it
   stops at the first file that changed since chezmoi wrote it, applying
   nothing. For a new file in a new folder, name the folder; chezmoi won't
   create it from a file target.
5. Run `chezmoi diff <target>` again (with the same flags) and confirm it is
   empty.
6. After the branch merges: if the main checkout is on main and clean, run
   `git -C <repo> pull`, then repeat steps 2, 4, and 5 from it. If it
   isn't, tell the user the merged change deploys once it is back on main.

## Step 4: Finish what an apply doesn't do

_Some changes need another step before they take effect. The doc's "When
an apply isn't enough" table has the full list._

- `settings.json` or a hook: a running Claude Code session keeps its
  settings; start a new session to test.
- Shell config: open a new shell, or `exec zsh`.
- A deleted or renamed source file: the old target stays deployed. Add it
  to `home/.chezmoiremove`.
- A new prompt in `.chezmoi.toml.tmpl`: the user runs `chezmoi init`.
- A `run_once_` script runs again only when its contents change.
  Re-running an unchanged one means clearing the state of all of them,
  which re-runs package installs and macOS defaults; ask the user first.

## Recover an edit made to a deployed copy

_Bring the change into the source without losing anything else._

1. `chezmoi diff <target>` shows the deployed edit (as lines apply would
   remove).
2. Copy that change into the source file by hand, on a dotfiles branch.
   Don't use `chezmoi add`: it copies the whole deployed file, including
   any other drift and another branch's applied changes.
3. If the diff holds changes the user didn't mention, ask which to keep.
4. Deploy as in Step 3; the diff should end up empty.
