--- The pnpm releases this plugin runs. Before 12 each is pnpm's own npm tarball pinned by sha256,
--- run from `package/bin/pnpm.cjs` with the provisioned node, so one tarball serves every host.
--- From 12 pnpm is a native binary per host, each `@pnpm/exe.<target>` tarball pinned by sha256.
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

--- Digests of each `@pnpm/exe.<target>` tarball, by daukle's `os/arch`.
---
--- @implNote 12.0 to 12.6 are deliberately absent: measured, they ignore `--modules-dir` for a
--- project's own modules, so nothing keeps them under `build/`, and a link in its place dangles.
local NATIVE_RELEASES = {
  ["12.18.0"] = {
    ["linux/x86_64"] = "679df2eedf158f639db6d1f00e713d766d0d7afc6a931bc51497a625d1e1bdf7",
    ["linux/aarch64"] = "2e326930b9b670712df1c93849d725c85f6b897cdf9239ee724b587c50ddd5bc",
    ["windows/x86_64"] = "492a9087c3489069727f7ba03c95faf41651a39f60872c9b4542397b48c45738",
    ["windows/aarch64"] = "3df31e477305717b457653738a61bc02f5c843b69c13e01ff36873f892b25377",
    ["macos/x86_64"] = "0c27f789778383d617abec146293db8ad871de119d1747c6177c06363d9bc8fe",
    ["macos/aarch64"] = "755615cb521051e182a8c1eb80478466b72d0652b2baa36515c99089daabc82e",
  },
}

local NATIVE_ORDER = { "12.18.0" }
local TARGET_OS = { linux = "linux", macos = "darwin", windows = "win32" }
local TARGET_ARCH = { x86_64 = "x64", aarch64 = "arm64" }

releases.ENTRY = "package/bin/pnpm.cjs"

local function pinned_versions()
  local out = {}
  for index, release in ipairs(RELEASES) do out[index] = release.version end
  for _, version in ipairs(NATIVE_ORDER) do out[#out + 1] = version end
  return table.concat(out, ", ")
end

--- Whether this plugin pins `version`, for a caller that must answer with a blocker, not raise.
function releases.is_pinned(version)
  if NATIVE_RELEASES[version] ~= nil then return true end
  for _, release in ipairs(RELEASES) do
    if release.version == version then return true end
  end
  return false
end

releases.pinned_versions = pinned_versions

--- Each host's binary of a native release, by `os/arch`, as `{ url, sha256, file }`.
local function native_binaries(version)
  local binaries = {}
  for host, sha256 in pairs(NATIVE_RELEASES[version]) do
    local os, arch = string.match(host, "^(.-)/(.-)$")
    local target = TARGET_OS[os] .. "-" .. TARGET_ARCH[arch]
    binaries[host] = { sha256 = sha256, file = os == "windows" and "package/pnpm.exe" or "package/pnpm",
                       url = "https://registry.npmjs.org/@pnpm/exe." .. target .. "/-/exe." .. target .. "-"
                             .. version .. ".tgz" }
  end
  return binaries
end

--- The binary of a native release for `host`, a `{ os, arch }`, or a raise naming the host.
function releases.binary_for(pnpm, host)
  local binary = pnpm.binaries[tostring(host.os) .. "/" .. tostring(host.arch)]
  if binary ~= nil then return binary end
  error(string.format("pnpm %s has no pinned binary for this host (%s %s)", pnpm.version, tostring(host.os),
                      tostring(host.arch)), 0)
end

--- The pinned release of `version`, as `{ version, url, sha256 }`, or `{ version, binaries }` for a
--- native release. Raises naming the pinned ones.
function releases.of(version)
  if NATIVE_RELEASES[version] ~= nil then return { version = version, binaries = native_binaries(version) } end
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
