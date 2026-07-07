-- UI / core UX plugins: guess-indent, tmux-navigator, devicons, gitsigns,
-- inline-diff, which-key, colorscheme + highlight fixes, todo-comments,
-- trouble, and the mini.nvim modules (ai, surround, sessions, starter,
-- statusline).

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

-- [[ Colorscheme ]]
-- You can easily change to a different colorscheme.
-- Change the name of the colorscheme plugin below, and then
-- change the command under that to load whatever the name of that colorscheme is.
--
-- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
-- vscode.nvim — its named color slots are remapped to the active theme's
-- palette (home/.chezmoidata/themes.toml, generated into theme_palette.lua)
-- via color_overrides, so the whole colorscheme follows `theme <name>`.
vim.pack.add { gh 'Mofiqul/vscode.nvim' }
local palette = require 'theme_palette'
require('vscode').setup {
  italic_comments = false,
  -- Transparent bg so the terminal's per-project background tint shows through.
  transparent = true,
  color_overrides = {
    vscBack = palette.ansi.background,
    vscFront = palette.ansi.foreground,
    vscGreen = palette.syntax.comment,
    vscOrange = palette.syntax.string,
    vscYellowOrange = palette.syntax.escape,
    vscLightRed = palette.syntax.regexp,
    vscLightGreen = palette.syntax.number,
    vscPink = palette.syntax.keyword,
    vscBlue = palette.syntax.keyword_storage,
    vscYellow = palette.syntax.func,
    vscBlueGreen = palette.syntax.type,
    vscLightBlue = palette.syntax.variable,
    vscAccentBlue = palette.syntax.constant,
    vscViolet = palette.ansi.magenta,
    vscGray = palette.ui.muted,
    vscLineNumber = palette.ui.muted,
    vscSelection = palette.ui.selection,
  },
}
vim.cmd.colorscheme 'vscode'

-- vscode.nvim gives the mini.statusline mode blocks a light background but
-- no foreground, so the mode text is unreadable. Force a dark fg while
-- keeping each mode's color. Re-applied whenever the colorscheme changes.
local function fix_statusline_mode_contrast()
  for _, mode in ipairs { 'Normal', 'Insert', 'Visual', 'Command', 'Replace', 'Other' } do
    local group = 'MiniStatuslineMode' .. mode
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    if hl.bg then
      vim.api.nvim_set_hl(0, group, { fg = palette.ansi.background, bg = string.format('#%06x', hl.bg), bold = true })
    end
  end
end
fix_statusline_mode_contrast()
vim.api.nvim_create_autocmd('ColorScheme', { callback = fix_statusline_mode_contrast })

-- Align gitsigns with the muted delta diff palette so nvim's gutter signs and
-- changed-line highlights match the terminal/lazygit diffs. delta has no
-- "change" state (a modified line is delete + add), so change lines render
-- green like adds and the green word-diff stays readable; only the gutter sign
-- (~) distinguishes a modify from an add. fg left unset so syntax shows through.
local function fix_gitsigns_palette()
  local set = vim.api.nvim_set_hl
  set(0, 'GitSignsAdd', { fg = palette.ui.git_add })
  set(0, 'GitSignsChange', { fg = palette.ui.git_change })
  set(0, 'GitSignsDelete', { fg = palette.ui.git_delete })
  set(0, 'GitSignsAddLn', { bg = palette.ui.diff_add_bg })
  set(0, 'GitSignsChangeLn', { bg = palette.ui.diff_change_bg })
  set(0, 'GitSignsDeleteLn', { bg = palette.ui.diff_del_bg })
  -- Intra-line word diff is handled by inline-diff.nvim, which derives its own
  -- colors from DiffAdd/DiffDelete below — no gitsigns word_diff groups needed.
  -- vimdiff / :diffthis use the Diff* groups — match the muted delta palette.
  set(0, 'DiffAdd', { bg = palette.ui.diff_add_bg })
  set(0, 'DiffChange', { bg = palette.ui.diff_change_bg })
  set(0, 'DiffDelete', { bg = palette.ui.diff_del_bg })
  set(0, 'DiffText', { bg = palette.ui.diff_text })
  -- Transparent floats (neo-tree preview, telescope, hover, which-key); the
  -- rounded winborder above delineates them.
  set(0, 'NormalFloat', { bg = 'none' })
  set(0, 'FloatBorder', { bg = 'none' })
  -- Bold the current-line number so it marks the line without a bg bar.
  set(0, 'CursorLineNr', { fg = palette.ansi.foreground, bold = true })
