#!/usr/bin/env lua
-- Offline fixture checks for the always-on writ map marker fix on WoW
-- Forever: with the map's Quest Objectives filter (questPOI) off, Craftsman's
-- Writ quests keep their markers, placed as Blizzard's QuestDataProvider would
-- place them, and every other quest stays hidden. With the filter on, Blizzard
-- draws them itself. There is no setting.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "writ-map-markers")
local fail, assertEqual, assertTrue = H.fail, H.assertEqual, H.assertTrue

local function readFile(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

-- =========================
-- No setting
-- =========================
-- The setting it had before release is gone, and so are its saved value and
-- the test log, cleared on load.
do
    SlashCmdList = {}
    floor = math.floor
    Carpenter = { Client = { isMainline = true, isForever = true } }
    CreateFrame = function()
        return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
    end
    assert(loadfile(repo .. "/Core/Carpenter.lua"))("Carpenter", { Private = {} })
    assertEqual(Carpenter.Defaults.writMapMarkersEnabled, nil, "no default for the removed setting")
    CarpenterDB = {
        foreverDefaultsResetVersion = 1,
        writMapMarkersEnabled = true,
        writMapMarkersProbeLog = { "16:43:00 map=1440" },
    }
    Carpenter_InitializeSettings()
    assertEqual(CarpenterDB.writMapMarkersEnabled, nil, "old setting cleared on load")
    assertEqual(CarpenterDB.writMapMarkersProbeLog, nil, "old test log cleared on load")

    Carpenter = {}
    WOW_PROJECT_ID = 99
    WOW_PROJECT_MAINLINE = 1
    GetBuildInfo = function() return "x", "", "", 16001 end
    assert(loadfile(repo .. "/Core/Compatibility.lua"))("Carpenter", {})
    assertEqual(Carpenter.FeatureManifest.writMapMarkersEnabled, nil, "no feature entry")
    assertTrue(not readFile("Settings/ConfigOptions.lua"):find("writMapMarkers", 1, true), "no settings option")
    assertTrue(not readFile("Localization/enUS.lua"):find("WRIT_MAP_MARKERS", 1, true), "no option strings")
end

-- The pin template inherits Blizzard's quest pin and takes the module's mixin,
-- and the Forever TOC loads the module before it.
local xml = readFile("Modules/WritMapMarkers.xml")
assertTrue(xml:find('name="CarpenterWritQuestPinTemplate"', 1, true), "pin template name")
assertTrue(xml:find('inherits="QuestPinTemplate"', 1, true), "pin template inherits QuestPinTemplate")
assertTrue(xml:find('mixin="CarpenterWritQuestPinMixin"', 1, true), "pin template mixin")
local toc = readFile("Carpenter_Camelot.toc")
local luaAt = toc:find("Modules\\WritMapMarkers.lua", 1, true)
local xmlAt = toc:find("Modules\\WritMapMarkers.xml", 1, true)
assertTrue(luaAt and xmlAt and luaAt < xmlAt, "Forever TOC loads the module, then its template")

-- =========================
-- Game state
-- =========================
H.installCreateFrame()
H.installHooks()
H.installTimers("immediate")

local cvars = { questPOI = false }
GetCVarBool = function(name) return cvars[name] == true end

Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4 } }
MapUtil = {
    ShouldMapTypeShowQuests = function(mapType)
        return mapType ~= Enum.UIMapType.World and mapType ~= Enum.UIMapType.Continent
            and mapType ~= Enum.UIMapType.Cosmic
    end,
}

local ZONE, CONTINENT = 1440, 1414
local maps = {
    [ZONE] = { mapID = ZONE, mapType = Enum.UIMapType.Zone },
    [CONTINENT] = { mapID = CONTINENT, mapType = Enum.UIMapType.Continent },
}
C_Map = { GetMapInfo = function(mapID) return maps[mapID] end }

local SPIDER_SILK_SLIPPERS, GREEN_IRON_GAUNTLETS, OGRE_STRENGTH = 94255, 94226, 94004
local NORMAL_QUEST = 1234
local questsOnMap = {}
local waypoints = {}
local complete = { [SPIDER_SILK_SLIPPERS] = true }
local disabled = {}
local watched = {}
local superTracked
local focused

