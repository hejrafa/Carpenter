--[[ Carpenter - AutoTrackQuests ]]
-- Automatically adds newly accepted quests to the objective tracker.

local frame = CreateFrame("Frame")

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("autoTrackQuestsEnabled")
end

local function GetQuestLogSize()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return C_QuestLog.GetNumQuestLogEntries()
    end
    if GetNumQuestLogEntries then
        return GetNumQuestLogEntries()
    end
    return 0
end

local function GetQuestInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(index)
        if info then
            return info.questID, info.title, info.isHeader
        end
    end

    if GetQuestLogTitle then
        local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
        return questID, title, isHeader
    end
end

local function FindQuestLogIndex(questID, questName)
    local numEntries = GetQuestLogSize()
    for index = 1, numEntries do
        local logQuestID, title, isHeader = GetQuestInfo(index)
        if not isHeader then
            if questID and logQuestID == questID then
                return index
            end
            if questName and title == questName then
                return index
            end
        end
    end
end

local function RefreshQuestTracker()
    if C_QuestLog and C_QuestLog.RefreshQuestWatch then
        C_QuestLog.RefreshQuestWatch()
    end
    if QuestWatch_Update then
        QuestWatch_Update()
    end
    if WatchFrame_Update then
        WatchFrame_Update()
    end
    if ObjectiveTracker_Update then
        ObjectiveTracker_Update()
    end
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
    end
    if QuestLog_Update then
        QuestLog_Update()
    end
end

local function IsValidQuestLogIndex(index, questID, questName)
    if not index or index <= 0 or index > GetQuestLogSize() then return false end

    local logQuestID, title, isHeader = GetQuestInfo(index)
    if isHeader then return false end
    if questID and logQuestID and logQuestID ~= questID then return false end
    if questName and title and title ~= questName then return false end

    return true
end

local function AddQuestToWatch(index, questID)
    if C_QuestLog and C_QuestLog.AddQuestWatch and questID then
        C_QuestLog.AddQuestWatch(questID)
        RefreshQuestTracker()
        return true
    end

    if AddQuestWatch and index then
        AddQuestWatch(index)
        RefreshQuestTracker()
        return true
    end

    return false
end

local function TrackQuest(questLogIndex, questID, questName)
    if not IsEnabled() then return end

    if questID and AddQuestToWatch(nil, questID) then
        return
    end

    local index = questLogIndex
    if not IsValidQuestLogIndex(index, questID, questName) then
        index = FindQuestLogIndex(questID, questName)
    end

    AddQuestToWatch(index, questID)
end

frame:RegisterEvent("QUEST_ACCEPTED")
frame:SetScript("OnEvent", function(_, _, questLogIndex, questID)
    local questName = GetTitleText and GetTitleText()
    if Carpenter and Carpenter.After then
        Carpenter:After(0, function()
            TrackQuest(questLogIndex, questID, questName)
        end)
    else
        TrackQuest(questLogIndex, questID, questName)
    end
end)
