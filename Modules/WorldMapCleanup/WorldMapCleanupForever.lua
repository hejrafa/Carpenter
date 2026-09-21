--[[ Carpenter - focused World Map Cleanup for WoW Forever ]]
-- Forever intentionally receives only the maximized-map layout, blackout
-- removal, and Silithus hover repair from the full Classic implementation.
if not (Carpenter and Carpenter.Client and Carpenter.Client.isForever) then return end

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Cleanup = ns.Private.WorldMapCleanup or {}
ns.Private.WorldMapCleanup = Cleanup

local FULLSCREEN_MAP_SCALE = 0.85

local frame = CreateFrame("Frame")
local hookedWorldMap = false
local originalMapState
local originalBlackoutState
local scheduleNonce = 0

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("worldMapCleanupEnabled")
end
Cleanup.IsEnabled = IsEnabled

local function GetWorldMapID()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return nil end
    if mapFrame.mapID then return mapFrame.mapID end
    if mapFrame.GetMapID then return mapFrame:GetMapID() end
    return nil
end
Cleanup.GetWorldMapID = GetWorldMapID

local function SafeRegisterEvent(event)
    if Carpenter and Carpenter.SafeRegisterEvent then
        Carpenter:SafeRegisterEvent(frame, event)
    else
        pcall(frame.RegisterEvent, frame, event)
    end
end

local function CaptureFramePoints(target)
    if not target or not target.GetNumPoints then return nil end

    local points = {}
    for index = 1, target:GetNumPoints() or 0 do
        local point, relativeTo, relativePoint, xOfs, yOfs = target:GetPoint(index)
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

local function RestoreFramePoints(target, points)
    if not target or not points or not target.ClearAllPoints or not target.SetPoint then return end

    target:ClearAllPoints()
    for _, point in ipairs(points) do
        if point.relativeTo then
            target:SetPoint(point.point, point.relativeTo, point.relativePoint, point.xOfs, point.yOfs)
        else
            target:SetPoint(point.point, point.xOfs, point.yOfs)
        end
    end
end

local function IsMapMaximized(mapFrame)
    if not mapFrame then return false end
    if mapFrame.IsMaximized then
        local ok, maximized = pcall(mapFrame.IsMaximized, mapFrame)
        if ok then return maximized == true end
    end
    return mapFrame.isMaximized == true
end

local function CaptureMapState(mapFrame)
    if originalMapState or not mapFrame then return end
    originalMapState = {
        points = CaptureFramePoints(mapFrame),
        width = mapFrame.GetWidth and mapFrame:GetWidth() or nil,
        height = mapFrame.GetHeight and mapFrame:GetHeight() or nil,
        scale = mapFrame.GetScale and mapFrame:GetScale() or 1,
    }
end

local function CaptureBlackoutState(blackout)
    if originalBlackoutState or not blackout then return end
    originalBlackoutState = {
        alpha = blackout.GetAlpha and blackout:GetAlpha() or 1,
        shown = blackout.IsShown and blackout:IsShown() or nil,
    }
end

local function HideMapBlackout()
    local mapFrame = _G.WorldMapFrame
    local blackout = mapFrame and mapFrame.BlackoutFrame
    if not blackout then return end

    CaptureBlackoutState(blackout)
    if blackout.SetAlpha then blackout:SetAlpha(0) end
    if blackout.Hide then blackout:Hide() end
end

local function RestoreMapBlackout()
    local mapFrame = _G.WorldMapFrame
    local blackout = mapFrame and mapFrame.BlackoutFrame
    if not blackout or not originalBlackoutState then return end

    if blackout.SetAlpha then blackout:SetAlpha(originalBlackoutState.alpha or 1) end
    if not IsMapMaximized(mapFrame) or originalBlackoutState.shown == false then
        if blackout.Hide then blackout:Hide() end
    elseif blackout.Show then
        blackout:Show()
    end
    originalBlackoutState = nil
end

local function ApplyMaximizedMapLayout()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return end

    if not IsMapMaximized(mapFrame) then
        if originalMapState and mapFrame.SetScale then
            mapFrame:SetScale(originalMapState.scale or 1)
        end
        return
    end

    CaptureMapState(mapFrame)
    HideMapBlackout()

    mapFrame.CP_WorldMapCleanupApplying = true
    if mapFrame.SetSize and originalMapState.width and originalMapState.height then
        mapFrame:SetSize(originalMapState.width, originalMapState.height)
        if mapFrame.OnFrameSizeChanged then mapFrame:OnFrameSizeChanged() end
    end
    if mapFrame.ClearAllPoints and mapFrame.SetPoint and UIParent then
        mapFrame:ClearAllPoints()
        mapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if mapFrame.SetScale then mapFrame:SetScale(FULLSCREEN_MAP_SCALE) end
    mapFrame.CP_WorldMapCleanupApplying = false
