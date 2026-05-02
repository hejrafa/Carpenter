local _, ns = ...

Carpenter = Carpenter or {}
ns = ns or {}

local L = ns.L or {}
ns.L = L
Carpenter.L = L

setmetatable(L, {
    __index = function(tbl, key)
        return rawget(tbl, key) or key
    end,
})

L.ADDON_NAME = "Carpenter"
L.RELOAD_UI = "Reload UI"
L.REQUIRES_RELOAD = "Requires UI reload"
L.SIDEBAR_PLACEHOLDER = "Hover over an option to the left to see its description and settings."
L.CONFIG_NOT_LOADED = "Config UI not loaded."
L.NO_RETAIL_OPTIONS = "Retail support is wired up, but no Retail options are enabled yet."
L.EQUIP_TO_SLOT = "Equip to Slot:"
L.TRINKET_TOP = "Trinket 13 (Top)"
L.TRINKET_BOTTOM = "Trinket 14 (Bottom)"
L.FOOD = "Food"
L.WATER = "Water"
L.HEALTH = "Health"
L.MANA = "Mana"
L.BANDAGE = "Bandage"
L.FILTER_GUILD_RECRUITMENT = "Guild recruitment"
L.FILTER_BOT_SPAM = "Bot spam"
L.FILTER_GAMBLING = "Gambling"
L.FILTER_DUPLICATES = "Duplicates"
L.FILTER_RESTEDXP = "RestedXP level-up spam"
L.SOLD_JUNK_ITEMS = "Sold junk items"
L.GEAR_REPAIRED = "Gear repaired"
L.INTERRUPTED = "Interrupted"

L.SECTION_ACTION_BARS = "Action Bars"
L.SECTION_INTERFACE = "Interface"
L.SECTION_UNIT_FRAMES = "Unit Frames"
L.SECTION_NAMEPLATES = "Nameplates"
L.SECTION_CHAT = "Chat"
L.SECTION_AUTOMATIONS = "Automations"
L.SECTION_TEXT = "Text"
L.SECTION_IMMERSION = "Immersion"

L.OPTION_HIDE_MACRO_NAMES = "Hide Macro Names"
L.OPTION_HIDE_KEYBINDS = "Hide Keybind Text"
L.OPTION_ACTION_BAR_FADER = "Fade Extra Action Bars"
L.OPTION_ACTION_BAR_RANGE = "Out of Range Tint"
L.OPTION_HIDE_STANCE_BAR = "Hide Stance Bar"
L.OPTION_MENU_TRANSPARENCY = "Fade Micro Menu & Bags"
L.OPTION_SMALLER_EXP_BAR = "Resize Exp & Rep Bars"
L.OPTION_MINIMAP_CLUTTER = "Remove Minimap Clutter"
L.OPTION_ENHANCE_TOOLTIP = "Enhanced Tooltip"
L.OPTION_SCALE_EXTRA_ABILITY = "Scale Extra Ability"
L.OPTION_CLASS_HEALTH_COLORS = "Class Colored Health"
L.OPTION_THREAT_INDICATOR = "Threat Percentage"
L.OPTION_DEBUFFS = "Debuffs"
L.OPTION_CLASS_ICON_PORTRAIT = "Class Icon Portrait"
L.OPTION_HIDE_UNIT_FRAME_COMBAT_TEXT = "Hide Unit Frame Combat Text"
L.OPTION_CLEAN_UP_UNIT_FRAMES = "Clean Unit Frame"
L.OPTION_HIDE_PVP_ICON = "Hide PvP Icon"
L.OPTION_HIDE_POWER_BAR = "Hide Combo/Power Bar"
L.OPTION_HIDE_BOSS_FRAMES = "Hide Boss Frames"
L.OPTION_HIDE_REST_ANIMATION = "Hide Zzz Rest Animation"
L.OPTION_HIDE_HEALTH_LOSS_FX = "Hide Health Loss FX"
L.OPTION_HIDE_GROUP_INDICATOR = "Hide Group Indicator"
L.OPTION_HIDE_REALM_INDICATOR = "Hide Realm Indicator"
L.OPTION_HIDE_PLAYER_CORNER_ICON = "Hide Player Corner Icon"
L.OPTION_HIDE_PARTY_FRAME_TITLE = "Hide Party Text"
L.OPTION_HIDE_TARGET_REPUTATION_COLOR = "Hide Target Reputation Color"
L.OPTION_COMBO_POINTS = "Combo Points"
L.OPTION_CAST_BAR = "Cast Bar"
L.OPTION_RAID_TARGET_ICON_ALIGNED = "Raid Target Icon Aligned"
L.OPTION_CHAT_FILTER = "Filter"
L.OPTION_CHAT_CLEANER = "Cleaner"
L.OPTION_HIDE_CHAT_BUTTONS = "Hide Chat Buttons"
L.OPTION_MOUNT_SPEED_TRINKET = "Mount Speed Trinket"
L.OPTION_CONSUMABLE_MACROS = "Consumable Macros"
L.OPTION_AUTO_TRACK_QUESTS = "Auto Track Quests"
L.OPTION_AUTO_SELL_JUNK = "Auto Sell Junk"
L.OPTION_AUTO_REPAIR = "Auto Repair"
L.OPTION_POISON_WARNING = "Poison Warning"
L.OPTION_HIDE_ERROR_MESSAGES = "Hide Error Messages"
L.OPTION_ACTION_CAM = "Action Cam"
