--[[ Carpenter - Classic Settings Preset ]]
-- Applies a small set of preferred Classic client settings when enabled.

local function IsEnabled()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic and Carpenter:IsEnabled("classicSettingsPresetEnabled")
end

local function SetCVarValue(name, value)
    if type(SetCVar) == "function" then
        pcall(SetCVar, name, value)
    end
end

local function ApplyActionBarToggles()
    _G.SHOW_MULTI_ACTIONBAR_1 = "1"
    _G.SHOW_MULTI_ACTIONBAR_2 = "1"
    _G.SHOW_MULTI_ACTIONBAR_3 = "1"

    SetCVarValue("multiBarBottomLeft", "1")
    SetCVarValue("multiBarBottomRight", "1")
    SetCVarValue("multiBarRight", "1")

    if type(SetActionBarToggles) == "function" then
        pcall(SetActionBarToggles, 1, 1, _G.SHOW_MULTI_ACTIONBAR_3, _G.SHOW_MULTI_ACTIONBAR_4)
    end
    if type(InterfaceOptions_UpdateMultiActionBars) == "function" then
        pcall(InterfaceOptions_UpdateMultiActionBars)
    end
    if type(MultiActionBar_Update) == "function" then
        pcall(MultiActionBar_Update)
    end
    if type(UIParent_ManageFramePositions) == "function" then
        pcall(UIParent_ManageFramePositions)
    end
end

local function ApplyRaidFrameToggles()
    SetCVarValue("raidFramesDisplayClassColor", "1")

    if type(CompactUnitFrameProfiles_ApplyCurrentSettings) == "function" then
        pcall(CompactUnitFrameProfiles_ApplyCurrentSettings)
    end
end

local function Apply()
    if not IsEnabled() then return end

    SetCVarValue("autoLootDefault", "1")
    SetCVarValue("nameplateShowEnemies", "1")
    SetCVarValue("nameplateShowEnemyMinions", "1")
    SetCVarValue("nameplateShowEnemyPets", "1")
    SetCVarValue("nameplateShowEnemyGuardians", "1")
    SetCVarValue("nameplateShowEnemyTotems", "1")
    SetCVarValue("statusText", "1")
    SetCVarValue("statusTextDisplay", "PERCENT")
    ApplyActionBarToggles()
    ApplyRaidFrameToggles()
end

Carpenter_ApplyClassicSettingsPreset = Apply

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function(self, event)
    Apply()
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
