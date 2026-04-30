local addonName, ns = ...

Carpenter = Carpenter or {}
ns = ns or {}

local _, _, _, interfaceVersion = GetBuildInfo()
local projectID = WOW_PROJECT_ID

local isRetail = (WOW_PROJECT_MAINLINE and projectID == WOW_PROJECT_MAINLINE) or interfaceVersion >= 100000
local isTBC = (WOW_PROJECT_BURNING_CRUSADE_CLASSIC and projectID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) or (interfaceVersion >= 20000 and interfaceVersion < 30000)
local isVanilla = (WOW_PROJECT_CLASSIC and projectID == WOW_PROJECT_CLASSIC) or (interfaceVersion >= 10000 and interfaceVersion < 20000)

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
    isTBC = isTBC,
    isVanilla = isVanilla,
    isClassic = isVanilla or isTBC,
}

local classicFeatures = {
    hideMacroNamesEnabled = true,
    hideKeybindsEnabled = true,
    actionBarFaderEnabled = true,
    actionBarRangeEnabled = true,
    hideStanceBarEnabled = true,
    minimapClutterEnabled = true,
    enhanceTooltipEnabled = true,
    classHealthColorsEnabled = true,
    threatIndicatorEnabled = true,
    unitFrameDebuffsEnabled = true,
    unitFrameClassIconEnabled = true,
    hideUnitFrameCombatTextEnabled = true,
    debuffTrackerEnabled = true,
    nameplateComboEnabled = true,
    nameplateCastNamesEnabled = true,
    nameplateClassHealthEnabled = true,
    raidTargetIconAlignedEnabled = true,
    chatFilterEnabled = true,
    chatCleanerEnabled = true,
    hideChatButtonsEnabled = true,
    autoCarrotEnabled = true,
    smartMacrosEnabled = true,
    autoTrackQuestsEnabled = true,
    autoSellGreys = true,
    autoRepair = true,
    enchantWarningEnabled = true,
    hideErrorMessagesEnabled = true,
    actionCamEnabled = true,
}

local featureSupport = {
    vanilla = classicFeatures,
    tbc = setmetatable({
        menuTransparencyEnabled = true,
        smallerExpBarEnabled = true,
    }, { __index = classicFeatures }),
    retail = {
        hideMacroNamesEnabled = true,
        hideStanceBarEnabled = true,
        menuTransparencyEnabled = true,
        enhanceTooltipEnabled = true,
        classHealthColorsEnabled = true,
        hideUnitFrameCombatTextEnabled = true,
        cleanUpUnitFramesEnabled = true,
        hideUnitFramePvPIconEnabled = true,
        hideUnitFramePowerBarEnabled = true,
        hideBossFramesEnabled = true,
        hideRestAnimationEnabled = true,
        hideCombatIconEnabled = true,
        hideHealthLossFxEnabled = true,
        hideGroupIndicatorEnabled = true,
        hideRoleIconEnabled = true,
        hidePvPTimerEnabled = true,
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
    },
}

Carpenter.FeatureSupport = featureSupport

function Carpenter:IsFeatureAvailable(configKey)
    local flavorSupport = featureSupport[Carpenter.Client.flavor]
    return flavorSupport and flavorSupport[configKey] == true
end
