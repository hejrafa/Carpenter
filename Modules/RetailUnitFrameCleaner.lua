--[[ Carpenter - Retail Unit Frame Cleaner ]]
-- Retail-only unit frame cleanup for PvP badges and class resource widgets.
local _, ns = ...
ns.Private = ns.Private or {}

local Visuals = ns.Private.RetailUnitFrameCleanerVisuals or {}
local Targets = ns.Private.RetailUnitFrameCleanerTargets or {}
local Realm = ns.Private.RetailUnitFrameCleanerRealm or {}

local lastFeatureState = {}

local function IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function ShouldHidePvPIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHidePowerBar()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideUnitFramePowerBarEnabled")
end

local function ShouldHideBossFrames()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideBossFramesEnabled")
end

local function ShouldHideRestAnimation()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideCombatIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideHealthLossFx()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideGroupIndicator()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideGroupIndicatorEnabled")
end

local function ShouldHideRealmIndicator()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHidePlayerCornerIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHidePartyFrameTitle()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideTargetReputationColor()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function HasActiveCleanerOption()
    if not IsRetail() then return false end
    return ShouldHidePvPIcon()
        or ShouldHidePowerBar()
        or ShouldHideBossFrames()
        or ShouldHideRestAnimation()
        or ShouldHideCombatIcon()
        or ShouldHideHealthLossFx()
        or ShouldHideGroupIndicator()
        or ShouldHideRealmIndicator()
        or ShouldHidePlayerCornerIcon()
        or ShouldHidePartyFrameTitle()
        or ShouldHideTargetReputationColor()
end

local function ShouldRunCleaner()
    if HasActiveCleanerOption() then
        return true
    end

    for _, wasEnabled in pairs(lastFeatureState) do
        if wasEnabled then return true end
    end

    return false
end

local function ApplyFrameFeature(featureKey, getFrames, predicate, alphaOnly)
    local enabled = predicate()
    if not enabled and not lastFeatureState[featureKey] then
        return
    end

    if enabled then
        for _, frame in ipairs(getFrames()) do
            if alphaOnly then
                Visuals.HideFrameAlpha(frame)
                Visuals.HookAlphaHide(frame, predicate)
            else
                Visuals.HideFrame(frame)
                Visuals.HookHide(frame, predicate)
            end
        end
    else
        for _, frame in ipairs(getFrames()) do
            if alphaOnly then
                Visuals.RestoreFrameAlpha(frame)
            else
                Visuals.RestoreFrame(frame)
            end
        end
    end

    lastFeatureState[featureKey] = enabled
end

local function ApplyRealmIndicatorFeature()
    local enabled = ShouldHideRealmIndicator()
    if not enabled and not lastFeatureState.realmIndicator then
        return
    end

    if enabled then
        Realm.Apply(ShouldHideRealmIndicator)
    end

    lastFeatureState.realmIndicator = enabled
end

local function Apply()
    if not IsRetail() then return end
    if not ShouldRunCleaner() then return end

    ApplyFrameFeature("pvpIcon", Targets.GetPvPIconFrames, ShouldHidePvPIcon, false)
    ApplyFrameFeature("powerBar", Targets.GetPowerBarFrames, ShouldHidePowerBar, false)
    ApplyFrameFeature("bossFrames", Targets.GetBossFrames, ShouldHideBossFrames, true)
    ApplyFrameFeature("restAnimation", Targets.GetRestAnimationFrames, ShouldHideRestAnimation, false)
    ApplyFrameFeature("combatIcon", Targets.GetCombatIconFrames, ShouldHideCombatIcon, false)
    ApplyFrameFeature("healthLossFx", Targets.GetHealthLossFxFrames, ShouldHideHealthLossFx, false)
    ApplyFrameFeature("groupIndicator", Targets.GetGroupIndicatorFrames, ShouldHideGroupIndicator, false)
    ApplyFrameFeature("playerCornerIcon", Targets.GetPlayerCornerIconFrames, ShouldHidePlayerCornerIcon, false)
    ApplyFrameFeature("partyFrameTitle", Targets.GetPartyFrameTitleFrames, ShouldHidePartyFrameTitle, false)
    -- Match BetterBlizzFrames' narrow Retail approach: only hide the actual reputation
    -- color texture, not the surrounding name/background pieces that affect layout.
    ApplyFrameFeature("targetReputationColor", Targets.GetTargetReputationColorFrames, ShouldHideTargetReputationColor, false)
    ApplyRealmIndicatorFeature()
end

local frame = CreateFrame("Frame")
local frameEvents = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
    "PLAYER_FLAGS_CHANGED",
    "PLAYER_UPDATE_RESTING",
    "PLAYER_REGEN_DISABLED",
    "UNIT_NAME_UPDATE",
    "NAME_PLATE_UNIT_ADDED",
    "PLAYER_REGEN_ENABLED",
}
local eventsRegistered = false
local applyScheduled = false

local function RegisterCleanerEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    for _, event in ipairs(frameEvents) do
        frame:RegisterEvent(event)
    end
end

local function UnregisterCleanerEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    frame:UnregisterAllEvents()
end

local function ScheduleApply()
    if applyScheduled then return end
    applyScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            applyScheduled = false
            Apply()
            if not HasActiveCleanerOption() and not ShouldRunCleaner() then
                UnregisterCleanerEvents()
            end
        end)
    else
        applyScheduled = false
        Apply()
        if not HasActiveCleanerOption() and not ShouldRunCleaner() then
            UnregisterCleanerEvents()
        end
    end
end

local function HandleEvent(_, event, unit)
    if event == "UNIT_NAME_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" then
        if HasActiveCleanerOption() then
            Realm.ApplyForUnit(unit, ShouldHideRealmIndicator)
        end
        return
    end

    if not ShouldRunCleaner() then return end

    ScheduleApply()
end

frame:SetScript("OnEvent", function(...)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("RetailUnitFrameCleaner:OnEvent", HandleEvent, ...)
    end
    return HandleEvent(...)
end)

local function RefreshSubscriptions()
    if not IsRetail() then
        UnregisterCleanerEvents()
        return
    end

    if HasActiveCleanerOption() or ShouldRunCleaner() then
        RegisterCleanerEvents()
        ScheduleApply()
    else
        UnregisterCleanerEvents()
    end
end

function Carpenter_ApplyRetailUnitFrameCleaner()
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("RetailUnitFrameCleaner:Apply", Apply)
    end
    return Apply()
end

local function CreateFeature()
    return {
        Enable = RefreshSubscriptions,
        Disable = RefreshSubscriptions,
    }
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("cleanUpUnitFramesEnabled", CreateFeature())
    Carpenter:RegisterFeature("hideUnitFramePowerBarEnabled", CreateFeature())
    Carpenter:RegisterFeature("hideBossFramesEnabled", CreateFeature())
    Carpenter:RegisterFeature("hideGroupIndicatorEnabled", CreateFeature())
end
