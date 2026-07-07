--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

require 'config.foundation' -- options, keymaps, autocmds (sets <leader>; must run before plugins)
require 'pack' -- vim.pack build hooks (PackChanged autocmd)

-- GitHub URL helper shared by every plugin section (lua/util.lua).
local gh = require('util').gh

require 'plugins.ui' -- guess-indent, tmux-navigator, gitsigns, inline-diff, which-key, colorscheme, todo-comments, trouble, mini

require 'plugins.navigation' -- telescope + LSP pickers

-- ============================================================
-- SECTION 5: LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================
do
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
end

-- ============================================================
-- SECTION 6: FORMATTING
-- conform.nvim setup and keymap
-- ============================================================
do
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
end

-- ============================================================
-- SECTION 6b: LINTING (non-LSP)
-- nvim-lint for linters with no language server (e.g. markdownlint)
-- ============================================================
do
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
end

-- ============================================================
-- SECTION 6c: FILE EXPLORER
-- neo-tree — a VS Code-style tree with git status + diagnostic badges
-- ============================================================
do
  vim.pack.add {
    gh 'MunifTanjim/nui.nvim', -- plenary + devicons already added above
    gh 'nvim-neo-tree/neo-tree.nvim',
  }
  require('neo-tree').setup {
    close_if_last_window = true,
    window = {
      mappings = {
        ['<space>'] = 'none', -- free Space so <leader> maps work inside neo-tree
        ['l'] = 'open',
        ['h'] = 'close_node',
      },
    },
    default_component_configs = {
      -- Plain single-char git markers instead of cryptic/box glyphs.
      git_status = {
        symbols = {
          added = '+',
          modified = '~',
          deleted = '-',
          renamed = '»',
          untracked = '?',
          ignored = '◌',
          unstaged = '○',
          staged = '✓',
          conflict = '!',
        },
      },
    },
    filesystem = {
      follow_current_file = { enabled = true }, -- reveal the open file in the tree
      use_libuv_file_watcher = true, -- auto-refresh on external changes
      filtered_items = {
        hide_dotfiles = false, -- we edit dotfiles
        hide_gitignored = true,
      },
    },
    -- git status + diagnostic badges show on files by default.
  }
  -- neo-tree sets its own window bg on load; re-apply transparency (incl. the
  -- float preview) whenever a neo-tree buffer opens, so it matches other windows.
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'neo-tree',
    callback = function()
      for _, g in ipairs {
        'NeoTreeNormal',
        'NeoTreeNormalNC',
        'NeoTreeEndOfBuffer',
        'NeoTreeFloatNormal',
        'NeoTreeFloatBorder',
        'NeoTreePreview',
      } do
        vim.api.nvim_set_hl(0, g, { bg = 'none' })
      end
      -- Mute neo-tree's git marker/filename colors to the project palette.
      local palette = require 'theme_palette'
      local git = {
        NeoTreeGitAdded = palette.ui.git_add,
        NeoTreeGitStaged = palette.ui.git_add,
        NeoTreeGitModified = palette.ui.git_change,
        NeoTreeGitUnstaged = palette.ui.git_change,
        NeoTreeGitUntracked = palette.ui.git_untracked,
        NeoTreeGitConflict = palette.ui.git_conflict,
        NeoTreeGitDeleted = palette.ui.git_delete,
      }
      for g, c in pairs(git) do
        vim.api.nvim_set_hl(0, g, { fg = c })
      end
    end,
  })
  -- Reveal the current file when there is one; from a no-file buffer (e.g. the
  -- dashboard) reveal must be off, else follow_current_file tries to reveal the
  -- scratch buffer and prompts "change cwd to ministarter://…?".
  vim.keymap.set('n', '<leader>e', function()
    local file = vim.api.nvim_buf_get_name(0)
    local real = file ~= '' and vim.fn.filereadable(file) == 1
    vim.cmd(real and 'Neotree toggle reveal' or 'Neotree toggle reveal=false')
  end, { desc = '[e]xplorer (Neo-tree)' })
  -- Tree of only git-changed files, for navigating what changed.
  vim.keymap.set(
    'n',
    '<leader>ge',
    '<cmd>Neotree toggle source=git_status position=left<cr>',
    { desc = 'Git changed files ([e]xplorer)' }
  )

  -- neo-tree's git-status icons go stale when you stage/unstage (via gitsigns or
  -- lazygit): staging only touches .git/index, not the file, so neo-tree's libuv
  -- file watcher never sees it. Refresh neo-tree's git status when gitsigns reports
  -- an index change, debounced so frequent sign updates while typing don't thrash it.
  local nt_refresh_pending = false
  vim.api.nvim_create_autocmd('User', {
    pattern = 'GitSignsUpdate',
    callback = function()
      if nt_refresh_pending then
        return
      end
      nt_refresh_pending = true
      vim.defer_fn(function()
        nt_refresh_pending = false
        pcall(function()
          require('neo-tree.sources.manager').refresh 'filesystem'
        end)
      end, 300)
    end,
  })
