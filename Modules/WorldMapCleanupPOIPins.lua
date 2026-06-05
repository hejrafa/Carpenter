--[[ Carpenter - World Map Cleanup POI pin provider ]]
local _, ns = ...
ns.Private = ns.Private or {}

local POIPins = ns.Private.WorldMapCleanupPOIPins or {}
ns.Private.WorldMapCleanupPOIPins = POIPins

local Data = ns.Private.WorldMapCleanupData or {}
local CUSTOM_PIN_TEMPLATE = "CPWorldMapCleanupPinTemplate"

local context = {}
local customPOIProvider = nil

function POIPins.Configure(newContext)
    context = newContext or {}
end

local function IsClassicClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic
end

local function ShouldShowMapPOIIcons()
    if context.ShouldShowMapPOIIcons then return context.ShouldShowMapPOIIcons() end
    return Carpenter and Carpenter:IsEnabled("worldMapCleanupEnabled") and CarpenterDB and CarpenterDB.worldMapPOIIconsEnabled == true
end

local function GetWorldMapID()
    if context.GetWorldMapID then return context.GetWorldMapID() end

    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return nil end

    if mapFrame.mapID then return mapFrame.mapID end

    if mapFrame.GetMapID then
        local mapID = mapFrame:GetMapID()
        if mapID then return mapID end
    end

    return nil
end

local function GetMapCanvasID(map)
    if not map then return nil end

    if map.GetMapID then
        local mapID = map:GetMapID()
        if mapID then return mapID end
    end

    return map.mapID
end

local function GetPOIMapID(map)
    return GetWorldMapID() or GetMapCanvasID(map)
end

local function IsDungeonPOI(kind)
    if Data.IsDungeonKind then return Data.IsDungeonKind(kind) end
    return kind == "Dungeon" or kind == "Raid" or kind == "Dunraid"
end

local function IsTravelPOI(kind)
    if Data.IsTravelKind then return Data.IsTravelKind(kind) end
    return kind == "FlightA" or kind == "FlightH" or kind == "FlightN" or
        kind == "TravelA" or kind == "TravelH" or kind == "TravelN"
end

local function ShouldShowPOI(kind)
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if Data.ShouldShowKind then return Data.ShouldShowKind(kind, faction) end

    if IsDungeonPOI(kind) then return true end
    if kind == "FlightN" or kind == "TravelN" then return true end

    if faction == "Alliance" then
        return kind == "FlightA" or kind == "TravelA"
    elseif faction == "Horde" then
        return kind == "FlightH" or kind == "TravelH"
    end

    return false
end

local function IsPOIAvailableForClient(pinInfo)
    if Data.IsPOIAvailableForClient then
        return Data.IsPOIAvailableForClient(pinInfo, Carpenter and Carpenter.Client and Carpenter.Client.isTBC)
    end

    if pinInfo[10] == "tbc" then
        return Carpenter and Carpenter.Client and Carpenter.Client.isTBC
    end

    return true
end

local function BuildPOIName(pinInfo)
    if Data.BuildPOIName then return Data.BuildPOIName(pinInfo) end

    local name = pinInfo[4] or ""
    local minLevel = pinInfo[7]
    local maxLevel = pinInfo[8]

    if minLevel and maxLevel then
        if minLevel == maxLevel then
            name = name .. " (" .. maxLevel .. ")"
        else
            name = name .. " (" .. minLevel .. "-" .. maxLevel .. ")"
        end
    end

    return name
end

local function BuildPOIInfo(pinInfo)
    if Data.BuildPOIInfo then return Data.BuildPOIInfo(pinInfo) end

    local kind = pinInfo[1]
    local atlas = Data.Atlas or {}
    return {
        position = CreateVector2D(pinInfo[2] / 100, pinInfo[3] / 100),
        name = BuildPOIName(pinInfo),
        description = pinInfo[5],
        atlasName = pinInfo[6] or atlas[kind],
        CPKind = kind,
        CPTargetMapID = pinInfo[9],
    }
end

