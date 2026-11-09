--[[ Carpenter - ActionCam ]]
-- One option: on = DynamicCam-style over-shoulder framing. Turning it off resets
-- the camera CVars Carpenter changed; loading with it off leaves camera CVars alone.
-- Uses default camera framing, then eases to a mounted zoom value while mounted.

local function SetSpellOverlayPosition(x, y)
    local overlay = SpellActivationOverlayFrame
    if overlay then
        overlay:ClearAllPoints()
        overlay:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
    end
end

local OVER_SHOULDER_OFFSET = 1
local DYNAMIC_PITCH_GROUND = 0.6
local DYNAMIC_PITCH_FLYING = 0.75
local DYNAMIC_PITCH_DOWN_SCALE = 0.25
local SMART_PIVOT_CUTOFF_DISTANCE = 10
local SPELL_OVERLAY_OFFSET_X = -90
local SPELL_OVERLAY_OFFSET_Y = 0

local MOUNT_ZOOM_VALUE = 10
local MOUNT_ZOOM_TRANSITION_TIME = 1
local ZOOM_TICK_INTERVAL = 0.05
local NARCISSUS_VIEW_RESTORE_DELAY = 0.2
local NARCISSUS_CVAR_RESTORE_DELAYS = { 1.05, 1.35 }
local UI_VISIBILITY_VIEW_RESTORE_DELAY = 0
local UI_VISIBILITY_CVAR_RESTORE_DELAYS = { 0.15, 0.5, 1.0 }

local lastMounted = nil   -- last mount state we actually acted on (so we only act on transition)
local preMountZoom = nil
local zoomSequence = 0
local zoomInProgress = false  -- prevent overlapping zoom sequences
local zoomTarget = nil  -- where a running zoom sequence is heading
local spellOverlayHooked = false
local spellOverlayApplying = false
local uiParentVisibilityHooked = false
local uiParentHiddenForActionCam = false
local cameraSettingsApplied = false
local originalCameraCVars = {}
local narcissusHooks = {}
local HookSpellOverlay
local UpdateSpellOverlayOffset

local function ScheduleSpellOverlayOffset(delay)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, UpdateSpellOverlayOffset)
    else
        UpdateSpellOverlayOffset()
    end
end

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("actionCamEnabled")
end

local function IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isMainline
end

local function IsForever()
    return Carpenter and Carpenter.Client and Carpenter.Client.isForever
end

local function SetCameraCVar(name, value)
    if type(SetCVar) ~= "function" then return false end
    return pcall(SetCVar, name, value) == true
end

local function SetOwnedCameraCVar(name, value)
    if originalCameraCVars[name] == nil then
        local original = false
        if type(GetCVar) == "function" then
            local ok, current = pcall(GetCVar, name)
            if ok and current ~= nil then
                original = current
            end
        end
        originalCameraCVars[name] = original
    end
    return SetCameraCVar(name, value)
end

local function RestoreOwnedCameraCVars()
    for name, value in pairs(originalCameraCVars) do
        if value ~= false then
            SetCameraCVar(name, value)
        end
        originalCameraCVars[name] = nil
    end
end

