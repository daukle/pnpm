--- The pnpm releases this plugin runs, each pnpm's own npm tarball pinned by sha256. pnpm runs from
--- `package/bin/pnpm.cjs` with the provisioned node, so one tarball serves every host.
local releases = {}

local RELEASES = {
  { version = "8.9.2", sha256 = "8d62573d93061f2722b7b48c9739e96cd4603c3ab153bc81c619dcb9861a214e" },
  { version = "9.15.9", sha256 = "cf86a7ad764406395d4286a6d09d730711720acc6d93e9dce9ac7ac4dc4a28a7" },
  { version = "10.0.0", sha256 = "43abf6e720fb7bc53c591b0862605c7d323d0a9d2dd33bcac07b062e13cf4948" },
  { version = "10.33.4", sha256 = "8e70ddc6649b18bc3d895cf3a908c0291ea4c38039ad8722c47e018daf1e9cfc" },
  { version = "10.34.9", sha256 = "7e8a946108e7baab119e51d27c24d6178b46545422643dbc91e34e2f1ee32e0f" },
  { version = "11.25.0", sha256 = "33dd0748f27e7916c4f1c8b6943461983e3453b06bbda6312a6280130b4881e5" },
  { version = "11.28.5", sha256 = "1ef4e447a68713656064f3f174c0f44719960a043a3fe2299169d08cf1dbf8ee" },
}

releases.ENTRY = "package/bin/pnpm.cjs"

local function pinned_versions()
  local out = {}
  for index, release in ipairs(RELEASES) do out[index] = release.version end
  return table.concat(out, ", ")
end

--- Whether this plugin pins `version`, for a caller that must answer with a blocker, not raise.
function releases.is_pinned(version)
  for _, release in ipairs(RELEASES) do
    if release.version == version then return true end
  end
  return false
end

releases.pinned_versions = pinned_versions

--- The pinned release of `version`, as `{ version, url, sha256 }`. Raises naming the pinned ones.
function releases.of(version)
  for _, release in ipairs(RELEASES) do
    if release.version == version then
      return { version = version, sha256 = release.sha256,
               url = "https://registry.npmjs.org/pnpm/-/pnpm-" .. version .. ".tgz" }
    end
  end
  error('pnpm "' .. tostring(version) .. '" is not a release this plugin pins; it pins ' .. pinned_versions(), 0)
end

--- The pnpm version a `"packageManager"` value names, or nil when it names another manager.
---
--- @implNote corepack's `+sha512.<hex>` suffix is dropped: the release is pinned here by sha256.
function releases.from_package_manager(value)
  if type(value) ~= "string" then return nil end
  return string.match(value, "^pnpm@(%d+%.%d+%.%d+)$") or string.match(value, "^pnpm@(%d+%.%d+%.%d+)%+")
end

return releases
