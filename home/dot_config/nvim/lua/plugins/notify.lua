-- Notifications (nvim-notify), unified <leader>t toggles, buffer
-- delete/close/path/info helpers, and tab + per-tab cwd keymaps.

local gh = require('util').gh

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
  -- name carries the [k]ey-hint brackets for which-key; strip them for toasts.
  local plain = name:gsub('[%[%]]', '')
  vim.keymap.set('n', key, function()
    local on = not get()
    set(on)
    vim.notify((on and 'Enabled ' or 'Disabled ') .. plain)
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

toggle('<leader>th', 'inlay [h]ints', function()
  return vim.lsp.inlay_hint.is_enabled { bufnr = 0 }
end, function(s)
  vim.lsp.inlay_hint.enable(s, { bufnr = 0 })
end)
toggle('<leader>tx', 'diagnostic te[x]t', function()
  return vim.diagnostic.config().virtual_text ~= false
end, function(s)
  vim.diagnostic.config { virtual_text = s }
end)
toggle(
  '<leader>tm',
  '[m]arkdown render',
  safe_get(function()
    return require('render-markdown.state').enabled
  end),
  function(s)
    vim.cmd('RenderMarkdown ' .. (s and 'enable' or 'disable'))
  end
)
toggle('<leader>tf', '[f]ormat on save', function()
  return not vim.g.disable_autoformat
end, function(s)
  vim.g.disable_autoformat = not s
end)
toggle(
  '<leader>gB',
  'line [B]lame',
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
