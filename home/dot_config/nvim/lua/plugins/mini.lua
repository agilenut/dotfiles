-- mini.nvim modules: ai (textobjects), surround, sessions (+ neo-tree hooks),
-- starter (dashboard with git-status footer), statusline (custom content).
-- Loaded after plugins.ui so nvim-web-devicons (added there) is available.

local gh = require('util').gh

-- [[ mini.nvim ]]
--  A collection of various small independent plugins/modules
vim.pack.add { gh 'nvim-mini/mini.nvim' }

-- Better Around/Inside textobjects
--
-- Examples:
--  - va)  - [V]isually select [A]round [)]paren
--  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
--  - ci'  - [C]hange [I]nside [']quote
require('mini.ai').setup {
  -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
  mappings = {
    around_next = 'aa',
    inside_next = 'ii',
  },
  n_lines = 500,
}

-- Add/delete/replace surroundings (brackets, quotes, etc.)
--
-- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
-- - sd'   - [S]urround [D]elete [']quotes
-- - sr)'  - [S]urround [R]eplace [)] [']
require('mini.surround').setup()

-- Sessions: save/restore a project's open buffers + layout. Saved sessions
-- surface on the dashboard (see items below); autowrite keeps the active
-- one current on exit. autoread stays off so a fresh nvim lands on the
-- dashboard rather than silently restoring.
local session_dir = vim.fn.stdpath 'data' .. '/sessions'
vim.fn.mkdir(session_dir, 'p')
-- Don't persist empty windows; close neo-tree before a write since its
-- special buffer restores blank/broken from a saved session.
vim.opt.sessionoptions:remove 'blank'
-- Close neo-tree for the write (its special buffer restores blank), then
-- reopen it after so a manual save doesn't disturb the current view.
local neotree_reopen = false
local function neotree_is_open()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'neo-tree' then
      return true
    end
  end
  return false
end
require('mini.sessions').setup {
  autowrite = true,
  directory = session_dir,
  hooks = {
    pre = {
      write = function()
        neotree_reopen = neotree_is_open()
        pcall(vim.cmd, 'Neotree close')
      end,
      -- Close neo-tree before a restore too: it holds nui.input window
      -- handles the restore invalidates, which crash a scheduled
      -- nvim_set_current_win. Unmounting neo-tree first clears them.
      read = function()
        pcall(vim.cmd, 'Neotree close')
      end,
    },
    post = {
      write = function()
        if neotree_reopen then
          pcall(vim.cmd, 'Neotree show')
        end
      end,
    },
  },
}
local function project_session()
  return vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
end
vim.keymap.set('n', '<leader>Ss', function()
  require('mini.sessions').write(project_session())
  vim.notify('Session saved: ' .. project_session())
end, { desc = 'Session [s]ave (project)' })
vim.keymap.set('n', '<leader>Sl', function()
  require('mini.sessions').select 'read'
end, { desc = 'Session [l]oad' })
vim.keymap.set('n', '<leader>Sd', function()
  require('mini.sessions').select 'delete'
end, { desc = 'Session [d]elete' })

