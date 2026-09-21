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

local classicFeatures = {
    hideMacroNamesEnabled = true,
    hideKeybindsEnabled = true,
    actionBarRangeEnabled = true,
    hideStanceBarEnabled = true,
    menuTransparencyEnabled = true,
    smallerExpBarEnabled = true,
    minimapClutterEnabled = true,
    worldMapCleanupEnabled = true,
    professionIconPortraitEnabled = true,
    talentIconPortraitEnabled = true,
    enhanceTooltipEnabled = true,
    classHealthColorsEnabled = true,
    threatIndicatorEnabled = true,
    unitFrameDebuffsEnabled = true,
    unitFrameBuffsEnabled = true,
    unitFrameClassIconEnabled = true,
    hideUnitFrameCombatTextEnabled = true,
    debuffTrackerEnabled = true,
    nameplateComboEnabled = true,
    chatFilterEnabled = true,
    chatCleanerEnabled = true,
    hideChatButtonsEnabled = true,
    autoCarrotEnabled = true,
    smartMacrosEnabled = true,
    poisonMacrosEnabled = true,
    autoTrackQuestsEnabled = true,
    autoSellGreys = true,
    autoRepair = true,
    enchantWarningEnabled = true,
    hideErrorMessagesEnabled = true,
    actionCamEnabled = true,
    explorerModeEnabled = true,
}

local featureSupport = {
    vanilla = classicFeatures,
    tbc = setmetatable({
        actionBarFaderEnabled = true,
    }, { __index = classicFeatures }),
    retail = {
        hideStanceBarEnabled = true,
        menuTransparencyEnabled = true,
        minimapClutterEnabled = true,
        enhanceTooltipEnabled = true,
        scaleExtraAbilityEnabled = true,
        hideQuestTrackerTitlesEnabled = true,
        classHealthColorsEnabled = true,
        threatIndicatorEnabled = false,
        cleanUpUnitFramesEnabled = true,
        hideUnitFramePvPIconEnabled = true,
        hideUnitFramePowerBarEnabled = true,
        hideBossFramesEnabled = true,
        hideRestAnimationEnabled = true,
        hideHealthLossFxEnabled = true,
        hideRealmIndicatorEnabled = true,
        hidePlayerCornerIconEnabled = true,
        hidePartyFrameTitleEnabled = true,
        hideTargetReputationColorEnabled = true,
        chatCleanerEnabled = true,
        hideChatButtonsEnabled = true,
        smartMacrosEnabled = true,
        autoSellGreys = true,
        autoRepair = true,
        hideErrorMessagesEnabled = true,
        actionCamEnabled = true,
        explorerModeEnabled = true,
    },
}

Carpenter.FeatureSupport = featureSupport

local foreverUnsupportedFeatures = {
    hideUnitFramePowerBarEnabled = true,
}

function Carpenter:IsFeatureAvailable(configKey)
    if Carpenter.Client.isForever and configKey == "hideMacroNamesEnabled" then
        return type(securecallfunction) == "function"
    end
    if Carpenter.Client.isForever and configKey == "worldMapCleanupEnabled" then
        return true
    end
    if Carpenter.Client.isForever and foreverUnsupportedFeatures[configKey] then
        return false
    end
    local flavorSupport = featureSupport[Carpenter.Client.flavor]
    return flavorSupport and flavorSupport[configKey] == true
end
