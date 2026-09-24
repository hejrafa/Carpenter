#!/usr/bin/env lua
-- Verifies quest tracker headers are compacted safely, restored on disable,
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
local campaignHeader = NewHeader(26)
local questModule = {
    Header = questsHeader,
    headerHeight = 25,
    baseHeight = 200,
    height = 200,
    heightModifiers = {},
    point = "TOP",
    relativePoint = "TOP",
    offsetX = 0,
    offsetY = -38,
}
function questModule:SetHeight(value) self.height = value end
function questModule:GetHeight() return self.height end
function questModule:UpdateHeight()
    local modifier = 0
    for _, value in pairs(self.heightModifiers) do modifier = modifier + value end
    self.height = self.baseHeight + modifier
end
function questModule:SetHeightModifier(key, value)
    self.heightModifiers[key] = value
    self:UpdateHeight()
end
function questModule:ClearHeightModifier(key)
    self.heightModifiers[key] = nil
    self:UpdateHeight()
end
function questModule:GetNumPoints() return 1 end
function questModule:GetPoint() return self.point, self.relativeTo, self.relativePoint, self.offsetX, self.offsetY end
function questModule:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    self.point = point
    self.relativeTo = relativeTo
    self.relativePoint = relativePoint
    self.offsetX = offsetX
    self.offsetY = offsetY
end

local campaignModule = {
    Header = campaignHeader,
    headerHeight = 25,
    baseHeight = 160,
    height = 160,
    heightModifiers = {},
}
function campaignModule:SetHeight(value) self.height = value end
function campaignModule:GetHeight() return self.height end
function campaignModule:UpdateHeight()
    local modifier = 0
    for _, value in pairs(self.heightModifiers) do modifier = modifier + value end
    self.height = self.baseHeight + modifier
end
function campaignModule:SetHeightModifier(key, value)
    self.heightModifiers[key] = value
    self:UpdateHeight()
end
function campaignModule:ClearHeightModifier(key)
    self.heightModifiers[key] = nil
    self:UpdateHeight()
end

ObjectiveTrackerFrame = {
    Header = allObjectivesHeader,
    modules = { questModule, campaignModule },
    Update = function() end,
}
ObjectiveTrackerContainerMixin = { Update = function() end }
questModule.relativeTo = ObjectiveTrackerFrame
QuestObjectiveTracker = questModule
CampaignQuestObjectiveTracker = campaignModule

