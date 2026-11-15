--[[ Carpenter - Craftsman's Writ map markers for WoW Forever ]]
-- A Craftsman's Writ asks you to deliver the goods "to the location marked on
-- your map", and its text names no place. Forever's world map draws quest
-- markers only while the map's Quest Objectives filter (the questPOI CVar) is
-- on: Blizzard's QuestDataProvider and QuestBlobDataProvider both stop at
-- GetCVarBool("questPOI"). With the filter off, a writ can't be found.
--
-- A fix for the game, always on with no setting: this data provider of
-- Carpenter's own draws the writs' markers while the filter is off. That is
-- the point C_QuestLog.GetQuestsOnMap gives (the delivery, or the objective
-- while it's in progress) and the next waypoint of a focused or super-tracked
-- writ, as Blizzard's provider does. While the filter is on it
-- draws nothing, so Blizzard's own markers aren't doubled. Other quests keep
-- following the filter.
--
-- The pins inherit QuestPinTemplate (Modules/WritMapMarkers.xml) for the
-- game's look, from a pool of their own. Their mixin replaces what would write
-- Blizzard state from addon code (the hover highlight and QuestCache lookups)
-- and skips SetPassThroughButtons in combat, where addons can't call it.
if not (Carpenter and Carpenter.Client and Carpenter.Client.isForever) then return end

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local WritMapMarkers = {}
ns.Private.WritMapMarkers = WritMapMarkers

local PIN_TEMPLATE = "CarpenterWritQuestPinTemplate"
local QUEST_FILTER_CVAR = "questPOI"

local eventFrame = CreateFrame("Frame")
local provider
local hookedWorldMap = false

-- =========================
-- Writ quests
-- =========================
-- From Forever's item table (ItemSparse, build 1.60.1.70938): every
-- "Craftsman's Writ: <item>" (items 264011-264160) starts quest 94004 or one
-- of 94212-94360. The Naxxramas-era "Craftsman's Writ - <item>" quests are
-- writs too. Matching IDs keeps this the same in every language.
local OLD_WRIT_QUESTS = {
    [9178] = true, [9179] = true, [9181] = true, [9182] = true, [9183] = true,
    [9184] = true, [9185] = true, [9186] = true, [9187] = true, [9188] = true,
    [9190] = true, [9191] = true, [9194] = true, [9195] = true, [9196] = true,
    [9197] = true, [9198] = true, [9200] = true, [9201] = true, [9202] = true,
    [9203] = true, [9204] = true, [9205] = true, [9206] = true,
}
local FIRST_WRIT_QUEST, LAST_WRIT_QUEST = 94212, 94360
local LONE_WRIT_QUEST = 94004

local function IsWritQuest(questID)
    if type(questID) ~= "number" then return false end
    if questID >= FIRST_WRIT_QUEST and questID <= LAST_WRIT_QUEST then return true end
    return questID == LONE_WRIT_QUEST or OLD_WRIT_QUESTS[questID] == true
end
WritMapMarkers.IsWritQuest = IsWritQuest

-- =========================
-- Markers
-- =========================
local function IsQuestFilterOn()
    return GetCVarBool ~= nil and GetCVarBool(QUEST_FILTER_CVAR) == true
end

local function MapTypeShowsQuests(mapType)
    if MapUtil and MapUtil.ShouldMapTypeShowQuests then
        return MapUtil.ShouldMapTypeShowQuests(mapType)
    end
    local mapTypes = Enum and Enum.UIMapType
    return not mapTypes or (mapType ~= mapTypes.World and mapType ~= mapTypes.Continent
        and mapType ~= mapTypes.Cosmic)
end

local function GetSuperTrackedQuestID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return C_SuperTrack.GetSuperTrackedQuestID()
    end
    return nil
end

-- The quest whose details the quest log shows; Blizzard then hides every
-- other quest's marker.
local function GetFocusedQuestID()
    if QuestMapFrame_GetFocusedQuestID then
        return QuestMapFrame_GetFocusedQuestID()
    end
    return nil
end

-- The writ markers for one map, placed as QuestDataProvider places markers
-- with the filter on (its RefreshAllData and ShouldShowQuest).
local function CollectMarkers(mapID)
    local markers = {}
    if not mapID or IsQuestFilterOn() then return markers end
    if not (C_Map and C_Map.GetMapInfo and C_QuestLog and C_QuestLog.GetQuestsOnMap) then return markers end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return markers end

    local focusedQuestID = GetFocusedQuestID()
    local superTrackedQuestID = GetSuperTrackedQuestID()
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent

    local function ShouldShow(questID)
        if not IsWritQuest(questID) then return false end
        if focusedQuestID and focusedQuestID ~= questID then return false end
        if HaveQuestData and not HaveQuestData(questID) then return false end
        if mapInfo.mapType == continentType and questID == superTrackedQuestID then return true end
        return MapTypeShowsQuests(mapInfo.mapType)
    end

    local quests = C_QuestLog.GetQuestsOnMap(mapID) or {}
    for index, info in ipairs(quests) do
        if not info.isMapIndicatorQuest and ShouldShow(info.questID) then
            markers[#markers + 1] = { questID = info.questID, x = info.x, y = info.y, frameLevelOffset = index }
        end
    end

    local waypointQuestID = focusedQuestID or superTrackedQuestID
    if waypointQuestID and C_QuestLog.GetNextWaypointForMap and ShouldShow(waypointQuestID) then
        local x, y = C_QuestLog.GetNextWaypointForMap(waypointQuestID, mapID)
        if x and y then
            markers[#markers + 1] = {
                questID = waypointQuestID, x = x, y = y, isWaypoint = true, frameLevelOffset = #quests + 1,
            }
        end
    end

    return markers
end
WritMapMarkers.CollectMarkers = CollectMarkers

-- =========================
-- Pin
-- =========================
CarpenterWritQuestPinMixin = CarpenterWritQuestPinMixin or {}
local PinMixin = CarpenterWritQuestPinMixin

-- POIButtonUtil.GetStyle without QuestCache, whose entries Blizzard's tracker
-- reads back.
local function GetQuestStyle(questID)
    local styles = POIButtonUtil.Style
    if C_QuestLog.IsComplete(questID) then return styles.QuestComplete end
    if C_QuestLog.IsQuestDisabledForSession and C_QuestLog.IsQuestDisabledForSession(questID) then
        return styles.QuestDisabled
    end
    return styles.QuestInProgress
end

function PinMixin:OnAcquired(marker)
    local questID = marker.questID
    self:SetQuestID(questID)

    local isSuperTracked = questID == GetSuperTrackedQuestID()
    self.isSuperTracked = isSuperTracked
    if isSuperTracked then
        self:UseFrameLevelType("PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST")
    else
        self:UseFrameLevelType("PIN_FRAME_LEVEL_ACTIVE_QUEST", marker.frameLevelOffset)
    end

    self.Display:ClearAllPoints()
    self.Display:SetPoint("CENTER")
    self:SetSelected(isSuperTracked)
    self:SetStyle(marker.isWaypoint and POIButtonUtil.Style.Waypoint or GetQuestStyle(questID))
    self:UpdateButtonStyle()
    self:EvaluateManagedHighlight()
    self:SetPosition(marker.x, marker.y)
end

function PinMixin:GetQuestClassification()
    local questID = self:GetQuestID()
    if questID and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        return C_QuestInfoSystem.GetQuestClassification(questID)
    end
    return nil
end

function PinMixin:GetHighlightType()
    return MapPinHighlightType and MapPinHighlightType.None
end

-- The map calls this on every pin it hands out so right-clicks reach the map
-- and zoom out. Addon code can't call it in combat; a pin handed out then
-- keeps the pass-through it had, or takes the right-click itself.
function PinMixin:SetPassThroughButtons(...)
    if InCombatLockdown and InCombatLockdown() then return end
    local widget = getmetatable(self)
    local methods = widget and widget.__index
    local setPassThrough = type(methods) == "table" and methods.SetPassThroughButtons
    if setPassThrough then setPassThrough(self, ...) end
end

local function Dash(text)
    return (QUEST_DASH or "- ") .. text
end

local function AddObjectiveLines(questID)
    local questLogIndex = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if not questLogIndex then return end

    local numDrops = GetNumQuestItemDrops and GetNumQuestItemDrops(questLogIndex) or 0
    if numDrops > 0 then
        for index = 1, numDrops do
            local text, _, finished = GetQuestLogItemDrop(index, questLogIndex)
            if text and not finished then GameTooltip:AddLine(Dash(text), 1, 1, 1, true) end
        end
        return
    end

    for index = 1, GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(questLogIndex) or 0 do
        local text, _, finished = GetQuestLogLeaderBoard(index, questLogIndex)
        if text and not finished then GameTooltip:AddLine(Dash(text), 1, 1, 1, true) end
    end
end

-- QuestPinMixin's tooltip, without the hover highlight it hands to the
-- objective tracker and quest log.
function PinMixin:OnMouseEnter()
    local questID = self:GetQuestID()
    if not questID or not GameTooltip then return end

    local title = C_QuestLog.GetTitleForQuestID(questID) or ""
    if SetQuestTitleLevelAndDifficultyColor then
        title = SetQuestTitleLevelAndDifficultyColor(questID, title) or title
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 5, 2)
    GameTooltip:SetText(title)
    if QuestUtils_AddQuestTypeToTooltip then
        QuestUtils_AddQuestTypeToTooltip(GameTooltip, questID, NORMAL_FONT_COLOR)
    end
    if GameTooltip_CheckAddQuestTimeToTooltip then
        GameTooltip_CheckAddQuestTimeToTooltip(GameTooltip, questID)
    end

    local waypointText = (questID == GetSuperTrackedQuestID() or questID == GetFocusedQuestID())
        and C_QuestLog.GetNextWaypointText and C_QuestLog.GetNextWaypointText(questID)
    if waypointText and waypointText ~= "" then
        GameTooltip:AddLine(Dash(waypointText), 1, 1, 1, true)
    elseif self:GetStyle() == POIButtonUtil.Style.QuestInProgress then
        AddObjectiveLines(questID)
    end

    GameTooltip:Show()
end

function PinMixin:OnMouseLeave()
    if GameTooltip and GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
end

-- Left-click super-tracks the writ, or stops when it already is, as a quest
-- marker does.
function PinMixin:OnMouseClickAction(button)
    if button ~= "LeftButton" or not C_SuperTrack then return end

    local questID = self:GetQuestID()
    if not questID then return end
    if self:IsSelected() then
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
        C_SuperTrack.ClearAllSuperTracked()
        return
    end

    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    if C_QuestLog.GetQuestWatchType and C_QuestLog.AddQuestWatch and C_QuestLog.GetQuestWatchType(questID) == nil then
        C_QuestLog.AddQuestWatch(questID)
    end
    C_SuperTrack.SetSuperTrackedQuestID(questID)
end

-- =========================
-- Data provider
-- =========================
local function RemoveMarkers()
    local map = provider and provider:GetMap()
    if map and map.RemoveAllPinsByTemplate then
        map:RemoveAllPinsByTemplate(PIN_TEMPLATE)
    end
end

local function EnsureProvider()
    if provider then return provider end
    local mapFrame = _G.WorldMapFrame
    if not (mapFrame and mapFrame.AddDataProvider and CreateFromMixins and MapCanvasDataProviderMixin) then
        return nil
    end
    if not (QuestPinMixin and POIButtonUtil and POIButtonUtil.Style) then return nil end

    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        RemoveMarkers()
    end

    function provider:RefreshAllData()
        RemoveMarkers()
        local map = self:GetMap()
        if not map then return end

        -- There's no setting to turn this off, so a pin that fails stays a
        -- missing marker instead of an error on every quest log update.
        for _, marker in ipairs(CollectMarkers(map:GetMapID())) do
            pcall(map.AcquirePin, map, PIN_TEMPLATE, marker)
        end
    end

    mapFrame:AddDataProvider(provider)
    return provider
end

local function IsMapShown()
    local mapFrame = _G.WorldMapFrame
    return mapFrame ~= nil and mapFrame.IsShown ~= nil and mapFrame:IsShown() == true
end

-- A closed map draws its markers again when it opens.
local function Refresh()
    if provider and IsMapShown() then provider:RefreshAllData() end
end

local function ScheduleRefresh()
    Carpenter:Defer("WritMapMarkers:refresh", 0, Refresh)
end

-- Opening or closing a quest's details changes which markers show.
local function HookWorldMap()
    local mapFrame = _G.WorldMapFrame
    if hookedWorldMap or not mapFrame then return end
    Carpenter:SafeHook(mapFrame, "SetFocusedQuestID", ScheduleRefresh)
    Carpenter:SafeHook(mapFrame, "ClearFocusedQuestID", ScheduleRefresh)
    hookedWorldMap = true
end

local function Setup()
    HookWorldMap()
    if EnsureProvider() then Refresh() end
end

local REFRESH_EVENTS = {
    "QUEST_LOG_UPDATE",
    "QUEST_POI_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "SUPER_TRACKING_CHANGED",
    "CVAR_UPDATE",
}

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_WorldMap" then Setup() end
        return
    end
    if event == "PLAYER_LOGIN" then
        Setup()
        return
    end
    if event == "CVAR_UPDATE" and arg1 ~= QUEST_FILTER_CVAR then return end
    if not IsMapShown() then return end
    if not provider then Setup() end
    ScheduleRefresh()
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs(REFRESH_EVENTS) do
    eventFrame:RegisterEvent(event)
end
Setup()
