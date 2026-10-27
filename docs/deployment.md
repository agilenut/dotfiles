# Deployment

_How files in this repo become the files on a machine, and how to change
them without losing an edit._

## Source and target

_Everything under `home/` is a source file; chezmoi writes each one to a
target under `~`._

`.chezmoiroot` makes `home/` the source directory, so `home/dot_zshenv`
deploys to `~/.zshenv` and `home/dot_claude/CLAUDE.md` to
`~/.claude/CLAUDE.md`. The deployed file is a copy. Editing it changes
nothing in the repo, and the next apply overwrites the edit or stops on it.

Source names carry the target's attributes:

| Source name     | Effect on the target                             |
| --------------- | ------------------------------------------------ |
| `dot_`          | Becomes `.` (hidden file)                        |
| `executable_`   | chmod +x                                         |
| `private_`      | chmod 600                                        |
| `encrypted_`    | Stored encrypted with age (`.age` suffix)        |
| `.tmpl` suffix  | Rendered as a Go template; the suffix is dropped |
| `run_once_`     | Script runs once per version of its contents     |
| `run_onchange_` | Script runs again when its content changes       |

A few special files shape the deploy:

- `.chezmoiignore` - targets chezmoi skips, such as local-only files
  (`recap.toml`) and everything that doesn't apply to the platform.
- `.chezmoiremove` - targets to delete. Removing a source file only stops
  chezmoi managing the target; the old copy stays until it is listed here.
- `.chezmoiexternal.toml` - git repos chezmoi clones (antidote, tpm).
- `.chezmoiscripts/` - scripts that run during an apply (packages, macOS
  defaults, the `smart_approve.py` install).

To find out what chezmoi does with a file:

```bash
chezmoi managed                   # every target chezmoi deploys
chezmoi source-path ~/.zshenv     # the source of one target
chezmoi cat ~/.config/git/config  # what a template renders to
```

## Edit, diff, apply

_Change the source, check what an apply would do, then apply only that._

1. Edit the file under `home/`, on a branch.
2. `chezmoi diff <target>` shows what an apply would change. Lines marked
   `-` are what the deployed copy has now; `+` is what it will get.
3. `chezmoi apply -v <target>` deploys it.
4. `chezmoi diff <target>` again; empty means the copy matches the source.

Name the targets. A bare `chezmoi apply` deploys every difference, so it
also reverts any edit made to a deployed copy and deploys anything else on
the branch. When a target changed since chezmoi last wrote it, apply asks
before overwriting. With no terminal (a Claude session, a script) it errors
on that file and applies nothing, and its short output is easy to read as
success.

Read the diff before applying. A change you didn't make is an edit to the
deployed copy or another branch's change that was applied before it
merged. Applying reverts it, so recover it first (below) or wait for that
branch to merge.

After a branch merges, apply the same targets again from the main
checkout, so the deployed copy matches main.

## Applying from a worktree

_The configured source is the main checkout; point chezmoi at the worktree
instead._

`chezmoi init agilenut` clones the repo to `~/.local/share/chezmoi`. To
work from a clone elsewhere, set `sourceDir = "<clone>/home"` in
`~/.config/chezmoi/chezmoi.toml`; that clone is the main checkout. To
deploy from a worktree, pass its paths:

```bash
chezmoi -S <worktree>/home -W <worktree> diff ~/.claude/CLAUDE.md
chezmoi -S <worktree>/home -W <worktree> apply -v ~/.claude/CLAUDE.md
```

- Run the diff from the main checkout too (no `-S`/`-W`). A difference
  there that the worktree doesn't explain belongs to another branch or to
  an edit of the deployed copy. If the main checkout isn't on main, its
  diff also shows that branch's work, which was never deployed; check
  `git status` there first.
- For a new file in a new folder, name the folder; chezmoi won't create
  the folder from a file target.

## Reading `chezmoi status`

_Two columns: what changed since the last apply, and what the next apply
would do._

| Letter  | First column (since chezmoi last wrote it) | Second column (next apply) |
| ------- | ------------------------------------------ | -------------------------- |
| (space) | No change                                  | No change                  |
| `A`     | Created                                    | Will be created            |
| `D`     | Deleted                                    | Will be deleted            |
| `M`     | Modified                                   | Will be modified           |
| `R`     | -                                          | Script will run            |

An `M` in the first column means the deployed copy was edited, or a tool
rewrote it (Karabiner rewrites its config often). With `M` in both columns,
an apply would overwrite that edit, so it stops on that file.

## Files an app rewrites

_Keep the source in the app's own format, so its saves show only real
changes._

Some apps write the file chezmoi deploys. chezmoi compares text, so a
source that differs from what the app writes shows up in `chezmoi diff`
after every save: a whole-file diff when the app reformats it, or a hunk
when the app adds a value the source lacks. Either way, real changes are
harder to see.

- Store the file exactly as the app writes it: its format, section order,
  values it adds, and file mode (`private_` for 600). For a template, match
  the rendered output.
- Keep formatters off it: list it in `.prettierignore`, and give it an
  `.editorconfig` section if its indentation or final newline differs.
- Check it: make the app save without changing anything (toggle a setting
  and back, or run its setup step), then confirm `chezmoi diff <target>`
  is empty.

| File                                 | Written by                                           | What the source matches                                                                                                          |
| ------------------------------------ | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `~/.config/karabiner/karabiner.json` | Karabiner, on any settings change                    | Karabiner's own format, byte for byte, and 600 mode                                                                              |
| `~/.config/git/config`               | GCM's installer (`git-credential-manager configure`) | On macOS, GCM's full path as the credential helper, in the layout git writes: helpers first, the empty one with a trailing space |
| `~/.config/lazygit/themes/*.yml`     | lazygit, when it migrates renamed config keys        | The current key names, set in `themes/templates/lazygit.yml.tmpl`                                                                |

## When an apply isn't enough

_Some changes need another step before they take effect._

| Change                                 | Also needed                                             |
| -------------------------------------- | ------------------------------------------------------- |
| Claude Code `settings.json` or a hook  | Start a new Claude session; a running one keeps its own |
| Shell config                           | Open a new shell, or `exec zsh`                         |
| Deleted or renamed source file         | List the old target in `home/.chezmoiremove`            |
| New prompt in `.chezmoi.toml.tmpl`     | `chezmoi init`                                          |
| Re-run an unchanged `run_once_` script | Clear its state (below)                                 |
| tmux plugins on a new machine          | Start tmux and press `C-a I`                            |
| External repos (antidote, tpm)         | `chezmoi apply --refresh-externals` to pull them now    |

A `run_once_` script runs once per version of its contents, so editing it
makes it run again on the next apply. Clearing the state re-runs every
`run_once_` script, including package installs and macOS defaults:

```bash
chezmoi state dump | grep scriptState         # see what has run
chezmoi state delete-bucket --bucket=scriptState
```

## Recovering an edit made to a deployed copy

_Bring the change into the source, then deploy as usual._

1. `chezmoi diff <target>` shows the edit, as `-` lines.
2. Copy the change into the source file by hand, on a branch.
3. Apply the target; the diff should be empty.

`chezmoi add <target>` also brings a deployed copy into the source, but it
copies the whole file, including any other drift and other branches'
applied changes. `chezmoi merge <target>` opens a three-way merge of the
deployed copy, the source, and the target state.

## Updating from the remote

_`chezmoi update` pulls the source repo and applies everything._

It runs `git pull --autostash --rebase` in the source checkout, then a full
apply, so it pulls into whatever branch the main checkout is on. Check the
branch and `chezmoi status` first.
