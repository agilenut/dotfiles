-- File explorer: neo-tree — a VS Code-style tree with git status +
-- diagnostic badges.

local gh = require('util').gh

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
