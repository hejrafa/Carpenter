--[[ Carpenter - Auto Track Quests layout helpers ]]
-- Renders no-objective quest fallbacks and keeps Classic watch lines aligned.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Layout = ns.Private.AutoTrackQuestLayout or {}
ns.Private.AutoTrackQuestLayout = Layout

local State = ns.Private.AutoTrackQuestState or {}

local questWatchLayoutRefreshScheduled = false
local QUEST_WATCH_WRAP_WIDTH = 230
local QUEST_WATCH_MIN_LINE_HEIGHT = 13
local QUEST_WATCH_MEASURE_HEIGHT = 240
local QUEST_WATCH_SECTION_GAP = 4
local QUEST_WATCH_FRAME_PADDING = 10
local QUEST_WATCH_FRAME_WIDTH = QUEST_WATCH_WRAP_WIDTH + QUEST_WATCH_FRAME_PADDING
local QUEST_WATCH_OBJECTIVE_PREFIX = " - "

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("autoTrackQuestsEnabled")
end

local function GetNativeQuestWatchLineIndex()
    local watchTextIndex = 1
    if not GetNumQuestWatches or not GetQuestIndexForWatch then
        return watchTextIndex
    end

    for index = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(index)
        local numObjectives = State.GetNumQuestObjectives(questIndex) or 0
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

local function GetQuestWatchPrefixWidth(line, prefix)
    if not line or type(prefix) ~= "string" or prefix == "" then return 0 end

    local probe = "X"
    return math.max(0, GetQuestWatchTextWidth(line, prefix .. probe) - GetQuestWatchTextWidth(line, probe))
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
        local numObjectives = State.GetNumQuestObjectives(questIndex) or 0
        if questIndex and numObjectives > 0 then
            gaps[lineIndex] = lineIndex > 1
            lineIndex = lineIndex + 1 + numObjectives
        end
    end

    return gaps
end

local function LayoutQuestWatchLines()
    if not IsEnabled() or not QuestWatchFrame then return end
    if not State.HasQuestWatches() then
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
        if not State.HasQuestWatches() then
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
    line._CarpenterQuestWatchOffsetX = offsetText and GetQuestWatchPrefixWidth(line, offsetText) or nil
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

    displayText = State.CleanQuestText(displayText)
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

    local state = State.GetFallbackState()
    if #state.order == 0 then return end

    local maxLines = MAX_QUESTWATCH_LINES or 30
    local lineIndex = GetNativeQuestWatchLineIndex()
    local rendered = 0

    for _, key in ipairs(state.order) do
        local watch = state.quests[key]
        local questIndex = watch and State.FindQuestLogIndex(watch.questID, watch.title)
        if watch and questIndex and not State.QuestHasTrackableObjectives(questIndex) and lineIndex + 1 <= maxLines then
            watch.title = State.GetQuestDisplayTitle(questIndex, watch.title)
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
            local questID, title, isHeader = State.GetQuestInfo(questIndex)
            if not isHeader and State.IsFallbackQuestWatched(questID, title) then
                PositionQuestLogWatchCheck(row, button, check, title)
                check:Show()
            end
        end
    end

    if QuestLogTrackTracking and #State.GetFallbackState().order > 0 then
        QuestLogTrackTracking:SetVertexColor(0, 1.0, 0)
    end
end

Layout.UpdateQuestWatchLayout = UpdateQuestWatchLayout
Layout.UpdateQuestLogWatchIndicators = UpdateQuestLogWatchIndicators
