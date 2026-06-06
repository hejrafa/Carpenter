--[[ Carpenter - World Map Cleanup ]]
-- Classic Era/TBC map tweaks: move the default map, reduce settlement markers,
-- and optionally add practical POIs for dungeons, raids, and same-faction travel.

if Carpenter and Carpenter.Client and not Carpenter.Client.isClassic then return end

local _, ns = ...
local POIPins = ns and ns.Private and ns.Private.WorldMapCleanupPOIPins or {}

local LEATRIX_SMALL_MAP_X = 16
local LEATRIX_SMALL_MAP_Y = -104
local FULLSCREEN_MAP_SCALE = 0.85
local MOVING_MAP_ALPHA = 0.5
local MAP_FADE_DURATION = 0.25
local GROUP_MEMBER_PIN_SIZE = 12
local GROUP_MEMBER_PIN_TEXTURE = "Interface\\AddOns\\Carpenter\\Art\\Icons\\GroupMemberPin.tga"
local SILITHUS_MAP_ID = 1451
local KALIMDOR_MAP_IDS = {
    [12] = true,
    [1414] = true,
}

local frame = CreateFrame("Frame")
local originalFullscreenGeometry = nil
local originalBlackoutAlpha = nil
local originalMapAlpha = nil
local originalMapScale = nil
local originalScreenAnchorPoints = nil
local hiddenMapObjects = {}
local hookedWorldMap = false
local hookedTownCityPins = false
local hookedCursorScale = false
local originalScrollContainerGetCursorPosition = nil
local originalScrollContainerGetNormalizedCursorPosition = nil
local originalWorldMapGetNormalizedCursorPosition = nil
local scheduleNonce = 0
local centeredMapCanvasKey = nil
local originalGroupMemberPinSizes = nil
local hookedGroupMemberPins = false
local hookedSilithusHighlightFix = false

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("worldMapCleanupEnabled")
end

local function ShouldShowMapPOIIcons()
    return IsEnabled() and CarpenterDB and CarpenterDB.worldMapPOIIconsEnabled == true
end

local function SafeRegisterEvent(event)
    if not event then return end
    pcall(frame.RegisterEvent, frame, event)
end

local function CaptureFramePoints(frameToCapture)
    if not frameToCapture or not frameToCapture.GetNumPoints then return nil end

    local points = {}
    local numPoints = frameToCapture:GetNumPoints() or 0
    for index = 1, numPoints do
        local point, relativeTo, relativePoint, xOfs, yOfs = frameToCapture:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
        }
    end

    return points
end

local function RestoreFramePoints(frameToRestore, points)
    if not frameToRestore or not points or not frameToRestore.ClearAllPoints or not frameToRestore.SetPoint then return end

    frameToRestore:ClearAllPoints()
    for _, point in ipairs(points) do
        if point.relativeTo then
            frameToRestore:SetPoint(point.point, point.relativeTo, point.relativePoint, point.xOfs, point.yOfs)
        else
            frameToRestore:SetPoint(point.point, point.xOfs, point.yOfs)
        end
    end
end

local function CaptureMapScale(mapFrame)
    if originalMapScale ~= nil or not mapFrame or not mapFrame.GetScale then return end
    originalMapScale = mapFrame:GetScale() or 1
end

local function CaptureSmallMapAnchor()
    if originalScreenAnchorPoints or not _G.WorldMapScreenAnchor then return end
    originalScreenAnchorPoints = CaptureFramePoints(_G.WorldMapScreenAnchor)
end

local function IsMapFullscreen(mapFrame)
    if not mapFrame then return false end
    if mapFrame.IsMaximized then
        local ok, maximized = pcall(mapFrame.IsMaximized, mapFrame)
        if ok then return maximized == true end
    end
    return mapFrame.isMaximized == true
end

