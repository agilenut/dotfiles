--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- ============================================================
-- SECTION 1: FOUNDATION
-- Core Neovim settings, leaders, options, basic keymaps, basic autocmds
-- ============================================================
do
  -- Enable faster startup by caching compiled Lua modules
  vim.loader.enable()

  -- Set <space> as the leader key
  -- See `:help mapleader`
  --  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Set to true if you have a Nerd Font installed and selected in the terminal
  vim.g.have_nerd_font = true

  -- No git command spawned from nvim (telescope git_status, :terminal lazygit,
  -- any plugin) may take .git/index.lock for opportunistic index refreshes —
  -- those collide with commits running concurrently in another session.
  -- Deliberate writes (stage hunk, commit) use mandatory locks and are
  -- unaffected. gitsigns/neo-tree/mini.git already pass --no-optional-locks;
  -- this covers everything else.
  vim.env.GIT_OPTIONAL_LOCKS = '0'

  -- Highlight chezmoi `.tmpl` files as their underlying type: strip the
  -- `.tmpl` suffix and re-run filetype detection on the remaining name
  -- (alacritty.toml.tmpl -> toml, git/config.tmpl -> gitconfig, etc.).
  vim.filetype.add {
    pattern = {
      ['.*%.tmpl'] = function(path)
        return vim.filetype.match { filename = (path:gsub('%.tmpl$', '')) }
      end,
      -- Extensionless configs whose type is path-based don't survive the strip
      -- above (chezmoi's source path is dot_config/, not .config/). Map them
      -- explicitly, higher priority than the generic .tmpl rule.
      ['.*/git/config%.tmpl'] = { 'gitconfig', { priority = 10 } },
    },
  }

  -- [[ Setting options ]]
  --  See `:help vim.o`
  -- NOTE: You can change these options as you wish!
  --  For more options, you can see `:help option-list`

  -- Make line numbers default
  vim.o.number = true
  -- You can also add relative line numbers, to help with jumping.
  --  Experiment for yourself to see if you like it!
  -- vim.o.relativenumber = true

  -- Enable mouse mode, can be useful for resizing splits for example!
  vim.o.mouse = 'a'

  -- Don't show the mode, since it's already in the status line
  vim.o.showmode = false

  -- Sync clipboard between OS and Neovim.
  --  Schedule the setting after `UiEnter` because it can increase startup-time.
  --  Remove this option if you want your OS clipboard to remain independent.
  --  See `:help 'clipboard'`
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

  -- Enable break indent
  vim.o.breakindent = true

  -- Enable undo/redo changes even after closing and reopening a file
  vim.o.undofile = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.o.ignorecase = true
  vim.o.smartcase = true

  -- Keep signcolumn on by default
  vim.o.signcolumn = 'yes'

  -- Rounded border on all floats — delineates the transparent popups.
  vim.o.winborder = 'rounded'

  -- Decrease update time
  vim.o.updatetime = 250

  -- Decrease mapped sequence wait time
  vim.o.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  --  See `:help 'list'`
  --  and `:help 'listchars'`
  --
  --  Notice listchars is set using `vim.opt` instead of `vim.o`.
  --  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
  --   See `:help lua-options`
  --   and `:help lua-guide-options`
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

  -- Hide the ~ markers on lines past the end of the buffer; the line numbers
  -- already show where content ends, so the column of tildes is just noise.
  vim.opt.fillchars:append { eob = ' ' }

  -- Preview substitutions live, as you type!
  vim.o.inccommand = 'split'

  -- Show which line your cursor is on
  vim.o.cursorline = true
  -- Highlight only the line NUMBER, not a full-width gray bar — the bar's fixed
  -- bg clashes with the transparent, tinted terminal backgrounds.
  vim.o.cursorlineopt = 'number'

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.o.scrolloff = 10

  -- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
  -- instead raise a dialog asking if you wish to save the current file(s)
  -- See `:help 'confirm'`
  vim.o.confirm = true

  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`

  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- Can switch between these as you prefer
    virtual_text = true, -- Text shows up at the end of the line
    virtual_lines = false, -- Text shows up underneath the line, with virtual lines

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- TIP: Disable arrow keys in normal mode
  -- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
  -- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
  -- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
  -- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

  -- Split navigation is handled by vim-tmux-navigator (Ctrl+hjkl across nvim
  -- splits AND tmux panes). The plugin is added in the plugins section below,
  -- after the `gh` helper is defined; the tmux config has the matching bindings.

  -- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
  -- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
  -- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
  -- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
  -- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.hl.on_yank()`
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })
end

-- ============================================================
-- SECTION 2: PLUGIN MANAGER INTRO
-- vim.pack intro, build hooks
-- ============================================================
do
  -- [[ Intro to `vim.pack` ]]
  -- `vim.pack` is a new plugin manager built into Neovim,
  --  which provides a Lua interface for installing and managing plugins.
  --
  --  See `:help vim.pack`, `:help vim.pack-examples` or the
  --  excellent blog post from the creator of vim.pack and mini.nvim:
  --  https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
  --
  --  To inspect plugin state and pending updates, run
  --    :lua vim.pack.update(nil, { offline = true })
  --
  --  To update plugins, run
  --    :lua vim.pack.update()
  --
  --
  --  Throughout the rest of the config there will be examples
  --  of how to install and configure plugins using `vim.pack`.
  --
  --  In this section we set up some autocommands to run build
  --  steps for certain plugins after they are installed or updated.

  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local stderr = result.stderr or ''
      local stdout = result.stdout or ''
      local output = stderr ~= '' and stderr or stdout
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  -- This autocommand runs after a plugin is installed or updated and
  --  runs the appropriate build command for that plugin if necessary.
  --
  -- See `:help vim.pack-events`
  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
        return
      end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end
    end,
  })
end

