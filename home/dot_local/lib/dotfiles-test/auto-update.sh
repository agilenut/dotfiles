#!/usr/bin/env bash
# Auto-update tooling tests: topgrade config, its custom-command scripts, and
# the update alias.
#
# Helpers that source a script under test must only run in a subshell
# (command substitution or `( … )`), so the sourced functions and `set -e`
# don't leak into the test runner. pass/fail run in the parent so the
# counters update. Captures end in `|| true`: the runner uses `set -e`, so a
# crashing script would otherwise abort the whole suite instead of failing
# its test.

DOTFILES_DRIFT="${HOME}/.local/bin/dotfiles-drift"
DOCKER_PULL_COMPOSE="${HOME}/.local/bin/docker-pull-compose"

test_dotfiles_drift() {
  section "Dotfiles drift report"

  if [ ! -f "$DOTFILES_DRIFT" ]; then
    fail "dotfiles-drift not installed at $DOTFILES_DRIFT"
    return
  fi

  drift_candidates() {
    # shellcheck source=/dev/null
    source "$DOTFILES_DRIFT" && dotfiles_drift_candidates
  }

  local result expected
  result=$(printf '%s\n' \
    ' R .chezmoiscripts/install-packages.sh' \
    'MM .claude/settings.json' \
    ' M .local/lib/pending.sh' \
    'M  .config/already-matches' \
    'MM Library/Application Support/app/state.json' | drift_candidates) || true
  expected=$(printf '%s\n' '.claude/settings.json' 'Library/Application Support/app/state.json')
  if [ "$result" = "$expected" ]; then
    pass "only files changed locally AND differing from source count as drift"
  else
    fail "drift candidates wrong: '$(printf '%s' "$result" | tr '\n' ',')'"
  fi

  # chezmoi stub: `status` prints $STUB_STATUS (or fails when it's unset);
  # `cat <target>` prints $STUB_TARGETS/<basename of target>; `source-path`
  # prints /src/<basename>, with .tmpl when $STUB_TARGETS/<basename>.tmpl
  # exists.
  local stubdir fakehome rc out
  stubdir=$(mktemp -d)
  fakehome="$stubdir/home"
  mkdir -p "$fakehome/.config" "$stubdir/targets"
  cat >"$stubdir/chezmoi" <<'CHEZMOISTUB'
#!/bin/sh
case "$1" in
  status) [ -n "$STUB_STATUS" ] && cat "$STUB_STATUS" ;;
  cat) cat "$STUB_TARGETS/$(basename "$2")" ;;
  source-path)
    b=$(basename "$2")
    if [ -e "$STUB_TARGETS/$b.tmpl" ]; then echo "/src/$b.tmpl"; else echo "/src/$b"; fi
    ;;
esac
CHEZMOISTUB
  chmod +x "$stubdir/chezmoi"

  drift_differs() {
    # shellcheck source=/dev/null
    source "$DOTFILES_DRIFT" && dotfiles_drift_differs "$1"
  }
  run_differs() {
    PATH="$stubdir:$PATH" HOME="$fakehome" STUB_TARGETS="$stubdir/targets" \
      drift_differs "$1"
  }

  printf '{"a": 1, "b": [1, 2]}\n' >"$fakehome/.config/app.json"
  printf '{\n    "b": [ 1, 2 ],\n    "a": 1\n}\n' >"$stubdir/targets/app.json"
  rc=0
  (run_differs .config/app.json) || rc=$?
  if [ "$rc" -eq 1 ]; then
    pass "JSON that differs only in formatting is not drift"
  else
    fail "reformatted JSON reported as drift (rc=$rc)"
  fi

  printf '{"a": 2, "b": [1, 2]}\n' >"$stubdir/targets/app.json"
  rc=0
  (run_differs .config/app.json) || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "JSON with a changed value is drift"
  else
    fail "changed JSON not reported as drift (rc=$rc)"
  fi

  printf '{"a": 1,\n' >"$fakehome/.config/broken.json"
  printf '{"a": 1}\n' >"$stubdir/targets/broken.json"
  rc=0
  (run_differs .config/broken.json) || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "unparseable JSON counts as drift"
  else
    fail "unparseable JSON dropped (rc=$rc)"
  fi

  printf 'same\n' >"$fakehome/.config/app.conf"
  printf 'same\n' >"$stubdir/targets/app.conf"
  rc=0
  (run_differs .config/app.conf) || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "non-JSON candidates are drift without normalizing"
  else
    fail "non-JSON candidate dropped (rc=$rc)"
  fi

  # ---- end to end: status in, report out ----
  # app.json is reformatted only (not drift); app.conf and broken.json are.
  # app.conf's source is a template, which `chezmoi re-add` won't overwrite.
  printf '{"a": 1, "b": [1, 2]}\n' >"$stubdir/targets/app.json"
  : >"$stubdir/targets/app.conf.tmpl"
  printf '%s\n' 'MM .config/app.json' 'MM .config/app.conf' \
    ' M .config/pending' 'MM .config/broken.json' >"$stubdir/status"
  rc=0
  out=$(PATH="$stubdir:$PATH" HOME="$fakehome" STUB_STATUS="$stubdir/status" \
    STUB_TARGETS="$stubdir/targets" bash "$DOTFILES_DRIFT" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^Dotfiles drift: 2 file' <<<"$out" \
    && grep -Fqx '  ~/.config/app.conf (template: copy the change into /src/app.conf.tmpl)' <<<"$out" \
    && grep -Fqx '  ~/.config/broken.json' <<<"$out" \
    && ! grep -q 'app.json' <<<"$out"; then
    pass "report lists real drift, names template sources, and leaves out reformatted JSON"
  else
    fail "drift report wrong (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi
  if grep -Fq 'chezmoi re-add <file>' <<<"$out" && ! grep -Fq 'chezmoi add' <<<"$out"; then
    pass "report suggests re-add, which won't overwrite a template"
  else
    fail "report should suggest chezmoi re-add: $(tr '\n' '|' <<<"$out")"
  fi

  : >"$stubdir/status"
  rc=0
  out=$(PATH="$stubdir:$PATH" HOME="$fakehome" STUB_STATUS="$stubdir/status" \
    STUB_TARGETS="$stubdir/targets" bash "$DOTFILES_DRIFT" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "No dotfiles drift." ]; then
    pass "no drift reports so and succeeds"
  else
    fail "no-drift run wrong (rc=$rc): $out"
  fi

  rc=0
  PATH="$stubdir:$PATH" HOME="$fakehome" bash "$DOTFILES_DRIFT" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "a failing chezmoi status fails the report"
  else
    fail "chezmoi status failure was swallowed"
  fi

  rm -rf "$stubdir"
}

