-- Linting (non-LSP): nvim-lint for linters with no language server
-- (markdownlint-cli2, stylelint, actionlint, mypy), config-gated per repo.

local gh = require('util').gh

vim.pack.add { gh 'mfussenegger/nvim-lint' }
local lint = require 'lint'
-- markdownlint-cli2 reads the repo's .markdownlint-cli2.* or .markdownlint.*,
-- so nvim's markdown diagnostics match pre-commit. LSP-backed languages
-- (eslint, ruff, etc.) don't need nvim-lint — their server reports diagnostics.
lint.linters_by_ft = {
  markdown = { 'markdownlint-cli2' },
  css = { 'stylelint' },
  scss = { 'stylelint' },
  yaml = { 'actionlint' },
  -- No pylint: ruff (LSP, always on) covers its PL rule family; enable
  -- more PL rules in a repo's ruff config rather than bridging pylint.
  python = { 'mypy' },
}

-- mypy resolves its config from cwd only (no upward walk). Run it from
-- the root of the config that satisfied the gate — a nearer unrelated
-- pyproject.toml must not steal the cwd from the declaring config.
local lint_cwd = {
  mypy = function()
    return require('project').mypy_root(0)
  end,
}

-- Per-linter run conditions beyond filetype and config gating: path
-- scoping, event scoping for slow linters, pyproject content gates.
-- Predicates live in project.lua so the <leader>bi buffer info reads the
-- same gates. basedpyright is the primary Python type checker; mypy is a
-- config-gated bridge for un-migrated repos (tool verdicts).
local lint_when = {
  actionlint = function()
    return require('project').in_workflows_dir(0)
  end,
  mypy = function(ev)
    -- Gate = "a mypy config resolves": same source as lint_cwd.mypy, so
    -- gate and spawn cwd can never disagree on markers.
    return ev.event == 'BufWritePost' -- slow, and lints the file on disk
      and lint_cwd.mypy() ~= nil
  end,
}

-- Mirror nvim-lint's ft resolution (exact match, else dotted-ft union) so
-- linters keep running if a runtime update makes workflows 'yaml.ghaction'.
local linters_for_ft = function(ft)
  local names = lint.linters_by_ft[ft]
  if names then
    return names
  end
  local seen = {}
  for _, part in ipairs(vim.split(ft, '.', { plain = true })) do
    for _, name in ipairs(lint.linters_by_ft[part] or {}) do
      seen[name] = true
    end
  end
  return vim.tbl_keys(seen)
end

-- Run the repo's pinned binary when one exists (mason fallback).
-- nvim-lint evaluates cmd with the linted buffer current, so bufnr 0 works.
for _, name in ipairs { 'markdownlint-cli2', 'stylelint', 'mypy' } do
  lint.linters[name].cmd = function()
    return require('project').local_bin(0, name)
  end
end

vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
  group = vim.api.nvim_create_augroup('nvim-lint', { clear = true }),
  callback = function(ev)
    if not vim.bo.modifiable then
      return
    end
    -- Linters with an entry in project.config_files are opt-in by config:
    -- they run only where that config exists (stylelint errors without one).
    -- lint_when adds non-config conditions (path/event scoping).
    local names = vim.tbl_filter(function(name)
      local project = require 'project'
      local configs = project.config_files[name]
      if configs and not project.has_config(0, configs) then
        return false
      end
      local when = lint_when[name]
      return not when or when(ev)
    end, linters_for_ft(vim.bo.filetype))
    -- Lint from the buffer's dir so stdin linters (markdownlint-cli2,
    -- stylelint) resolve their config from the file's location — matching
    -- pre-commit's per-file resolution — rather than nvim's cwd. Linters
    -- in lint_cwd override this with their own root.
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    local default_cwd = vim.uv.fs_stat(dir) and dir or nil
    for _, name in ipairs(names) do
      local cwd = lint_cwd[name] and lint_cwd[name]() or default_cwd
      lint.try_lint(name, { cwd = cwd })
    end
  end,
})
