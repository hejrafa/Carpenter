--[[ Carpenter - Explorer Mode ]]
-- Decides when to fade or restore, and wires events, Edit Mode, and the feature.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Internal = ns.Private.ExplorerModeInternal
local S = Internal.State
local ACTION_BUTTON_REFRESH_THROTTLE_SECONDS = Internal.ACTION_BUTTON_REFRESH_THROTTLE_SECONDS
local EXPLORING_ALPHA = Internal.EXPLORING_ALPHA
local FADE_OUT_DELAY_SECONDS = Internal.FADE_OUT_DELAY_SECONDS
local FADE_OUT_SECONDS = Internal.FADE_OUT_SECONDS
local HIDDEN_HEALTH_SETTLE_SECONDS = Internal.HIDDEN_HEALTH_SETTLE_SECONDS
local HOVER_FADE_IN_SECONDS = Internal.HOVER_FADE_IN_SECONDS
local VISIBLE_ALPHA = Internal.VISIBLE_ALPHA
local actionBarRefreshEvents = Internal.actionBarRefreshEvents
local registeredEvents = Internal.registeredEvents
local registeredUnitEvents = Internal.registeredUnitEvents
local IsEditModeSupportedClient = Internal.IsEditModeSupportedClient
local IsEnabled = Internal.IsEnabled
local IsGameEditModeActive = Internal.IsGameEditModeActive
local IsInCombat = Internal.IsInCombat
local IsPlayerHealthSecret = Internal.IsPlayerHealthSecret
local IsPlayerKnownHurt = Internal.IsPlayerKnownHurt
local SafeSetAlpha = Internal.SafeSetAlpha
local HookActionButtonOverlayFunctions = Internal.HookActionButtonOverlayFunctions
local RestoreActionButtonCooldownDrawStates = Internal.RestoreActionButtonCooldownDrawStates
local ApplyTargetAlpha = Internal.ApplyTargetAlpha
local FadeActionButtonVisuals = Internal.FadeActionButtonVisuals
local RefreshExplorerTargets = Internal.RefreshExplorerTargets
local fadeDriver = Internal.fadeDriver
local hoverDriver = Internal.hoverDriver

local frame = CreateFrame("Frame")
local actionBarFrame = CreateFrame("Frame")
local actionButtonRefreshQueued = false
local lastActionButtonRefreshAt = 0
local editModeCallbacksRegistered = false
local editModeHooksInstalled = false

local function CancelScheduledRefresh()
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:refresh"] = nil
    end
end

local function CancelScheduledActionButtonRefresh()
    actionButtonRefreshQueued = false
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:actionButtons"] = nil
        Carpenter.Deferred["ExplorerMode:actionButtonsVerify"] = nil
    end
end

local function CancelScheduledFadeOut()
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:fadeOut"] = nil
    end
end

local function RestoreVisible(duration, forceApply)
    CancelScheduledRefresh()
    CancelScheduledActionButtonRefresh()
    CancelScheduledFadeOut()
    S.activeFades = {}
    fadeDriver:Hide()
    hoverDriver:Hide()
    S.hoverFadeOutAt = {}
    S.explorerFaded = false

    if forceApply or not IsInCombat() then
        ApplyTargetAlpha(VISIBLE_ALPHA, duration or 0)
    end
end

local function RestoreManagedFrames()
    CancelScheduledRefresh()
    CancelScheduledActionButtonRefresh()
    CancelScheduledFadeOut()
    S.activeFades = {}
    fadeDriver:Hide()
    hoverDriver:Hide()

    for object, originalAlpha in pairs(S.managedAlphas) do
        SafeSetAlpha(object, originalAlpha or VISIBLE_ALPHA)
    end
    RestoreActionButtonCooldownDrawStates()
    S.managedFrames = {}
    S.managedAlphas = {}
    S.frameTargets = {}
    S.trackingBarHoverSources = setmetatable({}, { __mode = "k" })
    S.hoverFadeOutAt = {}
    S.actionButtonTargetAlpha = nil
    S.explorerFaded = false
end

local function ScheduleRefresh()
    local callback = function()
        if IsEnabled() and S.explorerFaded and not IsInCombat() and not IsPlayerKnownHurt() and not IsGameEditModeActive() then
            RefreshExplorerTargets()
        end
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:refresh", FADE_OUT_SECONDS + 0.2, callback)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(FADE_OUT_SECONDS + 0.2, callback)
    end
end

local function ShouldRefreshActionButtons()
    if not (IsEnabled() and S.explorerFaded and not IsInCombat() and not IsPlayerKnownHurt() and not IsGameEditModeActive()) then
        return false
    end

    return true
end

local function ShouldQueueActionButtonRefresh()
    return IsEnabled() and S.explorerFaded and not IsInCombat() and not IsGameEditModeActive()
end

local function RunActionButtonRefresh()
    actionButtonRefreshQueued = false
    lastActionButtonRefreshAt = GetTime and GetTime() or 0

    if not ShouldRefreshActionButtons() then
        return
    end

    local targetAlpha = S.actionButtonTargetAlpha or EXPLORING_ALPHA
    FadeActionButtonVisuals(targetAlpha, 0, true)

    local callback = function()
        if ShouldRefreshActionButtons() then
            FadeActionButtonVisuals(S.actionButtonTargetAlpha or targetAlpha, 0, true)
        end
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:actionButtonsVerify", 0.05, callback)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.05, callback)
    else
        callback()
    end
