local addonName, ns = ...

Carpenter = Carpenter or {}
ns = ns or {}

local _, _, _, interfaceVersion = GetBuildInfo()
local projectID = WOW_PROJECT_ID

-- WoW Forever/Camelot uses the retail-style API with its own interface range.
local isForever = interfaceVersion >= 16000 and interfaceVersion < 17000
local isRetail = (WOW_PROJECT_MAINLINE and projectID == WOW_PROJECT_MAINLINE) or interfaceVersion >= 100000 or isForever
local isTBC = not isForever and ((WOW_PROJECT_BURNING_CRUSADE_CLASSIC and projectID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) or (interfaceVersion >= 20000 and interfaceVersion < 30000))
local isVanilla = not isForever and ((WOW_PROJECT_CLASSIC and projectID == WOW_PROJECT_CLASSIC) or (interfaceVersion >= 10000 and interfaceVersion < 20000))

local flavor = "unknown"
if isRetail then
    flavor = "retail"
elseif isTBC then
    flavor = "tbc"
elseif isVanilla then
    flavor = "vanilla"
end

Carpenter.Client = {
    addonName = addonName or "Carpenter",
    flavor = flavor,
    interfaceVersion = interfaceVersion,
    projectID = projectID,
    isRetail = isRetail,
    isForever = isForever,
    isTBC = isTBC,
    isVanilla = isVanilla,
    isClassic = isVanilla or isTBC,
}

-- Which clients offer each feature, and the module files that implement it
-- there. Clients match the TOCs: vanilla (Carpenter_Vanilla.toc), tbc
-- (Carpenter_TBC.toc), retail (Carpenter.toc), forever (Carpenter_Camelot.toc).
-- A feature can list several implementations when clients use different
-- modules. tools/check-addon-shape.lua verifies every listed client loads the
-- files, and that a client loading a feature's files either offers it or says
-- why not in notOn.
local ALL = "vanilla tbc retail forever"
local CLASSIC = "vanilla tbc"
local MODERN = "retail forever"