-- Carpenter only owns Blizzard's experimental-camera warning while Action Cam is
-- active. In 12.1 Blizzard moved the handler behind GameEvent, so cover both paths.
local function SuppressCameraWarning()
    if not IsEnabled() then return end

    if UIParent and UIParent.UnregisterEvent then
        UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    end
    if GameEvent and GameEvent.UnregisterInternalEvent then
        pcall(GameEvent.UnregisterInternalEvent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    end
end

local function GetCurrentZoom()
    if GetCameraZoom then
        return GetCameraZoom()
    end
end

-- TEMPORARY: records what the camera does around a flight in the saved variables,
-- to read back after a /reload. Remove once flights are confirmed in game.
local function TraceZoom(label)
    pcall(function()
        local log = CarpenterDB.actionCamZoomTrace or {}
        CarpenterDB.actionCamZoomTrace = log
        if #log >= 80 then table.remove(log, 1) end
        log[#log + 1] = string.format("%.2f %s zoom=%.2f mounted=%s taxi=%s pre=%s target=%s", GetTime(), label,
            GetCurrentZoom(), tostring(IsMounted()), tostring(UnitOnTaxi("player")), tostring(preMountZoom), tostring(zoomTarget))
    end)
end

-- Mid-sequence, the camera is only part of the way to where it's heading, so that
-- reading isn't a distance worth coming back to.
local function GetIntendedZoom()
    if zoomInProgress then
        return zoomTarget
    end
    return GetCurrentZoom()
end

local function CancelZoomTransition()
    zoomSequence = zoomSequence + 1
    zoomInProgress = false
end

local function SmoothZoomTo(targetZoom, duration)
    if not targetZoom or not GetCurrentZoom() then return end
    if not CameraZoomIn or not CameraZoomOut then return end

    zoomSequence = zoomSequence + 1
    local sequence = zoomSequence
    local startZoom = GetCurrentZoom()
    local delta = targetZoom - startZoom
    local steps = math.max(1, math.floor((duration or MOUNT_ZOOM_TRANSITION_TIME) / ZOOM_TICK_INTERVAL))
    local previousZoom = startZoom

    if math.abs(delta) < 0.05 then
        zoomInProgress = false
        return
    end

    zoomInProgress = true
    zoomTarget = targetZoom
    for i = 1, steps do
        C_Timer.After(ZOOM_TICK_INTERVAL * i, function()
            if sequence ~= zoomSequence then return end

            local nextZoom = startZoom + (delta * (i / steps))
            local amount = nextZoom - previousZoom
            if amount > 0 then
                CameraZoomOut(amount)
            elseif amount < 0 then
                CameraZoomIn(-amount)
            end
            previousZoom = nextZoom

            if i == steps then
                zoomInProgress = false
                TraceZoom("arrived")
                C_Timer.After(3, function() TraceZoom("3s later") end)
            end
        end)
    end
end

UpdateSpellOverlayOffset = function()
    if not IsRetail() or not SpellActivationOverlayFrame then return end

    HookSpellOverlay()
    spellOverlayApplying = true
    if IsEnabled() then
        SetSpellOverlayPosition(SPELL_OVERLAY_OFFSET_X, SPELL_OVERLAY_OFFSET_Y)
    else
        SetSpellOverlayPosition(0, 0)
    end
    spellOverlayApplying = false
end

HookSpellOverlay = function()
    if spellOverlayHooked or not IsRetail() or not SpellActivationOverlayFrame then return end

    SpellActivationOverlayFrame:HookScript("OnShow", function()
        UpdateSpellOverlayOffset()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, UpdateSpellOverlayOffset)
        end
    end)

    Carpenter:SafeHook(SpellActivationOverlayFrame, "SetPoint", function()
        if spellOverlayApplying then return end
        ScheduleSpellOverlayOffset(0)
    end)

    Carpenter:SafeHook(SpellActivationOverlayFrame, "SetAllPoints", function()
        if spellOverlayApplying then return end
        ScheduleSpellOverlayOffset(0)
    end)

    if _G.SpellActivationOverlay_ShowOverlay then
        Carpenter:SafeHook("SpellActivationOverlay_ShowOverlay", function()
            ScheduleSpellOverlayOffset(0)
        end)
    end

    spellOverlayHooked = true
end

local function UpdateCameraZoom()
    if not IsEnabled() then
        return
    end
    local isMounted = (IsMounted and IsMounted()) and true or false

    if lastMounted == isMounted then
        return
    end
    lastMounted = isMounted

    if isMounted then
        -- Restoring the view after hiding the UI re-checks while still mounted, and
        -- by then the camera is at the mounted distance, so keep the saved one.
        preMountZoom = preMountZoom or GetIntendedZoom()
        TraceZoom("mounted")
        SmoothZoomTo(MOUNT_ZOOM_VALUE, MOUNT_ZOOM_TRANSITION_TIME)
    elseif preMountZoom then
        TraceZoom("dismounted")
        SmoothZoomTo(preMountZoom, MOUNT_ZOOM_TRANSITION_TIME)
        preMountZoom = nil
    end
