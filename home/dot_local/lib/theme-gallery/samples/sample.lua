-- Palette sample: lua — comments, strings, numbers, keywords, functions.
local M = {}

local MAX = 42
local name = "world\n"

--- Doc-style comment describing the greeter.
function M.greet(who)
  who = who or name
  for i = 1, MAX do
    if i % 7 == 0 then
      print(("hello %s (%d)"):format(who, i))
    end
  end
  return true
end

return M
