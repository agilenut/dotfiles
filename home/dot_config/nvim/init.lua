-- Neovim configuration, grown from kickstart.nvim
-- (https://github.com/nvim-lua/kickstart.nvim).
--
-- Plugins are managed with the built-in `vim.pack` (nvim 0.12+). Each module
-- below is side-effecting on require: it declares its plugins with
-- `vim.pack.add` and runs their setup at load. The requires run top-to-bottom
-- in dependency order — preserve the order when adding or moving modules.

require 'config.foundation' -- options, keymaps, autocmds (sets <leader>; must run before plugins)
require 'pack' -- vim.pack build hooks (PackChanged autocmd)

require 'plugins.ui' -- guess-indent, tmux-navigator, gitsigns, inline-diff, which-key
require 'plugins.colorscheme' -- vscode.nvim + palette-driven highlight fixes
require 'plugins.diagnostics' -- todo-comments, trouble (Problems panel)
require 'plugins.mini' -- mini.nvim: ai, surround, sessions, starter (dashboard), statusline
require 'plugins.navigation' -- telescope + LSP pickers
require 'plugins.lsp' -- fidget, LSP servers, mason, roslyn
require 'plugins.formatting' -- conform
require 'plugins.linting' -- nvim-lint
require 'plugins.explorer' -- neo-tree
require 'plugins.markdown' -- render-markdown
require 'plugins.notify' -- nvim-notify, unified toggles, buffer + tab helpers
require 'plugins.completion' -- LuaSnip + blink.cmp
require 'plugins.treesitter'

-- vim: ts=2 sts=2 sw=2 et