local featureManifest = {
    -- Action bars
    hideMacroNamesEnabled = { { clients = ALL, files = { "Modules/HideUIElements.lua" } } },
    hideKeybindsEnabled = {
        { clients = CLASSIC, files = { "Modules/HideUIElements.lua" } },
        notOn = { retail = "keybind text sits on protected action buttons", forever = "keybind text sits on protected action buttons" },
    },
    hideStanceBarEnabled = { { clients = ALL, files = { "Modules/HideUIElements.lua" } } },
    actionBarFaderEnabled = { { clients = "tbc", files = { "Modules/ActionBarFader.lua" } } },
    actionBarRangeEnabled = { { clients = CLASSIC, files = { "Modules/ActionBarRange.lua" } } },

    -- Interface
    menuTransparencyEnabled = { { clients = ALL, files = { "Modules/MenuTransparency.lua" } } },
    smallerExpBarEnabled = { { clients = CLASSIC, files = { "Modules/SmallerExpBar.lua" } } },
    minimapClutterEnabled = { { clients = ALL, files = { "Modules/MinimapClutter/MinimapClutter.lua" } } },
    hideQuestTrackerTitlesEnabled = { { clients = MODERN, files = { "Modules/HideQuestTrackerTitles.lua" } } },
    sortQuestsByLevelEnabled = { { clients = "forever", files = { "Modules/QuestTrackerSort.lua" } } },
    worldMapCleanupEnabled = {
        { clients = CLASSIC, files = { "Modules/WorldMapCleanup/WorldMapCleanup.lua" } },
        { clients = "forever", files = { "Modules/WorldMapCleanup/WorldMapCleanupForever.lua" } },
    },
    professionIconPortraitEnabled = { { clients = CLASSIC, files = { "Modules/ProfessionIconPortrait.lua" } } },
    talentIconPortraitEnabled = { { clients = CLASSIC, files = { "Modules/TalentIconPortrait.lua" } } },
    enhanceTooltipEnabled = { { clients = ALL, files = { "Modules/EnhanceTooltip.lua" } } },
    scaleExtraAbilityEnabled = { { clients = "retail", files = { "Modules/ExtraAbilityScale.lua" } } },

    -- Unit frames
    classHealthColorsEnabled = { { clients = ALL, files = { "Modules/ClassHealthColorsUnitFrames.lua" } } },
    threatIndicatorEnabled = { { clients = CLASSIC, files = { "Modules/ThreatIndicator.lua" } } },
    unitFrameDebuffsEnabled = {
        { clients = CLASSIC, files = { "Modules/DebuffTracker/DebuffTracker.lua" } },
        { clients = "forever", files = { "Modules/ForeverUnitFrameAuras.lua" } },
    },
    unitFrameBuffsEnabled = { { clients = CLASSIC, files = { "Modules/DebuffTracker/DebuffTracker.lua" } } },
    unitFrameClassIconEnabled = { { clients = CLASSIC, files = { "Modules/UnitFrameClassIcon.lua" } } },
    hideUnitFrameCombatTextEnabled = {
        { clients = CLASSIC, files = { "Modules/HideUnitFrameCombatText.lua" } },
        notOn = { retail = "folded into Unit Frame Cleanup", forever = "folded into Unit Frame Cleanup" },
    },
    cleanUpUnitFramesEnabled = { { clients = MODERN, files = { "Modules/RetailUnitFrameCleaner.lua" } } },
    hideUnitFramePowerBarEnabled = {
        { clients = "retail", files = { "Modules/RetailUnitFrameCleaner.lua" } },
        notOn = { forever = "Forever's class power bars can't be hidden safely" },
    },
    hideBossFramesEnabled = { { clients = MODERN, files = { "Modules/RetailUnitFrameCleaner.lua" } } },

    -- Nameplates
    debuffTrackerEnabled = {
        { clients = CLASSIC, files = { "Modules/DebuffTracker/DebuffTracker.lua" } },
        { clients = "forever", files = { "Modules/ForeverNameplateAuras.lua" } },
    },
    nameplateComboEnabled = { { clients = "vanilla tbc forever", files = { "Modules/NameplateComboPoints.lua" } } },

    -- Chat
    chatFilterEnabled = { { clients = CLASSIC, files = { "Modules/ChatFilter.lua" } } },
    chatCleanerEnabled = { { clients = ALL, files = { "Modules/ChatCleaner/ChatCleaner.lua" } } },
    hideChatButtonsEnabled = { { clients = ALL, files = { "Modules/HideChatButtons.lua" } } },

    -- Automations
    autoCarrotEnabled = { { clients = CLASSIC, files = { "Modules/AutoCarrot.lua" } } },
    smartMacrosEnabled = { { clients = ALL, files = { "Modules/SmartMacros/SmartMacros.lua" } } },
    poisonMacrosEnabled = { { clients = CLASSIC, files = { "Modules/PoisonMacros.lua" } } },
    autoTrackQuestsEnabled = { { clients = CLASSIC, files = { "Modules/AutoTrackQuests/AutoTrackQuests.lua" } } },
    autoSellGreys = { { clients = ALL, files = { "Modules/AutoSellGreys.lua" } } },
    autoRepair = { { clients = ALL, files = { "Modules/AutoRepair.lua" } } },

    -- Text
    enchantWarningEnabled = { { clients = "vanilla tbc forever", files = { "Modules/EnchantWarning.lua" } } },
    hideErrorMessagesEnabled = { { clients = ALL, files = { "Modules/HideErrorMessages.lua" } } },

    -- Immersion
    actionCamEnabled = { { clients = ALL, files = { "Modules/ActionCam.lua" } } },
    explorerModeEnabled = { { clients = ALL, files = { "Modules/ExplorerMode/ExplorerMode.lua" } } },
}

Carpenter.FeatureManifest = featureManifest

local function GetClientKey()
    local client = Carpenter.Client
    if client.isForever then return "forever" end
    return client.flavor
end

-- Feature key -> true for every feature this client offers.
local availableFeatures = {}
do
    local clientKey = GetClientKey()
    for configKey, implementations in pairs(featureManifest) do
        for _, implementation in ipairs(implementations) do
            for client in implementation.clients:gmatch("%S+") do
                if client == clientKey then
                    availableFeatures[configKey] = true
                end
            end
        end
    end
end

function Carpenter:IsFeatureAvailable(configKey)
    -- Retail-style clients can only hide macro names through secure calls.
    if Carpenter.Client.isRetail and configKey == "hideMacroNamesEnabled" then
        return availableFeatures[configKey] == true and type(securecallfunction) == "function"
    end
    return availableFeatures[configKey] == true
end
