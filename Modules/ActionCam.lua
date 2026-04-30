--[[ Carpenter - ActionCam ]]
-- One option: on = Camera Over Shoulder (+1). Off = reset camera cvars.
-- Nudges the camera out a little when you mount; on dismount zooms back in to where you were.

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

-- Keep Action Cam performance-safe: over-shoulder framing without Blizzard's
-- experimental dynamic pitch, which can be expensive while flying.
local OVER_SHOULDER_OFFSET = 1
local SPELL_OVERLAY_OFFSET_Y = -80

-- Smooth zoom: small steps, only on real mount/dismount transitions (debounced).
local MOUNT_ZOOM_STEPS = 10
local MOUNT_ZOOM_INCREMENT = 0.2
local MOUNT_ZOOM_INTERVAL = 0.02
-- Dismount: same steps/increment as mount so we return to the same zoom level.
local DISMOUNT_ZOOM_STEPS = MOUNT_ZOOM_STEPS
local DISMOUNT_ZOOM_INCREMENT = MOUNT_ZOOM_INCREMENT
local DISMOUNT_ZOOM_INTERVAL = MOUNT_ZOOM_INTERVAL

local lastMounted = nil   -- last mount state we actually acted on (so we only act on transition)
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

UpdateSpellOverlayOffset = function()
    if not IsRetail() or not SpellActivationOverlayFrame then return end

    HookSpellOverlay()
    spellOverlayApplying = true
    SpellActivationOverlayFrame:ClearAllPoints()
    if IsEnabled() then
        SpellActivationOverlayFrame:SetPoint("CENTER", UIParent, "CENTER", 0, SPELL_OVERLAY_OFFSET_Y)
    else
        SpellActivationOverlayFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
    if zoomInProgress then
        return
    end
    
    local isMounted = (IsMounted and IsMounted()) and true or false
    
    -- Only act when mount state *changes* (never on first run)
    if lastMounted == nil then
        lastMounted = isMounted
        return
    end
    if lastMounted == isMounted then
        return
    end
    lastMounted = isMounted
    
    if isMounted and CameraZoomOut then
        zoomInProgress = true
        for i = 1, MOUNT_ZOOM_STEPS do
            C_Timer.After(MOUNT_ZOOM_INTERVAL * i, function()
                if CameraZoomOut then CameraZoomOut(MOUNT_ZOOM_INCREMENT) end
                if i == MOUNT_ZOOM_STEPS then
                    zoomInProgress = false
                end
            end)
        end
    elseif not isMounted and CameraZoomIn then
        zoomInProgress = true
        for i = 1, DISMOUNT_ZOOM_STEPS do
            C_Timer.After(DISMOUNT_ZOOM_INTERVAL * i, function()
                if CameraZoomIn then CameraZoomIn(DISMOUNT_ZOOM_INCREMENT) end
                if i == DISMOUNT_ZOOM_STEPS then
                    zoomInProgress = false
                end
            end)
        end
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
        -- Camera Over Shoulder Offset
        SetCVar("test_cameraOverShoulder", OVER_SHOULDER_OFFSET)
        SetCVar("cameraSmoothingStyle", 0) -- required for offset

        SetCVar("test_cameraDynamicPitch", 0)
        
        -- Update zoom based on mount status
        UpdateCameraZoom()
        UpdateSpellOverlayOffset()
    else
        ResetCameraCVarsToDefaults()
        UpdateSpellOverlayOffset()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
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
