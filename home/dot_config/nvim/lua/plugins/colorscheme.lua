-- Colorscheme (vscode.nvim) + highlight fixes. Remaps the theme's named color
-- slots to the active palette (theme_palette.lua) and mutes/adjusts gitsigns,
-- diagnostic, syntax, statusline, and cursorline groups. Applied on load and
-- re-applied on every ColorScheme event. Loaded after plugins.ui (gitsigns) and
-- before plugins.mini (whose statusline groups the mode-contrast fix targets).

local gh = require('util').gh

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
