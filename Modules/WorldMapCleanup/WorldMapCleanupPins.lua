--[[ Carpenter - World Map Cleanup default pin adjustments ]]
if Carpenter and Carpenter.Client and not Carpenter.Client.isClassic then return end

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Cleanup = ns.Private.WorldMapCleanup or {}
ns.Private.WorldMapCleanup = Cleanup

local GROUP_MEMBER_PIN_SIZE = 12
local GROUP_MEMBER_PIN_TEXTURE = "Interface\\AddOns\\Carpenter\\Art\\Icons\\GroupMemberPin.tga"

local hiddenMapObjects = {}
local originalGroupMemberPinSizes = nil
local hookedTownCityPins = false
local hookedGroupMemberPins = false

local function IsEnabled()
    if Cleanup.IsEnabled then return Cleanup.IsEnabled() end
    return Carpenter and Carpenter:IsEnabled("worldMapCleanupEnabled")
end

local function GetWorldMapID()
    if Cleanup.GetWorldMapID then return Cleanup.GetWorldMapID() end

    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return nil end
    if mapFrame.mapID then return mapFrame.mapID end
    if mapFrame.GetMapID then return mapFrame:GetMapID() end
    return nil
end

local function StoreHiddenState(object)
    if hiddenMapObjects[object] then return end

    hiddenMapObjects[object] = {
        shown = object.IsShown and object:IsShown() or nil,
        alpha = object.GetAlpha and object:GetAlpha() or nil,
        mouseEnabled = object.IsMouseEnabled and object:IsMouseEnabled() or nil,
    }
end

local function HideMapObject(object)
    if not object then return end

    StoreHiddenState(object)
    if object.Hide then object:Hide() end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.EnableMouse then object:EnableMouse(false) end
end

function Cleanup.RestoreMapObjects()
    for object, state in pairs(hiddenMapObjects) do
        if object then
            if object.SetAlpha then object:SetAlpha(state.alpha or 1) end
            if object.EnableMouse and state.mouseEnabled ~= nil then object:EnableMouse(state.mouseEnabled) end
            if object.Show and state.shown then
                object:Show()
            elseif object.Hide and state.shown == false then
                object:Hide()
            end
        end
    end
    hiddenMapObjects = {}
end

local function IsContinentMapID(mapID)
    return mapID == 1414 or mapID == 1415 or mapID == 1945 or mapID == 947 or
        mapID == 12 or mapID == 13 or mapID == 1467
end

local function TextureCoordsMatch(texture, a, b, c, d, e, f, g, h)
    if not texture or not texture.GetTexCoord then return false end

    local ta, tb, tc, td, te, tf, tg, th = texture:GetTexCoord()
    return math.abs((ta or 0) - a) < 0.0001 and
        math.abs((tb or 0) - b) < 0.0001 and
        math.abs((tc or 0) - c) < 0.0001 and
        math.abs((td or 0) - d) < 0.0001 and
        math.abs((te or 0) - e) < 0.0001 and
        math.abs((tf or 0) - f) < 0.0001 and
        math.abs((tg or 0) - g) < 0.0001 and
        math.abs((th or 0) - h) < 0.0001
end

local function TextureIsTownOrCity(texture)
    if not texture or not texture.GetTexture then return false end

    local textureID = texture:GetTexture()
    if textureID ~= 136441 and textureID ~= "Interface\\Minimap\\POIIcons" and textureID ~= "Interface\\MINIMAP\\POIIcons" then
        return false
    end

    return TextureCoordsMatch(texture, 0.5, 0, 0.5, 0.125, 0.625, 0, 0.625, 0.125) or
        TextureCoordsMatch(texture, 0.625, 0, 0.625, 0.125, 0.75, 0, 0.75, 0.125)
end

local function HideTownCityPin(pin)
    if not IsEnabled() or not pin or pin.CPWorldMapCleanupPin then return end
    if not IsContinentMapID(GetWorldMapID()) then return end

    if pin.Texture and TextureIsTownOrCity(pin.Texture) then
        HideMapObject(pin)
    end
end

local function HookTownCityPins()
    if hookedTownCityPins or not BaseMapPoiPinMixin then return end

    local hooked = Carpenter and Carpenter.SafeHook and Carpenter:SafeHook(BaseMapPoiPinMixin, "OnAcquired", function(pin)
        HideTownCityPin(pin)
    end)
    hookedTownCityPins = hooked == true
end

