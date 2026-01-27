# dotfiles

![Tests](https://github.com/agilenut/dotfiles/actions/workflows/test.yml/badge.svg)

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Quick Start

```bash
# macOS / Linux
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply agilenut

# Windows (PowerShell)
(irm -useb get.chezmoi.io/ps1) | powershell -c -
chezmoi init --apply agilenut
```

On first run, you'll be prompted to select a profile:

- **personal** - Predefined settings for personal use (default)
- **custom** - Prompts for GitHub username, email, and signing key

## Profiles

Packages and configuration are organized into profiles defined in `.chezmoidata.toml`:

| Category       | Scope              | Example                          |
| -------------- | ------------------ | -------------------------------- |
| **Core tools** | Global (all users) | fzf, bat, git, neovim, tmux, zsh |
| **Dev tools**  | Profile-specific   | go, dotnet-sdk, shellcheck       |
| **GUI apps**   | Profile-specific   | 1Password, VS Code, Warp         |
| **Git config** | Profile-specific   | username, email, signing key     |

To create a work profile, add to `.chezmoidata.toml`:

```toml
[profiles.work.github]
  username = "work-username"
  email = "you@company.com"

[profiles.work.packages.darwin]
  dev = ["terraform", "kubectl", "azure-cli"]

[[profiles.work.apps.casks]]
  name = "slack"
  app = "Slack"
```

Then set `profile = "work"` in `~/.config/chezmoi/chezmoi.toml`.

## What's Included

### Shell & Terminal

- **zsh** with [antidote](https://github.com/mattmc3/antidote) plugin manager
- **oh-my-posh** prompt with custom theme
- **Alacritty** terminal (macOS)
- Plugins: fzf-tab, fast-syntax-highlighting, zsh-autosuggestions

### Core Tools (all profiles)

- **tmux** - terminal multiplexer with TPM plugin manager
- **fzf** - fuzzy finder with custom keybindings (Ctrl-T, Ctrl-R, Alt-C)
- **fd** - fast file finder
- **bat** - cat with syntax highlighting
- **eza** - modern ls replacement
- **zoxide** - smart cd
- **ripgrep** - fast grep
- **tree** - directory tree viewer
- **neovim** - editor
- **git** with git-credential-manager (HTTPS auth)

### Development Tools (personal profile)

- **go** - Go programming language
- **dotnet-sdk** - .NET development
- **powershell** - cross-platform shell
- **shellcheck** / **shfmt** - shell linting and formatting

### XDG Compliance

Environment variables configured for XDG Base Directory spec:

- Python: `PYTHON_HISTORY`, `PYTHONPYCACHEPREFIX`, `PYTHONUSERBASE`
- Go: `GOPATH`, `GOBIN`, `GOMODCACHE`
- pip: `require-virtualenv = true` safety net

### macOS Configuration

Privacy & security settings, Finder preferences, Dock behavior, keyboard shortcuts.

### GUI Apps (macOS)

VSCode, 1Password, Firefox, Chrome, Alfred, Rectangle Pro, and more via Homebrew casks.

## Daily Usage

```bash
# Preview what will change
chezmoi diff

# Apply changes
chezmoi apply -v

# Update from remote
chezmoi update

# Add a new dotfile
chezmoi add ~/.config/newapp/config
```

## Testing

```bash
# Run automated tests (installed version)
dotfiles-test --auto-only

# Run with manual tests (interactive, best in tmux)
tmux new-session
dotfiles-test
```

**Testing from source** (during development, before `chezmoi apply`):

- VS Code: `Cmd+Shift+P` → "Tasks: Run Test Task"
- Terminal: `./home/dot_local/bin/executable_dotfiles-test`

**Note**: Some tests require:

- **sudo** - Firewall and security tests (run interactively)
- **Full Disk Access** - Safari preference tests (grant in System Settings > Privacy)

### CI

Tests run automatically on push/PR via GitHub Actions. See the badge above.

## Development

### Repository Structure

```text
dotfiles/
├── home/                           # Chezmoi source directory
│   ├── dot_zshenv                  # → ~/.zshenv
│   ├── dot_config/                 # → ~/.config/
│   │   ├── zsh/                    # Shell configuration
│   │   ├── git/config.tmpl         # Git config (templated)
│   │   └── ...
│   ├── dot_local/bin/              # → ~/.local/bin/ (scripts)
│   ├── dot_local/lib/dotfiles-test # Test library
│   ├── dot_claude/                 # Claude Code config
│   └── .chezmoiscripts/            # Scripts run during apply
├── .chezmoi.toml.tmpl              # User config (name, email)
├── .chezmoiroot                    # Points to home/
└── .claude/                        # Project-specific Claude config
```

### File Naming Conventions

| Prefix          | Effect                           |
| --------------- | -------------------------------- |
| `dot_`          | Becomes `.` (hidden file)        |
| `executable_`   | chmod +x                         |
| `private_`      | chmod 600                        |
| `.tmpl` suffix  | Go template processing           |
| `run_once_`     | Script runs once per machine     |
| `run_onchange_` | Script runs when content changes |

### Pre-commit Hooks

```bash
# Install hooks
brew install pre-commit && pre-commit install

# Run manually
pre-commit run --all-files
```

Hooks: shfmt (shell formatting), shellcheck (linting), taplo (TOML), prettier, markdownlint.

### Local Development

To develop against a local clone instead of the remote repo:

```bash
# Clone the repo
git clone https://github.com/agilenut/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles

# Configure chezmoi to use local source
# Edit ~/.config/chezmoi/chezmoi.toml and set:
#   [data]
#   name = "Your Name"
#   email = "you@example.com"
#
# Then run:
chezmoi init --source=~/Developer/dotfiles

# Preview and apply changes
chezmoi diff
chezmoi apply -v
```

### Resetting Chezmoi State

To re-run `run_once_` scripts (e.g., after changing install-packages.sh):

```bash
# View tracked script state
chezmoi state dump | grep scriptState

# Clear state for a specific script (forces re-run)
chezmoi state delete-bucket --bucket=scriptState

# Or clear all chezmoi state
rm -rf ~/.local/share/chezmoi
chezmoi init --source=/path/to/dotfiles
```

## Platform Support

| Feature         | macOS       | Linux             | Windows |
| --------------- | ----------- | ----------------- | ------- |
| Shell (zsh)     | ✅          | ✅                | ❌      |
| Git config      | ✅          | ✅                | ✅      |
| Alacritty       | ✅          | ❌                | ❌      |
| Package install | ✅ Homebrew | ✅ apt/pacman/dnf | ❌      |
