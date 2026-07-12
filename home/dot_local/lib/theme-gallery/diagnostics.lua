-- theme-gallery: sourced (nvim -S) after opening diagnostics.txt to inject one
-- diagnostic of each severity, so the diag_* palette (error/warn/info/hint —
-- gutter signs, inline virtual text, underline) renders deterministically
-- without depending on a language server. Plain text buffer → no LSP noise.
vim.diagnostic.config { virtual_text = true, signs = true, underline = true }
local ns = vim.api.nvim_create_namespace 'gallery_diag'
local S = vim.diagnostic.severity
vim.diagnostic.set(ns, 0, {
  { lnum = 2, col = 0, end_col = 5, message = 'something is broken', severity = S.ERROR },
  { lnum = 3, col = 0, end_col = 7, message = 'something looks suspicious', severity = S.WARN },
  { lnum = 4, col = 0, end_col = 4, message = 'something worth noting', severity = S.INFO },
  { lnum = 5, col = 0, end_col = 4, message = 'a gentle suggestion', severity = S.HINT },
})
