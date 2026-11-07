--- A restricted reader of the `packages:` block of pnpm-lock.yaml versions 6.0 and 9.0, the one part the pins need.
---
--- @implNote daukle parses no YAML, and pnpm writes this block in one fixed shape: a two-space
--- key per package and four-space fields under it, `resolution` and the platform lists in flow
--- style. A line outside that shape is refused by name rather than guessed at, so a lockfile a
--- later pnpm writes differently fails loudly instead of pinning the wrong closure.
local lockfile = {}

local SUPPORTED_VERSIONS = { "6.0", "9.0" }
local REGISTRY = "https://registry.npmjs.org/"

local function is_supported(version)
  for _, supported in ipairs(SUPPORTED_VERSIONS) do
    if supported == version then return true end
  end
  return false
end

--- A version 6.0 `packages:` key as `name@version`: version 6.0 writes a leading `/` and a
--- trailing `(peer@x)` suffix, and the tarball is the same with or without the suffix.
local function without_version_6_decoration(key)
  local bare = string.gsub(key, "^/", "")
  return (string.gsub(bare, "%(.*$", ""))
end

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

local function is_directory_resolution(text)
  local body = string.match(text, "^{(.*)}$")
  return body ~= nil and string.match(body, "^directory: [^,]+, type: directory$") ~= nil
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

--- The registry url pnpm fetches a package from, which versions 6.0 and 9.0 imply rather than write.
local function registry_url(name, version)
  local unscoped = string.match(name, "^@[^/]+/(.+)$") or name
  return REGISTRY .. name .. "/-/" .. unscoped .. "-" .. version .. ".tgz"
end

--- The entry with its url, or nil for a project directory, which has nothing to fetch.
local function finished(entry)
  if entry.is_directory then return nil end
  entry.name, entry.version = name_and_version(entry.path)
  if entry.integrity == nil then error('"' .. entry.path .. '" has no resolution', 0) end
  entry.url = registry_url(entry.name, entry.version)
  return entry
end

local function keep(out, entry)
  local finished_entry = finished(entry)
  if finished_entry ~= nil then out[#out + 1] = finished_entry end
end

--- Every package of the lockfile's `packages:` block, sorted by key, as
--- `{ path, name, version, url, integrity, os, cpu, libc }`.
function lockfile.entries(text)
  local version = string.match(text, "^lockfileVersion: '([^']+)'")
  if not is_supported(version) then
    error("the lockfile is version " .. tostring(version) .. ", and this plugin reads versions "
          .. table.concat(SUPPORTED_VERSIONS, " and ") .. ", which pnpm 8 and later write", 0)
  end
  local block = string.match(text, "\npackages:\n(.-)\n%a[%w]*:\n") or string.match(text, "\npackages:\n(.*)$") or ""
  local out, current, seen = {}, nil, {}
  for line in string.gmatch(block .. "\n", "([^\n]*)\n") do
    line = string.gsub(line, "\r$", "")
    local key = string.match(line, "^  ([^%s].*):$")
    local field, value = string.match(line, "^    ([%a]+): (.+)$")
    if key ~= nil then
      if current ~= nil then keep(out, current) end
      local path = unquoted(key)
      if version == "6.0" then path = without_version_6_decoration(path) end
      if seen[path] then
        current = nil
      else
        seen[path] = true
        current = { path = path }
      end
    elseif field == "resolution" and current ~= nil then
      if is_directory_resolution(value) then
        current.is_directory = true
      else
        current.integrity = resolution_of(current.path, value)
      end
    elseif (field == "os" or field == "cpu" or field == "libc") and current ~= nil then
      current[field] = flow_list(value)
      if current[field] == nil then error('"' .. current.path .. '" lists its ' .. field .. " in a shape this reader does not know", 0) end
    end
  end
  if current ~= nil then keep(out, current) end
  table.sort(out, function(left, right) return left.path < right.path end)
  return out
end

return lockfile
