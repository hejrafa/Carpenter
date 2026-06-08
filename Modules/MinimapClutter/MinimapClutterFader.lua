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

local CLASSIC_TRACKING_MINIMAP_BUTTONS = {
    "MiniMapTracking",
    "MiniMapTrackingFrame",
    "MiniMapTrackingButton",
}

local FADE_SPEED = 6 -- higher = snappier fade

function Fader.Create(config)
    config = config or {}
    local isEnabled = config.IsEnabled or function() return false end
    local isClassicClient = config.IsClassicClient or function() return false end

    local addonButtons = {}
    local faderFrame = CreateFrame("Frame")
    faderFrame:Hide()

    local function IsAddonMinimapButton(frame)
        if not frame or frame == Minimap then return false end
        local name = frame.GetName and frame:GetName()
        if not name then return false end

        if name == "Minimap"
            or name:find("MiniMapTracking")
            or name:find("MinimapZoneText")
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

    local function RegisterAddonButton(btn)
        for _, button in ipairs(addonButtons) do
            if button == btn then return end
        end
        table.insert(addonButtons, btn)
    end

    local function IsMouseOverManagedMinimapButton()
        if not MouseIsOver then return false end

        for _, button in ipairs(addonButtons) do
            if button and button.IsShown and button:IsShown() and MouseIsOver(button) then
                return true
            end
        end

        return false
    end

    local function ShouldShowFadedMinimapButtons()
        if not isEnabled() or not MouseIsOver then return false end
        return (Minimap and MouseIsOver(Minimap)) or IsMouseOverManagedMinimapButton()
    end

    local function UpdateFadedMinimapButtonTargets(wakeFader)
        local shouldShow = ShouldShowFadedMinimapButtons()
        local targetAlpha = shouldShow and 1 or 0

        for _, button in ipairs(addonButtons) do
            if button and button.CP_MinimapFadeHooked then
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

    local function SetupFadedMinimapButton(button, enabled)
        if not button or button == Minimap or not button.SetAlpha or not button.SetScript then return end

        if enabled then
            if not button.CP_MinimapFadeHooked then
                button.CP_OrigOnEnter = button:GetScript("OnEnter")
                button.CP_OrigOnLeave = button:GetScript("OnLeave")
                button.CP_MinimapFadeHooked = true
            end

            RegisterAddonButton(button)
            if faderFrame then faderFrame:Show() end

            button.CP_CurrentAlpha = button.CP_CurrentAlpha or 0
            button.CP_TargetAlpha = ShouldShowFadedMinimapButtons() and 1 or 0
            button:SetAlpha(button.CP_CurrentAlpha)
            button:EnableMouse(true)

            button:SetScript("OnEnter", function(self)
                WakeMinimapButtonFader()
                if self.CP_OrigOnEnter then
                    self.CP_OrigOnEnter(self)
                end
            end)

            button:SetScript("OnLeave", function(self)
                WakeMinimapButtonFader()
                if self.CP_OrigOnLeave then
                    self.CP_OrigOnLeave(self)
                end
            end)
        else
            button.CP_TargetAlpha = nil
            button.CP_CurrentAlpha = nil
            button:SetAlpha(1)
            if button.CP_MinimapFadeHooked or button.CP_OrigOnEnter or button.CP_OrigOnLeave then
                button:SetScript("OnEnter", button.CP_OrigOnEnter)
                button:SetScript("OnLeave", button.CP_OrigOnLeave)
            end
            button.CP_MinimapFadeHooked = nil
        end
    end

    local function ApplyNamedMinimapButtonClutter(enabled)
        for _, name in ipairs(LFG_MINIMAP_BUTTONS) do
            SetupFadedMinimapButton(_G[name], enabled)
        end

        if isClassicClient() then
            for _, name in ipairs(CLASSIC_TRACKING_MINIMAP_BUTTONS) do
                SetupFadedMinimapButton(_G[name], enabled)
            end
        end
    end

    local function ApplyAddonButtonClutter(enabled)
        if not Minimap or not Minimap.GetChildren then return end

        if enabled then
            HookMinimapHover()
        end

        for i = 1, Minimap:GetNumChildren() do
            local child = select(i, Minimap:GetChildren())
            if IsAddonMinimapButton(child) then
                SetupFadedMinimapButton(child, enabled)
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
        if not addonButtons or #addonButtons == 0 then
            self:Hide()
            return
        end

        local shouldShow = UpdateFadedMinimapButtonTargets(false)

        local changed = false
        for _, btn in ipairs(addonButtons) do
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

        if not changed and not shouldShow then
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
