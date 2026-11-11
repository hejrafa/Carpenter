--[[ Carpenter - Blizzard AddOn Compartment ]]
-- Register at runtime so a disabled Carpenter does not leave callback names in
-- TOC metadata for Blizzard's AddOn Compartment to call without loading us.

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

local function GetMetadata(field)
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(addonName, field)
    end
end

local function RegisterAddonCompartment()
    if registered then return true end

    local compartment = _G.AddonCompartmentFrame
    if not compartment or type(compartment.RegisterAddon) ~= "function" then
        return false
    end

    compartment:RegisterAddon({
        text = GetMetadata("Title") or addonName or "Carpenter",
        icon = GetMetadata("IconTexture"),
        notCheckable = true,
        func = OnClick,
    })
    registered = true
    return true
end

if not RegisterAddonCompartment() and type(CreateFrame) == "function" then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
        if event == "ADDON_LOADED" and loadedAddonName ~= "Blizzard_Minimap" then return end
        if RegisterAddonCompartment() then
            self:UnregisterAllEvents()
        end
    end)
end
