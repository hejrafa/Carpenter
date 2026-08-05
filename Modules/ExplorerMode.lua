--[[ Carpenter - Explorer Mode ]]
-- Slowly fades the main HUD while out of combat, leaving the minimap alone.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ExplorerMode = ns.Private.ExplorerMode or {}
ns.Private.ExplorerMode = ExplorerMode
local TrackingBars = ns.Private.StatusTrackingBars or {}

local FEATURE_KEY = "explorerModeEnabled"
local EXPLORING_ALPHA = 0
local VISIBLE_ALPHA = 1
local FADE_OUT_DELAY_SECONDS = 1
local FADE_OUT_SECONDS = 2.8
local HOVER_FADE_IN_SECONDS = 0.45
local HOVER_FADE_OUT_DELAY_SECONDS = 1
local HOVER_FADE_OUT_SECONDS = 0.75
local HOVER_UPDATE_INTERVAL = 0.2
local ACTION_BUTTON_REFRESH_THROTTLE_SECONDS = 0.15
local CHAT_REPAIR_VERSION = 1
local ACTION_BAR_CLUSTER_KEY = "actionBarCluster"
local ACTION_BUTTON_FADE_KEY = {}

local frame = CreateFrame("Frame")
local actionBarFrame = CreateFrame("Frame")
local managedFrames = {}
local managedAlphas = {}
local frameTargets = {}
local activeFades = {}
local hoverFadeOutAt = {}
local explorerFaded = false
local actionButtonTargetAlpha = nil
local IsShownFrame
local actionButtonOverlayHooksInstalled = false
local actionButtonCooldownHookedFrames = {}
local actionButtonCooldownDrawStates = {}
local actionButtonRefreshQueued = false
local lastActionButtonRefreshAt = 0
local editModeCallbacksRegistered = false
local editModeHooksInstalled = false
local registeredEvents = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "QUEST_WATCH_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
}

local actionBarRefreshEvents = {
    ACTIONBAR_PAGE_CHANGED = true,
    UPDATE_BONUS_ACTIONBAR = true,
    UPDATE_OVERRIDE_ACTIONBAR = true,
    UPDATE_VEHICLE_ACTIONBAR = true,
}

local registeredUnitEvents = {
    "UNIT_HEALTH",
    "UNIT_HEALTH_FREQUENT",
    "UNIT_MAXHEALTH",
}

local frameNames = {
    -- Unit frames
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "FocusFrame",
    "FocusFrameToT",
    "PartyFrame",
    "CompactPartyFrame",
    "CompactRaidFrameContainer",
    -- Action bars and buttons
    "MainMenuBar",
    "MainMenuBarArtFrame",
    "MainMenuBarVehicleLeaveButton",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "StanceBar",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PetActionBarFrame",
    "PossessBarFrame",
    "OverrideActionBar",
    "ExtraActionBarFrame",
    "ZoneAbilityFrame",
    -- Quest and watch frames
    "QuestWatchFrame",
    "WatchFrame",
    "ObjectiveTrackerFrame",
    -- Player buffs, casting, and status HUD
    "BuffFrame",
    "TemporaryEnchantFrame",
    "DebuffFrame",
    "PlayerBuffFrame",
    "DurabilityFrame",
    "VehicleSeatIndicator",
}

local classicOrTBCBottomBarFrameNames = {
    -- Classic/TBC action bar art and page controls
    "MainMenuBarArtFrame",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MainMenuBarPageNumber",
    -- Micro menu and bag containers
    "MicroButtonAndBagsBar",
    "MicroMenuContainer",
    "BagsBar",
    "BagBarExpandToggle",
    -- Bag buttons
    "MainMenuBarBackpackButton",
    "KeyRingButton",
    "KeyringButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
    -- Micro menu buttons
    "MainMenuBarPerformanceBar",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "ProfessionMicroButton",
    "QuestLogMicroButton",
    "AchievementMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "PVPMicroButton",
    "LFGMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
}

local repeatedFramePrefixes = {
    { prefix = "PartyMemberFrame", suffix = "", count = 4 },
    { prefix = "PartyMemberFrame", suffix = "PetFrame", count = 4 },
    { prefix = "Boss", suffix = "TargetFrame", count = 8 },
    { prefix = "ArenaEnemyFrame", suffix = "", count = 5 },
}

local unitFramePieces = {
    "PlayerFrameHealthBar",
    "PlayerFrameManaBar",
    "PlayerFrameAlternateManaBar",
    "PlayerFrameTexture",
    "PlayerName",
    "PlayerLevelText",
    "PlayerPVPIcon",
    "PlayerLeaderIcon",
    "PlayerMasterIcon",
    "TargetFrameHealthBar",
    "TargetFrameManaBar",
    "TargetFrameTextureFrame",
    "TargetFrameNameBackground",
    "TargetFrameTextureFrameName",
    "TargetFrameTextureFrameLevelText",
    "TargetFrameTextureFramePVPIcon",
    "FocusFrameHealthBar",
    "FocusFrameManaBar",
    "FocusFrameTextureFrame",
    "FocusFrameNameBackground",
    "FocusFrameTextureFrameName",
    "FocusFrameTextureFrameLevelText",
}

local minimapClutterFrameNames = {
    Minimap = true,
    MinimapCluster = true,
    MiniMapLFGFrame = true,
    MinimapLFGFrame = true,
    LFGMinimapFrame = true,
    LFGMinimapButton = true,
    LookingForGroupMinimapButton = true,
    QueueStatusMinimapButton = true,
    MiniMapTracking = true,
    MiniMapTrackingFrame = true,
    MiniMapTrackingButton = true,
    MinimapZoneTextButton = true,
    MinimapZoneText = true,
    MinimapZoneTextButtonLeft = true,
    MinimapZoneTextButtonMiddle = true,
    MinimapZoneTextButtonRight = true,
    MinimapBorderTop = true,
    GameTimeFrame = true,
    GameTimeCalendarInvitesTexture = true,
    TimeManagerClockButton = true,
    TimeManagerClockTicker = true,
    TimeManagerClockButtonText = true,
    TimeManagerClockButtonBackground = true,
    TimeManagerClockButtonLeft = true,
    TimeManagerClockButtonMiddle = true,
    TimeManagerClockButtonRight = true,
    AddonCompartmentFrame = true,
}

