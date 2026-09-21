--[[ Carpenter - MinimapClutter addon button fader ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Fader = ns.Private.MinimapClutterFader or {}
ns.Private.MinimapClutterFader = Fader

local LFG_MINIMAP_BUTTONS = {
    "MiniMapLFGFrame",
    "MinimapLFGFrame",
    "LFGMinimapFrame",
    "LFGMinimapButton",
    "LookingForGroupMinimapButton",
    "QueueStatusMinimapButton",
}

local FADE_SPEED = 6 -- higher = snappier fade

function Fader.Create(config)
    config = config or {}
    local isEnabled = config.IsEnabled or function() return false end

    local fadeTargets = {}
    local hoverTargets = {}
    local faderFrame = CreateFrame("Frame")
    faderFrame:Hide()

    local function IsAddonMinimapButton(frame)
        if not frame or frame == Minimap then return false end
        local name = frame.GetName and frame:GetName()
        if not name then return false end

        if name == "Minimap"
            or name:find("MiniMapTracking")
            or name:find("MinimapZoneText")
            or name:find("AddonCompartment")
            or name:find("GameTime")
            or name:find("TimeManagerClock")
            or name:find("MinimapCompassTexture")
            or name:find("MinimapNorthTag")
        then
            return false
        end

        if name:find("LibDBIcon") or name:find("MinimapButton") or name:find("MiniMapButton") then
            return true
        end

        return false
    end

    local function RegisterFadeTarget(target, useHoverTarget)
        for _, button in ipairs(fadeTargets) do
            if button == target then
                if useHoverTarget then
                    for _, hoverTarget in ipairs(hoverTargets) do
                        if hoverTarget == target then return end
                    end
                    table.insert(hoverTargets, target)
                end
                return
            end
        end
        table.insert(fadeTargets, target)

        if useHoverTarget then
            table.insert(hoverTargets, target)
        end
    end

    local function RegisterHoverTarget(target)
        if not target or target == Minimap then return end

        for _, hoverTarget in ipairs(hoverTargets) do
            if hoverTarget == target then return end
        end
        table.insert(hoverTargets, target)
    end

    local function IsMouseOverManagedMinimapButton()
        for _, button in ipairs(hoverTargets) do
            if button and button.IsShown and button:IsShown() and
                button.IsMouseOver and button:IsMouseOver()
            then
                return true
            end
        end

        return false
    end

    local function ShouldShowFadedMinimapButtons()
        if not isEnabled() then return false end
        return (Minimap and Minimap.IsMouseOver and Minimap:IsMouseOver()) or
            IsMouseOverManagedMinimapButton()
    end

    local function UpdateFadedMinimapButtonTargets(wakeFader)
        local shouldShow = ShouldShowFadedMinimapButtons()
        local targetAlpha = shouldShow and 1 or 0

        for _, button in ipairs(fadeTargets) do
            if button and button.CP_MinimapFadeManaged then
                button.CP_TargetAlpha = targetAlpha
            end
        end

        if wakeFader and faderFrame then
            faderFrame:Show()
        end

        return shouldShow
    end

    local function WakeMinimapButtonFader()
        UpdateFadedMinimapButtonTargets(true)
    end

    local function HookFadeHoverTarget(target)
        if not target or target == Minimap or target.CP_MinimapFadeHooked or not target.HookScript then return end

        local okEnter = pcall(target.HookScript, target, "OnEnter", WakeMinimapButtonFader)
        local okLeave = pcall(target.HookScript, target, "OnLeave", WakeMinimapButtonFader)
        target.CP_MinimapFadeHooked = okEnter or okLeave
    end

    local function HookMinimapHover()
        if not Minimap or Minimap.CP_MinimapFadeHoverHooked then return end
        Minimap.CP_MinimapFadeHoverHooked = true

        if Minimap.HookScript then
            Minimap:HookScript("OnEnter", WakeMinimapButtonFader)
            Minimap:HookScript("OnLeave", WakeMinimapButtonFader)
        else
            local originalOnEnter = Minimap:GetScript("OnEnter")
            local originalOnLeave = Minimap:GetScript("OnLeave")
            Minimap:SetScript("OnEnter", function(self, ...)
                WakeMinimapButtonFader()
                if originalOnEnter then
                    originalOnEnter(self, ...)
                end
            end)
            Minimap:SetScript("OnLeave", function(self, ...)
                WakeMinimapButtonFader()
                if originalOnLeave then
                    originalOnLeave(self, ...)
                end
            end)
        end
    end

    local function SetupFadedMinimapButton(button, enabled, useHoverTarget)
        if not button or button == Minimap or not button.SetAlpha then return end

        if enabled then
            if useHoverTarget then
                RegisterHoverTarget(button)
                HookFadeHoverTarget(button)
            end
            button.CP_MinimapFadeManaged = true

            RegisterFadeTarget(button, false)
            if faderFrame then faderFrame:Show() end

            button.CP_CurrentAlpha = button.CP_CurrentAlpha or 0
            button.CP_TargetAlpha = ShouldShowFadedMinimapButtons() and 1 or 0
            button:SetAlpha(button.CP_CurrentAlpha)
        else
            button.CP_TargetAlpha = nil
            button.CP_CurrentAlpha = nil
            button:SetAlpha(1)
            button.CP_MinimapFadeManaged = nil
        end
    end

    local function ApplyNamedMinimapButtonClutter(enabled)
        for _, name in ipairs(LFG_MINIMAP_BUTTONS) do
            SetupFadedMinimapButton(_G[name], enabled, true)
        end
    end

    local function ApplyAddonButtonClutter(enabled)
        if enabled and Minimap then
            HookMinimapHover()
        end

        if Minimap and Minimap.GetChildren then
            for i = 1, Minimap:GetNumChildren() do
                local child = select(i, Minimap:GetChildren())
                if IsAddonMinimapButton(child) then
                    SetupFadedMinimapButton(child, enabled, true)
                end
            end
        end

        ApplyNamedMinimapButtonClutter(enabled)
        UpdateFadedMinimapButtonTargets(enabled)
    end

    faderFrame:SetScript("OnUpdate", function(self, elapsed)
        if not isEnabled() then
            self:Hide()
            return
        end
        if not fadeTargets or #fadeTargets == 0 then
            self:Hide()
            return
        end

        UpdateFadedMinimapButtonTargets(false)

        local changed = false
        for _, btn in ipairs(fadeTargets) do
            if btn and btn.CP_TargetAlpha and btn:IsShown() then
                local current = btn.CP_CurrentAlpha or btn:GetAlpha() or 0
                local target = btn.CP_TargetAlpha
                if math.abs(target - current) > 0.01 then
                    local direction = (target > current) and 1 or -1
                    local step = FADE_SPEED * elapsed * direction
                    local nextAlpha = current + step
                    if (direction > 0 and nextAlpha > target) or (direction < 0 and nextAlpha < target) then
                        nextAlpha = target
                    end
                    btn.CP_CurrentAlpha = nextAlpha
                    btn:SetAlpha(nextAlpha)
                    changed = true
                else
                    btn.CP_CurrentAlpha = target
                    btn:SetAlpha(target)
                end
            end
        end

        if not changed then
            self:Hide()
        end
    end)

    local api = {}

    function api.Apply(enabled)
        ApplyAddonButtonClutter(enabled)
        if not enabled then
            faderFrame:Hide()
        end
    end

    return api
end
