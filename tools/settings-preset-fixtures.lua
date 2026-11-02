#!/usr/bin/env lua
-- Offline checks for the hidden page's author keybinds.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixture-harness.lua")(repo, "settings-preset")
local assertContains = H.assertContains

local function read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end


-- A small game client: just the keybinds.
local bindings = { ["7"] = "ACTIONBUTTON7", F = "ASSISTTARGET", E = "STRAFERIGHT", X = "MACRO Mine" }
local refusedKeys = {}
local bindingWrites = 0
local savedBindingSet
local inCombat = false

GetBindingAction = function(key) return bindings[key] or "" end
SetBinding = function(key, action)
    if refusedKeys[key] then return false end
    bindingWrites = bindingWrites + 1
    bindings[key] = action
    return true
end
GetCurrentBindingSet = function() return 1 end
SaveBindings = function(set) savedBindingSet = set end
InCombatLockdown = function() return inCombat end

CarpenterDB = {}
Carpenter = { Client = { isForever = true } }
local ns = { Private = {} }
Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/SettingsPreset.lua"))("Carpenter", ns)
local preset = assert(ns.Private.SettingsPreset, "settings preset module did not load")

assert(preset.IsAvailable(), "Forever should show the author's keybinds")
Carpenter.Client.isForever = false
assert(not preset.IsAvailable(), "other clients should not get the Forever keybinds")
Carpenter.Client.isForever = true

-- Only keybinds: the game settings and action bars were dropped.
assert(preset.CVars == nil and preset.ActionBars == nil, "the preset should only carry keybinds")

local boundKeys = {}
for index, binding in ipairs(preset.Bindings) do
    assert(type(binding[1]) == "string" and type(binding[2]) == "string", "keybind " .. index .. " is malformed")
    assert(not boundKeys[binding[1]], binding[1] .. " is bound twice")
    boundKeys[binding[1]] = binding[2]
end
assert(#preset.Bindings == 53, "the author's Forever keybinds change 53 keys")
assert(boundKeys.E == "ACTIONBUTTON8" and boundKeys["7"] == "NONE" and boundKeys["'"] == "TOGGLERUN", "keybinds were copied wrong")

assert(not preset.IsApplied(), "different keybinds should read as unchecked")

local ok, result = preset.Restore()
assert(ok == false and result == "unchanged", "unchecking with nothing to put back should leave keybinds alone")

inCombat = true
ok, result = preset.Apply()
assert(ok == false and result == "combat", "keybinds must not change in combat")
assert(bindings.F == "ASSISTTARGET" and bindingWrites == 0, "a refused apply still changed keybinds")
inCombat = false

ok, result = preset.Apply()
assert(ok and result == "applied", "the author's keybinds did not apply")
assert(preset.IsApplied(), "applied keybinds should read as checked")
assert(bindings.F == "ACTIONBUTTON7" and bindings["7"] == nil and bindings.E == "ACTIONBUTTON8", "keybinds did not apply")
assert(bindings.X == "MACRO Mine", "keys outside the preset must keep their binding")
assert(savedBindingSet == 1, "keybinds were not saved to the current binding set")

local backup = assert(CarpenterDB.settingsPresetBackup, "the previous keybinds were not kept")
assert(backup.bindings.F == "ASSISTTARGET" and backup.bindings.Z == "NONE", "the backup lost the previous keybinds")

-- Applying again over the preset must not overwrite the backup with it.
local writesBefore = bindingWrites
preset.Apply()
assert(bindingWrites == writesBefore, "keybinds that already matched should not be written again")
assert(CarpenterDB.settingsPresetBackup.bindings.F == "ASSISTTARGET", "reapplying overwrote the backup")

ok, result = preset.Restore()
assert(ok and result == "restored", "unchecking did not restore the previous keybinds")
assert(bindings.F == "ASSISTTARGET" and bindings["7"] == "ACTIONBUTTON7" and bindings.Z == nil, "the previous keybinds did not come back")
assert(CarpenterDB.settingsPresetBackup == nil, "the backup should be cleared once restored")
assert(not preset.IsApplied(), "restored keybinds should read as unchecked")

refusedKeys.Q = true
ok, result = preset.Apply()
assert(ok == false and result == "partial", "a refused keybind should be reported")
assert(bindings.F == "ACTIONBUTTON7", "one refused keybind should not stop the rest")
refusedKeys.Q = nil
preset.Restore()

-- A backup from 1.8.10 and 1.8.11 also holds game settings; its keybinds
-- still come back.
CarpenterDB.settingsPresetBackup = { cvars = { graphicsQuality = "3" }, actionBars = 0, bindings = { F = "ASSISTTARGET" } }
bindings.F = "ACTIONBUTTON7"
ok, result = preset.Restore()
assert(ok and result == "restored" and bindings.F == "ASSISTTARGET", "an older backup's keybinds did not come back")

-- A backup left by the earlier Carpenter-settings version is not restored.
CarpenterDB.settingsPresetBackup = { hideMacroNamesEnabled = false }
ok, result = preset.Restore()
assert(ok == false and result == "unchanged", "an old-format backup must be ignored")

assertContains(read("Carpenter_Camelot.toc"), "Modules\\SettingsPreset.lua", "Forever keybinds load entry")
for _, toc in ipairs({ "Carpenter.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assert(not read(toc):find("Modules\\SettingsPreset.lua", 1, true), toc .. " must not load the Forever keybinds")
end

local config = read("config.lua")
assertContains(config, "AddToggle(L.SETTINGS_PRESET_NAME", "keybinds checkbox")
assertContains(config, "SettingsPreset.IsAvailable()", "Forever-only keybinds row")
-- The keybinds and the Edit Mode layout share one Settings section at the
-- top of the hidden page.
local settingsHeader = config:find("CreateHeader(L.SECTION_SETTINGS_PRESET", 1, true)
local settingsRow = config:find("AddToggle(L.SETTINGS_PRESET_NAME", 1, true)
local layoutRow = config:find("AddToggle(L.EDIT_MODE_LAYOUT_NAME", 1, true)
local macroHeader = config:find("for _, section in ipairs(MACRO_SECTIONS)", 1, true)
assert(settingsHeader and settingsRow and layoutRow and macroHeader, "hidden page sections are missing")
assert(settingsHeader < settingsRow and settingsRow < layoutRow and layoutRow < macroHeader,
    "the layout should sit under Settings, after the keybinds, at the top of the hidden page")
assert(not config:find("SECTION_EDIT_MODE_LAYOUT", 1, true), "the layout should not get a section of its own")

print("settings preset fixtures: passed")
