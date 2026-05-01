--[[ Carpenter - ActionCam ]]
-- One option: on = DynamicCam-style over-shoulder framing. Off = reset camera cvars.
-- Uses default camera framing, then eases to a mounted zoom value while mounted.

-- Suppress Blizzard's "experimental camera features" / "visual discomfort" popup and sound.
-- Same approach as YUI-Dialogue (https://github.com/Peterodox/YUI-Dialogue): unregister the
-- event so the confirmation never fires (no popup, no sound, no taint).
local function suppressCameraWarning()
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end
suppressCameraWarning()
-- In case the default UI registers it after we load:
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Carpenter" then
        suppressCameraWarning()
    end
end)

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

local lastMounted = nil   -- last mount state we actually acted on (so we only act on transition)
local preMountZoom = nil
local zoomSequence = 0
local zoomInProgress = false  -- prevent overlapping zoom sequences
local zoomCheckScheduled = false
local spellOverlayHooked = false
local spellOverlayApplying = false
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
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function GetCurrentZoom()
    if GetCameraZoom then
        return GetCameraZoom()
    end
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

    hooksecurefunc(SpellActivationOverlayFrame, "SetPoint", function()
        if spellOverlayApplying then return end
        ScheduleSpellOverlayOffset(0)
    end)

    hooksecurefunc(SpellActivationOverlayFrame, "SetAllPoints", function()
        if spellOverlayApplying then return end
        ScheduleSpellOverlayOffset(0)
    end)

    if _G.SpellActivationOverlay_ShowOverlay then
        hooksecurefunc("SpellActivationOverlay_ShowOverlay", function()
            ScheduleSpellOverlayOffset(0)
        end)
    end

    spellOverlayHooked = true
end

local function UpdateCameraZoom()
    zoomCheckScheduled = false
    if not IsEnabled() then
        return
    end
    local isMounted = (IsMounted and IsMounted()) and true or false
    
    if lastMounted == nil then
        lastMounted = isMounted
        if isMounted then
            preMountZoom = GetCurrentZoom()
            SmoothZoomTo(MOUNT_ZOOM_VALUE, MOUNT_ZOOM_TRANSITION_TIME)
        end
        return
    end
    if lastMounted == isMounted then
        return
    end
    lastMounted = isMounted
    
    if isMounted then
        preMountZoom = GetCurrentZoom()
        SmoothZoomTo(MOUNT_ZOOM_VALUE, MOUNT_ZOOM_TRANSITION_TIME)
    elseif preMountZoom then
        SmoothZoomTo(preMountZoom, MOUNT_ZOOM_TRANSITION_TIME)
        preMountZoom = nil
    end
end

local function ScheduleCameraZoomCheck(delay)
    if zoomCheckScheduled then return end
    zoomCheckScheduled = true
    C_Timer.After(delay or 0.25, UpdateCameraZoom)
end

local function ResetCameraCVarsToDefaults()
    -- Reset all camera CVars to safe defaults so Blizzard doesn't show the warning
    SetCVar("test_cameraOverShoulder", 0)
    SetCVar("test_cameraDynamicPitch", 0)
    SetCVar("test_cameraDynamicPitchBaseFovPad", 0.4)  -- default
    SetCVar("test_cameraDynamicPitchBaseFovPadFlying", 0.75)  -- default
    SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25)  -- default
    SetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 10)  -- default
end

local function UpdateCameraSettings()
    if IsEnabled() then
        SetCVar("test_cameraOverShoulder", OVER_SHOULDER_OFFSET)
        SetCVar("cameraSmoothingStyle", 0) -- required for offset

        SetCVar("test_cameraDynamicPitch", 1)
        SetCVar("test_cameraDynamicPitchBaseFovPad", DYNAMIC_PITCH_GROUND)
        SetCVar("test_cameraDynamicPitchBaseFovPadFlying", DYNAMIC_PITCH_FLYING)
        SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", DYNAMIC_PITCH_DOWN_SCALE)
        SetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", SMART_PIVOT_CUTOFF_DISTANCE)
        
        -- Update zoom based on mount status
        UpdateCameraZoom()
        UpdateSpellOverlayOffset()
    else
        CancelZoomTransition()
        ResetCameraCVarsToDefaults()
        UpdateSpellOverlayOffset()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")

local function HandleActionCamEvent(self, event, addon, unit)
    if event == "ADDON_LOADED" and addon == "Carpenter" then
        -- Reset CVars immediately if Action Cam is disabled (before Blizzard checks them)
        if not IsEnabled() then
            ResetCameraCVarsToDefaults()
        end
        C_Timer.After(0.1, UpdateCameraSettings)
    elseif event == "ADDON_LOADED" and addon == "Blizzard_SpellActivationOverlay" then
        ScheduleSpellOverlayOffset(0)
        ScheduleSpellOverlayOffset(0.1)
    elseif event == "PLAYER_LOGIN" then
        UpdateCameraSettings()
        ScheduleSpellOverlayOffset(0)
        ScheduleSpellOverlayOffset(0.1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Also reset on entering world if disabled (in case CVars were set by another addon)
        if not IsEnabled() then
            ResetCameraCVarsToDefaults()
        end
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
            (event == "UNIT_MODEL_CHANGED" and unit == "player")) then
        -- Mount/aura changed; delay so IsMounted() is up to date
        if IsEnabled() then
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

function Carpenter_ApplyActionCam()
    UpdateCameraSettings()
end
