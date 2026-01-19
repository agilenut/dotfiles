# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a cross-platform dotfiles repository managed by [chezmoi](https://www.chezmoi.io/). It supports macOS, Linux, and Windows while following XDG Base Directory specifications for a clean home directory.

## Architecture

### Chezmoi Structure

- `.chezmoi.toml.tmpl` - Configuration template (prompts for user name/email on first run)
- `.chezmoiroot` - Points to `home/` as the source directory
- `home/` - Chezmoi source directory containing dotfiles
  - Files prefixed with `dot_` become `.` files (e.g., `dot_zshenv` → `~/.zshenv`)
  - Files prefixed with `executable_` are made executable
  - Files ending in `.tmpl` are processed as Go templates
- `home/.chezmoiignore` - Platform-conditional file exclusions
- `home/.chezmoiexternal.toml` - External dependencies (antidote plugin manager)
- `home/.chezmoiscripts/` - Scripts run during `chezmoi apply`

### Directory Layout

```text
dotfiles/
├── home/
│   ├── dot_zshenv                    # → ~/.zshenv
│   ├── dot_config/                   # → ~/.config/
│   │   ├── zsh/
│   │   │   ├── dot_zshrc             # → ~/.config/zsh/.zshrc
│   │   │   └── shell/                # Modular shell configs
│   │   ├── git/
│   │   │   └── config.tmpl           # Templated for user info
│   │   ├── alacritty/
│   │   └── ...
│   └── dot_local/bin/                # → ~/.local/bin/
│       └── executable_*              # Helper scripts
├── .chezmoi.toml.tmpl
├── .chezmoiroot
└── .claude/
```

### Platform Support

- **macOS**: Full support (zsh, Alacritty, Homebrew packages)
- **Linux**: Shell configs, apt/pacman/dnf package installation
- **Windows**: Git config only (zsh configs excluded via `.chezmoiignore`)

### Key Dependencies

Installed via `run_once_before_install-packages.sh.tmpl`:

- fzf, fd, bat, eza, zoxide (terminal utilities)
- oh-my-posh (prompt)
- antidote (zsh plugin manager, via `.chezmoiexternal.toml`)
- neovim (editor)

## Common Commands

```bash
# Bootstrap on new machine
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply agilenut

# Preview changes
chezmoi diff

# Apply changes
chezmoi apply -v

# Add a new dotfile
chezmoi add ~/.config/newfile

# Edit source and apply
chezmoi edit ~/.config/somefile
chezmoi apply

# Update external dependencies
chezmoi update
```

## Templating

Files ending in `.tmpl` use Go template syntax:

- `{{ .name }}` - User's git name (prompted on first run)
- `{{ .email }}` - User's git email
- `{{ .chezmoi.os }}` - Operating system (darwin, linux, windows)
- `{{ if eq .chezmoi.os "darwin" }}...{{ end }}` - Platform conditionals

## File Naming Conventions

Chezmoi prefixes combine and are processed in order:

| Prefix          | Effect                               |
| --------------- | ------------------------------------ |
| `dot_`          | Becomes `.` (hidden file)            |
| `executable_`   | chmod +x                             |
| `private_`      | chmod 600                            |
| `readonly_`     | chmod 444                            |
| `empty_`        | Ensure file exists (even if empty)   |
| `modify_`       | Script that modifies existing file   |
| `run_`          | Script executed during apply         |
| `run_once_`     | Script executed only once            |
| `run_onchange_` | Script executed when contents change |

Example: `private_executable_dot_secret.sh.tmpl` → `~/.secret.sh` (mode 700, templated)

## Testing Changes

- **Preview**: `chezmoi diff` before applying
- **Dry run**: `chezmoi apply -v --dry-run` for verbose simulation
- **Tests**: Run `home/dot_local/bin/executable_dotfiles-test` to verify scripts work
- **Shell scripts**: Pre-commit runs shellcheck automatically

## Gotchas

- Always edit files in `home/`, never the target files directly
- The `.tmpl` suffix is stripped from the target filename
- `run_once_` scripts track execution by filename - rename to re-run
