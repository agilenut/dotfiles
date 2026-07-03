#!/usr/bin/env bash
# nvim project-aware tooling tests (lua/project.lua + conform wiring)
# shellcheck shell=bash

# Asserts the resolution LOGIC (which formatters, which roots, which
# binary). Hermetic: every tool the cases resolve is a fake executable
# seeded inside the fixtures (conform drops formatters whose binary
# isn't executable, so real tools would make results depend on mason).
# Assertions live in nvim-tooling-asserts.lua, which emits 'case=value'
# lines to a results file — nvim's own output is diagnostics only.

test_nvim_tooling() {
  section "nvim Project Tooling"

  if ! command -v nvim &>/dev/null; then
    skip "nvim not installed"
    return
  fi
  if [ ! -f "${HOME}/.config/nvim/lua/project.lua" ]; then
    skip_with_followup "nvim project.lua not installed" \
      "Run 'chezmoi apply' to install the nvim config"
    return
  fi
  if [ ! -f "$LIB_DIR/nvim-tooling-asserts.lua" ]; then
    fail "nvim-tooling-asserts.lua missing from $LIB_DIR"
    return
  fi

  # Install the cleanup trap BEFORE mktemp so a set -e abort can't leak
  # the fixture dir (same pattern as worktree.sh).
  local fixtures=""
  nvim_tooling_cleanup() {
    [ -n "$fixtures" ] && rm -rf "$fixtures"
  }
  trap nvim_tooling_cleanup EXIT
  fixtures="$(mktemp -d)"
  # Canonicalize: nvim reports resolved paths (/var → /private/var on macOS).
  fixtures="$(cd "$fixtures" && pwd -P)"

  make_fake_bin() {
    mkdir -p "$(dirname "$1")"
    printf '#!/bin/sh\nexit 0\n' >"$1"
    chmod +x "$1"
  }

  # --- fixtures: one dir per resolution case -------------------------------
  mkdir -p "$fixtures/ruff-repo" "$fixtures/ruff-subtable-repo" \
    "$fixtures/ruffian-repo" "$fixtures/rufftoml-repo/blackpkg" \
    "$fixtures/black-repo" "$fixtures/black-isort-repo" \
    "$fixtures/isort-cfg-repo" "$fixtures/mono/blackpkg" \
    "$fixtures/mypy-mono/subpkg" "$fixtures/bin-repo/sub" \
    "$fixtures/stylelint-repo" "$fixtures/plain"

  printf '[tool.ruff]\n' >"$fixtures/ruff-repo/pyproject.toml"
  # Subtable form must count as the tool being declared.
  printf '[tool.ruff.lint]\n' >"$fixtures/ruff-subtable-repo/pyproject.toml"
  # Prefix false-positive guard: [tool.ruffian] is NOT ruff → black wins.
  printf '[tool.ruffian]\n[tool.black]\n' >"$fixtures/ruffian-repo/pyproject.toml"
  # File-based ruff config: same-depth tie with black keeps ruff; a nearer
  # black subpackage still wins.
  printf '' >"$fixtures/rufftoml-repo/ruff.toml"
  printf '[tool.black]\n' >"$fixtures/rufftoml-repo/pyproject.toml"
  printf '[tool.black]\n' >"$fixtures/rufftoml-repo/blackpkg/pyproject.toml"
  printf '[tool.black]\n' >"$fixtures/black-repo/pyproject.toml"
  printf '[tool.black]\n[tool.isort]\n' >"$fixtures/black-isort-repo/pyproject.toml"
  # isort gate via its config FILE (not a pyproject table).
  printf '[tool.black]\n' >"$fixtures/isort-cfg-repo/pyproject.toml"
  printf '[settings]\n' >"$fixtures/isort-cfg-repo/.isort.cfg"
  # Monorepo: ruff at the root, a subpackage still pinned to black.
  printf '[tool.ruff]\n' >"$fixtures/mono/pyproject.toml"
  printf '[tool.black]\n' >"$fixtures/mono/blackpkg/pyproject.toml"
  # Monorepo: [tool.mypy] at the root, nearer pyproject without it.
  printf '[tool.mypy]\n' >"$fixtures/mypy-mono/pyproject.toml"
  printf '[tool.pytest.ini_options]\n' >"$fixtures/mypy-mono/subpkg/pyproject.toml"
  printf '{}\n' >"$fixtures/stylelint-repo/.stylelintrc.json"

  # Fake tool binaries so formatter availability is fixture-local.
  local repo
  for repo in ruff-repo ruff-subtable-repo rufftoml-repo mono plain; do
    make_fake_bin "$fixtures/$repo/.venv/bin/ruff"
  done
  for repo in ruffian-repo rufftoml-repo black-repo black-isort-repo isort-cfg-repo mono; do
    make_fake_bin "$fixtures/$repo/.venv/bin/black"
  done
  make_fake_bin "$fixtures/ruffian-repo/.venv/bin/ruff"
  make_fake_bin "$fixtures/black-isort-repo/.venv/bin/isort"
  make_fake_bin "$fixtures/isort-cfg-repo/.venv/bin/isort"
  # local_bin pin dirs + nvim-lint cmd routing.
  make_fake_bin "$fixtures/bin-repo/node_modules/.bin/zzz-tool"
  make_fake_bin "$fixtures/bin-repo/vendor/bin/zzz-pint"
  make_fake_bin "$fixtures/bin-repo/.venv/bin/zzz-venv"
  make_fake_bin "$fixtures/bin-repo/node_modules/.bin/markdownlint-cli2"
  # conform's stylelint condition gate (builtins prefer node_modules/.bin).
  make_fake_bin "$fixtures/stylelint-repo/node_modules/.bin/stylelint"
  make_fake_bin "$fixtures/stylelint-repo/node_modules/.bin/prettier"
  make_fake_bin "$fixtures/plain/node_modules/.bin/prettier"

  cp "$LIB_DIR/nvim-tooling-asserts.lua" "$fixtures/asserts.lua"

  # </dev/null: a blocking prompt in headless nvim must fail, not hang.
  local nvim_out
  nvim_out="$(NVIM_TOOLING_FIXTURES="$fixtures" nvim --headless \
    "+lua dofile(os.getenv('NVIM_TOOLING_FIXTURES') .. '/asserts.lua')" \
    +qa! </dev/null 2>&1 || true)"

  if [ ! -s "$fixtures/results" ]; then
    fail "nvim emitted no results — output: $(printf '%s' "$nvim_out" | head -c 300)"
    nvim_tooling_cleanup
    trap - EXIT
    return
  fi
  if grep -q '^lua_error=' "$fixtures/results"; then
    fail "asserts.lua errored: $(grep '^lua_error=' "$fixtures/results" | head -1 | cut -d= -f2-)"
  fi

  assert_nvim_case() {
    local case="$1" expected="$2"
    local actual
    actual="$(grep "^${case}=" "$fixtures/results" | head -1 | cut -d= -f2- || true)"
    if [[ "$actual" == "$expected" ]]; then
      pass "nvim tooling: $case = $expected"
    else
      fail "nvim tooling: $case expected '$expected' got '${actual:-<missing>}'"
    fi
  }

  assert_nvim_case ruff_repo 'ruff_organize_imports,ruff_format'
  assert_nvim_case ruff_subtable 'ruff_organize_imports,ruff_format'
  assert_nvim_case ruffian_negative 'black'
  assert_nvim_case rufftoml_tie 'ruff_organize_imports,ruff_format'
  assert_nvim_case rufftoml_nested_black 'black'
  assert_nvim_case black_repo 'black'
  assert_nvim_case black_isort_repo 'isort,black'
  assert_nvim_case isort_cfg_repo 'isort,black'
  assert_nvim_case mono_blackpkg 'black'
  assert_nvim_case mono_root 'ruff_organize_imports,ruff_format'
  assert_nvim_case plain_repo 'ruff_organize_imports,ruff_format'
  assert_nvim_case mypy_root "$fixtures/mypy-mono"
  assert_nvim_case local_bin "$fixtures/bin-repo/node_modules/.bin/zzz-tool"
  assert_nvim_case local_bin_vendor "$fixtures/bin-repo/vendor/bin/zzz-pint"
  assert_nvim_case local_bin_venv "$fixtures/bin-repo/.venv/bin/zzz-venv"
  assert_nvim_case local_bin_fallback 'zzz-absent'
  assert_nvim_case mdlint_cmd "$fixtures/bin-repo/node_modules/.bin/markdownlint-cli2"
  assert_nvim_case stylelint_gate_off 'false'
  assert_nvim_case stylelint_fmt_off 'prettier'
  assert_nvim_case stylelint_gate_on 'true'
  assert_nvim_case stylelint_fmt_on 'stylelint,prettier'

  nvim_tooling_cleanup
  trap - EXIT
}
