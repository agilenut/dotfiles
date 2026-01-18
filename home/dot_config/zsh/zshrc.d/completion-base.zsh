# completion-fzf.zsh
# =============================================================================
# Sets zsh completions

# Base completion
# -----------------------------------------------------------------------------

# Get cache directory
ZSH_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $ZSH_CACHE_HOME ]] || mkdir -p $ZSH_CACHE_HOME

# Enable zsh's completion system.
zmodload zsh/complist
autoload -Uz compinit && compinit -d "$ZSH_CACHE_HOME/zcompdump-$ZSH_VERSION"

# Enable completions for commands that don't seem to work:
compdef _gnu_generic fzf
compdef _gnu_generic oh-my-posh

# Enable completion cache.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_HOME/zcompcache"

# Clean up variable
unset ZSH_CACHE_HOME

# Include hidden files in completion.
_comp_options+=(globdots)

# Turn on completion menu.
zstyle ':completion:*' menu yes select

# Enable completers.
zstyle ':completion:*' completer _extensions _complete _approximate

# Enable case-insensitive completion.
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Color options.
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Grouping options.
# DO NOT ENABLE THESE OR THEY WILL BREAK FZF COMPLETIONS.
#zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
#zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
#zstyle ':completion:*' group-name ''
