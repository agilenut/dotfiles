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

# Echo a worktree's Compose project name: COMPOSE_PROJECT_NAME from its
# .env, when the worktree has a compose file. Prints nothing when either
# file is missing or the name is invalid.
# Args: $1 = worktree path
compose_project_for() {
  local wt_path="$1"

  local name has_compose=""
  for name in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
    [ -f "$wt_path/$name" ] && has_compose=1
  done
  { [ -n "$has_compose" ] && [ -f "$wt_path/.env" ]; } || return 0

  local project
  project=$(extract_compose_project "$wt_path/.env")
  if [ -z "$project" ]; then
    echo "WARNING: COMPOSE_PROJECT_NAME missing or invalid in $wt_path/.env; skipping Docker cleanup" >&2
  fi
  echo "$project"
}

# Run docker compose from /, so it works from container labels alone and
# never loads a compose file or .env from the caller's folder (which may be
# the deleted worktree or another project).
compose_by_name() {
  (cd / && docker compose "$@")
}

# Remove a Compose project and its "-e2e" variant: containers running or
# stopped, volumes, networks, and images built without an `image:` tag.
# Needs only the project name, so it can run after the worktree is gone.
# Docker not installed or not running only warns; returns non-zero when
# `docker compose down` fails.
# Args: $1 = project name, $2 = "verbose" (optional)
teardown_compose_projects() {
  local project="$1"
  local verbose="${2:-}"

  if ! command -v docker >/dev/null 2>&1; then
    echo "WARNING: docker is not installed; Compose project $project was not removed" >&2
    return 0
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "WARNING: Docker is not running; Compose project $project was not removed" >&2
    return 0
  fi

  local suffix p containers
  for suffix in "" "-e2e"; do
    p="${project}${suffix}"
    if ! containers=$(compose_by_name -p "$p" ps -a -q 2>/dev/null); then
      echo "WARNING: docker compose ps failed; Compose project $p was not removed" >&2
      continue
    fi
    [ -n "$containers" ] || continue
    [ -n "$verbose" ] && echo "Removing Compose project $p..."
    if ! compose_by_name -p "$p" down -v --rmi local --remove-orphans >&2; then
      echo "ERROR: docker compose down failed for project $p; retry from /: docker compose -p $p down -v --rmi local --remove-orphans" >&2
      return 1
    fi
  done
}

# Remove a worktree, then its Compose projects.
# Usage: teardown_worktree <path> [--verbose] [--force]
# Git removes the worktree before Docker is touched, so any refusal (changes
# without --force, a locked worktree, an unknown path) loses nothing.
# Returns non-zero when the worktree is kept or Docker cleanup fails.
teardown_worktree() {
  local wt_arg="$1"
  shift
  local verbose="" force=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --verbose) verbose=verbose ;;
      --force) force=1 ;;
      *)
        echo "ERROR: teardown_worktree: unknown option $1" >&2
        return 2
        ;;
    esac
    shift
  done

  # git -C <main repo> would read a relative path against the main repo.
  local wt_path
  wt_path="$(cd "$wt_arg" 2>/dev/null && pwd -P)" || {
    echo "ERROR: not a directory: $wt_arg" >&2
    return 1
  }

  local main_repo
  main_repo="$(git -C "$wt_path" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //' || true)"
  if [ -z "$main_repo" ] || [ ! -d "$main_repo" ]; then
    echo "ERROR: cannot find the main repo for $wt_path" >&2
    return 1
  fi

  if [ -z "$force" ]; then
    local changes
    if ! changes="$(git -C "$wt_path" status --porcelain)"; then
      echo "ERROR: git status failed in $wt_path; it was not removed" >&2
      return 1
    fi
    if [ -n "$changes" ]; then
      echo "ERROR: $wt_path has uncommitted or untracked changes and was not removed; pass --force to discard them" >&2
      return 1
    fi
  fi

  local project
  project="$(compose_project_for "$wt_path")"

  [ -n "$verbose" ] && echo "Removing worktree $wt_path..."
  local remove_args=(worktree remove)
  [ -n "$force" ] && remove_args+=(--force)
  if ! git -C "$main_repo" "${remove_args[@]}" "$wt_path" >&2; then
    echo "ERROR: git could not remove $wt_path" >&2
    return 1
  fi

  [ -z "$project" ] || teardown_compose_projects "$project" "$verbose"
}
