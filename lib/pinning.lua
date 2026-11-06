local lockfile = daukle.require("lib/lockfile")
local output = daukle.require("lib/output")

--- The text of daukle/pnpm/lock.lua for a lockfile: every entry, every platform
--- included, pinned by the sha256 of its tarball. Only a --resolve run may call it.
local function pin_file(spec, instance, lock_text)
  local entries = lockfile.entries(lock_text)
  for index = 1, #entries do
    local entry = entries[index]
    entry.sha256 = daukle.pin{ url = entry.url, as = entry.name .. " " .. tostring(entry.version) }.sha256
  end
  return output.render(spec, instance, lock_text, entries)
end

return { pin_file = pin_file }
