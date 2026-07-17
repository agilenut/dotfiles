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
- **Dev tools** (profile-specific): go, dotnet-sdk, shellcheck, etc.
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

Always edit in `home/`, never target files directly.

| Prefix          | Effect                           |
| --------------- | -------------------------------- |
| `dot_`          | Becomes `.` (hidden file)        |
| `executable_`   | chmod +x                         |
| `private_`      | chmod 600                        |
| `run_once_`     | Script runs once per machine     |
| `run_onchange_` | Script runs when content changes |

### Testing Changes

```bash
# Preview what will change
chezmoi diff

# Run automated tests
dotfiles-test --auto-only

# Run pre-commit hooks
pre-commit run --all-files
```

### Applying Changes

- **Safe to auto-apply**: Env var changes, config additions, test updates
- **Ask before applying**: Scripts, macOS defaults, system-wide changes

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

1. `chezmoi diff` - preview what will change. **Always run this first** — it surfaces local-only divergence (changes you've made directly to managed files like `~/.claude/settings.json` that aren't in dotfiles yet) so you don't accidentally clobber them in step 2.
2. `chezmoi apply -v` - apply and verify files land correctly. **If `chezmoi diff` shows local-only changes** (changes to managed files that aren't in the dotfiles source), `apply` will revert them. **Stop and ask the user** how to proceed — options: `chezmoi add` those changes first to bring them under management, ignore the divergence and commit without applying, or accept the revert. Don't auto-decide.
3. `dotfiles-test --auto-only` - run automated tests
4. `pre-commit run --all-files` - run linting/formatting

Then make small, focused commits. When adding new functionality, suggest corresponding tests.

## Common Tasks

```bash
# Bootstrap new machine
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply agilenut

# Add a new dotfile
chezmoi add ~/.config/newapp/config

# Preview and apply
chezmoi diff && chezmoi apply -v

# Update external dependencies
chezmoi update
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
- `run_once_` scripts track execution by filename hash - rename to re-run
- macOS sandboxed apps (Safari) store prefs in `~/Library/Containers/` - requires Full Disk Access
- Some dotfiles-test checks require sudo (firewall tests) or Full Disk Access (Safari)
- `dotfiles-test` runs from installed location (`~/.local/bin`); to test source changes before `chezmoi apply`, run `./home/dot_local/bin/executable_dotfiles-test` or use VS Code's "Run Test Task"
- Tmux plugins (resurrect, sensible) require first-run install: start tmux, press `C-a I` (Ctrl-a, then Shift-i)
- Manual tests work best in tmux (inline testing); without tmux, falls back to subshell mode
- Claude Code's native ASK rules override `permissionDecision=allow` from a `PreToolUse:Bash` hook. If `smart_approve.py` returns allow but the command still prompts, look for a broader matching ASK in `home/dot_claude/settings.json` — removing the ASK (when deny coverage is sufficient) lets hook-allow take effect.
- Claude Code permission pattern matching is **permissive only for a single trailing wildcard**. `Bash(prefix *)` matches bare `prefix`. `Bash(prefix-A * prefix-B *)` (interior `*` + trailing `*`) is **strict** — the trailing `*` requires a real arg, so bare `prefix-A x prefix-B` won't match. Both native AND `smart_approve.py` follow this rule. To allow both bare and with-args forms of an interior-wildcard pattern, add **both** `Bash(... <subcmd>)` (no trailing `*`) AND `Bash(... <subcmd> *)` to settings.json (e.g. `git -C * status` and `git -C * status *`). Deny patterns rely on the strict semantic too — be careful loosening matching, you'll catch reads.
- Claude Code has its own built-in safelist for common read-only commands (`git status`, `git diff`, `ls`, etc.) that auto-allow regardless of `settings.json`. When validating permission patterns empirically, use commands Claude is unlikely to safelist — fictitious binary names (`zzz-test-foo`) work cleanly because they're definitely not in the safelist.
- Claude Code caches `settings.json` permission rules at session start. Edits to `~/.claude/settings.json` mid-session don't influence the running session — to test how a new pattern behaves natively, start a fresh `claude` session. The `smart_approve.py` hook reloads settings on each invocation, but native does not.
- Process substitution `<(…)` / `>(…)` content is **not** decomposed by the smart_approve hook — the inner command is invisible to allow/deny matching. The redirection-strip regex deletes the `<(…)` / `>(…)` token but not its content, so commands inside fall outside the segment-level check. Use a temp file (`cmd > /tmp/x; foo /tmp/x`) or piped form (`cmd | foo`) instead when you need the inner command to be visible to permission rules.
- Always-on audit log at `~/.claude/logs/smart_approve_decisions.log` records every allow/deny decision (fallthroughs not logged, to keep volume manageable). Format: `<ISO-timestamp>\t<DECISION>\t<scrubbed cmd[:300]>`. To evaluate which heuristics fire in practice: `grep awk` (Step 5 widening), `grep -E 'ALLOW.*xargs '` (Step 4 peel produced an allow), `grep -E 'ALLOW.*time '` (Step 3 peel). Manual rotation if it grows large. **Captures argv contents unredacted** — commands like `gh api … -H 'Authorization: Bearer …'`, `curl -u user:TOKEN`, `mysql -p'…'` will land in the log. Don't enable as a long-term audit if you run those shapes; consider rotating/deleting after the evaluation week.
