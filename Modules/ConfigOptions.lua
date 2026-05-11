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
    local ShowFilterOptions = context.ShowFilterOptions
    local ShowCarrotSlots = context.ShowCarrotSlots
    local ShowMacroPreviews = context.ShowMacroPreviews
    local ShowSellJunkOptions = context.ShowSellJunkOptions

    local function Description(key)
        local text = L[key] or key
        text = text:gsub("{hl}", LighterCream):gsub("{/hl}", LightGrey)
        return LightGrey .. text
    end

    local function MountSpeedDescription()
        local client = Carpenter and Carpenter.Client
        return Description(client and client.isVanilla and "DESC_MOUNT_SPEED_TRINKET_CLASSIC" or "DESC_MOUNT_SPEED_TRINKET")
    end

    local sections = {
        {
            title = L.SECTION_ACTION_BARS or "Action Bars",
            options = {
                {
                    key = "hideMacroNamesEnabled",
                    label = L.OPTION_HIDE_MACRO_NAMES or "Hide Macro Names",
                    description = Description("DESC_HIDE_MACRO_NAMES"),
                    image = GetSettingsImage("macrotext.png"),
                },
                {
                    key = "hideKeybindsEnabled",
                    label = L.OPTION_HIDE_KEYBINDS or "Hide Keybind Text",
                    description = Description("DESC_HIDE_KEYBINDS"),
                    image = GetSettingsImage("keybind.png"),
                },
                {
                    key = "actionBarFaderEnabled",
                    label = L.OPTION_ACTION_BAR_FADER or "Fade Extra Action Bars",
                    description = Description("DESC_ACTION_BAR_FADER"),
                    image = GetSettingsImage("actionbar.png"),
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
                },
                {
                    key = "smallerExpBarEnabled",
                    label = L.OPTION_SMALLER_EXP_BAR or "Resize Exp & Rep Bars",
                    description = Description("DESC_SMALLER_EXP_BAR"),
                    image = GetSettingsImage("repbar.png"),
                },
                {
                    key = "minimapClutterEnabled",
                    label = L.OPTION_MINIMAP_CLUTTER or "Remove Minimap Clutter",
                    description = Description("DESC_MINIMAP_CLUTTER"),
                    image = GetSettingsImage("minimapclutter.png"),
                },
                {
                    key = "enhanceTooltipEnabled",
                    label = L.OPTION_ENHANCE_TOOLTIP or "Enhanced Tooltip",
                    description = Description("DESC_ENHANCE_TOOLTIP"),
                    image = GetSettingsImage("tooltip.png"),
                },
                {
                    key = "scaleExtraAbilityEnabled",
                    label = L.OPTION_SCALE_EXTRA_ABILITY or "Scale Extra Ability",
                    description = Description("DESC_SCALE_EXTRA_ABILITY"),
                    image = GetSettingsImage("actionbar.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyExtraAbilityScale then Carpenter_ApplyExtraAbilityScale() end
                    end,
                },
                {
                    key = "hideBossFramesEnabled",
                    label = L.OPTION_HIDE_BOSS_FRAMES or "Hide Boss Frames",
                    description = Description("DESC_HIDE_BOSS_FRAMES"),
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                    end,
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
                },
                {
                    key = "threatIndicatorEnabled",
                    label = L.OPTION_THREAT_INDICATOR or "Threat Percentage",
                    description = Description("DESC_THREAT_INDICATOR"),
                    image = GetSettingsImage("threat.png"),
                },
                {
                    key = "targetHealthPercentEnabled",
                    label = L.OPTION_TARGET_HEALTH_PERCENT or "Target Percentages",
                    description = Description("DESC_TARGET_HEALTH_PERCENT"),
                    image = GetSettingsImage("targetpercentage.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_UpdateTargetHealthPercent then Carpenter_UpdateTargetHealthPercent() end
                    end,
                },
                {
                    key = "unitFrameDebuffsEnabled",
                    label = L.OPTION_DEBUFFS or "Debuffs",
                    description = Description("DESC_UNIT_FRAME_DEBUFFS"),
                    image = GetSettingsImage("unitdebuff.png"),
                },
                {
                    key = "unitFrameBuffsEnabled",
                    label = L.OPTION_UNIT_FRAME_BUFFS or "Buffs",
                    description = Description("DESC_UNIT_FRAME_BUFFS"),
                    image = GetSettingsImage("unitbuff.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_UpdateUnitFrameAuras then Carpenter_UpdateUnitFrameAuras() end
                    end,
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
                    onToggle = function()
                        if Carpenter:IsEnabled("hideUnitFrameCombatTextEnabled") then
                            if Carpenter_ApplyUnitFrameCombatText then Carpenter_ApplyUnitFrameCombatText() end
                        else
                            if Carpenter_RestoreUnitFrameCombatText then Carpenter_RestoreUnitFrameCombatText() end
                        end
                    end,
                },
                {
                    key = "cleanUpUnitFramesEnabled",
                    label = L.OPTION_CLEAN_UP_UNIT_FRAMES or "Clean Unit Frame",
                    description = Description("DESC_CLEAN_UP_UNIT_FRAMES"),
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                        if Carpenter:IsEnabled("cleanUpUnitFramesEnabled") then
                            if Carpenter_ApplyUnitFrameCombatText then Carpenter_ApplyUnitFrameCombatText() end
                        else
                            if Carpenter_RestoreUnitFrameCombatText then Carpenter_RestoreUnitFrameCombatText() end
                        end
                    end,
                },
                {
                    key = "hideUnitFramePowerBarEnabled",
                    label = L.OPTION_HIDE_POWER_BAR or "Hide Combo/Power Bar",
                    description = Description("DESC_HIDE_POWER_BAR"),
                    image = GetSettingsImage("nameplatecombo.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                    end,
                },
                {
                    key = "hideGroupIndicatorEnabled",
                    label = L.OPTION_HIDE_GROUP_INDICATOR or "Hide Group Indicator",
                    description = Description("DESC_HIDE_GROUP_INDICATOR"),
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                    end,
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
                },
                {
                    key = "nameplateComboEnabled",
                    label = L.OPTION_COMBO_POINTS or "Combo Points",
                    description = Description("DESC_COMBO_POINTS"),
                    image = GetSettingsImage("nameplatecombo.png"),
                },
                {
                    key = "nameplateCastNamesEnabled",
                    label = L.OPTION_CAST_BAR or "Cast Bar",
                    description = Description("DESC_CAST_BAR"),
                    image = GetSettingsImage("spellname.png"),
                },
                {
                    key = "nameplateClassHealthEnabled",
                    label = L.OPTION_CLASS_HEALTH_COLORS or "Class Colored Health",
                    description = Description("DESC_NAMEPLATE_CLASS_HEALTH"),
                    image = GetSettingsImage("classhealthnameplate.png"),
                },
                {
                    key = "raidTargetIconAlignedEnabled",
                    label = L.OPTION_RAID_TARGET_ICON_ALIGNED or "Raid Target Icon Aligned",
                    description = Description("DESC_RAID_TARGET_ICON_ALIGNED"),
                    image = GetSettingsImage("raidtarget.png"),
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
                },
                {
                    key = "chatCleanerEnabled",
                    label = L.OPTION_CHAT_CLEANER or "Cleaner",
                    description = Description("DESC_CHAT_CLEANER"),
                    image = GetSettingsImage("chatcleaner.png"),
                },
                {
                    key = "hideChatButtonsEnabled",
                    label = L.OPTION_HIDE_CHAT_BUTTONS or "Hide Chat Buttons",
                    description = Description("DESC_HIDE_CHAT_BUTTONS"),
                    image = GetSettingsImage("chatbuttons.png"),
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
                },
                {
                    key = "smartMacrosEnabled",
                    label = L.OPTION_CONSUMABLE_MACROS or "Consumable Macros",
                    description = Description("DESC_CONSUMABLE_MACROS"),
                    sideLogic = ShowMacroPreviews,
                    image = GetSettingsImage("macro.png"),
                },
                {
                    key = "autoTrackQuestsEnabled",
                    label = L.OPTION_AUTO_TRACK_QUESTS or "Auto Track Quests",
                    description = Description("DESC_AUTO_TRACK_QUESTS"),
                    image = GetSettingsImage("questtrack.png"),
                    requiresReload = false,
                },
                {
                    key = "autoSellGreys",
                    label = L.OPTION_AUTO_SELL_JUNK or "Auto Sell Junk",
                    description = Description("DESC_AUTO_SELL_JUNK"),
                    sideLogic = ShowSellJunkOptions,
                    image = GetSettingsImage("selljunk.png"),
                },
                {
                    key = "autoRepair",
                    label = L.OPTION_AUTO_REPAIR or "Auto Repair",
                    description = Description("DESC_AUTO_REPAIR"),
                    image = GetSettingsImage("repair.png"),
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
                },
                {
                    key = "hideErrorMessagesEnabled",
                    label = L.OPTION_HIDE_ERROR_MESSAGES or "Hide Error Messages",
                    description = Description("DESC_HIDE_ERROR_MESSAGES"),
                    image = GetSettingsImage("error.png"),
                },
            },
        },
        {
            title = L.SECTION_SETTINGS or "Settings",
            options = {
                {
                    key = "classicSettingsPresetEnabled",
                    label = L.OPTION_SETTINGS_PRESET or "Preset",
                    description = Description("DESC_SETTINGS_PRESET"),
                    image = GetSettingsImage("preset.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyClassicSettingsPreset then Carpenter_ApplyClassicSettingsPreset() end
                    end,
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
                    onToggle = function()
                        if Carpenter_ApplyActionCam then Carpenter_ApplyActionCam() end
                    end,
                },
            },
        },
    }

    return sections
end
