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
  # points to, and ports-<name> the port bindings the container publishes.
  # `compose ... config` prints config-<project>, or config-<project>-env
  # when called with --env-file and that stub exists. With neither stub it
  # prints every fixture service with no ports, and without `--profile '*'`
  # a config with no services. It fails
  # with an error for each project named in CONFIG_FAIL. Other `compose`
  # calls are logged and fail with COMPOSE_FAIL set.
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
      *PortBindings*) file="$dir/ports-$target" ;;
      *) file="$dir/container-$target" ;;
    esac
    [ -f "$file" ] && cat "$file"
    ;;
  image)
    file="$dir/image-$(tr '/:' '__' <<<"$target")"
    [ -f "$file" ] && cat "$file"
    ;;
  compose)
    if [[ " $* " == *" config "* ]]; then
      if [[ " $CONFIG_FAIL " == *" $3 "* ]]; then
        echo "invalid interpolation format" >&2
        exit 1
      fi
      [[ " $* " == *" --profile * "* ]] || {
        echo '{"services":{}}'
        exit 0
      }
      file="$dir/config-$3"
      [[ " $* " != *" --env-file "* ]] || [ ! -f "$file-env" ] || file="$file-env"
      if [ -f "$file" ]; then
        cat "$file"
      else
        echo '{"services":{"web":{},"db":{},"cache":{},"proxy":{}}}'
      fi
      exit 0
    fi
    printf '%s\n' "$*" >>"$CALL_LOG"
    [ -z "$COMPOSE_FAIL" ]
    ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$tmp/stub-bin/docker"

  # uc_container <name> <tag> <project> <dir> <files> <service> [<env files>]:
  # a running container on an older image than its tag, started by compose.
  uc_container() {
    printf '%s\ttrue\tsha256:old-%s\n' "$2" "$1" >"$tmp/docker/container-$1"
    echo "sha256:new" >"$tmp/docker/image-$(tr '/:' '__' <<<"$2")"
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$3" "$4" "$5" "$6" "${7:-}" >"$tmp/docker/labels-$1"
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
  # shop's db publishes a port, and compose would publish the same one.
  echo '{"services":{"web":{},"db":{"ports":[{"host_ip":"127.0.0.1","target":5432,"published":"5432","protocol":"tcp"}]}}}' \
    >"$tmp/docker/config-shop"
  echo '{"5432/tcp":[{"HostIp":"127.0.0.1","HostPort":"5432"}]}' >"$tmp/docker/ports-shop-db-1"

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

  # A script started acme-e2e's proxy on port 1443 with a variable that
  # compose can't see, so compose would publish the .env port, 443. It's
  # skipped and fails the run; shop is still recreated.
  echo '{"services":{"proxy":{"ports":[{"target":443,"published":"443","protocol":"tcp"}]}}}' \
    >"$tmp/docker/config-acme-e2e"
  echo '{"443/tcp":[{"HostIp":"","HostPort":"1443"}]}' >"$tmp/docker/ports-acme-e2e-proxy-1"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && [ "$(cat "$log")" = "$(tail -1 <<<"$expected")" ] \
    && grep -Fq 'skip    acme-e2e-proxy-1 (ports would change from :1443:443/tcp to :443:443/tcp; recreate it the way it was started)' <<<"$out"; then
    pass "a container whose ports would change is skipped, the rest recreated"
  else
    fail "changed-port run wrong (rc=$rc): $(tr '\n' '|' <<<"$out") calls: $(tr '\n' '|' <"$log")"
  fi

  # The proxy was started with --env-file test.env, which sets port 1443.
  # It's recreated with the same env file, so its ports don't change.
  : >"$tmp/e2e/test.env"
  uc_container acme-e2e-proxy-1 caddy:2 acme-e2e "$tmp/e2e" \
    "$tmp/e2e/compose.yml,$tmp/e2e/compose.test.yml" proxy "$tmp/e2e/test.env"
  echo '{"services":{"proxy":{"ports":[{"target":443,"published":"1443","protocol":"tcp"}]}}}' \
    >"$tmp/docker/config-acme-e2e-env"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -eq 0 ] && [ "$(head -1 "$log")" = "compose -p acme-e2e --project-directory $tmp/e2e -f $tmp/e2e/compose.yml -f $tmp/e2e/compose.test.yml --env-file $tmp/e2e/test.env up -d --no-deps --no-build proxy" ]; then
    pass "a container started with an env file is recreated with it"
  else
    fail "env-file run wrong (rc=$rc): $(tr '\n' '|' <<<"$out") calls: $(tr '\n' '|' <"$log")"
  fi

  # An env file that's gone skips its project, like a missing config file.
  rm "$tmp/e2e/test.env"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && grep -Fq "skip    acme-e2e (env file gone: $tmp/e2e/test.env)" <<<"$out" \
    && [ "$(cat "$log")" = "$(tail -1 <<<"$expected")" ]; then
    pass "a project whose env file is gone is skipped, the rest recreated"
  else
    fail "missing-env-file run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi
  uc_container acme-e2e-proxy-1 caddy:2 acme-e2e "$tmp/e2e" \
    "$tmp/e2e/compose.yml,$tmp/e2e/compose.test.yml" proxy
  rm "$tmp/docker/config-acme-e2e" "$tmp/docker/config-acme-e2e-env" "$tmp/docker/ports-acme-e2e-proxy-1"

  # When compose can't read shop's config, its containers are skipped with
  # compose's error and fail the run; acme-e2e is still recreated.
  : >"$log"
  rc=0
  out=$(CONFIG_FAIL=shop run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && [ "$(cat "$log")" = "$(head -1 <<<"$expected")" ] \
    && grep -Fq "skip    shop-db-1 (compose can't read its config: invalid interpolation format; recreate it by hand)" <<<"$out"; then
    pass "a container whose compose config can't be read is skipped with compose's error, the rest recreated"
  else
    fail "unreadable-config run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi

  # With every container skipped, the run fails and doesn't claim there was
  # nothing to recreate.
  : >"$log"
  rc=0
  out=$(CONFIG_FAIL="shop acme-e2e" run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && [ ! -s "$log" ] && ! grep -Fq 'No containers to recreate.' <<<"$out"; then
    pass "every container skipped: fails without saying there was nothing to recreate"
  else
    fail "all-skipped run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi

  # The proxy's service was removed from acme-e2e's config: it's skipped
  # and fails the run, not reported as a port change.
  echo '{"services":{}}' >"$tmp/docker/config-acme-e2e"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -ne 0 ] && [ "$(cat "$log")" = "$(tail -1 <<<"$expected")" ] \
    && grep -Fq 'skip    acme-e2e-proxy-1 (service proxy no longer in its config; recreate it by hand)' <<<"$out"; then
    pass "a container whose service left its config is skipped, the rest recreated"
  else
    fail "removed-service run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi
  rm "$tmp/docker/config-acme-e2e"

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

  # A container compose didn't start is reported but doesn't fail the run.
  printf 'scratch\talpine:3\t\n' >"$state/stale-containers"
  : >"$log"
  rc=0
  out=$(run_uc --yes) || rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$log" ] && grep -Fq 'skip    scratch (not started by compose' <<<"$out" \
    && grep -Fq 'No containers to recreate.' <<<"$out"; then
    pass "only a container compose didn't start: reports it and succeeds"
  else
    fail "not-compose-only run wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
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
