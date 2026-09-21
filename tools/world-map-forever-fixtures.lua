local root = assert(arg[1], "usage: lua tools/world-map-forever-fixtures.lua <addon-root>")
local unpackValues = table.unpack or unpack

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function newRegion()
    local region = { alpha = 1, shown = true }
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:GetAlpha() return self.alpha end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:HookScript(event, callback) self[event] = callback end
    return region
end

do
    local compatibilityNamespace = {}
    Carpenter = {}
    WOW_PROJECT_ID = 99
    WOW_PROJECT_MAINLINE = 1
    function GetBuildInfo() return "Forever", "", "", 16001 end
    assert(loadfile(root .. "/Core/Compatibility.lua"))("Carpenter", compatibilityNamespace)
    assertEqual(Carpenter.Client.isForever, true, "Forever client detection")
    assertEqual(Carpenter:IsFeatureAvailable("worldMapCleanupEnabled"), true, "Forever map cleanup availability")
end

local registeredFeatures = {}
local driverFrame

CarpenterDB = { worldMapCleanupEnabled = true }
Carpenter = {
    Client = { isForever = true, isClassic = false },
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(_, key, feature) registeredFeatures[key] = feature end,
    SafeRegisterEvent = function(_, frame, event) frame:RegisterEvent(event) return true end,
    Defer = function(_, _, _, callback) callback() end,
}

function Carpenter:SafeHook(target, method, handler)
    local original = target and target[method]
    if type(original) ~= "function" then return false end
    target[method] = function(self, ...)
        local results = { original(self, ...) }
        handler(self, ...)
        return unpackValues(results)
    end
    return true
end

function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    driverFrame = driverFrame or frame
    return frame
end

UIParent = {}

local blackout = newRegion()
local mapFrame = {
    BlackoutFrame = blackout,
    height = 700,
    width = 1000,
    scale = 1,
    shown = true,
    isMaximized = true,
    points = { { "TOPLEFT", UIParent, "TOPLEFT", 20, -30 } },
    scripts = {},
}