test_docker_pull_compose() {
  section "Compose image pulls"

  if [ ! -f "$DOCKER_PULL_COMPOSE" ]; then
    fail "docker-pull-compose not installed at $DOCKER_PULL_COMPOSE"
    return
  fi

  compose_plan() {
    # shellcheck source=/dev/null
    source "$DOCKER_PULL_COMPOSE" && docker_pull_compose_plan
  }
  compose_select() {
    # shellcheck source=/dev/null
    source "$DOCKER_PULL_COMPOSE" && docker_pull_compose_select
  }

  local stubdir result expected
  stubdir=$(mktemp -d)
  mkdir -p "$stubdir/app" "$stubdir/api"
  : >"$stubdir/app/compose.yml"
  : >"$stubdir/api/compose.yml"
  : >"$stubdir/api/compose.override.yml"

  # A removed worktree leaves its project listed with files that are gone.
  result=$(jq -n --arg d "$stubdir" '[
    {Name: "app", Status: "running(2)", ConfigFiles: "\($d)/app/compose.yml"},
    {Name: "gone", Status: "exited(1)", ConfigFiles: "\($d)/gone/compose.yml"},
    {Name: "stdin", Status: "exited(1)", ConfigFiles: ""},
    {Name: "api", Status: "exited(3)",
     ConfigFiles: "\($d)/api/compose.yml,\($d)/api/compose.override.yml"}
  ]' | compose_plan) || true
  expected=$(printf 'pull\tapp\t%s\nskip\tgone\t%s\nskip\tstdin\t<none>\npull\tapi\t%s\n' \
    "$stubdir/app/compose.yml" "$stubdir/gone/compose.yml" \
    "$stubdir/api/compose.yml,$stubdir/api/compose.override.yml")
  if [ "$result" = "$expected" ]; then
    pass "projects with missing or no config files are skipped"
  else
    fail "compose plan wrong: '$(printf '%s' "$result" | tr '\n\t' '|,')'"
  fi

  # The rule that blocks pulling a locally built image from Docker Hub:
  # - shop builds `u/backend`, and its worker uses it image-only
  # - web (another project) uses `u/backend:latest` image-only
  # - jobs builds with no `image:`, which compose names `shop-jobs`;
  #   web's runner uses that name
  # Only images nobody builds are pulled.
  result=$(jq -n '[
    {name: "shop", files: "s.yml", services: {
      api: {build: {context: "."}, image: "u/backend"},
      worker: {image: "u/backend"},
      jobs: {build: {context: "."}},
      db: {image: "postgres:18"}}},
    {name: "web", files: "w.yml", services: {
      site: {image: "u/backend:latest"},
      runner: {image: "shop-jobs"},
      cache: {image: "redis:8-alpine@sha256:abc"}}},
    {name: "local", files: "l.yml", services: {
      app: {build: {context: "."}}}}
  ]' | compose_select) || true
  expected=$(printf 'pull\tshop\ts.yml\tdb\npull\tweb\tw.yml\tcache\nnone\tlocal\n')
  if [ "$result" = "$expected" ]; then
    pass "images any project builds are never pulled, across projects"
  else
    fail "compose select wrong: '$(printf '%s' "$result" | tr '\n\t' '|,')'"
  fi

  # docker stub: logs every call. DOCKER_DOWN fails `info`, LS_FAIL fails
  # `compose ls`, PULL_FAIL fails `pull`.
  local log rc out
  log="$stubdir/calls"
  jq -n --arg d "$stubdir" '[
    {Name: "api", Status: "running(1)",
     ConfigFiles: "\($d)/api/compose.yml,\($d)/api/compose.override.yml"},
    {Name: "gone", Status: "exited(1)", ConfigFiles: "\($d)/gone/compose.yml"}
  ]' >"$stubdir/ls.json"
  jq -n '{services: {
    api: {build: {context: "."}, image: "u/backend"},
    worker: {image: "u/backend"},
    db: {image: "postgres:18"}}}' >"$stubdir/config.json"
  cat >"$stubdir/docker" <<'DOCKERSTUB'