---Because most plugins are hosted on GitHub, you can use the helper
---function to have less repetition in the following sections.
---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- SECTION 3: UI / CORE UX PLUGINS
-- guess-indent, gitsigns, which-key, colorscheme, todo-comments, mini modules
-- ============================================================
do
  -- [[ Installing and Configuring Plugins ]]
  --
  -- To install a plugin simply call `vim.pack.add` with its git url.
  -- This will download the default branch of the plugin, which will usually be `main` or `master`
  -- You can also have more advanced specs, which we will talk about later.
  --
  -- For most plugins its not enough to install them, you also need to call their `.setup()` to start them.
  --
  -- For example, lets say we want to install `guess-indent.nvim` - a plugin for
  -- automatically detecting and setting the indentation.
  --
  -- We first install it from https://github.com/NMAC427/guess-indent.nvim
  -- and then call its `setup()` function to start it with default settings.
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {}

  -- vim-tmux-navigator: Ctrl+hjkl moves between nvim splits AND tmux panes as one
  -- grid (auto-maps <C-hjkl>). Matching bindings live in ~/.config/tmux/tmux.conf.
  vim.pack.add { gh 'christoomey/vim-tmux-navigator' }

  -- Because lua is a real programming language, you can also have some logic to your installation -
  -- like only installing a plugin if a condition is met.
  --
  -- Here we only install `nvim-web-devicons` (which adds pretty icons) if we have a Nerd Font,
  -- since otherwise the icons won't display properly.
  if vim.g.have_nerd_font then vim.pack.add { gh 'nvim-tree/nvim-web-devicons' } end

  -- Here is a more advanced configuration example that passes options to `gitsigns.nvim`
  --
  -- See `:help gitsigns` to understand what each configuration key does.
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  require('gitsigns').setup {
    signs = {
      add = { text = '+' }, ---@diagnostic disable-line: missing-fields
      change = { text = '~' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
    },
    on_attach = function(bufnr)
      local gs = require 'gitsigns'
      local function map(l, r, desc) vim.keymap.set('n', l, r, { buffer = bufnr, desc = desc }) end
      -- Jump between changed hunks (staged + unstaged). Always gitsigns nav — no
      -- diff-mode special-case, so a stray `:diffthis` can't silently break it.
      map(']c', function() gs.nav_hunk('next', { target = 'all' }) end, 'Next git [c]hange')
      map('[c', function() gs.nav_hunk('prev', { target = 'all' }) end, 'Prev git [c]hange')
      -- Hunk staging from the editor (stage_hunk toggles stage/unstage). Bigger
      -- git ops live in lazygit (<space>gg); inline diffs are on <leader>gd.
      map('<leader>ghs', gs.stage_hunk, 'Hunk [s]tage/unstage')
      map('<leader>ghr', gs.reset_hunk, 'Hunk [r]eset (discard changes)')
      -- Capital = whole buffer: stage all, unstage all, reset all (discard).
      map('<leader>ghS', gs.stage_buffer, 'Buffer [S]tage all')
      map('<leader>ghU', gs.reset_buffer_index, 'Buffer [U]nstage all')
      map('<leader>ghR', gs.reset_buffer, 'Buffer [R]eset all (discard)')
      -- Blame: gb = popup with the full commit for the current line. The ambient
      -- line-blame toggle (gB) lives with the other toggles in the notifications section.
      map('<leader>gb', function() gs.blame_line { full = true } end, 'Git [b]lame line')
    end,
  }

  -- inline-diff.nvim — VSCode-style live word-level inline diff: added/removed/changed
  -- shown inline as you type, with deleted lines. It derives colors from DiffAdd/
  -- DiffDelete and auto-boosts the word emphasis. Visualization only; gitsigns still
  -- owns signs, staging, blame, hunk nav.
  vim.pack.add { gh 'cvlmtg/inline-diff.nvim' }
  require('inline-diff').setup {}
  -- inline-diff re-defines its highlights with a forced contrast fg on every enable,
  -- which flattens treesitter colors. Strip that fg on the ADD groups (bg only) right
  -- after toggling, so added/changed code keeps its syntax highlighting. Deleted text
  -- is virtual text with no syntax, so it keeps the contrast fg.
  local function inline_diff_keep_syntax()
    for _, g in ipairs { 'InlineDiffAdd', 'InlineDiffWordAdd' } do
      local hl = vim.api.nvim_get_hl(0, { name = g })
      if hl.bg then vim.api.nvim_set_hl(0, g, { bg = hl.bg }) end
    end
  end
  vim.keymap.set('n', '<leader>gd', function()
    vim.cmd 'InlineDiff'
    inline_diff_keep_syntax()
  end, { desc = 'Git [d]iff (inline toggle)' })

  -- Useful plugin to show you pending keybinds.
  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    -- Delay between pressing a key and opening which-key (milliseconds)
    delay = 0,
    -- rules = false drops the spotty auto per-key icons; only the explicit group
    -- icons in `spec` below render (mappings must stay true or ALL icons vanish).
    icons = { mappings = true, rules = false },
    win = { border = 'rounded' }, -- which-key ignores the global winborder

    -- Keymap description convention: bracket ONLY the action key (the last key in
    -- the sequence), in its real case — `Git [b]lame line` (press b), `Buffer
    -- [S]tage all` (Shift+S). Group words stay plain/unbracketed as searchable
    -- context (so `<leader>sk` "git" finds git cmds); keys with no matching letter
    -- (x, gr) get no bracket. Icons live on groups only (icons.rules = false above),
    -- except the toggles, which carry a live state icon (green switch on / grey
    -- off) registered alongside their dynamic Enable/Disable label.
    -- Document existing key chains
    spec = {
      { '<leader>b', group = '[b]uffer' },
      { '<leader>s', group = '[s]earch', icon = { icon = '', color = 'cyan' }, mode = { 'n', 'v' } },
      { '<leader>t', group = '[t]oggle', icon = { icon = '', color = 'yellow' } },
      { '<leader>g', group = '[g]it', icon = { cat = 'filetype', name = 'git' } },
      { '<leader>gh', group = 'Git [h]unk', icon = { icon = '', color = 'orange' } },
      { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫', color = 'red' } },
      { 'gr', group = 'LSP Actions', icon = { icon = '', color = 'green' }, mode = { 'n' } },
    },
  }

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
    local colors = { Error = palette.ui.diag_error, Warn = palette.ui.diag_warn, Info = palette.ui.diag_info, Hint = palette.ui.diag_hint }
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
    local function up(c) return math.floor(c + (255 - c) * 0.16) end
    local bright = up(r) * 65536 + up(g) * 256 + up(b)
    vim.api.nvim_set_hl(0, 'CursorLine', { bg = bright })
    vim.api.nvim_set_hl(0, 'NeoTreeCursorLine', { bg = bright })
  end
  fix_cursorline()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = fix_cursorline })

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

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  require('mini.ai').setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

  -- Statusline. Mini's defaults, with a few tweaks via a custom content function:
  -- a short mode label (N/I/V) at any width; the LSP-client + fileinfo
  -- (filetype/encoding/size) sections dropped (that info is on <leader>bi); and
  -- diagnostics limited to errors + warnings, with icons colored by severity.
  local statusline = require 'mini.statusline'
  -- Cursor location as LINE:COLUMN.
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function() return '%2l:%-2v' end

  -- Errors + warnings only — mini's built-in section shows all four levels in the
  -- section's flat color. Icons colored via the themed Diagnostic* groups.
  local DIAG_ERROR, DIAG_WARN = '', ''
  local function diagnostics_ew()
    local c = vim.diagnostic.count(0)
    local e, w = c[vim.diagnostic.severity.ERROR] or 0, c[vim.diagnostic.severity.WARN] or 0
    local parts = {}
    if e > 0 then parts[#parts + 1] = '%#DiagnosticError#' .. DIAG_ERROR .. ' ' .. e end
    if w > 0 then parts[#parts + 1] = '%#DiagnosticWarn#' .. DIAG_WARN .. ' ' .. w end
    return table.concat(parts, ' ')
  end

  -- Special (non-file) buffers — neo-tree, help, quickfix, Trouble. The mode/path/
  -- flags bar is meaningless there; show just a focus-aware label (the mode-colored
  -- block marks the focused window; dimmed via the inactive content when not).
  local special = { ['neo-tree'] = 'Neo-tree', help = 'Help', qf = 'Quickfix', trouble = 'Trouble' }

  statusline.setup {
    use_icons = vim.g.have_nerd_font,
    content = {
      active = function()
        -- trunc_width 999 forces the short mode name (N/I/V) regardless of width.
        local mode, mode_hl = statusline.section_mode { trunc_width = 999 }
        local label = special[vim.bo.filetype]
        if label then
          -- Special buffers get a normal-looking bar: mode block, the label on the
          -- grey Devinfo bar (like the git section), and the cursor position.
          return statusline.combine_groups {
            { hl = mode_hl, strings = { mode } },
            { hl = 'MiniStatuslineDevinfo', strings = { label } },
            '%=',
            { hl = mode_hl, strings = { statusline.section_location { trunc_width = 75 } } },
          }
        end
        local git = statusline.section_git { trunc_width = 40 }
        local diff = statusline.section_diff { trunc_width = 75 }
        local diagnostics = diagnostics_ew()
        local filename = statusline.section_filename { trunc_width = 140 }
        local location = statusline.section_location { trunc_width = 75 }
        local search = statusline.section_searchcount { trunc_width = 75 }
        -- LSP and fileinfo sections intentionally omitted.
        return statusline.combine_groups {
          { hl = mode_hl, strings = { mode } },
          { hl = 'MiniStatuslineDevinfo', strings = { git, diff } },
          '%<',
          { hl = 'MiniStatuslineFilename', strings = { filename } },
          '%=',
          -- Diagnostics on the right, just left of line:col, on the transparent
          -- background (the grey Devinfo block washed out their muted colors).
          { hl = 'MiniStatuslineFilename', strings = { diagnostics } },
          { hl = mode_hl, strings = { search, location } },
        }
      end,
      inactive = function()
        local label = special[vim.bo.filetype]
        if label then
          -- Not selected: plain whitish label on the dark background (no grey bar).
          return statusline.combine_groups { { hl = 'MiniStatuslineFilename', strings = { ' ' .. label } } }
        end
        return '%#MiniStatuslineInactive#%F%='
      end,
    },
  }

  -- Make the filename section transparent (it also carries the diagnostics and the
  -- unfocused special-buffer label) so its content reads on the terminal background
  -- instead of the grey Devinfo fill. Re-derive on colorscheme change.
  local function transparent_filename()
    local h = vim.api.nvim_get_hl(0, { name = 'MiniStatuslineFilename', link = false })
    vim.api.nvim_set_hl(0, 'MiniStatuslineFilename', { fg = h.fg, bg = 'none' })
  end
  transparent_filename()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = transparent_filename })
