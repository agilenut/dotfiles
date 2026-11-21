# Dotfiles Project

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/), following XDG Base Directory specifications.

## Architecture

### How Chezmoi Works

Source files in `home/` are transformed and installed to target locations:

- `dot_` prefix → `.` (hidden file)
- `executable_` prefix → chmod +x
- `.tmpl` suffix → Go template processing (stripped from target)
- `run_once_` scripts execute once per machine

### Key Directories

```text
dotfiles/
├── home/                      # Chezmoi source directory
│   ├── .chezmoidata.toml      # Package definitions and profiles
│   ├── dot_zshenv             # → ~/.zshenv
│   ├── dot_config/            # → ~/.config/
│   │   ├── zsh/               # Shell config
│   │   ├── tmux/              # Tmux config with TPM
│   │   ├── git/               # Git config (templated)
│   │   └── ...
│   ├── dot_local/bin/         # → ~/.local/bin/ (scripts)
│   └── dot_local/lib/         # Test library
├── .chezmoi.toml.tmpl         # Profile selection and custom prompts
└── .claude/                   # Claude Code config
```

### Profile System

Profiles control which packages and configuration to install:

- **Core tools** (global): Installed for all profiles - fzf, bat, git, neovim, tmux, etc.
- **Dev tools** (profile-specific): go, shellcheck, shfmt, etc.
- **Apps** (profile-specific): GUI applications like 1Password, VS Code
- **Git config** (profile-specific): name, email, signing key

Profile data is defined in `home/.chezmoidata.toml`. The install script (`run_once_before_install-packages.sh.tmpl`) iterates over this data.

### Git Authentication

- **HTTPS with GCM**: Git Credential Manager handles authentication for GitHub, Azure DevOps, etc.
- **SSH signing** (optional): Commits can be signed via 1Password's `op-ssh-sign` if `signingkey` is set in the profile

### Platform Support

| Platform | Shell | Packages | GUI Apps |
| -------- | ----- | -------- | -------- |
| macOS    | zsh   | Homebrew | Casks    |
| Linux    | zsh   | apt/dnf  | -        |
| Windows  | -     | -        | -        |

## Development Workflow

### Editing Files

Always edit in `home/`, never target files directly. The `dotfiles` skill
has the deploy steps; [docs/deployment.md](../docs/deployment.md) explains
source names and why each step exists.

### Testing Changes

```bash
# Run automated tests
dotfiles-test --auto-only

# Run pre-commit hooks
pre-commit run --all-files
```

### Applying Changes

- **Safe to auto-apply**: Env var changes, config additions, test updates
- **Ask before applying**: Scripts, macOS defaults, system-wide changes
- **How**: the `dotfiles` skill's Deploy step (named targets only, diff
  from the main checkout first, `-S`/`-W` from a worktree).

### Theme Changes

Theming is runtime `$THEME`-driven. `themes/palette.toml` is the single source
of truth; `theme-gen` renders it × the templates in `themes/templates/` into
committed plain per-tool per-theme outputs under `home/dot_config/<tool>/themes/`.
Tools select at runtime from `$THEME` (derived in `dot_zshenv`); `theme <name>`
switches by writing `$XDG_STATE_HOME/theme` — no chezmoi apply. Non-env GUI tools
(alacritty, quicklook) follow via a switcher-written `current.*` file.

When a change touches `themes/palette.toml` or a template in `themes/templates/`
(alacritty, bat, nvim, quicklook, delta, lazygit), regenerate and get the user's
eyes on the result before committing or opening a PR:

1. Run `theme-gen` yourself to regenerate the committed outputs.
2. Run `theme-gallery` yourself (regenerates `docs/theme-gallery/<theme>.html`).
3. Run `git diff` on the generated HTML yourself and summarize for the user
   which colors moved (the inline hex changes) and in which tool/scope. Do NOT
   ask the user to run the diff — that's your job.
