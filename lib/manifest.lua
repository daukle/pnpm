local function json_object(list)
  if #list.names == 0 then return "{}" end
  local lines = {}
  for index = 1, #list.names do
    local name = list.names[index]
    lines[index] = '    "' .. name .. '": "' .. list.ranges[name] .. '"'
  end
  return "{\n" .. table.concat(lines, ",\n") .. "\n  }"
end

local function optional_list(field, list)
  if #list.names == 0 then return "" end
  return ',\n  "' .. field .. '": ' .. json_object(list)
end

local function identity_members(identity)
  local members = ""
  for _, field in ipairs({ "name", "version" }) do
    if identity ~= nil and identity[field] ~= nil then
      members = members .. string.format('  "%s": "%s",\n', field, identity[field])
    end
  end
  return members
end

--- The package.json pnpm resolves the closure from: the block's ranges and overrides, private so
--- pnpm asks for no name, and a workspace root's `identity`, which a member's `workspace:` range
--- may name. pnpm reads its overrides from `pnpm.overrides`.
local function package_json(spec, identity)
  local overrides = spec.overrides == nil and "" or (',\n  "pnpm": { "overrides": ' .. spec.overrides .. ' }')
  return '{\n'
    .. identity_members(identity)
    .. '  "private": true,\n'
    .. '  "dependencies": ' .. json_object(spec.packages) .. ',\n'
    .. '  "devDependencies": ' .. json_object(spec.devPackages)
    .. optional_list("peerDependencies", spec.peerPackages)
    .. optional_list("optionalDependencies", spec.optionalPackages)
    .. (spec.peerPackagesMeta == nil and "" or (',\n  "peerDependenciesMeta": ' .. spec.peerPackagesMeta))
    .. overrides .. '\n'
    .. '}\n'
end

return { package_json = package_json }
