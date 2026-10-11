#!/usr/bin/env lua
-- Verifies the feature registry: several modules can share an option key, and
-- toggling the option enables or disables each of them exactly once.

local root = assert(arg[1], "usage: lua tools/feature-registry-fixtures.lua <addon-root>")

SlashCmdList = {}
floor = math.floor
CarpenterDB = {}
Carpenter = {
    Client = { isRetail = true },
}

function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript() end
    return frame
end

local coreChunk = assert(loadfile(root .. "/Core/Carpenter.lua"))
coreChunk("Carpenter", { Private = {} })

-- Treat every key as available so IsEnabled reads CarpenterDB directly.
Carpenter.IsFeatureAvailable = function() return true end

local calls = {}
local function TrackingModule(name)
    return {
        Enable = function() calls[#calls + 1] = name .. ":on" end,
        Disable = function() calls[#calls + 1] = name .. ":off" end,
    }
end

Carpenter:RegisterFeature("cleanUpUnitFramesEnabled", TrackingModule("cleaner"))
Carpenter:RegisterFeature("cleanUpUnitFramesEnabled", TrackingModule("combatText"))
Carpenter:RegisterFeature("hideErrorMessagesEnabled", { Enable = function() calls[#calls + 1] = "errors:on" end })

-- Startup with everything off calls nothing.
CarpenterDB.cleanUpUnitFramesEnabled = false
CarpenterDB.hideErrorMessagesEnabled = false
Carpenter:RefreshFeatures()
assert(#calls == 0, "disabled features should not be called at startup")

-- Turning an option on enables every module registered for it, once.
CarpenterDB.cleanUpUnitFramesEnabled = true
Carpenter:RefreshFeature("cleanUpUnitFramesEnabled")
Carpenter:RefreshFeature("cleanUpUnitFramesEnabled")
assert(table.concat(calls, ",") == "cleaner:on,combatText:on", "expected both modules enabled once, got " .. table.concat(calls, ","))

-- Turning it off disables both.
calls = {}
CarpenterDB.cleanUpUnitFramesEnabled = false
Carpenter:RefreshFeature("cleanUpUnitFramesEnabled")
assert(table.concat(calls, ",") == "cleaner:off,combatText:off", "expected both modules disabled, got " .. table.concat(calls, ","))

-- A module without Disable is fine to turn off.
calls = {}
CarpenterDB.hideErrorMessagesEnabled = true
Carpenter:RefreshFeature("hideErrorMessagesEnabled")
CarpenterDB.hideErrorMessagesEnabled = false
Carpenter:RefreshFeature("hideErrorMessagesEnabled")
assert(table.concat(calls, ",") == "errors:on", "expected only the enable call, got " .. table.concat(calls, ","))

print("feature registry fixtures: passed")
