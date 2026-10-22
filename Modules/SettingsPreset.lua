--[[ Carpenter - The author's own game settings ]]
local _, ns = ...
ns.Private = ns.Private or {}

local SettingsPreset = ns.Private.SettingsPreset or {}
ns.Private.SettingsPreset = SettingsPreset

local unpack = unpack or table.unpack

-- The author's WoW Forever settings, copied from the client's WTF folder.
-- Machine and cache values (graphics API, window, locale, survey data),
-- tutorial state, and the camera settings Action Cam owns stay out.
SettingsPreset.CVars = {
    -- Graphics, sound, and the rest of the client's own settings. Overall
    -- quality goes first, since it presets the graphics options after it.
    { "graphicsQuality", "5" },
    { "RAIDgraphicsQuality", "5" },
    { "graphicsBloomUserMult", "0" },
    { "graphicsComputeEffects", "2" },
    { "graphicsDepthEffects", "3" },
    { "graphicsEnvironmentDetail", "5" },
    { "graphicsGroundClutter", "5" },
    { "graphicsLightMode", "2" },
    { "graphicsLiquidDetail", "2" },
    { "graphicsOutlineMode", "1" },
    { "graphicsParticleDensity", "3" },
    { "graphicsPBRLiquidDetail", "1" },
    { "graphicsProjectedTextures", "1" },
    { "graphicsShadowQuality", "3" },
    { "graphicsSpellDensity", "1" },
    { "graphicsSSAO", "3" },
    { "graphicsTextureResolution", "2" },
    { "graphicsViewDistance", "5" },
    { "raidGraphicsBloomUserMult", "1" },
    { "raidGraphicsComputeEffects", "2" },
    { "raidGraphicsDepthEffects", "3" },
    { "raidGraphicsEnvironmentDetail", "5" },
    { "raidGraphicsGroundClutter", "5" },
    { "raidGraphicsLightMode", "2" },
    { "raidGraphicsLiquidDetail", "2" },
    { "raidGraphicsOutlineMode", "1" },
    { "raidGraphicsParticleDensity", "3" },
    { "raidGraphicsPBRLiquidDetail", "1" },
    { "raidGraphicsProjectedTextures", "1" },
    { "raidGraphicsShadowQuality", "3" },
    { "raidGraphicsSpellDensity", "1" },
    { "raidGraphicsSSAO", "3" },
    { "raidGraphicsTextureResolution", "2" },
    { "raidGraphicsViewDistance", "5" },
    { "accessibilityScreenNarrationEnabled", "0" },
    { "bloomUserMult", "0" },
    { "checkAddonVersion", "0" },
    { "Contrast", "60" },
    { "entityLodDist", "8" },
    { "entityShadowFadeScale", "20" },
    { "farclip", "6000" },
    { "ffxAntiAliasingMode", "2" },
    { "floatingCombatTextCombatHealingAbsorbSelf_v2", "0" },
    { "floatingCombatTextLowManaHealth_v2", "0" },
    { "GamePadTurnWithCamera", "2" },
    { "giQuality", "3" },
    { "groundEffectDensity", "32" },
    { "groundEffectDist", "185" },
    { "horizonClip", "6000" },
    { "horizonStart", "1700" },
    { "lodObjectCullSize", "19" },
    { "lodObjectFadeScale", "90" },
    { "lodObjectMinSize", "0" },
    { "LowLatencyMode", "1" },
    { "movieSubtitle", "0" },
    { "OutlineEngineMode", "1" },
    { "particleDensity", "80" },
    { "pbrLiquidDetail", "1" },
    { "projectedTextures", "1" },
    { "RAIDentityLodDist", "8" },
    { "RAIDentityShadowFadeScale", "20" },
    { "RAIDfarclip", "6000" },
    { "RAIDgiQuality", "3" },
    { "RAIDgroundEffectDensity", "32" },
    { "RAIDgroundEffectDist", "185" },
    { "RAIDhorizonClip", "6000" },
    { "RAIDhorizonStart", "1700" },
    { "RAIDlodObjectCullSize", "19" },
    { "RAIDlodObjectFadeScale", "90" },
    { "RAIDlodObjectMinSize", "0" },
    { "RAIDOutlineEngineMode", "1" },
    { "RAIDparticleDensity", "80" },
    { "RAIDpbrLiquidDetail", "1" },
    { "RAIDprojectedTextures", "1" },
    { "RAIDreflectionMode", "2" },
    { "RAIDrefraction", "2" },
    { "RAIDrippleDetail", "1" },
    { "RAIDshadowBlendCascades", "1" },
    { "RAIDshadowMode", "3" },
    { "RAIDshadowNumCascades", "3" },
    { "RAIDshadowTextureSize", "1536" },
    { "RAIDSSAO", "3" },
    { "RAIDsunShafts", "2" },
    { "RAIDterrainLodDist", "500" },
    { "RAIDTerrainLodDiv", "512" },
    { "RAIDVolumeFogLevel", "2" },
    { "RAIDWaterDetail", "2" },
    { "RAIDweatherDensity", "3" },
    { "RAIDwmoLodDist", "350" },
    { "reflectionMode", "2" },
    { "refraction", "2" },
    { "RenderScale", "0.66666668653488" },
    { "rippleDetail", "1" },
    { "shadowBlendCascades", "1" },
    { "shadowMode", "3" },
    { "shadowNumCascades", "3" },
    { "shadowTextureSize", "1536" },
    { "Sound_AmbienceVolume", "1" },
    { "Sound_DialogVolume", "0.65000003576279" },
    { "Sound_EnableErrorSpeech", "0" },
    { "Sound_EnableMusic", "0" },
    { "Sound_EnablePetBattleMusic", "0" },
    { "Sound_MasterVolume", "0.69999998807907" },
    { "Sound_MusicVolume", "0.30000001192093" },
    { "Sound_SFXVolume", "0.69999998807907" },
    { "Sound_ZoneMusicNoDelay", "1" },
    { "spellClutter", "2" },
    { "spellVisualDensityFilterSetting", "2" },
    { "SSAO", "3" },
    { "sunShafts", "2" },
    { "terrainLodDist", "500" },
    { "TerrainLodDiv", "512" },
    { "uiScale", "0.75" },
    { "useMaxFPS", "1" },
    { "useTargetFPS", "0" },
    { "useUiScale", "1" },
    { "volumeFogLevel", "2" },
    { "vsync", "0" },
    { "waterDetail", "2" },
    { "weatherDensity", "3" },
    { "wmoLodDist", "350" },
    -- Interface, shared by every character on the account
    { "autoLootDefault", "1" },
    { "coordsByTenths", "0" },
    { "countdownForCooldowns", "1" },
    { "doNotFlashLowHealthWarning", "1" },
    { "enableFloatingCombatText", "1" },
    { "lootUnderMouse", "0" },
    { "minimapShowPlayerCoords", "0" },
    { "nameplateAuraScale", "1.2000000476837" },
    { "nameplateDebuffPadding", "8" },
    { "nameplateEnemyNpcAuraDisplay", "F" },
    { "nameplateEnemyPlayerAuraDisplay", "F" },
    { "nameplateFriendlyPlayerAuraDisplay", "G" },
    { "nameplateShowAll", "0" },
    { "nameplateShowClassColor", "1" },
    { "nameplateShowEnemies", "1" },
    { "nameplateShowEnemyGuardians", "1" },
    { "nameplateShowEnemyMinions", "1" },
    { "nameplateShowEnemyPets", "1" },
    { "nameplateShowEnemyTotems", "1" },
    { "nameplateShowFriendlyClassColor", "1" },
    { "nameplateStackingTypes", "C" },
    { "nameplateStyle", "4" },
    { "nameplateTargetRadialPosition", "1" },
    { "nameplateThreatDisplay", "D" },
    { "ReplaceMyPlayerPortrait", "1" },
    { "ReplaceOtherPlayerPortraits", "1" },
    { "ShakeStrengthCamera", "1" },
    { "ShakeStrengthUI", "1" },
    { "showTargetOfTarget", "1" },
    { "statusText", "1" },
    { "statusTextDisplay", "PERCENT" },
    { "timeMgrUseLocalTime", "1" },
    { "worldMapShowCursorCoords", "0" },
    { "worldMapShowPlayerCoords", "0" },
    -- Nameplates, raid frames, and the map, saved per character
    { "calendarShowResets", "1" },
    { "nameplateMaxAlpha", "1" },
    { "nameplateMaxAlphaDistance", "40" },
    { "nameplateMaxDistance", "60" },
    { "nameplateMaxScale", "1" },
    { "nameplateMinAlpha", "0.6" },
    { "nameplateMinAlphaDistance", "-100000" },
    { "nameplateMinScale", "1" },
    { "nameplateOccludedAlphaMult", "0.4" },
    { "nameplatePlayerMaxDistance", "60" },
    { "nameplateSelectedScale", "1.2" },
    { "nameplateTargetBehindMaxDistance", "30" },
    { "questPOI", "0" },
    { "raidFramesDisplayAggroHighlight", "0" },
    { "raidFramesDisplayClassColor", "1" },
    { "raidFramesDisplayPowerBars", "1" },
    { "raidFramesHealthText", "perc" },
}

-- Action bars 2 to 8 as enableMultiActionBars stores them, bar 2 in the
-- lowest bit: bars 2, 3, and 4 shown.
SettingsPreset.ActionBars = 7

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

local presetCVars = {}
for _, cvar in ipairs(SettingsPreset.CVars) do
    presetCVars[cvar[1]] = cvar[2]
end

local presetBindings = {}
for _, binding in ipairs(SettingsPreset.Bindings) do
    presetBindings[binding[1]] = binding[2]
end

function SettingsPreset.IsAvailable()
    return Carpenter and Carpenter.Client and Carpenter.Client.isForever == true
end

local function ReadCVar(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not getter then return nil end
    local ok, value = pcall(getter, name)
    if ok then return value end
    return nil
end

local function SameValue(current, wanted)
    if current == wanted then return true end
    local currentNumber, wantedNumber = tonumber(current), tonumber(wanted)
    return currentNumber ~= nil and wantedNumber ~= nil and math.abs(currentNumber - wantedNumber) < 0.0001
end

local function WriteCVar(name, value)
    if SameValue(ReadCVar(name), value) then return true end
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not setter then return false end
    local ok, result = pcall(setter, name, value)
    return ok and result ~= false
end

local function ReadActionBars()
    if not GetActionBarToggles then return nil end
    local count = select("#", GetActionBarToggles())
    local toggles = { GetActionBarToggles() }
    local mask = 0
    for index = 1, count do
        if toggles[index] then
            mask = mask + 2 ^ (index - 1)
        end
    end
    return mask, count
end

local function WriteActionBars(mask)
    local current, count = ReadActionBars()
    if current == mask then return true end
    if not count or not SetActionBarToggles then return false end
    local toggles = {}
    for index = 1, count do
        toggles[index] = math.floor(mask / 2 ^ (index - 1)) % 2 == 1
    end
    return pcall(SetActionBarToggles, unpack(toggles, 1, count)) == true
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
    for _, cvar in ipairs(SettingsPreset.CVars) do
        local current = ReadCVar(cvar[1])
        if current ~= nil and not SameValue(current, cvar[2]) then
            return false
        end
    end
    local actionBars = ReadActionBars()
    if actionBars and actionBars ~= SettingsPreset.ActionBars then
        return false
    end
    for _, binding in ipairs(SettingsPreset.Bindings) do
        if ReadBinding(binding[1]) ~= binding[2] then
            return false
        end
    end
    return true
end

-- Writes in the preset's order, so overall graphics quality lands before the
-- options it presets. Returns how many values the game turned down.
local function WriteSettings(cvars, actionBars, bindings)
    local refused = 0
    for _, cvar in ipairs(SettingsPreset.CVars) do
        local value = cvars[cvar[1]]
        if value ~= nil and not WriteCVar(cvar[1], value) then
            refused = refused + 1
        end
    end
    if actionBars and not WriteActionBars(actionBars) then
        refused = refused + 1
    end
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

-- Keeps everything the preset is about to change, so unchecking it can put
-- it back.
local function TakeBackup()
    local backup = { cvars = {}, bindings = {}, actionBars = ReadActionBars() }
    for _, cvar in ipairs(SettingsPreset.CVars) do
        backup.cvars[cvar[1]] = ReadCVar(cvar[1])
    end
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
    if WriteSettings(presetCVars, SettingsPreset.ActionBars, presetBindings) > 0 then
        return false, "partial"
    end
    return true, "applied"
end

function SettingsPreset.Restore()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if type(CarpenterDB) ~= "table" then
        return false, "failed"
    end

    local backup = CarpenterDB.settingsPresetBackup
    if type(backup) ~= "table" or type(backup.cvars) ~= "table" or type(backup.bindings) ~= "table" then
        return false, "unchanged"
    end
    local refused = WriteSettings(backup.cvars, backup.actionBars, backup.bindings)
    CarpenterDB.settingsPresetBackup = nil
    if refused > 0 then
        return false, "partial"
    end
    return true, "restored"
end
