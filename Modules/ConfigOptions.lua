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

    local sections = {
        {
            title = L.SECTION_ACTION_BARS or "Action Bars",
            options = {
                {
                    key = "hideMacroNamesEnabled",
                    label = L.OPTION_HIDE_MACRO_NAMES or "Hide Macro Names",
                    description = LightGrey .. "Macro labels can turn clean action bars into tiny text soup.\n\n" ..
                        "Hides " .. LighterCream .. "macro names" .. LightGrey .. " on action buttons so your bars stay icon-focused and easier to scan.",
                    image = GetSettingsImage("macrotext.png"),
                },
                {
                    key = "hideKeybindsEnabled",
                    label = L.OPTION_HIDE_KEYBINDS or "Hide Keybind Text",
                    description = LightGrey .. "Once your binds are muscle memory, hotkey text mostly gets in the way.\n\n" ..
                        "Hides " .. LighterCream .. "hotkey labels" .. LightGrey .. " on action buttons for quieter, cleaner bars.",
                    image = GetSettingsImage("keybind.png"),
                },
                {
                    key = "actionBarFaderEnabled",
                    label = L.OPTION_ACTION_BAR_FADER or "Fade Extra Action Bars",
                    description = LightGrey .. "Extra bars are useful, but they do not need to sit fully visible all the time.\n\n" ..
                        "Fades bars " .. LighterCream .. "7 and 8" .. LightGrey .. " until you hover them, then brings them back when you need a click.",
                    image = GetSettingsImage("actionbar.png"),
                },
                {
                    key = "actionBarRangeEnabled",
                    label = L.OPTION_ACTION_BAR_RANGE or "Out of Range Tint",
                    description = LightGrey .. "Range should be readable at a glance, especially when your target is moving.\n\n" ..
                        "Adds a subtle dark tint to " .. LighterCream .. "range-checked abilities" .. LightGrey .. " while your current target is out of range, then restores Blizzard's normal button look when you are close enough.",
                    image = GetSettingsImage("range.png"),
                    requiresReload = false,
                },
                {
                    key = "hideStanceBarEnabled",
                    label = L.OPTION_HIDE_STANCE_BAR or "Hide Stance Bar",
                    description = LightGrey .. "The stance bar can duplicate buttons you already bind elsewhere.\n\n" ..
                        "Hides the " .. LighterCream .. "Stance Bar" .. LightGrey .. " for forms, stances, and stealth buttons, keeping the bar out of sight while your binds still work.",
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
                    description = LightGrey .. "The micro menu and bag buttons are useful, but not every second of every fight.\n\n" ..
                        "Fades the " .. LighterCream .. "Micro Menu" .. LightGrey .. " and " .. LighterCream .. "Bag Bar" .. LightGrey .. " until you hover them or open your bags.",
                    image = GetSettingsImage("micromenu.png"),
                },
                {
                    key = "smallerExpBarEnabled",
                    label = L.OPTION_SMALLER_EXP_BAR or "Resize Exp & Rep Bars",
                    description = LightGrey .. "Experience and reputation bars carry useful progress, but they can be visually loud.\n\n" ..
                        "Scales the " .. LighterCream .. "Experience" .. LightGrey .. " and " .. LighterCream .. "Reputation" .. LightGrey .. " bars to 65% and lowers their opacity.",
                    image = GetSettingsImage("repbar.png"),
                },
                {
                    key = "minimapClutterEnabled",
                    label = L.OPTION_MINIMAP_CLUTTER or "Remove Minimap Clutter",
                    description = LightGrey .. "The minimap works better when the frame around it stays quiet.\n\n" ..
                        "Hides the minimap " .. LighterCream .. "zoom buttons" .. LightGrey .. ", " .. LighterCream .. "day/night icon" .. LightGrey .. ", and " .. LighterCream .. "zone text bar" .. LightGrey .. " while keeping mousewheel zoom available.",
                    image = GetSettingsImage("minimapclutter.png"),
                },
                {
                    key = "enhanceTooltipEnabled",
                    label = L.OPTION_ENHANCE_TOOLTIP or "Enhanced Tooltip",
                    description = LightGrey .. "Default unit tooltips can be bulky for how often you read them.\n\n" ..
                        "Cleans up " .. LighterCream .. "unit tooltips" .. LightGrey .. " by hiding the health bar, recoloring name and level lines, and showing the unit's current target.",
                    image = GetSettingsImage("tooltip.png"),
                },
                {
                    key = "enhanceUIEnabled",
                    label = L.OPTION_ENHANCE_UI or "Enhance UI",
                    description = LightGrey .. "Some Classic interface panels are cramped for repeated use.\n\n" ..
                        "Expands the " .. LighterCream .. "quest log" .. LightGrey .. ", " .. LighterCream .. "professions" .. LightGrey .. ", and " .. LighterCream .. "trainer" .. LightGrey .. " frames, adds quest levels and a map button, and adds a trainer " .. LighterCream .. "Train All" .. LightGrey .. " button.",
                    image = GetSettingsImage("tooltip.png"),
                },
                {
                    key = "scaleExtraAbilityEnabled",
                    label = L.OPTION_SCALE_EXTRA_ABILITY or "Scale Extra Ability",
                    description = LightGrey .. "Retail's extra ability buttons can appear oversized compared with the rest of your UI.\n\n" ..
                        "Scales the " .. LighterCream .. "Extra Action" .. LightGrey .. " and " .. LighterCream .. "Zone Ability" .. LightGrey .. " buttons to " .. LighterCream .. "80%" .. LightGrey .. ".",
                    image = GetSettingsImage("actionbar.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyExtraAbilityScale then Carpenter_ApplyExtraAbilityScale() end
                    end,
                },
                {
                    key = "hideBossFramesEnabled",
                    label = L.OPTION_HIDE_BOSS_FRAMES or "Hide Boss Frames",
                    description = LightGrey .. "Boss frames can duplicate information already covered by nameplates, raid frames, or boss mods.\n\n" ..
                        "Fades Retail " .. LighterCream .. "boss unit frames" .. LightGrey .. " and disables their mouse interaction.",
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
                    description = LightGrey .. "Green health bars are readable, but class color is faster to recognize.\n\n" ..
                        "Colors " .. LighterCream .. "player, target, focus, and party health bars" .. LightGrey .. " by class where class information is available.",
                    image = GetSettingsImage("classhealthbar.png"),
                },
                {
                    key = "threatIndicatorEnabled",
                    label = L.OPTION_THREAT_INDICATOR or "Threat Percentage",
                    description = LightGrey .. "Threat is easier to manage when the number is where your eyes already are.\n\n" ..
                        "Shows your " .. LighterCream .. "threat percentage" .. LightGrey .. " on the target frame so you can ease off, hold steady, or push with confidence.",
                    image = GetSettingsImage("threat.png"),
                },
                {
                    key = "targetHealthPercentEnabled",
                    label = L.OPTION_TARGET_HEALTH_PERCENT or "Target Percentages",
                    description = LightGrey .. "Classic can show your own health as a percentage, but enemy target frames stay vague.\n\n" ..
                        "Shows compact " .. LighterCream .. "health and resource percentages" .. LightGrey .. " on player targets and hostile target frames.",
                    image = GetSettingsImage("unitnumbers.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_UpdateTargetHealthPercent then Carpenter_UpdateTargetHealthPercent() end
                    end,
                },
                {
                    key = "unitFrameDebuffsEnabled",
                    label = L.OPTION_DEBUFFS or "Debuffs",
                    description = LightGrey .. "Crowd control should stand out from ordinary aura noise.\n\n" ..
                        "Highlights important " .. LighterCream .. "CC effects" .. LightGrey .. " such as stuns, polymorphs, fears, and similar debuffs on player and target unit frames.",
                    image = GetSettingsImage("unitdebuff.png"),
                },
                {
                    key = "unitFrameBuffsEnabled",
                    label = L.OPTION_UNIT_FRAME_BUFFS or "Buffs",
                    description = LightGrey .. "Your own cooldown buffs should be visible where your eyes already check your health.\n\n" ..
                        "Highlights important " .. LighterCream .. "player buffs" .. LightGrey .. " such as Sprint, Slice and Dice, defensive cooldowns, offensive cooldowns, and immunities on the player unit frame.",
                    image = GetSettingsImage("unitdebuff.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_UpdateUnitFrameAuras then Carpenter_UpdateUnitFrameAuras() end
                    end,
                },
                {
                    key = "unitFrameClassIconEnabled",
                    label = L.OPTION_CLASS_ICON_PORTRAIT or "Class Icon Portrait",
                    description = LightGrey .. "Unit portraits are flavorful, but class icons are faster to parse.\n\n" ..
                        "Replaces player, target, and focus " .. LighterCream .. "portraits" .. LightGrey .. " with class icons. When Debuffs is enabled, CC effects can still take over the portrait as usual.",
                    image = GetSettingsImage("classicon.png"),
                },
                {
                    key = "hideUnitFrameCombatTextEnabled",
                    label = L.OPTION_HIDE_UNIT_FRAME_COMBAT_TEXT or "Hide Unit Frame Combat Text",
                    description = LightGrey .. "Combat text on unit portraits can compete with the information around the frame.\n\n" ..
                        "Hides " .. LighterCream .. "damage" .. LightGrey .. ", " .. LighterCream .. "healing" .. LightGrey .. ", " .. LighterCream .. "avoidance" .. LightGrey .. ", periodic numbers, and combat state messages on player and pet portrait frames.",
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
                    description = LightGrey .. "Retail unit frames carry several small decorative markers around the core health and name information.\n\n" ..
                        "Hides " .. LighterCream .. "combat text" .. LightGrey .. ", " .. LighterCream .. "PvP icons" .. LightGrey .. ", the " .. LighterCream .. "combat sword" .. LightGrey .. ", " .. LighterCream .. "Zzz rest animation" .. LightGrey .. ", " .. LighterCream .. "health loss FX" .. LightGrey .. ", player " .. LighterCream .. "corner icon" .. LightGrey .. ", target " .. LighterCream .. "reputation color" .. LightGrey .. ", " .. LighterCream .. "party frame title text" .. LightGrey .. ", and " .. LighterCream .. "realm indicators" .. LightGrey .. ".",
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
                    description = LightGrey .. "Some class resources are already shown better on your bars, nameplates, or custom UI.\n\n" ..
                        "Hides Retail " .. LighterCream .. "class resource widgets" .. LightGrey .. " such as combo points, runes, holy power, soul shards, arcane charges, essence, and the personal resource bar.",
                    image = GetSettingsImage("nameplatecombo.png"),
                    requiresReload = false,
                    onToggle = function()
                        if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                    end,
                },
                {
                    key = "hideGroupIndicatorEnabled",
                    label = L.OPTION_HIDE_GROUP_INDICATOR or "Hide Group Indicator",
                    description = LightGrey .. "Hides the small " .. LighterCream .. "group number indicator" .. LightGrey .. " attached to the player frame.",
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
                    description = LightGrey .. "Crowd control on enemy nameplates should be visible without searching through tiny aura icons.\n\n" ..
                        "Shows important " .. LighterCream .. "CC effects" .. LightGrey .. " above enemy nameplates so you can see what is controlled at a glance.",
                    image = GetSettingsImage("nameplatedebuff.png"),
                },
                {
                    key = "nameplateComboEnabled",
                    label = L.OPTION_COMBO_POINTS or "Combo Points",
                    description = LightGrey .. "Combo points are easier to use when they sit on the thing you are attacking.\n\n" ..
                        "Displays your " .. LighterCream .. "combo points" .. LightGrey .. " on the target's nameplate for cleaner finisher timing.",
                    image = GetSettingsImage("nameplatecombo.png"),
                },
                {
                    key = "nameplateCastNamesEnabled",
                    label = L.OPTION_CAST_BAR or "Cast Bar",
                    description = LightGrey .. "Enemy casts need enough detail to act on quickly.\n\n" ..
                        "Adds a full " .. LighterCream .. "cast bar" .. LightGrey .. " below enemy nameplates with spell icon, spell name, progress, and interrupt feedback. Casts are gold, channels are green, and interrupted casts flash red.",
                    image = GetSettingsImage("spellname.png"),
                },
                {
                    key = "nameplateClassHealthEnabled",
                    label = L.OPTION_CLASS_HEALTH_COLORS or "Class Colored Health",
                    description = LightGrey .. "Enemy player nameplates are easier to read when class is visible in the bar itself.\n\n" ..
                        "Colors enemy player " .. LighterCream .. "nameplate health bars" .. LightGrey .. " by class, making healers, melee, and priority targets quicker to spot.",
                    image = GetSettingsImage("classhealthnameplate.png"),
                },
                {
                    key = "raidTargetIconAlignedEnabled",
                    label = L.OPTION_RAID_TARGET_ICON_ALIGNED or "Raid Target Icon Aligned",
                    description = LightGrey .. "Raid target icons can float awkwardly high above nameplates.\n\n" ..
                        "Moves " .. LighterCream .. "raid target icons" .. LightGrey .. " down so they sit closer to the nameplate they belong to.",
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
                    description = LightGrey .. "Trade and general chat can get noisy fast.\n\n" ..
                        "Filters common " .. LighterCream .. "spam patterns" .. LightGrey .. " such as guild recruitment, bot ads, gambling messages, duplicate lines, and RestedXP level-up announcements.",
                    sideLogic = ShowFilterOptions,
                    image = GetSettingsImage("chatfilter.png"),
                },
                {
                    key = "chatCleanerEnabled",
                    label = L.OPTION_CHAT_CLEANER or "Cleaner",
                    description = LightGrey .. "System messages are useful, but Blizzard's default formatting can be hard to scan.\n\n" ..
                        "Restyles " .. LighterCream .. "system and loot messages" .. LightGrey .. " for experience, reputation, money, learned abilities, currency, repairs, and similar events.",
                    image = GetSettingsImage("chatcleaner.png"),
                },
                {
                    key = "hideChatButtonsEnabled",
                    label = L.OPTION_HIDE_CHAT_BUTTONS or "Hide Chat Buttons",
                    description = LightGrey .. "Chat buttons are handy, but they do not need to frame the chat box all day.\n\n" ..
                        "Fades default " .. LighterCream .. "chat buttons" .. LightGrey .. " such as Chat Channels, Voice, scroll arrows, and minimize controls until you hover the chat area.",
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
                    description = LightGrey .. "Mount speed trinkets are useful, but manual swapping gets old quickly.\n\n" ..
                        "Equips " .. LighterCream .. "Riding Crop" .. LightGrey .. " if available, otherwise " .. LighterCream .. "Carrot on a Stick" .. LightGrey .. ", when you mount. Your previous trinket is restored when you dismount.",
                    sideLogic = ShowCarrotSlots,
                    image = GetSettingsImage("carrot.png"),
                },
                {
                    key = "smartMacrosEnabled",
                    label = L.OPTION_CONSUMABLE_MACROS or "Consumable Macros",
                    description = LightGrey .. "Consumable buttons are better when they follow your bags automatically.\n\n" ..
                        "Creates draggable macros for your best available " .. LighterCream .. "food" .. LightGrey .. ", " .. LighterCream .. "water" .. LightGrey .. ", " .. LighterCream .. "health potion" .. LightGrey .. ", " .. LighterCream .. "mana potion" .. LightGrey .. ", and supported bandages.",
                    sideLogic = ShowMacroPreviews,
                    image = GetSettingsImage("macro.png"),
                },
                {
                    key = "autoTrackQuestsEnabled",
                    label = L.OPTION_AUTO_TRACK_QUESTS or "Auto Track Quests",
                    description = LightGrey .. "New quests should land in the tracker without an extra trip to the quest log.\n\n" ..
                        "Automatically adds " .. LighterCream .. "newly accepted quests" .. LightGrey .. " to the objective tracker.",
                    image = GetSettingsImage("questtrack.png"),
                    requiresReload = false,
                },
                {
                    key = "autoSellGreys",
                    label = L.OPTION_AUTO_SELL_JUNK or "Auto Sell Junk",
                    description = LightGrey .. "Grey items are vendor trash by design.\n\n" ..
                        "Sells " .. LighterCream .. "grey-quality items" .. LightGrey .. " when you open a merchant. Hold " .. LighterCream .. "Shift" .. LightGrey .. " while opening the merchant to skip the sale.",
                    sideLogic = ShowSellJunkOptions,
                    image = GetSettingsImage("selljunk.png"),
                },
                {
                    key = "autoRepair",
                    label = L.OPTION_AUTO_REPAIR or "Auto Repair",
                    description = LightGrey .. "Repairing is easy to forget until your gear makes it your problem.\n\n" ..
                        "Repairs your " .. LighterCream .. "gear" .. LightGrey .. " with your gold when you open a repair vendor. Hold " .. LighterCream .. "Shift" .. LightGrey .. " while opening the vendor to skip repair.",
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
                    description = LightGrey .. "Weapon buffs are easy to miss when they fall off mid-session.\n\n" ..
                        "Shows an alert when your " .. LighterCream .. "weapon buff" .. LightGrey .. " such as poison or sharpening stone is missing or about to expire.",
                    image = GetSettingsImage("warning.png"),
                },
                {
                    key = "hideErrorMessagesEnabled",
                    label = L.OPTION_HIDE_ERROR_MESSAGES or "Hide Error Messages",
                    description = LightGrey .. "Repeated red error text can become visual noise during combat.\n\n" ..
                        "Silences common " .. LighterCream .. "ability errors" .. LightGrey .. " such as Out of range and Not enough energy while leaving important errors visible.",
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
                    description = LightGrey .. "A quick Classic baseline for fresh characters or clients.\n\n" ..
                        "Turns on " .. LighterCream .. "auto loot" .. LightGrey .. ", " .. LighterCream .. "enemy unit and minion nameplates" .. LightGrey .. ", " .. LighterCream .. "health percentages" .. LightGrey .. ", and " .. LighterCream .. "action bars 2 and 3" .. LightGrey .. ". Carpenter reapplies these settings when you log in while the preset is enabled.",
                    image = GetSettingsImage("actionbar.png"),
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
                    description = LightGrey .. "A small camera shift can make the world feel less like a spreadsheet with dragons.\n\n" ..
                        "Uses a DynamicCam-style " .. LighterCream .. "over-the-shoulder camera" .. LightGrey .. " with vertical pitch, a wider mounted zoom, and adjusted Retail spell activation overlays.",
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
