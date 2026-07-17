#!/usr/bin/env bash
# First-deploy bootstrap: create alacritty's current.toml (a copy of the active
# theme's variant) so the main config's `import` resolves before the first
# `theme` switch. Uses the state file's theme, else the default. `theme <name>`
# refreshes it thereafter; this only fills the gap on a fresh machine. The `! -e`
# guard leaves an existing current.toml alone.
set -euo pipefail

cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}"
statedir="${XDG_STATE_HOME:-$HOME/.local/state}"
themedir="$cfgdir/alacritty/themes"

theme="$(cat "$statedir/theme" 2>/dev/null || true)"
theme="${theme:-vscode-dark-modern}"

if [[ -d "$themedir" && ! -e "$themedir/current.toml" && -f "$themedir/$theme.toml" ]]; then
  cp -f "$themedir/$theme.toml" "$themedir/current.toml"
fi
