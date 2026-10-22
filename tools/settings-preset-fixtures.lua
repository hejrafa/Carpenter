#!/usr/bin/env lua
-- Offline checks for the hidden page's author game settings and keybinds.

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

-- A small game client: CVars, keybinds, and the action bar toggles.
local cvars = {
    graphicsQuality = "3",
    graphicsShadowQuality = "1",
    Sound_MasterVolume = "1",
    nameplateStyle = "0",
    nameplateMinAlpha = "0.6",
}
local refusedCVars = {}
local cvarWrites = {}
local bindings = { ["7"] = "ACTIONBUTTON7", F = "ASSISTTARGET", E = "STRAFERIGHT", X = "MACRO Mine" }
local toggles = { false, false, false, false, false, false, false }
local savedBindingSet
local inCombat = false

C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value)
        if refusedCVars[name] or cvars[name] == nil then return false end
        cvarWrites[#cvarWrites + 1] = name
        cvars[name] = tostring(value)
        -- Overall quality presets the individual options, like the client.
        if name == "graphicsQuality" then cvars.graphicsShadowQuality = tostring(value) end
        return true
    end,
}
GetBindingAction = function(key) return bindings[key] or "" end
SetBinding = function(key, action)
    bindings[key] = action
    return true
end
GetCurrentBindingSet = function() return 1 end
SaveBindings = function(set) savedBindingSet = set end
GetActionBarToggles = function() return unpack(toggles, 1, 7) end
SetActionBarToggles = function(...)
    assert(select("#", ...) == 7, "action bar toggles need all seven bars")
    toggles = { ... }
end
InCombatLockdown = function() return inCombat end
unpack = unpack or table.unpack

CarpenterDB = {}
Carpenter = { Client = { isForever = true } }
local ns = { Private = {} }
assert(loadfile(repo .. "/Modules/SettingsPreset.lua"))("Carpenter", ns)
local preset = assert(ns.Private.SettingsPreset, "settings preset module did not load")

assert(preset.IsAvailable(), "Forever should show the author's game settings")
Carpenter.Client.isForever = false
assert(not preset.IsAvailable(), "other clients should not get the Forever game settings")
Carpenter.Client.isForever = true

-- The preset's shape: settings only, quality ahead of what it presets.
local seen, positions = {}, {}
for index, cvar in ipairs(preset.CVars) do
    local name, value = cvar[1], cvar[2]
    assert(type(name) == "string" and type(value) == "string", "CVar " .. index .. " is malformed")
    assert(not seen[name], name .. " is listed twice")
    seen[name], positions[name] = true, index
    assert(not name:match("^CACHE%-") and not name:match("^Gx"), name .. " is machine state, not a setting")
end
for _, name in ipairs({ "graphicsQuality", "uiScale", "Sound_MasterVolume", "nameplateStyle", "autoLootDefault", "raidFramesHealthText" }) do
    assert(seen[name], name .. " is missing from the author's settings")
end
for _, name in ipairs({ "textLocale", "portal", "agentUID", "flaggedTutorials", "CameraKeepCharacterCentered", "cameraSmoothStyle", "enableMultiActionBars" }) do
    assert(not seen[name], name .. " should stay out of the author's settings")
end
assert(positions.graphicsQuality == 1, "overall graphics quality must apply first")
assert(positions.RAIDgraphicsQuality < positions.raidGraphicsShadowQuality, "raid quality must apply before its options")
assert(preset.ActionBars == 7, "the author shows action bars 2, 3, and 4")

local boundKeys = {}
for index, binding in ipairs(preset.Bindings) do
    assert(type(binding[1]) == "string" and type(binding[2]) == "string", "keybind " .. index .. " is malformed")
    assert(not boundKeys[binding[1]], binding[1] .. " is bound twice")
    boundKeys[binding[1]] = binding[2]
