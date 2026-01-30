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

### Committing

1. Run tests and ensure they pass
2. Make small, focused commits
3. When adding new functionality, suggest corresponding tests

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

## Gotchas

- The `.tmpl` suffix is stripped from target filenames
- `run_once_` scripts track execution by filename hash - rename to re-run
- macOS sandboxed apps (Safari) store prefs in `~/Library/Containers/` - requires Full Disk Access
- Some dotfiles-test checks require sudo (firewall tests) or Full Disk Access (Safari)
- `dotfiles-test` runs from installed location (`~/.local/bin`); to test source changes before `chezmoi apply`, run `./home/dot_local/bin/executable_dotfiles-test` or use VS Code's "Run Test Task"
- Tmux plugins (resurrect, sensible) require first-run install: start tmux, press `C-a I` (Ctrl-a, then Shift-i)
- Manual tests work best in tmux (inline testing); without tmux, falls back to subshell mode
