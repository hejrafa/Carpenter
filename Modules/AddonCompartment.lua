--[[ Carpenter - Blizzard AddOn Compartment ]]
-- Callback functions used by Retail's TOC-driven AddOn Compartment registration.

local addonName, ns = ...
ns = ns or {}

local function OpenConfig()
    if type(Carpenter_OpenConfig) == "function" then
        Carpenter_OpenConfig()
    end
end

local function OnClick(_, menuInputData)
    local button = type(menuInputData) == "table" and menuInputData.buttonName or menuInputData
    if not button or button == "LeftButton" then
        OpenConfig()
    end
end

local function OnEnter(owner, menuButton)
    local tooltipOwner = owner
    if tooltipOwner and not (tooltipOwner.GetObjectType or tooltipOwner.IsObjectType) then
        tooltipOwner = menuButton
    end
    if tooltipOwner and not (tooltipOwner.GetObjectType or tooltipOwner.IsObjectType) then
        tooltipOwner = nil
    end
    if not GameTooltip or not tooltipOwner then return end

    GameTooltip:SetOwner(tooltipOwner, "ANCHOR_RIGHT")
    local L = (Carpenter and Carpenter.L) or {}
    GameTooltip:SetText(L.ADDON_NAME or addonName or "Carpenter")
    GameTooltip:AddLine(L.OPEN_SETTINGS or "Open settings", 1, 1, 1)
    GameTooltip:Show()
end

local function OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

_G.Carpenter_AddonCompartment_OnClick = OnClick
_G.Carpenter_AddonCompartment_OnEnter = OnEnter
_G.Carpenter_AddonCompartment_OnLeave = OnLeave