local function CaptureFullscreenGeometry(mapFrame)
    if originalFullscreenGeometry or not IsMapFullscreen(mapFrame) then return end

    originalFullscreenGeometry = {
        points = CaptureFramePoints(mapFrame),
        width = mapFrame.GetWidth and mapFrame:GetWidth() or nil,
        height = mapFrame.GetHeight and mapFrame:GetHeight() or nil,
    }
end

local function RestoreFullscreenSize(mapFrame)
    if not mapFrame or not mapFrame.SetSize or not originalFullscreenGeometry then return end
    if not originalFullscreenGeometry.width or not originalFullscreenGeometry.height then return end
    if mapFrame.GetWidth and mapFrame.GetHeight then
        local currentWidth = mapFrame:GetWidth() or 0
        local currentHeight = mapFrame:GetHeight() or 0
        if math.abs(currentWidth - originalFullscreenGeometry.width) < 1 and
            math.abs(currentHeight - originalFullscreenGeometry.height) < 1 then
            return
        end
    end

    mapFrame:SetSize(originalFullscreenGeometry.width, originalFullscreenGeometry.height)
    if mapFrame.OnFrameSizeChanged then mapFrame:OnFrameSizeChanged() end
end

local function GetScaledMapCursorPosition(container, mapFrame)
    local x, y = MapCanvasScrollControllerMixin.GetCursorPosition(container)
    if not x or not y then return x, y end

    local scale = mapFrame and mapFrame.GetScale and mapFrame:GetScale() or 1
    if scale == 0 then return x, y end

    return x / scale, y / scale
end

local function HookScaledMapCursor()
    if hookedCursorScale then return end

    local mapFrame = _G.WorldMapFrame
    local scrollContainer = mapFrame and mapFrame.ScrollContainer
    if not scrollContainer or not MapCanvasScrollControllerMixin or not MapCanvasScrollControllerMixin.GetCursorPosition then return end

    originalScrollContainerGetCursorPosition = scrollContainer.GetCursorPosition
    scrollContainer.GetCursorPosition = function(container)
        return GetScaledMapCursorPosition(container, mapFrame)
    end

    originalScrollContainerGetNormalizedCursorPosition = scrollContainer.GetNormalizedCursorPosition
    if originalScrollContainerGetNormalizedCursorPosition then
        scrollContainer.GetNormalizedCursorPosition = function(container)
            if MapCanvasScrollControllerMixin.GetNormalizedCursorPosition then
                return MapCanvasScrollControllerMixin.GetNormalizedCursorPosition(container)
            end

            local x, y = container:GetCursorPosition()
            if not x or not y then return x, y end

            local width = container.GetWidth and container:GetWidth() or 0
            local height = container.GetHeight and container:GetHeight() or 0
            if width == 0 or height == 0 then return nil, nil end

            return x / width, y / height
        end
    end

    originalWorldMapGetNormalizedCursorPosition = mapFrame.GetNormalizedCursorPosition
    if originalWorldMapGetNormalizedCursorPosition then
        mapFrame.GetNormalizedCursorPosition = function(frame)
            local container = frame.ScrollContainer
            if container and container.GetNormalizedCursorPosition then
                return container:GetNormalizedCursorPosition()
            end
            return originalWorldMapGetNormalizedCursorPosition(frame)
        end
    end

    hookedCursorScale = true
end

local function RestoreScaledMapCursor()
    local mapFrame = _G.WorldMapFrame
    local scrollContainer = mapFrame and mapFrame.ScrollContainer
    if scrollContainer and originalScrollContainerGetCursorPosition then
        scrollContainer.GetCursorPosition = originalScrollContainerGetCursorPosition
    end
    if scrollContainer and originalScrollContainerGetNormalizedCursorPosition then
        scrollContainer.GetNormalizedCursorPosition = originalScrollContainerGetNormalizedCursorPosition
    end
    if mapFrame and originalWorldMapGetNormalizedCursorPosition then
        mapFrame.GetNormalizedCursorPosition = originalWorldMapGetNormalizedCursorPosition
    end

    originalScrollContainerGetCursorPosition = nil
    originalScrollContainerGetNormalizedCursorPosition = nil
    originalWorldMapGetNormalizedCursorPosition = nil
    hookedCursorScale = false
