#!/usr/bin/env lua
-- Offline checks for the hidden page's author settings preset.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local function read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function assertContains(text, needle, label)
    assert(text:find(needle, 1, true), label .. " is missing")
end

SlashCmdList = {}
floor = math.floor
CarpenterDB = {}
Carpenter = { Client = { isForever = true } }

function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript() end
    return frame
end

local ns = { Private = {} }
assert(loadfile(repo .. "/Core/Carpenter.lua"))("Carpenter", ns)
assert(loadfile(repo .. "/Modules/SettingsPreset.lua"))("Carpenter", ns)
local preset = assert(ns.Private.SettingsPreset, "settings preset module did not load")

-- The preset only names real settings, and only ones it turns away from their
-- defaults.
local enabledCount = 0
for key, value in pairs(preset.Settings) do
    assert(Carpenter.Defaults[key] ~= nil, key .. " is not a Carpenter setting")
    assert(value ~= Carpenter.Defaults[key], key .. " repeats its default")
    enabledCount = enabledCount + 1
end
assert(enabledCount == 23, "the author's Forever settings turn on 23 options")
assert(preset.Settings.explorerModeEnabled == nil, "Explorer Mode is off in the author's settings")

local refreshes = 0
Carpenter.RefreshFeatures = function() refreshes = refreshes + 1 end
local inCombat = false
InCombatLockdown = function() return inCombat end

Carpenter_InitializeSettings()
CarpenterDB.explorerModeEnabled = true
CarpenterDB.autoCarrotSlot = 13
CarpenterDB.smartMacroLastItems = { kept = true }
assert(not preset.IsApplied(), "a different profile should read as unchecked")

local ok, result = preset.Restore()
assert(ok == false and result == "unchanged", "unchecking with nothing to put back should leave settings alone")
assert(CarpenterDB.explorerModeEnabled == true, "a refused restore still changed settings")

inCombat = true
ok, result = preset.Apply()
assert(ok == false and result == "combat", "the preset must not apply in combat")
assert(CarpenterDB.explorerModeEnabled == true and refreshes == 0, "a refused preset still changed settings")
inCombat = false

ok, result = preset.Apply()
assert(ok and result == "applied", "the preset did not apply")
assert(preset.IsApplied(), "an applied preset should read as checked")
assert(refreshes == 1, "applying the preset should refresh features once")
for key, default in pairs(Carpenter.Defaults) do
    local expected = preset.Settings[key]
    if expected == nil then expected = default end
    assert(CarpenterDB[key] == expected, key .. " does not match the author's settings")
end
assert(CarpenterDB.smartMacroLastItems.kept, "the preset touched state outside the settings")
local backup = assert(CarpenterDB.settingsPresetBackup, "the previous settings were not kept")
assert(backup.explorerModeEnabled == true and backup.autoCarrotSlot == 13, "the backup lost the previous settings")

-- Applying again over the preset must not overwrite the backup with it.
preset.Apply()
assert(CarpenterDB.settingsPresetBackup.explorerModeEnabled == true, "reapplying the preset overwrote the backup")

ok, result = preset.Restore()
assert(ok and result == "restored", "unchecking did not restore the previous settings")
assert(CarpenterDB.explorerModeEnabled == true and CarpenterDB.autoCarrotSlot == 13, "the previous settings did not come back")
assert(CarpenterDB.hideMacroNamesEnabled == false, "restoring left a preset setting behind")
assert(CarpenterDB.settingsPresetBackup == nil, "the backup should be cleared once restored")
assert(not preset.IsApplied(), "restored settings should read as unchecked")

for _, toc in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assertContains(read(toc), "Modules\\SettingsPreset.lua", toc .. " settings preset load entry")
end

local config = read("config.lua")
assertContains(config, "AddToggle(L.SETTINGS_PRESET_NAME", "settings preset checkbox")
assert(config:find("SECTION_SETTINGS_PRESET", 1, true) < config:find("SECTION_EDIT_MODE_LAYOUT or", 1, true),
    "the settings section should sit at the top of the hidden page")

print("settings preset fixtures: passed")