end

-- ============================================================
-- SECTION 4: SEARCH & NAVIGATION
-- Telescope setup, keymaps, LSP picker mappings
-- ============================================================
do
  -- [[ Fuzzy Finder (files, lsp, etc) ]]
  --
  -- Telescope is a fuzzy finder that comes with a lot of different things that
  -- it can fuzzy find! It's more than just a "file finder", it can search
  -- many different aspects of Neovim, your workspace, LSP, and more!
  --
  -- There are lots of other alternative pickers (like snacks.picker, or fzf-lua)
  -- so feel free to experiment and see what you like!
  --
  -- The easiest way to use Telescope, is to start by doing something like:
  --  :Telescope help_tags
  --
  -- After running this command, a window will open up and you're able to
  -- type in the prompt window. You'll see a list of `help_tags` options and
  -- a corresponding preview of the help.
  --
  -- Two important keymaps to use while in Telescope are:
  --  - Insert mode: <c-/>
  --  - Normal mode: ?
  --
  -- This opens a window that shows you all of the keymaps for the current
  -- Telescope picker. This is really useful to discover what Telescope can
  -- do as well as how to actually do it!

  ---@type (string|vim.pack.Spec)[]
  local telescope_plugins = {
    gh 'nvim-lua/plenary.nvim',
    gh 'nvim-telescope/telescope.nvim',
    gh 'nvim-telescope/telescope-ui-select.nvim',
  }
  if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end

  -- NOTE: You can install multiple plugins at once
  vim.pack.add(telescope_plugins)

  -- See `:help telescope` and `:help telescope.setup()`
  require('telescope').setup {
    defaults = {
      mappings = {
        -- Match fzf: Ctrl+j/k move the selection, Ctrl+f/b scroll the preview,
        -- Ctrl+a selects all (parity with fzf's ctrl-a).
        -- (Telescope binds only C-n/p + C-u/d by default, so C-j/k fell through
        -- to insert-mode behavior — C-k digraph, C-j newline.)
        i = {
          ['<C-j>'] = require('telescope.actions').move_selection_next,
          ['<C-k>'] = require('telescope.actions').move_selection_previous,
          ['<C-f>'] = require('telescope.actions').preview_scrolling_down,
          ['<C-b>'] = require('telescope.actions').preview_scrolling_up,
          ['<C-a>'] = require('telescope.actions').select_all,
        },
        n = {
          ['<C-j>'] = require('telescope.actions').move_selection_next,
          ['<C-k>'] = require('telescope.actions').move_selection_previous,
          ['<C-f>'] = require('telescope.actions').preview_scrolling_down,
          ['<C-b>'] = require('telescope.actions').preview_scrolling_up,
          ['<C-a>'] = require('telescope.actions').select_all,
        },
      },
    },
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }

  -- Enable Telescope extensions if they are installed
  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')

  -- See `:help telescope.builtin`
  local builtin = require 'telescope.builtin'
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Search [h]elp' })
  vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'Search [k]eymaps' })
  vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = 'Search [f]iles' })
  vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = 'Search [s]elect Telescope' })
  vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = 'Search current [w]ord' })
  vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Search by [g]rep' })
  vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = 'Search [d]iagnostics' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = 'Search [r]esume' })
  vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = 'Search recent files [.]' })
  vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = 'Search [c]ommands' })
  vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

  vim.keymap.set('n', '<leader>sa', function() builtin.find_files { hidden = true, no_ignore = true } end, { desc = 'Search [a]ll files (incl. hidden + ignored)' })
  vim.keymap.set('n', '<leader>gs', builtin.git_status, { desc = 'Git [s]tatus (changed files)' })
  vim.keymap.set('n', '<leader>gg', function()
    vim.cmd 'tabnew'
    vim.cmd 'terminal lazygit'
    vim.cmd 'startinsert'
    -- Close the terminal tab the moment lazygit exits, so `q` drops you
    -- straight back to your code instead of a dead `[Process exited]` buffer.
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = vim.api.nvim_get_current_buf(),
      once = true,
      callback = function()
        vim.schedule(function() vim.cmd 'bdelete!' end)
      end,
    })
  end, { desc = 'Git (lazy[g]it)' })

  -- Add Telescope-based LSP pickers when an LSP attaches to a buffer.
  -- If you later switch picker plugins, this is where to update these mappings.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf

      -- Find references for the word under your cursor.
      vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = 'Goto [r]eferences' })

      -- Jump to the implementation of the word under your cursor.
      -- Useful when your language has ways of declaring types without an actual implementation.
      vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = 'Goto [i]mplementation' })

      -- Jump to the definition of the word under your cursor.
      -- This is where a variable was first declared, or where a function is defined, etc.
      -- To jump back, press <C-t>.
      vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = 'Goto [d]efinition' })

      -- Fuzzy find all the symbols in your current document.
      -- Symbols are things like variables, functions, types, etc.
      vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = '[O]pen Document Symbols' })

      -- Fuzzy find all the symbols in your current workspace.
      -- Similar to document symbols, except searches over your entire project.
      vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open [W]orkspace Symbols' })

      -- Jump to the type of the word under your cursor.
      -- Useful when you're not sure what type a variable is and you want to see
      -- the definition of its *type*, not where it was *defined*.
      vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = 'Goto [t]ype definition' })
    end,
  })

  -- Override default behavior and theme when searching
  vim.keymap.set('n', '<leader>/', function()
    -- You can pass additional configuration to Telescope to change the theme, layout, etc.
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 0,
      previewer = false,
    })
  end, { desc = '[/] Fuzzily search in current buffer' })

  -- It's also possible to pass additional configuration options.
  --  See `:help telescope.builtin.live_grep()` for information about particular keys
  vim.keymap.set(
    'n',
    '<leader>s/',
    function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end,
    { desc = 'Search [/] in open files' }
  )

  -- Shortcut for searching your Neovim configuration files
  vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = 'Search [n]eovim files' })
