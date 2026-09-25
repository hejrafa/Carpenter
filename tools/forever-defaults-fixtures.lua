#!/usr/bin/env lua
-- Verifies Forever resets the old forced-on profile once, then preserves
-- settings normally now that the beta client restores SavedVariables.

local root = assert(arg[1], "usage: lua tools/forever-defaults-fixtures.lua <addon-root>")

SlashCmdList = {}
floor = math.floor
CarpenterDB = {}
Carpenter = {
    Client = { isRetail = true, isForever = true },
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

for key, value in pairs(Carpenter.Defaults) do
    if type(value) == "boolean" then
        CarpenterDB[key] = true
    end
end

Carpenter_InitializeSettings()

for key, value in pairs(Carpenter.Defaults) do
    if type(value) == "boolean" then
        assert(CarpenterDB[key] == false, key .. " should default off on Forever")
    end
end
assert(CarpenterDB.foreverDefaultsResetVersion == 1, "Forever defaults reset marker was not saved")

CarpenterDB.actionCamEnabled = true
CarpenterDB.minimapClutterEnabled = true
Carpenter_InitializeSettings()
assert(CarpenterDB.actionCamEnabled == true, "Forever Action Cam choice did not persist")
assert(CarpenterDB.minimapClutterEnabled == true, "Forever minimap choice did not persist")

Carpenter.Client.isForever = false
CarpenterDB = {}
Carpenter_InitializeSettings()
for key, value in pairs(Carpenter.Defaults) do
    assert(CarpenterDB[key] == value, key .. " did not use its normal default")
end
assert(CarpenterDB.foreverDefaultsResetVersion == nil, "non-Forever clients received the migration marker")

print("Forever defaults fixtures: passed")
