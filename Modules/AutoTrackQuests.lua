--[[ Carpenter - AutoTrackQuests ]]
-- Automatically adds newly accepted quests to the objective tracker.

local frame = CreateFrame("Frame")
local fallbackMemory = { order = {}, quests = {} }
local nativeWatchMemory = { order = {}, quests = {} }
local hookedQuestWatchUpdate = false
local hookedQuestLogUpdate = false
local originalQuestLogTitleButton_OnClick = nil
local AddQuestToWatch

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
    local key = MakeQuestKey(questID, questName)
    return RemoveQuestStateEntry(GetNativeWatchState(), key)
end

local function GetQuestObjectiveText(index, fallbackText)
    local text = CleanQuestText(fallbackText)
    if text then return text end

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
    local key = MakeQuestKey(questID, questName)
    return RemoveQuestStateEntry(GetFallbackState(), key)
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

local function SafeRegisterEvent(event)
    pcall(frame.RegisterEvent, frame, event)
end

local function AddFallbackQuestWatch(index, questID, questName, objectiveText, quiet)
    if not index then return false end

    local logQuestID, title, isHeader = GetQuestInfo(index)
    if isHeader then return false end

    questID = questID or logQuestID
    questName = GetQuestDisplayTitle(index, questName)

    local key = MakeQuestKey(questID, questName)
    if not key then return false end

    objectiveText = GetQuestObjectiveText(index, objectiveText) or questName
    objectiveText = CleanQuestText(objectiveText)
    if not objectiveText then return false end

    local state = GetFallbackState()
    if not state.quests[key] then
        local maxWatches = MAX_WATCHABLE_QUESTS or 5
        local nativeWatches = GetNumQuestWatches and GetNumQuestWatches() or 0
        if (nativeWatches + #state.order) >= maxWatches then
            if not quiet and UIErrorsFrame and QUEST_WATCH_TOO_MANY then
                UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, maxWatches), 1.0, 0.1, 0.1, 1.0)
            end
            return false
        end
        tinsert(state.order, key)
    end

    state.quests[key] = {
        questID = questID,
        title = questName,
        objectiveText = objectiveText,
    }

    RefreshQuestTracker()
    return true
end

local function PruneFallbackQuestWatches()
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
            if AddQuestToWatch and AddQuestToWatch(questIndex, logQuestID or watch.questID, true) then
                RememberNativeQuestWatch(questIndex, logQuestID or watch.questID, title or watch.title)
            end
            state.quests[key] = nil
            tremove(state.order, index)
            changed = true
        else
            local logQuestID, title = GetQuestInfo(questIndex)
            watch.questID = watch.questID or logQuestID
            watch.title = GetQuestDisplayTitle(questIndex, title or watch.title)
            watch.objectiveText = GetQuestObjectiveText(questIndex, watch.objectiveText) or watch.objectiveText
            index = index + 1
        end
    end

    return changed
end

local function IsValidQuestLogIndex(index, questID, questName)
    if not index or index <= 0 or index > GetQuestLogSize() then return false end

    local logQuestID, title, isHeader = GetQuestInfo(index)
    if isHeader then return false end
    if questID and logQuestID and logQuestID ~= questID then return false end
    if questName and title and title ~= questName then return false end

    return true
end

AddQuestToWatch = function(index, questID, skipRefresh)
    if index and not QuestHasTrackableObjectives(index) then
        return false
    end

    if not CanAddNativeQuestWatch(index, questID) then
        return false
    end

    local function Finish()
        if not skipRefresh then
            RefreshQuestTracker()
        end
        return true
    end

    if IsQuestCurrentlyWatched(index, questID) then
        return Finish()
    end

    if C_QuestLog and C_QuestLog.AddQuestWatch and questID then
        local watched = C_QuestLog.AddQuestWatch(questID)
        if watched ~= false then
            return Finish()
        end
    end

    if AddQuestWatch and index then
        AddQuestWatch(index)
        return Finish()
    end

    return false
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

local function RestoreNativeQuestWatches()
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

            if not IsQuestCurrentlyWatched(questIndex, watch.questID) and AddQuestToWatch(questIndex, watch.questID, true) then
                changed = true
            end
            index = index + 1
        end
    end

    return changed
end

local function GetNativeQuestWatchLineIndex()
    local watchTextIndex = 1
    if not GetNumQuestWatches or not GetQuestIndexForWatch then
        return watchTextIndex
    end

    for index = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(index)
        local numObjectives = GetNumQuestObjectives(questIndex) or 0
        if questIndex and numObjectives > 0 then
            watchTextIndex = watchTextIndex + 1 + numObjectives
        end
    end

    return watchTextIndex
