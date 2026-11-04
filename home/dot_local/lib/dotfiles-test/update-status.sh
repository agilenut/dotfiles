#!/usr/bin/env bash
# update-status tests: the status-bar marker and the details, against fixture
# state files.

UPDATE_STATUS="${HOME}/.local/bin/update-status"

test_update_status() {
  section "Update status"

  # The scheduled run is macOS-only, and the fixtures use BSD `date -v`.
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi
  if [ ! -x "$UPDATE_STATUS" ]; then
    fail "update-status not installed (or not executable) at $UPDATE_STATUS"
    return
  fi

  # The output abbreviates $HOME as a literal ~. The marker's icon is Nerd
  # Font's warning sign, U+F071.
  local tmp state out today tilde='~' icon=$'\xef\x81\xb1'
  tmp=$(mktemp -d)
  state="$tmp/state/topgrade"
  today=$(date +%Y-%m-%d)
  us_fresh_state() {
    rm -rf "$tmp/state"
    mkdir -p "$state"
    echo "$today" >"$state/last-day"
    echo "$HOME/Library/Logs/topgrade-daily-$today.log" >"$state/last-log"
    : >"$state/drift"
    : >"$state/stale-containers"
    : >"$state/outdated-casks"
    : >"$state/new-steps"
  }
  # A docker stub answering `container inspect`, `image inspect` and
  # `version` from files in $tmp/docker: container-<name> holds the
  # container's tag, running state and image ID (tab-separated), and
  # image-<tag> (with / and : replaced by _) holds the ID the tag points to.
  # With no $tmp/docker it fails every call, as when Docker isn't running,
  # so tests that don't create it see every listed container stay listed.
  mkdir -p "$tmp/stub-bin"
  cat >"$tmp/stub-bin/docker" <<'STUB'
#!/usr/bin/env bash
dir="$STUB_DOCKER_DIR"
[ -d "$dir" ] || exit 1
target="${!#}"
case "$1" in
  container) file="$dir/container-$target" ;;
  image) file="$dir/image-$(tr '/:' '__' <<<"$target")" ;;
  version) exit 0 ;;
  *) exit 1 ;;
