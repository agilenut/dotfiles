-- <leader>t toggles: a small framework that flips a setting, toasts the new
-- state, and registers a live-state which-key entry. Covers inlay hints,
-- diagnostic text, markdown render, format-on-save, and line blame.

-- Toggle helper: flip the setting, announce it, and register a which-key entry
-- whose label and icon track live state — "Disable" + green switch when on,
-- "Enable" + grey switch when off. which-key re-runs the desc/icon functions
-- on every popup open, so the row always reflects the current value.
local TOGGLE_ON, TOGGLE_OFF = '', ''
local function toggle(key, name, get, set)
  -- name carries the [k]ey-hint brackets for which-key; strip them for toasts.
  local plain = name:gsub('[%[%]]', '')
  vim.keymap.set('n', key, function()
    local on = not get()
    set(on)
    vim.notify((on and 'Enabled ' or 'Disabled ') .. plain)
  end, { desc = 'Toggle ' .. name })
  require('which-key').add {
    {
      key,
      desc = function()
        return (get() and 'Disable ' or 'Enable ') .. name
      end,
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

toggle('<leader>th', 'inlay [h]ints', function()
  return vim.lsp.inlay_hint.is_enabled { bufnr = 0 }
end, function(s)
  vim.lsp.inlay_hint.enable(s, { bufnr = 0 })
end)
toggle('<leader>tx', 'diagnostic te[x]t', function()
  return vim.diagnostic.config().virtual_text ~= false
end, function(s)
  vim.diagnostic.config { virtual_text = s }
end)
toggle(
  '<leader>tm',
  '[m]arkdown render',
  safe_get(function()
    return require('render-markdown.state').enabled
  end),
  function(s)
    vim.cmd('RenderMarkdown ' .. (s and 'enable' or 'disable'))
  end
)
toggle('<leader>tf', '[f]ormat on save', function()
  return not vim.g.disable_autoformat
end, function(s)
  vim.g.disable_autoformat = not s
end)
toggle(
  '<leader>gB',
  'line [B]lame',
  safe_get(function()
    return require('gitsigns.config').config.current_line_blame
  end),
  function(s)
    require('gitsigns').toggle_current_line_blame(s)
  end
)
