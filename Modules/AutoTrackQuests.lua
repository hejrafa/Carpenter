--[[ Carpenter - AutoTrackQuests ]]
-- Automatically adds newly accepted quests to the objective tracker.

local frame = CreateFrame("Frame")
local fallbackMemory = { order = {}, quests = {} }
local nativeWatchMemory = { order = {}, quests = {} }
local hookedQuestWatchUpdate = false
local hookedQuestLogUpdate = false
local hookedRemoveQuestWatch = false
local hookedCQuestLogRemoveQuestWatch = false
local questWatchRemoveInProgress = false
local questWatchLayoutRefreshScheduled = false
local originalQuestLogTitleButton_OnClick = nil
local AddQuestToWatch
local QUEST_WATCH_WRAP_WIDTH = 230
local QUEST_WATCH_MIN_LINE_HEIGHT = 13
local QUEST_WATCH_MEASURE_HEIGHT = 240
local QUEST_WATCH_SECTION_GAP = 4
local QUEST_WATCH_FRAME_PADDING = 10
local QUEST_WATCH_FRAME_WIDTH = QUEST_WATCH_WRAP_WIDTH + QUEST_WATCH_FRAME_PADDING
local QUEST_WATCH_OBJECTIVE_PREFIX = "- "

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

local function AddFallbackQuestWatch(index, questID, questName, quiet)
    if not index then return false end

    local logQuestID, title, isHeader = GetQuestInfo(index)
    if isHeader then return false end

    questID = questID or logQuestID
    questName = GetQuestDisplayTitle(index, questName)

    local key = MakeQuestKey(questID, questName)
    if not key then return false end

    objectiveText = GetQuestObjectiveText(index) or questName
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
            watch.objectiveText = GetQuestObjectiveText(questIndex) or watch.title
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

local function ConfigureQuestWatchLine(line)
    if not line then return end
    local offsetX = line._CarpenterQuestWatchOffsetX or 0
    if line.SetWidth then
        line:SetWidth(math.max(1, QUEST_WATCH_WRAP_WIDTH - offsetX))
    end
    if line.SetMaxLines then
        pcall(line.SetMaxLines, line, 0)
    end
    if line.SetWordWrap then
        line:SetWordWrap(true)
    end
    if line.SetNonSpaceWrap then
        line:SetNonSpaceWrap(true)
    end
    if line.SetJustifyH then
        line:SetJustifyH("LEFT")
    end
    if line.SetHeight then
        line:SetHeight(QUEST_WATCH_MEASURE_HEIGHT)
    end
end

local function GetQuestWatchLineHeight(line)
    if not line then return QUEST_WATCH_MIN_LINE_HEIGHT end

    local height
    if line.GetStringHeight then
        height = line:GetStringHeight()
    end
    if not height or height <= 0 then
        height = line.GetHeight and line:GetHeight()
    end

    return math.max(QUEST_WATCH_MIN_LINE_HEIGHT, height or QUEST_WATCH_MIN_LINE_HEIGHT)
end

local function GetQuestWatchLineWidth(line)
    if not line then return 0 end

    local width
    if line.GetStringWidth then
        width = line:GetStringWidth()
    end
    if not width or width <= 0 then
        width = line.GetWidth and line:GetWidth()
    end

    width = width or 0
    if width > QUEST_WATCH_WRAP_WIDTH then
        return QUEST_WATCH_WRAP_WIDTH
    end
    return width
end

local function GetQuestWatchTextWidth(line, text)
    if not line or not text then return 0 end

    local originalText = line.GetText and line:GetText()
    line:SetText(text)
    local width = line.GetStringWidth and line:GetStringWidth() or line:GetWidth()
    line:SetText(originalText or "")

    return width or 0
end

local function GetQuestWatchRawLineText(line)
    if not line or not line.GetText then return nil end

    local text = line:GetText()
    if text == line._CarpenterQuestWatchWrappedText and line._CarpenterQuestWatchRawText then
        return line._CarpenterQuestWatchRawText
    end

    line._CarpenterQuestWatchRawText = text
    line._CarpenterQuestWatchWrappedText = nil
    return text
end