end

local function HideMapBlackout()
    local mapFrame = _G.WorldMapFrame
    local blackout = mapFrame and mapFrame.BlackoutFrame
    if not blackout then return end

    if originalBlackoutAlpha == nil and blackout.GetAlpha then
        originalBlackoutAlpha = blackout:GetAlpha()
    end

    if blackout.SetAlpha then blackout:SetAlpha(0) end
    if blackout.Hide then blackout:Hide() end
end

local function RestoreMapBlackout()
    local mapFrame = _G.WorldMapFrame
    local blackout = mapFrame and mapFrame.BlackoutFrame
    if not blackout then return end

    if blackout.SetAlpha then blackout:SetAlpha(originalBlackoutAlpha or 1) end
    if IsMapFullscreen(mapFrame) and blackout.Show then blackout:Show() end
end

local function IsMouseOverMap(mapFrame)
    if not mapFrame then return false end
    if mapFrame.IsMouseOver then
        local ok, isMouseOver = pcall(mapFrame.IsMouseOver, mapFrame)
        if ok then return isMouseOver == true end
    end
    if MouseIsOver then
        local ok, isMouseOver = pcall(MouseIsOver, mapFrame)
        if ok then return isMouseOver == true end
    end
    return false
end

local function CaptureMapAlpha(mapFrame)
    if originalMapAlpha ~= nil or not mapFrame or not mapFrame.GetAlpha then return end
    originalMapAlpha = mapFrame:GetAlpha() or 1
end

local function GetRestingMapAlpha()
    return originalMapAlpha or 1
end

local function ApplyMovingMapFade(elapsed, immediate)
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not mapFrame.SetAlpha or not mapFrame.GetAlpha then return end

    CaptureMapAlpha(mapFrame)

    local desiredAlpha = GetRestingMapAlpha()
    if IsEnabled() then
        local moving = IsPlayerMoving and IsPlayerMoving()
        if moving and not IsMouseOverMap(mapFrame) then
            desiredAlpha = MOVING_MAP_ALPHA
        end
    end

    if immediate then
        mapFrame:SetAlpha(desiredAlpha)
        return
    end

    local currentAlpha = mapFrame:GetAlpha() or desiredAlpha
    local alphaDiff = desiredAlpha - currentAlpha
    if math.abs(alphaDiff) < 0.01 then
        mapFrame:SetAlpha(desiredAlpha)
        return
    end

    local progress = math.min(1, (elapsed or 0) / MAP_FADE_DURATION)
    if progress <= 0 then return end

    mapFrame:SetAlpha(currentAlpha + (alphaDiff * progress))
end

local function ApplyFullscreenMapLayout(mapFrame)
    if not IsMapFullscreen(mapFrame) then return false end

    CaptureFullscreenGeometry(mapFrame)
    HideMapBlackout()
    HookScaledMapCursor()

    mapFrame.CP_WorldMapCleanupApplying = true
    RestoreFullscreenSize(mapFrame)
    if mapFrame.ClearAllPoints and mapFrame.SetPoint and UIParent then
        mapFrame:ClearAllPoints()
        mapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if mapFrame.SetScale and (not mapFrame.GetScale or math.abs((mapFrame:GetScale() or 1) - FULLSCREEN_MAP_SCALE) > 0.001) then
        mapFrame:SetScale(FULLSCREEN_MAP_SCALE)
    end
    mapFrame.CP_WorldMapCleanupApplying = false
    return true
end

local function RestoreMapScale(mapFrame)
    if mapFrame and mapFrame.SetScale and originalMapScale then
        mapFrame:SetScale(originalMapScale)
    end
end

local function ApplySmallMapAnchor()
    local anchor = _G.WorldMapScreenAnchor
    if not anchor or not anchor.ClearAllPoints or not anchor.SetPoint then return false end

    CaptureSmallMapAnchor()
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LEATRIX_SMALL_MAP_X, LEATRIX_SMALL_MAP_Y)
    return true
