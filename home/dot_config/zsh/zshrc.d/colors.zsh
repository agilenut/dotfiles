# colors.zsh
# =============================================================================
# Sets zsh completions.

# Make color constants available
autoload -Uz colors && colors

# Enable colored output from ls, etc. on FreeBSD-based systems
export CLICOLOR=1

# Default color scheme for BSD systems (including macos).
export LSCOLORS="exfxcxdxbxegedabagacad"

# Default color scheme for linux systems. Also needed for certain utilities.
export LS_COLORS="di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

# Customize color mappings for colored-man-pages.
export PAGER="less"
export LESS="--raw-control-chars"
less_termcap[md]="${fg_bold[green]}"
less_termcap[us]="${fg_bold[magenta]}"