C_QuestLog = {
    GetQuestsOnMap = function(mapID) return questsOnMap[mapID] end,
    GetNextWaypointForMap = function(questID, mapID)
        local point = waypoints[questID] and waypoints[questID][mapID]
        if point then return point[1], point[2] end
    end,
    GetNextWaypoint = function() return nil end,
    GetNextWaypointText = function(questID) return waypoints[questID] and "Take the boat to Booty Bay" or nil end,
    IsComplete = function(questID) return complete[questID] == true end,
    IsQuestDisabledForSession = function(questID) return disabled[questID] == true end,
    GetTitleForQuestID = function(questID) return "Quest " .. questID end,
    GetLogIndexForQuestID = function() return 3 end,
    GetNumQuestLogEntries = function() return 2 end,
    GetInfo = function(index)
        if index == 1 then return { isHeader = true, title = "Crafting" } end
        return { questID = SPIDER_SILK_SLIPPERS, isOnMap = true, hasLocalPOI = true }
    end,
    GetQuestWatchType = function(questID) return watched[questID] end,
    AddQuestWatch = function(questID) watched[questID] = 0 end,
}
HaveQuestData = function() return true end
C_SuperTrack = {
    GetSuperTrackedQuestID = function() return superTracked end,
    SetSuperTrackedQuestID = function(questID) superTracked = questID end,
    ClearAllSuperTracked = function() superTracked = nil end,
}
C_QuestInfoSystem = { GetQuestClassification = function() return 2 end }
QuestMapFrame_GetFocusedQuestID = function() return focused end
GetNumQuestLeaderBoards = function() return 1 end
GetQuestLogLeaderBoard = function() return "Spider Silk Slippers: 0/1", "item", false end
QUEST_DASH = "- "
MapPinHighlightType = { None = 0 }
POIButtonUtil = {
    Style = { QuestComplete = "complete", QuestInProgress = "inprogress", QuestDisabled = "disabled", Waypoint = "waypoint" },
}
-- No QuestCache: the pins must not reach for it.
QuestCache = nil

local tooltip = { lines = {} }
function tooltip:SetOwner(owner) self.owner = owner; self.lines = {} end
function tooltip:GetOwner() return self.owner end
function tooltip:SetText(text) self.lines = { text } end
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false; self.owner = nil end
GameTooltip = tooltip

function CreateFromMixins(...)
    local result = {}
    for index = 1, select("#", ...) do
        for key, value in pairs(select(index, ...)) do result[key] = value end
    end
    return result
end

MapCanvasDataProviderMixin = {}
function MapCanvasDataProviderMixin:OnAdded(map) self.owningMap = map end
function MapCanvasDataProviderMixin:GetMap() return self.owningMap end
function MapCanvasDataProviderMixin:RefreshAllData() end
function MapCanvasDataProviderMixin:RemoveAllData() end

-- What QuestPinTemplate brings: POIButtonMixin and QuestPinMixin, and the
-- widget's own SetPassThroughButtons, which addon code can't call in combat.
local inCombat = false
InCombatLockdown = function() return inCombat end
local buttonMethods = {}
function buttonMethods:SetPassThroughButtons(...)
    if inCombat then fail("SetPassThroughButtons called in combat") end
    self.passThrough = { ... }
