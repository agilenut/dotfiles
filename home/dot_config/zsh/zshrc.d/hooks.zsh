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