end
fix_gitsigns_palette()
vim.api.nvim_create_autocmd('ColorScheme', { callback = fix_gitsigns_palette })

-- Mute diagnostic colors to the project palette (vscode.nvim defaults to the
-- bright #f44747 we dropped). Covers inline text/signs/underline, Trouble, and
-- neo-tree badges, which all read the Diagnostic* groups.
local function fix_diagnostic_palette()
  local colors =
    { Error = palette.ui.diag_error, Warn = palette.ui.diag_warn, Info = palette.ui.diag_info, Hint = palette.ui.diag_hint }
  for sev, c in pairs(colors) do
    vim.api.nvim_set_hl(0, 'Diagnostic' .. sev, { fg = c })
    vim.api.nvim_set_hl(0, 'DiagnosticSign' .. sev, { fg = c })
    vim.api.nvim_set_hl(0, 'DiagnosticVirtualText' .. sev, { fg = c })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. sev, { sp = c, undercurl = true })
  end
end
fix_diagnostic_palette()
vim.api.nvim_create_autocmd('ColorScheme', { callback = fix_diagnostic_palette })

-- vscode.nvim leaves string escapes uncolored and renders regex as a plain
-- string. Stock VS Code Dark Modern themes escapes gold and regex red — match
-- it. Docstrings are deliberately green (as bat/delta render them, and unlike
-- stock which colors them as strings) so they read as documentation. Only
-- @string.documentation is touched, so regular strings stay peach.
local function fix_syntax_palette()
  vim.api.nvim_set_hl(0, '@string.escape', { fg = palette.syntax.escape })
  vim.api.nvim_set_hl(0, '@string.regexp', { fg = palette.syntax.regexp })
  vim.api.nvim_set_hl(0, '@string.documentation', { fg = palette.syntax.comment })
end
fix_syntax_palette()
vim.api.nvim_create_autocmd('ColorScheme', { callback = fix_syntax_palette })

-- The theme's CursorLine is near-black (#222) and barely reads on the transparent
-- background. Lighten it so the current-row highlight is visible in the panels that
-- use a full-line cursorline — neo-tree (via NeoTreeCursorLine) and Trouble (which
-- uses CursorLine directly). Normal buffers use cursorlineopt=number, so brightening
-- CursorLine only affects those panels. Re-derive on colorscheme change; bump 0.16
-- for a stronger bar.
local function fix_cursorline()
  local base = vim.api.nvim_get_hl(0, { name = 'CursorLine', link = false }).bg or 0x222222
  local r, g, b = math.floor(base / 65536) % 256, math.floor(base / 256) % 256, base % 256
  local function up(c)
    return math.floor(c + (255 - c) * 0.16)
  end
  local bright = up(r) * 65536 + up(g) * 256 + up(b)
  vim.api.nvim_set_hl(0, 'CursorLine', { bg = bright })
  vim.api.nvim_set_hl(0, 'NeoTreeCursorLine', { bg = bright })
end
fix_cursorline()
vim.api.nvim_create_autocmd('ColorScheme', { callback = fix_cursorline })

-- Highlight todo, notes, etc in comments
vim.pack.add { gh 'folke/todo-comments.nvim' }
require('todo-comments').setup { signs = false }

-- Trouble: a VS Code-style "Problems" panel for diagnostics (also quickfix,
-- LSP references, symbols). <leader>xx = workspace, <leader>xX = this buffer.
vim.pack.add { gh 'folke/trouble.nvim' }
require('trouble').setup {
  -- l / h expand / collapse the file groups, like neo-tree (merged with defaults).
  keys = { l = 'fold_open', h = 'fold_close' },
}
-- Trouble's folder icon is yellow (TroubleIconDirectory links to Special); link it
-- to Directory (blue) so folders match neo-tree. Re-apply on colorscheme change.
local function blue_trouble_folder()
  vim.api.nvim_set_hl(0, 'TroubleIconDirectory', { link = 'Directory' })
end
blue_trouble_folder()
vim.api.nvim_create_autocmd('ColorScheme', { callback = blue_trouble_folder })
vim.keymap.set('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', { desc = 'Diagnostics list (Trouble)' })
vim.keymap.set('n', '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', { desc = 'Buffer diagnostics (Trouble)' })

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
