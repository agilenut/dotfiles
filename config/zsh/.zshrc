# .zshrc
# =============================================================================
# Executed by zsh on each interactive shell.
# See https://zsh.sourceforge.io/Guide/zshguide02.html

# De-dupe
# -----------------------------------------------------------------------------
typeset -gU cdpath fpath mailpath path

# Interactive Behavior
# -----------------------------------------------------------------------------

# Use 'fzf' or 'zsh' completions
# NOTE: Custom variable used by antidote to determine which completion to setup.
export COMPLETION_MODE='fzf'

# Tell Terminal.app to disable sessions.
export SHELL_SESSIONS_DISABLE=1

#zstyle ':completion:*:*:git:*' user-commands ${${(M)${(k)commands}:#git-*}/git-/}
zstyle ':completion:*:*:git:*' user-commands ignore:'helps create .gitignore files'

# Antidote - load plugins
# -----------------------------------------------------------------------------

# Use friendly names for plugin directories.
# NOTE: Once antidote 2.0 is released, this will be the default & can be removed.
zstyle ':antidote:bundle' use-friendly-names 'yes'

# Load Plugins.
# TODO: Move git clone to a bootstrap script so that network is not required for shell start. 
[ -d "$XDG_DATA_HOME/antidote" ] ||
  git clone --depth 1 https://github.com/mattmc3/antidote "$XDG_DATA_HOME/antidote"

if [ ! -f "$XDG_DATA_HOME/antidote/antidote.zsh" ]; then
  print "Antidote not found. Run bootstrap." >&2
  return 1
fi

source "$XDG_DATA_HOME/antidote/antidote.zsh"
antidote load
