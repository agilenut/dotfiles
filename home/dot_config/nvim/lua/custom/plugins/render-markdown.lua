-- render-markdown.nvim — inline rendering of headings, code blocks, lists,
-- task lists, and tables in markdown buffers. treesitter + mini.nvim are
-- already loaded by init.lua, so we only need the plugin itself here.
vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {}
