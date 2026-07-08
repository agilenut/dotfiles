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
