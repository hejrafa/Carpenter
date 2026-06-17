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
MAX_QUESTWATCH_LINES = 8
QUEST_WATCH_TOO_MANY = "You can only watch %d quests."
COMPLETE = "Complete"

local quests = {
    [1] = {
        questID = 101,
        title = "Report to Goldshire",
        objectives = 0,
        objectiveText = "Speak with Marshal Dughan in Goldshire.",
        complete = false,
    },
    [2] = {
        questID = 202,
        title = "Kobold Candles",
        objectives = 2,
        objectiveText = "Collect candles from kobold workers.",
        complete = false,
        leaderboards = {
            { text = "Kobold Workers slain: 8/8", finished = true },
            { text = "Candles collected: 4/4", finished = true },
        },
    },
}

local function CreateMockRegion()
    local region = {
        text = "",
        shown = false,
        width = 230,
        height = 13,
        color = nil,
        points = {},
    }

    function region:SetText(text) self.text = text or "" end
    function region:GetText() return self.text end
    function region:SetTextColor(r, g, b) self.color = { r = r, g = g, b = b } end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:SetWidth(width) self.width = width end
    function region:GetWidth() return self.width end
    function region:SetHeight(height) self.height = height end
    function region:GetHeight() return self.height end
    function region:GetStringWidth() return #(self.text or "") * 6 end
    function region:GetStringHeight()
        local lines = 1
        for _ in tostring(self.text or ""):gmatch("\n") do
            lines = lines + 1
        end
        return lines * 13
    end
    function region:SetMaxLines() end
    function region:SetWordWrap() end
    function region:SetNonSpaceWrap() end
    function region:SetJustifyH() end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(...) self.points[#self.points + 1] = { ... } end

    return region
end

local function CreateMockFrame()
    local frame = CreateMockRegion()
    function frame:SetHeight(height) self.height = height end
    function frame:SetWidth(width) self.width = width end
    return frame
end

QuestWatchFrame = CreateMockFrame()
QuestWatchQuestName = CreateMockRegion()
for index = 1, MAX_QUESTWATCH_LINES do
    _G["QuestWatchLine" .. index] = CreateMockRegion()
end

local function ResetQuestWatchLines()
    for index = 1, MAX_QUESTWATCH_LINES do
        local line = _G["QuestWatchLine" .. index]
        line:SetText("")
        line:Hide()
        line.color = nil
        line._CarpenterQuestWatchFallbackLine = nil
        line._CarpenterQuestWatchCompleteLine = nil
        line._CarpenterQuestWatchGapBefore = nil
        line._CarpenterQuestWatchOffsetX = nil
        line._CarpenterQuestWatchRawText = nil
        line._CarpenterQuestWatchWrappedText = nil
    end
    QuestWatchFrame:Hide()
end

local function ShowQuestWatchLine(index, text)
    local line = _G["QuestWatchLine" .. index]
    line:SetText(text)
    line:Show()
    return line
end

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
    return quest.title, nil, nil, quest.isHeader, nil, quest.complete == true, nil, quest.questID
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

function GetQuestLogLeaderBoard(objectiveIndex, questIndex)
    local quest = quests[questIndex]
    local objective = quest and quest.leaderboards and quest.leaderboards[objectiveIndex]
    if not objective then return nil, nil, nil end
    return objective.text, "object", objective.finished == true
end

function IsQuestComplete(questID)
    for _, quest in pairs(quests) do
        if quest.questID == questID then
            return quest.complete == true
        end
    end
    return false
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

    do
        ResetQuestWatchLines()
        questWatchIndexes = { 2 }
        quests[2].complete = true
        ShowQuestWatchLine(1, quests[2].title)
        ShowQuestWatchLine(2, " - Kobold Workers slain: 8/8")
        ShowQuestWatchLine(3, " - Candles collected: 4/4")

        ns.Private.AutoTrackQuestLayout.UpdateQuestWatchLayout()

        local completeLine = _G.QuestWatchLine2
        local hiddenObjectiveLine = _G.QuestWatchLine3
        if completeLine:GetText() ~= "Complete" then
            failures[#failures + 1] = "complete native watch: expected Complete line, got " .. tostring(completeLine:GetText())
        end
        if not (completeLine.color and completeLine.color.r == 0 and completeLine.color.g == 1 and completeLine.color.b == 0) then
            failures[#failures + 1] = "complete native watch: expected green Complete line"
        end
        if hiddenObjectiveLine:IsShown() then
            failures[#failures + 1] = "complete native watch: expected extra objective line to be hidden"
        end
    end

    do
        ResetQuestWatchLines()
        questWatchIndexes = {}
        CarpenterDB.noObjectiveQuestWatches = nil
        CarpenterDB.autoTrackQuestWatches = nil
        quests[1].objectives = 0
        quests[1].complete = true
        selectedQuestIndex = 0

        fire("QUEST_ACCEPTED", 1, 101)

        local titleLine = _G.QuestWatchLine1
        local completeLine = _G.QuestWatchLine2
        if titleLine:GetText() ~= "Report to Goldshire" then
            failures[#failures + 1] = "complete fallback watch: expected quest title line, got " .. tostring(titleLine:GetText())
        end
        if completeLine:GetText() ~= "Complete" then
            failures[#failures + 1] = "complete fallback watch: expected Complete line, got " .. tostring(completeLine:GetText())
        end
        if not (completeLine:IsShown() and completeLine.color and completeLine.color.r == 0 and completeLine.color.g == 1 and completeLine.color.b == 0) then
            failures[#failures + 1] = "complete fallback watch: expected visible green Complete line"
        end
    end
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("auto-track quest fixtures: 6 passed")
