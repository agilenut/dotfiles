# theme.zsh - tab-completion for the `theme` command; completes the
# available theme names (read from the palette via `theme --list`).
_theme() {
  # zsh field-splits the command substitution; theme names have no spaces.
  compadd $(theme --list 2>/dev/null)
}
compdef _theme theme
