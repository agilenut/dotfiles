-- Annotations / problems: todo-comments (TODO/FIXME/NOTE highlighting) and
-- trouble (VS Code-style Problems panel: diagnostics, quickfix, references).

local gh = require('util').gh

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