end

local function SetQuestWatchLine(lineIndex, text, r, g, b, gapBefore)
    local line = _G["QuestWatchLine" .. lineIndex]
    if not line then return nil end

    line:ClearAllPoints()
    if lineIndex == 1 then
        line:SetPoint("TOPLEFT", QuestWatchQuestName or QuestWatchFrame, QuestWatchQuestName and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
    else
        line:SetPoint("TOPLEFT", _G["QuestWatchLine" .. (lineIndex - 1)], "BOTTOMLEFT", 0, gapBefore and -4 or 0)
    end

    line:SetText(text)
    line:SetTextColor(r, g, b)
    line:Show()

    if line.GetStringWidth then
        return line:GetStringWidth()
    end
    return line:GetWidth()
end

local function GetCurrentQuestWatchWidth(lastNativeLine)
    local maxWidth = 0
    for index = 1, lastNativeLine do
        local line = _G["QuestWatchLine" .. index]
        if line and line:IsShown() then
            local width = line.GetStringWidth and line:GetStringWidth() or line:GetWidth()
            if width and width > maxWidth then
                maxWidth = width
            end
        end
    end
    return maxWidth
end

local function PositionQuestLogWatchCheck(row, button, check, title)
    local normalText = _G["QuestLogTitle" .. row .. "NormalText"]
    local displayText = button.GetText and button:GetText() or title
    local textWidth

    displayText = CleanQuestText(displayText)
    if displayText then
        displayText = "  " .. displayText
    else
        displayText = "  " .. (title or "")
    end

    if QuestLogDummyText then
        QuestLogDummyText:SetText(displayText)
        textWidth = QuestLogDummyText:GetWidth()
    elseif button.GetTextWidth then
        textWidth = button:GetTextWidth()
    end

    if textWidth and textWidth + 24 < 275 then
        check:SetPoint("LEFT", button, "LEFT", textWidth + 24, 0)
    elseif normalText then
        check:SetPoint("LEFT", normalText, "LEFT", normalText:GetWidth(), 0)
    else
        check:SetPoint("LEFT", button, "LEFT", (textWidth or 0) + 24, 0)
    end
end

local function RenderFallbackQuestWatches()
    if not IsEnabled() or not QuestWatchFrame then return end

    local state = GetFallbackState()
    if #state.order == 0 then return end

    local maxLines = MAX_QUESTWATCH_LINES or 30
    local lineIndex = GetNativeQuestWatchLineIndex()
    local maxWidth = GetCurrentQuestWatchWidth(lineIndex - 1)
    local rendered = 0

    for _, key in ipairs(state.order) do
        local watch = state.quests[key]
        local questIndex = watch and FindQuestLogIndex(watch.questID, watch.title)
        if watch and questIndex and not QuestHasTrackableObjectives(questIndex) and lineIndex + 1 <= maxLines then
            watch.title = GetQuestDisplayTitle(questIndex, watch.title)
            local titleWidth = SetQuestWatchLine(lineIndex, watch.title or "", 0.75, 0.61, 0, lineIndex > 1)
            if titleWidth and titleWidth > maxWidth then
                maxWidth = titleWidth
            end
            lineIndex = lineIndex + 1

            local objective = " - " .. (watch.objectiveText or watch.title or "")
            local objectiveWidth = SetQuestWatchLine(lineIndex, objective, 0.8, 0.8, 0.8, false)
            if objectiveWidth and objectiveWidth > maxWidth then
                maxWidth = objectiveWidth
            end
            lineIndex = lineIndex + 1
            rendered = rendered + 1
        end
    end

    if rendered == 0 then return end

    for index = lineIndex, maxLines do
        local line = _G["QuestWatchLine" .. index]
        if line then
            line:Hide()
        end
    end

    QuestWatchFrame:Show()
    QuestWatchFrame:SetHeight(lineIndex * 13)
    QuestWatchFrame:SetWidth(maxWidth + 10)

    if QuestLogTrackTracking then
        QuestLogTrackTracking:SetVertexColor(0, 1.0, 0)
    end
    if UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end
end

local function UpdateQuestLogWatchIndicators()
    if not IsEnabled() then return end

    local offset = QuestLogListScrollFrame and FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
    local displayed = QUESTS_DISPLAYED or 6

    for row = 1, displayed do
        local button = _G["QuestLogTitle" .. row]
        local check = _G["QuestLogTitle" .. row .. "Check"]
        if button and check and button:IsShown() then
            local questIndex = row + offset
            local questID, title, isHeader = GetQuestInfo(questIndex)
            if not isHeader and IsFallbackQuestWatched(questID, title) then
                PositionQuestLogWatchCheck(row, button, check, title)
                check:Show()
            end
        end
    end

    if QuestLogTrackTracking and #GetFallbackState().order > 0 then
        QuestLogTrackTracking:SetVertexColor(0, 1.0, 0)
    end
end

local function HookQuestWatchUpdates()
    if not hookedQuestWatchUpdate and hooksecurefunc and QuestWatch_Update then
        hooksecurefunc("QuestWatch_Update", RenderFallbackQuestWatches)
        hookedQuestWatchUpdate = true
    end

    if not hookedQuestLogUpdate and hooksecurefunc and QuestLog_Update then
        hooksecurefunc("QuestLog_Update", UpdateQuestLogWatchIndicators)
        hookedQuestLogUpdate = true
    end

    if not originalQuestLogTitleButton_OnClick and QuestLogTitleButton_OnClick then
        originalQuestLogTitleButton_OnClick = QuestLogTitleButton_OnClick
        QuestLogTitleButton_OnClick = function(self, button)
            local nativeQuestIndex, nativeQuestID, nativeQuestTitle, wasNativeWatched

            if IsEnabled() and IsShiftKeyDown() and self and not self.isHeader then
                if not (IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) then
                    local offset = QuestLogListScrollFrame and FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
                    local questIndex = self:GetID() + offset
                    if questIndex and QuestHasTrackableObjectives(questIndex) then
                        nativeQuestIndex = questIndex
                        nativeQuestID, nativeQuestTitle = GetQuestInfo(questIndex)
                        wasNativeWatched = IsQuestCurrentlyWatched(questIndex, nativeQuestID)
                    elseif questIndex then
                        local questID, title = GetQuestInfo(questIndex)
                        if IsFallbackQuestWatched(questID, title) then
                            RemoveFallbackQuestWatch(questID, title)
                            RefreshQuestTracker()
                        else
                            AddFallbackQuestWatch(questIndex, questID, title, nil, false)
                        end
                        if QuestLog_SetSelection then
                            QuestLog_SetSelection(questIndex)
                        end
                        if QuestLog_Update then
                            QuestLog_Update()
                        end
                        return
                    end
                end
            end

            local results = { originalQuestLogTitleButton_OnClick(self, button) }

            if nativeQuestIndex then
                if IsQuestCurrentlyWatched(nativeQuestIndex, nativeQuestID) then
                    RememberNativeQuestWatch(nativeQuestIndex, nativeQuestID, nativeQuestTitle)
                elseif wasNativeWatched then
                    RemoveNativeQuestWatch(nativeQuestID, nativeQuestTitle)
                end
            end

            return unpack(results)
        end
    end
end

local function TrackQuest(questLogIndex, questID, questName, objectiveText)
    if not IsEnabled() then return end

    local index = questLogIndex
    if not IsValidQuestLogIndex(index, questID, questName) then
        index = FindQuestLogIndex(questID, questName)
    end

    if AddQuestToWatch(index, questID) then
        RememberNativeQuestWatch(index, questID, questName)
        RemoveFallbackQuestWatch(questID, questName)
        return
    end

    if index and not QuestHasTrackableObjectives(index) then
        AddFallbackQuestWatch(index, questID, questName, objectiveText, true)
    end
end

HookQuestWatchUpdates()

SafeRegisterEvent("QUEST_ACCEPTED")
SafeRegisterEvent("QUEST_LOG_UPDATE")
SafeRegisterEvent("QUEST_WATCH_UPDATE")
SafeRegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, questLogIndex, questID)
    HookQuestWatchUpdates()

    if event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" or event == "PLAYER_LOGIN" then
        PruneFallbackQuestWatches()
        RememberCurrentNativeQuestWatches()
        RestoreNativeQuestWatches()
        if Carpenter and Carpenter.After then
            Carpenter:After(0, function()
                if QuestWatch_Update then
                    QuestWatch_Update()
                else
                    RenderFallbackQuestWatches()
                end
                UpdateQuestLogWatchIndicators()
            end)
        else
            RenderFallbackQuestWatches()
            UpdateQuestLogWatchIndicators()
        end
        return
    end

    local questName = GetTitleText and GetTitleText()
    local objectiveText = GetObjectiveText and GetObjectiveText()
    if Carpenter and Carpenter.After then
        Carpenter:After(0, function()
            TrackQuest(questLogIndex, questID, questName, objectiveText)
        end)
    else
        TrackQuest(questLogIndex, questID, questName, objectiveText)
    end
end)