end

local function ApplyMapPosition()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not mapFrame.ClearAllPoints or not mapFrame.SetPoint then return end

    CaptureMapAlpha(mapFrame)
    CaptureMapScale(mapFrame)

    if IsMapFullscreen(mapFrame) then
        CaptureFullscreenGeometry(mapFrame)
    else
        CaptureSmallMapAnchor()
    end

    if not IsEnabled() then return end

    if ApplyFullscreenMapLayout(mapFrame) then return end

    RestoreMapScale(mapFrame)
    ApplySmallMapAnchor()
end

local function RestoreMapPosition()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not mapFrame.ClearAllPoints or not mapFrame.SetPoint then return end
    if not originalScreenAnchorPoints and not originalFullscreenGeometry then
        RestoreMapBlackout()
        return
    end

    mapFrame.CP_WorldMapCleanupApplying = true

    if IsMapFullscreen(mapFrame) and originalFullscreenGeometry then
        RestoreFullscreenSize(mapFrame)
        RestoreFramePoints(mapFrame, originalFullscreenGeometry.points)
    elseif originalScreenAnchorPoints then
        RestoreFramePoints(_G.WorldMapScreenAnchor, originalScreenAnchorPoints)
    end

    RestoreMapScale(mapFrame)
    mapFrame.CP_WorldMapCleanupApplying = false
    RestoreMapBlackout()
    ApplyMovingMapFade(0, true)
end

local function GetWorldMapID()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return nil end

    if mapFrame.mapID then return mapFrame.mapID end

    if mapFrame.GetMapID then
        local mapID = mapFrame:GetMapID()
        if mapID then return mapID end
    end

    return nil
end

local function IsKalimdorMapID(mapID)
    return KALIMDOR_MAP_IDS[mapID] == true
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

local function HideBrokenSilithusHighlight(pin)
    if not IsEnabled() or not IsSilithusHoverOnKalimdor(pin) then return end

    local highlightTexture = pin and pin.HighlightTexture
    if highlightTexture and highlightTexture.Hide then
        highlightTexture:Hide()
    end
end

local function HookSilithusHighlightFix()
    if hookedSilithusHighlightFix or not hooksecurefunc then return end
    if not _G.MapHighlightPinMixin or not _G.MapHighlightPinMixin.Refresh then return end

    hooksecurefunc(_G.MapHighlightPinMixin, "Refresh", function(pin)
        HideBrokenSilithusHighlight(pin)
    end)
    hookedSilithusHighlightFix = true
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

local function ApplySilithusHighlightFix()
    HookSilithusHighlightFix()
    if not IsEnabled() or not IsKalimdorMapID(GetWorldMapID()) then return end

    ForEachMapHighlightPin(HideBrokenSilithusHighlight)
end

local function RefreshMapHighlightPins()
    ForEachMapHighlightPin(function(pin)
        if pin and pin.Refresh then
            pcall(pin.Refresh, pin)
        end
    end)
end

if POIPins.Configure then
    POIPins.Configure({
        ShouldShowMapPOIIcons = ShouldShowMapPOIIcons,
        GetWorldMapID = GetWorldMapID,
    })
end

local function EnsurePOIProvider()
    if POIPins.EnsureProvider then return POIPins.EnsureProvider() end
    return false
end

local function RemovePOIPins()
    if POIPins.Remove then POIPins.Remove() end
end

local function ApplyPOIPins()
    if POIPins.Apply then POIPins.Apply() end
end

local function GetMapCanvasCenterKey(mapFrame, scrollContainer, mapID)
    if not mapID or not scrollContainer then return nil end

    local width = scrollContainer.GetWidth and scrollContainer:GetWidth() or 0
    local height = scrollContainer.GetHeight and scrollContainer:GetHeight() or 0
    if width <= 0 or height <= 0 then return nil end

    local mode = IsMapFullscreen(mapFrame) and "fullscreen" or "windowed"
    return tostring(mapID) .. ":" .. mode .. ":" .. math.floor(width + 0.5) .. "x" .. math.floor(height + 0.5)
