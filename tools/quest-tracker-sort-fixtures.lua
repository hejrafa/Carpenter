#!/usr/bin/env lua
-- Verifies Sort Quests by Level reorders the Forever watch list safely.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local inCombat = false
local keepsInsertionOrder = true
local watchList = {}
local watchChanges = 0
local superTrackedQuestID = 0
local eventFrame
local deferred = {}

local questLevels = {
    [101] = 12,
    [102] = 8,
    [103] = 10,
    [104] = 8,
    [105] = 15,
}

local function RemoveFromList(questID)
    for i, id in ipairs(watchList) do
        if id == questID then
            table.remove(watchList, i)
            return true
        end
    end
    return false
end

C_QuestLog = {
    GetNumQuestWatches = function() return #watchList end,
    GetQuestIDForQuestWatchIndex = function(index) return watchList[index] end,
    GetLogIndexForQuestID = function(questID) return questLevels[questID] and questID or nil end,
    GetInfo = function(logIndex)
        return { questID = logIndex, difficultyLevel = questLevels[logIndex], level = questLevels[logIndex] }
    end,
    RemoveQuestWatch = function(questID)
        watchChanges = watchChanges + 1
        if superTrackedQuestID == questID then superTrackedQuestID = 0 end
        return RemoveFromList(questID)
    end,
    AddQuestWatch = function(questID)
        watchChanges = watchChanges + 1
        RemoveFromList(questID)
        -- Forever puts a newly watched quest at the top.
        table.insert(watchList, 1, questID)
        if not keepsInsertionOrder then
            table.sort(watchList)
        end
        return true
    end,
}
-- Stand-in for Blizzard's zone-change sort: any order that is not ours.
C_QuestLog.SortQuestWatches = function()
    table.sort(watchList, function(a, b) return a > b end)
end
function hooksecurefunc(target, name, hook)
    local original = target[name]
    target[name] = function(...)
        original(...)
        hook(...)
    end
end

C_SuperTrack = {
    GetSuperTrackedQuestID = function() return superTrackedQuestID end,
    SetSuperTrackedQuestID = function(questID) superTrackedQuestID = questID end,
}

function InCombatLockdown() return inCombat end
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, handler) self.handler = handler end
    eventFrame = frame
    return frame
end

CarpenterDB = { sortQuestsByLevelEnabled = true }
Carpenter = {
    Features = {},
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(self, key, feature) self.Features[key] = feature end,
    Defer = function(_, key, _, callback) deferred[key] = callback end,
}

local function Flush()
    while next(deferred) do
        local key, callback = next(deferred)
        deferred[key] = nil
        callback()
    end
end

local function Fire(event)
    if eventFrame.events[event] then
        eventFrame.handler(eventFrame, event)
    end
    Flush()
end

local ns = { Private = {} }
local chunk = assert(loadfile(repo .. "/Modules/QuestTrackerSort.lua"))
chunk("Carpenter", ns)

local feature = Carpenter.Features.sortQuestsByLevelEnabled
assert(feature, "feature should register")

local function Order()
    return table.concat(watchList, ",")
end

-- Sorts lowest level first and keeps ties in their tracked order.
watchList = { 101, 104, 103, 102, 105 }
superTrackedQuestID = 103
feature:Enable()
Flush()
assert(Order() == "104,102,103,101,105", "expected level order got " .. Order())
assert(superTrackedQuestID == 103, "super-tracked quest should be kept")

-- Already sorted: no watch changes.
watchChanges = 0
Fire("QUEST_WATCH_LIST_CHANGED")
assert(watchChanges == 0, "sorted list should not be touched")

-- Only quests up to the last out-of-place one are re-added.
watchList = { 103, 104, 102, 101, 105 }
watchChanges = 0
Fire("QUEST_ACCEPTED")
assert(Order() == "104,102,103,101,105", "expected level order got " .. Order())
assert(watchChanges == 6, "expected 3 quests re-added got " .. watchChanges .. " changes")

-- Blizzard's own re-sort on zone change gets sorted back.
C_QuestLog.SortQuestWatches()
assert(Order() == "105,104,103,102,101", "fixture sort should scramble the list")
Flush()
assert(Order() == "104,102,103,101,105", "expected level order after Blizzard sort got " .. Order())

-- Combat waits for PLAYER_REGEN_ENABLED.
watchList = { 105, 104 }
inCombat = true
Fire("QUEST_WATCH_LIST_CHANGED")
assert(Order() == "105,104", "should not reorder in combat")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
assert(Order() == "104,105", "should reorder after combat got " .. Order())

-- A client that ignores insertion order must not cause an endless re-add loop.
keepsInsertionOrder = false
watchList = { 101, 102 }
watchChanges = 0
Fire("QUEST_WATCH_LIST_CHANGED")
local firstAttempt = watchChanges
Fire("QUEST_WATCH_LIST_CHANGED")
Fire("QUEST_WATCH_LIST_CHANGED")
assert(watchChanges == firstAttempt, "should give up after one failed attempt")
keepsInsertionOrder = true

-- Disabled: nothing happens.
CarpenterDB.sortQuestsByLevelEnabled = false
feature:Disable()
watchList = { 105, 104 }
assert(not eventFrame.events.QUEST_WATCH_LIST_CHANGED, "events should unregister")

print("quest tracker sort fixtures passed")
