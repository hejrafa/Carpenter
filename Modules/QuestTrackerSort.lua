--[[ Carpenter - Quest Tracker Sort ]]
-- Orders tracked quests from lowest to highest level on WoW Forever.
-- Blizzard's tracker lists quests in watch-list order, so this reorders the
-- watch list itself instead of touching the tracker (which would taint it).
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

local function SortWatchList(force)
    if not force and not IsEnabled() then return end
    if not (C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.AddQuestWatch and C_QuestLog.RemoveQuestWatch) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        pendingCombatSort = true
        return
    end

    local quests = GetWatchedQuests()
    local sorted = QuestTrackerSort.GetSortedOrder(quests)

    local firstMismatch
    for i, quest in ipairs(sorted) do
        if quests[i].questID ~= quest.questID then
            firstMismatch = i
            break
        end
    end
    if not firstMismatch then
        lastAttemptedOrder = nil
        return
    end

    local signature = GetOrderSignature(quests)
    if not force and signature == lastAttemptedOrder then return end
    lastAttemptedOrder = signature

    -- Untracking the super-tracked quest can clear the waypoint; put it back.
    local superTrackedQuestID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()

    -- Quests before the first mismatch are already in place. Re-adding the rest
    -- appends them to the watch list in level order.
    local results = {}
    for i = firstMismatch, #sorted do
        results[#results + 1] = { questID = sorted[i].questID, removed = C_QuestLog.RemoveQuestWatch(sorted[i].questID) }
    end
    for i = firstMismatch, #sorted do
        results[i - firstMismatch + 1].added = C_QuestLog.AddQuestWatch(sorted[i].questID)
    end

    if IsUsable(superTrackedQuestID) and superTrackedQuestID ~= 0
        and C_SuperTrack.SetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() ~= superTrackedQuestID
    then
        C_SuperTrack.SetSuperTrackedQuestID(superTrackedQuestID)
    end

    return results
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

local function PrintWatchList(label)
    local parts = {}
    for _, quest in ipairs(GetWatchedQuests()) do
        parts[#parts + 1] = tostring(quest.level or "?") .. ":" .. tostring(quest.questID)
    end
    print("|cff00ccaaCarpenter|r " .. label .. " (" .. #parts .. "): " .. table.concat(parts, "  "))
end

-- /cpquestsort shows the watch list, tries one sort, and shows the result.
SLASH_CARPENTERQUESTSORT1 = "/cpquestsort"
SlashCmdList["CARPENTERQUESTSORT"] = function()
    print("|cff00ccaaCarpenter|r Sort Quests by Level enabled: " .. tostring(IsEnabled()))
    PrintWatchList("before")
    local results = SortWatchList(true)
    if not results then
        print("|cff00ccaaCarpenter|r already in level order (or in combat)")
        return
    end
    local parts = {}
    for _, result in ipairs(results) do
        parts[#parts + 1] = tostring(result.questID) .. " removed=" .. tostring(result.removed) .. " added=" .. tostring(result.added)
    end
    print("|cff00ccaaCarpenter|r calls: " .. table.concat(parts, ", "))
    PrintWatchList("right after")
    C_Timer.After(1, function() PrintWatchList("1s later") end)
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
