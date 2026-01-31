# Synology or SSH Linux Support Plan

## Goal

Be able to install dotfiles onto my synolog with a light weight but comfortable terminal setup. This is potentially not just for Synology but actually for any small light-weight setup. But we mention Synology because it has specific constraints and installation methods.

## Install

User would have to run chezmoi install and apply.

## Tools

We will start the feature with the most minmimum tooling and slowly expand iteratively.

We will likely need some way to determine which OS targets get which tools. Likely not all tools will be compatible with all environments.

Also, we may have some installs that desire a very minimum install like Synology where we would avoid node, dotnet, etc.

Also, for Synology, we will be viewing via SSH. So, if tooling for terminal prettiness will not work over SSH, we must take this into account and reduce accordingly.

### First Iteration

- XDG configured environment.
- Paging configuration (less if available)
- Editor configuration (neovim if available, vim if not; otherwise vi)
- Visual editor (if it makes sense - vscode if available, otherwise same as editor)
- Colors
- LS (eza if available, lsd if not, else ls)
- Git (tooling, config, ignore)
- Aliases

### Future Iterations

- bat if possible and config
- zsh and config
- fd, fzf, zoxide integration

## Approach

As much config from the existing repo should be reused as possible.

Where needed, config can be changed to perform tests to determine if certain tools are available before installing configuration or adding aliases to prevent pollution and failures.

Example: DOTNET\_ exports may be wrapped in a test to check if dotnet is installed.

Since the first iteration will not include zsh, we must work in ash or bash environments. This likely means extracting some of the items that would be shared in both sh, bash, and zsh so that we keep config dry.

Example: XDG and basic args that are currently in zshenv may need to be extracted into a shared location and sourced from zshenv so that they can also be in .profile.

Example: Aliases are currently in zsh specific files but many will be shared. Ideally no aliases would be zsh specific. If there are any, it might be better to define them as functions.

Use /note along the way to write out progress so that separate claude sessions can resume.

## Success

### Successful First Iteration

- ✅ Dotfiles and tools install using only chezmoi
- ✅ User xdg setup, editor, pager, colors, pretty ls config, git, and aliases setup in default OS shell as well as bash if it is installed.

### Successful Future Iteration

- ✅ User (via ssh) has very similar search, ctrl+t, alt+c, cd, cdi, completion behavior as macos.
