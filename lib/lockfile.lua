--- A restricted reader of pnpm-lock.yaml version 9's `packages:` block, the one part the pins need.
---
--- @implNote daukle parses no YAML, and pnpm writes this block in one fixed shape: a two-space
--- key per package and four-space fields under it, `resolution` and the platform lists in flow
--- style. A line outside that shape is refused by name rather than guessed at, so a lockfile a
--- later pnpm writes differently fails loudly instead of pinning the wrong closure.
local lockfile = {}

local SUPPORTED_VERSION = "9.0"
local REGISTRY = "https://registry.npmjs.org/"

local function unquoted(text)
  return string.match(text, "^'(.*)'$") or string.match(text, '^"(.*)"$') or text
end

--- `name` and `version` of a `name@version` key; a scoped name keeps its leading `@`.
local function name_and_version(key)
  local name, version = string.match(key, "^(@?[^@]+)@(.+)$")
  if name == nil then error('the lockfile names the package "' .. key .. '", which is not name@version', 0) end
  return name, version
end

local function flow_list(text)
  local body = string.match(text, "^%[(.*)%]$")
  if body == nil then return nil end
  local out = {}
  for item in string.gmatch(body, "[^,]+") do out[#out + 1] = unquoted(string.match(item, "^%s*(.-)%s*$")) end
  return out
end

local function resolution_of(key, text)
  local body = string.match(text, "^{(.*)}$")
  local integrity = body and string.match(body, "^integrity: ([%w%+/=%-]+)$")
  if integrity == nil then
    error('"' .. key .. '" resolves to ' .. text .. ', not to a registry tarball by its integrity:'
          .. " only a registry package can be pinned by its digest", 0)
  end
  return integrity
end

--- The registry url pnpm fetches a package from, which version 9 implies rather than writes.
local function registry_url(name, version)
  local unscoped = string.match(name, "^@[^/]+/(.+)$") or name
  return REGISTRY .. name .. "/-/" .. unscoped .. "-" .. version .. ".tgz"
end

local function finished(entry)
  if entry.integrity == nil then error('"' .. entry.path .. '" has no resolution', 0) end
  entry.url = registry_url(entry.name, entry.version)
  return entry
end

--- Every package of the lockfile's `packages:` block, sorted by key, as
--- `{ path, name, version, url, integrity, os, cpu, libc }`.
function lockfile.entries(text)
  local version = string.match(text, "^lockfileVersion: '([^']+)'")
  if version ~= SUPPORTED_VERSION then
    error("the lockfile is version " .. tostring(version) .. ", and this plugin reads version "
          .. SUPPORTED_VERSION .. ", which pnpm 9 and later write", 0)
  end
  local block = string.match(text, "\npackages:\n(.-)\n%a[%w]*:\n") or string.match(text, "\npackages:\n(.*)$") or ""
  local out, current = {}, nil
  for line in string.gmatch(block .. "\n", "([^\n]*)\n") do
    line = string.gsub(line, "\r$", "")
    local key = string.match(line, "^  ([^%s].*):$")
    local field, value = string.match(line, "^    ([%a]+): (.+)$")
    if key ~= nil then
      if current ~= nil then out[#out + 1] = finished(current) end
      local path = unquoted(key)
      local name, package_version = name_and_version(path)
      current = { path = path, name = name, version = package_version }
    elseif field == "resolution" and current ~= nil then
      current.integrity = resolution_of(current.path, value)
    elseif (field == "os" or field == "cpu" or field == "libc") and current ~= nil then
      current[field] = flow_list(value)
      if current[field] == nil then error('"' .. current.path .. '" lists its ' .. field .. " in a shape this reader does not know", 0) end
    end
  end
  if current ~= nil then out[#out + 1] = finished(current) end
  table.sort(out, function(left, right) return left.path < right.path end)
  return out
end

return lockfile
