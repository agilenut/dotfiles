# editor.zsh
# =============================================================================
# Sets editor variables.

if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  export EDITOR="code --wait"
  export VISUAL="code --wait"
else
  export EDITOR="nvim"
  export VISUAL="nvim"
fi