end
QuestPinMixin = {}
local function NewQuestPin(map)
    local pin = setmetatable({ map = map, shown = true, Display = { points = {} } }, { __index = buttonMethods })
    function pin.Display:ClearAllPoints() self.points = {} end
    function pin.Display:SetPoint(point) self.points[#self.points + 1] = point end
    function pin:SetQuestID(questID) self.questID = questID end
    function pin:GetQuestID() return self.questID end
    function pin:UseFrameLevelType(levelType, offset) self.levelType, self.levelOffset = levelType, offset end
    function pin:SetSelected(selected) self.selected = selected end
    function pin:IsSelected() return self.selected end
    function pin:SetStyle(style) self.style = style end
    function pin:GetStyle() return self.style end
    function pin:GetQuestClassification() return QuestCache:Get(self.questID):GetQuestClassification() end
    function pin:UpdateButtonStyle() self.classification = self:GetQuestClassification() end
    function pin:EvaluateManagedHighlight() end
    function pin:SetPosition(x, y) self.x, self.y = x, y end
    function pin:GetMap() return self.map end
    function pin:CheckMouseButtonPassthrough(button)
        self:SetPassThroughButtons()
        self:SetPassThroughButtons(button)
    end
    return pin
end

-- =========================
-- World map
-- =========================
local mapFrame = H.NamedFrame("WorldMapFrame", { mapID = ZONE, pinPools = {}, acquired = 0 })
function mapFrame:GetMapID() return self.mapID end
function mapFrame:AddDataProvider(dataProvider)
    self.dataProvider = dataProvider
    dataProvider:OnAdded(self)
end
function mapFrame:AcquirePin(template, ...)
    local pin = NewQuestPin(self)
    for key, value in pairs(_G.CarpenterWritQuestPinMixin) do pin[key] = value end
    pin.template = template
    pin:OnAcquired(...)
    pin:CheckMouseButtonPassthrough("RightButton")
    self.pinPools[template] = self.pinPools[template] or {}
    table.insert(self.pinPools[template], pin)
    self.acquired = self.acquired + 1
    return pin
end
function mapFrame:RemoveAllPinsByTemplate(template) self.pinPools[template] = nil end
function mapFrame:SetFocusedQuestID(questID) focused = questID end
function mapFrame:ClearFocusedQuestID() focused = nil end

local function Pins()
    return mapFrame.pinPools.CarpenterWritQuestPinTemplate or {}
end

local function Refresh()
    mapFrame.dataProvider:RefreshAllData()
end

-- =========================
-- Module
-- =========================
CarpenterDB = {}
H.carpenter({ Client = { isForever = true } })
local ns = { Private = {} }
H.load("Modules/WritMapMarkers.lua", ns)
local Writs = ns.Private.WritMapMarkers
assertTrue(_G.CarpenterWritQuestPinMixin, "pin mixin is global for the XML template")

-- Writs by quest ID, in any language.
for _, questID in ipairs({ OGRE_STRENGTH, 94212, GREEN_IRON_GAUNTLETS, SPIDER_SILK_SLIPPERS, 94360, 9178, 9206 }) do
    assertEqual(Writs.IsWritQuest(questID), true, "writ quest " .. questID)
end
for _, questID in ipairs({ 94211, 94361, 9180, 9142, NORMAL_QUEST }) do
    assertEqual(Writs.IsWritQuest(questID), false, "not a writ quest " .. questID)
end

-- On from the moment it loads.
local provider = mapFrame.dataProvider
assertTrue(provider, "data provider added to the world map at load")
local eventFrame = H.createdFrames[1]
assertTrue(eventFrame.events.QUEST_LOG_UPDATE and eventFrame.events.CVAR_UPDATE, "refresh events registered at load")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "Blizzard_WorldMap")
assertEqual(mapFrame.dataProvider, provider, "setting up again keeps the one provider")

-- A ready writ, a normal quest, and a writ the map only hints at.
questsOnMap[ZONE] = {
    { questID = NORMAL_QUEST, x = 0.2, y = 0.3 },
    { questID = SPIDER_SILK_SLIPPERS, x = 0.4, y = 0.5 },
    { questID = GREEN_IRON_GAUNTLETS, x = 0.6, y = 0.6, isMapIndicatorQuest = true },
}
questsOnMap[CONTINENT] = { { questID = SPIDER_SILK_SLIPPERS, x = 0.45, y = 0.7 } }