local function GetPOIIconSize(kind)
    if Data.GetIconSize then return Data.GetIconSize(kind) end

    local sizes = Data.IconSizes or {}
    return sizes[kind] or 20
end

local function ApplyPOIIconVisuals(pin, info)
    local size = GetPOIIconSize(info.CPKind)
    local textures = { pin.Texture, pin.HighlightTexture }

    if pin.SetSize then pin:SetSize(size, size) end

    for _, texture in ipairs(textures) do
        if texture then
            if texture.SetAtlas and info.atlasName then
                pcall(texture.SetAtlas, texture, info.atlasName, false)
            end
            if texture.SetScale then texture:SetScale(1) end
            if texture.SetRotation then texture:SetRotation(0) end
            if texture.SetSize then texture:SetSize(size, size) end
        end
    end
end

local function EnsurePinMixin()
    if _G.CPWorldMapCleanupPinMixin then return true end
    if not BaseMapPoiPinMixin or not BaseMapPoiPinMixin.CreateSubPin then return false end

    _G.CPWorldMapCleanupPinMixin = BaseMapPoiPinMixin:CreateSubPin("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")

    function _G.CPWorldMapCleanupPinMixin:OnAcquired(info)
        self.CPWorldMapCleanupPin = true
        BaseMapPoiPinMixin.OnAcquired(self, info)
        self.CPKind = info.CPKind
        self.CPTargetMapID = info.CPTargetMapID

        ApplyPOIIconVisuals(self, info)
    end

    function _G.CPWorldMapCleanupPinMixin:OnMouseUp(button)
        if button == "LeftButton" and self.CPTargetMapID and _G.WorldMapFrame and _G.WorldMapFrame.SetMapID then
            _G.WorldMapFrame:SetMapID(self.CPTargetMapID)
        elseif button == "RightButton" and _G.WorldMapFrame and _G.WorldMapFrame.NavigateToParentMap then
            _G.WorldMapFrame:NavigateToParentMap()
        end
    end

    return true
end

local function RemovePOIPinsFromMap(map)
    if map and map.RemoveAllPinsByTemplate then
        pcall(map.RemoveAllPinsByTemplate, map, CUSTOM_PIN_TEMPLATE)
    end
end

function POIPins.Remove()
    local mapFrame = _G.WorldMapFrame
    RemovePOIPinsFromMap(mapFrame)

    if customPOIProvider and customPOIProvider.GetMap then
        local providerMap = customPOIProvider:GetMap()
        if providerMap ~= mapFrame then
            RemovePOIPinsFromMap(providerMap)
        end
    end
end

function POIPins.EnsureProvider()
    if customPOIProvider then return true end

    local mapFrame = _G.WorldMapFrame
    if not IsClassicClient() or not mapFrame or not mapFrame.AddDataProvider then return false end
    if not CreateFromMixins or not MapCanvasDataProviderMixin or not CreateVector2D then return false end
    if not EnsurePinMixin() then return false end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RefreshAllData()
        local map = self.GetMap and self:GetMap()
        RemovePOIPinsFromMap(map)
        if map ~= _G.WorldMapFrame then RemovePOIPinsFromMap(_G.WorldMapFrame) end

        if not ShouldShowMapPOIIcons() or not map then return end

        local pins = Data.POIs and Data.POIs[GetPOIMapID(map)]
        if not pins then return end

        local atlas = Data.Atlas or {}
        for _, pinInfo in ipairs(pins) do
            if IsPOIAvailableForClient(pinInfo) and ShouldShowPOI(pinInfo[1]) and atlas[pinInfo[1]] then
                pcall(map.AcquirePin, map, CUSTOM_PIN_TEMPLATE, BuildPOIInfo(pinInfo))
            end
        end
    end

    mapFrame:AddDataProvider(provider)
    customPOIProvider = provider
    return true
end

function POIPins.Apply()
    if not ShouldShowMapPOIIcons() then
        POIPins.Remove()
        return
    end

    if POIPins.EnsureProvider() and customPOIProvider and customPOIProvider.RefreshAllData then
        customPOIProvider:RefreshAllData()
    end
end
