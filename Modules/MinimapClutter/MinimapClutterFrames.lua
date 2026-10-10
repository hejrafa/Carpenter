--[[ Carpenter - MinimapClutter frame helpers ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Frames = ns.Private.MinimapClutterFrames or {}
ns.Private.MinimapClutterFrames = Frames

local MINIMAP_FRAMES = {
    "MinimapZoomIn",
    "MinimapZoomOut",
    "MinimapCloseButton",     -- Old-style close button sitting on that strip
    "MinimapToggleButton",    -- Old-style plus/minus minimap toggle button
}

function Frames.Create(config)
    config = config or {}
    local isEnabled = config.IsEnabled or function() return false end
    local isRetailClient = config.IsRetailClient or function() return false end
    local hiddenFrames = {}
    local mutedButtons = {}

    local function HideMinimapFrame(frame)
        if not frame then return end

        if not hiddenFrames[frame] then
            local shown = frame.IsShown and frame:IsShown()
            local alpha = frame.GetAlpha and frame:GetAlpha()
            hiddenFrames[frame] = {
                shown = shown,
                alpha = alpha,
            }
        end

        frame:Hide()
        frame:SetAlpha(0)

        if not frame.IsCPMinimapHooked then
            hooksecurefunc(frame, "Show", function(self)
                if isEnabled() then
                    self:Hide()
                    self:SetAlpha(0)
                end
            end)
            frame.IsCPMinimapHooked = true
        end
    end

    local function RestoreMinimapFrames()
        for hiddenFrame, state in pairs(hiddenFrames) do
            if hiddenFrame then
                if hiddenFrame.SetAlpha then
                    hiddenFrame:SetAlpha(state.alpha ~= nil and state.alpha or 1)
                end
                if state.shown == false then
                    if hiddenFrame.Hide then hiddenFrame:Hide() end
                elseif hiddenFrame.Show then
                    hiddenFrame:Show()
                end
            end
        end
        hiddenFrames = {}
    end

    -- Forever and Retail show Minimap.ZoomIn/ZoomOut on every hover, and the
    -- mouse wheel zooms by clicking them. Keep them shown but invisible and
    -- unclickable instead of hiding them, so wheel zoom keeps working.
    local function MuteZoomButton(button)
        if not button or not button.SetAlpha then return end
        if not mutedButtons[button] then
            mutedButtons[button] = {
                alpha = button.GetAlpha and button:GetAlpha(),
                mouse = not button.IsMouseEnabled or button:IsMouseEnabled(),
            }
        end
        button:SetAlpha(0)
        if button.EnableMouse then button:EnableMouse(false) end
    end

    local function RestoreZoomButtons()
        for button, state in pairs(mutedButtons) do
            button:SetAlpha(state.alpha ~= nil and state.alpha or 1)
            if button.EnableMouse then button:EnableMouse(state.mouse) end
        end
        mutedButtons = {}
    end

    local function ApplyClusterTweaks()
        local cluster = _G["MinimapCluster"]
        if not cluster then return end

        if cluster.CloseButton then
            HideMinimapFrame(cluster.CloseButton)
        end
        if cluster.ToggleButton then
            HideMinimapFrame(cluster.ToggleButton)
        end
    end

    local function HideDayNightArtwork()
        local cluster = _G["MinimapCluster"]
        if cluster and cluster.DielFrame then
            HideMinimapFrame(cluster.DielFrame)
        end
    end

    local api = {}

    function api.Apply(enabled)
        if not enabled then
            RestoreMinimapFrames()
            RestoreZoomButtons()
            return
        end

        -- Forever exposes its day/night artwork as a separate DielFrame. Never
        -- hide the calendar here; the fader fades it with the minimap header.
        HideDayNightArtwork()

        if isRetailClient() then
            if Minimap then
                MuteZoomButton(Minimap.ZoomIn)
                MuteZoomButton(Minimap.ZoomOut)
            end
            return
        end

        for _, name in ipairs(MINIMAP_FRAMES) do
            local frame = _G[name]
            if frame then
                HideMinimapFrame(frame)
            end
        end

        ApplyClusterTweaks()
    end

    local mouseWheelZoomEnabled = false
    local originalMouseWheelEnabled
    local originalMouseWheelScript

    function api.EnableMouseWheelZoom()
        if not Minimap or not Minimap.GetZoom or not Minimap.SetZoom then return end

        if not mouseWheelZoomEnabled then
            originalMouseWheelEnabled = Minimap.IsMouseWheelEnabled and Minimap:IsMouseWheelEnabled() or false
            originalMouseWheelScript = Minimap:GetScript("OnMouseWheel")
            mouseWheelZoomEnabled = true
        end

        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", function(self, delta)
            local currentZoom = self:GetZoom() or 0
            local maxZoom = (self.GetZoomLevels and self:GetZoomLevels()) or 5

            if delta > 0 and currentZoom < maxZoom - 1 then
                self:SetZoom(currentZoom + 1)
            elseif delta < 0 and currentZoom > 0 then
                self:SetZoom(currentZoom - 1)
            end
        end)
    end

    function api.DisableMouseWheelZoom()
        if not mouseWheelZoomEnabled or not Minimap then return end

        Minimap:SetScript("OnMouseWheel", originalMouseWheelScript)
        Minimap:EnableMouseWheel(originalMouseWheelEnabled)
        mouseWheelZoomEnabled = false
    end

    return api
end
