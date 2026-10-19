--[[ Carpenter - Hide Quest Tracker Titles ]]
-- Hides the Objective Tracker's container and quest-module headers and
-- reclaims their layout space without changing protected visibility state.

local FEATURE_KEY = "hideQuestTrackerTitlesEnabled"
local COLLAPSED_HEADER_HEIGHT = 0.001
local MODULE_HEIGHT_MODIFIER = "CarpenterHiddenHeader"
local secureCallFunction = securecallfunction
local originalAlphas = setmetatable({}, { __mode = "k" })
local originalHeights = setmetatable({}, { __mode = "k" })
local originalVertexColors = setmetatable({}, { __mode = "k" })
local managedModuleHeights = setmetatable({}, { __mode = "k" })
local managedModuleAnchors = setmetatable({}, { __mode = "k" })
local hookedTrackers = setmetatable({}, { __mode = "k" })
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

local function GetQuestTrackerModules()
    local modules = {}
    local seen = {}

    local function AddModule(module)
        if module and not seen[module] then
            seen[module] = true
            modules[#modules + 1] = module
        end
    end

    AddModule(_G.QuestObjectiveTracker)
    AddModule(_G.QUEST_TRACKER_MODULE)

    local client = Carpenter and Carpenter.Client
    if not (client and client.isForever) then
        AddModule(_G.CampaignQuestObjectiveTracker)
        AddModule(_G.CAMPAIGN_QUEST_TRACKER_MODULE)
    end

    return modules
end

local function GetQuestTrackerHeaders()
    local frames = {}
    local seen = {}
    local tracker = _G.ObjectiveTrackerFrame
    local blocksFrame = _G.ObjectiveTrackerBlocksFrame or (tracker and tracker.BlocksFrame)

    -- Current Objective Tracker layout.
    AddUniqueFrame(frames, seen, tracker and tracker.Header)
    for _, module in ipairs(GetQuestTrackerModules()) do
        AddUniqueFrame(frames, seen, module.Header)
    end

    -- Dragonflight-era and Classic-compatible layouts.
    AddUniqueFrame(frames, seen, tracker and tracker.HeaderMenu)
    AddUniqueFrame(frames, seen, blocksFrame and blocksFrame.QuestHeader)

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

    local layoutHeaderHeight = module.headerHeight
    if type(layoutHeaderHeight) ~= "number" or layoutHeaderHeight <= 0 then
        layoutHeaderHeight = removedHeight
    end

    local state = managedModuleHeights[module]
    if type(module.SetHeightModifier) == "function"
        and type(module.ClearHeightModifier) == "function"
    then
        if state and state.usesHeightModifier and state.removedHeight == layoutHeaderHeight then return end

        managedModuleHeights[module] = {
            usesHeightModifier = true,
            removedHeight = layoutHeaderHeight,
        }
        CallWidgetMethodSecurely(module, "SetHeightModifier", MODULE_HEIGHT_MODIFIER, -layoutHeaderHeight)
        return
    end

    local ok, currentHeight = pcall(module.GetHeight, module)
    if not ok or type(currentHeight) ~= "number" then return end

    if state and math.abs(currentHeight - state.appliedHeight) < 0.5 then return end

    local collapsedHeight = math.max(COLLAPSED_HEADER_HEIGHT, currentHeight - layoutHeaderHeight)
    managedModuleHeights[module] = {
        originalHeight = currentHeight,
        appliedHeight = collapsedHeight,
    }
    CallWidgetMethodSecurely(module, "SetHeight", collapsedHeight)
end

-- The Professions section keeps its "Professions" headline but loses the
-- header bar art behind it. Blizzard's add animation fades that texture's
-- alpha in whenever a recipe is first tracked, so it's hidden through its
-- vertex color, which nothing else touches.
local function GetHeaderBackgrounds()
    local tracker = _G.ProfessionsRecipeTracker
    local background = tracker and tracker.Header and tracker.Header.Background
    return background and { background } or {}
end

-- TEMP professions header probe: logs the header's state to
-- CarpenterDB.trackerProbeLog. Remove once the header art hides on Forever.
local function ProbeTrackerText(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return "S" end
    end
    if value == nil then return "-" end
    local ok, text = pcall(tostring, value)
    return ok and text or "?"
end

local function ProbeProfessionsHeader(stage)
    if type(CarpenterDB) ~= "table" then return end
    local log = CarpenterDB.trackerProbeLog
    if type(log) ~= "table" then
        log = {}
        CarpenterDB.trackerProbeLog = log
    end
    if #log >= 60 then return end
    pcall(function()
        local tracker = _G.ProfessionsRecipeTracker
        local header = tracker and tracker.Header
        local background = header and header.Background
        local line = stage .. " tracker=" .. ProbeTrackerText(tracker ~= nil) .. " header=" .. ProbeTrackerText(header ~= nil)
            .. " bg=" .. ProbeTrackerText(background ~= nil)
        if background then
            local r, g, b, a = background:GetVertexColor()
            line = line .. " atlas=" .. ProbeTrackerText(background.GetAtlas and background:GetAtlas())
                .. " vc=" .. ProbeTrackerText(r) .. "," .. ProbeTrackerText(g) .. "," .. ProbeTrackerText(b) .. "," .. ProbeTrackerText(a)
                .. " alpha=" .. ProbeTrackerText(background:GetAlpha()) .. " shown=" .. ProbeTrackerText(background:IsShown())
                .. " visible=" .. ProbeTrackerText(background:IsVisible())
        end
        if header then
            line = line .. " headerShown=" .. ProbeTrackerText(header:IsShown()) .. " text=" .. ProbeTrackerText(header.Text and header.Text:GetText())
            local regions = {}
            for _, region in ipairs({ header:GetRegions() }) do
                regions[#regions + 1] = ProbeTrackerText(region.GetAtlas and region:GetAtlas() or region:GetObjectType())
            end
            line = line .. " regions=" .. table.concat(regions, ";")
        end
        log[#log + 1] = (date and date("%H:%M:%S ") or "") .. line
    end)
end

local function HideHeaderBackgrounds()
    ProbeProfessionsHeader("before")
    for _, background in ipairs(GetHeaderBackgrounds()) do
        if originalVertexColors[background] == nil and type(background.GetVertexColor) == "function" then
            local ok, r, g, b, a = pcall(background.GetVertexColor, background)
            if ok then originalVertexColors[background] = { r or 1, g or 1, b or 1, a or 1 } end
        end
        local color = originalVertexColors[background] or { 1, 1, 1, 1 }
        CallWidgetMethodSecurely(background, "SetVertexColor", color[1], color[2], color[3], 0)
    end
    ProbeProfessionsHeader("after")
end

local function RestoreHeaders()
    for background, color in pairs(originalVertexColors) do
        CallWidgetMethodSecurely(background, "SetVertexColor", color[1], color[2], color[3], color[4])
        originalVertexColors[background] = nil
    end

    for frame, alpha in pairs(originalAlphas) do
        SetAlphaSecurely(frame, alpha)
        originalAlphas[frame] = nil
    end

    for frame, height in pairs(originalHeights) do
        CallWidgetMethodSecurely(frame, "SetHeight", height)
        originalHeights[frame] = nil
    end

    for module, state in pairs(managedModuleHeights) do
        if state.usesHeightModifier then
            CallWidgetMethodSecurely(module, "ClearHeightModifier", MODULE_HEIGHT_MODIFIER)
        elseif type(module.GetHeight) == "function" then
            local ok, currentHeight = pcall(module.GetHeight, module)
            if ok and math.abs(currentHeight - state.appliedHeight) < 0.5 then
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
    for _, header in ipairs(GetQuestTrackerHeaders()) do
        CollapseHeader(header)
    end

    MoveFirstModuleToTop(tracker)
    for _, module in ipairs(GetQuestTrackerModules()) do
        CollapseQuestModuleHeight(module, module.Header and originalHeights[module.Header])
    end
    HideHeaderBackgrounds()
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
