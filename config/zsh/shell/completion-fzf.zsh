# completion-fzf.zsh
# =============================================================================
# Sets zsh completions

# Base completion
# -----------------------------------------------------------------------------

# Grouping options.
# Can be enabled to add grouping support but it is annoying.
# NOTE: don't use escape sequences (like '%F{red}%d%f') here, 
# fzf-tab will ignore them
#zstyle ':completion:*:descriptions' format '[%d]'

# FZF
# -----------------------------------------------------------------------------

# Source FZF
source <(fzf --zsh)

# Set colors
# 0=black, 1=red, 2=green, 3=yellow, 4=blue,
# 5=magenta, 6=cyan, 7=white (light grey)
# 8=bright black (dark grey), 9=bright red, 10=bright green, 11=bright yellow,
# 12=bright blue, 13=bright magenta, 14=bright cyan, 15=bright white
# NOTE: This is not a standard FZF parameter but is useful to have.
FZF_COLOR_OPTS='--color=fg:7,fg+:12,pointer:4,hl:5,hl+:5,prompt:6,info:3'

# Set shared preview arguments
FZF_PREVIEW_BIND="?:toggle-preview,\
ctrl-a:select-all,\
ctrl-f:preview-page-down,\
ctrl-b:preview-page-up"

# Set default options for fd - including the ignore file.
FD_DEFAULT_OPTS=(
  --hidden
  --follow
  "--ignore-file=${XDG_CONFIG_HOME:-$HOME/.config}/fd/fd.ignore"
)

# Default options for all FZF commands
export FZF_DEFAULT_OPTS="$FZF_COLOR_OPTS"

# Set CTRL-T to use fd command for both files and directories.
export FZF_CTRL_T_COMMAND="fd ${FD_DEFAULT_OPTS[@]}"

# Use preview for CTRL-T
export FZF_CTRL_T_OPTS="--preview 'fzf-preview {}' \
--bind '$FZF_PREVIEW_BIND' \
--preview-window hidden \
--height 80%"

# Set ALT-C to use fd command for just directories.
export FZF_ALT_C_COMMAND="fd --type d ${FD_DEFAULT_OPTS[@]}"

# Use preview for ALT-C
export FZF_ALT_C_OPTS="--preview 'fzf-preview {}' \
--bind '$FZF_PREVIEW_BIND' \
--preview-window hidden \
--height 80%"

# Use preview for CTRL-R
export FZF_CTRL_R_OPTS="--preview 'fzf-preview {}' \
--bind '$FZF_PREVIEW_BIND' \
--preview-window up:10%,wrap,hidden \
--height 80%"

# Generates file and directory completion candidates
# based on the current directory.
# Arguments:
#  Pattern to match
# Outputs:
#  List of matched files and directories.
_fzf_compgen_path() {
  fd ${FD_DEFAULT_OPTS[@]} . "$1"
}

# Generates directory completion candidates
# based on the current directory.
# Arguments:
#  Pattern to match
# Outputs:
#  List of matched directories.
_fzf_compgen_dir() {
  fd --type d ${FD_DEFAULT_OPTS[@]} . "$1"
}

# FZF-TAB
# -----------------------------------------------------------------------------

zstyle ':fzf-tab:*' fzf-flags $FZF_COLOR_OPTS
zstyle ':fzf-tab:*' switch-group '<' '>'

zstyle ':fzf-tab:complete:(cd|cdi|z|ls|eza|mv|cp|rm):*' fzf-preview 'fzf-preview $realpath'
zstyle ':fzf-tab:complete:(cd|cdi|z|ls|eza):*' fzf-flags --preview-window hidden --bind $FZF_PREVIEW_BIND --height 80% $FZF_COLOR_OPTS
zstyle ':fzf-tab:complete:(mv|cp|rm):*' fzf-flags --multi --preview-window hidden --bind $FZF_PREVIEW_BIND --height 80% $FZF_COLOR_OPTS

# Zoxide
# -----------------------------------------------------------------------------

export _ZO_FZF_OPTS="--reverse \
  --preview 'fzf-preview {2}' \
  --preview-window hidden \
  --bind $FZF_PREVIEW_BIND \
  --height 80% \
  --nth 2 \
  $FZF_COLOR_OPTS"