end
assert(#preset.Bindings == 53, "the author's Forever keybinds change 53 keys")
assert(boundKeys.E == "ACTIONBUTTON8" and boundKeys["7"] == "NONE" and boundKeys["'"] == "TOGGLERUN", "keybinds were copied wrong")

-- Every CVar the fake client knows starts out different from the preset.
for _, cvar in ipairs(preset.CVars) do
    if cvars[cvar[1]] == nil then cvars[cvar[1]] = "?" end
end
cvars.uiScale = "0.75000001"
assert(not preset.IsApplied(), "a different setup should read as unchecked")

local ok, result = preset.Restore()
assert(ok == false and result == "unchanged", "unchecking with nothing to put back should leave settings alone")

inCombat = true
ok, result = preset.Apply()
assert(ok == false and result == "combat", "the game settings must not change in combat")
assert(bindings.F == "ASSISTTARGET" and #cvarWrites == 0, "a refused apply still changed settings")
inCombat = false

ok, result = preset.Apply()
assert(ok and result == "applied", "the author's settings did not apply")
assert(preset.IsApplied(), "applied settings should read as checked")
for _, cvar in ipairs(preset.CVars) do
    assert(cvars[cvar[1]] == cvar[2] or cvar[1] == "uiScale", cvar[1] .. " did not get the author's value")
end
for _, name in ipairs(cvarWrites) do
    assert(name ~= "uiScale", "a value that already matched should not be written again")
end
assert(cvars.graphicsShadowQuality == "3", "graphics quality overwrote the shadow setting applied after it")
assert(bindings.F == "ACTIONBUTTON7" and bindings["7"] == nil and bindings.E == "ACTIONBUTTON8", "keybinds did not apply")
assert(bindings.X == "MACRO Mine", "keys outside the preset must keep their binding")
assert(toggles[1] and toggles[2] and toggles[3] and not toggles[4], "action bars 2, 3, and 4 should be shown")
assert(savedBindingSet == 1, "keybinds were not saved to the current binding set")

local backup = assert(CarpenterDB.settingsPresetBackup, "the previous settings were not kept")
assert(backup.cvars.nameplateStyle == "0" and backup.bindings.F == "ASSISTTARGET" and backup.bindings.Z == "NONE", "the backup lost the previous settings")
assert(backup.actionBars == 0, "the backup lost the previous action bars")

-- Applying again over the preset must not overwrite the backup with it.
preset.Apply()
assert(CarpenterDB.settingsPresetBackup.cvars.nameplateStyle == "0", "reapplying overwrote the backup")

ok, result = preset.Restore()
assert(ok and result == "restored", "unchecking did not restore the previous settings")
assert(cvars.nameplateStyle == "0" and cvars.graphicsQuality == "3", "the previous CVars did not come back")
assert(bindings.F == "ASSISTTARGET" and bindings["7"] == "ACTIONBUTTON7" and bindings.Z == nil, "the previous keybinds did not come back")
assert(not toggles[1] and not toggles[2] and not toggles[3], "the previous action bars did not come back")
assert(CarpenterDB.settingsPresetBackup == nil, "the backup should be cleared once restored")
assert(not preset.IsApplied(), "restored settings should read as unchecked")

refusedCVars.Sound_MasterVolume = true
ok, result = preset.Apply()
assert(ok == false and result == "partial", "a refused CVar should be reported")
assert(bindings.F == "ACTIONBUTTON7", "one refused CVar should not stop the rest")
refusedCVars.Sound_MasterVolume = nil

-- A backup left by the earlier Carpenter-settings version is not restored.
CarpenterDB.settingsPresetBackup = { hideMacroNamesEnabled = false }
ok, result = preset.Restore()
assert(ok == false and result == "unchanged", "an old-format backup must be ignored")

assertContains(read("Carpenter_Camelot.toc"), "Modules\\SettingsPreset.lua", "Forever settings preset load entry")
for _, toc in ipairs({ "Carpenter.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assert(not read(toc):find("Modules\\SettingsPreset.lua", 1, true), toc .. " must not load the Forever game settings")
end

local config = read("config.lua")
assertContains(config, "AddToggle(L.SETTINGS_PRESET_NAME", "game settings checkbox")
assertContains(config, "SettingsPreset.IsAvailable()", "Forever-only game settings section")
assert(config:find("SECTION_SETTINGS_PRESET", 1, true) < config:find("SECTION_EDIT_MODE_LAYOUT or", 1, true),
    "the settings section should sit at the top of the hidden page")

print("settings preset fixtures: passed")
