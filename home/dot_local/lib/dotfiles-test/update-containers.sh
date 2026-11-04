#!/usr/bin/env bash
# update-containers tests: which compose commands it runs for the listed
# containers, against a stubbed docker and fixture state files.

UPDATE_CONTAINERS="${HOME}/.local/bin/update-containers"

test_update_containers() {
  section "Update containers"

  if [ ! -x "$UPDATE_CONTAINERS" ]; then
    fail "update-containers not installed (or not executable) at $UPDATE_CONTAINERS"
    return
  fi

  local tmp state log out rc expected
  tmp=$(mktemp -d)
  state="$tmp/state/topgrade"
  log="$tmp/calls"
  mkdir -p "$state" "$tmp/docker" "$tmp/stub-bin" "$tmp/shop" "$tmp/e2e"
  : >"$tmp/shop/compose.yml"
  : >"$tmp/e2e/compose.yml"
  : >"$tmp/e2e/compose.test.yml"

  # A docker stub. `info` fails with DOCKER_DOWN set. `container inspect`
  # answers from $tmp/docker: labels-<name> for the compose-label format,
  # container-<name> (tag, running state, image ID) for update-status's
  # recheck. image-<tag> (with / and : replaced by _) holds the ID the tag
  # points to. `compose` calls are logged and fail with COMPOSE_FAIL set.
  cat >"$tmp/stub-bin/docker" <<'STUB'
#!/usr/bin/env bash
dir="$STUB_DOCKER_DIR"
target="${!#}"
case "$1" in
  info) [ -z "$DOCKER_DOWN" ] ;;
  version) exit 0 ;;
  container)
    case "$*" in
      *Labels*) file="$dir/labels-$target" ;;
      *) file="$dir/container-$target" ;;
    esac
    [ -f "$file" ] && cat "$file"
    ;;
  image)
    file="$dir/image-$(tr '/:' '__' <<<"$target")"
    [ -f "$file" ] && cat "$file"
    ;;
  compose)
    printf '%s\n' "$*" >>"$CALL_LOG"
    [ -z "$COMPOSE_FAIL" ]
    ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$tmp/stub-bin/docker"

  # uc_container <name> <tag> <project> <dir> <files> <service>: a running
  # container on an older image than its tag, started by compose.
  uc_container() {
    printf '%s\ttrue\tsha256:old-%s\n' "$2" "$1" >"$tmp/docker/container-$1"
    echo "sha256:new" >"$tmp/docker/image-$(tr '/:' '__' <<<"$2")"
    printf '%s\t%s\t%s\t%s\n' "$3" "$4" "$5" "$6" >"$tmp/docker/labels-$1"
  }
  run_uc() {
    PATH="$tmp/stub-bin:$PATH" STUB_DOCKER_DIR="$tmp/docker" CALL_LOG="$log" \
      XDG_STATE_HOME="$tmp/state" "$UPDATE_CONTAINERS" "$@" 2>&1 </dev/null
  }

  # shop has two stale services; e2e (started with -p and two config files)
  # has one; scratch wasn't started by compose; cache was already recreated.
  uc_container shop-web-1 nginx:1 shop "$tmp/shop" "$tmp/shop/compose.yml" web
  uc_container shop-db-1 postgres:18 shop "$tmp/shop" "$tmp/shop/compose.yml" db
  uc_container acme-e2e-proxy-1 caddy:2 acme-e2e "$tmp/e2e" \
    "$tmp/e2e/compose.yml,$tmp/e2e/compose.test.yml" proxy
  uc_container scratch alpine:3 '' '' '' ''
  uc_container shop-cache-1 redis:8 shop "$tmp/shop" "$tmp/shop/compose.yml" cache
  printf 'redis:8\ttrue\tsha256:new\n' >"$tmp/docker/container-shop-cache-1"
  printf '%s\t%s\t%s\n' \
    shop-web-1 nginx:1 shop \
    acme-e2e-proxy-1 caddy:2 acme-e2e \
    scratch alpine:3 '' \
    shop-cache-1 redis:8 shop \
    shop-db-1 postgres:18 shop >"$state/stale-containers"

  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  expected=$(printf '%s\n' \
    "compose -p acme-e2e --project-directory $tmp/e2e -f $tmp/e2e/compose.yml -f $tmp/e2e/compose.test.yml up -d --no-deps --no-build proxy" \
    "compose -p shop --project-directory $tmp/shop -f $tmp/shop/compose.yml up -d --no-deps --no-build db web")
  if [ "$rc" -eq 0 ] && [ "$(cat "$log")" = "$expected" ]; then
    pass "recreates each project's stale services with its own name, folder, and config files"
  else
    fail "compose calls wrong (rc=$rc): $(tr '\n' '|' <"$log")"
  fi
  if grep -Fq 'skip    scratch (not started by compose' <<<"$out" \
    && grep -Fq 'recreated  shop (db web)' <<<"$out"; then
    pass "a container compose didn't start is reported, not recreated"
  else
    fail "update-containers output wrong: $(tr '\n' '|' <<<"$out")"
  fi

  # Without --yes it asks, so with no terminal it stops before recreating.
  : >"$log"
  rc=0
  out=$(run_uc) || rc=$?
  if [ "$rc" -ne 0 ] && [ ! -s "$log" ] && grep -Fq 'rerun with --yes' <<<"$out" \
    && grep -Fq 'docker compose -p shop' <<<"$out"; then
    pass "with neither --yes nor a terminal, shows the commands and recreates nothing"
  else
    fail "no-terminal run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi

  # A project whose config file is gone is skipped and fails the run; the
  # others are still recreated.
  rm "$tmp/e2e/compose.test.yml"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && grep -Fq "skip    acme-e2e (config file gone: $tmp/e2e/compose.test.yml)" <<<"$out" \
    && [ "$(cat "$log")" = "$(tail -1 <<<"$expected")" ]; then
    pass "a project whose config file is gone is skipped, the rest recreated"
  else
    fail "missing-config run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi

  : >"$log"
  rc=0
  out=$(COMPOSE_FAIL=1 run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && grep -Fq 'FAILED     shop' <<<"$out"; then
    pass "a failed recreate is reported and fails the run"
  else
    fail "failed recreate not surfaced (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi

  : >"$state/stale-containers"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$log" ] && [ "$out" = "No containers to recreate." ]; then
    pass "nothing listed: says so and runs nothing"
  else
    fail "empty-list run wrong (rc=$rc): $out"
  fi

  rc=0
  out=$(DOCKER_DOWN=1 run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && [ "$out" = "Docker isn't running." ]; then
    pass "Docker not running: says so and fails"
  else
    fail "Docker-down run wrong (rc=$rc): $out"
  fi

  rm -rf "$tmp"
}
