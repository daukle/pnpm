local lockfile = daukle.require("lib/lockfile")
local expect = daukle.require("tests/expect")

local INTEGRITY = "resolution: {integrity: sha512-AAAA}"

local function lockfile_text(version, packages)
  return "lockfileVersion: '" .. version .. "'\n\npackages:\n\n" .. packages
end

local function entry_block(key, resolution)
  return "  " .. key .. ":\n    " .. resolution .. "\n\n"
end

local function reads(name, version, packages, wanted)
  return { name = name, check = function()
    local entries = lockfile.entries(lockfile_text(version, packages))
    local rows = {}
    for index, entry in ipairs(entries) do rows[index] = entry.path .. " " .. entry.url end
    return expect.equal(rows, wanted)
  end }
end

return {
  reads("a 6.0 key with several peer groups gives the bare version", "6.0",
    entry_block("/a@1.0.0(b@1.0.0)(c@2.0.0)", INTEGRITY),
    { "a@1.0.0 https://registry.npmjs.org/a/-/a-1.0.0.tgz" }),
  reads("a scoped 6.0 key loses its slash", "6.0",
    entry_block("/@s/a@1.0.0(b@1.0.0)", INTEGRITY),
    { "@s/a@1.0.0 https://registry.npmjs.org/@s/a/-/a-1.0.0.tgz" }),
  reads("6.0 keys differing only by peer suffix are one entry", "6.0",
    entry_block("/a@1.0.0(b@1.0.0)", INTEGRITY) .. entry_block("/a@1.0.0(b@1.0.0)(c@2.0.0)", INTEGRITY),
    { "a@1.0.0 https://registry.npmjs.org/a/-/a-1.0.0.tgz" }),
  reads("a 6.0 file: directory entry is skipped", "6.0",
    entry_block("/a@1.0.0", INTEGRITY) .. "  'file:':\n    resolution: {directory: '', type: directory}\n    name: vue\n\n",
    { "a@1.0.0 https://registry.npmjs.org/a/-/a-1.0.0.tgz" }),
  reads("a 9.0 directory entry is skipped", "9.0",
    entry_block("a@1.0.0", INTEGRITY) .. entry_block("vue@file:../..", "resolution: {directory: ../.., type: directory}"),
    { "a@1.0.0 https://registry.npmjs.org/a/-/a-1.0.0.tgz" }),
}
