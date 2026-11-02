--[[ Carpenter - MinimapFade ]]
-- Fades the minimap and everything around it (zone name, clock, tracking,
-- addon buttons) and reveals it on hover with a smooth transition.

local FADE_IN_SECONDS = 0.2
local FADE_OUT_SECONDS = 0.6
local HOVER_PADDING = 14
local UPDATE_INTERVAL = 0.05

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("minimapFadeEnabled")
end

-- =========================
-- Core Logic: Hover Fading
-- =========================

local currentAlpha = 1
local minimapHiddenByFade = false

-- Every client keeps the map, its header, and addon buttons inside
-- MinimapCluster, so its alpha fades the header. The map itself is drawn
-- by the engine from the Minimap frame's own alpha, so a cluster-only fade
-- left the map and the buttons on it at full strength until it was hidden.
-- The map therefore gets the same alpha directly and ignores the cluster's,
-- so the buttons on it fade once rather than twice.
local minimapIgnoredParentAlpha
local function SetFadeAlpha(alpha)
    local cluster, minimap = _G.MinimapCluster, _G.Minimap
    if cluster then cluster:SetAlpha(alpha) end
    if minimap then minimap:SetAlpha(alpha) end
end

local function SetMinimapIgnoresParentAlpha(ignore)
    local minimap = _G.Minimap
    if not minimap or not minimap.SetIgnoreParentAlpha then return end
    if ignore then
        if minimapIgnoredParentAlpha == nil then
            minimapIgnoredParentAlpha = minimap.IsIgnoringParentAlpha and minimap:IsIgnoringParentAlpha() or false
        end
        minimap:SetIgnoreParentAlpha(true)
    elseif minimapIgnoredParentAlpha ~= nil then
        minimap:SetIgnoreParentAlpha(minimapIgnoredParentAlpha)
        minimapIgnoredParentAlpha = nil
    end
end

-- The game draws the player arrow, group dots, and tracking icons over the
-- map without its alpha, so the map is hidden once it has fully faded. A
-- minimap the player hid themselves stays hidden.
local function SetMinimapHidden(hidden)
    local minimap = _G.Minimap
    if not minimap then return end

    if hidden then
        if minimap:IsShown() then
            minimap:Hide()
            minimapHiddenByFade = true
        end
    elseif minimapHiddenByFade then
        minimapHiddenByFade = false
        minimap:Show()
    end
end

-- Hidden frames keep their edges, so the hidden map still counts as hovered.
local function IsMouseOverPaddedFrame(frame, padding)
    if not frame or not frame.GetLeft then return false end

    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end

    -- A frame's edges are in its own scale, which Edit Mode can change.
    local scale = (frame.GetEffectiveScale and frame:GetEffectiveScale())
        or (UIParent and UIParent:GetEffectiveScale()) or 1
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale

    return x >= left - padding and x <= right + padding and y >= bottom - padding and y <= top + padding
end

local function IsMenuOpen(button)
    return button and button.IsMenuOpen and button:IsMenuOpen() == true
end

local function ShouldShow()
    -- Edit Mode needs to see the minimap to move it.
    local editMode = _G.EditModeManagerFrame
    if editMode and editMode.IsEditModeActive and editMode:IsEditModeActive() then
        return true
    end

    -- Keep it up while its tracking or addon compartment menu is open.
    local cluster = _G.MinimapCluster
    if IsMenuOpen(cluster and cluster.Tracking and cluster.Tracking.Button)
        or IsMenuOpen(_G.MiniMapTrackingButton)
        or IsMenuOpen(_G.AddonCompartmentFrame)
    then
        return true
    end

    return IsMouseOverPaddedFrame(cluster, HOVER_PADDING)
        or IsMouseOverPaddedFrame(cluster and cluster.MinimapContainer, HOVER_PADDING)
        or IsMouseOverPaddedFrame(_G.Minimap, HOVER_PADDING)
end

local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then
        self:Hide()
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    local step = self.elapsed
    self.elapsed = 0

    local targetAlpha = ShouldShow() and 1 or 0
    if currentAlpha < targetAlpha then
        SetMinimapHidden(false)
        currentAlpha = math.min(targetAlpha, currentAlpha + step / FADE_IN_SECONDS)
        SetFadeAlpha(currentAlpha)
    elseif currentAlpha > targetAlpha then
        currentAlpha = math.max(targetAlpha, currentAlpha - step / FADE_OUT_SECONDS)
        SetFadeAlpha(currentAlpha)
    end

    if currentAlpha == 0 then
        SetMinimapHidden(true)
    end
end)

local feature = {}

function feature:Enable()
    currentAlpha = 0
    SetMinimapIgnoresParentAlpha(true)
    SetFadeAlpha(0)
    SetMinimapHidden(true)
    updateFrame:Show()
end

function feature:Disable()
    updateFrame:Hide()
    currentAlpha = 1
    SetMinimapHidden(false)
    SetFadeAlpha(1)
    SetMinimapIgnoresParentAlpha(false)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("minimapFadeEnabled", feature)
end
