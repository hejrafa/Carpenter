--[[ Carpenter - The author's own settings ]]
local _, ns = ...
ns.Private = ns.Private or {}

local SettingsPreset = ns.Private.SettingsPreset or {}
ns.Private.SettingsPreset = SettingsPreset

-- The author's WoW Forever settings. Every setting not listed here goes back
-- to its default, so applying the preset gives exactly this profile.
SettingsPreset.Settings = {
    -- Action Bars
    hideMacroNamesEnabled = true,
    hideStanceBarEnabled = true,
    -- Interface
    menuTransparencyEnabled = true,
    minimapClutterEnabled = true,
    worldMapCleanupEnabled = true,
    enhanceTooltipEnabled = true,
    scaleExtraAbilityEnabled = true,
    hideQuestTrackerTitlesEnabled = true,
    sortQuestsByLevelEnabled = true,
    -- Unit Frames
    classHealthColorsEnabled = true,
    unitFrameDebuffsEnabled = true,
    cleanUpUnitFramesEnabled = true,
    hideBossFramesEnabled = true,
    -- Nameplates
    debuffTrackerEnabled = true,
    nameplateComboEnabled = true,
    -- Chat
    chatCleanerEnabled = true,
    hideChatButtonsEnabled = true,
    -- Automations
    smartMacrosEnabled = true,
    autoSellGreys = true,
    autoRepair = true,
    -- Text
    enchantWarningEnabled = true,
    hideErrorMessagesEnabled = true,
    -- Immersion
    actionCamEnabled = true,
}

local function GetDefaults()
    if type(CarpenterDB) ~= "table" then return nil end
    return Carpenter and Carpenter.Defaults
end

local function ValueOrDefault(values, key, default)
    local value = values[key]
    if value == nil then return default end
    return value
end

function SettingsPreset.IsApplied()
    local defaults = GetDefaults()
    if not defaults then return false end
    for key, default in pairs(defaults) do
        if CarpenterDB[key] ~= ValueOrDefault(SettingsPreset.Settings, key, default) then
            return false
        end
    end
    return true
end

local function WriteSettings(values, defaults)
    local poiIconsEnabled = CarpenterDB.worldMapPOIIconsEnabled
    for key, default in pairs(defaults) do
        CarpenterDB[key] = ValueOrDefault(values, key, default)
    end
    Carpenter:RefreshFeatures()
    -- The map's POI icons ride along with World Map Cleanup instead of
    -- toggling a feature of their own.
    if CarpenterDB.worldMapPOIIconsEnabled ~= poiIconsEnabled and Carpenter_ApplyWorldMapCleanup then
        Carpenter_ApplyWorldMapCleanup()
    end
end

-- Keeps the settings from before the preset went on, so unchecking it can put
-- them back.
function SettingsPreset.Apply()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    local defaults = GetDefaults()
    if not defaults then
        return false, "failed"
    end

    if not SettingsPreset.IsApplied() then
        local backup = {}
        for key in pairs(defaults) do
            backup[key] = CarpenterDB[key]
        end
        CarpenterDB.settingsPresetBackup = backup
    end
    WriteSettings(SettingsPreset.Settings, defaults)
    return true, "applied"
end

function SettingsPreset.Restore()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    local defaults = GetDefaults()
    if not defaults then
        return false, "failed"
    end

    local backup = CarpenterDB.settingsPresetBackup
    if type(backup) ~= "table" then
        return false, "unchanged"
    end
    WriteSettings(backup, defaults)
    CarpenterDB.settingsPresetBackup = nil
    return true, "restored"
end
