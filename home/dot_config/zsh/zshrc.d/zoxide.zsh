# zoxide.zsh
# =============================================================================
# Setup zoxide.

# NOTE: Some of these optionsn rely on FZF being configured first.
export _ZO_FZF_OPTS="--reverse \
  --preview 'fzf-preview {2}' \
  --preview-window hidden \
  --bind $FZF_PREVIEW_BIND \
  --height 80% \
  --nth 2 \
  $FZF_COLOR_OPTS"

# Initialize zoxide
eval "$(zoxide init zsh --cmd=cd)"