local function BuildIndentedObjectiveLine(line, text)
    if type(text) ~= "string" then return text end

    local prefix, body = text:match("^(%s*%-%s+)(.+)$")
    if not prefix or not body then return text end

    body = body:gsub("[\r\n]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if body == "" then return text end

    local continuationIndent = prefix:gsub("%S", " ")
    local lines = {}
    local current = prefix

    for word in body:gmatch("%S+") do
        local candidate
        if current == prefix or current == continuationIndent then
            candidate = current .. word
        else
            candidate = current .. " " .. word
        end

        if current ~= prefix and current ~= continuationIndent and GetQuestWatchTextWidth(line, candidate) > QUEST_WATCH_WRAP_WIDTH then
            tinsert(lines, current)
            current = continuationIndent .. word
        else
            current = candidate
        end
    end

    if current and current ~= prefix and current ~= continuationIndent then
        tinsert(lines, current)
    end

    return table.concat(lines, "\n")
end

local function ApplyQuestWatchLineText(line)
    local rawText = GetQuestWatchRawLineText(line)
    if type(rawText) ~= "string" or rawText == "" then return end

    local wrappedText = BuildIndentedObjectiveLine(line, rawText)
    if wrappedText ~= rawText then
        line._CarpenterQuestWatchWrappedText = wrappedText
        line:SetText(wrappedText)
    end
end

local function ClearQuestWatchLineMetadata()
    local maxLines = MAX_QUESTWATCH_LINES or 30
    for index = 1, maxLines do
        local line = _G["QuestWatchLine" .. index]
        if line then
            line._CarpenterQuestWatchFallbackLine = nil
            line._CarpenterQuestWatchGapBefore = nil
            line._CarpenterQuestWatchOffsetX = nil
            line._CarpenterQuestWatchRawText = nil
            line._CarpenterQuestWatchWrappedText = nil
        end
    end
end

local function HideQuestWatchFrame()
    local maxLines = MAX_QUESTWATCH_LINES or 30
    for index = 1, maxLines do
        local line = _G["QuestWatchLine" .. index]
        if line then
            if line.SetText then
                line:SetText("")
            end
            line:Hide()
        end
    end

    if QuestWatchFrame then
        QuestWatchFrame:Hide()
    end

    if UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end
end

local function GetNativeQuestWatchLineGaps()
    local gaps = {}
    local lineIndex = 1
    if not GetNumQuestWatches or not GetQuestIndexForWatch then
        return gaps
    end

    for index = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(index)
        local numObjectives = GetNumQuestObjectives(questIndex) or 0
        if questIndex and numObjectives > 0 then
            gaps[lineIndex] = lineIndex > 1
            lineIndex = lineIndex + 1 + numObjectives
        end
    end

    return gaps
end

local function LayoutQuestWatchLines()
    if not IsEnabled() or not QuestWatchFrame then return end
    if not HasQuestWatches() then
        HideQuestWatchFrame()
        return
    end

    local anchor = QuestWatchQuestName or QuestWatchFrame
    local anchorPoint = QuestWatchQuestName and "BOTTOMLEFT" or "TOPLEFT"
    local nativeGaps = GetNativeQuestWatchLineGaps()
    local maxLines = MAX_QUESTWATCH_LINES or 30
    local offsetY = 0
    local visibleLines = 0

    for index = 1, maxLines do
        local line = _G["QuestWatchLine" .. index]
        if line and line:IsShown() and (not line.GetText or line:GetText() ~= "") then
            ConfigureQuestWatchLine(line)
            ApplyQuestWatchLineText(line)

            local gapBefore = line._CarpenterQuestWatchFallbackLine and line._CarpenterQuestWatchGapBefore or nativeGaps[index]
            if gapBefore and visibleLines > 0 then
                offsetY = offsetY + QUEST_WATCH_SECTION_GAP
            end

            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", anchor, anchorPoint, line._CarpenterQuestWatchOffsetX or 0, -offsetY)

            local height = GetQuestWatchLineHeight(line)
            if line.SetHeight then
                line:SetHeight(height)
            end
            offsetY = offsetY + height

            visibleLines = visibleLines + 1
        end
    end

    if visibleLines == 0 then
        if not HasQuestWatches() then
            QuestWatchFrame:Hide()
            if UIParent_ManageFramePositions then
                UIParent_ManageFramePositions()
            end
        end
        return
    end

    QuestWatchFrame:SetHeight(offsetY + QUEST_WATCH_FRAME_PADDING)
    QuestWatchFrame:SetWidth(QUEST_WATCH_FRAME_WIDTH)
    QuestWatchFrame:Show()

    if UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end
end

local function ScheduleQuestWatchLayoutRefresh()
    if questWatchLayoutRefreshScheduled then return end

    questWatchLayoutRefreshScheduled = true
    local function RefreshLayout()
        questWatchLayoutRefreshScheduled = false
        LayoutQuestWatchLines()
    end

    if Carpenter and Carpenter.After then
        Carpenter:After(0, RefreshLayout)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshLayout)
    else
        questWatchLayoutRefreshScheduled = false
    end
end

