--[[ Carpenter - Auto Track Quests state helpers ]]
-- Shared quest-log, saved-state, and native-watch helpers for AutoTrackQuests.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local State = ns.Private.AutoTrackQuestState or {}
ns.Private.AutoTrackQuestState = State

local fallbackMemory = { order = {}, quests = {} }
local nativeWatchMemory = { order = {}, quests = {} }

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

local function CleanQuestText(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    return text
end

local function GetFallbackState()
    if type(CarpenterDB) ~= "table" then
        return fallbackMemory
    end

    local state = CarpenterDB.noObjectiveQuestWatches
    if type(state) ~= "table" then
        state = {}
        CarpenterDB.noObjectiveQuestWatches = state
    end
    if type(state.order) ~= "table" then
        state.order = {}
    end
    if type(state.quests) ~= "table" then
        state.quests = {}
    end

    return state
end

local function GetNativeWatchState()
    if type(CarpenterDB) ~= "table" then
        return nativeWatchMemory
    end

    local state = CarpenterDB.autoTrackQuestWatches
    if type(state) ~= "table" then
        state = {}
        CarpenterDB.autoTrackQuestWatches = state
    end
    if type(state.order) ~= "table" then
        state.order = {}
    end
    if type(state.quests) ~= "table" then
        state.quests = {}
    end

    return state
end

local function MakeQuestKey(questID, questName)
    if questID and questID > 0 then
        return tostring(questID)
    end
    questName = CleanQuestText(questName)
    if questName then
        return "name:" .. questName
    end
end

local function GetQuestDisplayTitle(index, fallbackTitle)
    if not index then
        return CleanQuestText(fallbackTitle)
    end

    local _, title = GetQuestInfo(index)
    return CleanQuestText(title) or CleanQuestText(fallbackTitle)
end

local function RemoveQuestStateEntry(state, key)
    if not state or not key then return false end

    local removed = false
    if state.quests and state.quests[key] ~= nil then
        state.quests[key] = nil
        removed = true
    end
    if type(state.order) == "table" then
        for index = #state.order, 1, -1 do
            if state.order[index] == key then
                tremove(state.order, index)
                removed = true
            end
        end
    end

    return removed
end

local function RemoveQuestWatchFromState(state, questID, questName)
    local key = MakeQuestKey(questID, questName)
    local removed = RemoveQuestStateEntry(state, key)

    if questID and questID > 0 and questName then
        removed = RemoveQuestStateEntry(state, MakeQuestKey(nil, questName)) or removed
    end

    return removed
end

local function RememberNativeQuestWatch(index, questID, questName)
    local logQuestID, title, isHeader
    if index then
        logQuestID, title, isHeader = GetQuestInfo(index)
        if isHeader then return false end
    end

    questID = questID or logQuestID
    questName = GetQuestDisplayTitle(index, questName or title)

    local key = MakeQuestKey(questID, questName)
    if not key then return false end

    local state = GetNativeWatchState()
    if not state.quests[key] then
        tinsert(state.order, key)
    end

    state.quests[key] = {
        questID = questID,
        title = questName,
    }

    return true
end

local function RemoveNativeQuestWatch(questID, questName)
    return RemoveQuestWatchFromState(GetNativeWatchState(), questID, questName)
end

local function GetQuestObjectiveText(index)
    if not index or not GetQuestLogQuestText then return nil end

    local selectedIndex = GetQuestLogSelection and GetQuestLogSelection()
    if SelectQuestLogEntry then
        SelectQuestLogEntry(index)
    end

    local _, objectives = GetQuestLogQuestText()
    text = CleanQuestText(objectives)

    if selectedIndex ~= nil and SelectQuestLogEntry then
        SelectQuestLogEntry(selectedIndex)
        if selectedIndex > 0 and QuestLogFrame and QuestLogFrame:IsVisible() and QuestLog_UpdateQuestDetails then
            QuestLog_UpdateQuestDetails(1)
        end
    end

    return text
end

local function GetNumQuestObjectives(index)
    if GetNumQuestLeaderBoards and index then
        return GetNumQuestLeaderBoards(index) or 0
    end
    return nil
end

local function QuestHasTrackableObjectives(index)
    local numObjectives = GetNumQuestObjectives(index)
    if numObjectives == nil then return true end
    return numObjectives > 0
end

local function IsQuestCurrentlyWatched(index, questID)
    if C_QuestLog and C_QuestLog.IsQuestWatched and questID then
        local ok, watched = pcall(C_QuestLog.IsQuestWatched, questID)
        if ok and watched ~= nil then
            return watched == true
        end
    end

    if IsQuestWatched and index then
        local watched = IsQuestWatched(index)
        return watched == true or watched == 1
    end

    if GetNumQuestWatches and GetQuestIndexForWatch and index then
        for watchIndex = 1, GetNumQuestWatches() do
            if GetQuestIndexForWatch(watchIndex) == index then
                return true
            end
        end
    end

    return false
end

local function CanAddNativeQuestWatch(index, questID)
    if IsQuestCurrentlyWatched(index, questID) then return true end
    if GetNumQuestWatches then
        local maxWatches = MAX_WATCHABLE_QUESTS or 5
        return (GetNumQuestWatches() or 0) < maxWatches
    end
    return true
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

local function IsFallbackQuestWatched(questID, questName)
    local key = MakeQuestKey(questID, questName)
    local state = GetFallbackState()
    return key and state.quests[key] ~= nil
end

local function RemoveFallbackQuestWatch(questID, questName)
    return RemoveQuestWatchFromState(GetFallbackState(), questID, questName)
end

local function GetNumNativeQuestWatches()
    if GetNumQuestWatches then
        return GetNumQuestWatches() or 0
    end
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        return C_QuestLog.GetNumQuestWatches() or 0
    end
    return 0
end

local function HasQuestWatches()
    return GetNumNativeQuestWatches() > 0 or #GetFallbackState().order > 0
end

local function IsValidQuestLogIndex(index, questID, questName)
    if not index or index <= 0 or index > GetQuestLogSize() then return false end

    local logQuestID, title, isHeader = GetQuestInfo(index)
    if isHeader then return false end
    if questID and logQuestID and logQuestID ~= questID then return false end
    if questName and title and title ~= questName then return false end

    return true
end

local function RememberCurrentNativeQuestWatches()
    if not GetNumQuestWatches or not GetQuestIndexForWatch then return end

    for watchIndex = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(watchIndex)
        if questIndex and QuestHasTrackableObjectives(questIndex) then
            local questID, title, isHeader = GetQuestInfo(questIndex)
            if not isHeader then
                RememberNativeQuestWatch(questIndex, questID, title)
            end
        end
    end
end

local function RestoreNativeQuestWatches(addQuestToWatch)
    local state = GetNativeWatchState()
    local changed = false
    local index = 1

    while index <= #state.order do
        local key = state.order[index]
        local watch = state.quests[key]
        local questIndex = watch and FindQuestLogIndex(watch.questID, watch.title)

        if not watch or not questIndex then
            RemoveQuestStateEntry(state, key)
            changed = true
        elseif not QuestHasTrackableObjectives(questIndex) then
            index = index + 1
        else
            local logQuestID, title = GetQuestInfo(questIndex)
            watch.questID = watch.questID or logQuestID
            watch.title = GetQuestDisplayTitle(questIndex, title or watch.title)

            if not IsQuestCurrentlyWatched(questIndex, watch.questID) and addQuestToWatch and addQuestToWatch(questIndex, watch.questID, true) then
                changed = true
            end
            index = index + 1
        end
    end

    return changed
end

local function PruneFallbackQuestWatches(addQuestToWatch)
    local state = GetFallbackState()
    local changed = false
    local index = 1

    while index <= #state.order do
        local key = state.order[index]
        local watch = state.quests[key]
        local questIndex = watch and FindQuestLogIndex(watch.questID, watch.title)

        if not watch or not questIndex then
            if watch then
                state.quests[key] = nil
            end
            tremove(state.order, index)
            changed = true
        elseif QuestHasTrackableObjectives(questIndex) then
            local logQuestID, title = GetQuestInfo(questIndex)
            if addQuestToWatch and addQuestToWatch(questIndex, logQuestID or watch.questID, true) then
                RememberNativeQuestWatch(questIndex, logQuestID or watch.questID, title or watch.title)
            end
            state.quests[key] = nil
            tremove(state.order, index)
            changed = true
        else
            local logQuestID, title = GetQuestInfo(questIndex)
            watch.questID = watch.questID or logQuestID
            watch.title = GetQuestDisplayTitle(questIndex, title or watch.title)
            watch.objectiveText = GetQuestObjectiveText(questIndex) or watch.title
            index = index + 1
        end
    end

    return changed
end

State.GetQuestLogSize = GetQuestLogSize
State.GetQuestInfo = GetQuestInfo
State.CleanQuestText = CleanQuestText
State.GetFallbackState = GetFallbackState
State.GetNativeWatchState = GetNativeWatchState
State.MakeQuestKey = MakeQuestKey
State.GetQuestDisplayTitle = GetQuestDisplayTitle
State.RemoveQuestStateEntry = RemoveQuestStateEntry
State.RemoveQuestWatchFromState = RemoveQuestWatchFromState
State.RememberNativeQuestWatch = RememberNativeQuestWatch
State.RemoveNativeQuestWatch = RemoveNativeQuestWatch
State.GetQuestObjectiveText = GetQuestObjectiveText
State.GetNumQuestObjectives = GetNumQuestObjectives
State.QuestHasTrackableObjectives = QuestHasTrackableObjectives
State.IsQuestCurrentlyWatched = IsQuestCurrentlyWatched
State.CanAddNativeQuestWatch = CanAddNativeQuestWatch
State.FindQuestLogIndex = FindQuestLogIndex
State.IsFallbackQuestWatched = IsFallbackQuestWatched
State.RemoveFallbackQuestWatch = RemoveFallbackQuestWatch
State.GetNumNativeQuestWatches = GetNumNativeQuestWatches
State.HasQuestWatches = HasQuestWatches
State.IsValidQuestLogIndex = IsValidQuestLogIndex
State.RememberCurrentNativeQuestWatches = RememberCurrentNativeQuestWatches
State.RestoreNativeQuestWatches = RestoreNativeQuestWatches
State.PruneFallbackQuestWatches = PruneFallbackQuestWatches