4. Surface the regenerated pages for the user to open and eyeball, and get their
   explicit visual approval before committing or opening a PR.
5. Commit the regenerated outputs + gallery in the same PR as the palette change.

The rendered colors are the source of truth here; a template that "looks right"
can still shift a color the user needs to approve. When planning theme work,
add this gallery review as an explicit plan step; otherwise suggest it
dynamically when a change trips the trigger above.

### Committing

Before committing changes to this repo:

1. Deploy the changed files per the `dotfiles` skill, so tests run against
   them. It stops to ask when a diff shows changes that exist only in the
   deployed copy.
2. `dotfiles-test --auto-only` - run automated tests
3. `pre-commit run --all-files` - run linting/formatting

Then make small, focused commits. When adding new functionality, suggest corresponding tests.

## Before a PR

`/pr` runs this block before creating a PR and when verifying a CI fix.
The test script runs from the source, so the test code is the branch's.
Some checks read applied files under `~/.config` or find the repo through
`chezmoi source-path` (the main checkout), so apply the branch's changed
files first when those checks matter (the `dotfiles` skill's Deploy
step). The Committing steps above run similar checks per commit,
using the installed `dotfiles-test`.

```bash
./home/dot_local/bin/executable_dotfiles-test --auto-only
pre-commit run --all-files
```

## Before a wrap

`/wrap` runs these checks; each failure becomes an open thread unless the
check says otherwise.

