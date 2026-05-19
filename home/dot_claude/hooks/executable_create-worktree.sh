#!/usr/bin/env bash
set -euo pipefail

# WorktreeCreate hook: creates a git worktree for isolated agent execution.
# Receives JSON on stdin with cwd (main repo path) and optional name (target
# branch). When name is given, the worktree is created on that branch (created
# off main/master if it doesn't exist yet, attached if it does). When name is
# omitted, falls back to the legacy behavior: detached HEAD on the main repo's
# current branch.
# Must print the worktree path to stdout.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=worktree-lib.sh
source "$SCRIPT_DIR/worktree-lib.sh"

INPUT="$(cat)"
CWD="$(parse_cwd "$INPUT")"
NAME="$(echo "$INPUT" | jq -r '.name // empty')"

# Canonicalize CWD so JSON-supplied values like "../foo" or symlinks can't
# escape the expected layout via dirname/basename games.
REPO_ROOT="$(cd "${CWD:-$(pwd)}" 2>/dev/null && pwd -P)" || {
  echo "ERROR: cwd is not a valid directory: ${CWD:-$(pwd)}" >&2
  exit 1
}
REPO_NAME="$(basename "$REPO_ROOT")"

# Reject early if the canonical cwd isn't a git work tree, so the user gets a
# self-explanatory error rather than a downstream `git worktree add` failure.
git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: $REPO_ROOT is not a git work tree" >&2
  exit 1
}

if [ -n "$NAME" ]; then
  # Explicit target branch passed via EnterWorktree({name: "..."}).
  TARGET_BRANCH="$NAME"
  # Validate branch name: same character class as legacy slug + `/` for
  # namespaced branches like `feat/foo`. First char excludes `-` so the
  # name can't be misread as a flag.
  if [[ ! "$TARGET_BRANCH" =~ ^[A-Za-z0-9_.][A-Za-z0-9._/-]*$ ]]; then
    echo "ERROR: invalid branch name: $TARGET_BRANCH" >&2
    exit 1
  fi
else
  # Legacy: derive target from the main repo's currently checked-out branch
  # and create the worktree detached at that commit.
  TARGET_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
fi
BRANCH_SLUG="${TARGET_BRANCH//\//-}"

if [[ ! "$BRANCH_SLUG" =~ ^[A-Za-z0-9_.][A-Za-z0-9._-]*$ ]]; then
  echo "ERROR: invalid branch slug derived from $TARGET_BRANCH: $BRANCH_SLUG" >&2
  exit 1
fi

WORKTREE_DIR="$(dirname "$REPO_ROOT")"
WORKTREE_PATH="$WORKTREE_DIR/${REPO_NAME}--${BRANCH_SLUG}"

# Reuse existing worktree if it already exists.
if [ -d "$WORKTREE_PATH" ]; then
  if [ -n "$NAME" ] && git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    # Branch exists; try to attach. Falls back to detach if the branch is
    # already checked out somewhere (git refuses double-attachment).
    git -C "$WORKTREE_PATH" switch "$TARGET_BRANCH" >&2 2>/dev/null \
      || git -C "$WORKTREE_PATH" checkout --detach "$TARGET_BRANCH" >&2
  else
    # NOTE: no `--` here. For `git checkout`, `--` separates rev-ish from
    # path-spec, so `checkout --detach -- "$TARGET_BRANCH"` would treat
    # TARGET_BRANCH as a file path, not a commit.
    git -C "$WORKTREE_PATH" checkout --detach "$TARGET_BRANCH" >&2
  fi
  echo "Reusing existing worktree at $WORKTREE_PATH (updated to $(git -C "$WORKTREE_PATH" rev-parse --short HEAD))" >&2
  echo "$WORKTREE_PATH"
  exit 0
fi

# Create new worktree.
# Use `--` to terminate option parsing before the positional arguments so a
# branch name beginning with `-` (or any future weirdness) can't be parsed
# as a flag by git worktree add.
if [ -n "$NAME" ]; then
  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    # Branch exists; attach. Will fail if already checked out elsewhere.
    git -C "$REPO_ROOT" worktree add -- "$WORKTREE_PATH" "$TARGET_BRANCH" >&2
  else
    # Branch doesn't exist; create off main/master.
    if git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/main; then
      BASE_REF="main"
    elif git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/master; then
      BASE_REF="master"
    else
      echo "ERROR: cannot create $TARGET_BRANCH — no main or master branch in $REPO_ROOT" >&2
      exit 1
    fi
    git -C "$REPO_ROOT" worktree add -b "$TARGET_BRANCH" -- "$WORKTREE_PATH" "$BASE_REF" >&2
  fi
else
  git -C "$REPO_ROOT" worktree add --detach -- "$WORKTREE_PATH" "$TARGET_BRANCH" >&2
fi

# Run setup only if the repo's script supports --worktree.
if [ -f "$WORKTREE_PATH/setup" ] && grep -q -- '--worktree' "$WORKTREE_PATH/setup"; then
  OFFSET="$(pick_offset "$REPO_ROOT")"
  "$WORKTREE_PATH/setup" --worktree "$REPO_ROOT" --offset "$OFFSET" >&2
fi

echo "$WORKTREE_PATH"
