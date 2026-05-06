--[[ Carpenter - MinimapClutter ]]
-- Hides minimap zoom buttons, day/night icon, and zone text/border for a cleaner minimap.

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("minimapClutterEnabled")
end

-- =========================
-- Core
-- =========================

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

local function HideMinimapFrame(frame)
    if not frame then return end

    frame:Hide()
    frame:SetAlpha(0)

    if not frame.IsCPMinimapHooked then
        hooksecurefunc(frame, "Show", function(self)
            if IsEnabled() then
                self:Hide()
                self:SetAlpha(0)
            end
        end)
        frame.IsCPMinimapHooked = true
    end
end

-- Some clients (like the Anniversary/TBC hybrid) group the minimap into MinimapCluster
-- with sub-frames like BorderTop and a CloseButton. Handle those explicitly as well.
local function ApplyClusterTweaks()
    local cluster = _G["MinimapCluster"]
    if not cluster then return end

    -- Strip with zone text + close button, e.g. MinimapCluster.BorderTop
    if cluster.BorderTop then
        HideMinimapFrame(cluster.BorderTop)
    end

    -- Close button attached to the cluster (newer naming)
    if cluster.CloseButton then
        HideMinimapFrame(cluster.CloseButton)
    end

    -- Minimap visibility toggle attached to the cluster (e.g. MinimapCluster.ToggleButton)
    if cluster.ToggleButton then
        HideMinimapFrame(cluster.ToggleButton)
    end
end

-- Treat common addon minimap buttons (LibDBIcon, generic minimap buttons) as clutter and fade them
-- until hovered, similar in spirit to LibDBIconStub:ShowOnEnter(), but with smooth alpha transitions.
local function IsAddonMinimapButton(frame)
    if not frame or frame == Minimap then return false end
    local name = frame.GetName and frame:GetName()
    if not name then return false end

    -- Ignore core Blizzard minimap elements we explicitly manage elsewhere.
    if name == "Minimap"
        or name:find("MiniMapTracking")
        or name:find("MinimapZoneText")
        or name:find("MinimapCompassTexture")
        or name:find("MinimapNorthTag")
    then
        return false
    end

    -- Common patterns for addon buttons
    if name:find("LibDBIcon") or name:find("MinimapButton") or name:find("MiniMapButton") then
        return true
    end

    return false
end

-- Simple registry + fader for addon buttons we manage
local CP_AddonButtons = {}
local CP_FaderFrame

local function RegisterAddonButton(btn)
    for _, b in ipairs(CP_AddonButtons) do
        if b == btn then return end
    end
    table.insert(CP_AddonButtons, btn)
end

local function ApplyAddonButtonClutter(enabled)
    if not Minimap or not Minimap.GetChildren then return end

    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if IsAddonMinimapButton(child) then
            if enabled then
                if not child.CP_OrigOnEnter then
                    child.CP_OrigOnEnter = child:GetScript("OnEnter")
                    child.CP_OrigOnLeave = child:GetScript("OnLeave")
                end

                RegisterAddonButton(child)
                if CP_FaderFrame then CP_FaderFrame:Show() end

                child.CP_CurrentAlpha = child.CP_CurrentAlpha or 0
                child.CP_TargetAlpha = 0
                child:SetAlpha(child.CP_CurrentAlpha)
                child:EnableMouse(true)

                child:SetScript("OnEnter", function(self)
                    self.CP_TargetAlpha = 1
                    if CP_FaderFrame then CP_FaderFrame:Show() end
                    if self.CP_OrigOnEnter then
                        self.CP_OrigOnEnter(self)
                    end
                end)

                child:SetScript("OnLeave", function(self)
                    self.CP_TargetAlpha = 0
                    if CP_FaderFrame then CP_FaderFrame:Show() end
                    if self.CP_OrigOnLeave then
                        self.CP_OrigOnLeave(self)
                    end
                end)
            else
                -- Restore when clutter option is disabled
                child.CP_TargetAlpha = nil
                child.CP_CurrentAlpha = nil
                child:SetAlpha(1)
                if child.CP_OrigOnEnter or child.CP_OrigOnLeave then
                    child:SetScript("OnEnter", child.CP_OrigOnEnter)
                    child:SetScript("OnLeave", child.CP_OrigOnLeave)
                end
            end
        end
    end
end

-- Smooth fader that lerps addon button alpha toward target over time
CP_FaderFrame = CreateFrame("Frame")
local FADE_SPEED = 6 -- higher = snappier fade

CP_FaderFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then
        self:Hide()
        return
    end
    if not CP_AddonButtons or #CP_AddonButtons == 0 then
        self:Hide()
        return
    end

    local changed = false
    for _, btn in ipairs(CP_AddonButtons) do
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

-- Enable mousewheel zoom on the minimap so hiding zoom buttons doesn't remove the ability to zoom.
local function EnableMouseWheelZoom()
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

local function ApplyMinimapClutter()
    if not IsEnabled() then
        -- If the feature is disabled, restore Blizzard defaults (best-effort).
        for _, name in ipairs(MINIMAP_FRAMES) do
            local frame = _G[name]
            if frame then
                frame:SetAlpha(1)
                frame:Show()
            end
        end
        -- Restore addon minimap buttons if we previously faded them.
        ApplyAddonButtonClutter(false)
        CP_FaderFrame:Hide()
        return
    end

    for _, name in ipairs(MINIMAP_FRAMES) do
        local frame = _G[name]
        if frame then
            HideMinimapFrame(frame)
        end
    end

    -- Also handle cluster-based implementations like: MinimapCluster.BorderTop:Hide()
    ApplyClusterTweaks()

    -- Fade addon minimap buttons until hovered.
    ApplyAddonButtonClutter(true)

    -- Always make sure scrolling the minimap still controls zoom.
    EnableMouseWheelZoom()
end

-- =========================
-- Events
-- =========================

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function()
    ApplyMinimapClutter()
end)
CP_FaderFrame:Hide()

local feature = {}

function feature:Enable()
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    ApplyMinimapClutter()
    -- Re-enforce shortly after login/zone to catch any late layout changes.
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("MinimapClutter:startup", { 1, 5 }, ApplyMinimapClutter)
    else
        C_Timer.After(1, ApplyMinimapClutter)
        C_Timer.After(5, ApplyMinimapClutter)
    end
end

function feature:Disable()
    f:UnregisterAllEvents()
    ApplyMinimapClutter()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("minimapClutterEnabled", feature)
end
