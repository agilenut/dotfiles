# tmux.zsh
# =============================================================================
# Auto-attach to (or create) the `personal` tmux session for interactive
# Alacritty shells. Allow-list semantics: only fires when $ALACRITTY_WINDOW_ID
# is set. Other terminals (VS Code's integrated terminal, Warp, Terminal.app,
# remote SSH sessions) get a plain zsh prompt without the auto-attach.
#
# term-<profile> scripts launch tmux directly via `alacritty -e tmux …`,
# bypassing this guard — those keep their named sessions.

if [[ -o interactive ]] \
  && [[ -z "$TMUX" ]] \
  && [[ -n "$ALACRITTY_WINDOW_ID" ]]; then
  # No `exec` — when tmux exits/detaches, fall through to a normal zsh prompt
  # rather than closing the Alacritty window. Use Ctrl+D from the prompt to
  # close the window when truly done.
  tmux new-session -A -s personal
fi