end

-- Each new event restarts the wait, so the check never runs just after an event
-- whose mount state isn't up to date yet.
local function ScheduleCameraZoomCheck(delay)
    Carpenter:Defer("ActionCam:zoomCheck", delay or 0.25, UpdateCameraZoom)
end

local function ResetCameraCVarsToDefaults()
    -- Called only after Carpenter enabled Action Cam during this UI session.
    SetCameraCVar("test_cameraOverShoulder", 0)
    SetCameraCVar("test_cameraDynamicPitch", 0)
    SetCameraCVar("test_cameraDynamicPitchBaseFovPad", 0.4)  -- default
    SetCameraCVar("test_cameraDynamicPitchBaseFovPadFlying", 0.75)  -- default
    SetCameraCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25)  -- default
    SetCameraCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 10)  -- default
    SetCameraCVar("test_cameraHeadMovementStrength", 0)
    SetCameraCVar("test_cameraTargetFocusEnemyEnable", 0)
    SetCameraCVar("test_cameraTargetFocusInteractEnable", 0)
    RestoreOwnedCameraCVars()
end

local function ApplyForeverCameraOverrides()
    if not IsForever() then return end

    -- These modern accessibility camera options override the experimental
    -- Action Cam CVars unless they are disabled.
    SetOwnedCameraCVar("CameraKeepCharacterCentered", 0)
    SetOwnedCameraCVar("CameraReduceUnexpectedMovement", 0)

    -- Carpenter's established profile is steady: no head movement and no
    -- automatic camera pull toward enemies or interaction targets.
    SetCameraCVar("test_cameraHeadMovementStrength", 0)
    SetCameraCVar("test_cameraTargetFocusEnemyEnable", 0)
    SetCameraCVar("test_cameraTargetFocusInteractEnable", 0)
end

local function UpdateCameraSettings()
    if IsEnabled() then
        SuppressCameraWarning()
        ApplyForeverCameraOverrides()
        cameraSettingsApplied = true
        SetCameraCVar("test_cameraOverShoulder", OVER_SHOULDER_OFFSET)
        SetOwnedCameraCVar("cameraSmoothStyle", 0) -- required for offset

        SetCameraCVar("test_cameraDynamicPitch", 1)
        SetCameraCVar("test_cameraDynamicPitchBaseFovPad", DYNAMIC_PITCH_GROUND)
        SetCameraCVar("test_cameraDynamicPitchBaseFovPadFlying", DYNAMIC_PITCH_FLYING)
        SetCameraCVar("test_cameraDynamicPitchBaseFovPadDownScale", DYNAMIC_PITCH_DOWN_SCALE)
        SetCameraCVar("test_cameraDynamicPitchSmartPivotCutoffDist", SMART_PIVOT_CUTOFF_DISTANCE)
        
        -- Update zoom based on mount status
        UpdateCameraZoom()
        UpdateSpellOverlayOffset()
    else
        CancelZoomTransition()
        if cameraSettingsApplied then
            ResetCameraCVarsToDefaults()
            cameraSettingsApplied = false
        end
        UpdateSpellOverlayOffset()
    end
end

local function IsNarcissusActive()
    return _G.Narci and _G.Narci.isActive
end

local function RestoreActionCamAfterNarcissus(restoreView)
    if not IsEnabled() or IsNarcissusActive() then return end

    if restoreView and SetView then
        pcall(SetView, 5)
        lastMounted = nil
    end

    UpdateCameraSettings()
end

local function RestoreActionCamAfterUIVisibility(restoreView)
    if not IsEnabled() then return end

    if restoreView and SetView then
        pcall(SetView, 5)
        lastMounted = nil
    end

    UpdateCameraSettings()
end

