#!/usr/bin/env bash
# First-deploy bootstrap: create alacritty's current.toml symlink so the main
# config's `import` resolves before the first `theme` switch. Points at the state
# file's theme, else the default. `theme <name>` repoints it thereafter; this
# only fills the gap on a fresh machine. The `! -e` guard leaves an existing
# current.toml alone but self-heals a dangling one (its theme file was deleted).
set -euo pipefail

cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}"
statedir="${XDG_STATE_HOME:-$HOME/.local/state}"
themedir="$cfgdir/alacritty/themes"

theme="$(cat "$statedir/theme" 2>/dev/null || true)"
theme="${theme:-vscode-dark-modern}"

if [[ -d "$themedir" && ! -e "$themedir/current.toml" && -f "$themedir/$theme.toml" ]]; then
  ln -sfn "$theme.toml" "$themedir/current.toml"
fi