end

local function ScheduleActionButtonRefresh()
    if not ShouldQueueActionButtonRefresh() or actionButtonRefreshQueued then
        return
    end

    local now = GetTime and GetTime() or 0
    local elapsedSinceRefresh = now - (lastActionButtonRefreshAt or 0)
    local delay = math.max(0, ACTION_BUTTON_REFRESH_THROTTLE_SECONDS - elapsedSinceRefresh)

    actionButtonRefreshQueued = true

    if delay <= 0 then
        RunActionButtonRefresh()
        return
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:actionButtons", delay, RunActionButtonRefresh)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, RunActionButtonRefresh)
    else
        RunActionButtonRefresh()
    end
end

local function FadeOutForExploration()
    if not IsEnabled() or IsInCombat() then
        return
    end
    if IsGameEditModeActive() then
        RestoreVisible(0, true)
        return
    end
    if IsPlayerKnownHurt() then
        RestoreVisible(HOVER_FADE_IN_SECONDS)
        return
    end

    S.explorerFaded = true
    ApplyTargetAlpha(EXPLORING_ALPHA, FADE_OUT_SECONDS)
    hoverDriver:Show()
    ScheduleRefresh()
end

local function ScheduleFadeOut()
    CancelScheduledFadeOut()
    local delay = FADE_OUT_DELAY_SECONDS
    if IsPlayerHealthSecret() then
        delay = HIDDEN_HEALTH_SETTLE_SECONDS
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:fadeOut", delay, FadeOutForExploration)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, FadeOutForExploration)
    else
        FadeOutForExploration()
    end
end

local function ApplyExplorerMode(forceVisible)
    if not IsEnabled() then
        RestoreManagedFrames()
        return
    end

    if forceVisible then
        RestoreVisible(0, true)
        return
    end

    local inCombat = IsInCombat()
    if inCombat then
        RestoreVisible(0)
    elseif IsGameEditModeActive() then
        RestoreVisible(0, true)
    elseif IsPlayerKnownHurt() then
        RestoreVisible(HOVER_FADE_IN_SECONDS)
    elseif S.explorerFaded then
        RefreshExplorerTargets()
        hoverDriver:Show()
        ScheduleRefresh()
    else
        ScheduleFadeOut()
    end
end

frame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" then
        if unit ~= "player" then
            return
        end
        if IsEnabled() and IsPlayerHealthSecret() and not IsInCombat() and not IsGameEditModeActive() then
            -- Hidden health could have dropped, so show the HUD and only fade
            -- again once regen stops changing it.
            RestoreVisible(HOVER_FADE_IN_SECONDS)
            ScheduleFadeOut()
            return
        end
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        HookActionButtonOverlayFunctions()
    end
    ApplyExplorerMode(event == "PLAYER_REGEN_DISABLED")
end)

actionBarFrame:SetScript("OnEvent", function()
    ScheduleActionButtonRefresh()
end)

local function OnEditModeEnter()
    if IsEnabled() then
        RestoreVisible(0, true)
    end
end

local function OnEditModeExit()
    if IsEnabled() then
        ApplyExplorerMode()
    end
end

local function RegisterEditModeCallbacks()
    if not IsEditModeSupportedClient() then
        return
    end

    if not editModeCallbacksRegistered and EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter, frame)
        EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, frame)
        editModeCallbacksRegistered = true
    end

    if not editModeHooksInstalled and hooksecurefunc and _G.EditModeManagerFrame then
        local editMode = _G.EditModeManagerFrame
        if type(editMode.EnterEditMode) == "function" then
            pcall(hooksecurefunc, editMode, "EnterEditMode", OnEditModeEnter)
        end
        if type(editMode.ExitEditMode) == "function" then
            pcall(hooksecurefunc, editMode, "ExitEditMode", OnEditModeExit)
        end
        editModeHooksInstalled = true
    end
end

local feature = {}

function feature:Enable()
    for _, event in ipairs(registeredEvents) do
        if Carpenter and Carpenter.SafeRegisterEvent then
            Carpenter:SafeRegisterEvent(frame, event)
        else
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    for event in pairs(actionBarRefreshEvents) do
        if Carpenter and Carpenter.SafeRegisterEvent then
            Carpenter:SafeRegisterEvent(actionBarFrame, event)
        else
            pcall(actionBarFrame.RegisterEvent, actionBarFrame, event)
        end
    end
    for _, event in ipairs(registeredUnitEvents) do
        if Carpenter and Carpenter.SafeRegisterUnitEvent then
            Carpenter:SafeRegisterUnitEvent(frame, event, "player")
        else
            pcall(frame.RegisterUnitEvent, frame, event, "player")
        end
    end
    HookActionButtonOverlayFunctions()
    RegisterEditModeCallbacks()
    ApplyExplorerMode()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    actionBarFrame:UnregisterAllEvents()
    RestoreManagedFrames()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("explorerModeEnabled", feature)
end

Internal.RestoreVisible = RestoreVisible
