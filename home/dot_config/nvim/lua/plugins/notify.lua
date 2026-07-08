-- Notifications: route vim.notify through nvim-notify's animated toasts,
-- themed to the muted Diagnostic* palette. Loaded first so the toggle/buffer/
-- tab modules that follow emit themed toasts.

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
