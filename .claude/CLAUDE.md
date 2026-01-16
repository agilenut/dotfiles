# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS that manages shell configuration and terminal tools using the XDG Base Directory specification.

## Architecture

### Directory Structure
- `.zshenv` - Entry point, sets XDG environment variables and ZDOTDIR
- `config/zsh/` - Main zsh configuration (ZDOTDIR)
  - `.zprofile` - Login shell setup (Homebrew, PATH)
  - `.zshrc` - Interactive shell setup (plugins via antidote)
  - `.zsh_plugins.txt` - Antidote plugin manifest with load order
  - `shell/` - Modular configuration files loaded by antidote
- `config/` - XDG_CONFIG_HOME configurations (git, alacritty, bat, fzf, oh-my-posh)
- `local/bin/` - Custom scripts added to PATH (XDG_BIN_HOME)

### Plugin System
Uses [antidote](https://github.com/mattmc3/antidote) for zsh plugin management. Plugins are defined in `.zsh_plugins.txt` with:
- Conditional loading via `conditional:is-macos` or `conditional:is-completion-fzf`
- Local shell configs loaded as plugins from `$ZDOTDIR/shell/`
- Order matters: completions must load before fzf-tab

### Completion Mode
The `COMPLETION_MODE` variable in `.zshrc` toggles between `fzf` and `zsh` completions. The `is-completion-fzf` script checks this for conditional plugin loading.

## Key Dependencies
- Homebrew (package manager)
- antidote (zsh plugin manager, auto-cloned on first run)
- fzf + fd (fuzzy finding)
- eza (modern ls replacement)
- bat (syntax highlighting)
- zoxide (smart cd)
- oh-my-posh (prompt)
- nvim (editor)

## Symlink Setup
Files need to be symlinked to their XDG locations:
- `.zshenv` → `~/.zshenv`
- `config/*` → `~/.config/*`
- `local/bin/*` → `~/.local/bin/*`
