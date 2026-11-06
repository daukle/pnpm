--- `overrides`: npm's own override object as one JSON text, written into the package.json
--- npm resolves from and nowhere else, since npm reads it only to compute the closure (D-246).
local overrides = {}

overrides.KEY = "overrides"

local function count_members(object)
  local count = 0
  for _ in pairs(object) do count = count + 1 end
  return count
end

--- The checked text, or nil when the block has none. Raises on anything but one JSON object.
---
--- @implNote the text is parsed alone AND as the only member of a wrapper, because it is pasted
--- into package.json verbatim and `{}, "dependencies": {}` would otherwise add a member there.
function overrides.checked(config)
  local text = config[overrides.KEY]
  if text == nil then return nil end
  local shape = '"' .. overrides.KEY .. '" must be npm\'s override object as JSON text,'
                .. " such as '{\"ms\": \"2.1.2\"}'"
  if type(text) ~= "string" or string.match(text, "^%s*{") == nil or string.match(text, "}%s*$") == nil then
    error(shape, 0)
  end
  local wrapped = daukle.json_parse('{"' .. overrides.KEY .. '": ' .. text .. "}")
  if type(daukle.json_parse(text)) ~= "table" or count_members(wrapped) ~= 1 then error(shape, 0) end
  return text
end

return overrides
