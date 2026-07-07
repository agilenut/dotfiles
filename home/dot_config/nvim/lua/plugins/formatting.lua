-- Formatting: conform.nvim (format on save + <leader>f), routing python
-- formatters through the repo's pinned binaries.

local gh = require('util').gh

-- [[ Formatting ]]
vim.pack.add { gh 'stevearc/conform.nvim' }
-- conform's builtin prettier/pint/stylelint definitions already prefer the
-- repo's node_modules/.bin or vendor/bin binary. The python builtins run
-- bare commands, so route them through the repo's .venv pin (mason as
-- fallback).
local local_tool = function(name)
  return function(_, ctx)
    return require('project').local_bin(ctx.buf, name)
  end
end
require('conform').setup {
  notify_on_error = false,
  format_on_save = function()
    -- Format on save unless globally disabled via <leader>tf.
    if vim.g.disable_autoformat then
      return nil
    end
    return { timeout_ms = 1000, lsp_format = 'fallback' }
  end,
  default_format_opts = {
    -- Use the external formatter below if set; otherwise fall back to the LSP
    -- (e.g. C# via roslyn, which formats from .editorconfig).
    lsp_format = 'fallback',
  },
  -- External formatters run the same binaries as pre-commit, reading the repo's
  -- .editorconfig / .prettierrc / etc. Project-local installs are preferred.
  formatters_by_ft = {
    lua = { 'stylua' },
    -- Python: ruff is the formatter (tool verdicts); repos pinned to black
    -- with no ruff config (uperix) bridge to black until migrated. Between
    -- black and ruff the NEARER declaration wins (monorepo subpackages own
    -- their tooling); same depth keeps ruff. isort needs its own config —
    -- its defaults aren't black-compatible, and a repo that never
    -- configured it shouldn't get imports reordered.
    python = function(bufnr)
      local project = require 'project'
      local black_root = project.pyproject_tool_root(bufnr, 'black')
      local ruff_root = project.pyproject_tool_root(bufnr, 'ruff')
      local ruff_toml = vim.fs.root(bufnr, { 'ruff.toml', '.ruff.toml' })
      if ruff_toml and (not ruff_root or #ruff_toml > #ruff_root) then
        ruff_root = ruff_toml
      end
      if black_root and (not ruff_root or #black_root > #ruff_root) then
        if project.has_pyproject_tool(bufnr, 'isort') or project.has_config(bufnr, { '.isort.cfg' }) then
          return { 'isort', 'black' }
        end
        return { 'black' }
      end
      return { 'ruff_organize_imports', 'ruff_format' }
    end,
    javascript = { 'prettier' },
    javascriptreact = { 'prettier' },
    typescript = { 'prettier' },
    typescriptreact = { 'prettier' },
    vue = { 'prettier' },
    -- stylelint --fix first (skipped without a config), then prettier —
    -- mirrors the lint side so save-fixes match what pre-commit would do.
    css = { 'stylelint', 'prettier' },
    scss = { 'stylelint', 'prettier' },
    html = { 'prettier' },
    json = { 'prettier' },
    jsonc = { 'prettier' },
    yaml = { 'prettier' },
    markdown = { 'prettier' },
    sh = { 'shfmt' },
    bash = { 'shfmt' },
    toml = { 'taplo' },
    php = { 'pint' },
    -- C#: no entry — roslyn's editorconfig-based LSP formatting (lsp_format fallback).
  },
  formatters = {
    ruff_format = { command = local_tool 'ruff' },
    ruff_organize_imports = { command = local_tool 'ruff' },
    black = { command = local_tool 'black' },
    isort = { command = local_tool 'isort' },
    -- stylelint errors without a config; run it only where one exists.
    stylelint = {
      condition = function(_, ctx)
        local project = require 'project'
        return project.has_config(ctx.buf, project.config_files.stylelint)
      end,
    },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>f', function()
  require('conform').format { async = true }
end, { desc = '[f]ormat buffer' })
