--[[ Carpenter - NameplateComboPoints ]]
-- Shows Rogue TargetFrame-style combo points under CURRENT TARGET's nameplate.

local _, ns = ...
local Nameplates = ns and ns.Private and ns.Private.Nameplates or {}
local addonFrame = CreateFrame("Frame")
local resourceFrame
local resourcePoints = {
    base = {},
    active = {}
}

-- Using the same sprite sheet for both states
local COMBO_TEXTURE = "Interface\\ComboFrame\\ComboPoint"

-- Scales the whole group at once so the socket, dot, and alignment tuning
-- below keep their proportions.
local COMBO_SCALE = 1.25

-- Offsets from the bottom of the nameplate health bar, in nameplate pixels.
-- Anchoring to the health bar keeps the points in place when nameplate size
-- changes. They are divided by COMBO_SCALE at anchor time so resizing the
-- group does not also move it.
local OFFSET_X = 0
local OFFSET_Y = 3

-- =========================================================
-- Configuration
-- =========================================================
local function isEnabled()
    return Carpenter and Carpenter:IsEnabled("nameplateComboEnabled")
end

-- =========================================================
-- Visual Setup
-- =========================================================
local function ensureResourceFrame()
    if resourceFrame then return end

    -- Create the main container
    resourceFrame = CreateFrame("Frame", "CarpenterComboFrame", UIParent)
    resourceFrame:Hide()
    resourceFrame:SetScale(COMBO_SCALE)

    -- Base 9x10 keeps the sockets compact while making them easier to read.
    local texW, texH = 9, 10
    local padding = 2
    local totalWidth = (texW * 5) + (padding * 4)
    resourceFrame:SetSize(totalWidth, texH)

    for i = 1, 5 do
        -- 1. Create the Base Socket (The "Default" texture)
        local base = resourceFrame:CreateTexture(nil, "BACKGROUND")
        base:SetSize(texW, texH)
        base:SetTexture(COMBO_TEXTURE)
        -- Standard Blizzard mapping for the empty socket
        base:SetTexCoord(0, 0.375, 0, 1)

        if i == 1 then
            base:SetPoint("LEFT", resourceFrame, "LEFT", 0, 0)
        else
            base:SetPoint("LEFT", resourcePoints.base[i - 1], "RIGHT", padding, 0)
        end

        -- 2. Create the Active Dot (The "Red" texture on top)
        local active = resourceFrame:CreateTexture(nil, "OVERLAY")
        active:SetSize(8, 14)
        active:SetTexture(COMBO_TEXTURE)
        -- Clean circular crop
        active:SetTexCoord(0.395, 0.655, 0, 1)

        -- ALIGNMENT:
        -- Shifted back left by 1 (from 2.5 to 1.5)
        active:SetPoint("CENTER", base, "CENTER", 1.5, -0.8)
        active:SetAlpha(1)
        active:Hide()

        resourcePoints.base[i] = base
        resourcePoints.active[i] = active
    end
end

local function setComboVisual(cp)
    ensureResourceFrame()
    resourceFrame:Show()

    for i = 1, 5 do
        -- Base sockets are always shown
        resourcePoints.base[i]:Show()

        -- Red active dots logic
        if i <= cp then
            resourcePoints.active[i]:Show()
        else
            resourcePoints.active[i]:Hide()
        end
    end
end

-- =========================================================
-- Core Logic
-- =========================================================
local StartFollowTicker
local StopFollowTicker
local followTickerActive = false

local function update()
    if not isEnabled() then
        if resourceFrame then resourceFrame:Hide() end
        if StopFollowTicker then StopFollowTicker() end
        addonFrame:Hide()
        return
    end

    -- 1. Check Target validity
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
        if resourceFrame then resourceFrame:Hide() end
        if StopFollowTicker then StopFollowTicker() end
        addonFrame:Hide()
        return
    end

    -- 2. Find Nameplate
    local plate = Nameplates.GetForUnit and Nameplates.GetForUnit("target")
    if not plate then
        if resourceFrame then resourceFrame:Hide() end
        if StopFollowTicker then StopFollowTicker() end
        addonFrame:Hide()
        return
    end

    -- 3. Get Combo Points
    local cp = GetComboPoints("player", "target") or 0

    -- 4. Anchor and Display
    ensureResourceFrame()

    -- Re-parent to the plate directly for movement synchronization
    if resourceFrame:GetParent() ~= plate then
        resourceFrame:SetParent(plate)
    end

    resourceFrame:ClearAllPoints()
    resourceFrame:SetFrameStrata("TOOLTIP")
    resourceFrame:SetFrameLevel(plate:GetFrameLevel() + 50)

    if resourceFrame.SetIgnoreParentAlpha then
        resourceFrame:SetIgnoreParentAlpha(true)
    end

    -- Anchor under the health bar when it is available so the points follow
    -- nameplate size changes, and fall back to the plate itself otherwise.
    local anchor = (Nameplates.GetHealthBar and Nameplates.GetHealthBar(plate)) or plate
    resourceFrame:SetPoint("TOP", anchor, "BOTTOM", OFFSET_X / COMBO_SCALE, OFFSET_Y / COMBO_SCALE)

    setComboVisual(cp)
    if StartFollowTicker then StartFollowTicker() end
    addonFrame:Show()
end

-- =========================================================
-- Events
-- =========================================================
addonFrame:SetScript("OnEvent", function(self, event, ...)
    update()
end)

addonFrame:Hide()

StartFollowTicker = function()
    if followTickerActive then return end
    followTickerActive = true
    if Carpenter and Carpenter.StartTicker then
        Carpenter:StartTicker("NameplateComboPoints:follow", 0.05, update)
    end
end

StopFollowTicker = function()
    if not followTickerActive then return end
    followTickerActive = false
    if Carpenter and Carpenter.StopTicker then
        Carpenter:StopTicker("NameplateComboPoints:follow")
    end
end

local feature = {}

function feature:Enable()
    addonFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    addonFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    addonFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    addonFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    update()
end

function feature:Disable()
    addonFrame:UnregisterAllEvents()
    StopFollowTicker()
    addonFrame:Hide()
    if resourceFrame then
        resourceFrame:Hide()
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("nameplateComboEnabled", feature)
end
