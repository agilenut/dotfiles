-- Small helpers shared across the config modules.

local M = {}

---Because most plugins are hosted on GitHub, you can use this helper
---function to have less repetition in the plugin specs.
---@param repo string
---@return string
function M.gh(repo)
  return 'https://github.com/' .. repo
end

return M
