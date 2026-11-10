daukle.plugin{ api = 1, uses = { "write" } }

daukle.toolchain{ name = "unit", generate = function() return {} end }

local SUITES = {
  lockfile_test = daukle.require("tests/lockfile_test"),
  workspace_test = daukle.require("tests/workspace_test"),
}
local SUITE_ORDER = { "lockfile_test", "workspace_test" }

daukle.task{
  name = "unit:test",
  run = function()
    local failures, count = {}, 0
    for _, suite in ipairs(SUITE_ORDER) do
      for _, case in ipairs(SUITES[suite]) do
        count = count + 1
        local problem = case.check()
        if problem ~= nil then failures[#failures + 1] = suite .. ": " .. case.name .. ": " .. problem end
      end
    end
    if #failures > 0 then
      error(#failures .. " of " .. count .. " failed:\n" .. table.concat(failures, "\n"), 0)
    end
    daukle.write{ path = "unit.txt", text = count .. " passed\n" }
  end,
}
