# zoxide.zsh
# =============================================================================
# Setup zoxide.

export _ZO_FZF_OPTS="--reverse \
  --preview 'fzf-preview {2}' \
  --preview-window hidden \
  --bind '?:toggle-preview,ctrl-a:select-all,ctrl-f:preview-page-down,ctrl-b:preview-page-up' \
  --height 80% \
  --nth 2 \
  --color=fg:7,fg+:12,pointer:4,hl:5,hl+:5,prompt:6,info:3"

# Initialize zoxide
eval "$(zoxide init zsh --cmd=cd)"
