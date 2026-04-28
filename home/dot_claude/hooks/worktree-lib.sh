# Shared functions for worktree hooks. Source this file, don't execute it.
# shellcheck shell=bash

# Parse cwd from Claude Code hook JSON on stdin. Requires jq.
parse_cwd() {
  local input="$1"
  echo "$input" | jq -r '.cwd // empty'
}

# Check if a path is a git worktree (.git is a file, not a directory).
is_worktree() {
  [ -f "$1/.git" ]
}

# Pick a random port offset (1-99) where all 7 service ports are free.
pick_offset() {
  local base_ports=(5432 3000 2525 5050 8080 8000 443)
  for _ in 1 2 3 4 5; do
    local offset=$((RANDOM % 99 + 1))
    local collision=false
    for base in "${base_ports[@]}"; do
      if lsof -i :"$((base + offset))" -sTCP:LISTEN >/dev/null 2>&1; then
        collision=true
        break
      fi
    done
    if [ "$collision" = false ]; then
      echo "$offset"
      return 0
    fi
  done
  echo "ERROR: Could not find a free port offset after 5 attempts" >&2
  return 1
}

# Stop Docker containers for a worktree, then remove the git worktree.
# Args: $1 = worktree path, $2 = "verbose" (optional)
teardown_worktree() {
  local wt_path="$1"
  local verbose="${2:-}"

  if [ -f "$wt_path/.env" ] && [ -f "$wt_path/docker-compose.yml" ]; then
    (
      cd "$wt_path" || return
      set -a
      # shellcheck source=/dev/null
      source .env
      set +a
      PROJECT="${COMPOSE_PROJECT_NAME:-}"
      if [ -n "$PROJECT" ]; then
        for suffix in "" "-e2e"; do
          local p="${PROJECT}${suffix}"
          if docker compose -p "$p" ps -q 2>/dev/null | grep -q .; then
            [ -n "$verbose" ] && echo "Stopping Docker project $p..."
            docker compose -p "$p" down -v 2>/dev/null || true
          fi
        done
      fi
    )
  fi

  local main_repo
  main_repo="$(git -C "$wt_path" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //' || true)"
  if [ -n "$main_repo" ] && [ -d "$main_repo" ]; then
    [ -n "$verbose" ] && echo "Removing worktree $wt_path..."
    git -C "$main_repo" worktree remove --force "$wt_path" 2>/dev/null || true
  fi
}
