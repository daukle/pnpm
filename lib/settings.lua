local output = daukle.require("lib/output")
local overrides = daukle.require("lib/overrides")
local releases = daukle.require("lib/releases")

local KNOWN_KEYS = { version = true, pnpm = true, packages = true, devPackages = true, ["for"] = true,
                     [output.PINNED_FROM] = true, [overrides.KEY] = true }

local RESOLVE = '"daukle pnpm:resolve --resolve"'
local PIN_FILE = "daukle/pnpm/" .. output.OUTPUT

local SCOPED = "^@[%w][%w%.%_%-]*/[%w][%w%.%_%-]*$"
local PLAIN = "^[%w][%w%.%_%-]*$"

local function config_of(context)
  if context.toolchain ~= nil then return context.toolchain.config end
  return context.config
end

local function reject_unknown_keys(config)
  for key in pairs(config) do
    if KNOWN_KEYS[key] == nil then
      error(string.format('"%s" is not a key this toolchain knows: a misspelled key would'
                          .. ' otherwise be ignored and resolve the wrong closure silently', key), 0)
    end
  end
end

local function version_of(context)
  local version = (context.toolchain ~= nil and context.toolchain.version)
                  or config_of(context).version
  if version == nil then
    error('a pnpm toolchain needs a "version", the node pnpm runs on: write the node toolchain\'s', 0)
  end
  return version
end

--- The toolchain instance the pins land on, admitted by core's own instance name rule.
local function target_of(config)
  local target = config["for"] or "node"
  if type(target) ~= "string" or string.match(target, "^[%l%d][%l%d%._%-]*$") == nil then
    error('"for" names the toolchain the pins land on, such as "node", not "'
          .. tostring(target) .. '"', 0)
  end
  return target
end

local function pnpm_of(config)
  if config.pnpm == nil then
    error('a pnpm toolchain needs "pnpm", the pnpm release that resolves and installs, as the'
          .. ' project\'s "packageManager" names it', 0)
  end
  return releases.of(config.pnpm)
end

--- @implNote ranges are written into a package.json without a json escaper, so a character that
--- would need escaping is refused at the edge instead, as daukle/npm refuses it.
local function checked_range(name, range, key)
  if type(range) ~= "string" then
    error(string.format('%s."%s" must be a version range as a string, not a %s', key, name, type(range)), 0)
  end
  if range == "" then error(string.format('%s."%s" is empty, and pnpm has no empty range', key, name), 0) end
  if string.match(range, '^[%w%s%.%-%+%*|<>=~^%(%)]+$') == nil then
    error(string.format('%s."%s" is "%s", which is not a registry version range: a git, file,'
                        .. ' url, alias, workspace or catalog specifier resolves outside the'
                        .. ' registry, and only a registry tarball can be pinned', key, name, range), 0)
  end
  return range
end

local function checked_packages(config, key)
  local packages = config[key]
  if packages == nil then return {}, {} end
  if type(packages) ~= "table" or #packages > 0 then
    error('"' .. key .. '" must be a table of package name to version range', 0)
  end
  local names = {}
  for name, range in pairs(packages) do
    if type(name) ~= "string" or (string.match(name, PLAIN) == nil and string.match(name, SCOPED) == nil) then
      error(string.format('"%s" is not a package name: a name is "lodash" or "@scope/name"', tostring(name)), 0)
    end
    checked_range(name, range, key)
    names[#names + 1] = name
  end
  table.sort(names)
  return names, packages
end

--- Checks a block. Returns `{ version, pnpm, target, packages, devPackages, pinnedFrom, overrides }`,
--- each package list as `{ names = sorted, ranges = name -> range }`.
local function spec_of(config, version)
  reject_unknown_keys(config)
  local names, ranges = checked_packages(config, "packages")
  local dev_names, dev_ranges = checked_packages(config, "devPackages")
  for _, name in ipairs(dev_names) do
    if ranges[name] ~= nil then
      error(string.format('"%s" is in both "packages" and "devPackages", and pnpm keeps one', name), 0)
    end
  end
  return {
    version = version,
    pnpm = pnpm_of(config),
    target = target_of(config),
    packages = { names = names, ranges = ranges },
    devPackages = { names = dev_names, ranges = dev_ranges },
    pinnedFrom = config[output.PINNED_FROM],
    overrides = overrides.checked(config),
  }
end

local function read(context)
  return spec_of(config_of(context), version_of(context))
end

local function changed_names(list, pinned, out)
  for name, range in pairs(list.ranges) do
    if pinned[name] ~= range then out[#out + 1] = name end
  end
  for name in pairs(pinned) do
    if list.ranges[name] == nil then out[#out + 1] = name end
  end
end

local function stale(what)
  error(what .. " changed since the pins in " .. PIN_FILE .. " were resolved: run " .. RESOLVE .. " again", 0)
end

--- Refuses a build whose ranges have no pins, or pins resolved from other ranges, another pnpm or
--- other overrides: an ordinary build may not resolve, and the old closure would ignore the edit.
local function refuse_unpinned(spec, resolving)
  if resolving or (#spec.packages.names == 0 and #spec.devPackages.names == 0) then return end
  if spec.pinnedFrom == nil then
    error("these packages have no pins yet, and a build installs only pinned packages: run "
          .. RESOLVE .. ", which writes " .. PIN_FILE, 0)
  end
  local changed = {}
  changed_names(spec.packages, spec.pinnedFrom.packages or {}, changed)
  changed_names(spec.devPackages, spec.pinnedFrom.devPackages or {}, changed)
  table.sort(changed)
  if #changed > 0 then stale("the ranges of " .. table.concat(changed, ", ")) end
  if spec.pnpm.version ~= spec.pinnedFrom.pnpm then stale('"pnpm"') end
  if spec.overrides ~= spec.pinnedFrom.overrides then stale(overrides.KEY) end
end

return { read = read, spec_of = spec_of, refuse_unpinned = refuse_unpinned }
