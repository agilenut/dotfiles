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

# Succeed when a folder holds a compose file at its top level.
# Args: $1 = folder
has_compose_file() {
  local name
  for name in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
    [ -f "$1/$name" ] && return 0
  done
  return 1
}

# Echo the Compose project name a checkout runs under, using compose's precedence:
# COMPOSE_PROJECT_NAME from its .env, else a top-level `name:` in its
# compose file, else its folder name the way compose derives one
# (lowercased, keeping only a-z, 0-9, - and _, without leading - or _).
# Args: $1 = checkout path
default_compose_project() {
  local project name
  project=$(extract_compose_project "$1/.env")
  if [ -z "$project" ]; then
    for name in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
      [ -f "$1/$name" ] || continue
      project=$({ grep -m1 -E '^name:' "$1/$name" || true; } | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]*(#.*)?$//' | tr -d "\"'")
      break
    done
    [[ "$project" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || project=""
  fi
  if [ -z "$project" ]; then
    project=$(basename "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' | sed -E 's/^[-_]+//')
  fi
  echo "$project"
}

# Run docker compose from /, so it works from container labels alone and
# never loads a compose file or .env from the caller's folder (which may be
# the deleted worktree or another project).
compose_by_name() {
  (cd / && docker compose "$@")
}

# Find the Compose projects that belong to a worktree. Every container
# records the folder compose ran in (com.docker.compose.project.working_dir),
# so this works whatever the projects are named, and after the worktree is
# gone. Prints one tab-separated line per project: "own", the project, then
# each folder its containers ran in, relative to the worktree ("." or
# "./sub"), when all its containers came from the worktree's folder or a
# folder inside it; "mixed" and the project when some came from elsewhere.
# `docker compose down` removes a whole project, so a mixed one can't be
# removed without taking the other folder's containers with it.
# Args: $1, $2... = the worktree's absolute paths, with symlinks resolved
#       and with them kept
worktree_projects() {
  local listing
  listing=$(docker ps -a --format '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.project.working_dir"}}') \
    || return 1
  # Paths go through the environment, since awk -v would rewrite backslashes.
  WT_PATHS="$(printf '%s\n' "$@")" awk -F'\t' '
      BEGIN { n = split(ENVIRON["WT_PATHS"], wt, "\n") }
      $1 == "" { next }
      {
        rel = ""
        for (i = 1; i <= n && rel == ""; i++)
          if ($2 == wt[i]) rel = "."
          else if (index($2, wt[i] "/") == 1) rel = "." substr($2, length(wt[i]) + 1)
        if (rel == "") { other[$1] = 1; next }
        if (!seen[$1 SUBSEP rel]++) dirs[$1] = dirs[$1] "\t" rel
      }
      END {
        for (p in dirs) print ((p in other) ? "mixed\t" p : "own\t" p dirs[p])
      }' <<<"$listing" \
    | sort
}

# Echo the first checkout that runs a project with this name from the same
# folder, relative to the checkout. Two checkouts of one repo derive the same
# name for a folder unless an .env sets it, so such a project's volumes may
# hold that checkout's data. Fails when no checkout does.
# Args: $1 = project name, $2 = folder relative to the checkout ("." or
#       "./sub"), $3 = the other checkouts' paths, one per line
checkout_using_project() {
  local checkout dir
  while IFS= read -r checkout; do
    [ -n "$checkout" ] || continue
    dir="$checkout/${2#./}"
    [ "$2" = . ] && dir="$checkout"
    [ -d "$dir" ] || continue
    if [ "$(default_compose_project "$dir")" = "$1" ]; then
      echo "$checkout"
      return 0
    fi
  done <<<"$3"
  return 1
}

# Print what removing a project deletes: its named data volumes, and a count
# of the images compose built for it, which compose tags
# <project>-<service>. `down --rmi local` keeps an image a service names
# with `image:`, so those aren't counted. When a lookup fails, warns and
# prints "unknown" for both.
# Args: $1 = project name
describe_compose_project() {
  local label="label=com.docker.compose.project=$1" volumes ids details="" images=0
  if ! volumes=$(docker volume ls --filter "$label" --format '{{.Label "com.docker.compose.volume"}}') \
    || ! ids=$(docker images -q --filter "$label") \
    || { [ -n "$ids" ] && ! details=$(sort -u <<<"$ids" \
      | xargs docker image inspect --format '{{index .Config.Labels "com.docker.compose.service"}} {{join .RepoTags " "}}'); }; then
    echo "WARNING: docker volume or image lookup failed for Compose project $1" >&2
    echo "remove $1: volumes unknown; images unknown"
    return 0
  fi
  volumes=$(sort <<<"$volumes" | tr '\n' ' ')
  volumes="${volumes# }"
  volumes="${volumes% }"
  if [ -n "$details" ]; then
    images=$(awk -v p="$1" '{ for (i = 2; i <= NF; i++) if (index($i, p "-" $1 ":") == 1) { n++; break } } END { print n + 0 }' <<<"$details")
  fi
  echo "remove $1: volumes ${volumes:-none}; images $images"
}

# Remove the Compose projects that belong to a worktree, with their volumes,
# networks, and the images compose built for them (not ones a service names
# with `image:`).
# Projects are found by folder (worktree_projects). Volumes and images
# record only a project name, so leftovers whose containers are all gone are
# found only under the worktree's own COMPOSE_PROJECT_NAME. A project that
# another checkout of the repo would run under the same name, from the same
# folder, is never removed, even when every container left came from the
# worktree: the name is shared (a subfolder's derived name, or a worktree
# .env that copied the main checkout's), and `down -v` would delete that
# checkout's volumes.
# With "dry-run", prints a line per project (describe_compose_project, or
# "keep <project>: <reason>") and removes nothing.
# Docker not installed or not running warns, unless "quiet"; returns non-zero
# when `docker compose down` fails for any project, after trying them all.
# Args: $1 = the worktree's COMPOSE_PROJECT_NAME from .env (may be empty),
#       $2 = the repo's other checkouts, one path per line,
#       $3 = "verbose", "dry-run" or empty, $4 = "quiet" or empty,
#       $5... = the worktree's paths (see worktree_projects)
teardown_compose_projects() {
  local env_project="$1" others="$2" mode="$3" quiet="$4"
  shift 4
  local wt_path="$1"

  if ! command -v docker >/dev/null 2>&1; then
    [ -n "$quiet" ] || echo "WARNING: docker is not installed; Compose projects for $wt_path were not removed" >&2
    return 0
  fi
  if ! docker info >/dev/null 2>&1; then
    [ -n "$quiet" ] || echo "WARNING: Docker is not running; Compose projects for $wt_path were not removed" >&2
    return 0
  fi

  local found
  if ! found=$(worktree_projects "$@"); then
    echo "WARNING: docker ps failed; Compose projects for $wt_path were not removed" >&2
    return 0
  fi

  local remove=() line fields kind p reason rel checkout
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    IFS=$'\t' read -r -a fields <<<"$line"
    kind="${fields[0]}" p="${fields[1]}" reason=""
    if [ "$kind" = mixed ]; then
      reason="it also has containers from other folders"
    else
      for rel in "${fields[@]:2}"; do
        if checkout=$(checkout_using_project "$p" "$rel" "$others"); then
          reason="$checkout runs a project with the same name"
          break
        fi
      done
    fi
    if [ -z "$reason" ]; then
      remove+=("$p")
    elif [ "$mode" = dry-run ]; then
      echo "keep $p: $reason"
    else
      echo "WARNING: Compose project $p was not removed: $reason" >&2
    fi
  done <<<"$found"

  if [ -n "$env_project" ] \
    && ! grep -qE "^(own|mixed)	${env_project}(	|\$)" <<<"$found"; then
    local label="label=com.docker.compose.project=$env_project" containers volumes images
    if checkout=$(checkout_using_project "$env_project" . "$others"); then
      : # That checkout's data; leave it to /wrap's leftovers check.
    elif ! containers=$(docker ps -a -q --filter "$label" 2>/dev/null) \
      || ! volumes=$(docker volume ls -q --filter "$label" 2>/dev/null) \
      || ! images=$(docker images -q --filter "$label" 2>/dev/null); then
      echo "WARNING: docker container, volume or image lookup failed; Compose project $env_project was not removed" >&2
    elif [ -z "$containers" ] && [ -n "$volumes$images" ]; then
      remove+=("$env_project")
    fi
  fi

  local failed=0
  for p in ${remove[@]+"${remove[@]}"}; do
    if [ "$mode" = dry-run ]; then
      describe_compose_project "$p"
      continue
    fi
    [ "$mode" = verbose ] && echo "Removing Compose project $p..."
    if ! compose_by_name -p "$p" down -v --rmi local --remove-orphans >&2; then
      echo "ERROR: docker compose down failed for project $p; retry from /: docker compose -p $p down -v --rmi local --remove-orphans" >&2
      failed=1
    fi
  done
  return "$failed"
}

# Remove a worktree, then its Compose projects.
# Usage: teardown_worktree <path> [--verbose] [--force] [--dry-run]
# Git removes the worktree before Docker is touched, so any refusal (changes
# without --force, a locked worktree, an unknown path) loses nothing.
# --dry-run prints what removal would do to each Compose project and changes
# nothing, git included.
# Returns non-zero when the worktree is kept or Docker cleanup fails.
teardown_worktree() {
  local wt_arg="$1"
  shift
  local verbose="" force="" dry_run=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --verbose) verbose=1 ;;
      --force) force=1 ;;
      --dry-run) dry_run=1 ;;
      *)
        echo "ERROR: teardown_worktree: unknown option $1" >&2
        return 2
        ;;
    esac
    shift
  done
  local mode=""
  if [ -n "$dry_run" ]; then
    mode=dry-run
  elif [ -n "$verbose" ]; then
    mode=verbose
  fi

  # git -C <main repo> would read a relative path against the main repo.
  # Compose records the folder path as it was when compose ran, symlinks
  # included, so the path is matched both with symlinks resolved and with
  # them kept.
  local wt_path wt_logical
  wt_path="$(cd "$wt_arg" 2>/dev/null && pwd -P)" || {
    echo "ERROR: not a directory: $wt_arg" >&2
    return 1
  }
  wt_logical="$(cd "$wt_arg" && pwd -L)"

  local main_repo
  main_repo="$(git -C "$wt_path" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //' || true)"
  if [ -z "$main_repo" ] || [ ! -d "$main_repo" ]; then
    echo "ERROR: cannot find the main repo for $wt_path" >&2
    return 1
  fi

  # Projects can be started from a compose file in a subfolder, so the
  # folder lookup runs for every worktree. Only a worktree with a top-level
  # compose file warns when Docker is missing, so repos that don't use
  # Compose stay quiet.
  local quiet=quiet env_project=""
  if has_compose_file "$wt_path"; then
    quiet=""
    env_project="$(extract_compose_project "$wt_path/.env")"
    if [ -f "$wt_path/.env" ] && [ -z "$env_project" ]; then
      echo "WARNING: COMPOSE_PROJECT_NAME missing or invalid in $wt_path/.env; skipping the leftover volume and image check" >&2
    fi
  fi
  local others
  others="$(git -C "$main_repo" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' \
    | grep -vxF -e "$wt_path" -e "$wt_logical" || true)"

  if [ -n "$dry_run" ]; then
    teardown_compose_projects "$env_project" "$others" dry-run "$quiet" "$wt_path" "$wt_logical"
    return
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

  [ "$mode" = verbose ] && echo "Removing worktree $wt_path..."
  local remove_args=(worktree remove)
  [ -n "$force" ] && remove_args+=(--force)
  if ! git -C "$main_repo" "${remove_args[@]}" "$wt_path" >&2; then
    echo "ERROR: git could not remove $wt_path" >&2
    return 1
  fi

  teardown_compose_projects "$env_project" "$others" "$mode" "$quiet" "$wt_path" "$wt_logical"
}
