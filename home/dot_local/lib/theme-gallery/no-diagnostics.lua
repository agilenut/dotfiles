-- theme-gallery: disable diagnostic display (vim.diagnostic.enable(false)).
-- Two uses: every per-file syntax card (suppress a project-less sample's
-- LSP-error underlines — aha would corrupt them into a purple background, see
-- docs/known-issues.md; semantic tokens still load), and the gitsigns showcase
-- (keep the sign column for the gitsigns add/change/delete signs only).
vim.diagnostic.enable(false)
