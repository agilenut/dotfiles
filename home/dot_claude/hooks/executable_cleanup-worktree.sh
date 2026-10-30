#!/usr/bin/env bash
set -euo pipefail

# Usage: cleanup-worktree.sh [--force] <worktree-path>
# Example: ~/.claude/hooks/cleanup-worktree.sh ../viva-hub--main
# Without --force, a worktree with uncommitted or untracked changes is kept
# and the script exits non-zero.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=worktree-lib.sh
source "$SCRIPT_DIR/worktree-lib.sh"

usage() {
  echo "Usage: cleanup-worktree.sh [--force] <worktree-path>" >&2
  exit 2
}

FORCE=""
WORKTREE_PATH=""
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=--force ;;
    -*) usage ;;
    *)
      [ -z "$WORKTREE_PATH" ] || usage
      WORKTREE_PATH="$arg"
      ;;
  esac
done
[ -n "$WORKTREE_PATH" ] || usage

if ! is_worktree "$WORKTREE_PATH"; then
  echo "ERROR: $WORKTREE_PATH is not a git worktree" >&2
  exit 1
fi

teardown_worktree "$WORKTREE_PATH" --verbose ${FORCE:+"$FORCE"}

echo "Done."