local actionButtonOverlayFunctions = {
    "ActionButton_ShowOverlayGlow",
    "ActionButton_ShowCooldownFlash",
    "ActionButton_StartFlash",
    "ActionButton_UpdateCooldown",
}

local actionButtonRefreshFunctions = {
    "ActionButton_Update",
    "ActionButton_UpdateAction",
    "ActionButton_UpdateState",
}

local cooldownFrameFunctions = {
    "CooldownFrame_Set",
    "CooldownFrame_SetTimer",
}

local actionButtonGroups = {
    { prefix = "ActionButton", count = 12 },
    { prefix = "BonusActionButton", count = 12 },
    { prefix = "MultiBarBottomLeftButton", count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "MultiBarRightButton", count = 12 },
    { prefix = "MultiBarLeftButton", count = 12 },
    { prefix = "MultiBar5Button", count = 12 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "StanceButton", count = 10 },
    { prefix = "ShapeshiftButton", count = 10 },
    { prefix = "PossessButton", count = 2 },
    { prefix = "OverrideActionBarButton", count = 6 },
    { prefix = "ExtraActionButton", count = 1 },
}

local actionButtonNames = {
    "ZoneAbilityFrame",
}

local actionBarManagedFrameNames = {
    MainMenuBar = true,
    MainMenuBarArtFrame = true,
    MainMenuBarVehicleLeaveButton = true,
    MultiBarBottomLeft = true,
    MultiBarBottomRight = true,
    MultiBarRight = true,
    MultiBarLeft = true,
    MultiBar5 = true,
    StanceBar = true,
    StanceBarFrame = true,
    ShapeshiftBarFrame = true,
    PetActionBarFrame = true,
    PossessBarFrame = true,
    OverrideActionBar = true,
    ExtraActionBarFrame = true,
    ZoneAbilityFrame = true,
}

local classicOrTBCActionBarVisualFrameNames = {
    MainMenuBarArtFrame = true,
}

local actionBarClusterFrameNames = {
    MainMenuBar = true,
    MainMenuBarArtFrame = true,
    MainMenuBarVehicleLeaveButton = true,
    MultiBarBottomLeft = true,
    MultiBarBottomRight = true,
    MultiBarRight = true,
    MultiBarLeft = true,
    MultiBar5 = true,
    StanceBar = true,
    StanceBarFrame = true,
    ShapeshiftBarFrame = true,
    PetActionBarFrame = true,
    PossessBarFrame = true,
    OverrideActionBar = true,
    ExtraActionBarFrame = true,
    ZoneAbilityFrame = true,
}

for _, name in ipairs(classicOrTBCBottomBarFrameNames) do
    actionBarClusterFrameNames[name] = true
end

local actionButtonNamePatterns = {
    "^ActionButton%d+$",
    "^BonusActionButton%d+$",
    "^MultiBarBottomLeftButton%d+$",
    "^MultiBarBottomRightButton%d+$",
    "^MultiBarRightButton%d+$",
    "^MultiBarLeftButton%d+$",
    "^MultiBar5Button%d+$",
    "^PetActionButton%d+$",
    "^StanceButton%d+$",
    "^ShapeshiftButton%d+$",
    "^PossessButton%d+$",
    "^OverrideActionBarButton%d+$",
    "^ExtraActionButton%d+$",
    "^ZoneAbilityFrame$",
}

local actionButtonCooldownKeys = {
    "cooldown",
    "Cooldown",
    "chargeCooldown",
    "ChargeCooldown",
    "IconCooldown",
}

local cooldownDrawMethods = {
    { getter = "GetDrawSwipe", setter = "SetDrawSwipe", fallback = true },
    { getter = "GetDrawBling", setter = "SetDrawBling", fallback = true },
    { getter = "GetDrawEdge", setter = "SetDrawEdge", fallback = true },
}

local function NormalizeChatWindowName(name)
    return tostring(name or ""):lower():gsub("%s+", "")
end