esac
[ -f "$file" ] || exit 1
cat "$file"
STUB
  chmod +x "$tmp/stub-bin/docker"
  us_status() {
    PATH="$tmp/stub-bin:$PATH" STUB_DOCKER_DIR="$tmp/docker" XDG_STATE_HOME="$tmp/state" \
      "$UPDATE_STATUS" "$@" 2>&1
  }

  rm -rf "$tmp/state"
  out=$(us_status --tmux) || true
  if [ -z "$out" ] && us_status | grep -q 'All clear'; then
    pass "no state yet: no marker, and the details say all clear"
  else
    fail "no-state output wrong: '$out'"
  fi

  us_fresh_state
  out=$(us_status --tmux) || true
  if [ -z "$out" ] && us_status | grep -q 'All clear'; then
    pass "a clean recent run: no marker"
  else
    fail "clean-state marker should be empty: '$out'"
  fi

  us_fresh_state
  printf '%s\n' 'Brew (ARM)' 'npm' >"$state/failed"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=red]$icon 1#[default]" ]; then
    pass "a failed run shows a red marker"
  else
    fail "failed marker wrong: '$out'"
  fi
  out=$(us_status) || true
  if grep -Fq 'Update failed: Brew (ARM), npm' <<<"$out" \
    && grep -Fq "$tilde/Library/Logs/topgrade-daily-$today.log" <<<"$out"; then
    pass "details name the failed steps and the log"
  else
    fail "failed details wrong: $(tr '\n' '|' <<<"$out")"
  fi

  # One count per kind of item, however many files or apps it lists.
  us_fresh_state
  printf '%s\n' .config/git/config .config/karabiner/karabiner.json >"$state/drift"
  printf '%s\t%s\t%s\n' shop-db-1 postgres:18 shop >"$state/stale-containers"
  printf '%s\n' visual-studio-code warp >"$state/outdated-casks"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=brightblack]$icon 3#[default]" ]; then
    pass "drift, stale containers, and waiting casks: a gray marker counting 3"
  else
    fail "attention marker wrong: '$out'"
  fi
  out=$(us_status) || true
  if grep -Fq "$tilde/.config/karabiner/karabiner.json" <<<"$out" && grep -Fq 'chezmoi re-add' <<<"$out" \
    && grep -Fq 'shop-db-1 (shop)' <<<"$out" && grep -Fq '`update-containers`' <<<"$out" \
    && grep -Fq 'visual-studio-code, warp' <<<"$out" && grep -Fq 'Run `dotfiles-drift` to recheck' <<<"$out"; then
    pass "details list each item with what to run"
  else
    fail "attention details wrong: $(tr '\n' '|' <<<"$out")"
  fi

  us_fresh_state
  echo npm >"$state/new-steps"
  echo '2.1.1 → 2.1.2' >"$state/claude-upgrade"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=brightblack]$icon 2#[default]" ] && us_status | grep -Fq 'Claude Code 2.1.1 → 2.1.2' \
    && us_status | grep -Fq 'claude-refresh' && us_status | grep -Fq 'New topgrade step: npm'; then
    pass "a new step and a Claude Code upgrade count, with what to run"
  else
    fail "notice output wrong: '$out' / $(us_status | tr '\n' '|')"
  fi

  # A held lock or an unloaded job stops the run without failing it.
  us_fresh_state
  date -v-3d +%Y-%m-%d >"$state/last-day"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=red]$icon 1#[default]" ] && us_status | grep -q "hasn't run since $(date -v-3d +%Y-%m-%d)"; then
    pass "no run in over 2 days shows a red marker"
  else
    fail "stale-run marker wrong: '$out'"
  fi
  date -v-2d +%Y-%m-%d >"$state/last-day"
  out=$(us_status --tmux) || true
  if [ -z "$out" ]; then
    pass "a run 2 days ago (one missed day) isn't flagged yet"
  else
    fail "2-day-old run flagged: '$out'"
  fi

  # `failed` holds one reason line when the run itself failed.
  us_fresh_state
  echo 'update failed, see log' >"$state/failed"
  rm "$state/last-log"
  out=$(us_status) || true
  if grep -Fq 'Update failed: update failed, see log.' <<<"$out" && ! grep -Fq ',  ' <<<"$out"; then
    pass "a one-line failure reason keeps its comma, and a missing log path doesn't break it"
  else
    fail "reason line wrong: $(tr '\n' '|' <<<"$out")"
  fi

  us_fresh_state
  printf '%s\t%s\t%s\n' scratch alpine:3 '' >"$state/stale-containers"
  out=$(us_status) || true
  if grep -Fq 'Containers on an older image: scratch. ' <<<"$out"; then
    pass "a container outside any compose project is listed by name alone"
  else
    fail "project-less container wrong: $(tr '\n' '|' <<<"$out")"
  fi

  # The list is written once a day, so each entry is checked again against
  # the container's own tag, and only a running container on an older image
  # stays listed.
  us_container() { printf '%s\t%s\t%s\n' "$2" "$3" "$4" >"$tmp/docker/container-$1"; }
  us_fresh_state
  mkdir -p "$tmp/docker"
  printf '%s\t%s\t%s\n' \
    shop-cache-1 redis:7 shop \
    shop-db-1 postgres:18 shop \
    shop-api-1 shop/api:1 shop \
    shop-web-1 nginx:1 shop \
    shop-job-1 shop/worker:1 shop \
    old-1 alpine:3 '' >"$state/stale-containers"
  echo sha256:redis-new >"$tmp/docker/image-redis_7"
  us_container shop-cache-1 redis:7 true sha256:redis-old
  echo sha256:pg-new >"$tmp/docker/image-postgres_18"
  us_container shop-db-1 postgres:18 true sha256:pg-new
  echo sha256:api-1 >"$tmp/docker/image-shop_api_1"
  echo sha256:api-2 >"$tmp/docker/image-shop_api_2"
  us_container shop-api-1 shop/api:2 true sha256:api-2
  us_container shop-web-1 nginx:1 true sha256:nginx-old
  echo sha256:worker-new >"$tmp/docker/image-shop_worker_1"
  us_container shop-job-1 shop/worker:1 false sha256:worker-old
  out=$(us_status) || true
  if grep -Fq 'Containers on an older image: shop-cache-1 (shop). ' <<<"$out"; then
    pass "only a running container on an older image stays listed (recreated, moved to a new tag, tag gone, stopped, and removed drop off)"
  else
    fail "stale list not rechecked: $(tr '\n' '|' <<<"$out")"
  fi
  us_container shop-cache-1 redis:7 true sha256:redis-new
  out=$(us_status --tmux) || true
  if [ -z "$out" ] && us_status | grep -q 'All clear'; then
    pass "once no listed container is still on an older image, no marker"
  else
    fail "marker should be empty once nothing is stale: '$out'"
  fi
  rm -rf "$tmp/docker"
  out=$(us_status) || true
  if grep -Fq 'Containers on an older image: shop-cache-1 (shop), shop-db-1 (shop), shop-api-1 (shop), shop-web-1 (shop), shop-job-1 (shop), old-1. ' <<<"$out"; then
    pass "with Docker down, every listed container stays listed"
  else
    fail "Docker-down stale list wrong: $(tr '\n' '|' <<<"$out")"
  fi

  us_fresh_state
  echo mise >"$state/failed"
  date -v-3d +%Y-%m-%d >"$state/last-day"
  out=$(us_status --tmux) || true
  if [ "$out" = " #[fg=red]$icon 2#[default]" ]; then
    pass "a failure and a stale run together: red, counting 2"
  else
    fail "failed + stale marker wrong: '$out'"
  fi

  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  # Last, because tmux truncates status-right from the left.
  if grep -Eq "^set -g status-right '.*#\(~/.local/bin/update-status --tmux\)'$" "$conf"; then
    pass "the marker ends the tmux status bar"
  else
    fail "tmux status-right doesn't end with the update-status marker"
  fi
  # Its #(...) commands go to sh, and no quoting makes every directory name
  # safe there (#{q:} leaves newlines), so the path never goes in one.
  local jobs
  jobs=$(grep -E '^set -g status-right ' "$conf" | grep -o '#([^)]*)')
  if [[ -n "$jobs" ]] && ! grep -q 'pane_current_path' <<<"$jobs"; then
    pass "the status bar's shell commands never get the pane's path"
  else
    fail "a tmux status-right #(...) command gets #{pane_current_path}: $(tr '\n' ' ' <<<"$jobs")"
  fi

  # tmux-git-status gets a pane ID and asks tmux for its path.
  local git_status="$HOME/.local/bin/tmux-git-status" repo="$tmp/repo dir" out
  mkdir -p "$tmp/bin" "$repo"
  git -C "$repo" init -q -b trunk
  printf '#!/bin/sh\n[ "$*" = "display -p -t %%7 #{pane_current_path}" ] && echo "$STUB_PANE_PATH"\n' \
    >"$tmp/bin/tmux"
  chmod +x "$tmp/bin/tmux"
  out=$(PATH="$tmp/bin:$PATH" STUB_PANE_PATH="$repo" "$git_status" %7)
  if [[ "$out" == *"⎇ trunk"* ]]; then
    pass "tmux-git-status reads the pane's path from tmux"
  else
    fail "tmux-git-status with a pane ID printed: '$out'"
  fi

  rm -rf "$tmp"
}
