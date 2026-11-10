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

--- Each field daukle/node carries on a workspace root as its raw JSON text, as members of a file.
local function carried_members(carried)
  local names = {}
  for name in pairs(carried or {}) do
    if name ~= "name" and name ~= "version" then names[#names + 1] = name end
  end
  table.sort(names)
  local members = ""
  for _, name in ipairs(names) do members = members .. string.format(',\n  "%s": %s', name, carried[name]) end
  return members
end

--- The package.json pnpm resolves the closure from: the block's ranges and overrides, private so
--- pnpm asks for no name, and for a workspace root its `identity`, which a member's `workspace:`
--- range may name, and the fields daukle/node `carried` into the root it renders, since a frozen
--- install compares some of them with the lockfile. pnpm reads its overrides from `pnpm.overrides`.
local function package_json(spec, identity, carried)
  local overrides = spec.overrides == nil and "" or (',\n  "pnpm": { "overrides": ' .. spec.overrides .. ' }')
  return '{\n'
    .. identity_members(identity)
    .. '  "private": true,\n'
    .. '  "dependencies": ' .. json_object(spec.packages) .. ',\n'
    .. '  "devDependencies": ' .. json_object(spec.devPackages)
    .. optional_list("peerDependencies", spec.peerPackages)
    .. optional_list("optionalDependencies", spec.optionalPackages)
    .. (spec.peerPackagesMeta == nil and "" or (',\n  "peerDependenciesMeta": ' .. spec.peerPackagesMeta))
    .. overrides .. carried_members(carried) .. '\n'
    .. '}\n'
end

--- The `overrides:` line of the `pnpm-workspace.yaml` beside the resolve, `{}` when the block has none,
--- so a later run never reads overrides an earlier one left in the derived directory.
---
--- @implNote pnpm 11 and 12 read overrides only from the workspace file and ignore
--- `pnpm.overrides`, measured 2026-11-10 (D-285). The JSON text is a YAML flow mapping, and a
--- newline is never inside a JSON string, so joining the lines keeps it one valid flow value.
local function workspace_overrides(spec)
  if spec.overrides == nil then return "overrides: {}\n" end
  return "overrides: " .. string.gsub(spec.overrides, "%s*\r?\n%s*", " ") .. "\n"
end

local WORKSPACE_FILE = "pnpm-workspace.yaml"

--- Whether this pnpm reads settings from a `pnpm-workspace.yaml` that declares no `packages`.
--- @implNote measured 2026-11-10: 9.15.9 refuses such a file ("packages field missing or empty"),
--- 8.9.2 ignores it, and 10.34.9, 11.28.5 and 12.18.0 read its overrides.
local function reads_workspace_settings(version)
  return tonumber(string.match(version, "^(%d+)")) >= 10
end

return {
  package_json = package_json,
  workspace_overrides = workspace_overrides,
  reads_workspace_settings = reads_workspace_settings,
  WORKSPACE_FILE = WORKSPACE_FILE,
  REMOVE_WORKSPACE_FILE = "require('fs').rmSync('" .. WORKSPACE_FILE .. "', { force: true })",
}
