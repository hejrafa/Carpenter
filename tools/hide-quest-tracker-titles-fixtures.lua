#!/usr/bin/env lua
-- Verifies quest tracker headers are hidden by alpha only, restored on disable,
-- and never changed while combat lockdown is active.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local registeredFeature
local featureEnabled = true
local inCombat = false
local secureCallCount = 0
local eventFrame
local containerUpdateHook
local moduleHeightHook

local function NewHeader(height)
    return {
        alpha = 1,
        height = height or 26,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        GetAlpha = function(self) return self.alpha end,
        SetHeight = function(self, value) self.height = value end,
        GetHeight = function(self) return self.height end,
        Hide = function() error("quest tracker headers must not be hidden") end,
    }
end

local allObjectivesHeader = NewHeader(32)
local questsHeader = NewHeader(26)
local questModule = {
    Header = questsHeader,
    height = 200,
    point = "TOP",
    relativePoint = "TOP",
    offsetX = 0,
    offsetY = -38,
}
function questModule:SetHeight(value) self.height = value end
function questModule:GetHeight() return self.height end
function questModule:UpdateHeight() end
function questModule:GetNumPoints() return 1 end
function questModule:GetPoint() return self.point, self.relativeTo, self.relativePoint, self.offsetX, self.offsetY end
function questModule:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    self.point = point
    self.relativeTo = relativeTo
    self.relativePoint = relativePoint
    self.offsetX = offsetX
    self.offsetY = offsetY
end

ObjectiveTrackerFrame = {
    Header = allObjectivesHeader,
    modules = { questModule },
    Update = function() end,
}
ObjectiveTrackerContainerMixin = { Update = function() end }
questModule.relativeTo = ObjectiveTrackerFrame
QuestObjectiveTracker = questModule

Carpenter = {
    IsEnabled = function(_, key)
        return key == "hideQuestTrackerTitlesEnabled" and featureEnabled
    end,
    RegisterFeature = function(_, key, feature)
        if key == "hideQuestTrackerTitlesEnabled" then registeredFeature = feature end
    end,
    After = function()
        error("quest tracker title hiding must not rely on delayed startup passes")
    end,
}

function securecallfunction(func, ...)
    secureCallCount = secureCallCount + 1
    return func(...)
end

function InCombatLockdown()
    return inCombat
end

function hooksecurefunc(object, method, callback)
    if object == ObjectiveTrackerContainerMixin and method == "Update" then
        containerUpdateHook = callback
    elseif object == questModule and method == "UpdateHeight" then
        moduleHeightHook = callback
    else
        error("unexpected secure hook target")
    end
end

function CreateFrame()
    eventFrame = { events = {} }
    function eventFrame:Hide() end
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:UnregisterEvent(event) self.events[event] = nil end
    function eventFrame:UnregisterAllEvents() self.events = {} end
    function eventFrame:SetScript(_, handler) self.OnEvent = handler end
    return eventFrame
end

local chunk = assert(loadfile(repo .. "/Modules/HideQuestTrackerTitles.lua"))
chunk("Carpenter", {})

assert(registeredFeature and registeredFeature.Enable, "quest tracker title feature was not registered")
registeredFeature:Enable()
assert(allObjectivesHeader.alpha == 0, "All Objectives header should be hidden")
assert(questsHeader.alpha == 0, "Quests header should be hidden")
assert(allObjectivesHeader.height == 0.001, "All Objectives header space should be collapsed")
assert(questsHeader.height == 0.001, "Quests header space should be collapsed")
assert(questModule.offsetY == 0, "first tracker module should move to the top")
assert(questModule.height == 174, "quest module should release its hidden header height")
assert(secureCallCount >= 2, "header alpha changes should use securecallfunction")
assert(containerUpdateHook, "container mixin Update should receive a secure post-hook")
assert(moduleHeightHook, "module mixin UpdateHeight should receive a secure post-hook")

allObjectivesHeader.alpha = 1
allObjectivesHeader.height = 32
questsHeader.alpha = 1
questsHeader.height = 26
questModule.offsetY = -38
questModule.height = 200
containerUpdateHook(ObjectiveTrackerFrame)
assert(allObjectivesHeader.alpha == 0 and allObjectivesHeader.height == 0.001, "tracker updates should keep the container header collapsed")
assert(questsHeader.alpha == 0 and questsHeader.height == 0.001, "tracker updates should keep the quest header collapsed")
assert(questModule.offsetY == 0 and questModule.height == 174, "tracker updates should keep compact module geometry")

questModule.height = 200
moduleHeightHook(questModule)
assert(questModule.height == 174, "standalone quest module height updates should remain compact")

questsHeader.alpha = 1
eventFrame.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
assert(questsHeader.alpha == 0, "quest updates should reapply hidden headers")

allObjectivesHeader.alpha = 1
questsHeader.alpha = 1
inCombat = true
eventFrame.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
assert(allObjectivesHeader.alpha == 1, "All Objectives header must not change during combat")
assert(questsHeader.alpha == 1, "Quests header must not change during combat")
assert(eventFrame.events.PLAYER_REGEN_ENABLED, "combat changes should be deferred")

inCombat = false
eventFrame.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(allObjectivesHeader.alpha == 0, "All Objectives header should hide after combat")
assert(questsHeader.alpha == 0, "Quests header should hide after combat")

featureEnabled = false
registeredFeature:Disable()
assert(allObjectivesHeader.alpha == 1, "All Objectives header alpha should be restored")
assert(questsHeader.alpha == 1, "Quests header alpha should be restored")
assert(allObjectivesHeader.height == 32, "All Objectives header height should be restored")
assert(questsHeader.height == 26, "Quests header height should be restored")
assert(questModule.offsetY == -38, "first tracker module position should be restored")
assert(questModule.height == 200, "quest module height should be restored")

local legacyAllObjectivesHeader = NewHeader()
local legacyQuestsHeader = NewHeader()
ObjectiveTrackerFrame = { HeaderMenu = legacyAllObjectivesHeader }
QuestObjectiveTracker = nil
ObjectiveTrackerBlocksFrame = { QuestHeader = legacyQuestsHeader }

featureEnabled = true
registeredFeature:Enable()
assert(legacyAllObjectivesHeader.alpha == 0, "legacy objective header should be hidden")
assert(legacyQuestsHeader.alpha == 0, "legacy quest header should be hidden")

featureEnabled = false
registeredFeature:Disable()
assert(legacyAllObjectivesHeader.alpha == 1, "legacy objective header should be restored")
assert(legacyQuestsHeader.alpha == 1, "legacy quest header should be restored")

print("hide-quest-tracker-titles fixtures: passed")
