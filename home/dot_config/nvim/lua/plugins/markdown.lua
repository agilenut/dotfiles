-- Markdown rendering: render-markdown — pretty in-buffer markdown;
-- <leader>tm (in plugins/notify.lua toggles) switches raw vs rendered.

local gh = require('util').gh

vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' } -- treesitter + icons already present
require('render-markdown').setup {}
