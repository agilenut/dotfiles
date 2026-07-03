-- Headless-nvim assertions for the project-aware tooling tests.
-- Run by nvim-tooling.sh: copied into the fixture dir and dofile()d with
-- NVIM_TOOLING_FIXTURES set. Emits 'case=value' lines to the results file;
-- appends per call so a mid-run error still leaves completed cases behind.
local fixtures = os.getenv 'NVIM_TOOLING_FIXTURES'
local results_path = fixtures .. '/results'

local function emit(case, value)
  local f = assert(io.open(results_path, 'a'))
  f:write(case .. '=' .. tostring(value) .. '\n')
  f:close()
end

local function formatters_for(path)
  vim.cmd.edit(path)
  local names = {}
  for _, f in ipairs(require('conform').list_formatters(0)) do
    names[#names + 1] = f.name
  end
  return table.concat(names, ',')
end

local function main()
  local project = require 'project'

  -- conform python arbitration (fixtures seed fake tool binaries in
  -- .venv/bin, so availability never depends on mason)
  emit('ruff_repo', formatters_for(fixtures .. '/ruff-repo/x.py'))
  emit('ruff_subtable', formatters_for(fixtures .. '/ruff-subtable-repo/x.py'))
  emit('ruffian_negative', formatters_for(fixtures .. '/ruffian-repo/x.py'))
  emit('rufftoml_tie', formatters_for(fixtures .. '/rufftoml-repo/x.py'))
  emit('rufftoml_nested_black', formatters_for(fixtures .. '/rufftoml-repo/blackpkg/x.py'))
  emit('black_repo', formatters_for(fixtures .. '/black-repo/x.py'))
  emit('black_isort_repo', formatters_for(fixtures .. '/black-isort-repo/x.py'))
  emit('isort_cfg_repo', formatters_for(fixtures .. '/isort-cfg-repo/x.py'))
  emit('mono_blackpkg', formatters_for(fixtures .. '/mono/blackpkg/x.py'))
  emit('mono_root', formatters_for(fixtures .. '/mono/x.py'))
  emit('plain_repo', formatters_for(fixtures .. '/plain/x.py'))

  -- pyproject_tool_root walks past pyprojects that don't declare the tool
  vim.cmd.edit(fixtures .. '/mypy-mono/subpkg/x.py')
  emit('mypy_root', project.pyproject_tool_root(0, 'mypy'))

  -- local_bin: all three pin dirs, plus the PATH-name fallback
  vim.cmd.edit(fixtures .. '/bin-repo/sub/x.md')
  emit('local_bin', project.local_bin(0, 'zzz-tool'))
  emit('local_bin_vendor', project.local_bin(0, 'zzz-pint'))
  emit('local_bin_venv', project.local_bin(0, 'zzz-venv'))
  emit('local_bin_fallback', project.local_bin(0, 'zzz-absent'))

  -- nvim-lint cmd routing resolves the pinned binary for the current buffer
  emit('mdlint_cmd', require('lint').linters['markdownlint-cli2'].cmd())

  -- stylelint gate: project API and the conform condition that consumes it
  vim.cmd.edit(fixtures .. '/plain/x.scss')
  emit('stylelint_gate_off', project.has_config(0, project.config_files.stylelint))
  emit('stylelint_fmt_off', formatters_for(fixtures .. '/plain/x.scss'))
  vim.cmd.edit(fixtures .. '/stylelint-repo/x.scss')
  emit('stylelint_gate_on', project.has_config(0, project.config_files.stylelint))
  emit('stylelint_fmt_on', formatters_for(fixtures .. '/stylelint-repo/x.scss'))
end

local ok, err = pcall(main)
if not ok then
  emit('lua_error', err)
end
