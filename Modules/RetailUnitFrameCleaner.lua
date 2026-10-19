--[[ Carpenter - Retail Unit Frame Cleaner ]]
-- Retail-only unit frame cleanup for PvP badges and class resource widgets.
local _, ns = ...
ns.Private = ns.Private or {}

local Visuals = ns.Private.RetailUnitFrameCleanerVisuals or {}
local Targets = ns.Private.RetailUnitFrameCleanerTargets or {}
local Realm = ns.Private.RetailUnitFrameCleanerRealm or {}

local lastFeatureState = {}
local partyTitleOriginalAlpha = setmetatable({}, { __mode = "k" })
local threatGlowOriginalAlpha = setmetatable({}, { __mode = "k" })

-- How strongly the red threat glow still shows with Clean Unit Frame on.
local THREAT_GLOW_ALPHA = 0.3

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

local function ShouldDimThreatGlow()
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
        or ShouldHideRealmIndicator()
        or ShouldHidePlayerCornerIcon()
        or ShouldHidePartyFrameTitle()
        or ShouldHideTargetReputationColor()
        or ShouldDimThreatGlow()
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
            else
                Visuals.HideFrame(frame)
            end
        end
    else
        local restored = true
        for _, frame in ipairs(getFrames()) do
            local frameRestored
            if alphaOnly then
                frameRestored = Visuals.RestoreFrameAlpha(frame)
            else
                frameRestored = Visuals.RestoreFrame(frame)
            end
            restored = restored and frameRestored ~= false
        end
        if not restored then
            -- Combat blocked part of the restore; PLAYER_REGEN_ENABLED retries it.
            return
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

local function ApplyPartyFrameTitleFeature()
    local enabled = ShouldHidePartyFrameTitle()
    if not enabled and not lastFeatureState.partyFrameTitle then return end

    for _, frame in ipairs(Targets.GetPartyFrameTitleFrames()) do
        if enabled then
            if partyTitleOriginalAlpha[frame] == nil and frame.GetAlpha then
                partyTitleOriginalAlpha[frame] = frame:GetAlpha()
            end
            if frame.SetAlpha then frame:SetAlpha(0) end
        elseif partyTitleOriginalAlpha[frame] ~= nil then
            if frame.SetAlpha then frame:SetAlpha(partyTitleOriginalAlpha[frame]) end
            partyTitleOriginalAlpha[frame] = nil
        end
    end

    lastFeatureState.partyFrameTitle = enabled
end

-- Dims rather than hides, so you still see when something is on you. The glow
-- textures belong to secure unit frames, so they're only touched out of combat.
local function ApplyThreatGlowFeature()
    local enabled = ShouldDimThreatGlow()
    if not enabled and not lastFeatureState.threatGlow then return end
    if InCombatLockdown and InCombatLockdown() then return end

    for _, texture in ipairs(Targets.GetThreatGlowTextures()) do
        if enabled then
            if threatGlowOriginalAlpha[texture] == nil and texture.GetAlpha then
                threatGlowOriginalAlpha[texture] = texture:GetAlpha()
            end
            if texture.SetAlpha then texture:SetAlpha(THREAT_GLOW_ALPHA) end
        elseif threatGlowOriginalAlpha[texture] ~= nil then
            if texture.SetAlpha then texture:SetAlpha(threatGlowOriginalAlpha[texture]) end
            threatGlowOriginalAlpha[texture] = nil
        end
    end

    lastFeatureState.threatGlow = enabled
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
    for _, frame in ipairs(Targets.GetLegacyPartyHealthLossFxFrames and Targets.GetLegacyPartyHealthLossFxFrames() or {}) do
        Visuals.RestoreFrame(frame)
    end
    ApplyFrameFeature("playerCornerIcon", Targets.GetPlayerCornerIconFrames, ShouldHidePlayerCornerIcon, false)
    -- CompactPartyFrameTitle participates in Blizzard's secure Edit Mode party
    -- refresh. Limit this feature to alpha only: no hooks, parenting, visibility,
    -- scripts, events, or custom fields on that frame.
    ApplyPartyFrameTitleFeature()
    ApplyThreatGlowFeature()
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
end
