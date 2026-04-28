#!/usr/bin/env bash
set -euo pipefail

# WorktreeCreate hook: creates a git worktree for isolated agent execution.
# Receives JSON on stdin with cwd (main repo path).
# Must print the worktree path to stdout.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=worktree-lib.sh
source "$SCRIPT_DIR/worktree-lib.sh"

INPUT="$(cat)"
CWD="$(parse_cwd "$INPUT")"

REPO_ROOT="${CWD:-$(pwd)}"
REPO_NAME="$(basename "$REPO_ROOT")"

BASE_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
BRANCH_SLUG="${BASE_BRANCH//\//-}"

WORKTREE_DIR="$(dirname "$REPO_ROOT")"
WORKTREE_PATH="$WORKTREE_DIR/${REPO_NAME}--${BRANCH_SLUG}"

# Reuse existing worktree if it already exists, updating to current HEAD
if [ -d "$WORKTREE_PATH" ]; then
  git -C "$WORKTREE_PATH" checkout --detach "$BASE_BRANCH" >&2
  echo "Reusing existing worktree at $WORKTREE_PATH (updated to $(git -C "$WORKTREE_PATH" rev-parse --short HEAD))" >&2
  echo "$WORKTREE_PATH"
  exit 0
fi

git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" "$BASE_BRANCH" --detach >&2

# Run setup only if the repo's script supports --worktree.
if [ -f "$WORKTREE_PATH/setup" ] && grep -q -- '--worktree' "$WORKTREE_PATH/setup"; then
  OFFSET="$(pick_offset "$REPO_ROOT")"
  "$WORKTREE_PATH/setup" --worktree "$REPO_ROOT" --offset "$OFFSET" >&2
fi

echo "$WORKTREE_PATH"
