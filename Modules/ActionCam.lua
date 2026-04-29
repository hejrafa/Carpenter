--[[ Carpenter - ActionCam ]]
-- One option: on = Camera Over Shoulder (+1) + Vertical Pitch (screenshot defaults). Off = reset cvars.
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

-- Fixed values from screenshot: offset +1, vertical pitch 0.5 / 0.75 / 0.25 / 10
local OVER_SHOULDER_OFFSET = 1
local PITCH_ON_GROUND = 0.5
local PITCH_FLYING = 0.75
local DOWN_SCALE = 0.25
local SMART_PIVOT_CUTOFF = 10

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

local function UpdateCameraZoom()
    if not CarpenterDB or not CarpenterDB.actionCamEnabled then
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
    if not CarpenterDB then
        return
    end

    if CarpenterDB.actionCamEnabled then
        -- Camera Over Shoulder Offset
        SetCVar("test_cameraOverShoulder", OVER_SHOULDER_OFFSET)
        SetCVar("cameraSmoothingStyle", 0) -- required for offset

        -- Vertical Pitch (screenshot defaults)
        SetCVar("test_cameraDynamicPitch", 1)
        SetCVar("test_cameraDynamicPitchBaseFovPad", PITCH_ON_GROUND)
        SetCVar("test_cameraDynamicPitchBaseFovPadFlying", PITCH_FLYING)
        SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", DOWN_SCALE)
        SetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", SMART_PIVOT_CUTOFF)
        
        -- Update zoom based on mount status
        UpdateCameraZoom()
    else
        ResetCameraCVarsToDefaults()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(self, event, addon, unit)
    if event == "ADDON_LOADED" and addon == "Carpenter" then
        -- Reset CVars immediately if Action Cam is disabled (before Blizzard checks them)
        if not CarpenterDB or not CarpenterDB.actionCamEnabled then
            ResetCameraCVarsToDefaults()
        end
        C_Timer.After(0.1, UpdateCameraSettings)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Also reset on entering world if disabled (in case CVars were set by another addon)
        if not CarpenterDB or not CarpenterDB.actionCamEnabled then
            ResetCameraCVarsToDefaults()
        end
        UpdateCameraSettings()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif (event == "PLAYER_MOUNT_DISPLAY_CHANGED" or
            (event == "UNIT_MODEL_CHANGED" and unit == "player") or
            (event == "UNIT_AURA" and unit == "player")) then
        -- Mount/aura changed; delay so IsMounted() is up to date
        if CarpenterDB and CarpenterDB.actionCamEnabled then
            C_Timer.After(0.25, UpdateCameraZoom)
        end
    end
end)

-- Re-apply when the option is toggled
local watchFrame = CreateFrame("Frame")
watchFrame:RegisterEvent("ADDON_LOADED")
watchFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Carpenter" then
        local last = nil
        C_Timer.NewTicker(0.2, function()
            if CarpenterDB and last ~= CarpenterDB.actionCamEnabled then
                last = CarpenterDB.actionCamEnabled
                UpdateCameraSettings()
            end
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Periodic check for mount status as a safety net (in case events are missed)
local mountCheckFrame = CreateFrame("Frame")
mountCheckFrame:RegisterEvent("ADDON_LOADED")
mountCheckFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Carpenter" then
        local lastMounted = nil
        C_Timer.NewTicker(0.5, function()
            if CarpenterDB and CarpenterDB.actionCamEnabled then
                local isMounted = IsMounted()
                if lastMounted ~= isMounted then
                    lastMounted = isMounted
                    UpdateCameraZoom()
                end
            end
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
