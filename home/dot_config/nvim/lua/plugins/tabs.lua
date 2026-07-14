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

-- Custom tabline: label each tab by its real file (filename tail), skipping
-- special/sidebar buffers (neo-tree, Trouble, quickfix, help — anything with a
-- non-empty buftype) so focusing a sidebar no longer renames the tab. Replaces
-- the built-in tabline, so it renders the TabLine/TabLineSel groups (themed in
-- colorscheme.lua) and the click-to-close control itself.
local function tab_buf(tab)
  local focused = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
  if vim.bo[focused].buftype == '' then
    return focused
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == '' then
      return b
    end
  end
  return focused -- tab has only special windows
end

function _G.render_tabline()
  local cur = vim.api.nvim_get_current_tabpage()
  local out = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buf = tab_buf(tab)
    local name = vim.api.nvim_buf_get_name(buf)
    local label = name ~= '' and vim.fn.fnamemodify(name, ':t') or '[No Name]'
    if vim.bo[buf].modified then
      label = label .. ' ●'
    end
    label = label:gsub('%%', '%%%%') -- escape % so a filename with one isn't parsed as a statusline item
    local hl = (tab == cur) and '%#TabLineSel#' or '%#TabLine#'
    out[#out + 1] = ('%s%%%dT %d %s '):format(hl, i, i, label)
  end
  out[#out + 1] = '%#TabLineFill#%T'
  if #vim.api.nvim_list_tabpages() > 1 then
    out[#out + 1] = '%=%#TabLine#%999X ✕ %X'
  end
  return table.concat(out)
end

vim.o.tabline = '%!v:lua.render_tabline()'