function mapFrame:GetNumPoints() return #self.points end
function mapFrame:GetPoint(index) return unpackValues(self.points[index]) end
function mapFrame:ClearAllPoints() self.points = {} end
function mapFrame:SetPoint(...) self.points[#self.points + 1] = { ... } end
function mapFrame:GetWidth() return self.width end
function mapFrame:GetHeight() return self.height end
function mapFrame:SetSize(width, height) self.width, self.height = width, height end
function mapFrame:OnFrameSizeChanged() end
function mapFrame:GetScale() return self.scale end
function mapFrame:SetScale(scale) self.scale = scale end
function mapFrame:IsMaximized() return self.isMaximized end
function mapFrame:IsShown() return self.shown end
function mapFrame:HookScript(event, callback) self.scripts[event] = callback end
function mapFrame:Maximize() self.isMaximized = true end
function mapFrame:Minimize() self.isMaximized = false end
function mapFrame:SynchronizeDisplayState() end
function mapFrame:OnMapChanged() end
function mapFrame:GetMapID() return 1414 end
function mapFrame:IsCanvasMouseFocus() return true end
function mapFrame:GetNormalizedCursorPosition() return 0.43, 0.80 end

local nativeHighlight = newRegion()
local highlightPin = {
    HighlightTexture = nativeHighlight,
}

function highlightPin:GetMap() return mapFrame end
function highlightPin:GetWidth() return 1000 end
function highlightPin:GetHeight() return 700 end
function highlightPin:CreateTexture()
    local texture = newRegion()
    function texture:SetTexture(path) self.path = path end
    function texture:SetTexCoord(...) self.texCoords = { ... } end
    function texture:SetBlendMode(mode) self.blendMode = mode end
    function texture:SetVertexColor(...) self.vertexColor = { ... } end
    function texture:ClearAllPoints() self.point = nil end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:SetPoint(...) self.point = { ... } end
    return texture
end

MapHighlightPinMixin = { Refresh = function() end }
function highlightPin:Refresh() MapHighlightPinMixin.Refresh(self) end

function mapFrame:EnumeratePinsByTemplate(template)
    assertEqual(template, "MapHighlightPinTemplate", "Silithus pin template")
    local yielded = false
    return function()
        if yielded then return nil end
        yielded = true
        return highlightPin
    end
end

WorldMapFrame = mapFrame
C_Map = {
    GetMapInfoAtPosition = function() return { mapID = 1451 } end,
    GetMapRectOnMap = function() return 0.39, 0.47, 0.74, 0.895 end,
}
C_Timer = { After = function(_, callback) callback() end }

local namespace = { Private = {} }
assert(loadfile(root .. "/Modules/WorldMapCleanup/WorldMapCleanupSilithus.lua"))("Carpenter", namespace)
assert(loadfile(root .. "/Modules/WorldMapCleanup/WorldMapCleanupForever.lua"))("Carpenter", namespace)

local feature = assert(registeredFeatures.worldMapCleanupEnabled, "Forever World Map Cleanup feature was not registered")
feature:Enable()

assertEqual(mapFrame.scale, 0.85, "maximized map scale")
assertEqual(mapFrame.points[1][1], "CENTER", "maximized map anchor")
assertEqual(mapFrame.points[1][2], UIParent, "maximized map anchor parent")
assertEqual(blackout.shown, false, "fullscreen blackout visibility")
assertEqual(blackout.alpha, 0, "fullscreen blackout alpha")
assertEqual(GameTimeFrame, nil, "fixture sanity")
assertEqual(highlightPin.CP_SilithusHighlightTexture.shown, true, "Silithus replacement highlight")
assertEqual(nativeHighlight.shown, false, "broken native Silithus highlight")

CarpenterDB.worldMapCleanupEnabled = false
feature:Disable()
assertEqual(mapFrame.scale, 1, "disabled map scale restoration")
assertEqual(mapFrame.points[1][1], "TOPLEFT", "disabled map anchor restoration")
assertEqual(blackout.shown, true, "disabled blackout restoration")
assertEqual(blackout.alpha, 1, "disabled blackout alpha restoration")
assertEqual(highlightPin.CP_SilithusHighlightTexture.shown, false, "disabled Silithus highlight restoration")

mapFrame.isMaximized = false
CarpenterDB.worldMapCleanupEnabled = true
feature:Enable()
assertEqual(mapFrame.scale, 1, "windowed map scale remains unchanged")
assertEqual(mapFrame.points[1][1], "TOPLEFT", "windowed map anchor remains unchanged")
assertEqual(blackout.shown, true, "windowed map blackout remains unchanged")

mapFrame.isMaximized = true
feature:Enable()
mapFrame.isMaximized = false
mapFrame:ClearAllPoints()
mapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -50)
CarpenterDB.worldMapCleanupEnabled = false
feature:Disable()
assertEqual(mapFrame.points[1][4], 40, "windowed map anchor survives disabling")
assertEqual(mapFrame.points[1][5], -50, "windowed map offset survives disabling")
assertEqual(blackout.shown, false, "windowed map blackout stays hidden after disabling")

local camelotFile = assert(io.open(root .. "/Carpenter_Camelot.toc", "r"))
local camelotTOC = camelotFile:read("*a")
camelotFile:close()
assert(camelotTOC:find("Modules\\WorldMapCleanup\\WorldMapCleanupForever.lua", 1, true), "Camelot TOC does not load the Forever map cleanup")
assert(not camelotTOC:find("WorldMapCleanupPOIPins.lua", 1, true), "Camelot must not load Classic POI pins")
assert(not camelotTOC:find("WorldMapCleanupPins.lua", 1, true), "Camelot must not load Classic town or group pin cleanup")

print("world-map Forever fixtures: passed")
