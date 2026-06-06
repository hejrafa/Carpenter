#!/usr/bin/env lua
-- Offline fixture checks for Auto Track Quests watch state and fallback flow.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

unpack = unpack or table.unpack
tinsert = table.insert
tremove = table.remove

local ns = { Private = {} }
local failures = {}
local createdFrames = {}
local questWatchIndexes = {}
local questWatchUpdates = 0
local questLogUpdates = 0
local selectedQuestIndex = 0
local shiftDown = false

CarpenterDB = {}
Carpenter = {
    IsEnabled = function(_, key) return key == "autoTrackQuestsEnabled" end,
    After = function(_, _, callback) callback() end,
}

MAX_WATCHABLE_QUESTS = 5
QUEST_WATCH_TOO_MANY = "You can only watch %d quests."

local quests = {
    [1] = {
        questID = 101,
        title = "Report to Goldshire",
        objectives = 0,
        objectiveText = "Speak with Marshal Dughan in Goldshire.",
    },
}

local function loadAddonFile(path)
    local chunk, err = loadfile(repo .. "/" .. path)
    if not chunk then error(err) end
    return chunk("Carpenter", ns)
end

function CreateFrame()
    local frame = { events = {}, _scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(script, handler) self._scripts[script] = handler end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

function hooksecurefunc(target, method, handler)
    if type(target) == "table" then
        local original = target[method]
        if type(original) ~= "function" then return end
        target[method] = function(...)
            local results = { original(...) }
            handler(...)
            return unpack(results)
        end
        return
    end

    handler = method
    local original = _G[target]
    if type(original) ~= "function" then return end
    _G[target] = function(...)
        local results = { original(...) }
        handler(...)
        return unpack(results)
    end
end

function GetNumQuestLogEntries()
    return #quests
end

function GetQuestLogTitle(index)
    local quest = quests[index]
    if not quest then return nil end
    return quest.title, nil, nil, quest.isHeader, nil, nil, nil, quest.questID
end

function GetNumQuestLeaderBoards(index)
    local quest = quests[index]
    return quest and quest.objectives or 0
end

function GetQuestLogSelection()
    return selectedQuestIndex
end

function SelectQuestLogEntry(index)
    selectedQuestIndex = index
end

function GetQuestLogQuestText()
    local quest = quests[selectedQuestIndex]
    return nil, quest and quest.objectiveText or nil
end

function GetTitleText()
    return quests[1] and quests[1].title
end

function GetNumQuestWatches()
    return #questWatchIndexes
end

function GetQuestIndexForWatch(watchIndex)
    return questWatchIndexes[watchIndex]
end

function IsQuestWatched(index)
    for _, watchedIndex in ipairs(questWatchIndexes) do
        if watchedIndex == index then return true end
    end
    return false
end

function AddQuestWatch(index)
    for _, watchedIndex in ipairs(questWatchIndexes) do
        if watchedIndex == index then return end
    end
    questWatchIndexes[#questWatchIndexes + 1] = index
end

function RemoveQuestWatch(index)
    for watchIndex = #questWatchIndexes, 1, -1 do
        if questWatchIndexes[watchIndex] == index then
            table.remove(questWatchIndexes, watchIndex)
        end
    end
end

function QuestWatch_Update()
    questWatchUpdates = questWatchUpdates + 1
end

function QuestLog_Update()
    questLogUpdates = questLogUpdates + 1
end

function WatchFrame_Update() end
function ObjectiveTracker_Update() end
function UIParent_ManageFramePositions() end
function IsShiftKeyDown() return shiftDown end

UIErrorsFrame = { AddMessage = function() end }

loadAddonFile("Modules/AutoTrackQuests/AutoTrackQuestState.lua")
loadAddonFile("Modules/AutoTrackQuests/AutoTrackQuestLayout.lua")
loadAddonFile("Modules/AutoTrackQuests/AutoTrackQuests.lua")

local frame = createdFrames[1]
if not frame or type(frame._scripts.OnEvent) ~= "function" then
    failures[#failures + 1] = "auto track frame: event handler was not registered"
end

local function fire(event, ...)
    frame._scripts.OnEvent(frame, event, ...)
end

if #failures == 0 then
    fire("QUEST_ACCEPTED", 1, 101)

    local fallbackState = CarpenterDB.noObjectiveQuestWatches
    local fallbackWatch = fallbackState and fallbackState.quests and fallbackState.quests["101"]
    if not fallbackWatch then
        failures[#failures + 1] = "no-objective fallback: expected fallback watch for quest 101"
    elseif fallbackWatch.objectiveText ~= "Speak with Marshal Dughan in Goldshire." then
        failures[#failures + 1] = "no-objective fallback: unexpected objective text " .. tostring(fallbackWatch.objectiveText)
    end
    if #questWatchIndexes ~= 0 then
        failures[#failures + 1] = "no-objective fallback: expected no native watch while quest has no objectives"
    end

    quests[1].objectives = 1
    fire("QUEST_LOG_UPDATE")

    if #questWatchIndexes ~= 1 or questWatchIndexes[1] ~= 1 then
        failures[#failures + 1] = "native promotion: expected quest index 1 to be watched"
    end
    fallbackState = CarpenterDB.noObjectiveQuestWatches
    if fallbackState and fallbackState.quests and fallbackState.quests["101"] then
        failures[#failures + 1] = "native promotion: expected fallback watch to be removed"
    end

    local nativeState = CarpenterDB.autoTrackQuestWatches
    if not (nativeState and nativeState.quests and nativeState.quests["101"]) then
        failures[#failures + 1] = "native promotion: expected remembered native watch for quest 101"
    end

    RemoveQuestWatch(1)
    if #questWatchIndexes ~= 1 or questWatchIndexes[1] ~= 1 then
        failures[#failures + 1] = "auto restore: expected non-manual removal to restore native watch"
    end

    shiftDown = true
    RemoveQuestWatch(1)
    shiftDown = false

    if #questWatchIndexes ~= 0 then
        failures[#failures + 1] = "manual removal: expected Shift removal to keep quest unwatched"
    end
    nativeState = CarpenterDB.autoTrackQuestWatches
    if nativeState and nativeState.quests and nativeState.quests["101"] then
        failures[#failures + 1] = "manual removal: expected native watch state to be forgotten"
    end

    if questWatchUpdates == 0 or questLogUpdates == 0 then
        failures[#failures + 1] = "tracker refresh: expected quest watch and quest log refreshes"
    end
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("auto-track quest fixtures: 4 passed")