#!/bin/sh
printf '%s\n' "$*" >>"$CALL_LOG"
case "$*" in
  info*) [ -z "$DOCKER_DOWN" ] ;;
  "compose ls"*) [ -z "$LS_FAIL" ] && cat "$STUB_LS" ;;
  *" config "*) cat "$STUB_CONFIG" ;;
  *" pull "*) [ -z "$PULL_FAIL" ] ;;
  *) exit 0 ;;
esac
DOCKERSTUB
  chmod +x "$stubdir/docker"

  run_pull() {
    PATH="$stubdir:$PATH" CALL_LOG="$log" STUB_LS="$stubdir/ls.json" \
      STUB_CONFIG="$stubdir/config.json" bash "$DOCKER_PULL_COMPOSE" 2>&1
  }

  : >"$log"
  rc=0
  out=$(DOCKER_DOWN=1 run_pull) || rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^compose' "$log"; then
    pass "Docker not running: skips without failing"
  else
    fail "Docker-down run misbehaved (rc=$rc, log: $(tr '\n' ' ' <"$log"))"
  fi

  : >"$log"
  rc=0
  out=$(run_pull) || rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -Fqx "compose -p api -f $stubdir/api/compose.yml -f $stubdir/api/compose.override.yml --profile * pull --quiet db" "$log" \
    && grep -Fq -- '--profile * config --no-env-resolution --format json' "$log" \
    && ! grep -q -- '-p gone' "$log"; then
    pass "pulls only image-only services, all config files in order, all profiles"
  else
    fail "pull not issued as expected (rc=$rc, log: $(tr '\n' '|' <"$log"))"
  fi

  : >"$log"
  rc=0
  out=$(PULL_FAIL=1 run_pull) || rc=$?
  if [ "$rc" -ne 0 ] && grep -q '^FAILED  api' <<<"$out"; then
    pass "a failed pull is reported and fails the step"
  else
    fail "failed pull not surfaced (rc=$rc): $(tr '\n' '|' <<<"$out")"
  fi

  : >"$log"
  rc=0
  out=$(LS_FAIL=1 run_pull) || rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "a failing compose ls fails the step instead of pulling nothing"
  else
    fail "compose ls failure was swallowed"
  fi

  rm -rf "$stubdir"
}

test_topgrade_config() {
  section "topgrade config"

  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi
  if ! command -v topgrade &>/dev/null; then
    fail "topgrade not installed"
    return
  fi

  local config="${XDG_CONFIG_HOME:-$HOME/.config}/topgrade.toml"
  if [[ -f "$config" ]]; then
    pass "topgrade config exists"
  else
    fail "topgrade config not found at $config (run \`chezmoi apply\`)"
    return
  fi

  # Check behavior, not syntax: topgrade treats invalid TOML or an unknown key
  # as no config at all, which would bring back `chezmoi update` and pulls of
  # every local image tag.
  local dry
  dry="$(topgrade --dry-run --no-self-update --notify-end never --config "$config" 2>&1 </dev/null || true)"
  if grep -qE 'chezmoi update|docker pull' <<<"$dry"; then
    fail "dry run would run a disabled step (config ignored?)"
  else
    pass "dry run runs neither chezmoi update nor docker pull"
  fi
  if grep -q 'dotfiles-drift' <<<"$dry" && grep -q 'docker-pull-compose' <<<"$dry" \
    && grep -q 'upgrade-strategy eager' <<<"$dry"; then
    pass "dry run includes the drift, compose-pull, and eager pipx commands"
  else
    fail "dry run is missing a replacement command"
  fi
}

test_update_alias() {
  section "update alias"

  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi

  if zsh_check 'alias update 2>/dev/null | grep -q topgrade'; then
    pass "update runs topgrade"
  else
    fail "update alias doesn't run topgrade"
  fi

  if zsh_check 'alias brewup &>/dev/null'; then
    fail "brewup alias still defined (topgrade's brew step replaces it)"
  else
    pass "brewup alias removed"
  fi
}
