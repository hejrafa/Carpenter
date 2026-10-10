--[[ Carpenter - Quest Tracker Sort ]]
-- Orders tracked quests from lowest to highest level on WoW Forever.
-- Blizzard's tracker lists quests in watch-list order, so this reorders the
-- watch list itself instead of touching the tracker (which would taint it).
-- Forever puts a newly watched quest at the top of the list.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local FEATURE_KEY = "sortQuestsByLevelEnabled"
local UPDATE_DELAY = 0.2

local QuestTrackerSort = {}
ns.Private.QuestTrackerSort = QuestTrackerSort

local frame = CreateFrame("Frame")
local pendingCombatSort = false
-- The watch order we last tried to fix. If the same order comes back, the
-- client did not keep our order, so stop instead of re-adding in a loop.
local lastAttemptedOrder

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

local function IsUsable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- The tracker's "[12]" prefix comes from difficultyLevel, so sort on the same value.
local function GetQuestLevel(questID)
    local logIndex = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if not IsUsable(logIndex) then return nil end

    local info = C_QuestLog.GetInfo(logIndex)
    if not info then return nil end

    local level = info.difficultyLevel
    if not IsUsable(level) or level == 0 then
        level = info.level
    end
    if not IsUsable(level) or type(level) ~= "number" then return nil end
    return level
end

local function GetOrderSignature(quests)
    local ids = {}
    for i, quest in ipairs(quests) do
        ids[i] = tostring(quest.questID)
    end
    return table.concat(ids, ",")
end

local function GetWatchedQuests()
    local quests = {}
    for watchIndex = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
        if IsUsable(questID) then
            quests[#quests + 1] = {
                questID = questID,
                index = watchIndex,
                level = GetQuestLevel(questID),
            }
        end
    end
    return quests
end

-- Lowest level first; quests without a known level go last; ties keep their order.
function QuestTrackerSort.CompareQuests(a, b)
    if a.level ~= b.level then
        if a.level == nil then return false end
        if b.level == nil then return true end
        return a.level < b.level
    end
    return a.index < b.index
end

function QuestTrackerSort.GetSortedOrder(quests)
    local sorted = {}
    for i, quest in ipairs(quests) do
        sorted[i] = quest
    end
    table.sort(sorted, QuestTrackerSort.CompareQuests)
    return sorted
end

local function SortWatchList()
    if not IsEnabled() then return end
    if not (C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.AddQuestWatch and C_QuestLog.RemoveQuestWatch) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        pendingCombatSort = true
        return
    end

    local quests = GetWatchedQuests()
    local sorted = QuestTrackerSort.GetSortedOrder(quests)

    local lastMismatch
    for i = #sorted, 1, -1 do
        if quests[i].questID ~= sorted[i].questID then
            lastMismatch = i
            break
        end
    end
    if not lastMismatch then
        lastAttemptedOrder = nil
        return
    end

    local signature = GetOrderSignature(quests)
    if signature == lastAttemptedOrder then return end
    lastAttemptedOrder = signature

    -- Untracking the super-tracked quest can clear the waypoint; put it back.
    local superTrackedQuestID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()

    -- Quests after the last mismatch are already in place. Re-adding the rest
    -- highest level first leaves the lowest level on top.
    for i = lastMismatch, 1, -1 do
        C_QuestLog.RemoveQuestWatch(sorted[i].questID)
    end
    for i = lastMismatch, 1, -1 do
        C_QuestLog.AddQuestWatch(sorted[i].questID)
    end

    if IsUsable(superTrackedQuestID) and superTrackedQuestID ~= 0
        and C_SuperTrack.SetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() ~= superTrackedQuestID
    then
        C_SuperTrack.SetSuperTrackedQuestID(superTrackedQuestID)
    end
end

local function ScheduleSort()
    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("QuestTrackerSort:update", UPDATE_DELAY, SortWatchList)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(UPDATE_DELAY, SortWatchList)
    else
        SortWatchList()
    end
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not pendingCombatSort then return end
        pendingCombatSort = false
    end
    ScheduleSort()
end)

-- Blizzard re-sorts the watch list itself on zone and subzone changes.
local hookedBlizzardSort = false
local function HookBlizzardSort()
    if hookedBlizzardSort or not (C_QuestLog and C_QuestLog.SortQuestWatches) then return end
    hookedBlizzardSort = true
    hooksecurefunc(C_QuestLog, "SortQuestWatches", function()
        if not IsEnabled() then return end
        lastAttemptedOrder = nil
        ScheduleSort()
    end)
end

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    HookBlizzardSort()
    lastAttemptedOrder = nil
    ScheduleSort()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    pendingCombatSort = false
    lastAttemptedOrder = nil
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
