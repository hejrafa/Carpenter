--[[ Carpenter - MinimapFade ]]
-- Fades the minimap and everything around it (zone name, clock, tracking,
-- addon buttons) and reveals it on hover with a smooth transition.

local HOVER_PADDING = 14
local HoverFade = Carpenter.HoverFade

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("minimapFadeEnabled")
end

-- =========================
-- Core Logic: Hover Fading
-- =========================

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

    -- Hidden frames keep their edges, so the hidden map still counts as
    -- hovered: no visibility check.
    local IsHovered = HoverFade.IsMouseOverPaddedFrame
    return IsHovered(cluster, HOVER_PADDING)
        or IsHovered(cluster and cluster.MinimapContainer, HOVER_PADDING)
        or IsHovered(_G.Minimap, HOVER_PADDING)
end

local fader = HoverFade.Create({
    isEnabled = IsEnabled,
    shouldShow = ShouldShow,
    apply = function(alpha)
        if alpha > 0 then SetMinimapHidden(false) end
        SetFadeAlpha(alpha)
    end,
    -- The map stays hidden while fully faded, even if something shows it.
    onTick = function(alpha)
        if alpha == 0 then SetMinimapHidden(true) end
    end,
})

local feature = {}

function feature:Enable()
    SetMinimapIgnoresParentAlpha(true)
    fader:Start(0)
    SetMinimapHidden(true)
end

function feature:Disable()
    fader:Stop(1)
    SetMinimapIgnoresParentAlpha(false)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("minimapFadeEnabled", feature)
end
