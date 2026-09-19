--[[ Carpenter - Hide Quest Tracker Titles ]]
-- Hides the Objective Tracker's container and quest-module headers and
-- reclaims their layout space without changing protected visibility state.

local FEATURE_KEY = "hideQuestTrackerTitlesEnabled"
local COLLAPSED_HEADER_HEIGHT = 0.001
local secureCallFunction = securecallfunction
local originalAlphas = setmetatable({}, { __mode = "k" })
local originalHeights = setmetatable({}, { __mode = "k" })
local managedModuleHeights = setmetatable({}, { __mode = "k" })
local managedModuleAnchors = setmetatable({}, { __mode = "k" })
local hookedTrackers = setmetatable({}, { __mode = "k" })
local hookedQuestModules = setmetatable({}, { __mode = "k" })
local containerUpdateHookInstalled = false
local pendingCombatApply = false

local eventFrame = CreateFrame("Frame")
eventFrame:Hide()

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

local function AddUniqueFrame(frames, seen, frame)
    if not frame or seen[frame] then return end
    if type(frame.SetAlpha) ~= "function" then return end
    seen[frame] = true
    frames[#frames + 1] = frame
end

local function GetQuestTrackerHeaders()
    local frames = {}
    local seen = {}
    local tracker = _G.ObjectiveTrackerFrame
    local blocksFrame = _G.ObjectiveTrackerBlocksFrame or (tracker and tracker.BlocksFrame)
    local questTracker = _G.QuestObjectiveTracker
    local questModule = _G.QUEST_TRACKER_MODULE

    -- Current Objective Tracker layout.
    AddUniqueFrame(frames, seen, tracker and tracker.Header)
    AddUniqueFrame(frames, seen, questTracker and questTracker.Header)

    -- Dragonflight-era and Classic-compatible layouts.
    AddUniqueFrame(frames, seen, tracker and tracker.HeaderMenu)
    AddUniqueFrame(frames, seen, blocksFrame and blocksFrame.QuestHeader)
    AddUniqueFrame(frames, seen, questModule and questModule.Header)

    return frames
end

local function SetAlphaSecurely(frame, alpha)
    local setter = frame and frame.SetAlpha
    if type(setter) ~= "function" then return false end

    if type(frame.GetAlpha) == "function" then
        local ok, currentAlpha = pcall(frame.GetAlpha, frame)
        if ok and currentAlpha == alpha then return true end
    end

    if type(secureCallFunction) == "function" then
        secureCallFunction(setter, frame, alpha)
    else
        local ok = pcall(setter, frame, alpha)
        if not ok then return false end
    end
    return true
end

local function CallWidgetMethodSecurely(frame, methodName, ...)
    local method = frame and frame[methodName]
    if type(method) ~= "function" then return false end

    if type(secureCallFunction) == "function" then
        secureCallFunction(method, frame, ...)
    else
        local ok = pcall(method, frame, ...)
        if not ok then return false end
    end
    return true
end

local function RememberAlpha(frame)
    if originalAlphas[frame] ~= nil then return end

    local alpha = 1
    if type(frame.GetAlpha) == "function" then
        local ok, currentAlpha = pcall(frame.GetAlpha, frame)
        if ok and type(currentAlpha) == "number" then
            alpha = currentAlpha
        end
    end
    originalAlphas[frame] = alpha
end

local function RememberHeight(frame)
    if originalHeights[frame] ~= nil or type(frame.GetHeight) ~= "function" then return end

    local ok, height = pcall(frame.GetHeight, frame)
    if ok and type(height) == "number" then
        originalHeights[frame] = height
    end
end

local function CollapseHeader(header)
    RememberAlpha(header)
    RememberHeight(header)
    SetAlphaSecurely(header, 0)

    local shouldCollapse = true
    if type(header.GetHeight) == "function" then
        local ok, currentHeight = pcall(header.GetHeight, header)
        shouldCollapse = not ok or currentHeight ~= COLLAPSED_HEADER_HEIGHT
    end
    if shouldCollapse then
        CallWidgetMethodSecurely(header, "SetHeight", COLLAPSED_HEADER_HEIGHT)
    end
end

local function GetTopAnchor(frame, relativeTo)
    if not frame or type(frame.GetNumPoints) ~= "function" or type(frame.GetPoint) ~= "function" then return end

    local ok, pointCount = pcall(frame.GetNumPoints, frame)
    if not ok or type(pointCount) ~= "number" then return end

    for index = 1, pointCount do
        local pointOk, point, anchorTo, relativePoint, offsetX, offsetY = pcall(frame.GetPoint, frame, index)
        if pointOk and point == "TOP" and anchorTo == relativeTo then
            return point, anchorTo, relativePoint, offsetX or 0, offsetY or 0
        end
    end
end

local function MoveFirstModuleToTop(tracker)
    local modules = tracker and tracker.modules
    if type(modules) ~= "table" then return end

    for _, module in ipairs(modules) do
        local point, relativeTo, relativePoint, offsetX, offsetY = GetTopAnchor(module, tracker)
        if point then
            if not managedModuleAnchors[module] then
                managedModuleAnchors[module] = {
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    offsetX = offsetX,
                    offsetY = offsetY,
                }
            end
            if offsetY ~= 0 then
                CallWidgetMethodSecurely(module, "SetPoint", point, relativeTo, relativePoint, offsetX, 0)
            end
            return
        end
    end
end

local function CollapseQuestModuleHeight(module, removedHeight)
    if not module or not removedHeight or removedHeight <= 0 then return end
    if type(module.GetHeight) ~= "function" then return end

    local ok, currentHeight = pcall(module.GetHeight, module)
    if not ok or type(currentHeight) ~= "number" then return end

    local state = managedModuleHeights[module]
    if state and currentHeight == state.appliedHeight then return end

    local collapsedHeight = math.max(COLLAPSED_HEADER_HEIGHT, currentHeight - removedHeight)
    managedModuleHeights[module] = {
        originalHeight = currentHeight,
        appliedHeight = collapsedHeight,
    }
    CallWidgetMethodSecurely(module, "SetHeight", collapsedHeight)
end

local function RestoreHeaders()
    for frame, alpha in pairs(originalAlphas) do
        SetAlphaSecurely(frame, alpha)
        originalAlphas[frame] = nil
    end

    for frame, height in pairs(originalHeights) do
        CallWidgetMethodSecurely(frame, "SetHeight", height)
        originalHeights[frame] = nil
    end

    for module, state in pairs(managedModuleHeights) do
        if type(module.GetHeight) == "function" then
            local ok, currentHeight = pcall(module.GetHeight, module)
            if ok and currentHeight == state.appliedHeight then
                CallWidgetMethodSecurely(module, "SetHeight", state.originalHeight)
            end
        end
        managedModuleHeights[module] = nil
    end

    for module, anchor in pairs(managedModuleAnchors) do
        local point, relativeTo = GetTopAnchor(module, anchor.relativeTo)
        if point and relativeTo == anchor.relativeTo then
            CallWidgetMethodSecurely(
                module,
                "SetPoint",
                anchor.point,
                anchor.relativeTo,
                anchor.relativePoint,
                anchor.offsetX,
                anchor.offsetY
            )
        end
        managedModuleAnchors[module] = nil
    end
end

local function ApplyQuestTrackerTitleVisibility()
    if InCombatLockdown and InCombatLockdown() then
        pendingCombatApply = true
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    pendingCombatApply = false
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    if not IsEnabled() then
        RestoreHeaders()
        return
    end

    local tracker = _G.ObjectiveTrackerFrame
    local questTracker = _G.QuestObjectiveTracker

    for _, header in ipairs(GetQuestTrackerHeaders()) do
        CollapseHeader(header)
    end

    MoveFirstModuleToTop(tracker)
    CollapseQuestModuleHeight(questTracker, questTracker and originalHeights[questTracker.Header])
end

local function EnsureTrackerUpdateHook()
    if type(hooksecurefunc) ~= "function" then return end

    local containerMixin = _G.ObjectiveTrackerContainerMixin
    if not containerUpdateHookInstalled
        and type(containerMixin) == "table"
        and type(containerMixin.Update) == "function"
    then
        local ok = pcall(hooksecurefunc, containerMixin, "Update", function(container)
            if container == _G.ObjectiveTrackerFrame and IsEnabled() then
                ApplyQuestTrackerTitleVisibility()
            end
        end)
        if ok then
            containerUpdateHookInstalled = true
        end
    end

    local questModule = _G.QuestObjectiveTracker or _G.QUEST_TRACKER_MODULE
    if questModule
        and not hookedQuestModules[questModule]
        and type(questModule.UpdateHeight) == "function"
    then
        local ok = pcall(hooksecurefunc, questModule, "UpdateHeight", function()
            if IsEnabled() then
                ApplyQuestTrackerTitleVisibility()
            end
        end)
        if ok then
            hookedQuestModules[questModule] = true
        end
    end

    -- Older tracker implementations do not expose the shared mixins. Their
    -- updates resolve the frame method dynamically, so a frame hook remains a
    -- useful compatibility fallback.
    local tracker = _G.ObjectiveTrackerFrame
    if containerUpdateHookInstalled
        or not tracker
        or hookedTrackers[tracker]
        or type(tracker.Update) ~= "function"
    then
        return
    end

    local ok = pcall(hooksecurefunc, tracker, "Update", function()
        if IsEnabled() then
            ApplyQuestTrackerTitleVisibility()
        end
    end)
    if ok then
        hookedTrackers[tracker] = true
    end
end

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED"
        and loadedAddonName ~= "Blizzard_ObjectiveTracker"
        and loadedAddonName ~= "Blizzard_QuestObjectiveTracker"
    then
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not pendingCombatApply then return end

    EnsureTrackerUpdateHook()
    ApplyQuestTrackerTitleVisibility()
end)

local feature = {}

function feature:Enable()
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    EnsureTrackerUpdateHook()
    ApplyQuestTrackerTitleVisibility()
end

function feature:Disable()
    eventFrame:UnregisterAllEvents()
    ApplyQuestTrackerTitleVisibility()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
