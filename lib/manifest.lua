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

--- The package.json pnpm resolves the closure from: the block's ranges and overrides and nothing
--- else, private so pnpm asks for no name. pnpm reads its overrides from `pnpm.overrides`.
local function package_json(spec)
  local overrides = spec.overrides == nil and "" or (',\n  "pnpm": { "overrides": ' .. spec.overrides .. ' }')
  return '{\n'
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
