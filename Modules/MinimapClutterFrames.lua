--[[ Carpenter - MinimapClutter frame helpers ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Frames = ns.Private.MinimapClutterFrames or {}
ns.Private.MinimapClutterFrames = Frames

local MINIMAP_FRAMES = {
    "MinimapZoomIn",
    "MinimapZoomOut",
    "GameTimeFrame",          -- Day/Night icon / clock frame
    "MinimapZoneTextButton",  -- Clickable zone text
    "MinimapZoneText",        -- Zone text fontstring
    "MinimapBorderTop",       -- Old-style zone text background art/strip above the minimap
    "MinimapCloseButton",     -- Old-style close button sitting on that strip
    "MinimapToggleButton",    -- Old-style plus/minus minimap toggle button
}

function Frames.Create(config)
    config = config or {}
    local isEnabled = config.IsEnabled or function() return false end

    local function HideMinimapFrame(frame)
        if not frame then return end

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

    local function ApplyClusterTweaks()
        local cluster = _G["MinimapCluster"]
        if not cluster then return end

        if cluster.BorderTop then
            HideMinimapFrame(cluster.BorderTop)
        end
        if cluster.CloseButton then
            HideMinimapFrame(cluster.CloseButton)
        end
        if cluster.ToggleButton then
            HideMinimapFrame(cluster.ToggleButton)
        end
    end

    local api = {}

    function api.Apply(enabled)
        if not enabled then
            for _, name in ipairs(MINIMAP_FRAMES) do
                local frame = _G[name]
                if frame then
                    frame:SetAlpha(1)
                    frame:Show()
                end
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

    function api.EnableMouseWheelZoom()
        if not Minimap or not Minimap.GetZoom or not Minimap.SetZoom then return end

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

    return api
end
