# dotfiles

![Tests](https://github.com/agilenut/dotfiles/actions/workflows/test.yml/badge.svg)

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Quick Start

### New Machine Setup

```bash
# macOS / Linux
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply agilenut

# Windows (PowerShell)
(irm -useb get.chezmoi.io/ps1) | powershell -c -
chezmoi init --apply agilenut
```

On first run, you'll be prompted for:

- Git user name
- Git email

### Existing Machine

```bash
# Preview changes
chezmoi diff

# Apply changes
chezmoi apply -v

# Update from remote
chezmoi update
```

## What's Included

- **Shell**: zsh with [antidote](https://github.com/mattmc3/antidote) plugin manager
- **Prompt**: [oh-my-posh](https://ohmyposh.dev/) with custom theme
- **Terminal**: [Alacritty](https://alacritty.org/) (macOS)
- **Tools**: fzf, fd, bat, eza, zoxide, ripgrep, neovim

## Platform Support

| Feature | macOS | Linux | Windows |
|---------|-------|-------|---------|
| Shell (zsh) | ✅ | ✅ | ❌ |
| Git config | ✅ | ✅ | ✅ |
| Alacritty | ✅ | ❌ | ❌ |
| Package install | ✅ Homebrew | ✅ apt/pacman/dnf | ❌ |

## Adding New Dotfiles

```bash
# Add an existing file to chezmoi
chezmoi add ~/.config/newapp/config

# Edit and apply
chezmoi edit ~/.config/newapp/config
chezmoi apply
```

## Structure

```
dotfiles/
├── home/                    # Chezmoi source (dotfiles go here)
│   ├── dot_zshenv          # → ~/.zshenv
│   ├── dot_config/         # → ~/.config/
│   └── dot_local/bin/      # → ~/.local/bin/
├── .chezmoi.toml.tmpl      # User config template
└── .chezmoiroot            # Points to home/
```

Files use chezmoi naming conventions:

- `dot_` prefix → `.` in target
- `executable_` prefix → made executable
- `.tmpl` suffix → processed as template
