#!/usr/bin/env bash
set -euo pipefail

# WorktreeRemove hook: cleans up a worktree when the agent finishes.
# Receives JSON on stdin with cwd (the worktree directory).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=worktree-lib.sh
source "$SCRIPT_DIR/worktree-lib.sh"

INPUT="$(cat)"
WORKTREE_PATH="$(parse_cwd "$INPUT")"

if [ -z "$WORKTREE_PATH" ]; then
  echo "WARNING: No cwd in stdin, skipping cleanup" >&2
  exit 0
fi
if ! is_worktree "$WORKTREE_PATH"; then
  echo "WARNING: $WORKTREE_PATH is not a git worktree, skipping" >&2
  exit 0
fi

teardown_worktree "$WORKTREE_PATH"
