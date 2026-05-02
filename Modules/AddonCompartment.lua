--[[ Carpenter - Blizzard AddOn Compartment ]]
-- Registers Carpenter in Retail's minimap AddOn Compartment dropdown.

local addonName, ns = ...
ns = ns or {}

local registered = false

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
    GameTooltip:SetText((Carpenter and Carpenter.L and Carpenter.L.ADDON_NAME) or addonName or "Carpenter")
    GameTooltip:AddLine("Open settings", 1, 1, 1)
    GameTooltip:Show()
end

local function OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function RegisterAddonCompartment()
    if registered or not AddonCompartmentFrame or not AddonCompartmentFrame.RegisterAddon then return end

    local identifier = addonName or "Carpenter"
    local displayName = (Carpenter and Carpenter.L and Carpenter.L.ADDON_NAME) or identifier

    if AddonCompartmentFrame.registeredAddons then
        for _, addonData in ipairs(AddonCompartmentFrame.registeredAddons) do
            if addonData.identifier == identifier or addonData.text == displayName then
                registered = true
                return
            end
        end
    end

    AddonCompartmentFrame:RegisterAddon({
        identifier = identifier,
        text = displayName,
        icon = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(identifier, "IconTexture")
            or "Interface\\AddOns\\Carpenter\\Art\\Icons\\Carpenter_Logo",
        notCheckable = true,
        registerForAnyClick = true,
        func = OnClick,
        funcOnEnter = OnEnter,
        funcOnLeave = OnLeave,
    })

    registered = true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self)
    RegisterAddonCompartment()
    if registered then
        self:UnregisterAllEvents()
    end
end)
