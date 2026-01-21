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

On first run, you'll be prompted for git user name and email.

## What's Included

### Shell & Terminal

- **zsh** with [antidote](https://github.com/mattmc3/antidote) plugin manager
- **oh-my-posh** prompt with custom theme
- **Alacritty** terminal (macOS)
- Plugins: fzf-tab, fast-syntax-highlighting, zsh-autosuggestions

### Development Tools

- **fzf** - fuzzy finder with custom keybindings (Ctrl-T, Ctrl-R, Alt-C)
- **fd** - fast file finder
- **bat** - cat with syntax highlighting
- **eza** - modern ls replacement
- **zoxide** - smart cd
- **ripgrep** - fast grep
- **neovim** - editor

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
# Run automated tests
dotfiles-test --auto-only

# Run with manual tests (interactive)
dotfiles-test
```

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

To test changes before committing:

```bash
# Point chezmoi to local repo
chezmoi init --source=/path/to/dotfiles

# Preview and apply
chezmoi diff
chezmoi apply -v
```

## Platform Support

| Feature         | macOS       | Linux             | Windows |
| --------------- | ----------- | ----------------- | ------- |
| Shell (zsh)     | ✅          | ✅                | ❌      |
| Git config      | ✅          | ✅                | ✅      |
| Alacritty       | ✅          | ❌                | ❌      |
| Package install | ✅ Homebrew | ✅ apt/pacman/dnf | ❌      |
