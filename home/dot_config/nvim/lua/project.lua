-- Project-aware tool resolution. Repos pin tool versions in local package
-- dirs; prefer that binary over the global mason install so nvim runs the
-- same version as the repo's pre-commit/CI.
local M = {}

-- Ancestor dirs (relative to the buffer's file) that hold pinned executables.
local bin_dirs = { 'node_modules/.bin', 'vendor/bin', '.venv/bin' }

-- Config files that gate opt-in tools: a tool runs only where one of its
-- config files exists in an ancestor dir of the buffer's file. Filename
-- checks only — a config living INSIDE package.json (e.g. a "stylelint"
-- field) is not detected, and the tool silently stays off in such a repo.
M.config_files = {
  stylelint = {
    '.stylelintrc',
    '.stylelintrc.cjs',
    '.stylelintrc.js',
    '.stylelintrc.json',
    '.stylelintrc.mjs',
    '.stylelintrc.yaml',
    '.stylelintrc.yml',
    'stylelint.config.cjs',
    'stylelint.config.cts',
    'stylelint.config.js',
    'stylelint.config.mjs',
    'stylelint.config.mts',
    'stylelint.config.ts',
  },
}

---True when one of `names` exists in an ancestor dir of the buffer's file.
---@param bufnr integer
---@param names string[]
---@return boolean
function M.has_config(bufnr, names)
  return vim.fs.root(bufnr, names) ~= nil
end

---Dir of the nearest ancestor pyproject.toml declaring `[tool.<tool>]` (or a
---subtable like `[tool.ruff.lint]`), walking past pyprojects that don't
---declare it; nil when none does. Canonical header form only — quoted or
---whitespace-padded table headers are not recognized (false negatives keep
---the tool off, the safe direction).
---@param bufnr integer
---@param tool string
---@return string|nil
function M.pyproject_tool_root(bufnr, tool)
  local prefix = '[tool.' .. tool
  local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
  for _, path in ipairs(vim.fs.find('pyproject.toml', { upward = true, path = dirname, limit = math.huge })) do
    local ok, lines = pcall(vim.fn.readfile, path)
    if ok then
      for _, line in ipairs(lines) do
        local following = line:sub(#prefix + 1, #prefix + 1)
        if line:sub(1, #prefix) == prefix and (following == ']' or following == '.') then
          return vim.fs.dirname(path)
        end
      end
    end
  end
  return nil
end

---True when an ancestor pyproject.toml declares `[tool.<tool>]`.
---@param bufnr integer
---@param tool string
---@return boolean
function M.has_pyproject_tool(bufnr, tool)
  return M.pyproject_tool_root(bufnr, tool) ~= nil
end

---Root dir of the buffer's mypy config (mypy.ini/.mypy.ini, or the declaring
---pyproject.toml); nil when the repo has none. Doubles as mypy's run gate.
---@param bufnr integer
---@return string|nil
function M.mypy_root(bufnr)
  return vim.fs.root(bufnr, { 'mypy.ini', '.mypy.ini' }) or M.pyproject_tool_root(bufnr, 'mypy')
end

---True when the buffer's file sits DIRECTLY in .github/workflows/ —
---GitHub ignores subdirectories, so actionlint should too.
---@param bufnr integer
---@return boolean
function M.in_workflows_dir(bufnr)
  return vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)):find('/%.github/workflows$') ~= nil
end

---Resolve `name` to the buffer's project-local executable (searching upward
---from the file), falling back to plain `name` on PATH (mason).
---@param bufnr integer
---@param name string
---@return string
function M.local_bin(bufnr, name)
  local paths = {}
  for _, dir in ipairs(bin_dirs) do
    table.insert(paths, dir .. '/' .. name)
  end
  local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
  -- conform's finder walks parent dirs and checks executability; it reads
  -- only ctx.dirname, so a minimal ctx serves non-conform callers too.
  return require('conform.util').find_executable(paths, name)({}, { dirname = dirname })
end

return M
