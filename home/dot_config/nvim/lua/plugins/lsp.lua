-- LSP: attach keymaps, server configuration, mason tool installation, and
-- C# via roslyn.nvim.

local gh = require('util').gh

-- [[ LSP Configuration ]]
-- Brief aside: **What is LSP?**
--
-- LSP is an initialism you've probably heard, but might not understand what it is.
--
-- LSP stands for Language Server Protocol. It's a protocol that helps editors
-- and language tooling communicate in a standardized fashion.
--
-- In general, you have a "server" which is some tool built to understand a particular
-- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
-- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
-- processes that communicate with some "client" - in this case, Neovim!
--
-- LSP provides Neovim with features like:
--  - Go to definition
--  - Find references
--  - Autocompletion
--  - Symbol Search
--  - and more!
--
-- Thus, Language Servers are external tools that must be installed separately from
-- Neovim. This is where `mason` and related plugins come into play.
--
-- If you're wondering about lsp vs treesitter, you can check out the wonderfully
-- and elegantly composed help section, `:help lsp-vs-treesitter`

-- Useful status updates for LSP.
vim.pack.add { gh 'j-hui/fidget.nvim' }
require('fidget').setup {}

--  This function gets run when an LSP attaches to a particular buffer.
--    That is to say, every time a new file is opened that is associated with
--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
--    function will be executed to configure the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    -- NOTE: Remember that Lua is a real programming language, and as such it is possible
    -- to define small helper and utility functions so you don't have to repeat yourself.
    --
    -- In this case, we create a function that lets us more easily define mappings specific
    -- for LSP related items. It sets the mode, buffer and description for us each time.
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Rename the variable under your cursor.
    --  Most Language Servers support renaming across files, etc.
    map('grn', vim.lsp.buf.rename, 'Re[n]ame')

    -- Execute a code action, usually your cursor needs to be on top of an error
    -- or a suggestion from your LSP for this to activate.
    map('gra', vim.lsp.buf.code_action, 'Code [a]ction', { 'n', 'x' })

    -- WARN: This is not Goto Definition, this is Goto Declaration.
    --  For example, in C this would take you to the header.
    map('grD', vim.lsp.buf.declaration, 'Goto [D]eclaration')

    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    See `:help CursorHold` for information about when this is executed
    --
    -- When you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method('textDocument/documentHighlight', event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end
  end,
})

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--  See `:help lsp-config` for information about keys and how to configure
---@type table<string, vim.lsp.Config>
local servers = {
  -- clangd = {},
  -- gopls = {},
  -- pyright = {},
  -- rust_analyzer = {},
  --
  -- Some languages (like typescript) have entire language plugins that can be useful:
  --    https://github.com/pmizio/typescript-tools.nvim
  --
  -- But for many setups, the LSP (`ts_ls`) will work just fine
  -- ts_ls = {},

  stylua = {}, -- Used to format Lua code

  -- Special Lua Config, as recommended by neovim help docs
  lua_ls = {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if
          path ~= vim.fn.stdpath 'config'
          and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
        then
          return
        end
      end

      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = {
          version = 'LuaJIT',
          path = { 'lua/?.lua', 'lua/?/init.lua' },
        },
        workspace = {
          checkThirdParty = false,
          -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
          --  See https://github.com/neovim/nvim-lspconfig/issues/3189
          library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
            '${3rd}/luv/library',
            '${3rd}/busted/library',
          }),
        },
      })
    end,
    ---@type lspconfig.settings.lua_ls
    settings = {
      Lua = {
        format = { enable = false }, -- Disable formatting (formatting is done by stylua)
      },
    },
  },

  -- Python: basedpyright for types, ruff for lint (+ format via conform)
  basedpyright = {
    settings = {
      -- Open files only, matching VS Code (Pylance defaults the same and
      -- none of the repos override it). Whole-repo checking is CI's job.
      -- Also sidesteps basedpyright 1.39's empty workspace/diagnostic pulls.
      basedpyright = { analysis = { diagnosticMode = 'openFilesOnly' } },
    },
  },
  -- ruff owns lint and import-sorting; basedpyright owns hover (its is
  -- richer: types, signatures, docstrings). Disable ruff's hover so K always
  -- hits basedpyright rather than ruff's minimal noqa/rule popup.
  ruff = {
    on_init = function(client)
      client.server_capabilities.hoverProvider = false
    end,
  },
  -- PHP
  intelephense = {},
  -- Shell (bash/sh; zsh has no language server)
  bashls = {},
  -- Config files
  yamlls = {},
  jsonls = {},
  taplo = {},
  -- Tailwind class completion (invoicing, elenkis app). classFunctions
  -- extends completion/hover/linting into the class-builder helpers.
  -- Scoped root_dir: lspconfig falls back to .git, which attaches the
  -- server in every repo (e.g. tack, a Laravel/SCSS repo with no Tailwind);
  -- require a real Tailwind signal instead.
  tailwindcss = {
    root_dir = function(bufnr, on_dir)
      local root = require('project').tailwind_root(bufnr)
      if root then
        on_dir(root)
      end
    end,
    settings = {
      tailwindCSS = {
        classFunctions = { 'cva', 'cx', 'clsx', 'cn' },
      },
    },
  },
  -- Azure infra-as-code (elenkis infra/). cmd set explicitly: the
  -- lspconfig default ships none, and mason-lspconfig's shim only applies
  -- via its setup(), which this config doesn't use.
  bicep = { cmd = { 'bicep-lsp' } },
  -- CSS/SCSS: completion/hover only — validation off (stylelint via
  -- nvim-lint is the linter, matching the repos' .vscode settings).
  cssls = {
    settings = {
      css = { validate = false },
      scss = { validate = false },
      less = { validate = false },
    },
  },
  -- Markdown navigation (markdownlint comes later via nvim-lint)
  marksman = {},

  -- TypeScript / JavaScript / React + the Vue SFC <script> layer (vtsls).
  -- The @vue/typescript-plugin gives Vue files TS support in hybrid mode.
  vtsls = {
    filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
    settings = {
      vtsls = {
        tsserver = {
          globalPlugins = {
            {
              name = '@vue/typescript-plugin',
              location = vim.fn.stdpath 'data' .. '/mason/packages/vue-language-server/node_modules/@vue/language-server',
              languages = { 'vue' },
              configNamespace = 'typescript',
            },
          },
        },
      },
    },
  },
  -- Vue templates/styles (Volar v3, hybrid mode — vtsls handles the script layer)
  vue_ls = {},
  -- ESLint diagnostics (reads the repo's flat or legacy eslint config)
  eslint = {},
}

vim.pack.add {
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
}

-- Automatically install LSPs and related tools to stdpath for Neovim
require('mason').setup {
  -- Crashdummyy registry provides roslyn-language-server (for roslyn.nvim).
  registries = {
    'github:mason-org/mason-registry',
    'github:Crashdummyy/mason-registry',
  },
}

-- Ensure the servers and tools above are installed
--
-- To check the current status of installed tools and/or manually install
-- other tools, you can run
--    :Mason
--
-- You can press `g?` for help in this menu.
local ensure_installed = vim.tbl_keys(servers or {})
vim.list_extend(ensure_installed, {
  'roslyn-language-server', -- C# server for roslyn.nvim (Crashdummyy registry)
  -- Formatters for conform (stylua/ruff/taplo already installed as servers/tools)
  'prettier',
  'shfmt',
  'pint',
  -- Linters with no LSP (run via nvim-lint, reading the repo's config)
  'markdownlint-cli2',
  'stylelint',
  'actionlint',
  -- Python bridge tools for repos not yet migrated to ruff/basedpyright
  'black',
  'isort',
  'mypy',
})

require('mason-tool-installer').setup { ensure_installed = ensure_installed }

for name, server in pairs(servers) do
  vim.lsp.config(name, server)
  vim.lsp.enable(name)
end

-- C# via roslyn.nvim — the Roslyn LSP (same engine as VS Code's C# Dev Kit).
-- Attaches on .sln/.csproj; server installed from mason (Crashdummyy registry).
vim.pack.add { gh 'seblyng/roslyn.nvim' }
require('roslyn').setup {}
-- Whole-solution diagnostics so problems from unopened C# files show in Trouble.
vim.lsp.config('roslyn', {
  settings = {
    ['csharp|background_analysis'] = {
      dotnet_analyzer_diagnostics_scope = 'fullSolution',
      dotnet_compiler_diagnostics_scope = 'fullSolution',
    },
  },
})
