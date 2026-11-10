local manifest = daukle.require("lib/manifest")

--- The derived directory a workspace is rebuilt in to resolve it.
local DIRECTORY = "resolve-workspace"

local WORKSPACE_FILE = "__daukle_pnpm_workspace__.yaml"
local PLACEMENTS_FILE = "__daukle_workspace__.json"
local LOCKFILE = "pnpm-lock.yaml"

local function generated_path(instance, name)
  return "build/daukle/" .. instance .. "/" .. name
end

local function generated_names(target)
  local names = {}
  for _, entry in ipairs(daukle.list("build/daukle/" .. target) or {}) do names[entry.name] = true end
  return names
end

--- The patch files a workspace file's `patchedDependencies` block names, relative to its root.
---
--- @implNote `pnpm_workspace.patch_files` in daukle/node already refused any other shape of this
--- block when it migrated or rendered the file.
local function patch_files(workspace_text)
  local files, inside = {}, false
  for line in string.gmatch(workspace_text .. "\n", "([^\n]*)\n") do
    if string.match(line, "^%S") then
      inside = string.match(line, "^patchedDependencies:") ~= nil
    elseif inside and string.match(line, "^%s*#") == nil then
      local value = string.match((string.gsub(line, "%s+#.*$", "")), ".*:%s+(.-)%s*$")
      local file = value and string.match(value, "^[\"']?(.-)[\"']?$")
      if file ~= nil and file ~= "" then files[#files + 1] = file end
    end
  end
  return files
end

local function package_root(context)
  return string.match(context.root, "^%.%./%.%./%.%./(.+)$") or "."
end

local function project_path(context, file)
  local root = package_root(context)
  return root == "." and file or (root .. "/" .. file)
end

local function write_file(name, text)
  daukle.write{ path = DIRECTORY .. "/" .. name, text = text }
end

--- The fields daukle/node carries on the root, read from the manifest because this block does not
--- hold them. A project whose only manifest is `daukle.lua` has no declarative text to read.
local function carried_fields(target)
  if string.match(daukle.manifest, "%.toml$") == nil then return nil end
  local toolchains = daukle.parse(daukle.read(daukle.manifest), daukle.manifest).toolchains or {}
  return toolchains[target] ~= nil and toolchains[target].packageFields or nil
end

local function root_identity(target, names)
  if not names["package.json"] then return nil end
  return daukle.json_parse(daukle.read(generated_path(target, "package.json")))
end

--- The workspace file with the block's own overrides line in place of the one daukle/node rendered
--- from the pins being replaced, which pnpm 11 and 12 would otherwise resolve against (D-285).
--- @implNote daukle/node writes that line as one `overrides: {...}` flow line and refuses it beside a
--- carried `overrides:` setting, so a block-form `overrides:` here is the user's and is kept.
local function with_current_overrides(workspace_text, spec)
  local text = string.gsub(workspace_text, "\noverrides: {[^\n]*\n", "\n")
  if spec.overrides == nil or not manifest.reads_workspace_settings(spec.pnpm.version) then return text end
  return text .. manifest.workspace_overrides(spec)
end

--- Rebuilds the workspace to resolve in `DIRECTORY`: this block's root ranges, each member's and
--- the workspace file as daukle/node generated them, its patch files and the lockfile it pinned.
---
--- @implNote the root's ranges are this block's, since daukle/node renders the root from the pins
--- being replaced. The old lockfile is kept so that an edited range moves only what it reaches,
--- as `pnpm install` does after an edit of package.json.
local function write(context, spec)
  local names = generated_names(spec.target)
  if not names[WORKSPACE_FILE] or not names[PLACEMENTS_FILE] then
    error('pnpm:resolve re-pins a workspace from what daukle/node generates for "' .. spec.target
          .. '", and that toolchain generated no workspace: "for" names it, and it needs a "workspace" key', 0)
  end
  local workspace_text = with_current_overrides(daukle.read(generated_path(spec.target, WORKSPACE_FILE)), spec)
  write_file("package.json", manifest.package_json(spec, root_identity(spec.target, names), carried_fields(spec.target)))
  write_file("pnpm-workspace.yaml", workspace_text)
  if names[LOCKFILE] then write_file(LOCKFILE, daukle.read(generated_path(spec.target, LOCKFILE))) end
  local placements = daukle.json_parse(daukle.read(generated_path(spec.target, PLACEMENTS_FILE)))
  for instance, directory in pairs(placements.members or {}) do
    write_file(directory .. "/package.json", daukle.read(generated_path(instance, "package.json")))
  end
  for _, file in ipairs(patch_files(workspace_text)) do
    write_file(file, daukle.read(project_path(context, file)))
  end
end

--- Empties `DIRECTORY`, so only the committed pins can seed a resolve.
local CLEAR_SCRIPT = "require('fs').rmSync('" .. DIRECTORY .. "', { recursive: true, force: true })"

return { DIRECTORY = DIRECTORY, CLEAR_SCRIPT = CLEAR_SCRIPT, patch_files = patch_files, write = write }
