--[[ Carpenter - World Map Cleanup Silithus highlight fix ]]
if Carpenter and Carpenter.Client and not Carpenter.Client.isClassic then return end

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Cleanup = ns.Private.WorldMapCleanup or {}
ns.Private.WorldMapCleanup = Cleanup

local SILITHUS_MAP_ID = 1451
local SILITHUS_HIGHLIGHT_TEXTURE = "Interface\\WorldMap\\Silithus\\SilithusHighlight.blp"
local SILITHUS_HIGHLIGHT_ALPHA = 0.9
local SILITHUS_FALLBACK_HIGHLIGHT_RECT = {
    left = 0.39,
    right = 0.47,
    top = 0.74,
    bottom = 0.895,
}
local KALIMDOR_MAP_IDS = {
    [12] = true,
    [1414] = true,
}

local hookedSilithusHighlightFix = false

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

local function IsKalimdorMapID(mapID)
    return KALIMDOR_MAP_IDS[mapID] == true
end

local function ClampValue(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetMapForHighlightPin(pin)
    if pin and pin.GetMap then
        local ok, map = pcall(pin.GetMap, pin)
        if ok and map then return map end
    end

    return _G.WorldMapFrame
end

local function GetMapIDForHighlightPin(pin)
    local map = GetMapForHighlightPin(pin)
    if map and map.GetMapID then
        local ok, mapID = pcall(map.GetMapID, map)
        if ok and mapID then return mapID end
    end

    return GetWorldMapID()
end

local function IsSilithusHoverOnKalimdor(pin)
    if not C_Map or not C_Map.GetMapInfoAtPosition then return false end

    local map = GetMapForHighlightPin(pin)
    local mapID = GetMapIDForHighlightPin(pin)
    if not IsKalimdorMapID(mapID) then return false end

    if map and map.IsCanvasMouseFocus then
        local ok, isFocused = pcall(map.IsCanvasMouseFocus, map)
        if ok and not isFocused then return false end
    end

    if not map or not map.GetNormalizedCursorPosition then return false end

    local ok, cursorX, cursorY = pcall(map.GetNormalizedCursorPosition, map)
    if not ok or not cursorX or not cursorY then return false end

    local positionMapInfo
    ok, positionMapInfo = pcall(C_Map.GetMapInfoAtPosition, mapID, cursorX, cursorY)
    return ok and positionMapInfo and positionMapInfo.mapID == SILITHUS_MAP_ID
end

local function GetSilithusHighlightRect(mapID)
    if C_Map and C_Map.GetMapRectOnMap then
        local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, SILITHUS_MAP_ID, mapID)
        if ok and left and right and top and bottom and right > left and bottom > top then
            return ClampValue(left, 0, 1), ClampValue(right, 0, 1), ClampValue(top, 0, 1), ClampValue(bottom, 0, 1)
        end
    end

    return SILITHUS_FALLBACK_HIGHLIGHT_RECT.left,
        SILITHUS_FALLBACK_HIGHLIGHT_RECT.right,
        SILITHUS_FALLBACK_HIGHLIGHT_RECT.top,
        SILITHUS_FALLBACK_HIGHLIGHT_RECT.bottom
end

local function SetSilithusHighlightSize(texture, width, height)
    if texture.SetSize then
        texture:SetSize(width, height)
    else
        texture:SetWidth(width)
        texture:SetHeight(height)
    end
end

local function EnsureSilithusHighlight(pin)
    if not pin or not pin.CreateTexture then return nil end

    if not pin.CP_SilithusHighlightTexture then
        local texture = pin:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(SILITHUS_HIGHLIGHT_TEXTURE)
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetAlpha(SILITHUS_HIGHLIGHT_ALPHA)
        if texture.SetBlendMode then texture:SetBlendMode("ADD") end
        if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1) end
        texture:Hide()
        pin.CP_SilithusHighlightTexture = texture
    end

    return pin.CP_SilithusHighlightTexture
end

local function HideSilithusHighlight(pin)
    local texture = pin and pin.CP_SilithusHighlightTexture
    if texture and texture.Hide then texture:Hide() end
end

local function ShowSilithusHighlight(pin)
    local texture = EnsureSilithusHighlight(pin)
    if not texture or not pin.GetWidth or not pin.GetHeight then return false end

    local pinWidth = pin:GetWidth() or 0
    local pinHeight = pin:GetHeight() or 0
    if pinWidth <= 0 or pinHeight <= 0 then return false end

    local left, right, top, bottom = GetSilithusHighlightRect(GetMapIDForHighlightPin(pin))
    local width = (right - left) * pinWidth
    local height = (bottom - top) * pinHeight
    if width <= 0 or height <= 0 then return false end

    texture:ClearAllPoints()
    SetSilithusHighlightSize(texture, width, height)
    texture:SetPoint("TOPLEFT", pin, "TOPLEFT", left * pinWidth, -top * pinHeight)
    texture:Show()
    return true
end

local function ApplySilithusHighlightReplacement(pin)
    if not pin then return end

    if not IsEnabled() or not IsSilithusHoverOnKalimdor(pin) then
        HideSilithusHighlight(pin)
        return
    end

    if ShowSilithusHighlight(pin) and pin.HighlightTexture and pin.HighlightTexture.Hide then
        pin.HighlightTexture:Hide()
    end
end

local function HookSilithusHighlightFix()
    if hookedSilithusHighlightFix or not _G.MapHighlightPinMixin or not _G.MapHighlightPinMixin.Refresh then return end

    local hooked = Carpenter and Carpenter.SafeHook and Carpenter:SafeHook(_G.MapHighlightPinMixin, "Refresh", function(pin)
        ApplySilithusHighlightReplacement(pin)
    end)
    hookedSilithusHighlightFix = hooked == true
end

local function ForEachMapHighlightPin(callback)
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not callback then return end

    if mapFrame.EnumeratePinsByTemplate then
        for pin in mapFrame:EnumeratePinsByTemplate("MapHighlightPinTemplate") do
            callback(pin)
        end
    elseif mapFrame.EnumerateAllPins then
        for pin in mapFrame:EnumerateAllPins() do
            if pin and pin.HighlightTexture and pin.Refresh then
                callback(pin)
            end
        end
    end
end

function Cleanup.ApplySilithusHighlightFix()
    HookSilithusHighlightFix()
    ForEachMapHighlightPin(ApplySilithusHighlightReplacement)
end

function Cleanup.RefreshMapHighlightPins()
    ForEachMapHighlightPin(function(pin)
        if pin and pin.Refresh then
            pcall(pin.Refresh, pin)
        end
    end)
end
