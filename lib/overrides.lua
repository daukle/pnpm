--- `overrides`: npm's own override object as one JSON text, written into the package.json
--- npm resolves from and nowhere else, since npm reads it only to compute the closure (D-246).
local object_text = daukle.require("lib/object_text")

local overrides = {}

overrides.KEY = "overrides"

--- The checked text, or nil when the block has none. Raises on anything but one JSON object.
function overrides.checked(config)
  return object_text.checked(config, overrides.KEY, "pnpm's override object", '{"ms": "2.1.2"}')
end

return overrides
