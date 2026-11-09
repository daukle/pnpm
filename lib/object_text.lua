--- A package.json object a block carries as one JSON text, pasted into the file verbatim.
local object_text = {}

local function count_members(object)
  local count = 0
  for _ in pairs(object) do count = count + 1 end
  return count
end

--- The checked text of `config[key]`, or nil when the block has none. Raises on anything but one
--- JSON object.
---
--- @implNote the text is parsed alone AND as the only member of a wrapper, because it is pasted
--- into package.json verbatim and `{}, "dependencies": {}` would otherwise add a member there.
function object_text.checked(config, key, what, example)
  local text = config[key]
  if text == nil then return nil end
  local shape = '"' .. key .. '" must be ' .. what .. " as JSON text, such as '" .. example .. "'"
  if type(text) ~= "string" or string.match(text, "^%s*{") == nil or string.match(text, "}%s*$") == nil then
    error(shape, 0)
  end
  local wrapped = daukle.json_parse('{"' .. key .. '": ' .. text .. "}")
  if type(daukle.json_parse(text)) ~= "table" or count_members(wrapped) ~= 1 then error(shape, 0) end
  return text
end

return object_text