end

-- ============================================================
-- SECTION 5: LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================
do
  -- [[ LSP Configuration ]]
  -- Brief aside: **What is LSP?**
  --
  -- LSP is an initialism you've probably heard, but might not understand what it is.
  --
  -- LSP stands for Language Server Protocol. It's a protocol that helps editors
  -- and language tooling communicate in a standardized fashion.
  --
  -- In general, you have a "server" which is some tool built to understand a particular
  -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
  -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
  -- processes that communicate with some "client" - in this case, Neovim!
  --
  -- LSP provides Neovim with features like:
  --  - Go to definition
  --  - Find references
  --  - Autocompletion
  --  - Symbol Search
  --  - and more!
  --
  -- Thus, Language Servers are external tools that must be installed separately from
  -- Neovim. This is where `mason` and related plugins come into play.
  --
  -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
  -- and elegantly composed help section, `:help lsp-vs-treesitter`

  -- Useful status updates for LSP.
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {}

  --  This function gets run when an LSP attaches to a particular buffer.
  --    That is to say, every time a new file is opened that is associated with
  --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
  --    function will be executed to configure the current buffer
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
      -- NOTE: Remember that Lua is a real programming language, and as such it is possible
      -- to define small helper and utility functions so you don't have to repeat yourself.
      --
      -- In this case, we create a function that lets us more easily define mappings specific
      -- for LSP related items. It sets the mode, buffer and description for us each time.
      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      -- Rename the variable under your cursor.
      --  Most Language Servers support renaming across files, etc.
      map('grn', vim.lsp.buf.rename, 'Re[n]ame')

      -- Execute a code action, usually your cursor needs to be on top of an error
      -- or a suggestion from your LSP for this to activate.
      map('gra', vim.lsp.buf.code_action, 'Code [a]ction', { 'n', 'x' })

      -- WARN: This is not Goto Definition, this is Goto Declaration.
      --  For example, in C this would take you to the header.
      map('grD', vim.lsp.buf.declaration, 'Goto [D]eclaration')

      -- The following two autocommands are used to highlight references of the
      -- word under your cursor when your cursor rests there for a little while.
      --    See `:help CursorHold` for information about when this is executed
      --
      -- When you move your cursor, the highlights will be cleared (the second autocommand).
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end
    end,
  })

  -- Enable the following language servers
  --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
  --  See `:help lsp-config` for information about keys and how to configure
  ---@type table<string, vim.lsp.Config>
  local servers = {
    -- clangd = {},
    -- gopls = {},
    -- pyright = {},
    -- rust_analyzer = {},
    --
    -- Some languages (like typescript) have entire language plugins that can be useful:
    --    https://github.com/pmizio/typescript-tools.nvim
    --
    -- But for many setups, the LSP (`ts_ls`) will work just fine
    -- ts_ls = {},

    stylua = {}, -- Used to format Lua code

    -- Special Lua Config, as recommended by neovim help docs
    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
            --  See https://github.com/neovim/nvim-lspconfig/issues/3189
            library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
              '${3rd}/luv/library',
              '${3rd}/busted/library',
            }),
          },
        })
      end,
      ---@type lspconfig.settings.lua_ls
      settings = {
        Lua = {
          format = { enable = false }, -- Disable formatting (formatting is done by stylua)
        },
      },
    },

    -- Python: basedpyright for types, ruff for lint (+ format via conform)
    basedpyright = {
      settings = {
        -- Analyze the whole project (not just open files) so Trouble shows
        -- problems across the project. Heavier on large repos.
        basedpyright = { analysis = { diagnosticMode = 'workspace' } },
      },
    },
    ruff = {},
    -- PHP
    intelephense = {},
    -- Shell (bash/sh; zsh has no language server)
    bashls = {},
    -- Config files
    yamlls = {},
    jsonls = {},
    taplo = {},
    -- Tailwind class completion (invoicing, v4 CSS-first). classFunctions
    -- extends completion/hover/linting into the class-builder helpers.
    tailwindcss = {
      settings = {
        tailwindCSS = {
          classFunctions = { 'cva', 'cx', 'clsx', 'cn' },
        },
      },
    },
    -- Azure infra-as-code (elenkis infra/). cmd set explicitly: the
    -- lspconfig default ships none, and mason-lspconfig's shim only applies
    -- via its setup(), which this config doesn't use.
    bicep = { cmd = { 'bicep-lsp' } },
    -- CSS/SCSS: completion/hover only — validation off (stylelint via
    -- nvim-lint is the linter, matching the repos' .vscode settings).
    cssls = {
      settings = {
        css = { validate = false },
        scss = { validate = false },
        less = { validate = false },
      },
    },
    -- Markdown navigation (markdownlint comes later via nvim-lint)
    marksman = {},

    -- TypeScript / JavaScript / React + the Vue SFC <script> layer (vtsls).
    -- The @vue/typescript-plugin gives Vue files TS support in hybrid mode.
    vtsls = {
      filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
      settings = {
        vtsls = {
          tsserver = {
            globalPlugins = {
              {
                name = '@vue/typescript-plugin',
                location = vim.fn.stdpath 'data' .. '/mason/packages/vue-language-server/node_modules/@vue/language-server',
                languages = { 'vue' },
                configNamespace = 'typescript',
              },
            },
          },
        },
      },
    },
    -- Vue templates/styles (Volar v3, hybrid mode — vtsls handles the script layer)
    vue_ls = {},
    -- ESLint diagnostics (reads the repo's flat or legacy eslint config)
    eslint = {},
  }

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  }

  -- Automatically install LSPs and related tools to stdpath for Neovim
  require('mason').setup {
    -- Crashdummyy registry provides roslyn-language-server (for roslyn.nvim).
    registries = {
      'github:mason-org/mason-registry',
      'github:Crashdummyy/mason-registry',
    },
  }

  -- Ensure the servers and tools above are installed
  --
  -- To check the current status of installed tools and/or manually install
  -- other tools, you can run
  --    :Mason
  --
  -- You can press `g?` for help in this menu.
  local ensure_installed = vim.tbl_keys(servers or {})
  vim.list_extend(ensure_installed, {
    'roslyn-language-server', -- C# server for roslyn.nvim (Crashdummyy registry)
    -- Formatters for conform (stylua/ruff/taplo already installed as servers/tools)
    'prettier',
    'shfmt',
    'pint',
    -- Linters with no LSP (run via nvim-lint, reading the repo's config)
    'markdownlint-cli2',
    'stylelint',
    'actionlint',
    -- Python bridge tools for repos not yet migrated to ruff/basedpyright
    'black',
    'isort',
    'mypy',
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end

  -- C# via roslyn.nvim — the Roslyn LSP (same engine as VS Code's C# Dev Kit).
  -- Attaches on .sln/.csproj; server installed from mason (Crashdummyy registry).
  vim.pack.add { gh 'seblyng/roslyn.nvim' }
  require('roslyn').setup {}
  -- Whole-solution diagnostics so problems from unopened C# files show in Trouble.
  vim.lsp.config('roslyn', {
    settings = {
      ['csharp|background_analysis'] = {
        dotnet_analyzer_diagnostics_scope = 'fullSolution',
        dotnet_compiler_diagnostics_scope = 'fullSolution',
      },
    },
  })
end

-- ============================================================
-- SECTION 6: FORMATTING
-- conform.nvim setup and keymap
-- ============================================================
do
  -- [[ Formatting ]]
  vim.pack.add { gh 'stevearc/conform.nvim' }
  -- conform's builtin prettier/pint/stylelint definitions already prefer the
  -- repo's node_modules/.bin or vendor/bin binary. The python builtins run
  -- bare commands, so route them through the repo's .venv pin (mason as
  -- fallback).
  local local_tool = function(name)
    return function(_, ctx)
      return require('project').local_bin(ctx.buf, name)
    end
  end
  require('conform').setup {
    notify_on_error = false,
    format_on_save = function()
      -- Format on save unless globally disabled via <leader>tf.
      if vim.g.disable_autoformat then
        return nil
      end
      return { timeout_ms = 1000, lsp_format = 'fallback' }
    end,
    default_format_opts = {
      -- Use the external formatter below if set; otherwise fall back to the LSP
      -- (e.g. C# via roslyn, which formats from .editorconfig).
      lsp_format = 'fallback',
    },
    -- External formatters run the same binaries as pre-commit, reading the repo's
    -- .editorconfig / .prettierrc / etc. Project-local installs are preferred.
    formatters_by_ft = {
      lua = { 'stylua' },
      -- Python: ruff is the formatter (tool verdicts); repos pinned to black
      -- with no ruff config (uperix) bridge to black until migrated. Between
      -- black and ruff the NEARER declaration wins (monorepo subpackages own
      -- their tooling); same depth keeps ruff. isort needs its own config —
      -- its defaults aren't black-compatible, and a repo that never
      -- configured it shouldn't get imports reordered.
      python = function(bufnr)
        local project = require 'project'
        local black_root = project.pyproject_tool_root(bufnr, 'black')
        local ruff_root = project.pyproject_tool_root(bufnr, 'ruff')
        local ruff_toml = vim.fs.root(bufnr, { 'ruff.toml', '.ruff.toml' })
        if ruff_toml and (not ruff_root or #ruff_toml > #ruff_root) then
          ruff_root = ruff_toml
        end
        if black_root and (not ruff_root or #black_root > #ruff_root) then
          if project.has_pyproject_tool(bufnr, 'isort') or project.has_config(bufnr, { '.isort.cfg' }) then
            return { 'isort', 'black' }
          end
          return { 'black' }
        end
        return { 'ruff_organize_imports', 'ruff_format' }
      end,
      javascript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescript = { 'prettier' },
      typescriptreact = { 'prettier' },
      vue = { 'prettier' },
      -- stylelint --fix first (skipped without a config), then prettier —
      -- mirrors the lint side so save-fixes match what pre-commit would do.
      css = { 'stylelint', 'prettier' },
      scss = { 'stylelint', 'prettier' },
      html = { 'prettier' },
      json = { 'prettier' },
      jsonc = { 'prettier' },
      yaml = { 'prettier' },
      markdown = { 'prettier' },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      toml = { 'taplo' },
      php = { 'pint' },
      -- C#: no entry — roslyn's editorconfig-based LSP formatting (lsp_format fallback).
    },
    formatters = {
      ruff_format = { command = local_tool 'ruff' },
      ruff_organize_imports = { command = local_tool 'ruff' },
      black = { command = local_tool 'black' },
      isort = { command = local_tool 'isort' },
      -- stylelint errors without a config; run it only where one exists.
      stylelint = {
        condition = function(_, ctx)
          local project = require 'project'
          return project.has_config(ctx.buf, project.config_files.stylelint)
        end,
      },
    },
  }

  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[f]ormat buffer' })
end

-- ============================================================
-- SECTION 6b: LINTING (non-LSP)
-- nvim-lint for linters with no language server (e.g. markdownlint)
-- ============================================================
do
  vim.pack.add { gh 'mfussenegger/nvim-lint' }
  local lint = require 'lint'
  -- markdownlint-cli2 reads the repo's .markdownlint-cli2.* or .markdownlint.*,
  -- so nvim's markdown diagnostics match pre-commit. LSP-backed languages
  -- (eslint, ruff, etc.) don't need nvim-lint — their server reports diagnostics.
  lint.linters_by_ft = {
    markdown = { 'markdownlint-cli2' },
    css = { 'stylelint' },
    scss = { 'stylelint' },
    yaml = { 'actionlint' },
    -- No pylint: ruff (LSP, always on) covers its PL rule family; enable
    -- more PL rules in a repo's ruff config rather than bridging pylint.
    python = { 'mypy' },
  }

  -- mypy resolves its config from cwd only (no upward walk). Run it from
  -- the root of the config that satisfied the gate — a nearer unrelated
  -- pyproject.toml must not steal the cwd from the declaring config.
  local lint_cwd = {
    mypy = function()
      return vim.fs.root(0, { 'mypy.ini', '.mypy.ini' }) or require('project').pyproject_tool_root(0, 'mypy')
    end,
  }

  -- Per-linter run conditions beyond filetype and config gating: path
  -- scoping, event scoping for slow linters, pyproject content gates.
  -- basedpyright is the primary Python type checker; mypy is a config-gated
  -- bridge for un-migrated repos (tool verdicts).
  local lint_when = {
    actionlint = function()
      -- Direct children only — GitHub ignores subdirs of workflows/.
      return vim.fs.dirname(vim.api.nvim_buf_get_name(0)):find('/%.github/workflows$') ~= nil
    end,
    mypy = function(ev)
      -- Gate = "a mypy config resolves": same source as lint_cwd.mypy, so
      -- gate and spawn cwd can never disagree on markers.
      return ev.event == 'BufWritePost' -- slow, and lints the file on disk
        and lint_cwd.mypy() ~= nil
    end,
  }

  -- Mirror nvim-lint's ft resolution (exact match, else dotted-ft union) so
  -- linters keep running if a runtime update makes workflows 'yaml.ghaction'.
  local linters_for_ft = function(ft)
    local names = lint.linters_by_ft[ft]
    if names then
      return names
    end
    local seen = {}
    for _, part in ipairs(vim.split(ft, '.', { plain = true })) do
      for _, name in ipairs(lint.linters_by_ft[part] or {}) do
        seen[name] = true
      end
    end
    return vim.tbl_keys(seen)
  end

  -- Run the repo's pinned binary when one exists (mason fallback).
  -- nvim-lint evaluates cmd with the linted buffer current, so bufnr 0 works.
  for _, name in ipairs { 'markdownlint-cli2', 'stylelint', 'mypy' } do
    lint.linters[name].cmd = function()
      return require('project').local_bin(0, name)
    end
  end

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
    group = vim.api.nvim_create_augroup('nvim-lint', { clear = true }),
    callback = function(ev)
      if not vim.bo.modifiable then
        return
      end
      -- Linters with an entry in project.config_files are opt-in by config:
      -- they run only where that config exists (stylelint errors without one).
      -- lint_when adds non-config conditions (path/event scoping).
      local names = vim.tbl_filter(function(name)
        local project = require 'project'
        local configs = project.config_files[name]
        if configs and not project.has_config(0, configs) then
          return false
        end
        local when = lint_when[name]
        return not when or when(ev)
      end, linters_for_ft(vim.bo.filetype))
      -- Lint from the buffer's dir so stdin linters (markdownlint-cli2,
      -- stylelint) resolve their config from the file's location — matching
      -- pre-commit's per-file resolution — rather than nvim's cwd. Linters
      -- in lint_cwd override this with their own root.
      local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
      local default_cwd = vim.uv.fs_stat(dir) and dir or nil
      for _, name in ipairs(names) do
        local cwd = lint_cwd[name] and lint_cwd[name]() or default_cwd
        lint.try_lint(name, { cwd = cwd })
      end
    end,
  })
end

-- ============================================================
-- SECTION 6c: FILE EXPLORER
-- neo-tree — a VS Code-style tree with git status + diagnostic badges
-- ============================================================
do
  vim.pack.add {
    gh 'MunifTanjim/nui.nvim', -- plenary + devicons already added above
    gh 'nvim-neo-tree/neo-tree.nvim',
  }
  require('neo-tree').setup {
    close_if_last_window = true,
    window = {
      mappings = {
        ['<space>'] = 'none', -- free Space so <leader> maps work inside neo-tree
        ['l'] = 'open',
        ['h'] = 'close_node',
      },
    },
    default_component_configs = {
      -- Plain single-char git markers instead of cryptic/box glyphs.
      git_status = {
        symbols = {
          added = '+', modified = '~', deleted = '-', renamed = '»',
          untracked = '?', ignored = '◌', unstaged = '○', staged = '✓', conflict = '!',
        },
      },
    },
    filesystem = {
      follow_current_file = { enabled = true }, -- reveal the open file in the tree
      use_libuv_file_watcher = true, -- auto-refresh on external changes
      filtered_items = {
        hide_dotfiles = false, -- we edit dotfiles
        hide_gitignored = true,
      },
    },
    -- git status + diagnostic badges show on files by default.
  }
  -- neo-tree sets its own window bg on load; re-apply transparency (incl. the
  -- float preview) whenever a neo-tree buffer opens, so it matches other windows.
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'neo-tree',
    callback = function()
      for _, g in ipairs { 'NeoTreeNormal', 'NeoTreeNormalNC', 'NeoTreeEndOfBuffer', 'NeoTreeFloatNormal', 'NeoTreeFloatBorder', 'NeoTreePreview' } do
        vim.api.nvim_set_hl(0, g, { bg = 'none' })
      end
      -- Mute neo-tree's git marker/filename colors to the project palette.
      local palette = require 'theme_palette'
      local git = {
        NeoTreeGitAdded = palette.ui.git_add,
        NeoTreeGitStaged = palette.ui.git_add,
        NeoTreeGitModified = palette.ui.git_change,
        NeoTreeGitUnstaged = palette.ui.git_change,
        NeoTreeGitUntracked = palette.ui.git_untracked,
        NeoTreeGitConflict = palette.ui.git_conflict,
        NeoTreeGitDeleted = palette.ui.git_delete,
      }
      for g, c in pairs(git) do
        vim.api.nvim_set_hl(0, g, { fg = c })
      end
    end,
  })
  vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle reveal<cr>', { desc = '[e]xplorer (Neo-tree)' })
  -- Tree of only git-changed files, for navigating what changed.
  vim.keymap.set('n', '<leader>ge', '<cmd>Neotree toggle source=git_status position=left<cr>', { desc = 'Git changed files ([e]xplorer)' })

  -- neo-tree's git-status icons go stale when you stage/unstage (via gitsigns or
  -- lazygit): staging only touches .git/index, not the file, so neo-tree's libuv
  -- file watcher never sees it. Refresh neo-tree's git status when gitsigns reports
  -- an index change, debounced so frequent sign updates while typing don't thrash it.
  local nt_refresh_pending = false
  vim.api.nvim_create_autocmd('User', {
    pattern = 'GitSignsUpdate',
    callback = function()
      if nt_refresh_pending then return end
      nt_refresh_pending = true
      vim.defer_fn(function()
        nt_refresh_pending = false
        pcall(function() require('neo-tree.sources.manager').refresh 'filesystem' end)
      end, 300)
    end,
  })
