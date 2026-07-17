#!/usr/bin/env bash
# Theme runtime tests
# shellcheck shell=bash

# Guards the runtime $THEME model: that .zshenv derives each tool's selector from
# $THEME with the right precedence (inherited > state file > built-in default).
# The palette contract test (theme-palette.sh) validates the generated OUTPUTS;
# this validates the SELECTION the deployed .zshenv performs — the thing a future
# .zshenv edit could silently break. Everything runs in an isolated
# XDG_STATE_HOME so the real ~/.local/state/theme is never touched.
test_theme_runtime() {
  section "Theme Runtime"

  local zshenv="$HOME/.zshenv"
  if ! command -v zsh >/dev/null 2>&1; then
    fail "zsh not found; cannot test the \$THEME derivation"
    return
  fi
  if [[ ! -f $zshenv ]]; then
    fail "$zshenv not found (run chezmoi apply)"
    return
  fi

  local tmpstate cfg out
  tmpstate="$(mktemp -d)"
  cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

  # Run a fresh login-like zsh (ZDOTDIR/THEME unset so it reads ~/.zshenv) with an
  # isolated state dir, and print the derived dial + selectors, pipe-joined.
  #   $1 = none | empty | <theme>   (state-file contents)
  #   $2 = inherited THEME           (simulates alacritty's per-window [env])
  derive() {
    case $1 in
      none) rm -f "$tmpstate/theme" ;;
      empty) : >"$tmpstate/theme" ;;
      *) printf '%s\n' "$1" >"$tmpstate/theme" ;;
    esac
    local -a env_args=(-u ZDOTDIR -u THEME "XDG_STATE_HOME=$tmpstate" "XDG_CONFIG_HOME=$cfg")
    [[ -n $2 ]] && env_args+=("THEME=$2")
    env "${env_args[@]}" zsh -c \
      'source "$HOME/.zshenv"; print -r -- "$THEME|$BAT_THEME|$DELTA_FEATURES|${LG_CONFIG_FILE:t}"'
  }

  # 1. No state file -> built-in default, and every selector derives from it.
  out="$(derive none "")"
  if [[ $out == "vscode-dark-modern|vscode-dark-modern|+vscode-dark-modern|vscode-dark-modern.yml" ]]; then
    pass "no state file: defaults, and BAT_THEME/DELTA_FEATURES/LG_CONFIG_FILE all derive from \$THEME"
  else
    fail "default derivation wrong: $out"
  fi

  # 2. State file -> $THEME and all selectors follow it.
  out="$(derive dark-2026 "")"
  if [[ $out == "dark-2026|dark-2026|+dark-2026|dark-2026.yml" ]]; then
    pass "state file: \$THEME and all selectors follow it"
  else
    fail "state-file derivation wrong: $out"
  fi

  # 3. Inherited $THEME (alacritty per-window [env]) wins over the state file.
  out="$(derive dark-2026 vscode-dark-modern)"
  if [[ $out == vscode-dark-modern\|* ]]; then
    pass "inherited \$THEME (per-window) overrides the state file"
  else
    fail "per-window override wrong: $out"
  fi

  # 4. Empty state file -> falls back to default (guards the empty-\$THEME
  #    collapse that would break every selector).
  out="$(derive empty "")"
  if [[ $out == vscode-dark-modern\|* ]]; then
    pass "empty state file: falls back to default (no empty-\$THEME collapse)"
  else
    fail "empty-state-file guard failed: $out"
  fi

  rm -rf "$tmpstate"
}
