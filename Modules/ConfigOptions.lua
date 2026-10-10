--[[ Carpenter - Config option definitions ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Options = ns.Private.ConfigOptions or {}
ns.Private.ConfigOptions = Options

function Options.Create(context)
    context = context or {}
    local L = context.L or {}
    local LightGrey = context.LightGrey or "|cffaaaaaa"
    local LighterCream = context.LighterCream or "|cffffff99"
    local GetSettingsImage = context.GetSettingsImage or function() return nil end
    local SideLogic = context.SideLogic or {}
    local ShowFilterOptions = SideLogic.FilterOptions or context.ShowFilterOptions
    local ShowCarrotSlots = SideLogic.CarrotSlots or context.ShowCarrotSlots
    local ShowMacroPreviews = SideLogic.MacroPreviews or context.ShowMacroPreviews
    local ShowPoisonMacroPreviews = SideLogic.PoisonMacroPreviews or context.ShowPoisonMacroPreviews
    local ShowSellJunkOptions = SideLogic.SellJunkOptions or context.ShowSellJunkOptions
    local ShowWorldMapOptions = SideLogic.WorldMapOptions or context.ShowWorldMapOptions

    local function Description(key)
        local text = L[key] or key
        text = text:gsub("{hl}", LighterCream):gsub("{/hl}", LightGrey)
        return LightGrey .. text
    end

    local function MountSpeedDescription()
        local client = Carpenter and Carpenter.Client
        return Description(client and client.isVanilla and "DESC_MOUNT_SPEED_TRINKET_CLASSIC" or "DESC_MOUNT_SPEED_TRINKET")
    end

    local function MinimapClutterDescription()
        local client = Carpenter and Carpenter.Client
        return Description(client and client.isRetail and "DESC_MINIMAP_CLUTTER_RETAIL" or "DESC_MINIMAP_CLUTTER")
    end

    local function WorldMapCleanupDescription()
        local client = Carpenter and Carpenter.Client
        return Description(client and client.isForever and "DESC_WORLD_MAP_CLEANUP_FOREVER" or "DESC_WORLD_MAP_CLEANUP")
    end

    local function RunGlobal(globalName)
        local callback = _G[globalName]
        if callback then callback() end
    end

    local function OnToggleGlobal(globalName)
        return function()
            RunGlobal(globalName)
        end
    end

    local function SyncUnitFrameCombatText(configKey)
        if Carpenter and Carpenter.IsEnabled and Carpenter:IsEnabled(configKey) then
            RunGlobal("Carpenter_ApplyUnitFrameCombatText")
        else
            RunGlobal("Carpenter_RestoreUnitFrameCombatText")
        end
    end

    local function OnToggleUnitFrameCombatText(configKey)
        return function()
            SyncUnitFrameCombatText(configKey)
        end
    end

    local function OnToggleRetailUnitFramesAndCombatText(configKey)
        return function()
            RunGlobal("Carpenter_ApplyRetailUnitFrameCleaner")
            SyncUnitFrameCombatText(configKey)
        end
    end

    local ApplyActionCam = OnToggleGlobal("Carpenter_ApplyActionCam")
    local ApplyExplorerMode = OnToggleGlobal("Carpenter_ApplyExplorerMode")
    local ApplyExtraAbilityScale = OnToggleGlobal("Carpenter_ApplyExtraAbilityScale")
    local ApplyRetailUnitFrames = OnToggleGlobal("Carpenter_ApplyRetailUnitFrameCleaner")
    local ApplyUnitFrameAuras = OnToggleGlobal("Carpenter_UpdateUnitFrameAuras")
    local ApplyWorldMapCleanup = OnToggleGlobal("Carpenter_ApplyWorldMapCleanup")
    local ApplyRetailUnitFramesAndCombatText = OnToggleRetailUnitFramesAndCombatText("cleanUpUnitFramesEnabled")
    local ApplyUnitFrameCombatText = OnToggleUnitFrameCombatText("hideUnitFrameCombatTextEnabled")

    local sections = {
        {
            title = L.SECTION_ACTION_BARS or "Action Bars",
            options = {
                {
                    key = "hideMacroNamesEnabled",
                    label = L.OPTION_HIDE_MACRO_NAMES or "Hide Macro Names",
                    description = Description("DESC_HIDE_MACRO_NAMES"),
                    image = GetSettingsImage("macrotext.png"),
                    requiresReload = false,
                },
                {
                    key = "hideKeybindsEnabled",
                    label = L.OPTION_HIDE_KEYBINDS or "Hide Keybind Text",
                    description = Description("DESC_HIDE_KEYBINDS"),
                    image = GetSettingsImage("keybind.png"),
                    requiresReload = false,
                },
                {
                    key = "actionBarFaderEnabled",
                    label = L.OPTION_ACTION_BAR_FADER or "Fade Extra Action Bars",
                    description = Description("DESC_ACTION_BAR_FADER"),
                    image = GetSettingsImage("actionbar.png"),
                    requiresReload = false,
                },
                {
                    key = "actionBarRangeEnabled",
                    label = L.OPTION_ACTION_BAR_RANGE or "Out of Range Tint",
                    description = Description("DESC_ACTION_BAR_RANGE"),
                    image = GetSettingsImage("range.png"),
                    requiresReload = false,
                },
                {
                    key = "hideStanceBarEnabled",
                    label = L.OPTION_HIDE_STANCE_BAR or "Hide Stance Bar",
                    description = Description("DESC_HIDE_STANCE_BAR"),
                    image = GetSettingsImage("stance.png"),
                    requiresReload = false,
                },
            },
        },
        {
            title = L.SECTION_INTERFACE or "Interface",
            options = {
                {
                    key = "menuTransparencyEnabled",
                    label = L.OPTION_MENU_TRANSPARENCY or "Fade Micro Menu & Bags",
                    description = Description("DESC_MENU_TRANSPARENCY"),
                    image = GetSettingsImage("micromenu.png"),
                    requiresReload = false,
                },
                {
                    key = "smallerExpBarEnabled",
                    label = L.OPTION_SMALLER_EXP_BAR or "Fade Exp & Rep Bars",
                    description = Description("DESC_SMALLER_EXP_BAR"),
                    image = GetSettingsImage("repbar.png"),
                    requiresReload = false,
                },
                {
                    key = "minimapClutterEnabled",
                    label = L.OPTION_MINIMAP_CLUTTER or "Remove Minimap Clutter",
                    description = MinimapClutterDescription(),
                    image = GetSettingsImage("minimapclutter.png"),
                    requiresReload = false,
                },
                {
                    key = "hideQuestTrackerTitlesEnabled",
                    label = L.OPTION_HIDE_QUEST_TRACKER_TITLES or "Hide Quest Tracker Titles",
                    description = Description("DESC_HIDE_QUEST_TRACKER_TITLES"),
                    image = GetSettingsImage("questtrack.png"),
                    requiresReload = false,
                },
                {
                    key = "worldMapCleanupEnabled",
                    label = L.OPTION_WORLD_MAP_CLEANUP or "World Map Cleanup",
                    description = WorldMapCleanupDescription(),
                    sideLogic = not (Carpenter and Carpenter.Client and Carpenter.Client.isForever) and ShowWorldMapOptions or nil,
                    image = GetSettingsImage("map.png"),
                    requiresReload = false,
                    onToggle = ApplyWorldMapCleanup,
                },
                {
                    key = "professionIconPortraitEnabled",
                    label = L.OPTION_PROFESSION_ICON_PORTRAIT or "Profession Icon Portrait",
                    description = Description("DESC_PROFESSION_ICON_PORTRAIT"),
                    image = GetSettingsImage("profession.png"),
                    requiresReload = false,
                },
                {
                    key = "talentIconPortraitEnabled",
                    label = L.OPTION_TALENT_ICON_PORTRAIT or "Talent Icon Portrait",
                    description = Description("DESC_TALENT_ICON_PORTRAIT"),
                    image = GetSettingsImage("talents.png"),
                    requiresReload = false,
                },
                {
                    key = "enhanceTooltipEnabled",
                    label = L.OPTION_ENHANCE_TOOLTIP or "Enhanced Tooltip",
                    description = Description("DESC_ENHANCE_TOOLTIP"),
                    image = GetSettingsImage("tooltip.png"),
                    requiresReload = false,
                },
                {
                    key = "scaleExtraAbilityEnabled",
                    label = L.OPTION_SCALE_EXTRA_ABILITY or "Scale Extra Ability",
                    description = Description("DESC_SCALE_EXTRA_ABILITY"),
                    image = GetSettingsImage("actionbar.png"),
                    requiresReload = false,
                    onToggle = ApplyExtraAbilityScale,
                },
                {
                    key = "hideBossFramesEnabled",
                    label = L.OPTION_HIDE_BOSS_FRAMES or "Hide Boss Frames",
                    description = Description("DESC_HIDE_BOSS_FRAMES"),
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = ApplyRetailUnitFrames,
                },
            },
        },
        {
            title = L.SECTION_UNIT_FRAMES or "Unit Frames",
            options = {
                {
                    key = "classHealthColorsEnabled",
                    label = L.OPTION_CLASS_HEALTH_COLORS or "Class Colored Health",
                    description = Description("DESC_CLASS_HEALTH_COLORS"),
                    image = GetSettingsImage("classhealthbar.png"),
                    requiresReload = false,
                },
                {
                    key = "threatIndicatorEnabled",
                    label = L.OPTION_THREAT_INDICATOR or "Threat Percentage",
                    description = Description("DESC_THREAT_INDICATOR"),
                    image = GetSettingsImage("threat.png"),
                    requiresReload = false,
                },
                {
                    key = "unitFrameDebuffsEnabled",
                    label = L.OPTION_DEBUFFS or "Debuffs",
                    description = Description("DESC_UNIT_FRAME_DEBUFFS"),
                    image = GetSettingsImage("unitdebuff.png"),
                    requiresReload = false,
                    onToggle = ApplyUnitFrameAuras,
                },
                {
                    key = "unitFrameBuffsEnabled",
                    label = L.OPTION_UNIT_FRAME_BUFFS or "Buffs",
                    description = Description("DESC_UNIT_FRAME_BUFFS"),
                    image = GetSettingsImage("unitbuff.png"),
                    requiresReload = false,
                    onToggle = ApplyUnitFrameAuras,
                },
                {
                    key = "unitFrameClassIconEnabled",
                    label = L.OPTION_CLASS_ICON_PORTRAIT or "Class Icon Portrait",
                    description = Description("DESC_CLASS_ICON_PORTRAIT"),
                    image = GetSettingsImage("classicon.png"),
                },
                {
                    key = "hideUnitFrameCombatTextEnabled",
                    label = L.OPTION_HIDE_UNIT_FRAME_COMBAT_TEXT or "Hide Unit Frame Combat Text",
                    description = Description("DESC_HIDE_UNIT_FRAME_COMBAT_TEXT"),
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = ApplyUnitFrameCombatText,
                },
                {
                    key = "cleanUpUnitFramesEnabled",
                    label = L.OPTION_CLEAN_UP_UNIT_FRAMES or "Clean Unit Frame",
                    description = Description("DESC_CLEAN_UP_UNIT_FRAMES"),
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = ApplyRetailUnitFramesAndCombatText,
                },
                {
                    key = "hideUnitFramePowerBarEnabled",
                    label = L.OPTION_HIDE_POWER_BAR or "Hide Combo/Power Bar",
                    description = Description("DESC_HIDE_POWER_BAR"),
                    image = GetSettingsImage("nameplatecombo.png"),
                    requiresReload = false,
                    onToggle = ApplyRetailUnitFrames,
                },
            },
        },
        {
            title = L.SECTION_NAMEPLATES or "Nameplates",
            options = {
                {
                    key = "debuffTrackerEnabled",
                    label = L.OPTION_DEBUFFS or "Debuffs",
                    description = Description("DESC_NAMEPLATE_DEBUFFS"),
                    image = GetSettingsImage("nameplatedebuff.png"),
                    requiresReload = false,
                },
                {
                    key = "nameplateComboEnabled",
                    label = L.OPTION_COMBO_POINTS or "Combo Points",
                    description = Description("DESC_COMBO_POINTS"),
                    image = GetSettingsImage("nameplatecombo.png"),
                    requiresReload = false,
                },
            },
        },
        {
            title = L.SECTION_CHAT or "Chat",
            options = {
                {
                    key = "chatFilterEnabled",
                    label = L.OPTION_CHAT_FILTER or "Filter",
                    description = Description("DESC_CHAT_FILTER"),
                    sideLogic = ShowFilterOptions,
                    image = GetSettingsImage("chatfilter.png"),
                    requiresReload = false,
                },
                {
                    key = "chatCleanerEnabled",
                    label = L.OPTION_CHAT_CLEANER or "Cleaner",
                    description = Description("DESC_CHAT_CLEANER"),
                    image = GetSettingsImage("chatcleaner.png"),
                    requiresReload = false,
                },
                {
                    key = "hideChatButtonsEnabled",
                    label = L.OPTION_HIDE_CHAT_BUTTONS or "Hide Chat Buttons",
                    description = Description("DESC_HIDE_CHAT_BUTTONS"),
                    image = GetSettingsImage("chatbuttons.png"),
                    requiresReload = false,
                },
                {
                    key = "chatGlossaryEnabled",
                    label = L.OPTION_CHAT_GLOSSARY or "Glossary",
                    description = Description("DESC_CHAT_GLOSSARY"),
                    requiresReload = false,
                },
            },
        },
        {
            title = L.SECTION_AUTOMATIONS or "Automations",
            options = {
                {
                    key = "autoCarrotEnabled",
                    label = L.OPTION_MOUNT_SPEED_TRINKET or "Mount Speed Trinket",
                    description = MountSpeedDescription(),
                    sideLogic = ShowCarrotSlots,
                    image = GetSettingsImage("carrot.png"),
                    requiresReload = false,
                },
                {
                    key = "smartMacrosEnabled",
                    label = L.OPTION_CONSUMABLE_MACROS or "Consumable Macros",
                    description = Description("DESC_CONSUMABLE_MACROS"),
                    sideLogic = ShowMacroPreviews,
                    image = GetSettingsImage("macro.png"),
                    requiresReload = false,
                },
                {
                    key = "poisonMacrosEnabled",
                    class = "ROGUE",
                    label = L.OPTION_POISON_MACROS or "Rogue Macros",
                    description = Description("DESC_POISON_MACROS"),
                    sideLogic = ShowPoisonMacroPreviews,
                    image = GetSettingsImage("poisonmacro.png"),
                    requiresReload = false,
                },
                {
                    key = "autoTrackQuestsEnabled",
                    label = L.OPTION_AUTO_TRACK_QUESTS or "Auto Track Quests",
                    description = Description("DESC_AUTO_TRACK_QUESTS"),
                    image = GetSettingsImage("questtrack.png"),
                },
                {
                    key = "autoSellGreys",
                    label = L.OPTION_AUTO_SELL_JUNK or "Auto Sell Junk",
                    description = Description("DESC_AUTO_SELL_JUNK"),
                    sideLogic = ShowSellJunkOptions,
                    image = GetSettingsImage("selljunk.png"),
                    requiresReload = false,
                },
                {
                    key = "autoRepair",
                    label = L.OPTION_AUTO_REPAIR or "Auto Repair",
                    description = Description("DESC_AUTO_REPAIR"),
                    image = GetSettingsImage("repair.png"),
                    requiresReload = false,
                },
            },
        },
        {
            title = L.SECTION_TEXT or "Text",
            options = {
                {
                    key = "enchantWarningEnabled",
                    label = L.OPTION_POISON_WARNING or "Poison Warning",
                    description = Description("DESC_POISON_WARNING"),
                    image = GetSettingsImage("warning.png"),
                    requiresReload = false,
                },
                {
                    key = "hideErrorMessagesEnabled",
                    label = L.OPTION_HIDE_ERROR_MESSAGES or "Hide Error Messages",
                    description = Description("DESC_HIDE_ERROR_MESSAGES"),
                    image = GetSettingsImage("error.png"),
                    requiresReload = false,
                },
            },
        },
        {
            title = L.SECTION_IMMERSION or "Immersion",
            options = {
                {
                    key = "actionCamEnabled",
                    label = L.OPTION_ACTION_CAM or "Action Cam",
                    description = Description("DESC_ACTION_CAM"),
                    image = GetSettingsImage("actioncam.png"),
                    requiresReload = false,
                    onToggle = ApplyActionCam,
                },
                {
                    key = "explorerModeEnabled",
                    label = L.OPTION_EXPLORER_MODE or "Explorer Mode",
                    description = Description("DESC_EXPLORER_MODE"),
                    badge = {
                        text = L.BADGE_BETA or "BETA",
                        tooltipTitle = L.BADGE_BETA_TITLE or "Beta",
                        tooltipText = L.BADGE_BETA_EXPLORER_MODE or "Fresh off the workbench. It's safe to try, but what fades and when may still change as it gets more testing.",
                    },
                    image = GetSettingsImage("explorer.png"),
                    requiresReload = false,
                    onToggle = ApplyExplorerMode,
                },
            },
        },
    }

    return sections
end
