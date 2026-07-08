-- UI / core UX plugins: guess-indent, tmux-navigator, devicons, gitsigns,
-- inline-diff, which-key. (colorscheme, diagnostics/trouble, and mini.nvim are
-- their own modules, loaded next in init.lua.)

local gh = require('util').gh

-- [[ Installing and Configuring Plugins ]]
--
-- To install a plugin simply call `vim.pack.add` with its git url.
-- This will download the default branch of the plugin, which will usually be `main` or `master`
-- You can also have more advanced specs, which we will talk about later.
--
-- For most plugins its not enough to install them, you also need to call their `.setup()` to start them.
--
-- For example, lets say we want to install `guess-indent.nvim` - a plugin for
-- automatically detecting and setting the indentation.
--
-- We first install it from https://github.com/NMAC427/guess-indent.nvim
-- and then call its `setup()` function to start it with default settings.
vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
require('guess-indent').setup {}

-- vim-tmux-navigator: Ctrl+hjkl moves between nvim splits AND tmux panes as one
-- grid (auto-maps <C-hjkl>). Matching bindings live in ~/.config/tmux/tmux.conf.
vim.pack.add { gh 'christoomey/vim-tmux-navigator' }

-- Because lua is a real programming language, you can also have some logic to your installation -
-- like only installing a plugin if a condition is met.
--
-- Here we only install `nvim-web-devicons` (which adds pretty icons) if we have a Nerd Font,
-- since otherwise the icons won't display properly.
if vim.g.have_nerd_font then
  vim.pack.add { gh 'nvim-tree/nvim-web-devicons' }
end

-- Here is a more advanced configuration example that passes options to `gitsigns.nvim`
--
-- See `:help gitsigns` to understand what each configuration key does.
-- Adds git related signs to the gutter, as well as utilities for managing changes
vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
require('gitsigns').setup {
  signs = {
    add = { text = '+' }, ---@diagnostic disable-line: missing-fields
    change = { text = '~' }, ---@diagnostic disable-line: missing-fields
    delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
    topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
    changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
  },
  on_attach = function(bufnr)
    local gs = require 'gitsigns'
    local function map(l, r, desc)
      vim.keymap.set('n', l, r, { buffer = bufnr, desc = desc })
    end
    -- Jump between changed hunks (staged + unstaged). Always gitsigns nav — no
    -- diff-mode special-case, so a stray `:diffthis` can't silently break it.
    map(']c', function()
      gs.nav_hunk('next', { target = 'all' })
    end, 'Next git [c]hange')
    map('[c', function()
      gs.nav_hunk('prev', { target = 'all' })
    end, 'Prev git [c]hange')
    -- Hunk staging from the editor (stage_hunk toggles stage/unstage). Bigger
    -- git ops live in lazygit (<space>gg); inline diffs are on <leader>gd.
    map('<leader>ghs', gs.stage_hunk, 'Hunk [s]tage/unstage')
    map('<leader>ghr', gs.reset_hunk, 'Hunk [r]eset (discard changes)')
    -- Capital = whole buffer: stage all, unstage all, reset all (discard).
    map('<leader>ghS', gs.stage_buffer, 'Buffer [S]tage all')
    map('<leader>ghU', gs.reset_buffer_index, 'Buffer [U]nstage all')
    map('<leader>ghR', gs.reset_buffer, 'Buffer [R]eset all (discard)')
    -- Blame: gb = popup with the full commit for the current line. The ambient
    -- line-blame toggle (gB) lives with the other toggles in the notifications section.
    map('<leader>gb', function()
      gs.blame_line { full = true }
    end, 'Git [b]lame line')
  end,
}

-- inline-diff.nvim — VSCode-style live word-level inline diff: added/removed/changed
-- shown inline as you type, with deleted lines. It derives colors from DiffAdd/
-- DiffDelete and auto-boosts the word emphasis. Visualization only; gitsigns still
-- owns signs, staging, blame, hunk nav.
vim.pack.add { gh 'cvlmtg/inline-diff.nvim' }
require('inline-diff').setup {}
-- inline-diff re-defines its highlights with a forced contrast fg on every enable,
-- which flattens treesitter colors. Strip that fg on the ADD groups (bg only) right
-- after toggling, so added/changed code keeps its syntax highlighting. Deleted text
-- is virtual text with no syntax, so it keeps the contrast fg.
local function inline_diff_keep_syntax()
  for _, g in ipairs { 'InlineDiffAdd', 'InlineDiffWordAdd' } do
    local hl = vim.api.nvim_get_hl(0, { name = g })
    if hl.bg then
      vim.api.nvim_set_hl(0, g, { bg = hl.bg })
    end
  end
end
vim.keymap.set('n', '<leader>gd', function()
  vim.cmd 'InlineDiff'
  inline_diff_keep_syntax()
end, { desc = 'Git [d]iff (inline toggle)' })

-- Useful plugin to show you pending keybinds.
vim.pack.add { gh 'folke/which-key.nvim' }
require('which-key').setup {
  -- Delay between pressing a key and opening which-key (milliseconds)
  delay = 0,
  -- rules = false drops the spotty auto per-key icons; only the explicit group
  -- icons in `spec` below render (mappings must stay true or ALL icons vanish).
  icons = { mappings = true, rules = false },
  win = { border = 'rounded' }, -- which-key ignores the global winborder

  -- Keymap description convention: bracket ONLY the action key (the last key in
  -- the sequence), in its real case — `Git [b]lame line` (press b), `Buffer
  -- [S]tage all` (Shift+S). Group words stay plain/unbracketed as searchable
  -- context (so `<leader>sk` "git" finds git cmds); keys with no matching letter
  -- (x, gr) get no bracket. Icons live on groups only (icons.rules = false above),
  -- except the toggles, which carry a live state icon (green switch on / grey
  -- off) registered alongside their dynamic Enable/Disable label.
  -- Document existing key chains
  spec = {
    { '<leader>b', group = '[b]uffer' },
    { '<leader><Tab>', group = 'tabs', icon = { icon = '\u{f0db}', color = 'cyan' } },
    { '<leader>S', group = '[S]ession', icon = { icon = '\u{f0c7}', color = 'green' } },
    { '<leader>s', group = '[s]earch', icon = { icon = '', color = 'cyan' }, mode = { 'n', 'v' } },
    { '<leader>t', group = '[t]oggle', icon = { icon = '', color = 'yellow' } },
    { '<leader>g', group = '[g]it', icon = { cat = 'filetype', name = 'git' } },
    { '<leader>gh', group = 'Git [h]unk', icon = { icon = '', color = 'orange' } },
    { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫', color = 'red' } },
    { 'gr', group = 'LSP Actions', icon = { icon = '', color = 'green' }, mode = { 'n' } },
  },
}
