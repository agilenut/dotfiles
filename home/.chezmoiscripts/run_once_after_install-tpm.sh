#!/bin/sh
# Bootstrap tmux plugin manager (TPM) and install plugins listed in tmux.conf.
# Runs once per machine, after dotfiles are applied (so tmux.conf is in place).
# Subsequent install/update happens inside tmux via TPM keybindings:
#   prefix + I  install new plugins
#   prefix + U  update plugins
#   prefix + alt-u  clean removed plugins

set -eu

TPM_DIR="$HOME/.config/tmux/plugins/tpm"

if [ ! -d "$TPM_DIR" ]; then
  echo "Installing tmux plugin manager..." >&2
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

"$TPM_DIR/bin/install_plugins"