-- Filter off: only the writ.
Refresh()
local pins = Pins()
assertEqual(#pins, 1, "filter off shows the writ only")
local pin = pins[1]
assertEqual(pin.questID, SPIDER_SILK_SLIPPERS, "writ pin quest")
assertEqual(pin.x, 0.4, "writ pin x")
assertEqual(pin.y, 0.5, "writ pin y")
assertEqual(pin.style, "complete", "ready writ shows the turn-in style")
assertEqual(pin.levelType, "PIN_FRAME_LEVEL_ACTIVE_QUEST", "writ pin frame level")
assertEqual(pin.levelOffset, 2, "frame level offset follows the map's quest order")
assertEqual(pin.selected, false, "writ not super-tracked")
assertEqual(pin.classification, 2, "classification read without QuestCache")
assertEqual(pin.passThrough and pin.passThrough[1], "RightButton", "right-clicks pass through to the map")
assertEqual(pin.Display.points[1], "CENTER", "display centered")

-- Filter on: Blizzard draws them; nothing doubled.
cvars.questPOI = true
Refresh()
assertEqual(#Pins(), 0, "filter on leaves the markers to Blizzard")

-- Turning the filter off from the map's menu refreshes through CVAR_UPDATE.
cvars.questPOI = false
eventFrame.scripts.OnEvent(eventFrame, "CVAR_UPDATE", "questPOI")
assertEqual(#Pins(), 1, "CVAR_UPDATE for questPOI refreshes the markers")
local acquired = mapFrame.acquired
eventFrame.scripts.OnEvent(eventFrame, "CVAR_UPDATE", "showQuestLevel")
assertEqual(mapFrame.acquired, acquired, "other CVars don't refresh")

-- A closed map isn't refreshed; it refreshes itself when opened.
mapFrame.shown = false
eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
assertEqual(mapFrame.acquired, acquired, "closed map isn't refreshed")
mapFrame.shown = true
eventFrame.scripts.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
assertEqual(mapFrame.acquired, acquired + 1, "open map refreshes on quest log updates")

-- Another quest's details hide the writ, as they hide every other marker.
mapFrame:SetFocusedQuestID(NORMAL_QUEST)
assertEqual(#Pins(), 0, "focused normal quest hides the writ")

-- The writ's own details show it and its next waypoint.
waypoints[SPIDER_SILK_SLIPPERS] = { [ZONE] = { 0.9, 0.1 } }
mapFrame:SetFocusedQuestID(SPIDER_SILK_SLIPPERS)
pins = Pins()
assertEqual(#pins, 2, "focused writ shows its marker and waypoint")
assertEqual(pins[2].style, "waypoint", "waypoint style")
assertEqual(pins[2].x, 0.9, "waypoint x")
assertEqual(pins[2].levelOffset, 4, "waypoint after the map's quests")
mapFrame:ClearFocusedQuestID()
waypoints[SPIDER_SILK_SLIPPERS] = nil
assertEqual(#Pins(), 1, "closing the details refreshes")

-- Continent maps show a writ only while it's super-tracked.
mapFrame.mapID = CONTINENT
Refresh()
assertEqual(#Pins(), 0, "continent hides a writ that isn't super-tracked")
superTracked = SPIDER_SILK_SLIPPERS
Refresh()
pin = Pins()[1]
assertTrue(pin, "continent shows the super-tracked writ")
assertEqual(pin.levelType, "PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST", "super-tracked frame level")
assertEqual(pin.selected, true, "super-tracked writ is selected")
superTracked = nil
mapFrame.mapID = ZONE

-- In progress and disabled styles.
complete[SPIDER_SILK_SLIPPERS] = false
Refresh()
pin = Pins()[1]
assertEqual(pin.style, "inprogress", "writ in progress")

-- Tooltip: title and the open objective, nothing handed to Blizzard's highlight.
pin:OnMouseEnter()
assertEqual(tooltip.owner, pin, "tooltip owned by the pin")
assertEqual(tooltip.lines[1], "Quest " .. SPIDER_SILK_SLIPPERS, "tooltip title")
assertEqual(tooltip.lines[2], "- Spider Silk Slippers: 0/1", "tooltip objective")
pin:OnMouseLeave()
assertEqual(tooltip.shown, false, "tooltip hidden on leave")

disabled[SPIDER_SILK_SLIPPERS] = true
Refresh()
assertEqual(Pins()[1].style, "disabled", "writ disabled for the session")
disabled[SPIDER_SILK_SLIPPERS] = nil
complete[SPIDER_SILK_SLIPPERS] = true

-- In combat the pin skips SetPassThroughButtons.
inCombat = true
Refresh()
assertEqual(Pins()[1].passThrough, nil, "no pass-through set in combat")
inCombat = false

-- Clicks: left super-tracks (and watches), left again stops; right-clicks
-- are the map's.
Refresh()
pin = Pins()[1]
pin:OnMouseClickAction("LeftButton")
assertEqual(superTracked, SPIDER_SILK_SLIPPERS, "left-click super-tracks the writ")
assertEqual(watched[SPIDER_SILK_SLIPPERS], 0, "left-click watches the writ")
pin:SetSelected(true)
pin:OnMouseClickAction("LeftButton")
assertEqual(superTracked, nil, "left-click on the selected writ stops super-tracking")
pin:OnMouseClickAction("RightButton")
assertEqual(superTracked, nil, "right-click doesn't super-track")

-- Nothing is saved.
assertTrue(next(CarpenterDB) == nil, "nothing written to saved variables")

print("writ-map-markers fixtures passed")
