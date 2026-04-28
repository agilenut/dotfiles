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

# Read base host ports from a project's .env.example file. Looks for lines
# of the form (commented or not):
#   PG_HOST_PORT=5432
#   # SMTP_PORT=2525
# Echoes one port per line. Empty output if the file is missing or has no
# matching entries.
read_base_ports() {
  local env_example="$1"
  [ -f "$env_example" ] || return 0
  grep -oE '^[#[:space:]]*[A-Z_]+_(HOST_)?PORT=[0-9]+' "$env_example" 2>/dev/null \
    | grep -oE '[0-9]+$'
}

# Pick a random port offset (1-99) where all the project's declared host
# ports are free. Reads the port list from $repo_root/.env.example. If no
# .env.example or no matching ports are found, returns a random offset
# without collision-checking.
# Args: $1 = repo root (defaults to current directory)
pick_offset() {
  local repo_root="${1:-$(pwd)}"
  local base_ports=()

  while IFS= read -r port; do
    [ -n "$port" ] && base_ports+=("$port")
  done < <(read_base_ports "$repo_root/.env.example")

  if [ ${#base_ports[@]} -eq 0 ]; then
    # No port list to check against; emit a random offset and warn so
    # callers know collision-checking was skipped.
    echo "WARN: no host ports declared in $repo_root/.env.example; using random offset without collision check" >&2
    echo $((RANDOM % 99 + 1))
    return 0
  fi

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

# Safely extract COMPOSE_PROJECT_NAME from a .env file without executing
# its contents. Validates the value matches [A-Za-z0-9_-]+ and echoes it
# (or empty string if missing/invalid). Avoids the shell-injection risk
# of `source .env` against attacker-influenceable file paths.
extract_compose_project() {
  local env_file="$1"
  [ -f "$env_file" ] || return 0
  local val
  val=$(grep -E '^COMPOSE_PROJECT_NAME=' "$env_file" 2>/dev/null \
    | head -1 | cut -d= -f2- | tr -d "\"'\n\r")
  if [[ "$val" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "$val"
  fi
}

# Stop Docker containers for a worktree, then remove the git worktree.
# Args: $1 = worktree path, $2 = "verbose" (optional)
teardown_worktree() {
  local wt_path="$1"
  local verbose="${2:-}"

  if [ -f "$wt_path/.env" ] && [ -f "$wt_path/docker-compose.yml" ]; then
    local project
    project=$(extract_compose_project "$wt_path/.env")
    if [ -n "$project" ]; then
      for suffix in "" "-e2e"; do
        local p="${project}${suffix}"
        if docker compose -p "$p" ps -q 2>/dev/null | grep -q .; then
          [ -n "$verbose" ] && echo "Stopping Docker project $p..."
          docker compose -p "$p" down -v 2>/dev/null || true
        fi
      done
    elif [ -n "$verbose" ]; then
      echo "Skipping Docker cleanup: COMPOSE_PROJECT_NAME missing or invalid in $wt_path/.env" >&2
    fi
  fi

  local main_repo
  main_repo="$(git -C "$wt_path" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //' || true)"
  if [ -n "$main_repo" ] && [ -d "$main_repo" ]; then
    [ -n "$verbose" ] && echo "Removing worktree $wt_path..."
    git -C "$main_repo" worktree remove --force "$wt_path" 2>/dev/null || true
  fi
}
