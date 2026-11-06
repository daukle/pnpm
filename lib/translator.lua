local settings = daukle.require("lib/settings")
local pinning = daukle.require("lib/pinning")
local output = daukle.require("lib/output")
local releases = daukle.require("lib/releases")

--- The pnpm instance written for a node instance: `node` gives `pnpm`, `node-web` gives `pnpm-web`,
--- so two node instances of one project never meet in one pnpm block.
local function instance_for(node_instance)
  if node_instance == "node" then return "pnpm" end
  local suffix = string.match(node_instance, "^node(%-.+)$")
  return "pnpm" .. (suffix or ("-" .. node_instance))
end

local SURFACE = "NPM-SURFACE.md: dependencies"

local function block_of(foreign)
  local config = foreign.config or {}
  local block = { version = config.version, pnpm = config.pnpm, packages = config.packages,
                  devPackages = config.devPackages, overrides = config.overrides }
  if foreign.instance ~= "node" then block["for"] = foreign.instance end
  return block, config.lock
end

local function unresolved(manifest)
  return {
    manifest = manifest,
    blockers = { {
      construct = "dependencies",
      where = "package.json",
      why = "pinning them fetches every package once to compute its sha256, which only a"
            .. ' resolve run may do: run "daukle migrate --resolve"',
      surface = SURFACE,
    } },
  }
end

local function unpinned(manifest, version)
  return {
    manifest = manifest,
    blockers = { {
      construct = '"packageManager"',
      where = "package.json",
      why = 'names pnpm "' .. tostring(version) .. '", a release daukle/pnpm does not pin; it pins '
            .. releases.pinned_versions(),
      surface = SURFACE,
    } },
  }
end

--- Translates the dependencies daukle/node's migrator found in a pnpm project into the pnpm block
--- and, in a --resolve run, the pin file of the committed pnpm-lock.yaml it handed over, so the
--- migrated project installs exactly the closure the old one did.
local function translate(foreign)
  local block, lock_text = block_of(foreign)
  local instance = instance_for(foreign.instance)
  local pinned = releases.is_pinned(block.pnpm)
  local spec = pinned and settings.spec_of(block, block.version) or nil
  if instance ~= "pnpm" then block.toolchain = "pnpm" end
  local manifest = { toolchains = { [instance] = block } }
  if not pinned then return unpinned(manifest, block.pnpm) end
  if not foreign.resolving then return unresolved(manifest) end
  if type(lock_text) ~= "string" then
    error("daukle/node's migrator handed over no pnpm-lock.yaml, so there is no closure to pin", 0)
  end
  return {
    manifest = manifest,
    blockers = {},
    files = { { path = "daukle/" .. instance .. "/" .. output.OUTPUT,
                text = pinning.pin_file(spec, instance, lock_text) } },
  }
end

return { translate = translate }
