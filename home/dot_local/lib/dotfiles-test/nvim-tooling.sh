#!/usr/bin/env bash
# nvim project-aware tooling tests (lua/project.lua + conform wiring)
# shellcheck shell=bash

# Asserts the resolution LOGIC (which formatters, which roots, which
# binary), not tool availability — so the tests hold on machines where
# mason hasn't installed the tools yet.

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

  local fixtures
  fixtures="$(mktemp -d)"
  # Canonicalize: nvim reports resolved paths (/var → /private/var on macOS).
  fixtures="$(cd "$fixtures" && pwd -P)"

  # --- fixtures: one dir per resolution case -------------------------------
  mkdir -p "$fixtures/ruff-repo" "$fixtures/black-repo" \
    "$fixtures/black-isort-repo" "$fixtures/mono/blackpkg" \
    "$fixtures/mypy-mono/subpkg" "$fixtures/bin-repo/node_modules/.bin" \
    "$fixtures/bin-repo/sub" "$fixtures/stylelint-repo" "$fixtures/plain"
  printf '[tool.ruff]\n' >"$fixtures/ruff-repo/pyproject.toml"
  printf '[tool.black]\n' >"$fixtures/black-repo/pyproject.toml"
  printf '[tool.black]\n[tool.isort]\n' >"$fixtures/black-isort-repo/pyproject.toml"
  # Monorepo: ruff at the root, a subpackage still pinned to black.
  printf '[tool.ruff]\n' >"$fixtures/mono/pyproject.toml"
  printf '[tool.black]\n' >"$fixtures/mono/blackpkg/pyproject.toml"
  # Monorepo: [tool.mypy] at the root, nearer pyproject without it.
  printf '[tool.mypy]\n' >"$fixtures/mypy-mono/pyproject.toml"
  printf '[tool.pytest.ini_options]\n' >"$fixtures/mypy-mono/subpkg/pyproject.toml"
  # Repo-pinned executable for local_bin.
  printf '#!/bin/sh\n' >"$fixtures/bin-repo/node_modules/.bin/zzz-tool"
  chmod +x "$fixtures/bin-repo/node_modules/.bin/zzz-tool"
  printf '{}\n' >"$fixtures/stylelint-repo/.stylelintrc.json"

  cat >"$fixtures/asserts.lua" <<'LUA'
local fixtures = os.getenv('NVIM_TOOLING_FIXTURES')
local project = require 'project'
local function emit(case, value)
  io.stdout:write(case .. '=' .. tostring(value) .. '\n')
end
local function formatters_for(path)
  vim.cmd.edit(path)
  local names = {}
  for _, f in ipairs(require('conform').list_formatters(0)) do
    names[#names + 1] = f.name
  end
  return table.concat(names, ',')
end
-- conform python arbitration
emit('ruff_repo', formatters_for(fixtures .. '/ruff-repo/x.py'))
emit('black_repo', formatters_for(fixtures .. '/black-repo/x.py'))
emit('black_isort_repo', formatters_for(fixtures .. '/black-isort-repo/x.py'))
emit('mono_blackpkg', formatters_for(fixtures .. '/mono/blackpkg/x.py'))
emit('mono_root', formatters_for(fixtures .. '/mono/x.py'))
emit('plain_repo', formatters_for(fixtures .. '/plain/x.py'))
-- pyproject_tool_root walks past pyprojects that don't declare the tool
vim.cmd.edit(fixtures .. '/mypy-mono/subpkg/x.py')
emit('mypy_root', project.pyproject_tool_root(0, 'mypy'))
-- local_bin prefers the repo-pinned executable, falls back to PATH name
vim.cmd.edit(fixtures .. '/bin-repo/sub/x.md')
emit('local_bin', project.local_bin(0, 'zzz-tool'))
emit('local_bin_fallback', project.local_bin(0, 'zzz-absent'))
-- stylelint config gate
vim.cmd.edit(fixtures .. '/plain/x.scss')
emit('stylelint_gate_off', project.has_config(0, project.config_files.stylelint))
vim.cmd.edit(fixtures .. '/stylelint-repo/x.scss')
emit('stylelint_gate_on', project.has_config(0, project.config_files.stylelint))
LUA

  local out
  out="$(NVIM_TOOLING_FIXTURES="$fixtures" nvim --headless \
    "+lua dofile(os.getenv('NVIM_TOOLING_FIXTURES') .. '/asserts.lua')" \
    +qa! 2>&1)" || true

  assert_nvim_case() {
    local case="$1" expected="$2"
    local actual
    actual="$(printf '%s\n' "$out" | grep "^${case}=" | head -1 | cut -d= -f2-)"
    if [[ "$actual" == "$expected" ]]; then
      pass "nvim tooling: $case = $expected"
    else
      fail "nvim tooling: $case expected '$expected' got '${actual:-<missing>}'"
    fi
  }

  assert_nvim_case ruff_repo 'ruff_organize_imports,ruff_format'
  assert_nvim_case black_repo 'black'
  assert_nvim_case black_isort_repo 'isort,black'
  assert_nvim_case mono_blackpkg 'black'
  assert_nvim_case mono_root 'ruff_organize_imports,ruff_format'
  assert_nvim_case plain_repo 'ruff_organize_imports,ruff_format'
  assert_nvim_case mypy_root "$fixtures/mypy-mono"
  assert_nvim_case local_bin "$fixtures/bin-repo/node_modules/.bin/zzz-tool"
  assert_nvim_case local_bin_fallback 'zzz-absent'
  assert_nvim_case stylelint_gate_off 'false'
  assert_nvim_case stylelint_gate_on 'true'

  rm -rf "$fixtures"
}