end

-- ============================================================
-- SECTION 6d: MARKDOWN RENDERING
-- render-markdown — pretty in-buffer markdown; <leader>tm toggles raw vs rendered
-- ============================================================
do
  vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' } -- treesitter + icons already present
  require('render-markdown').setup {}
end

-- ============================================================
-- SECTION: notifications, unified toggles, buffer delete
-- ============================================================
do
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

  -- Toggle helper: flip the setting, announce it, and register a which-key entry
  -- whose label and icon track live state — "Disable" + green switch when on,
  -- "Enable" + grey switch when off. which-key re-runs the desc/icon functions
  -- on every popup open, so the row always reflects the current value.
  local TOGGLE_ON, TOGGLE_OFF = '', ''
  local function toggle(key, name, get, set)
    vim.keymap.set('n', key, function()
      local on = not get()
      set(on)
      vim.notify((on and 'Enabled ' or 'Disabled ') .. name)
    end, { desc = 'Toggle ' .. name })
    require('which-key').add {
      {
        key,
        desc = function() return (get() and 'Disable ' or 'Enable ') .. name end,
        icon = function()
          local on = get()
          -- Explicit 'grey' (not nil) for off: the base WhichKeyIcon fallback is underlined.
          return { icon = on and TOGGLE_ON or TOGGLE_OFF, color = on and 'green' or 'grey' }
        end,
      },
    }
  end

  -- Wrap a state read that reaches into a plugin's internals so a future refactor
  -- of that module can't throw inside which-key's render callback (which would
  -- blank the toggle popup). Core vim.* getters below don't need this.
  local function safe_get(fn)
    return function()
      local ok, v = pcall(fn)
      return ok and v or false
    end
  end

  toggle('<leader>th', 'inlay hints', function() return vim.lsp.inlay_hint.is_enabled { bufnr = 0 } end, function(s) vim.lsp.inlay_hint.enable(s, { bufnr = 0 }) end)
  toggle('<leader>tx', 'diagnostic text', function() return vim.diagnostic.config().virtual_text ~= false end, function(s) vim.diagnostic.config { virtual_text = s } end)
  toggle('<leader>tm', 'markdown render', safe_get(function() return require('render-markdown.state').enabled end), function(s) vim.cmd('RenderMarkdown ' .. (s and 'enable' or 'disable')) end)
  toggle('<leader>tf', 'format on save', function() return not vim.g.disable_autoformat end, function(s) vim.g.disable_autoformat = not s end)
  toggle('<leader>gB', 'line blame', safe_get(function() return require('gitsigns.config').config.current_line_blame end), function(s) require('gitsigns').toggle_current_line_blame(s) end)

  -- Delete the current buffer while keeping the window/split layout: show the
  -- alternate (or another listed) buffer in its place, falling back to a fresh
  -- empty buffer only when nothing else is listed.
  local function buf_delete()
    local cur = vim.api.nvim_get_current_buf()
    if vim.bo[cur].modified then
      vim.notify('Buffer has unsaved changes; save or use :bd! first', vim.log.levels.WARN)
      return
    end
    local repl
    local alt = vim.fn.bufnr '#'
    if alt > 0 and alt ~= cur and vim.bo[alt].buflisted then
      repl = alt
    else
      for _, b in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
        if b.bufnr ~= cur then
          repl = b.bufnr
          break
        end
      end
    end
    repl = repl or vim.api.nvim_create_buf(true, false)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == cur then
        vim.api.nvim_win_set_buf(win, repl)
      end
    end
    if vim.api.nvim_buf_is_valid(cur) then
      pcall(vim.api.nvim_buf_delete, cur, {})
    end
  end
  vim.keymap.set('n', '<leader>bd', buf_delete, { desc = 'Buffer [d]elete' })

  -- File metadata dropped from the statusline (full path, type, encoding, size,
  -- attached LSP servers), plus the buffer's resolved formatters (with binary
  -- path — shows whether the repo's pin or mason won) and configured linters.
  -- Sticky toast: stays up until <leader>bi is pressed again.
  local buffer_info_open = false
  vim.keymap.set('n', '<leader>bi', function()
    if buffer_info_open then
      require('notify').dismiss { silent = true, pending = false }
      buffer_info_open = false
      return
    end
    local buf = 0
    local path = vim.api.nvim_buf_get_name(buf)
    local full = path ~= '' and vim.fn.fnamemodify(path, ':~') or '[No Name]'
    local enc = vim.bo[buf].fileencoding ~= '' and vim.bo[buf].fileencoding or vim.o.encoding
    local ft = vim.bo[buf].filetype
    local bytes = path ~= '' and vim.fn.getfsize(path) or -1
    local size
    if bytes < 0 then
      size = '(unsaved)'
    elseif bytes < 1024 then
      size = bytes .. ' B'
    elseif bytes < 1024 * 1024 then
      size = string.format('%.1f KB', bytes / 1024)
    else
      size = string.format('%.1f MB', bytes / (1024 * 1024))
    end
    local names = {}
    for _, c in ipairs(vim.lsp.get_clients { bufnr = buf }) do
      names[#names + 1] = c.name
    end
    -- Available formatters with their resolved binary (project pin or mason).
    local formatters = {}
    for _, f in ipairs(require('conform').list_formatters(buf)) do
      formatters[#formatters + 1] = f.name .. ' → ' .. (f.command or '?')
    end
    -- Linters configured for the filetype; config-gated ones (same
    -- project.config_files gate the lint autocmd reads) marked when off.
    -- Path/event scoping (actionlint, mypy) isn't reflected here.
    local project = require 'project'
    local linters = {}
    for _, name in ipairs(require('lint').linters_by_ft[ft] or {}) do
      local configs = project.config_files[name]
      local off = configs and not project.has_config(buf, configs)
      linters[#linters + 1] = off and (name .. ' (off: no config)') or name
    end
    buffer_info_open = true
    vim.notify(table.concat({
      'Path:  ' .. full,
      'Type:  ' .. (ft ~= '' and ft or '(none)') .. '   ' .. enc .. '   ' .. vim.bo[buf].fileformat,
      'Size:  ' .. size,
      'LSP:   ' .. (#names > 0 and table.concat(names, ', ') or '(none)'),
      'Format: ' .. (#formatters > 0 and table.concat(formatters, '\n        ') or '(lsp or none)'),
      'Lint:  ' .. (#linters > 0 and table.concat(linters, ', ') or '(none)'),
    }, '\n'), vim.log.levels.INFO, { title = 'Buffer info', timeout = false })
  end, { desc = 'Buffer [i]nfo (path, type, LSP, format, lint)' })
end

-- ============================================================
-- SECTION 7: AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================
do
  -- [[ Snippet Engine ]]

  -- NOTE: You can also specify plugin using a version range for its git tag.
  --  See `:help vim.version.range()` for more info
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {}

  -- `friendly-snippets` contains a variety of premade snippets.
  --    See the README about individual language/framework/plugin snippets:
  --    https://github.com/rafamadriz/friendly-snippets
  --
  -- vim.pack.add { gh 'rafamadriz/friendly-snippets' }
  -- require('luasnip.loaders.from_vscode').lazy_load()

  -- [[ Autocomplete Engine ]]
  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
  require('blink.cmp').setup {
    keymap = {
      -- 'default' (recommended) for mappings similar to built-in completions
      --   <c-y> to accept ([y]es) the completion.
      --    This will auto-import if your LSP supports it.
      --    This will expand snippets if the LSP sent a snippet.
      -- 'super-tab' for tab to accept
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- For an understanding of why the 'default' preset is recommended,
      -- you will need to read `:help ins-completion`
      --
      -- No, but seriously. Please read `:help ins-completion`, it is really good!
      --
      -- All presets have the following mappings:
      -- <tab>/<s-tab>: move to right/left of your snippet expansion
      -- <c-space>: Open menu or open docs if already open
      -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
      -- <c-e>: Hide menu
      -- <c-k>: Toggle signature help
      --
      -- See `:help blink-cmp-config-keymap` for defining your own keymap
      preset = 'default',

      -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
      --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono',
    },

    completion = {
      -- By default, you may press `<c-space>` to show the documentation.
      -- Optionally, set `auto_show = true` to show the documentation after a delay.
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
    },

    snippets = { preset = 'luasnip' },

    -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
    -- which automatically downloads a prebuilt binary when enabled.
    --
    -- By default, we use the Lua implementation instead, but you may enable
    -- the rust implementation via `'prefer_rust_with_warning'`
    --
    -- See `:help blink-cmp-config-fuzzy` for more information
    fuzzy = { implementation = 'lua' },

    -- Shows a signature help window while you type arguments for a function
    signature = { enabled = true },
  }
end

-- ============================================================
-- SECTION 8: TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================
do
  -- [[ Configure Treesitter ]]
  --  Used to highlight, edit, and navigate code
  --
  --  See `:help nvim-treesitter-intro`

  -- NOTE: You can also specify a branch or a specific commit
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end
    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds
    -- For more info on folds see `:help folds`
    -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    -- vim.wo.foldmethod = 'expr'

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- SECTION 9: OPTIONAL EXAMPLES / NEXT STEPS
-- kickstart.plugins.* examples
-- ============================================================
do
  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug'
  -- require 'kickstart.plugins.indent_line'
  -- require 'kickstart.plugins.lint'
  -- require 'kickstart.plugins.autopairs'
  -- require 'kickstart.plugins.neo-tree'
  -- require 'kickstart.plugins.gitsigns' -- adds gitsigns recommended keymaps

  -- NOTE: You can add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  require 'custom.plugins'
end

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
