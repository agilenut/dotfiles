-- Project-aware tool resolution. Repos pin tool versions in local package
-- dirs; prefer that binary over the global mason install so nvim runs the
-- same version as the repo's pre-commit/CI.
local M = {}

-- Ancestor dirs (relative to the buffer's file) that hold pinned executables.
local bin_dirs = { 'node_modules/.bin', 'vendor/bin', '.venv/bin' }

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