-- Start screen (dashboard). Auto-opens on `nvim` with no file; buf_delete
-- also lands here when the last buffer closes. Type to filter items,
-- <Up>/<Down> (or <C-n>/<C-p>) to move, <CR> to activate.
local starter = require 'mini.starter'
-- Footer: git status for the launch dir's repo — branch, ahead/behind vs
-- upstream, dirty-file count. Empty (hidden) outside a repo. Runs on each
-- dashboard open, so it reflects the current state.
local function git_status()
  local cwd = vim.fn.getcwd()
  -- --no-optional-locks: never take .git/index.lock for the status refresh
  -- (would collide with a concurrent commit). Belt-and-suspenders with the
  -- global GIT_OPTIONAL_LOCKS=0 this config already sets.
  local function git(...)
    local res = vim.fn.systemlist { 'git', '--no-optional-locks', '-C', cwd, ... }
    return vim.v.shell_error == 0 and res or nil
  end
  local branch = git('branch', '--show-current')
  if not branch or not branch[1] or branch[1] == '' then
    return ''
  end
  local parts = { '  ' .. branch[1] }
  local ab = git('rev-list', '--left-right', '--count', 'HEAD...@{upstream}')
  if ab and ab[1] then
    local ahead, behind = ab[1]:match '(%d+)%s+(%d+)'
    if ahead and not (ahead == '0' and behind == '0') then
      parts[#parts + 1] = '↑' .. ahead .. ' ↓' .. behind
    end
  end
  -- posh-git style: staged (index) | unstaged (worktree), each as
  -- +added ~modified -deleted, then !untracked. Porcelain XY = X:index,
  -- Y:worktree. Shown only when the tree is dirty.
  local staged, unstaged, untracked = { a = 0, m = 0, d = 0 }, { a = 0, m = 0, d = 0 }, 0
  local function bump(t, code)
    if code == 'A' then
      t.a = t.a + 1
    elseif code == 'D' then
      t.d = t.d + 1
    elseif code ~= ' ' then
      t.m = t.m + 1 -- M, R, C, U, T
    end
  end
  for _, line in ipairs(git('status', '--porcelain') or {}) do
    if line:sub(1, 2) == '??' then
      untracked = untracked + 1
    else
      bump(staged, line:sub(1, 1))
      bump(unstaged, line:sub(2, 2))
    end
  end
  if staged.a + staged.m + staged.d + unstaged.a + unstaged.m + unstaged.d + untracked > 0 then
    local seg = string.format('+%d ~%d -%d | +%d ~%d -%d', staged.a, staged.m, staged.d, unstaged.a, unstaged.m, unstaged.d)
    if untracked > 0 then
      seg = seg .. ' !' .. untracked
    end
    parts[#parts + 1] = seg
  end
  return table.concat(parts, '   ')
end

-- Per-item icons: colored file-type icons (nvim-web-devicons) for recent
-- files, glyphs for actions. Inserted as separate units (like the bullet
-- hook), so type-to-filter — which matches item names — is unaffected.
local devicons = require 'nvim-web-devicons'
-- Nerd-font glyphs by codepoint (raw glyphs don't survive some edits).
local action_icons = {
  ['Find files'] = '\u{f002}', -- search
  ['Live grep'] = '\u{f0b0}', -- filter
  ['New file'] = '\u{f15b}', -- file
  ['Config'] = '\u{f013}', -- gear
  ['Quit'] = '\u{f011}', -- power
}
local function adding_icons(content)
  local coords = starter.content_coords(content, 'item')
  for i = #coords, 1, -1 do
    local l, u = coords[i].line, coords[i].unit
    local item = content[l][u].item
    local icon, hl
    if item.section == 'Actions' then
      icon, hl = action_icons[item.name] or '', 'MiniStarterItemPrefix'
    else
      local fname = item.name:match '^(.-) %(' or item.name
      icon, hl = devicons.get_icon(fname, fname:match '%.([^.]+)$', { default = true })
    end
    table.insert(content[l], u, { string = icon .. '  ', type = 'item_icon', hl = hl })
  end
  return content
end

starter.setup {
  header = table.concat({
    '███╗   ██╗██╗   ██╗██╗███╗   ███╗',
    '████╗  ██║██║   ██║██║████╗ ████║',
    '██╔██╗ ██║██║   ██║██║██╔████╔██║',
    '██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║',
    '██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║',
    '╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝',
  }, '\n'),
  footer = git_status,
  items = {
    starter.sections.sessions(5, true),
    starter.sections.recent_files(8, false),
    { name = 'Find files', action = 'Telescope find_files', section = 'Actions' },
    { name = 'Live grep', action = 'Telescope live_grep', section = 'Actions' },
    { name = 'New file', action = 'enew', section = 'Actions' },
    { name = 'Config', action = 'edit ' .. vim.fn.stdpath 'config' .. '/init.lua', section = 'Actions' },
    { name = 'Quit', action = 'qa', section = 'Actions' },
  },
  content_hooks = {
    adding_icons,
    starter.gen_hook.aligning('center', 'center'),
  },
}

-- Statusline. Mini's defaults, with a few tweaks via a custom content function:
-- a short mode label (N/I/V) at any width; the LSP-client + fileinfo
-- (filetype/encoding/size) sections dropped (that info is on <leader>bi); and
-- diagnostics limited to errors + warnings, with icons colored by severity.
local statusline = require 'mini.statusline'
-- Cursor location as LINE:COLUMN.
---@diagnostic disable-next-line: duplicate-set-field
statusline.section_location = function()
  return '%2l:%-2v'
end

-- Errors + warnings only — mini's built-in section shows all four levels in the
-- section's flat color. Icons colored via the themed Diagnostic* groups.
local DIAG_ERROR, DIAG_WARN = '', ''
local function diagnostics_ew()
  local c = vim.diagnostic.count(0)
  local e, w = c[vim.diagnostic.severity.ERROR] or 0, c[vim.diagnostic.severity.WARN] or 0
  local parts = {}
  if e > 0 then
    parts[#parts + 1] = '%#DiagnosticError#' .. DIAG_ERROR .. ' ' .. e
  end
  if w > 0 then
    parts[#parts + 1] = '%#DiagnosticWarn#' .. DIAG_WARN .. ' ' .. w
  end
  return table.concat(parts, ' ')
end

-- Special (non-file) buffers — neo-tree, help, quickfix, Trouble. The mode/path/
-- flags bar is meaningless there; show just a focus-aware label (the mode-colored
-- block marks the focused window; dimmed via the inactive content when not).
local special = { ['neo-tree'] = 'Neo-tree', help = 'Help', qf = 'Quickfix', trouble = 'Trouble' }

statusline.setup {
  use_icons = vim.g.have_nerd_font,
  content = {
    active = function()
      -- trunc_width 999 forces the short mode name (N/I/V) regardless of width.
      local mode, mode_hl = statusline.section_mode { trunc_width = 999 }
      local label = special[vim.bo.filetype]
      if label then
        -- Special buffers get a normal-looking bar: mode block, the label on the
        -- grey Devinfo bar (like the git section), and the cursor position.
        return statusline.combine_groups {
          { hl = mode_hl, strings = { mode } },
          { hl = 'MiniStatuslineDevinfo', strings = { label } },
          '%=',
          { hl = mode_hl, strings = { statusline.section_location { trunc_width = 75 } } },
        }
      end
      local git = statusline.section_git { trunc_width = 40 }
      local diff = statusline.section_diff { trunc_width = 75 }
      local diagnostics = diagnostics_ew()
      local filename = statusline.section_filename { trunc_width = 140 }
      local location = statusline.section_location { trunc_width = 75 }
      local search = statusline.section_searchcount { trunc_width = 75 }
      -- LSP and fileinfo sections intentionally omitted.
      return statusline.combine_groups {
        { hl = mode_hl, strings = { mode } },
        { hl = 'MiniStatuslineDevinfo', strings = { git, diff } },
        '%<',
        { hl = 'MiniStatuslineFilename', strings = { filename } },
        '%=',
        -- Diagnostics on the right, just left of line:col, on the transparent
        -- background (the grey Devinfo block washed out their muted colors).
        { hl = 'MiniStatuslineFilename', strings = { diagnostics } },
        { hl = mode_hl, strings = { search, location } },
      }
    end,
    inactive = function()
      local label = special[vim.bo.filetype]
      if label then
        -- Not selected: plain whitish label on the dark background (no grey bar).
        return statusline.combine_groups { { hl = 'MiniStatuslineFilename', strings = { ' ' .. label } } }
      end
      return '%#MiniStatuslineInactive#%F%='
    end,
  },
}

-- Make the filename section transparent (it also carries the diagnostics and the
-- unfocused special-buffer label) so its content reads on the terminal background
-- instead of the grey Devinfo fill. Re-derive on colorscheme change.
local function transparent_filename()
  local h = vim.api.nvim_get_hl(0, { name = 'MiniStatuslineFilename', link = false })
  vim.api.nvim_set_hl(0, 'MiniStatuslineFilename', { fg = h.fg, bg = 'none' })
end
transparent_filename()
vim.api.nvim_create_autocmd('ColorScheme', { callback = transparent_filename })