local function ScheduleNarcissusActionCamRestore()
    if not IsEnabled() or IsNarcissusActive() then return end

    if not C_Timer or not C_Timer.After then
        RestoreActionCamAfterNarcissus(true)
        return
    end

    C_Timer.After(NARCISSUS_VIEW_RESTORE_DELAY, function()
        RestoreActionCamAfterNarcissus(true)
    end)

    for _, delay in ipairs(NARCISSUS_CVAR_RESTORE_DELAYS) do
        C_Timer.After(delay, function()
            RestoreActionCamAfterNarcissus(false)
        end)
    end
end

local function ScheduleUIVisibilityActionCamRestore()
    if not IsEnabled() then return end

    if not C_Timer or not C_Timer.After then
        RestoreActionCamAfterUIVisibility(true)
        return
    end

    C_Timer.After(UI_VISIBILITY_VIEW_RESTORE_DELAY, function()
        RestoreActionCamAfterUIVisibility(true)
    end)

    for _, delay in ipairs(UI_VISIBILITY_CVAR_RESTORE_DELAYS) do
        C_Timer.After(delay, function()
            RestoreActionCamAfterUIVisibility(false)
        end)
    end
end

local function OnNarcissusToggle()
    ScheduleNarcissusActionCamRestore()
end

local function HookNarcissusFunction(name)
    if narcissusHooks[name] or type(_G[name]) ~= "function" or not hooksecurefunc then return end

    local ok = Carpenter:SafeHook(name, OnNarcissusToggle)
    if ok then
        narcissusHooks[name] = true
    end
end

local function HookNarcissusCamera()
    HookNarcissusFunction("Narci_Open")
    HookNarcissusFunction("Narci_OpenGroupPhoto")
end

local function HookUIParentVisibility()
    if uiParentVisibilityHooked or not UIParent or not UIParent.HookScript then return end

    UIParent:HookScript("OnHide", function()
        if IsEnabled() then
            uiParentHiddenForActionCam = true
        end
    end)

    UIParent:HookScript("OnShow", function()
        if not uiParentHiddenForActionCam then return end
        uiParentHiddenForActionCam = false
        ScheduleUIVisibilityActionCamRestore()
    end)

    uiParentVisibilityHooked = true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
-- Flight paths take and return control, so landing is noticed even if the mount
-- events don't come through.
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")

local function HandleActionCamEvent(self, event, addon)
    if event == "ADDON_LOADED" and addon == "Carpenter" then
        C_Timer.After(0.1, UpdateCameraSettings)
    elseif event == "ADDON_LOADED" and addon == "Narcissus" then
        HookNarcissusCamera()
    elseif event == "ADDON_LOADED" and addon == "Blizzard_SpellActivationOverlay" then
        ScheduleSpellOverlayOffset(0)
        ScheduleSpellOverlayOffset(0.1)
    elseif event == "PLAYER_LOGIN" then
        HookUIParentVisibility()
        HookNarcissusCamera()
        UpdateCameraSettings()
        ScheduleSpellOverlayOffset(0)
        ScheduleSpellOverlayOffset(0.1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        HookUIParentVisibility()
        UpdateCameraSettings()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, UpdateSpellOverlayOffset)
            C_Timer.After(2, UpdateSpellOverlayOffset)
            C_Timer.After(5, UpdateSpellOverlayOffset)
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        ScheduleSpellOverlayOffset(0)
        ScheduleSpellOverlayOffset(0.05)
    elseif (event == "PLAYER_MOUNT_DISPLAY_CHANGED" or
            event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" or
            event == "UNIT_MODEL_CHANGED") then
        -- Mount/aura changed; delay so IsMounted() is up to date
        if IsEnabled() then
            TraceZoom(event)
            ScheduleCameraZoomCheck(0.25)
        end
    end
end

frame:SetScript("OnEvent", function(...)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("ActionCam:OnEvent", HandleActionCamEvent, ...)
    end
    return HandleActionCamEvent(...)
end)

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("actionCamEnabled", {
        Enable = UpdateCameraSettings,
        Disable = UpdateCameraSettings,
    })
end
