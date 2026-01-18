# keybinds.zsh
# =============================================================================
# Sets zsh key binds

# VI
# -----------------------------------------------------------------------------

# Must be enabled before fzf completions are setup.
# Otherwise, it breaks cd **<tab> fzf completions.
bindkey -v

# Use vim keys in tab complete menu.
# Must be setup after base completions are loaded.
#bindkey -M menuselect 'h' vi-backward-char
#bindkey -M menuselect 'k' vi-up-line-or-history
#bindkey -M menuselect 'l' vi-forward-char
#bindkey -M menuselect 'j' vi-down-line-or-history
#bindkey -M menuselect '^i' vi-insert
