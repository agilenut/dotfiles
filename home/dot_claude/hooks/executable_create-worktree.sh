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

# Canonicalize CWD so JSON-supplied values like "../foo" or symlinks can't
# escape the expected layout via dirname/basename games.
REPO_ROOT="$(cd "${CWD:-$(pwd)}" 2>/dev/null && pwd -P)" || {
  echo "ERROR: cwd is not a valid directory: ${CWD:-$(pwd)}" >&2
  exit 1
}
REPO_NAME="$(basename "$REPO_ROOT")"

BASE_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
BRANCH_SLUG="${BASE_BRANCH//\//-}"

# Reject branch slugs containing path separators or characters that could
# break argument handling. The first-char class excludes `-` so the slug
# can't be misread as a flag by downstream commands.
if [[ ! "$BRANCH_SLUG" =~ ^[A-Za-z0-9_.][A-Za-z0-9._-]*$ ]]; then
  echo "ERROR: invalid branch slug derived from $BASE_BRANCH: $BRANCH_SLUG" >&2
  exit 1
fi

WORKTREE_DIR="$(dirname "$REPO_ROOT")"
WORKTREE_PATH="$WORKTREE_DIR/${REPO_NAME}--${BRANCH_SLUG}"

# Reuse existing worktree if it already exists, updating to current HEAD
if [ -d "$WORKTREE_PATH" ]; then
  # NOTE: no `--` here. For `git checkout`, `--` separates rev-ish from
  # path-spec, so `checkout --detach -- "$BASE_BRANCH"` would treat
  # BASE_BRANCH as a file path, not a commit. Different from `worktree
  # add` below where `--` correctly terminates option parsing.
  git -C "$WORKTREE_PATH" checkout --detach "$BASE_BRANCH" >&2
  echo "Reusing existing worktree at $WORKTREE_PATH (updated to $(git -C "$WORKTREE_PATH" rev-parse --short HEAD))" >&2
  echo "$WORKTREE_PATH"
  exit 0
fi

# Use `--` to terminate option parsing before the positional arguments so a
# branch name beginning with `-` (or any future weirdness) can't be parsed
# as a flag by git worktree add.
git -C "$REPO_ROOT" worktree add --detach -- "$WORKTREE_PATH" "$BASE_BRANCH" >&2

# Run setup only if the repo's script supports --worktree.
if [ -f "$WORKTREE_PATH/setup" ] && grep -q -- '--worktree' "$WORKTREE_PATH/setup"; then
  OFFSET="$(pick_offset "$REPO_ROOT")"
  "$WORKTREE_PATH/setup" --worktree "$REPO_ROOT" --offset "$OFFSET" >&2
fi

echo "$WORKTREE_PATH"
