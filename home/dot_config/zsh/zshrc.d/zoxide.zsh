# zoxide.zsh
# =============================================================================
# Setup zoxide.

# cdi (zoxide interactive) reads _ZO_FZF_OPTS only; it does NOT inherit
# FZF_DEFAULT_OPTS. Reuse the shared bind/color vars (set in fzf.zsh, sourced
# first) so cdi's preview toggle/scroll + colors match every other fzf.
export _ZO_FZF_OPTS="--reverse \
  --bind '$FZF_PREVIEW_BIND' \
  --preview 'fzf-preview {2}' \
  --preview-window hidden \
  --height 80% \
  --nth 2 \
  $FZF_COLOR_OPTS"

# Initialize zoxide
eval "$(zoxide init zsh --cmd=cd)"
