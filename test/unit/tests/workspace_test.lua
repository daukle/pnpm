local expect = daukle.require("tests/expect")
local workspace = daukle.require("lib/workspace")

local function reads(name, text, wanted)
  return { name = name, check = function() return expect.equal(workspace.patch_files(text), wanted) end }
end

return {
  reads("a plain entry", "patchedDependencies:\n  ms@2.1.3: patches/ms.patch\n", { "patches/ms.patch" }),
  reads("a quoted value", "patchedDependencies:\n  ms@2.1.3: 'patches/ms.patch'\n", { "patches/ms.patch" }),
  reads("a quoted key holding a colon", "patchedDependencies:\n  'a@npm:b@1': patches/a.patch\n", { "patches/a.patch" }),
  reads("a trailing comment", "patchedDependencies:\n  ms@2.1.3: patches/ms.patch # why\n", { "patches/ms.patch" }),
  reads("a comment line holding a colon", "patchedDependencies:\n  # see: x\n  ms@2.1.3: patches/ms.patch\n", { "patches/ms.patch" }),
  reads("a carriage return", "patchedDependencies:\r\n  ms@2.1.3: patches/ms.patch\r\n", { "patches/ms.patch" }),
  reads("another key's lines", "catalog:\n  ms: 2.1.3\npatchedDependencies:\n  ms@2.1.3: p.patch\nother:\n  a: b\n", { "p.patch" }),
  reads("no block", "packages:\n  - 'a'\n", {}),
}