end

-- ============================================================
-- SECTION 6d: MARKDOWN RENDERING
-- render-markdown — pretty in-buffer markdown; <leader>tm toggles raw vs rendered
-- ============================================================
do
  vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' } -- treesitter + icons already present
  require('render-markdown').setup {}
end

-- ============================================================
-- SECTION: notifications, unified toggles, buffer delete
-- ============================================================
do
  -- nvim-notify: route vim.notify through animated toasts (with history via
  -- :Notifications). Single-purpose; background_colour is pinned to the VS Code
  -- Dark editor bg because the theme runs transparent, so notify has no window
  -- background to read and blend against (change it if the theme changes).
  vim.pack.add { gh 'rcarriga/nvim-notify' }
  local notify = require 'notify'
  notify.setup {
    stages = 'fade',
    render = 'wrapped-compact',
    timeout = 3000,
    background_colour = require('theme_palette').ansi.background,
  }
  vim.notify = notify

  -- nvim-notify ships bright accent colors (green INFO, orange WARN, red ERROR)
  -- that ignore the theme. Link each level's border/title/icon to the matching
  -- (muted) Diagnostic* group so toasts read like the rest of the UI. Re-link on
  -- colorscheme change.
  local function theme_notify()
    local map = { INFO = 'Info', WARN = 'Warn', ERROR = 'Error', DEBUG = 'Hint', TRACE = 'Hint' }
    for level, diag in pairs(map) do
      for _, part in ipairs { 'Border', 'Title', 'Icon' } do
        vim.api.nvim_set_hl(0, 'Notify' .. level .. part, { link = 'Diagnostic' .. diag })
      end
    end
  end
  theme_notify()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = theme_notify })

  -- Toggle helper: flip the setting, announce it, and register a which-key entry
  -- whose label and icon track live state — "Disable" + green switch when on,
  -- "Enable" + grey switch when off. which-key re-runs the desc/icon functions
  -- on every popup open, so the row always reflects the current value.
  local TOGGLE_ON, TOGGLE_OFF = '', ''
  local function toggle(key, name, get, set)
    vim.keymap.set('n', key, function()
      local on = not get()
      set(on)
      vim.notify((on and 'Enabled ' or 'Disabled ') .. name)
    end, { desc = 'Toggle ' .. name })
    require('which-key').add {
      {
        key,
        desc = function()
          return (get() and 'Disable ' or 'Enable ') .. name
        end,
        icon = function()
          local on = get()
          -- Explicit 'grey' (not nil) for off: the base WhichKeyIcon fallback is underlined.
          return { icon = on and TOGGLE_ON or TOGGLE_OFF, color = on and 'green' or 'grey' }
        end,
      },
    }
  end

  -- Wrap a state read that reaches into a plugin's internals so a future refactor
  -- of that module can't throw inside which-key's render callback (which would
  -- blank the toggle popup). Core vim.* getters below don't need this.
  local function safe_get(fn)
    return function()
      local ok, v = pcall(fn)
      return ok and v or false
    end
  end

  toggle('<leader>th', 'inlay hints', function()
    return vim.lsp.inlay_hint.is_enabled { bufnr = 0 }
  end, function(s)
    vim.lsp.inlay_hint.enable(s, { bufnr = 0 })
  end)
  toggle('<leader>tx', 'diagnostic text', function()
    return vim.diagnostic.config().virtual_text ~= false
  end, function(s)
    vim.diagnostic.config { virtual_text = s }
  end)
  toggle(
    '<leader>tm',
    'markdown render',
    safe_get(function()
      return require('render-markdown.state').enabled
    end),
    function(s)
      vim.cmd('RenderMarkdown ' .. (s and 'enable' or 'disable'))
    end
  )
  toggle('<leader>tf', 'format on save', function()
    return not vim.g.disable_autoformat
  end, function(s)
    vim.g.disable_autoformat = not s
  end)
  toggle(
    '<leader>gB',
    'line blame',
    safe_get(function()
      return require('gitsigns.config').config.current_line_blame
    end),
    function(s)
      require('gitsigns').toggle_current_line_blame(s)
    end
  )

  -- Delete the current buffer while keeping the window/split layout: show the
  -- alternate (or another listed) buffer in its place, falling back to a fresh
  -- empty buffer only when nothing else is listed.
  local function buf_delete()
    local cur = vim.api.nvim_get_current_buf()
    if vim.bo[cur].modified then
      vim.notify('Buffer has unsaved changes; save or use :bd! first', vim.log.levels.WARN)
      return
    end
    local repl
    local alt = vim.fn.bufnr '#'
    if alt > 0 and alt ~= cur and vim.bo[alt].buflisted then
      repl = alt
    else
      for _, b in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
        if b.bufnr ~= cur then
          repl = b.bufnr
          break
        end
      end
    end
    if not repl then
      -- No other buffer left: land on the dashboard instead of a blank scratch.
      require('mini.starter').open()
      if vim.api.nvim_buf_is_valid(cur) then
        pcall(vim.api.nvim_buf_delete, cur, {})
      end
      return
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == cur then
        vim.api.nvim_win_set_buf(win, repl)
      end
    end
    if vim.api.nvim_buf_is_valid(cur) then
      pcall(vim.api.nvim_buf_delete, cur, {})
    end
  end
  vim.keymap.set('n', '<leader>bd', buf_delete, { desc = 'Buffer [d]elete' })

  -- Close every other listed buffer, keeping the current one. Skips buffers
  -- with unsaved changes (same guard as [d]elete) and reports how many.
  vim.keymap.set('n', '<leader>bo', function()
    local cur = vim.api.nvim_get_current_buf()
    local skipped = 0
    for _, b in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
      if b.bufnr ~= cur then
        if vim.bo[b.bufnr].modified then
          skipped = skipped + 1
        else
          pcall(vim.api.nvim_buf_delete, b.bufnr, {})
        end
      end
    end
    if skipped > 0 then
      vim.notify(skipped .. ' buffer(s) with unsaved changes kept', vim.log.levels.WARN)
    end
  end, { desc = 'Buffer close [o]thers' })

  -- Copy the buffer's path to the clipboard. bp = repo-relative (what
  -- pre-commit / lefthook --files expect); bP = absolute.
  local function copy_path(relative)
    local abs = vim.fn.expand '%:p'
    if abs == '' then
      vim.notify('No file for this buffer', vim.log.levels.WARN)
      return
    end
    local path = abs
    if relative then
      local root = vim.fs.root(0, '.git')
      path = root and abs:sub(#root + 2) or vim.fn.fnamemodify(abs, ':.')
    end
    vim.fn.setreg('+', path)
    vim.notify('Copied: ' .. path, vim.log.levels.INFO)
  end
  vim.keymap.set('n', '<leader>bp', function()
    copy_path(true)
  end, { desc = 'Copy [p]ath (repo-relative)' })
  vim.keymap.set('n', '<leader>bP', function()
    copy_path(false)
  end, { desc = 'Copy [P]ath (absolute)' })

  -- Tabs + per-tab cwd. Aimed at multi-repo folders (uperix's bare worktrees):
  -- give each tab its own repo via a tab-local cwd (:tcd), so git tools scope
  -- cleanly per tab. Nav with ]t / [t (gt / gT also work).
  vim.keymap.set('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
  vim.keymap.set('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Prev tab' })
  vim.keymap.set('n', '<leader><Tab>n', '<cmd>tabnew<cr>', { desc = 'Tab [n]ew' })
  vim.keymap.set('n', '<leader><Tab>x', '<cmd>tabclose<cr>', { desc = 'Tab close ([x])' })
  vim.keymap.set('n', '<leader><Tab>o', '<cmd>tabonly<cr>', { desc = 'Tab close [o]thers' })
  vim.keymap.set('n', '<leader><Tab>d', function()
    local root = vim.fs.root(0, '.git')
    if not root then
      vim.notify('No git repo for this buffer', vim.log.levels.WARN)
      return
    end
    vim.cmd('tcd ' .. vim.fn.fnameescape(root))
    vim.notify('tab cwd → ' .. vim.fn.fnamemodify(root, ':~'))
  end, { desc = "Tab cwd → this file's repo ([d]ir)" })
  vim.keymap.set('n', '<leader><Tab>r', function()
    local root = vim.fs.root(0, '.git')
    if not root then
      vim.notify('No git repo for this buffer', vim.log.levels.WARN)
      return
    end
    local file = vim.api.nvim_buf_get_name(0)
    vim.cmd('tabnew' .. (file ~= '' and ' ' .. vim.fn.fnameescape(file) or ''))
    vim.cmd('tcd ' .. vim.fn.fnameescape(root))
    vim.notify('repo tab: ' .. vim.fn.fnamemodify(root, ':t'))
  end, { desc = 'New [r]epo tab (file + tcd its root)' })

  -- File metadata dropped from the statusline (full path, type, encoding, size,
  -- attached LSP servers), plus the buffer's resolved formatters (with binary
  -- path — shows whether the repo's pin or mason won) and configured linters.
  -- Sticky toast: stays up until <leader>bi is pressed again.
  local buffer_info_open = false
  vim.keymap.set('n', '<leader>bi', function()
    if buffer_info_open then
      require('notify').dismiss { silent = true, pending = false }
      buffer_info_open = false
      return
    end
    local buf = 0
    local path = vim.api.nvim_buf_get_name(buf)
    local full = path ~= '' and vim.fn.fnamemodify(path, ':~') or '[No Name]'
    local enc = vim.bo[buf].fileencoding ~= '' and vim.bo[buf].fileencoding or vim.o.encoding
    local ft = vim.bo[buf].filetype
    local bytes = path ~= '' and vim.fn.getfsize(path) or -1
    local size
    if bytes < 0 then
      size = '(unsaved)'
    elseif bytes < 1024 then
      size = bytes .. ' B'
    elseif bytes < 1024 * 1024 then
      size = string.format('%.1f KB', bytes / 1024)
    else
      size = string.format('%.1f MB', bytes / (1024 * 1024))
    end
    local names = {}
    for _, c in ipairs(vim.lsp.get_clients { bufnr = buf }) do
      names[#names + 1] = c.name
    end
    -- Available formatters with their resolved binary, compacted to answer
    -- "which pin won": repo-relative for project pins, 'mason:' for mason
    -- installs, '(PATH)' for bare-name fallbacks.
    local mason_bin = vim.fn.stdpath 'data' .. '/mason/bin/'
    local repo_root = vim.fs.root(buf, '.git')
    local function short_cmd(cmd)
      if not cmd then
        return '?'
      end
      if not cmd:find('/', 1, true) then
        -- Bare name: resolve like the spawn would, to spot mason installs.
        local resolved = vim.fn.exepath(cmd)
        if resolved == '' then
          return cmd .. ' (not on PATH)'
        end
        cmd = resolved
      end
      if cmd:sub(1, #mason_bin) == mason_bin then
        return 'mason: ' .. cmd:sub(#mason_bin + 1)
      elseif repo_root and cmd:sub(1, #repo_root + 1) == repo_root .. '/' then
        return cmd:sub(#repo_root + 2)
      end
      return vim.fn.fnamemodify(cmd, ':~')
    end
    local formatters = {}
    for _, f in ipairs(require('conform').list_formatters(buf)) do
      formatters[#formatters + 1] = f.name .. ' → ' .. short_cmd(f.command)
    end
    -- Linters configured for the filetype, annotated with the same gates the
    -- lint autocmd reads (project.config_files / mypy_root / in_workflows_dir).
    local project = require 'project'
    local lint_off = {
      mypy = function()
        return project.mypy_root(buf) == nil and 'off: no config' or 'on save'
      end,
      actionlint = function()
        return not project.in_workflows_dir(buf) and 'off: not a workflow' or nil
      end,
    }
    local linters = {}
    for _, name in ipairs(require('lint').linters_by_ft[ft] or {}) do
      local note
      local configs = project.config_files[name]
      if configs and not project.has_config(buf, configs) then
        note = 'off: no config'
      elseif lint_off[name] then
        note = lint_off[name]()
      end
      -- Active linters resolve a binary the same way formatters do — show it.
      local entry = name
      if not (note and note:find '^off') then
        local cmd = require('lint').linters[name].cmd
        if type(cmd) == 'function' then
          cmd = cmd() -- evaluated with the info'd buffer current, like the autocmd
        end
        if type(cmd) == 'string' then
          entry = name .. ' → ' .. short_cmd(cmd)
        end
      end
      linters[#linters + 1] = note and (entry .. ' (' .. note .. ')') or entry
    end
    buffer_info_open = true
    vim.notify(
      table.concat({
        'Path:  ' .. full,
        'Type:  ' .. (ft ~= '' and ft or '(none)') .. '   ' .. enc .. '   ' .. vim.bo[buf].fileformat,
        'Size:  ' .. size,
        -- LSP diagnostics ARE linting (ruff, eslint, …); the CLI line is only
        -- the no-server tools nvim-lint spawns.
        'LSP:   ' .. (#names > 0 and table.concat(names, ', ') or '(none)'),
        'Format: ' .. (#formatters > 0 and table.concat(formatters, '\n        ') or '(lsp or none)'),
        'CLI lint: ' .. (#linters > 0 and table.concat(linters, '\n          ') or '(none)'),
      }, '\n'),
      vim.log.levels.INFO,
      { title = 'Buffer info', timeout = false }
    )
  end, { desc = 'Buffer [i]nfo (path, type, LSP, format, lint)' })
end

-- ============================================================
-- SECTION 7: AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================
do
  -- [[ Snippet Engine ]]

  -- NOTE: You can also specify plugin using a version range for its git tag.
  --  See `:help vim.version.range()` for more info
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {}

  -- `friendly-snippets` contains a variety of premade snippets.
  --    See the README about individual language/framework/plugin snippets:
  --    https://github.com/rafamadriz/friendly-snippets
  --
  -- vim.pack.add { gh 'rafamadriz/friendly-snippets' }
  -- require('luasnip.loaders.from_vscode').lazy_load()

  -- [[ Autocomplete Engine ]]
  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
  require('blink.cmp').setup {
    keymap = {
      -- 'default' (recommended) for mappings similar to built-in completions
      --   <c-y> to accept ([y]es) the completion.
      --    This will auto-import if your LSP supports it.
      --    This will expand snippets if the LSP sent a snippet.
      -- 'super-tab' for tab to accept
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- For an understanding of why the 'default' preset is recommended,
      -- you will need to read `:help ins-completion`
      --
      -- No, but seriously. Please read `:help ins-completion`, it is really good!
      --
      -- All presets have the following mappings:
      -- <tab>/<s-tab>: move to right/left of your snippet expansion
      -- <c-space>: Open menu or open docs if already open
      -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
      -- <c-e>: Hide menu
      -- <c-k>: Toggle signature help
      --
      -- See `:help blink-cmp-config-keymap` for defining your own keymap
      -- super-tab: <Tab> accepts the selected item (VS Code-like); <C-y> also
      -- still accepts. Tab stays context-aware — snippet-jump/indent otherwise.
      preset = 'super-tab',

      -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
      --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono',
    },

    completion = {
      -- By default, you may press `<c-space>` to show the documentation.
      -- Optionally, set `auto_show = true` to show the documentation after a delay.
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
    },

    snippets = { preset = 'luasnip' },

    -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
    -- which automatically downloads a prebuilt binary when enabled.
    --
    -- By default, we use the Lua implementation instead, but you may enable
    -- the rust implementation via `'prefer_rust_with_warning'`
    --
    -- See `:help blink-cmp-config-fuzzy` for more information
    fuzzy = { implementation = 'lua' },

    -- Shows a signature help window while you type arguments for a function
    signature = { enabled = true },
  }
end

-- ============================================================
-- SECTION 8: TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================
do
  -- [[ Configure Treesitter ]]
  --  Used to highlight, edit, and navigate code
  --
  --  See `:help nvim-treesitter-intro`

  -- NOTE: You can also specify a branch or a specific commit
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then
      return
    end
    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds
    -- For more info on folds see `:help folds`
    -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    -- vim.wo.foldmethod = 'expr'

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then
      vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then
        return
      end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function()
          treesitter_try_attach(buf, language)
        end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- SECTION 9: OPTIONAL EXAMPLES / NEXT STEPS
-- kickstart.plugins.* examples
-- ============================================================
do
  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug'
  -- require 'kickstart.plugins.indent_line'
  -- require 'kickstart.plugins.lint'
  -- require 'kickstart.plugins.autopairs'
  -- require 'kickstart.plugins.neo-tree'
  -- require 'kickstart.plugins.gitsigns' -- adds gitsigns recommended keymaps

  -- NOTE: You can add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  require 'custom.plugins'
end

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
