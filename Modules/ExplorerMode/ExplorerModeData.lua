--[[ Carpenter - Explorer Mode data ]]
-- Constants, frame lists, and shared state.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

-- Shared between the Explorer Mode files; not part of any public API.
local Internal = ns.Private.ExplorerModeInternal or {}
ns.Private.ExplorerModeInternal = Internal

Internal.State = {
    managedFrames = {},
    managedAlphas = {},
    frameTargets = {},
    activeFades = {},
    hoverFadeOutAt = {},
    trackingBarHoverSources = setmetatable({}, { __mode = "k" }),
    explorerFaded = false,
    actionButtonTargetAlpha = nil,
}

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
-- Retail and Forever hide health from addons, so there we wait for health
-- to stop changing (regen has filled it) before fading.
local HIDDEN_HEALTH_SETTLE_SECONDS = 5

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

Internal.ACTION_BAR_CLUSTER_KEY = ACTION_BAR_CLUSTER_KEY
Internal.ACTION_BUTTON_FADE_KEY = ACTION_BUTTON_FADE_KEY
Internal.ACTION_BUTTON_REFRESH_THROTTLE_SECONDS = ACTION_BUTTON_REFRESH_THROTTLE_SECONDS
Internal.CHAT_REPAIR_VERSION = CHAT_REPAIR_VERSION
Internal.EXPLORING_ALPHA = EXPLORING_ALPHA
Internal.FADE_OUT_DELAY_SECONDS = FADE_OUT_DELAY_SECONDS
Internal.FADE_OUT_SECONDS = FADE_OUT_SECONDS
Internal.FEATURE_KEY = FEATURE_KEY
Internal.HIDDEN_HEALTH_SETTLE_SECONDS = HIDDEN_HEALTH_SETTLE_SECONDS
Internal.HOVER_FADE_IN_SECONDS = HOVER_FADE_IN_SECONDS
Internal.HOVER_FADE_OUT_DELAY_SECONDS = HOVER_FADE_OUT_DELAY_SECONDS
Internal.HOVER_FADE_OUT_SECONDS = HOVER_FADE_OUT_SECONDS
Internal.HOVER_UPDATE_INTERVAL = HOVER_UPDATE_INTERVAL
Internal.VISIBLE_ALPHA = VISIBLE_ALPHA
Internal.actionBarClusterFrameNames = actionBarClusterFrameNames
Internal.actionBarManagedFrameNames = actionBarManagedFrameNames
Internal.actionBarRefreshEvents = actionBarRefreshEvents
Internal.actionButtonCooldownKeys = actionButtonCooldownKeys
Internal.actionButtonGroups = actionButtonGroups
Internal.actionButtonNamePatterns = actionButtonNamePatterns
Internal.actionButtonNames = actionButtonNames
Internal.actionButtonOverlayFunctions = actionButtonOverlayFunctions
Internal.actionButtonRefreshFunctions = actionButtonRefreshFunctions
Internal.classicOrTBCActionBarVisualFrameNames = classicOrTBCActionBarVisualFrameNames
Internal.classicOrTBCBottomBarFrameNames = classicOrTBCBottomBarFrameNames
Internal.cooldownDrawMethods = cooldownDrawMethods
Internal.cooldownFrameFunctions = cooldownFrameFunctions
Internal.frameNames = frameNames
Internal.minimapClutterFrameNames = minimapClutterFrameNames
Internal.registeredEvents = registeredEvents
Internal.registeredUnitEvents = registeredUnitEvents
Internal.repeatedFramePrefixes = repeatedFramePrefixes
Internal.unitFramePieces = unitFramePieces
