--[[ Carpenter - ExtraAbilityScale ]]
-- Scales Retail's Extra Action and Zone Ability buttons to a less intrusive size.

local SCALE_MULTIPLIER = 0.8

local originalScales = setmetatable({}, { __mode = "k" })
local hookedFrames = setmetatable({}, { __mode = "k" })
local applyingScale = false
local pendingCombatApply = false

local function IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function IsEnabled()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("scaleExtraAbilityEnabled")
end

local function CanChangeFrame(frame)
    if not frame then return false end
    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        pendingCombatApply = true
        return false
    end
    return true
end

local function SetManagedScale(frame, enabled)
    if not frame or not frame.SetScale or not frame.GetScale then return end
    if not originalScales[frame] then
        originalScales[frame] = frame:GetScale() or 1
    end
    if not CanChangeFrame(frame) then return end

    local baseScale = originalScales[frame] or 1
    local desiredScale = enabled and (baseScale * SCALE_MULTIPLIER) or baseScale
    local currentScale = frame:GetScale() or 1
    if math.abs(currentScale - desiredScale) <= 0.001 then return end

    applyingScale = true
    frame:SetScale(desiredScale)
    applyingScale = false
end

local function ScheduleApply(delay)
    if Carpenter and Carpenter.After then
        Carpenter:After(delay or 0, Carpenter_ApplyExtraAbilityScale)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, Carpenter_ApplyExtraAbilityScale)
    end
end

local function HookFrame(frame)
    if not frame or hookedFrames[frame] then return end
    hookedFrames[frame] = true

    if frame.HookScript then
        frame:HookScript("OnShow", function()
            ScheduleApply(0)
        end)
    end

    if hooksecurefunc and frame.SetScale then
        hooksecurefunc(frame, "SetScale", function()
            if applyingScale or not IsEnabled() then return end
            ScheduleApply(0)
        end)
    end
end

local function GetFrames()
    local frames = {}

    if ExtraActionBarFrame then
        frames[#frames + 1] = ExtraActionBarFrame
    elseif ExtraActionButton1 then
        frames[#frames + 1] = ExtraActionButton1
    end

    if ZoneAbilityFrame then
        frames[#frames + 1] = ZoneAbilityFrame
    end

    return frames
end

function Carpenter_ApplyExtraAbilityScale()
    if not IsRetail() then return end

    local enabled = IsEnabled()
    local frames = GetFrames()
    for _, frame in ipairs(frames) do
        HookFrame(frame)
        SetManagedScale(frame, enabled)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingCombatApply then return end
    pendingCombatApply = false

    Carpenter_ApplyExtraAbilityScale()
    ScheduleApply(0.2)
    ScheduleApply(1)
end)