local function IsDefaultChatWindowName(index, name)
    local normalizedName = NormalizeChatWindowName(name)
    if normalizedName == "" or normalizedName == tostring(index) then
        return true
    end

    local defaults = {
        "ChatFrame" .. index,
        "Chat " .. index,
        "Window " .. index,
        "Chat Window " .. index,
        _G["CHAT_WINDOW_" .. index],
    }

    local function AddFormattedDefault(template)
        if not template then return end
        local ok, formattedName = pcall(string.format, template, index)
        if ok then
            defaults[#defaults + 1] = formattedName
        end
    end

    AddFormattedDefault(CHAT_NAME_TEMPLATE)
    AddFormattedDefault(CHAT_WINDOW_NAME_TEMPLATE)

    for _, defaultName in ipairs(defaults) do
        if defaultName and normalizedName == NormalizeChatWindowName(defaultName) then
            return true
        end
    end

    return false
end

local function GetChatWindowShown(index)
    if GetChatWindowInfo then
        local ok, name, fontSize, r, g, b, alpha, shown = pcall(GetChatWindowInfo, index)
        if ok then
            return shown == true
        end
    end

    local chatFrame = _G["ChatFrame" .. index]
    return chatFrame and IsShownFrame(chatFrame)
end

local function GetChatWindowName(index)
    if GetChatWindowInfo then
        local ok, name = pcall(GetChatWindowInfo, index)
        if ok then
            return name
        end
    end
    return nil
end

local function CloseChatWindow(index)
    local chatFrame = _G["ChatFrame" .. index]

    if FCF_Close and chatFrame then
        pcall(FCF_Close, chatFrame)
    end

    if SetChatWindowShown then
        pcall(SetChatWindowShown, index, false)
    end

    if chatFrame and chatFrame.Hide then
        pcall(chatFrame.Hide, chatFrame)
    end

    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab and tab.Hide then
        pcall(tab.Hide, tab)
    end
end

local function RepairAccidentalChatWindows()
    if not CarpenterDB or CarpenterDB.explorerModeChatWindowRepairVersion == CHAT_REPAIR_VERSION then
        return
    end

    if Carpenter and Carpenter.Client and Carpenter.Client.isClassic then
        for index = 4, 10 do
            if GetChatWindowShown(index) and IsDefaultChatWindowName(index, GetChatWindowName(index)) then
                CloseChatWindow(index)
            end
        end
    end

    CarpenterDB.explorerModeChatWindowRepairVersion = CHAT_REPAIR_VERSION
end

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

function ExplorerMode.IsFaded()
    return IsEnabled() and explorerFaded == true
end

local function IsClassicOrTBCClient()
    local client = Carpenter and Carpenter.Client
    return client and (client.isVanilla or client.isTBC or client.isClassic)
end

local function IsEditModeSupportedClient()
    local client = Carpenter and Carpenter.Client
    return client and (client.isRetail or client.isTBC)
end

local function IsForbiddenFrame(frameObject)
    if not frameObject or not frameObject.IsForbidden then
        return false
    end
    local ok, forbidden = pcall(frameObject.IsForbidden, frameObject)
    return ok and forbidden
end

local function SafeGetFrameName(frameObject)
    if not frameObject or not frameObject.GetName then
        return nil
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    return ok and name or nil
end

local function IsMinimapClutterFrame(frameObject)
    local current = frameObject
    local depth = 0

    while current and depth <= 8 do
        local name = SafeGetFrameName(current)
        if name and minimapClutterFrameNames[name] then
            return true
        end

        if current == Minimap or current == _G.MinimapCluster then
            return true
        end

        if not current.GetParent then
            return false
        end

        local ok, parent = pcall(current.GetParent, current)
        if not ok then
            return false
        end

        current = parent
        depth = depth + 1
    end

    return false
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsGameEditModeActive()
    if not IsEditModeSupportedClient() then
        return false
    end

    local editMode = _G.EditModeManagerFrame
    if not editMode then
        return false
    end

    if editMode.IsEditModeActive then
        local ok, active = pcall(editMode.IsEditModeActive, editMode)
        if ok then
            return active == true
        end
    end

    if editMode.editModeActive ~= nil then
        return editMode.editModeActive == true
    end

    return false
end

local function GetPlayerHealthBar()
    local Unit = ns and ns.Private and ns.Private.Unit
    return Unit and Unit.FrameHealthBar and Unit.FrameHealthBar("player") or nil
end

local function IsPlayerHealthBarFull()
    local healthBar = GetPlayerHealthBar()
    if not (healthBar and healthBar.GetValue and healthBar.GetMinMaxValues) then
        return nil
    end

    local ok, fullHealth = pcall(function()
        local value = healthBar:GetValue() or 0
        local _, maxValue = healthBar:GetMinMaxValues()
        maxValue = maxValue or 0
        if maxValue <= 0 then
            return true
        end

        return value >= maxValue
    end)

    if ok then
        return fullHealth == true
    end
    return nil
end

local function IsPlayerAtFullHealth()
    if not UnitHealth or not UnitHealthMax then
        return true
    end

    local ok, fullHealth = pcall(function()
        local maxHealth = UnitHealthMax("player") or 0
        if maxHealth <= 0 then
            return true
        end

        return (UnitHealth("player") or 0) >= maxHealth
    end)

    if ok then
        return fullHealth == true
    end

    local barFullHealth = IsPlayerHealthBarFull()
    if barFullHealth ~= nil then
        return barFullHealth
    end

    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

function IsShownFrame(frameObject)
    if not frameObject or not frameObject.IsShown then
        return true
    end
    local ok, shown = pcall(frameObject.IsShown, frameObject)
    return ok and shown
end

local function IsMouseOverFrame(frameObject)
    if not frameObject or not IsShownFrame(frameObject) then
        return false
    end

    if MouseIsOver then
        local ok, hovering = pcall(MouseIsOver, frameObject)
        if ok then
            return hovering == true
        end
    end

    if frameObject.IsMouseOver then
        local ok, hovering = pcall(frameObject.IsMouseOver, frameObject)
        return ok and hovering == true
    end

    return false
end

local function IsManagedAncestorHovered(frameObject)
    if not frameObject or not frameObject.GetParent then
        return false
    end

    local ok, parent = pcall(frameObject.GetParent, frameObject)
    while ok and parent do
        if managedFrames[parent] and IsMouseOverFrame(parent) then
            return true
        end
        if not parent.GetParent then
            return false
        end
        ok, parent = pcall(parent.GetParent, parent)
    end

    return false
end

local function SafeAlphaValue(value, fallback)
    fallback = fallback or VISIBLE_ALPHA

    local ok, alpha = pcall(function()
        if value == nil then
            return fallback
        end
        if value < 0 then
            return 0
        end
        if value > 1 then
            return 1
        end
        return value
    end)

    return ok and alpha or fallback
end

local function ReadFrameAlpha(frameObject, fallback)
    fallback = fallback or VISIBLE_ALPHA
    if not (frameObject and frameObject.GetAlpha) then
        return fallback
    end

    local ok, alpha = pcall(frameObject.GetAlpha, frameObject)
    if not ok then
        return fallback
    end

    return SafeAlphaValue(alpha, fallback)
end

local function AddManagedFrame(frameObject)
    if not frameObject or IsForbiddenFrame(frameObject) or IsMinimapClutterFrame(frameObject) or not frameObject.SetAlpha then
        return
    end

    if not managedFrames[frameObject] then
        managedAlphas[frameObject] = ReadFrameAlpha(frameObject, VISIBLE_ALPHA)
        managedFrames[frameObject] = true
    end
end

local function AddFrameByName(name)
    AddManagedFrame(_G[name])
end

local function RefreshManagedFrames()
    for _, name in ipairs(frameNames) do
        AddFrameByName(name)
    end

    if TrackingBars.ForEachRoot then
        TrackingBars.ForEachRoot(AddManagedFrame, true)
    end

    if IsClassicOrTBCClient() then
        for _, name in ipairs(classicOrTBCBottomBarFrameNames) do
            AddFrameByName(name)
        end
    end

    for _, name in ipairs(unitFramePieces) do
        AddFrameByName(name)
    end

    for _, group in ipairs(repeatedFramePrefixes) do
        for i = 1, group.count do
            AddFrameByName(group.prefix .. i .. group.suffix)
        end
    end
end

local function RememberAlpha(object)
    if not object or managedAlphas[object] or not object.GetAlpha then
        return
    end

    managedAlphas[object] = ReadFrameAlpha(object, VISIBLE_ALPHA)
end

local function SafeSetAlpha(object, alpha)
    if not object or not object.SetAlpha then
        return
    end
    if IsForbiddenFrame(object) then
        return
    end
    RememberAlpha(object)
    pcall(object.SetAlpha, object, alpha)
end

local function TargetAlphaForObject(object, targetAlpha)
    local originalAlpha = SafeAlphaValue(managedAlphas[object], VISIBLE_ALPHA)
    if targetAlpha == VISIBLE_ALPHA then
        return originalAlpha
    end
    return math.min(originalAlpha, SafeAlphaValue(targetAlpha, EXPLORING_ALPHA))
end

local function GetManagedTargetForFrame(frameObject)
    local current = frameObject
    while current do
        if managedFrames[current] then
            return frameTargets[current], current
        end
        if not current.GetParent then
            return nil, nil
        end
        local ok, parent = pcall(current.GetParent, current)
        if not ok then
            return nil, nil
        end
        current = parent
    end

    return nil, nil
end

local ApplyActionButtonOverlayAlpha
local RefreshActionButtonCooldownHooks
local FadeActionButtonVisuals

local function IsKnownActionButtonName(name)
    if not name then
        return false
    end

    for _, pattern in ipairs(actionButtonNamePatterns) do
        if name:match(pattern) then
            return true
        end
    end

    return false
end

local function IsActionButtonFrame(frameObject)
    if not frameObject or not frameObject.GetName then
        return false
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    return ok and IsKnownActionButtonName(name)
end

local function FindActionButtonAncestor(frameObject)
    local current = frameObject
    local depth = 0
    while current and depth <= 8 do
        if IsActionButtonFrame(current) then
            return current
        end
        if not current.GetParent then
            return nil
        end
        local ok, parent = pcall(current.GetParent, current)
        if not ok then
            return nil
        end
        current = parent
        depth = depth + 1
    end

    return nil
end

local function ForEachActionButton(callback)
    for _, group in ipairs(actionButtonGroups) do
        for i = 1, group.count do
            local button = _G[group.prefix .. i]
            if button then
                callback(button)
            end
        end
    end

    for _, name in ipairs(actionButtonNames) do
        local button = _G[name]
        if button then
            callback(button)
        end
    end
end

local function GetFrameName(frameObject)
    if not frameObject or not frameObject.GetName then
        return nil
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    return ok and name or nil
end

local function IsNamedFrameInSet(frameObject, nameSet)
    local name = GetFrameName(frameObject)
    return name and nameSet[name] == true
end

local function IsActionBarManagedFrame(frameObject)
    if IsClassicOrTBCClient() and IsNamedFrameInSet(frameObject, classicOrTBCActionBarVisualFrameNames) then
        return false
    end

    return IsNamedFrameInSet(frameObject, actionBarManagedFrameNames)
end

local function IsActionBarClusterFrame(frameObject)
    return IsNamedFrameInSet(frameObject, actionBarClusterFrameNames)
end

local function IsCooldownFrame(frameObject)
    if not frameObject or not frameObject.SetAlpha then
        return false
    end

    return frameObject.SetCooldown or frameObject.SetDrawSwipe or frameObject.SetDrawBling
end

local function GetCooldownDrawValue(cooldown, method)
    if cooldown[method.getter] then
        local ok, value = pcall(cooldown[method.getter], cooldown)
        if ok then
            return value == true
        end
    end

    return method.fallback
end

local function SetCooldownDrawValue(cooldown, method, value)
    if cooldown[method.setter] then
        pcall(cooldown[method.setter], cooldown, value)
    end
end

local function RememberCooldownDrawState(cooldown)
    local state = actionButtonCooldownDrawStates[cooldown]
    if state then
        return state
    end

    state = {}
    actionButtonCooldownDrawStates[cooldown] = state

    for _, method in ipairs(cooldownDrawMethods) do
        if cooldown[method.setter] then
            state[method.setter] = GetCooldownDrawValue(cooldown, method)
        end
    end

    return state
end

local function RestoreCooldownDrawState(cooldown, state)
    if not cooldown or IsForbiddenFrame(cooldown) then
        return
    end

    state = state or actionButtonCooldownDrawStates[cooldown]
    if not state then
        return
    end

    for _, method in ipairs(cooldownDrawMethods) do
        if state[method.setter] ~= nil then
            SetCooldownDrawValue(cooldown, method, state[method.setter])
        end
    end
end

local function RestoreActionButtonCooldownDrawStates()
    for cooldown, state in pairs(actionButtonCooldownDrawStates) do
        RestoreCooldownDrawState(cooldown, state)
        actionButtonCooldownDrawStates[cooldown] = nil
    end
end

local function ApplyCooldownDrawState(cooldown, targetAlpha)
    if not IsCooldownFrame(cooldown) or IsForbiddenFrame(cooldown) then
        return
    end

    if targetAlpha == EXPLORING_ALPHA then
        RememberCooldownDrawState(cooldown)
        for _, method in ipairs(cooldownDrawMethods) do
            SetCooldownDrawValue(cooldown, method, false)
        end
    elseif actionButtonCooldownDrawStates[cooldown] then
        RestoreCooldownDrawState(cooldown)
        actionButtonCooldownDrawStates[cooldown] = nil
    end
end

local function AddCooldownFrame(cooldowns, frameObject)
    if IsCooldownFrame(frameObject) then
        cooldowns[frameObject] = true
    end
end

local function CollectCooldownChildren(root, cooldowns, depth)
    if not root or depth > 3 or IsForbiddenFrame(root) then
        return
    end

    AddCooldownFrame(cooldowns, root)

    if root.GetChildren then
        for i = 1, root:GetNumChildren() do
            CollectCooldownChildren(select(i, root:GetChildren()), cooldowns, depth + 1)
        end
    end
end

local function CollectActionButtonCooldownFrames(button, cooldowns)
    if not button then
        return
    end

    for _, key in ipairs(actionButtonCooldownKeys) do
        AddCooldownFrame(cooldowns, button[key])
    end

    if button.GetName then
        local ok, name = pcall(button.GetName, button)
        if ok and name then
            AddCooldownFrame(cooldowns, _G[name .. "Cooldown"])
        end
    end

    CollectCooldownChildren(button, cooldowns, 0)
end

local function CollectAlphaTargets(root, starts, targets, targetAlpha, depth)
    if not root or depth > 4 then
        return
    end
    if IsForbiddenFrame(root) or IsMinimapClutterFrame(root) then
        return
    end

    if root.SetAlpha then
        RememberAlpha(root)
        local target = TargetAlphaForObject(root, targetAlpha)
        starts[root] = ReadFrameAlpha(root, target)
        targets[root] = TargetAlphaForObject(root, targetAlpha)
    end

    if root.GetRegions then
        for i = 1, select("#", root:GetRegions()) do
            local region = select(i, root:GetRegions())
            if region and region.SetAlpha and not IsMinimapClutterFrame(region) then
                RememberAlpha(region)
                local target = TargetAlphaForObject(region, targetAlpha)
                starts[region] = ReadFrameAlpha(region, target)
                targets[region] = TargetAlphaForObject(region, targetAlpha)
            end
        end
    end

    if root.GetChildren then
        for i = 1, root:GetNumChildren() do
            CollectAlphaTargets(select(i, root:GetChildren()), starts, targets, targetAlpha, depth + 1)
        end
    end
end

local function ApplyActionButtonCooldownDrawStates(button, targetAlpha)
    local cooldowns = {}
    CollectActionButtonCooldownFrames(button, cooldowns)

    for cooldown in pairs(cooldowns) do
        ApplyCooldownDrawState(cooldown, targetAlpha)
    end
end

local function ApplyActionButtonFrameAlpha(button, targetAlpha)
    if not button or IsForbiddenFrame(button) or not button.SetAlpha then
        return
    end

    RememberAlpha(button)
    SafeSetAlpha(button, TargetAlphaForObject(button, targetAlpha))
end

function ApplyActionButtonOverlayAlpha(button, targetAlphaOverride)
    if not button then
        return
    end

    local targetAlpha = targetAlphaOverride or GetManagedTargetForFrame(button) or actionButtonTargetAlpha
    if targetAlpha == nil then
        return
    end

    if targetAlpha == EXPLORING_ALPHA and (IsInCombat() or not explorerFaded or not IsPlayerAtFullHealth()) then
        return
    end

    if IsInCombat() then
        ApplyActionButtonCooldownDrawStates(button, targetAlpha)
        return
    end

    ApplyActionButtonCooldownDrawStates(button, targetAlpha)
    ApplyActionButtonFrameAlpha(button, targetAlpha)
end

local function ClampUpdatedActionButtonAlpha(button)
    if actionButtonTargetAlpha == nil then
        return
    end
    if not (IsEnabled() and explorerFaded and not IsInCombat() and IsPlayerAtFullHealth() and not IsGameEditModeActive()) then
        return
    end

    ApplyActionButtonFrameAlpha(button, actionButtonTargetAlpha)
end

local function ApplyActionButtonVisualAlphasForManagedFrame(frameObject, targetAlpha)
    if not IsActionBarManagedFrame(frameObject) then
        return
    end

    ForEachActionButton(function(button)
        local currentTargetAlpha, managedRoot = GetManagedTargetForFrame(button)
        if managedRoot == frameObject or button == frameObject then
            ApplyActionButtonOverlayAlpha(button, targetAlpha or currentTargetAlpha)
        end
    end)
end

local function ApplyActionButtonCooldownDrawStatesForManagedFrame(frameObject, targetAlpha)
    if not IsActionBarManagedFrame(frameObject) then
        return
    end

    ForEachActionButton(function(button)
        local currentTargetAlpha, managedRoot = GetManagedTargetForFrame(button)
        if managedRoot == frameObject or button == frameObject then
            ApplyActionButtonCooldownDrawStates(button, targetAlpha or currentTargetAlpha)
        end
    end)
end

local function ApplyCooldownFrameAlpha(cooldown)
    local button = FindActionButtonAncestor(cooldown)
    if button then
        ApplyActionButtonOverlayAlpha(button)
    end
end

local function HookActionButtonCooldownFrame(cooldown)
    if not cooldown or actionButtonCooldownHookedFrames[cooldown] or not cooldown.HookScript then
        return
    end

    actionButtonCooldownHookedFrames[cooldown] = true
    pcall(cooldown.HookScript, cooldown, "OnShow", ApplyCooldownFrameAlpha)
end

function RefreshActionButtonCooldownHooks()
    ForEachActionButton(function(button)
        local cooldowns = {}
        CollectActionButtonCooldownFrames(button, cooldowns)
        for cooldown in pairs(cooldowns) do
            HookActionButtonCooldownFrame(cooldown)
        end
    end)
end

local function HookActionButtonOverlayFunctions()
    if actionButtonOverlayHooksInstalled or not hooksecurefunc then
        if RefreshActionButtonCooldownHooks then
            RefreshActionButtonCooldownHooks()
        end
        return
    end

    local hookedAny = false
    for _, functionName in ipairs(actionButtonOverlayFunctions) do
        if type(_G[functionName]) == "function" then
            local ok = pcall(hooksecurefunc, functionName, function(button)
                ApplyActionButtonOverlayAlpha(button)
            end)
            hookedAny = hookedAny or ok
        end
    end

    for _, functionName in ipairs(actionButtonRefreshFunctions) do
        if type(_G[functionName]) == "function" then
            local ok = pcall(hooksecurefunc, functionName, function(button)
                ClampUpdatedActionButtonAlpha(button)
            end)
            hookedAny = hookedAny or ok
        end
    end

    for _, functionName in ipairs(cooldownFrameFunctions) do
        if type(_G[functionName]) == "function" then
            local ok = pcall(hooksecurefunc, functionName, function(cooldown)
                ApplyCooldownFrameAlpha(cooldown)
            end)
            hookedAny = hookedAny or ok
        end
    end

    RefreshActionButtonCooldownHooks()
    actionButtonOverlayHooksInstalled = hookedAny
end

local function EaseFadeProgress(progress)
    return progress * progress * progress * (progress * ((progress * 6) - 15) + 10)
end

local function EaseFadeOutProgress(progress)
    return EaseFadeProgress(progress)
end

local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
fadeDriver:SetScript("OnUpdate", function(self, elapsed)
    local hasActiveFade = false

    for root, fade in pairs(activeFades) do
        fade.elapsed = fade.elapsed + elapsed
        local progress = fade.duration > 0 and math.min(fade.elapsed / fade.duration, 1) or 1

        for object, startAlpha in pairs(fade.starts) do
            local targetAlpha = fade.targets[object] or VISIBLE_ALPHA
            local easedProgress = EaseFadeProgress(progress)
            if targetAlpha < startAlpha then
                easedProgress = EaseFadeOutProgress(progress)
            end
            SafeSetAlpha(object, startAlpha + ((targetAlpha - startAlpha) * easedProgress))
        end

        if progress >= 1 then
            activeFades[root] = nil
        else
            hasActiveFade = true
        end
    end

    if not hasActiveFade then
        self:Hide()
    end
end)

local function FadeFrame(frameObject, targetAlpha, duration, forceApply)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha then
        return
    end

    if not forceApply and frameTargets[frameObject] == targetAlpha then
        return
    end
    frameTargets[frameObject] = targetAlpha

    if UIFrameFadeRemoveFrame and not IsInCombat() then
        pcall(UIFrameFadeRemoveFrame, frameObject)
    end

    local starts = {}
    local targets = {}
    CollectAlphaTargets(frameObject, starts, targets, targetAlpha, 0)

    if duration == nil or duration <= 0 then
        ApplyActionButtonVisualAlphasForManagedFrame(frameObject, targetAlpha)
        activeFades[frameObject] = nil
        for object, alpha in pairs(targets) do
            SafeSetAlpha(object, alpha)
        end
        return
    end

    ApplyActionButtonCooldownDrawStatesForManagedFrame(frameObject, targetAlpha)

    activeFades[frameObject] = {
        elapsed = 0,
        duration = duration,
        starts = starts,
        targets = targets,
    }
    fadeDriver:Show()
end

function FadeActionButtonVisuals(targetAlpha, duration, forceApply)
    if not forceApply and actionButtonTargetAlpha == targetAlpha then
        return
    end

    actionButtonTargetAlpha = targetAlpha
    local starts = {}
    local targets = {}

    ForEachActionButton(function(button)
        if button and not IsForbiddenFrame(button) and button.SetAlpha then
            ApplyActionButtonCooldownDrawStates(button, targetAlpha)
            local target = TargetAlphaForObject(button, targetAlpha)
            starts[button] = ReadFrameAlpha(button, target)
            targets[button] = TargetAlphaForObject(button, targetAlpha)
        end
    end)

    if duration == nil or duration <= 0 then
        activeFades[ACTION_BUTTON_FADE_KEY] = nil
        for object, alpha in pairs(targets) do
            SafeSetAlpha(object, alpha)
        end
        if targetAlpha == VISIBLE_ALPHA then
            RestoreActionButtonCooldownDrawStates()
        end
        return
    end

    activeFades[ACTION_BUTTON_FADE_KEY] = {
        elapsed = 0,
        duration = duration,
        starts = starts,
        targets = targets,
    }
    fadeDriver:Show()
end

local function ForEachActionBarClusterFrame(callback)
    for frameObject in pairs(managedFrames) do
        if IsActionBarClusterFrame(frameObject) then
            callback(frameObject)
        end
    end
end

local function IsActionBarClusterHovered()
    local hovered = false
    ForEachActionBarClusterFrame(function(frameObject)
        if not hovered and not IsActionBarManagedFrame(frameObject) and IsMouseOverFrame(frameObject) then
            hovered = true
        end
    end)

    ForEachActionButton(function(button)
        if not hovered and IsMouseOverFrame(button) then
            hovered = true
        end
    end)

    return hovered
end

local function HasVisibleActionBarClusterTarget()
    if actionButtonTargetAlpha == VISIBLE_ALPHA then
        return true
    end

    local visible = false
    ForEachActionBarClusterFrame(function(frameObject)
        if frameTargets[frameObject] == VISIBLE_ALPHA then
            visible = true
        end
    end)

    return visible
end

local function HasVisibleHoverTarget()
    if HasVisibleActionBarClusterTarget() then
        return true
    end

    for frameObject in pairs(managedFrames) do
        if not IsActionBarClusterFrame(frameObject) and frameTargets[frameObject] == VISIBLE_ALPHA then
            return true
        end
    end

    return false
end

local function FadeActionBarCluster(targetAlpha, duration)
    ForEachActionBarClusterFrame(function(frameObject)
        if not IsActionBarManagedFrame(frameObject) then
            FadeFrame(frameObject, targetAlpha, duration)
        end
    end)
    FadeActionButtonVisuals(targetAlpha, duration)
end

local hoverDriver = CreateFrame("Frame")
hoverDriver:Hide()
hoverDriver:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() or IsInCombat() then
        self:Hide()
        return
    end
    if IsGameEditModeActive() then
        RestoreVisible(0, true)
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < HOVER_UPDATE_INTERVAL then
        return
    end
    self.elapsed = 0

    if GetCursorPosition then
        local cursorX, cursorY = GetCursorPosition()
        local cursorMoved = cursorX ~= self.lastCursorX or cursorY ~= self.lastCursorY
        self.lastCursorX = cursorX
        self.lastCursorY = cursorY

        if not cursorMoved and not HasVisibleHoverTarget() and not next(activeFades) then
            return
        end
    end

    local now = GetTime and GetTime() or 0
    if IsActionBarClusterHovered() then
        hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = nil
        FadeActionBarCluster(VISIBLE_ALPHA, HOVER_FADE_IN_SECONDS)
    elseif HasVisibleActionBarClusterTarget() then
        hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] or (now + HOVER_FADE_OUT_DELAY_SECONDS)
        if now >= hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] then
            hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = nil
            FadeActionBarCluster(EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
        end
    else
        hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = nil
        FadeActionBarCluster(EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
    end

    for frameObject in pairs(managedFrames) do
        if IsActionBarClusterFrame(frameObject) then
            hoverFadeOutAt[frameObject] = nil
        elseif IsMouseOverFrame(frameObject) or IsManagedAncestorHovered(frameObject) then
            hoverFadeOutAt[frameObject] = nil
            FadeFrame(frameObject, VISIBLE_ALPHA, HOVER_FADE_IN_SECONDS)
        elseif frameTargets[frameObject] == VISIBLE_ALPHA then
            hoverFadeOutAt[frameObject] = hoverFadeOutAt[frameObject] or (now + HOVER_FADE_OUT_DELAY_SECONDS)
            if now >= hoverFadeOutAt[frameObject] then
                hoverFadeOutAt[frameObject] = nil
                FadeFrame(frameObject, EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
            end
        else
            hoverFadeOutAt[frameObject] = nil
            FadeFrame(frameObject, EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
        end
    end
end)

local function ApplyTargetAlpha(targetAlpha, duration)
    RefreshManagedFrames()
    for frameObject in pairs(managedFrames) do
        if not IsActionBarManagedFrame(frameObject) then
            FadeFrame(frameObject, targetAlpha, duration)
        end
    end
    FadeActionButtonVisuals(targetAlpha, duration)

    if targetAlpha == VISIBLE_ALPHA then
        RestoreActionButtonCooldownDrawStates()
    end
end

local function RefreshExplorerTargets()
    RefreshManagedFrames()
    for frameObject in pairs(managedFrames) do
        if not IsActionBarManagedFrame(frameObject) then
            local targetAlpha = frameTargets[frameObject]
            if targetAlpha == nil then targetAlpha = EXPLORING_ALPHA end
            FadeFrame(frameObject, targetAlpha, 0, true)
        end
    end

    FadeActionButtonVisuals(actionButtonTargetAlpha or EXPLORING_ALPHA, 0, true)
end

local function CancelScheduledRefresh()
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:refresh"] = nil
    end
end

local function CancelScheduledActionButtonRefresh()
    actionButtonRefreshQueued = false
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:actionButtons"] = nil
        Carpenter.Deferred["ExplorerMode:actionButtonsVerify"] = nil
    end
end

local function CancelScheduledFadeOut()
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:fadeOut"] = nil
    end
end

local function RestoreVisible(duration, forceApply)
    CancelScheduledRefresh()
    CancelScheduledActionButtonRefresh()
    CancelScheduledFadeOut()
    activeFades = {}
    fadeDriver:Hide()
    hoverDriver:Hide()
    hoverFadeOutAt = {}
    explorerFaded = false

    if forceApply or not IsInCombat() then
        ApplyTargetAlpha(VISIBLE_ALPHA, duration or 0)
    end
end

local function RestoreManagedFrames()
    CancelScheduledRefresh()
    CancelScheduledActionButtonRefresh()
    CancelScheduledFadeOut()
    activeFades = {}
    fadeDriver:Hide()
    hoverDriver:Hide()

    for object, originalAlpha in pairs(managedAlphas) do
        SafeSetAlpha(object, originalAlpha or VISIBLE_ALPHA)
    end
    RestoreActionButtonCooldownDrawStates()
    managedFrames = {}
    managedAlphas = {}
    frameTargets = {}
    hoverFadeOutAt = {}
    actionButtonTargetAlpha = nil
    explorerFaded = false
end

local function ScheduleRefresh()
    local callback = function()
        if IsEnabled() and explorerFaded and not IsInCombat() and IsPlayerAtFullHealth() and not IsGameEditModeActive() then
            RefreshExplorerTargets()
        end
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:refresh", FADE_OUT_SECONDS + 0.2, callback)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(FADE_OUT_SECONDS + 0.2, callback)
    end
end

local function ShouldRefreshActionButtons()
    if not (IsEnabled() and explorerFaded and not IsInCombat() and IsPlayerAtFullHealth() and not IsGameEditModeActive()) then
        return false
    end

    return true
end

local function ShouldQueueActionButtonRefresh()
    return IsEnabled() and explorerFaded and not IsInCombat() and not IsGameEditModeActive()
end

local function RunActionButtonRefresh()
    actionButtonRefreshQueued = false
    lastActionButtonRefreshAt = GetTime and GetTime() or 0

    if not ShouldRefreshActionButtons() then
        return
    end

    local targetAlpha = actionButtonTargetAlpha or EXPLORING_ALPHA
    FadeActionButtonVisuals(targetAlpha, 0, true)

    local callback = function()
        if ShouldRefreshActionButtons() then
            FadeActionButtonVisuals(actionButtonTargetAlpha or targetAlpha, 0, true)
        end
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:actionButtonsVerify", 0.05, callback)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.05, callback)
    else
        callback()
    end
end

local function ScheduleActionButtonRefresh()
    if not ShouldQueueActionButtonRefresh() or actionButtonRefreshQueued then
        return
    end

    local now = GetTime and GetTime() or 0
    local elapsedSinceRefresh = now - (lastActionButtonRefreshAt or 0)
    local delay = math.max(0, ACTION_BUTTON_REFRESH_THROTTLE_SECONDS - elapsedSinceRefresh)

    actionButtonRefreshQueued = true

    if delay <= 0 then
        RunActionButtonRefresh()
        return
    end

    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:actionButtons", delay, RunActionButtonRefresh)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, RunActionButtonRefresh)
    else
        RunActionButtonRefresh()
    end
end

local function FadeOutForExploration()
    if not IsEnabled() or IsInCombat() then
        return
    end
    if IsGameEditModeActive() then
        RestoreVisible(0, true)
        return
    end
    if not IsPlayerAtFullHealth() then
        RestoreVisible(HOVER_FADE_IN_SECONDS)
        return
    end

    explorerFaded = true
    ApplyTargetAlpha(EXPLORING_ALPHA, FADE_OUT_SECONDS)
    hoverDriver:Show()
    ScheduleRefresh()
end

local function ScheduleFadeOut()
    CancelScheduledFadeOut()
    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ExplorerMode:fadeOut", FADE_OUT_DELAY_SECONDS, FadeOutForExploration)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(FADE_OUT_DELAY_SECONDS, FadeOutForExploration)
    else
        FadeOutForExploration()
    end
end

local function ApplyExplorerMode(forceVisible)
    if not IsEnabled() then
        RestoreManagedFrames()
        return
    end

    if forceVisible then
        RestoreVisible(0, true)
        return
    end

    local inCombat = IsInCombat()
    if inCombat then
        RestoreVisible(0)
    elseif IsGameEditModeActive() then
        RestoreVisible(0, true)
    elseif not IsPlayerAtFullHealth() then
        RestoreVisible(HOVER_FADE_IN_SECONDS)
    elseif explorerFaded then
        RefreshExplorerTargets()
        hoverDriver:Show()
        ScheduleRefresh()
    else
        ScheduleFadeOut()
    end
end

frame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" then
        if unit ~= "player" then
            return
        end
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        HookActionButtonOverlayFunctions()
    end
    ApplyExplorerMode(event == "PLAYER_REGEN_DISABLED")
end)

actionBarFrame:SetScript("OnEvent", function()
    ScheduleActionButtonRefresh()
end)

local function OnEditModeEnter()
    if IsEnabled() then
        RestoreVisible(0, true)
    end
end

local function OnEditModeExit()
    if IsEnabled() then
        ApplyExplorerMode()
    end
end

local function RegisterEditModeCallbacks()
    if not IsEditModeSupportedClient() then
        return
    end

    if not editModeCallbacksRegistered and EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter, frame)
        EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, frame)
        editModeCallbacksRegistered = true
    end

    if not editModeHooksInstalled and hooksecurefunc and _G.EditModeManagerFrame then
        local editMode = _G.EditModeManagerFrame
        if type(editMode.EnterEditMode) == "function" then
            pcall(hooksecurefunc, editMode, "EnterEditMode", OnEditModeEnter)
        end
        if type(editMode.ExitEditMode) == "function" then
            pcall(hooksecurefunc, editMode, "ExitEditMode", OnEditModeExit)
        end
        editModeHooksInstalled = true
    end
