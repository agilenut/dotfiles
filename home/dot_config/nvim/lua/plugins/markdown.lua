-- Markdown rendering: render-markdown — pretty in-buffer markdown;
-- <leader>tm (in plugins/notify.lua toggles) switches raw vs rendered.
--
-- Tuned toward a cleaner, palette-driven render: hierarchy shown by indenting
-- each section by heading level (no gutter glyph, no inline icon), headings in
-- blue bold over a subtle block-width background, code blocks
-- with a clear background + palette language label (no devicon), padded inline
-- code, dim blockquotes, small bullets, cyan links/footnotes with no link
-- icons, and superscript footnotes. render-markdown's default highlight groups
-- aren't palette-driven, so we override them from theme_palette (re-applied on
-- ColorScheme).

local gh = require('util').gh
local p = require 'theme_palette'

vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' } -- treesitter + icons already present

require('render-markdown').setup {
  heading = {
    icons = { '' }, -- no inline icon; '#'s concealed, heading is bold text
    sign = false, -- no gutter glyph; hierarchy is shown by indentation instead
    position = 'inline',
    backgrounds = {}, -- no background band; heading is just blue bold text.
    -- (An empty list means no bg group is applied — otherwise the plugin
    -- re-applies its own green diff-derived default, clobbering any override.)
    -- foregrounds use the default RenderMarkdownH{1..6} groups, recolored below.
  },
  -- Indent each section by its heading level (org-indent style) instead of a
  -- gutter number. H1 stays flush; H2+ (and their bodies) step right.
  indent = {
    enabled = true,
    per_level = 2,
    skip_level = 1, -- don't indent H1
    skip_heading = false, -- indent the heading title with its section
    icon = ' ', -- plain whitespace indent, no vertical guide bar
  },
  code = {
    style = 'full', -- show the language label over code blocks
    width = 'block', -- background spans the code, not the whole window
    min_width = 40,
    sign = false, -- no language devicon in the sign column (gutter)
    language_icon = false, -- language name only, no inline devicon glyph
    highlight_language = 'RenderMarkdownCodeInfo', -- palette-colored (below), not the gold devicon
    inline = true, -- render inline code with a background
    inline_pad = 0, -- no padding: bg hugs the text (trying vs glow's ` code `)
    left_pad = 1,
    right_pad = 1,
  },
  bullet = { icons = { '•', '◦', '▪', '▫' } },
  quote = { icon = '▍' },
  link = {
    hyperlink = '', -- no generic link icon
    image = '',
    email = '',
    -- custom is deep-merged with the default per-domain icons (github, youtube,
    -- …), and an empty table won't clear them — null out every default entry's
    -- icon (the merge keeps each pattern, just drops the glyph).
    custom = (function()
      local none = {}
      for _, k in ipairs {
        'web',
        'apple',
        'discord',
        'github',
        'gitlab',
        'google',
        'hackernews',
        'linkedin',
        'microsoft',
        'neovim',
        'reddit',
        'slack',
        'stackoverflow',
        'steam',
        'twitter',
        'wikipedia',
        'x',
        'youtube',
        'youtube_short',
      } do
        none[k] = { icon = '' }
      end
      return none
    end)(),
    footnote = { superscript = true, icon = '' }, -- superscript ¹, no leading icon
  },
  pipe_table = { preset = 'round' },
}

-- render-markdown ships its own (non-palette) colors; drive them from the
-- palette so markdown matches everything else. Re-apply on colorscheme change.
local function theme_markdown()
  local set = vim.api.nvim_set_hl
  -- Headings: bold, no background band, colored with syntax.keyword_storage —
  -- the same per-theme token bat (markup.heading) and vscode.nvim (vscBlue) use
  -- for markdown headings, so rendered/source views agree in both themes (blue
  -- in vscode, salmon in dark-2026). render-markdown foregrounds color the icon;
  -- the heading TEXT is treesitter (@markup.heading.N), so set both.
  for i = 1, 6 do
    set(0, 'RenderMarkdownH' .. i, { fg = p.syntax.keyword_storage, bold = true })
    set(0, '@markup.heading.' .. i .. '.markdown', { fg = p.syntax.keyword_storage, bold = true })
  end
  -- Bold: plain bold, no color tint (like glow).
  set(0, '@markup.strong', { fg = p.ansi.foreground, bold = true })
  -- Code: a clear block background; inline code as a padded box, glow-style
  -- (foreground text on a subtle bg); muted language label.
  set(0, 'RenderMarkdownCode', { bg = p.ui.line_highlight })
  set(0, 'RenderMarkdownCodeInline', { bg = p.ui.line_highlight, fg = p.ansi.foreground })
  set(0, 'RenderMarkdownCodeInfo', { fg = p.ui.muted })
  -- Links & footnotes: cyan (holds its hue in both themes).
  set(0, '@markup.link.label.markdown_inline', { fg = p.ansi.cyan })
  set(0, '@markup.link.url', { fg = p.ansi.cyan })
  set(0, '@markup.link', { fg = p.ansi.cyan })
  set(0, 'RenderMarkdownLink', { fg = p.ansi.cyan })
  -- Blockquotes: de-emphasized (ui.dim, between fg and muted), not the default
  -- yellow — bat's markup.quote uses the same token. The bar is the
  -- RenderMarkdownQuote* group; the text is treesitter @markup.quote.
  for i = 1, 6 do
    set(0, 'RenderMarkdownQuote' .. i, { fg = p.ui.dim })
  end
  set(0, '@markup.quote', { fg = p.ui.dim })
  set(0, '@markup.quote.markdown', { fg = p.ui.dim })
  -- Bullets: plain foreground (not a dark grey).
  set(0, 'RenderMarkdownBullet', { fg = p.ansi.foreground })
end
theme_markdown()
vim.api.nvim_create_autocmd('ColorScheme', { callback = theme_markdown })