local function ApplyExistingTownCityPins()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return end

    if mapFrame.EnumerateAllPins then
        for pin in mapFrame:EnumerateAllPins() do
            HideTownCityPin(pin)
        end
    elseif mapFrame.EnumeratePinsByTemplate then
        for pin in mapFrame:EnumeratePinsByTemplate("BaseMapPoiPinTemplate") do
            HideTownCityPin(pin)
        end
    end
end

function Cleanup.ApplyTownCityIcons()
    Cleanup.RestoreMapObjects()
    if not IsEnabled() or not _G.WorldMapFrame then return end

    HookTownCityPins()
    ApplyExistingTownCityPins()
end

local function CaptureGroupMemberPinSizes(pin)
    if originalGroupMemberPinSizes or not pin or not pin.dataProvider then return end
    if not pin.dataProvider.GetUnitPinSizesTable then return end

    local sizes = pin.dataProvider:GetUnitPinSizesTable()
    if not sizes then return end

    originalGroupMemberPinSizes = {
        party = sizes.party,
        raid = sizes.raid,
    }
end

local function SetGroupMemberPinTexture(pin)
    if not pin or not pin.SetPinTexture then return end

    pcall(pin.SetPinTexture, pin, "party", GROUP_MEMBER_PIN_TEXTURE)
    pcall(pin.SetPinTexture, pin, "raid", GROUP_MEMBER_PIN_TEXTURE)
end

local function HookGroupMemberPinAppearance(pin)
    if not pin or pin.CP_WorldMapCleanupGroupPinHooked then return end
    if not pin.UpdateAppearanceData then return end

    local hooked = Carpenter and Carpenter.SafeHook and Carpenter:SafeHook(pin, "UpdateAppearanceData", function(self)
        if IsEnabled() then SetGroupMemberPinTexture(self) end
    end)
    if hooked then
        pin.CP_WorldMapCleanupGroupPinHooked = true
    end
end

local function SetGroupMemberPinAppearance(pin, enabled)
    if not pin then return end

    if enabled then
        HookGroupMemberPinAppearance(pin)
        SetGroupMemberPinTexture(pin)
    end

    if pin.SetAppearanceField then
        pcall(pin.SetAppearanceField, pin, "party", "useClassColor", enabled == true)
        pcall(pin.SetAppearanceField, pin, "raid", "useClassColor", enabled == true)
    end

    if enabled and pin.SetAppearanceField then
        pcall(pin.SetAppearanceField, pin, "party", "sublevel", 0)
        pcall(pin.SetAppearanceField, pin, "raid", "sublevel", 0)
    end

    if pin.dataProvider and pin.dataProvider.GetUnitPinSizesTable then
        local sizes = pin.dataProvider:GetUnitPinSizesTable()
        if sizes then
            if enabled then
                CaptureGroupMemberPinSizes(pin)
                sizes.party = GROUP_MEMBER_PIN_SIZE
                sizes.raid = GROUP_MEMBER_PIN_SIZE
            elseif originalGroupMemberPinSizes then
                sizes.party = originalGroupMemberPinSizes.party
                sizes.raid = originalGroupMemberPinSizes.raid
            end
        end
    end

    if pin.UpdateShownUnits then pcall(pin.UpdateShownUnits, pin) end
    if pin.SynchronizePinSizes then pcall(pin.SynchronizePinSizes, pin) end
end

local function ForEachGroupMemberPin(callback)
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not callback then return end

    if mapFrame.EnumeratePinsByTemplate then
        for pin in mapFrame:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
            callback(pin)
        end
    elseif mapFrame.EnumerateAllPins then
        for pin in mapFrame:EnumerateAllPins() do
            if pin and pin.SetAppearanceField and pin.dataProvider and pin.SynchronizePinSizes then
                callback(pin)
            end
        end
    end
end

function Cleanup.ApplyGroupMemberPins()
    if not IsEnabled() then return end

    ForEachGroupMemberPin(function(pin)
        SetGroupMemberPinAppearance(pin, true)
    end)
end

function Cleanup.RestoreGroupMemberPins()
    ForEachGroupMemberPin(function(pin)
        SetGroupMemberPinAppearance(pin, false)
    end)
    originalGroupMemberPinSizes = nil
end

function Cleanup.HookGroupMemberPins()
    if hookedGroupMemberPins or not _G.GroupMembersPinMixin then return end
    if not _G.GroupMembersPinMixin.OnAcquired then return end

    local hooked = Carpenter and Carpenter.SafeHook and Carpenter:SafeHook(_G.GroupMembersPinMixin, "OnAcquired", function()
        Cleanup.ApplyGroupMemberPins()
    end)
    hookedGroupMemberPins = hooked == true
end

function Cleanup.HookTownCityPins()
    HookTownCityPins()
end