end

local function GetMapCanvasBaseScale(scrollContainer)
    if scrollContainer.zoomLevels and scrollContainer.zoomLevels[1] and scrollContainer.zoomLevels[1].scale then
        return scrollContainer.zoomLevels[1].scale
    end

    if scrollContainer.GetScaleForMinZoom then
        local ok, scale = pcall(scrollContainer.GetScaleForMinZoom, scrollContainer)
        if ok then return scale end
    end

    return nil
end

local function CenterMapCanvasForCurrentMap()
    local mapFrame = _G.WorldMapFrame
    local scrollContainer = mapFrame and mapFrame.ScrollContainer
    if not IsEnabled() or not mapFrame or not scrollContainer then return end

    local mapID = GetWorldMapID()
    local centerKey = GetMapCanvasCenterKey(mapFrame, scrollContainer, mapID)
    if not centerKey or centeredMapCanvasKey == centerKey then return end

    local baseScale = GetMapCanvasBaseScale(scrollContainer)
    if baseScale and scrollContainer.InstantPanAndZoom then
        local ok = pcall(scrollContainer.InstantPanAndZoom, scrollContainer, baseScale, 0.5, 0.5, true)
        if not ok then return end
    elseif scrollContainer.SetPanTarget then
        pcall(scrollContainer.SetPanTarget, scrollContainer, 0.5, 0.5)
    else
        return
    end

    centeredMapCanvasKey = centerKey
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

local function RestoreMapObjects()
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
    if hookedTownCityPins or not hooksecurefunc or not BaseMapPoiPinMixin then return end

    hooksecurefunc(BaseMapPoiPinMixin, "OnAcquired", function(pin)
        HideTownCityPin(pin)
    end)
    hookedTownCityPins = true
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

local function ApplyTownCityIcons()
    RestoreMapObjects()
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
    if not pin or pin.CP_WorldMapCleanupGroupPinHooked or not hooksecurefunc then return end
    if not pin.UpdateAppearanceData then return end

    hooksecurefunc(pin, "UpdateAppearanceData", function(self)
        if IsEnabled() then SetGroupMemberPinTexture(self) end
    end)
    pin.CP_WorldMapCleanupGroupPinHooked = true
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

local function ApplyGroupMemberPins()
    if not IsEnabled() then return end

    ForEachGroupMemberPin(function(pin)
        SetGroupMemberPinAppearance(pin, true)
    end)
end

local function RestoreGroupMemberPins()
    ForEachGroupMemberPin(function(pin)
        SetGroupMemberPinAppearance(pin, false)
    end)
    originalGroupMemberPinSizes = nil
end

local function HookGroupMemberPins()
    if hookedGroupMemberPins or not hooksecurefunc or not _G.GroupMembersPinMixin then return end
    if not _G.GroupMembersPinMixin.OnAcquired then return end

    hooksecurefunc(_G.GroupMembersPinMixin, "OnAcquired", function()
        ApplyGroupMemberPins()
    end)
    hookedGroupMemberPins = true
end

local function ApplyWorldMapCleanup()
    ApplyMapPosition()
    CenterMapCanvasForCurrentMap()
    ApplyTownCityIcons()
    ApplySilithusHighlightFix()
    HookGroupMemberPins()
    ApplyGroupMemberPins()
    ApplyPOIPins()
    ApplyMovingMapFade(0, false)
end

local function ApplyWorldMapCleanupImmediately()
    if IsEnabled() then ApplyWorldMapCleanup() end
end

frame:SetScript("OnUpdate", function(_, elapsed)
    local mapFrame = _G.WorldMapFrame
    if mapFrame and mapFrame.IsShown and mapFrame:IsShown() then
        ApplySilithusHighlightFix()
        ApplyMovingMapFade(elapsed, false)
    end
end)

