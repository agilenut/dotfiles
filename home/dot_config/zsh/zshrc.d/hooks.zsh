# hooks.zsh
# =============================================================================
# Setup hooks.

# Handles command not found event.
# Arguments:
#  The unfound command.
# Outputs:
#  0 if command was a file name and opens editor.
#  127 if not a file - replicates default behavior.
command_not_found_handler() {
  if [[ -f "$1" ]]; then
    $EDITOR "$1"
    return 0
  fi
  echo "zsh: command not found: $1"
  return 127
}

# Emit OSC 7 to report the shell's cwd to terminals that consume it: Warp
# (updates the tab's cwd + git-branch indicator) and macOS Terminal (opens a new
# tab/window in the same directory). Alacritty 0.17 does NOT consume OSC 7 - its
# hint and new-window spawns read the pty foreground process cwd directly via
# libproc, which is why open-path queries the active tmux pane instead of relying
# on this. Skip in non-interactive shells (zsh -c, ssh command=, captured stdout)
# so escape bytes don't leak into program output. Refuse to emit if PWD contains
# control characters (a directory name with literal ESC/BEL would inject
# arbitrary terminal sequences on every chpwd).
#
# Inside tmux, wrap the sequence in DCS passthrough so the outer terminal
# also receives it. tmux otherwise consumes OSC 7 internally without
# forwarding (tmux.conf must have `set -g allow-passthrough on`).
_osc7_cwd() {
  [[ -o interactive ]] || return 0
  case "${HOST}${PWD}" in
    *[[:cntrl:]]*) return 0 ;;
  esac
  # Minimal percent-encoding for common reserved chars in $PWD so RFC 3986
  # parsers don't truncate at the first space/#/?. Most terminals tolerate
  # raw bytes, but a few (and any logging that round-trips through a stricter
  # URI parser) won't.
  local encoded="${PWD// /%20}"
  encoded="${encoded//#/%23}"
  encoded="${encoded//\?/%3F}"
  if [[ -n "$TMUX" ]]; then
    printf '\ePtmux;\e\e]7;file://%s%s\e\e\\\e\\' "$HOST" "$encoded"
  else
    printf '\e]7;file://%s%s\e\\' "$HOST" "$encoded"
  fi
}
typeset -ag chpwd_functions
chpwd_functions+=(_osc7_cwd)
_osc7_cwd