- **Deploy drift.** Check the main checkout's branch and state as the
  `dotfiles` skill's Deploy step 1 does, then run `chezmoi status` and
  read it with the table in
  [docs/deployment.md](../docs/deployment.md#reading-chezmoi-status).
  Each row is an edit made to a deployed copy, a branch change applied
  before it merged, a merged change not yet applied, or an app rewriting
  its own file; the `dotfiles` skill and the deployment doc say how to
  handle each.
- **Privacy.** For each unmerged branch the wrap covers, read
  `git log -p origin/main..<branch>`, plus each worktree's uncommitted
  changes (`git diff HEAD`) and the untracked files
  `git status --porcelain` lists, against the Privacy list below.
  Gitleaks catches secrets only; names, client names, emails, and
  hostnames need a read. A pushed branch is already public, so a hit is
  not an ordinary open thread. Put it first in `/wrap`'s action list,
  and make its fix the first item in its block:
  - uncommitted change, untracked file, or unpushed commit: the first
    "I'll do" action
  - pushed commit: the first "Asking separately" question, so the user
    can decide on a history rewrite

## Common Tasks

```bash
# Bootstrap new machine
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply agilenut

# Add a new dotfile (writes to the main checkout; from a worktree, add -S/-W)
chezmoi add ~/.config/newapp/config
```

## Privacy

This repo is public. Never commit PII:

- Real first/last names — use the repo's GitHub username (the `<owner>` in the repo URL, also visible via `gh repo view --json owner --jq .owner.login`) instead
- Real client / project / company names — use fictional placeholders (`acme`, `widgets`)
- Personal email addresses — use the GitHub no-reply email
- Hostnames, IPs, infrastructure identifiers
- API keys, tokens, secrets

Applies to launchd labels, comments, examples, template defaults, test fixtures, scripts — anything that gets committed.

**Encrypted files:** when committing them (`chezmoi add --encrypt`), describe by **role** not **content** (e.g., "tack staging + prod aliases" rather than "tack-staging (1.2.3.4) + tack-prod (5.6.7.8)"). Commit messages are part of the public history; leaking decrypted values into the message undoes the encryption.

## Known Issues

Diagnosed limitations we've chosen to live with are recorded in
[docs/known-issues.md](../docs/known-issues.md) with root cause and what NOT to
try. Read it before investigating a rendering or tooling oddity so you don't
re-chase a ruled-out cause (e.g. delta not syntax-highlighting PHP diffs).

## Gotchas

- The `.tmpl` suffix is stripped from target filenames
- `run_once_` scripts run once per version of their contents: an edited one runs again on the next apply, and a rename alone doesn't re-run it
- macOS sandboxed apps (Safari) store prefs in `~/Library/Containers/` - requires Full Disk Access
- Some dotfiles-test checks require sudo (firewall tests) or Full Disk Access (Safari)
- `dotfiles-test` runs from installed location (`~/.local/bin`); to test source changes before `chezmoi apply`, run `./home/dot_local/bin/executable_dotfiles-test` or use VS Code's "Run Test Task"
- Tmux plugins (resurrect, sensible) require first-run install: start tmux, press `C-a I` (Ctrl-a, then Shift-i)
- Manual tests work best in tmux (inline testing); without tmux, falls back to subshell mode
- **Claude Code decides Bash permissions itself; there is no approval hook.** An allow rule approves a command without a prompt and without the auto-mode classifier. A command no allow rule matches goes to the classifier in auto mode and prompts in accept-edits and manual mode. An ask rule prompts in every mode, auto included, even when an allow rule also matches. `home/dot_local/lib/dotfiles-test/claude-permissions.sh` checks that no hook decides Bash permissions and that the ask and deny rules described here stay in `settings.json`.
- `Bash(prefix *)` also matches a bare `prefix`, but only when the trailing `*` is the rule's only wildcard. With an interior `*` (`Bash(prefix-A * prefix-B *)`) the trailing `*` needs a real argument.
- **Never write an allow rule with a wildcard before its subcommand.** `*` matches spaces, so `Bash(git -C * add *)` also matched `git -C /r rebase -x <cmd> add HEAD~2` and, three times in real history, a `git commit` whose message said "add". Claude Code 2.1.246+ warns about the shape at startup, and a test fails if `permissions.allow` has one. `git -C <path>` therefore has no allow rule and goes to the classifier. Deny and ask rules keep their `-C` variants, since nothing strips `-C` before matching.
- **A trailing wildcard can't pin an option that can be repeated.** `Bash(gh api -X GET *)` reads as "GET only", but `gh` uses the last `-X`/`--method`, so `gh api -X GET <path> -X DELETE` ran as a DELETE. Deny rules for any second method flag close it; they have no space after the flag so `--method=DELETE` and `-XDELETE` match too. They also deny a `gh api -X GET` whose argument nests another `$(gh api -X GET …)`, which is rare and already needed approval. Look for the same defect wherever a rule ending in `*` "pins" an option.
- **git accepts any unique prefix of a long option**, so a deny for `--upload-pack` also needs `--upl`.
- **An allow rule for a command whose arguments choose the host it contacts needs ask rules for those arguments.** With `cat` allowed, an allowed network command aimed at an attacker's host sends local files out with no check. The `ask` list in `home/dot_claude/settings.json` covers a URL, `--hostname`, and package-index flags on the allowed network commands. `WebFetch` and `dig` have no allow rule for the same reason, so the classifier checks each one.
- Claude Code has its own built-in safelist for common read-only commands (`git status`, `git diff`, `ls`, etc.) that auto-allow regardless of `settings.json`. When validating permission patterns empirically, use commands Claude is unlikely to safelist — fictitious binary names (`zzz-test-foo`) work cleanly because they're definitely not in the safelist.
- In auto mode, writes to `.claude/**` and `~/.claude/` route to the classifier no matter what the allow rules say, and edits to a `CLAUDE.md` are commonly denied as `[Instruction Poisoning]`. This repo's agent config lives in both `.claude/` and `home/dot_claude/`, so the denial is routine here. This check, not the deny rules on settings and hooks, is what protects those files; the deny rules catch accidental writes. Ask the user to switch to manual mode (Shift+Tab) — only they can change it — rather than reworking the text to get past the classifier.
- Claude Code reads `settings.json` permission rules and hooks at session start. Edits to `~/.claude/settings.json` mid-session don't affect the running session; to test a new pattern, start a fresh session (`claude -p` works for a scripted check).