local function ScheduleApply(delay)
    if Carpenter and Carpenter.Defer then
        scheduleNonce = scheduleNonce + 1
        Carpenter:Defer("WorldMapCleanup:apply:" .. scheduleNonce, delay or 0, ApplyWorldMapCleanup)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, ApplyWorldMapCleanup)
    else
        ApplyWorldMapCleanup()
    end
end

local function HookWorldMap()
    local mapFrame = _G.WorldMapFrame
    if hookedWorldMap or not mapFrame then return end

    EnsurePOIProvider()
    HookTownCityPins()
    HookSilithusHighlightFix()

    if mapFrame.HookScript then
        mapFrame:HookScript("OnShow", function()
            ApplyWorldMapCleanupImmediately()
            ScheduleApply(0.15)
        end)
    end

    if mapFrame.BlackoutFrame and mapFrame.BlackoutFrame.HookScript then
        mapFrame.BlackoutFrame:HookScript("OnShow", function()
            if IsEnabled() then HideMapBlackout() end
        end)
    end

    if hooksecurefunc then
        if mapFrame.RefreshAllData then hooksecurefunc(mapFrame, "RefreshAllData", function() ScheduleApply(0) end) end
        if mapFrame.OnMapChanged then
            hooksecurefunc(mapFrame, "OnMapChanged", function()
                CenterMapCanvasForCurrentMap()
                ScheduleApply(0)
            end)
        end
        if mapFrame.Maximize then
            hooksecurefunc(mapFrame, "Maximize", function()
                ApplyWorldMapCleanupImmediately()
                ScheduleApply(0.1)
            end)
        end
        if mapFrame.Minimize then
            hooksecurefunc(mapFrame, "Minimize", function()
                ApplyWorldMapCleanupImmediately()
                ScheduleApply(0.1)
            end)
        end
        if mapFrame.SynchronizeDisplayState then
            hooksecurefunc(mapFrame, "SynchronizeDisplayState", function()
                ApplyWorldMapCleanupImmediately()
                ScheduleApply(0.1)
            end)
        end
    end

    hookedWorldMap = true
end

frame:SetScript("OnEvent", function(_, event, addOnName)
    if event == "ADDON_LOADED" and addOnName ~= "Blizzard_WorldMap" then return end

    HookWorldMap()
    ApplyWorldMapCleanupImmediately()
    ScheduleApply(0.2)
end)

local feature = {}

function feature:Enable()
    SafeRegisterEvent("ADDON_LOADED")
    SafeRegisterEvent("PLAYER_LOGIN")
    SafeRegisterEvent("PLAYER_ENTERING_WORLD")
    SafeRegisterEvent("PLAYER_LEVEL_UP")
    SafeRegisterEvent("PLAYER_STARTED_MOVING")
    SafeRegisterEvent("PLAYER_STOPPED_MOVING")
    SafeRegisterEvent("WORLD_MAP_UPDATE")
    SafeRegisterEvent("AREA_POIS_UPDATED")

    HookWorldMap()
    ApplyWorldMapCleanupImmediately()
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("WorldMapCleanup:startup", { 0.2, 1, 3 }, ApplyWorldMapCleanup)
    else
        ScheduleApply(0.2)
        ScheduleApply(1)
        ScheduleApply(3)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
    centeredMapCanvasKey = nil
    RestoreGroupMemberPins()
    RestoreMapObjects()
    RemovePOIPins()
    RefreshMapHighlightPins()
    RestoreScaledMapCursor()
    RestoreMapPosition()
    ApplyMovingMapFade(0, true)
end

function Carpenter_ApplyWorldMapCleanup()
    HookWorldMap()
    if IsEnabled() then
        ApplyWorldMapCleanup()
    else
        centeredMapCanvasKey = nil
        RestoreGroupMemberPins()
        RestoreMapObjects()
        RemovePOIPins()
        RefreshMapHighlightPins()
        RestoreScaledMapCursor()
        RestoreMapPosition()
        ApplyMovingMapFade(0, true)
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("worldMapCleanupEnabled", feature)
end