Carpenter = {
    Client = { isForever = false },
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
assert(campaignHeader.alpha == 0, "Campaign header should be hidden")
assert(allObjectivesHeader.height == 0.001, "All Objectives header space should be collapsed")
assert(questsHeader.height == 0.001, "Quests header space should be collapsed")
assert(campaignHeader.height == 0.001, "Campaign header space should be collapsed")
assert(questModule.offsetY == 0, "first tracker module should move to the top")
assert(questModule.height == 175, "quest module should release its layout header height")
assert(campaignModule.height == 135, "campaign module should release its layout header height")
assert(secureCallCount >= 3, "header alpha changes should use securecallfunction")
assert(containerUpdateHook, "container mixin Update should receive a secure post-hook")
assert(questModule.heightModifiers.CarpenterHiddenHeader == -25, "quest module should use a persistent height modifier")
assert(campaignModule.heightModifiers.CarpenterHiddenHeader == -25, "campaign module should use a persistent height modifier")

allObjectivesHeader.alpha = 1
allObjectivesHeader.height = 32
questsHeader.alpha = 1
questsHeader.height = 26
campaignHeader.alpha = 1
campaignHeader.height = 26
questModule.offsetY = -38
questModule:UpdateHeight()
campaignModule:UpdateHeight()
containerUpdateHook(ObjectiveTrackerFrame)
assert(allObjectivesHeader.alpha == 0 and allObjectivesHeader.height == 0.001, "tracker updates should keep the container header collapsed")
assert(questsHeader.alpha == 0 and questsHeader.height == 0.001, "tracker updates should keep the quest header collapsed")
assert(campaignHeader.alpha == 0 and campaignHeader.height == 0.001, "tracker updates should keep the campaign header collapsed")
assert(questModule.offsetY == 0 and questModule.height == 175, "tracker updates should keep compact module geometry")
assert(campaignModule.height == 135, "tracker updates should keep compact campaign geometry")

questModule:UpdateHeight()
campaignModule:UpdateHeight()
assert(questModule.height == 175, "standalone quest module height updates should remain compact")
assert(campaignModule.height == 135, "standalone campaign module height updates should remain compact")

questsHeader.alpha = 1
eventFrame.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
assert(questsHeader.alpha == 0, "quest updates should reapply hidden headers")

allObjectivesHeader.alpha = 1
questsHeader.alpha = 1
campaignHeader.alpha = 1
inCombat = true
eventFrame.OnEvent(eventFrame, "QUEST_LOG_UPDATE")
assert(allObjectivesHeader.alpha == 1, "All Objectives header must not change during combat")
assert(questsHeader.alpha == 1, "Quests header must not change during combat")
assert(campaignHeader.alpha == 1, "Campaign header must not change during combat")
assert(eventFrame.events.PLAYER_REGEN_ENABLED, "combat changes should be deferred")

inCombat = false
eventFrame.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(allObjectivesHeader.alpha == 0, "All Objectives header should hide after combat")
assert(questsHeader.alpha == 0, "Quests header should hide after combat")
assert(campaignHeader.alpha == 0, "Campaign header should hide after combat")

featureEnabled = false
registeredFeature:Disable()
assert(allObjectivesHeader.alpha == 1, "All Objectives header alpha should be restored")
assert(questsHeader.alpha == 1, "Quests header alpha should be restored")
assert(campaignHeader.alpha == 1, "Campaign header alpha should be restored")
assert(allObjectivesHeader.height == 32, "All Objectives header height should be restored")
assert(questsHeader.height == 26, "Quests header height should be restored")
assert(campaignHeader.height == 26, "Campaign header height should be restored")
assert(questModule.offsetY == -38, "first tracker module position should be restored")
assert(questModule.height == 200, "quest module height should be restored")
assert(campaignModule.height == 160, "campaign module height should be restored")

Carpenter.Client.isForever = true
featureEnabled = true
registeredFeature:Enable()
assert(allObjectivesHeader.alpha == 0, "Forever should still hide the All Objectives header")
assert(questsHeader.alpha == 0, "Forever should still hide the Quests header")
assert(campaignHeader.alpha == 1, "Forever must not hide the Retail Campaign header")
assert(campaignHeader.height == 26, "Forever must not collapse the Retail Campaign header")
assert(campaignModule.height == 160, "Forever must not compact the Retail Campaign module")

featureEnabled = false
registeredFeature:Disable()
assert(allObjectivesHeader.alpha == 1, "Forever objective header should be restored")
assert(questsHeader.alpha == 1, "Forever quest header should be restored")
Carpenter.Client.isForever = false

local legacyAllObjectivesHeader = NewHeader()
local legacyQuestsHeader = NewHeader()
ObjectiveTrackerFrame = { HeaderMenu = legacyAllObjectivesHeader }
QuestObjectiveTracker = nil
CampaignQuestObjectiveTracker = nil
ObjectiveTrackerBlocksFrame = { QuestHeader = legacyQuestsHeader }

featureEnabled = true
registeredFeature:Enable()
assert(legacyAllObjectivesHeader.alpha == 0, "legacy objective header should be hidden")
assert(legacyQuestsHeader.alpha == 0, "legacy quest header should be hidden")

featureEnabled = false
registeredFeature:Disable()
assert(legacyAllObjectivesHeader.alpha == 1, "legacy objective header should be restored")
assert(legacyQuestsHeader.alpha == 1, "legacy quest header should be restored")

local retailTOC = assert(io.open(repo .. "/Carpenter.toc", "r")):read("*a")
local foreverTOC = assert(io.open(repo .. "/Carpenter_Camelot.toc", "r")):read("*a")
assert(retailTOC:find("Modules\\HideQuestTrackerTitles.lua", 1, true), "Retail TOC should load quest tracker title hiding")
assert(foreverTOC:find("Modules\\HideQuestTrackerTitles.lua", 1, true), "Forever TOC should keep quest tracker title hiding")

print("hide-quest-tracker-titles fixtures: passed")
