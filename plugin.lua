--- daukle/pnpm: turning a pnpm project's version ranges into a closure pinned by sha256.
---
--- pnpm computes the closure, because a closure computed any other way would differ from pnpm's
--- on some project; this plugin pins it and writes the pins where daukle/node installs them from.
--- It is to pnpm what daukle/npm is to npm. D-251.

daukle.plugin{
  api = 8,
  uses = { "provision", "exec", "write", "pin", "json_parse" },
  --[[ The node release table is daukle/node's and is read rather than copied, so pnpm runs on the
       same node as the build. lib/runtimes calls no verb, so the rule that a required module runs
       under the DEPENDENT's uses has nothing to cover. ]]
  requires = {
    node = {
      url = "https://github.com/daukle/node/releases/download/3.2.0/plugin.lua",
      sha256 = "a17e72aa646864a884f47cd4c1ebcb2793dcc44630dccc280e9ae374d53e8b05",
    },
  },
}

local runtimes = daukle.require("node:lib/runtimes")
local settings = daukle.require("lib/settings")
local manifest = daukle.require("lib/manifest")
local pinning = daukle.require("lib/pinning")
local output = daukle.require("lib/output")
local releases = daukle.require("lib/releases")
local translator = daukle.require("lib/translator")

--- Prints a file of the derived directory, since a task reads only project files.
local PRINT_LOCK = "process.stdout.write(require('fs').readFileSync('pnpm-lock.yaml', 'utf8'))"

daukle.toolchain{
  name = "pnpm",
  generate = function(context)
    settings.refuse_unpinned(settings.read(context), context.resolving)
    return {}
  end,
}

local function refuse_without_resolve(context)
  if not context.resolving then
    error('pnpm:resolve fetches every package of the closure, unpinned, to compute its sha256,'
          .. ' so it runs only as "daukle pnpm:resolve --resolve"', 0)
  end
end

--- @implNote resolving writes a package.json of this block's ranges alone, so its lockfile would
--- hold no member's importer and the next frozen install would fail.
local function refuse_a_workspace_root(spec)
  if not spec.workspace then return end
  error("pnpm:resolve resolves one package, and this block is a pnpm workspace root, whose lockfile"
        .. " also holds every member: re-pinning a workspace is not built, so its pins stay as its"
        .. " migration wrote them", 0)
end

--- The tool that runs the pinned pnpm and the words before pnpm's own: its native binary from 12,
--- otherwise the provisioned node and pnpm's entry script.
local function pnpm_command(context, spec, node)
  if spec.pnpm.binaries ~= nil then
    local binary = releases.binary_for(spec.pnpm, context.host)
    local root = daukle.provision{ url = binary.url, sha256 = binary.sha256, as = "pnpm " .. spec.pnpm.version }
    return root:tool(binary.file), {}
  end
  local root = daukle.provision{ url = spec.pnpm.url, sha256 = spec.pnpm.sha256, as = "pnpm " .. spec.pnpm.version }
  return node, { root:path(releases.ENTRY) }
end

local function provisioned_node(context, spec)
  local pick = runtimes.for_host{ os = context.host.os, arch = context.host.arch, version = spec.version }
  local root = daukle.provision{ url = pick.url, sha256 = pick.sha256, as = "node " .. pick.version }
  return root:tool(pick.node)
end

daukle.task{
  name = "pnpm:resolve",
  run = function(context)
    refuse_without_resolve(context)
    local spec = settings.read(context)
    refuse_a_workspace_root(spec)
    local node = provisioned_node(context, spec)
    local pnpm, argv = pnpm_command(context, spec, node)
    daukle.write{ path = "package.json", text = manifest.package_json(spec) }
    -- resolving must run none of the closure's code, which a preinstall script would
    for _, word in ipairs({ "install", "--lockfile-only", "--ignore-scripts", "--store-dir", "pnpm-store" }) do
      argv[#argv + 1] = word
    end
    daukle.exec(pnpm, argv)
    local lock_text = daukle.exec(node, { "-e", PRINT_LOCK }, { capture = true }).stdout
    return daukle.write{ path = output.OUTPUT,
                         text = pinning.pin_file(spec, context.toolchain.name, lock_text),
                         committed = true }
  end,
}

daukle.translator{ tool = "npm", id = "pnpm", translate = translator.translate }
