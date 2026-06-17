--[[ Carpenter - AutoTrackQuests ]]
-- Automatically adds newly accepted quests to the objective tracker.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local frame = CreateFrame("Frame")
local State = ns.Private.AutoTrackQuestState or {}
local Layout = ns.Private.AutoTrackQuestLayout or {}

local hookedQuestWatchUpdate = false
local hookedQuestLogUpdate = false
local hookedRemoveQuestWatch = false
local hookedCQuestLogRemoveQuestWatch = false
local questWatchRemoveInProgress = false
local questWatchRestoreScheduled = false
local manualQuestWatchRemovalDepth = 0
local originalQuestLogTitleButton_OnClick = nil
local AddQuestToWatch

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("autoTrackQuestsEnabled")
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

    local logQuestID, title, isHeader = State.GetQuestInfo(index)
    if isHeader then return false end

    questID = questID or logQuestID
    questName = State.GetQuestDisplayTitle(index, questName)

    local key = State.MakeQuestKey(questID, questName)
    if not key then return false end

    local objectiveText = State.GetQuestObjectiveText(index) or questName
    objectiveText = State.CleanQuestText(objectiveText)
    if not objectiveText then return false end

    local state = State.GetFallbackState()
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

AddQuestToWatch = function(index, questID, skipRefresh)
    if index and not State.QuestHasTrackableObjectives(index) then
        return false
    end

    if not State.CanAddNativeQuestWatch(index, questID) then
        return false
    end

    local function Finish()
        if not skipRefresh then
            RefreshQuestTracker()
        end
        return true
    end

    if State.IsQuestCurrentlyWatched(index, questID) then
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

local function ForgetQuestWatch(questIndex, questID)
    local title, isHeader

    if questIndex then
        local logQuestID
        logQuestID, title, isHeader = State.GetQuestInfo(questIndex)
        questID = questID or logQuestID
    elseif questID then
        questIndex = State.FindQuestLogIndex(questID)
        if questIndex then
            questID, title, isHeader = State.GetQuestInfo(questIndex)
        end
    end

    if isHeader then return end

    local removed = State.RemoveNativeQuestWatch(questID, title)
    removed = State.RemoveFallbackQuestWatch(questID, title) or removed

    return removed, questIndex, questID
end

local function ScheduleRestoreNativeQuestWatches()
    if questWatchRestoreScheduled or not IsEnabled() then return end
    questWatchRestoreScheduled = true

    local function Restore()
        questWatchRestoreScheduled = false
        if not IsEnabled() then return end

        State.RestoreNativeQuestWatches(AddQuestToWatch)
        RefreshQuestTracker()
    end

    if Carpenter and Carpenter.After then
        Carpenter:After(0, Restore)
    else
        Restore()
    end
end

local function KeepQuestWatchRemoved(questIndex, questID)
    if questWatchRemoveInProgress or not State.IsQuestCurrentlyWatched(questIndex, questID) then return end

    questWatchRemoveInProgress = true
    if C_QuestLog and C_QuestLog.RemoveQuestWatch and questID then
        pcall(C_QuestLog.RemoveQuestWatch, questID)
    elseif RemoveQuestWatch and questIndex then
        pcall(RemoveQuestWatch, questIndex)
    end
    questWatchRemoveInProgress = false
end

local function IsManualQuestWatchRemoval()
    return manualQuestWatchRemovalDepth > 0 or (IsEnabled() and IsShiftKeyDown and IsShiftKeyDown())
end

local function HandleQuestWatchRemoved(questIndex, questID)
    if questWatchRemoveInProgress then return end

    if not IsEnabled() or IsManualQuestWatchRemoval() then
        local removed, resolvedIndex, resolvedQuestID = ForgetQuestWatch(questIndex, questID)
        KeepQuestWatchRemoved(resolvedIndex or questIndex, resolvedQuestID or questID)
        if removed or not State.IsQuestCurrentlyWatched(resolvedIndex or questIndex, resolvedQuestID or questID) then
            RefreshQuestTracker()
        end
        return
    end

    ScheduleRestoreNativeQuestWatches()
end

local function HookQuestWatchUpdates()
    if not hookedQuestWatchUpdate and hooksecurefunc and QuestWatch_Update then
        hooksecurefunc("QuestWatch_Update", Layout.UpdateQuestWatchLayout)
        hookedQuestWatchUpdate = true
    end

    if not hookedQuestLogUpdate and hooksecurefunc and QuestLog_Update then
        hooksecurefunc("QuestLog_Update", Layout.UpdateQuestLogWatchIndicators)
        hookedQuestLogUpdate = true
    end

    if not hookedRemoveQuestWatch and hooksecurefunc and RemoveQuestWatch then
        hooksecurefunc("RemoveQuestWatch", function(questIndex)
            HandleQuestWatchRemoved(questIndex, nil)
        end)
        hookedRemoveQuestWatch = true
    end

    if not hookedCQuestLogRemoveQuestWatch and hooksecurefunc and C_QuestLog and C_QuestLog.RemoveQuestWatch then
        hooksecurefunc(C_QuestLog, "RemoveQuestWatch", function(questID)
            HandleQuestWatchRemoved(nil, questID)
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
                    if questIndex and State.QuestHasTrackableObjectives(questIndex) then
                        nativeQuestIndex = questIndex
                        nativeQuestID, nativeQuestTitle = State.GetQuestInfo(questIndex)
                        wasNativeWatched = State.IsQuestCurrentlyWatched(questIndex, nativeQuestID)
                    elseif questIndex then
                        local questID, title = State.GetQuestInfo(questIndex)
                        if State.IsFallbackQuestWatched(questID, title) then
                            State.RemoveFallbackQuestWatch(questID, title)
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

            if nativeQuestIndex and wasNativeWatched then
                manualQuestWatchRemovalDepth = manualQuestWatchRemovalDepth + 1
            end
            local results = { originalQuestLogTitleButton_OnClick(self, button) }
            if nativeQuestIndex and wasNativeWatched then
                manualQuestWatchRemovalDepth = math.max(0, manualQuestWatchRemovalDepth - 1)
            end

            if nativeQuestIndex then
                if State.IsQuestCurrentlyWatched(nativeQuestIndex, nativeQuestID) then
                    State.RememberNativeQuestWatch(nativeQuestIndex, nativeQuestID, nativeQuestTitle)
                elseif wasNativeWatched then
                    State.RemoveNativeQuestWatch(nativeQuestID, nativeQuestTitle)
                end
            end

            return unpack(results)
        end
    end
end

local function TrackQuest(questLogIndex, questID, questName)
    if not IsEnabled() then return end

    local index = questLogIndex
    if not State.IsValidQuestLogIndex(index, questID, questName) then
        index = State.FindQuestLogIndex(questID, questName)
    end

    if AddQuestToWatch(index, questID) then
        State.RememberNativeQuestWatch(index, questID, questName)
        State.RemoveFallbackQuestWatch(questID, questName)
        return
    end

    if index and not State.QuestHasTrackableObjectives(index) then
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
        State.PruneFallbackQuestWatches(AddQuestToWatch)
        State.RememberCurrentNativeQuestWatches()
        State.RestoreNativeQuestWatches(AddQuestToWatch)
        if Carpenter and Carpenter.After then
            Carpenter:After(0, function()
                if QuestWatch_Update then
                    QuestWatch_Update()
                else
                    Layout.UpdateQuestWatchLayout()
                end
                Layout.UpdateQuestLogWatchIndicators()
            end)
        else
            Layout.UpdateQuestWatchLayout()
            Layout.UpdateQuestLogWatchIndicators()
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