end

local function RestoreMapLayout()
    local mapFrame = _G.WorldMapFrame
    if mapFrame and originalMapState then
        mapFrame.CP_WorldMapCleanupApplying = true
        if IsMapMaximized(mapFrame) then
            if mapFrame.SetSize and originalMapState.width and originalMapState.height then
                mapFrame:SetSize(originalMapState.width, originalMapState.height)
                if mapFrame.OnFrameSizeChanged then mapFrame:OnFrameSizeChanged() end
            end
            RestoreFramePoints(mapFrame, originalMapState.points)
        end
        if mapFrame.SetScale then mapFrame:SetScale(originalMapState.scale or 1) end
        mapFrame.CP_WorldMapCleanupApplying = false
    end

    originalMapState = nil
    RestoreMapBlackout()
end

local function ApplyWorldMapCleanup()
    if not IsEnabled() then return end
    ApplyMaximizedMapLayout()
    if Cleanup.ApplySilithusHighlightFix then
        Cleanup.ApplySilithusHighlightFix()
    end
end

local function ScheduleApply(delay)
    scheduleNonce = scheduleNonce + 1
    local key = "WorldMapCleanupForever:apply:" .. scheduleNonce
    if Carpenter and Carpenter.Defer then
        Carpenter:Defer(key, delay or 0, ApplyWorldMapCleanup)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, ApplyWorldMapCleanup)
    else
        ApplyWorldMapCleanup()
    end
end

local function HookWorldMap()
    local mapFrame = _G.WorldMapFrame
    if hookedWorldMap or not mapFrame then return end

    if mapFrame.HookScript then
        mapFrame:HookScript("OnShow", function()
            ApplyWorldMapCleanup()
            ScheduleApply(0.15)
        end)
    end

    if mapFrame.BlackoutFrame and mapFrame.BlackoutFrame.HookScript then
        mapFrame.BlackoutFrame:HookScript("OnShow", function()
            if IsEnabled() and IsMapMaximized(mapFrame) then
                HideMapBlackout()
            end
        end)
    end

    if Carpenter and Carpenter.SafeHook then
        Carpenter:SafeHook(mapFrame, "Maximize", function()
            ApplyWorldMapCleanup()
            ScheduleApply(0.1)
        end)
        Carpenter:SafeHook(mapFrame, "Minimize", function()
            ApplyWorldMapCleanup()
            ScheduleApply(0.1)
        end)
        Carpenter:SafeHook(mapFrame, "SynchronizeDisplayState", function()
            ApplyWorldMapCleanup()
            ScheduleApply(0.1)
        end)
        Carpenter:SafeHook(mapFrame, "OnMapChanged", function()
            if Cleanup.ApplySilithusHighlightFix then Cleanup.ApplySilithusHighlightFix() end
        end)
    end

    hookedWorldMap = true
end

frame:SetScript("OnUpdate", function()
    local mapFrame = _G.WorldMapFrame
    if IsEnabled() and mapFrame and mapFrame.IsShown and mapFrame:IsShown() and Cleanup.ApplySilithusHighlightFix then
        Cleanup.ApplySilithusHighlightFix()
    end
end)

frame:SetScript("OnEvent", function(_, event, addOnName)
    if event == "ADDON_LOADED" and addOnName ~= "Blizzard_WorldMap" then return end
    HookWorldMap()
    ApplyWorldMapCleanup()
    ScheduleApply(0.2)
end)

local feature = {}

function feature:Enable()
    SafeRegisterEvent("ADDON_LOADED")
    SafeRegisterEvent("PLAYER_LOGIN")
    SafeRegisterEvent("PLAYER_ENTERING_WORLD")
    SafeRegisterEvent("WORLD_MAP_UPDATE")
    HookWorldMap()
    ApplyWorldMapCleanup()
    ScheduleApply(0.2)
    ScheduleApply(1)
end

function feature:Disable()
    frame:UnregisterAllEvents()
    if Cleanup.RefreshMapHighlightPins then Cleanup.RefreshMapHighlightPins() end
    RestoreMapLayout()
end

function Carpenter_ApplyWorldMapCleanup()
    HookWorldMap()
    if IsEnabled() then
        ApplyWorldMapCleanup()
    else
        if Cleanup.RefreshMapHighlightPins then Cleanup.RefreshMapHighlightPins() end
        RestoreMapLayout()
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("worldMapCleanupEnabled", feature)
end
