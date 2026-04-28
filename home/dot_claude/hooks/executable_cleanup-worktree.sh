#!/usr/bin/env bash
set -euo pipefail

# Usage: cleanup-worktree.sh <worktree-path>
# Example: ~/.claude/hooks/cleanup-worktree.sh ../viva-hub--main

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=worktree-lib.sh
source "$SCRIPT_DIR/worktree-lib.sh"

WORKTREE_PATH="${1:?Usage: cleanup-worktree.sh <worktree-path>}"

if ! is_worktree "$WORKTREE_PATH"; then
  echo "ERROR: $WORKTREE_PATH is not a git worktree" >&2
  exit 1
fi

teardown_worktree "$WORKTREE_PATH" verbose

echo "Done."