local function SetQuestWatchLine(lineIndex, text, r, g, b, gapBefore, offsetText)
    local line = _G["QuestWatchLine" .. lineIndex]
    if not line then return nil end

    ConfigureQuestWatchLine(line)
    line._CarpenterQuestWatchFallbackLine = true
    line._CarpenterQuestWatchGapBefore = gapBefore and true or false
    line._CarpenterQuestWatchOffsetX = offsetText and GetQuestWatchTextWidth(line, offsetText) or nil
    ConfigureQuestWatchLine(line)

    line:ClearAllPoints()
    if lineIndex == 1 then
        line:SetPoint("TOPLEFT", QuestWatchQuestName or QuestWatchFrame, QuestWatchQuestName and "BOTTOMLEFT" or "TOPLEFT", line._CarpenterQuestWatchOffsetX or 0, 0)
    else
        line:SetPoint("TOPLEFT", _G["QuestWatchLine" .. (lineIndex - 1)], "BOTTOMLEFT", line._CarpenterQuestWatchOffsetX or 0, gapBefore and -4 or 0)
    end

    line:SetText(text)
    line:SetTextColor(r, g, b)
    line:Show()

    return GetQuestWatchLineWidth(line)
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
    local rendered = 0

    for _, key in ipairs(state.order) do
        local watch = state.quests[key]
        local questIndex = watch and FindQuestLogIndex(watch.questID, watch.title)
        if watch and questIndex and not QuestHasTrackableObjectives(questIndex) and lineIndex + 1 <= maxLines then
            watch.title = GetQuestDisplayTitle(questIndex, watch.title)
            SetQuestWatchLine(lineIndex, watch.title or "", 0.75, 0.61, 0, lineIndex > 1)
            lineIndex = lineIndex + 1

            local objective = watch.objectiveText or watch.title or ""
            SetQuestWatchLine(lineIndex, objective, 0.8, 0.8, 0.8, false, QUEST_WATCH_OBJECTIVE_PREFIX)
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

    if QuestLogTrackTracking then
        QuestLogTrackTracking:SetVertexColor(0, 1.0, 0)
    end
end

local function UpdateQuestWatchLayout()
    ClearQuestWatchLineMetadata()
    RenderFallbackQuestWatches()
    LayoutQuestWatchLines()
    ScheduleQuestWatchLayoutRefresh()
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

local function ForgetQuestWatch(questIndex, questID)
    local title, isHeader

    if questIndex then
        local logQuestID
        logQuestID, title, isHeader = GetQuestInfo(questIndex)
        questID = questID or logQuestID
    elseif questID then
        questIndex = FindQuestLogIndex(questID)
        if questIndex then
            questID, title, isHeader = GetQuestInfo(questIndex)
        end
    end

    if isHeader then return end

    local removed = RemoveNativeQuestWatch(questID, title)
    removed = RemoveFallbackQuestWatch(questID, title) or removed

    return removed, questIndex, questID
end

local function KeepQuestWatchRemoved(questIndex, questID)
    if questWatchRemoveInProgress or not IsQuestCurrentlyWatched(questIndex, questID) then return end

    questWatchRemoveInProgress = true
    if C_QuestLog and C_QuestLog.RemoveQuestWatch and questID then
        pcall(C_QuestLog.RemoveQuestWatch, questID)
    elseif RemoveQuestWatch and questIndex then
        pcall(RemoveQuestWatch, questIndex)
    end
    questWatchRemoveInProgress = false
end

local function HookQuestWatchUpdates()
    if not hookedQuestWatchUpdate and hooksecurefunc and QuestWatch_Update then
        hooksecurefunc("QuestWatch_Update", UpdateQuestWatchLayout)
        hookedQuestWatchUpdate = true
    end

    if not hookedQuestLogUpdate and hooksecurefunc and QuestLog_Update then
        hooksecurefunc("QuestLog_Update", UpdateQuestLogWatchIndicators)
        hookedQuestLogUpdate = true
    end

    if not hookedRemoveQuestWatch and hooksecurefunc and RemoveQuestWatch then
        hooksecurefunc("RemoveQuestWatch", function(questIndex)
            if questWatchRemoveInProgress then return end

            local removed, resolvedIndex, resolvedQuestID = ForgetQuestWatch(questIndex)
            KeepQuestWatchRemoved(resolvedIndex or questIndex, resolvedQuestID)
            if removed or not IsQuestCurrentlyWatched(resolvedIndex or questIndex, resolvedQuestID) then
                RefreshQuestTracker()
            end
        end)
        hookedRemoveQuestWatch = true
    end

    if not hookedCQuestLogRemoveQuestWatch and hooksecurefunc and C_QuestLog and C_QuestLog.RemoveQuestWatch then
        hooksecurefunc(C_QuestLog, "RemoveQuestWatch", function(questID)
            if questWatchRemoveInProgress then return end

            local removed, resolvedIndex, resolvedQuestID = ForgetQuestWatch(nil, questID)
            KeepQuestWatchRemoved(resolvedIndex, resolvedQuestID or questID)
            if removed or not IsQuestCurrentlyWatched(resolvedIndex, resolvedQuestID or questID) then
                RefreshQuestTracker()
            end
        end)
        hookedCQuestLogRemoveQuestWatch = true
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
                            AddFallbackQuestWatch(questIndex, questID, title, false)
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

local function TrackQuest(questLogIndex, questID, questName)
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
        AddFallbackQuestWatch(index, questID, questName, true)
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
                    UpdateQuestWatchLayout()
                end
                UpdateQuestLogWatchIndicators()
            end)
        else
            UpdateQuestWatchLayout()
            UpdateQuestLogWatchIndicators()
        end
        return
    end

    local questName = GetTitleText and GetTitleText()
    if Carpenter and Carpenter.After then
        Carpenter:After(0, function()
            TrackQuest(questLogIndex, questID, questName)
        end)
    else
        TrackQuest(questLogIndex, questID, questName)
    end
end)