end

_G.Carpenter_ApplyExplorerMode = ApplyExplorerMode
_G.Carpenter_RepairExplorerModeChatWindows = RepairAccidentalChatWindows

local repairFrame = CreateFrame("Frame")
repairFrame:RegisterEvent("PLAYER_LOGIN")
repairFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if Carpenter and Carpenter.After then
        Carpenter:After(2, RepairAccidentalChatWindows)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(2, RepairAccidentalChatWindows)
    else
        RepairAccidentalChatWindows()
    end
end)

local feature = {}

function feature:Enable()
    for _, event in ipairs(registeredEvents) do
        if Carpenter and Carpenter.SafeRegisterEvent then
            Carpenter:SafeRegisterEvent(frame, event)
        else
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    for event in pairs(actionBarRefreshEvents) do
        if Carpenter and Carpenter.SafeRegisterEvent then
            Carpenter:SafeRegisterEvent(actionBarFrame, event)
        else
            pcall(actionBarFrame.RegisterEvent, actionBarFrame, event)
        end
    end
    for _, event in ipairs(registeredUnitEvents) do
        if Carpenter and Carpenter.SafeRegisterUnitEvent then
            Carpenter:SafeRegisterUnitEvent(frame, event, "player")
        else
            pcall(frame.RegisterUnitEvent, frame, event, "player")
        end
    end
    HookActionButtonOverlayFunctions()
    RegisterEditModeCallbacks()
    ApplyExplorerMode()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    actionBarFrame:UnregisterAllEvents()
    RestoreManagedFrames()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
