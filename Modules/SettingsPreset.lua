--[[ Carpenter - The author's own keybinds ]]
local _, ns = ...
ns.Private = ns.Private or {}

local SettingsPreset = ns.Private.SettingsPreset or {}
ns.Private.SettingsPreset = SettingsPreset

-- The author's WoW Forever keybinds, copied from the client's WTF folder.
-- Keybinds the way the client saves them: only keys that differ from
-- Blizzard's defaults, with NONE for a default key the author cleared.
SettingsPreset.Bindings = {
    { "BUTTON3", "MULTIACTIONBAR2BUTTON9" },
    { "Q", "MULTIACTIONBAR3BUTTON3" },
    { "E", "ACTIONBUTTON8" },
    { "Z", "TOGGLEPINGLISTENER" },
    { "NUMPADDIVIDE", "NONE" },
    { "R", "MULTIACTIONBAR3BUTTON2" },
    { "SHIFT-R", "MULTIACTIONBAR2BUTTON2" },
    { "6", "NONE" },
    { "7", "NONE" },
    { "8", "NONE" },
    { "9", "NONE" },
    { "0", "NONE" },
    { "-", "NONE" },
    { "=", "NONE" },
    { "CTRL-1", "MULTIACTIONBAR3BUTTON1" },
    { "CTRL-2", "MULTIACTIONBAR2BUTTON1" },
    { "CTRL-3", "MULTIACTIONBAR2BUTTON4" },
    { "CTRL-4", "ACTIONBUTTON6" },
    { "CTRL-5", "MULTIACTIONBAR1BUTTON6" },
    { "CTRL-6", "MULTIACTIONBAR3BUTTON9" },
    { "CTRL-7", "MULTIACTIONBAR3BUTTON4" },
    { "SHIFT-1", "MULTIACTIONBAR1BUTTON1" },
    { "SHIFT-2", "MULTIACTIONBAR1BUTTON2" },
    { "SHIFT-3", "MULTIACTIONBAR1BUTTON3" },
    { "SHIFT-4", "MULTIACTIONBAR1BUTTON4" },
    { "SHIFT-5", "MULTIACTIONBAR1BUTTON5" },
    { "SHIFT-6", "NONE" },
    { "SHIFT-UP", "NONE" },
    { "SHIFT-MOUSEWHEELUP", "NONE" },
    { "SHIFT-DOWN", "NONE" },
    { "SHIFT-MOUSEWHEELDOWN", "NONE" },
    { "G", "MULTIACTIONBAR3BUTTON8" },
    { "F", "ACTIONBUTTON7" },
    { "V", "MULTIACTIONBAR3BUTTON7" },
    { "SHIFT-V", "MULTIACTIONBAR2BUTTON7" },
    { "T", "ACTIONBUTTON9" },
    { "SHIFT-T", "MULTIACTIONBAR1BUTTON9" },
    { "C", "MULTIACTIONBAR3BUTTON6" },
    { "B", "OPENALLBAGS" },
    { "SHIFT-B", "NONE" },
    { "Y", "TOGGLECHARACTER0" },
    { "MOUSEWHEELUP", "ACTIONPAGE1" },
    { "MOUSEWHEELDOWN", "ACTIONPAGE2" },
    { "SHIFT-C", "MULTIACTIONBAR2BUTTON6" },
    { "CTRL-MOUSEWHEELUP", "CAMERAZOOMIN" },
    { "CTRL-MOUSEWHEELDOWN", "CAMERAZOOMOUT" },
    { "SHIFT-F", "MULTIACTIONBAR1BUTTON7" },
    { "SHIFT-E", "MULTIACTIONBAR1BUTTON8" },
    { "SHIFT-Q", "MULTIACTIONBAR2BUTTON3" },
    { "SHIFT-G", "MULTIACTIONBAR2BUTTON8" },
    { "SHIFT-BUTTON3", "STARTAUTORUN" },
    { ";", "TOGGLESHEATH" },
    { "'", "TOGGLERUN" },
}

local presetBindings = {}
for _, binding in ipairs(SettingsPreset.Bindings) do
    presetBindings[binding[1]] = binding[2]
end

function SettingsPreset.IsAvailable()
    return Carpenter and Carpenter.Client and Carpenter.Client.isForever == true
end

local function ReadBinding(key)
    if not GetBindingAction then return nil end
    local action = GetBindingAction(key)
    if action == "" then return "NONE" end
    return action
end

local function WriteBinding(key, action)
    if ReadBinding(key) == action then return true end
    if not SetBinding then return false end
    if action == "NONE" then action = nil end
    local ok, result = pcall(SetBinding, key, action)
    return ok and result ~= false
end

function SettingsPreset.IsApplied()
    for _, binding in ipairs(SettingsPreset.Bindings) do
        if ReadBinding(binding[1]) ~= binding[2] then
            return false
        end
    end
    return true
end

-- Returns how many keybinds the game turned down.
local function WriteBindings(bindings)
    local refused = 0
    for _, binding in ipairs(SettingsPreset.Bindings) do
        local action = bindings[binding[1]]
        if action ~= nil and not WriteBinding(binding[1], action) then
            refused = refused + 1
        end
    end
    if SaveBindings and GetCurrentBindingSet then
        pcall(SaveBindings, GetCurrentBindingSet())
    end
    return refused
end

-- Keeps every keybind the preset is about to change, so unchecking it can put
-- it back.
local function TakeBackup()
    local backup = { bindings = {} }
    for _, binding in ipairs(SettingsPreset.Bindings) do
        backup.bindings[binding[1]] = ReadBinding(binding[1])
    end
    return backup
end

function SettingsPreset.Apply()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if type(CarpenterDB) ~= "table" then
        return false, "failed"
    end

    if not SettingsPreset.IsApplied() then
        CarpenterDB.settingsPresetBackup = TakeBackup()
    end
    if WriteBindings(presetBindings) > 0 then
        return false, "partial"
    end
    return true, "applied"
end

-- Backups from before the game settings were dropped also hold CVars and
-- action bars; only their keybinds come back.
function SettingsPreset.Restore()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if type(CarpenterDB) ~= "table" then
        return false, "failed"
    end

    local backup = CarpenterDB.settingsPresetBackup
    if type(backup) ~= "table" or type(backup.bindings) ~= "table" then
        return false, "unchanged"
    end
    local refused = WriteBindings(backup.bindings)
    CarpenterDB.settingsPresetBackup = nil
    if refused > 0 then
        return false, "partial"
    end
    return true, "restored"
end
