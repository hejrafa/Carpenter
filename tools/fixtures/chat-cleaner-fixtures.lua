#!/usr/bin/env lua
-- Offline fixture checks for Chat Cleaner formatting.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

unpack = unpack or table.unpack
floor = math.floor

local ns = { Private = {} }
Carpenter = {
    L = {},
    Client = { isMainline = false },
    -- Retail's and Forever's atlas markup, so every money line tests the whole
    -- chat pipeline with it. tools/fixtures/money-icons-fixtures.lua pins which client gets
    -- which icons.
    MoneyIcons = {
        Gold = "|A:coin-gold:10:10:2:0|a",
        Silver = "|A:coin-silver:10:10:2:0|a",
        Copper = "|A:coin-copper:10:10:2:0|a",
    },
    MinusSign = "\226\136\146",
    IsEnabled = function(_, key) return key == "chatCleanerEnabled" end,
    RegisterFeature = function(_, key, feature)
        registeredChatFeatures = registeredChatFeatures or {}
        table.insert(registeredChatFeatures, { key = key, feature = feature })
    end,
    Profile = function(_, _, callback, ...)
        return callback(...)
    end,
}

RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
}
ITEM_QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1.00, g = 1.00, b = 1.00 },
    [2] = { r = 0.12, g = 1.00, b = 0.00 },
    [3] = { r = 0.00, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
}
ChatTypeInfo = {
    PARTY = { r = 0.67, g = 0.67, b = 1 },
    RAID = { r = 1, g = 0.50, b = 0 },
    GUILD = { r = 64 / 255, g = 1, b = 64 / 255 },
}

CHAT_PARTY_LEADER_GET = "[Party Leader] %s: "
CHAT_PARTY_GET = "[Party] %s: "
CHAT_RAID_LEADER_GET = "[Raid Leader] %s: "
CHAT_RAID_GET = "[Raid] %s: "
CHAT_INSTANCE_CHAT_LEADER_GET = "[Instance Leader] %s: "
CHAT_INSTANCE_CHAT_GET = "[Instance] %s: "
CHAT_GUILD_GET = "[Guild] %s: "
CHAT_OFFICER_GET = "[Officer] %s: "
CHAT_RAID_WARNING_GET = "[Raid Warning] %s: "

LOOT_ITEM = "%s receives loot: %s."
LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
LOOT_ITEM_PUSHED = "%s receives item: %s."
LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
LOOT_ITEM_CREATED_SELF = "You create: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
CREATED_ITEM = "%s creates: %s."
CREATED_ITEM_MULTIPLE = "%s creates: %sx%d."
LOOT_ROLL_NEED = "%s has selected Need for: %s"
LOOT_ROLL_GREED = "%s has selected Greed for: %s"
LOOT_ROLL_DISENCHANT = "%s has selected Disenchant for: %s"
LOOT_ROLL_WON = "%s won: %s"

NUM_CHAT_WINDOWS = 1
_G.ChatFrame1 = { AddMessage = function() end }
_G.ChatFrame1EditBox = {
    GetRegions = function() end,
}

local now = 1000
local currentMoney = 0
local groupMembers = 0
local inRaid = false
local inCombatLockdown = false
local fixtureFriends = {
    { name = "Dreadwarden", className = "Mage", connected = true },
}
local fixtureGuildMembers = {
    { name = "Wightwalker", className = "Rogue", classFileName = "ROGUE", online = false },
}
function GetTime() return now end
function GetMoney() return currentMoney end
function GetLocale() return "enUS" end
function IsInRaid() return inRaid end
function GetNumGroupMembers() return groupMembers end
function InCombatLockdown() return inCombatLockdown end
function GetNumFriends() return #fixtureFriends end
function GetFriendInfo(index)
    local friend = fixtureFriends[index]
    if not friend then return nil end
    return friend.name, 60, friend.className, "Stormwind", friend.connected
end
function GetNumGuildMembers() return #fixtureGuildMembers end
function GetGuildRosterInfo(index)
    local member = fixtureGuildMembers[index]
    if not member then return nil end
    return member.name, "Member", 0, 60, member.className, "Stormwind", "", "", member.online, nil, member.classFileName
end
function UnitName(unit)
    if unit == "player" then return "Tester" end
    return nil
end
function UnitClass(unit)
    if unit == "player" then return "Warrior", "WARRIOR" end
    return nil, nil
end
function GetItemInfo(item)
    if type(item) == "string" then
        local name = item:match("|h%[(.-)%]|h") or item:match("%[(.-)%]")
        if name then return name, item, 2 end
    end
    return nil, nil, nil
end
local createdFrames = {}
function CreateFrame()
    local frame = { _scripts = {}, _events = {} }
    createdFrames[#createdFrames + 1] = frame
    function frame:RegisterEvent(event) self._events[event] = true end
    function frame:RegisterUnitEvent() end
    function frame:UnregisterAllEvents() end
    function frame:SetScript(script, handler) self._scripts[script] = handler end
    function frame:Hide() self.hidden = true end
    function frame:Show() self.hidden = false end
    function frame:IsShown() return not self.hidden end
    return frame
end
function ChatFrame_AddMessageEventFilter() end
function ChatFrame_RemoveMessageEventFilter() end

C_Timer = {
    After = function(_, callback) callback() end,
}

local function loadAddonFile(path)
    local chunk, err = loadfile(repo .. "/" .. path)
    if not chunk then error(err) end
    return chunk("Carpenter", ns)
end

loadAddonFile("Localization/enUS.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerUtils.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerLoot.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerSessions.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerSystem.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerRewards.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerSocial.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerPostProcess.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerLifecycle.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleanerHiddenLines.lua")
loadAddonFile("Modules/ChatCleaner/ChatCleaner.lua")

local filter = ns.Private.ChatCleaner and ns.Private.ChatCleaner.FilterImpl
assert(type(filter) == "function", "ChatCleaner filter was not exposed")
local postProcessor = ns.Private.ChatCleaner and ns.Private.ChatCleaner.PostProcessor
assert(type(postProcessor) == "table" and type(postProcessor.ProcessMessage) == "function", "ChatCleaner post-processor was not exposed")

local function plain(text)
    if not text then return text end
    return text
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1")
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local fixtures = {
    {
        name = "fatigue death",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "Lionginas died of fatigue in The Merchant Coast! They were level 32",
        expectPlain = "Lionginas died from fatigue! Level 32",
    },
    {
        name = "lava crisp death",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "Duckboisolo was burnt to a crisp by lava in Ragefire Chasm! They were level 14",
        expectPlain = "Duckboisolo burned! Level 14",
    },
    {
        name = "slain death keeps killer",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "Hulksmash was slain by Baron Silverlaine in Shadowfang Keep! They were level 25",
        expectPlain = "Hulksmash was slain by Baron Silverlaine! Level 25",
    },
    -- Blizzard batches battleground joins and leaves at the start and prints
    -- them straight to the chat frame, past every chat filter.
    {
        name = "batched battleground joins",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "3 players have joined the battle: Muhlixier Naturebro, Xarodas Schwarzhuf, Peti Lucko",
        expectPlain = "Muhlixier Naturebro, Xarodas Schwarzhuf, Peti Lucko joined",
    },
    {
        name = "batched battleground leave",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "Gorb Garnsson has left the battle.",
        expectPlain = "Gorb Garnsson left",
        requireColor = "|cffff4040",
    },
    {
        name = "batched battleground leaves list",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "2 players have left the battle: Gorb Garnsson, Peti Lucko",
        expectPlain = "Gorb Garnsson, Peti Lucko left",
        requireColor = "|cffff4040",
    },
    {
        name = "batched battleground leave count",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "5 players have left the battle.",
        expectPlain = "5 players left",
        requireColor = "|cffff4040",
    },
    {
        name = "player links keep original color",
        path = "post",
        event = "CHAT_MSG_CHANNEL",
        message = "|Hplayer:Tester|h[Tester]|h says hi",
        expectPlain = "Tester says hi",
        rejectColor = "|cffc69b6d",
    },
    {
        name = "channel line keeps the number and the sender",
        path = "post",
        event = "CHAT_MSG_CHANNEL",
        message = "|Hchannel:channel:1|h[1. General - Mulgore]|h |Hplayer:Bob:1:CHANNEL:1|h[Bob]|h: hello",
        expectPlain = "1. Bob: hello",
    },
    {
        name = "channel line with no sender drops the colon",
        path = "post",
        event = "CHAT_MSG_CHANNEL",
        message = "|Hchannel:channel:3|h[3. LocalDefense - Mulgore]|h : Thunder Bluff is under attack!",
        expectPlain = "3. Thunder Bluff is under attack!",
    },
    {
        name = "channel line keeps a colon the sender typed",
        path = "post",
        event = "CHAT_MSG_CHANNEL",
        message = "|Hchannel:channel:1|h[1. General - Mulgore]|h |Hplayer:Bob:1:CHANNEL:1|h[Bob]|h:  : hello",
        expectPlain = "1. Bob: : hello",
    },
    {
        name = "story mode say lost in battle passes",
        event = "CHAT_MSG_SAY",
        author = "Kohji",
        message = "[Kohji] says: [Gutterspeak] [Story Mode: Lost in Battle]",
        expectPlain = "[Kohji] says: [Gutterspeak] [Story Mode: Lost in Battle]",
    },
    {
        name = "story mode say arugal passes",
        event = "CHAT_MSG_SAY",
        author = "Kohji",
        message = "[Kohji] says: [Gutterspeak] [Story Mode: Arugal and Shadowfang Keep]",
        expectPlain = "[Kohji] says: [Gutterspeak] [Story Mode: Arugal and Shadowfang Keep]",
    },
    {
        name = "system battle loss stays hidden",
        event = "CHAT_MSG_SYSTEM",
        message = "Your team lost the battle.",
        expectHidden = true,
    },
    {
        name = "left channel hidden",
        event = "CHAT_MSG_SYSTEM",
        message = "Left Channel: 1. General - Elwynn Forest",
        expectHidden = true,
    },
    {
        name = "monster emote placeholders are escaped",
        event = "CHAT_MSG_MONSTER_EMOTE",
        author = "Defias Thief",
        message = "%s points at %o target.",
        expectPlain = "Defias Thief points at Defias Thief target.",
    },
    {
        name = "invited a player",
        event = "CHAT_MSG_SYSTEM",
        message = "You have invited Vispera Maur to join your group.",
        expectPlain = "Invited Vispera Maur",
        requireColor = "|cff00ff00",
    },
    {
        name = "suggested a player reads like an invite",
        event = "CHAT_MSG_SYSTEM",
        message = "You have suggested that Vispera Maur join your group.",
        expectPlain = "Suggested Vispera Maur",
        requireColor = "|cff00ff00",
    },
    {
        name = "feel rested",
        event = "CHAT_MSG_SYSTEM",
        message = "You feel rested.",
        expectPlain = "Rested",
    },
    {
        name = "feel normal",
        event = "CHAT_MSG_SYSTEM",
        message = "You feel normal.",
        expectPlain = "Normal",
    },
    {
        name = "Forever no longer rested reads like feel normal",
        event = "CHAT_MSG_SYSTEM",
        message = "You are no longer rested.",
        expectPlain = "Normal",
    },
    -- The link keeps its brackets at this stage; the post-processor drops them.
    {
        name = "learned spell",
        event = "CHAT_MSG_SYSTEM",
        message = "You have learned a new spell: |cff71d5ff|Hspell:2983|h[Sprint]|h|r.",
        expectPlain = "+ Learned: [Sprint]",
        requireColors = { "|cffffffffLearned:" },
    },
    {
        name = "learned passive effect reads like a learned spell",
        event = "CHAT_MSG_SYSTEM",
        message = "You have learned a new passive effect: |cff71d5ff|Hspell:3127|h[Parry (Passive)]|h|r.",
        expectPlain = "+ Learned: [Parry (Passive)]",
        requireColors = { "|cffffffffLearned:" },
    },
    {
        name = "loot roll range",
        event = "CHAT_MSG_LOOT",
        message = "Yantiparazi rolls 40 (1-100)",
        expectPlain = "Yantiparazi rolls 40 (1-100)",
        rejectColor = "|cffc69b6d",
    },
    {
        name = "loot prefix self item",
        event = "CHAT_MSG_LOOT",
        message = "Loot: Sentry's Gloves of the Monkey",
        expectPlain = "Loot + Sentry's Gloves of the Monkey",
        requireColors = { "|cffffffffLoot|r", "|cff00ff00Sentry's Gloves of the Monkey|r" },
    },
    {
        name = "bare loot prefix item",
        event = "CHAT_MSG_SYSTEM",
        message = "Loot: Malachite",
        expectPlain = "Loot + Malachite",
        requireColors = { "|cffffffffLoot|r", "|cff00ff00Malachite|r" },
    },
    {
        name = "group bare loot prefix item uses party color",
        event = "CHAT_MSG_LOOT",
        groupMembers = 2,
        message = "Loot: Malachite",
        expectPlain = "Loot + Malachite",
        requireColors = { "|cffaaaaffLoot|r", "|cff00ff00Malachite|r" },
    },
    {
        name = "bare loot post-process item",
        path = "post",
        event = "CHAT_MSG_LOOT",
        message = "Loot: Disciple's Robe of the Eagle",
        expectPlain = "Loot + Disciple's Robe of the Eagle",
        requireColors = { "|cffffffffLoot|r", "|cff00ff00Disciple's Robe of the Eagle|r" },
    },
    {
        name = "group bare loot post-process item uses party color",
        path = "post",
        event = "CHAT_MSG_LOOT",
        groupMembers = 2,
        message = "|cff00ff00Loot:|r Disciple's Robe of the Eagle",
        expectPlain = "Loot + Disciple's Robe of the Eagle",
        requireColors = { "|cffaaaaffLoot|r", "|cff00ff00Disciple's Robe of the Eagle|r" },
    },
    {
        name = "raid bare loot post-process item uses raid color",
        path = "post",
        event = "CHAT_MSG_LOOT",
        groupMembers = 10,
        inRaid = true,
        message = "|cff00ff00Loot:|r Disciple's Robe of the Eagle",
        expectPlain = "Loot + Disciple's Robe of the Eagle",
        requireColors = { "|cffff7f00Loot|r", "|cff00ff00Disciple's Robe of the Eagle|r" },
    },
    {
        name = "colored bare loot post-process item",
        path = "post",
        event = "CHAT_MSG_LOOT",
        message = "|cff00ff00Loot:|r Disciple's Robe of the Eagle",
        expectPlain = "Loot + Disciple's Robe of the Eagle",
        requireColors = { "|cffffffffLoot|r", "|cff00ff00Disciple's Robe of the Eagle|r" },
    },
    {
        name = "colored bare loot post-process line",
        path = "post",
        event = "CHAT_MSG_LOOT",
        message = "|cff00ff00Loot: Disciple's Robe of the Eagle|r",
        expectPlain = "Loot + Disciple's Robe of the Eagle",
        requireColors = { "|cffffffffLoot|r", "|cff00ff00Disciple's Robe of the Eagle|r" },
    },
    {
        name = "combat item link filter keeps styling",
        event = "CHAT_MSG_LOOT",
        inCombatLockdown = true,
        message = "You receive loot: |cff1eff00|Hitem:774::::::::|h[Malachite]|h|r.",
        expectPlain = "+ [Malachite]",
        requireColors = { "|cffc8c8c8+|r", "|Hitem:774::::::::|h" },
    },
    {
        name = "combat item link post-process keeps styling",
        path = "post",
        event = "CHAT_MSG_LOOT",
        inCombatLockdown = true,
        message = "Loot: |cff1eff00|Hitem:774::::::::|h[Malachite]|h|r",
        expectPlain = "Loot + Malachite",
        requireColors = { "|cffffffffLoot|r", "|cffc8c8c8+|r", "|Hitem:774::::::::|h" },
    },
    {
        name = "group loot channel uses party color",
        event = "CHAT_MSG_LOOT",
        groupMembers = 2,
        message = "Malagas receives loot: Ruined Leather Scraps.",
        expectPlain = "Malagas + Ruined Leather Scraps",
        requireColor = "|cffaaaaffMalagas ",
    },
    {
        name = "raid loot channel uses raid color",
        event = "CHAT_MSG_LOOT",
        groupMembers = 10,
        inRaid = true,
        message = "Malagas receives loot: Ruined Leather Scraps.",
        expectPlain = "Malagas + Ruined Leather Scraps",
        requireColor = "|cffff7f00Malagas ",
    },
    {
        name = "party loot uses party color",
        event = "CHAT_MSG_PARTY",
        author = "Mirella",
        message = "Mirella receives loot: Medium Leather.",
        expectPlain = "Mirella + Medium Leather",
        requireColor = "|cffaaaaffMirella ",
    },
    {
        name = "raid loot uses raid color",
        event = "CHAT_MSG_RAID",
        author = "Mirella",
        message = "Mirella receives loot: Medium Leather.",
        expectPlain = "Mirella + Medium Leather",
        requireColor = "|cffff7f00Mirella ",
    },
    {
        name = "loot roll selected compact",
        event = "CHAT_MSG_LOOT",
        message = "Loot: You have selected Greed for: Sentry's Gloves of the Monkey",
        expectPlain = "You Greed Sentry's Gloves of the Monkey",
        rejectPlain = "selected",
    },
    {
        name = "group loot roll selected uses party color",
        event = "CHAT_MSG_LOOT",
        groupMembers = 2,
        message = "Loot: You have selected Greed for: Malachite",
        expectPlain = "You Greed Malachite",
        requireColor = "|cffaaaaffYou|r |cffaaaaffGreed|r",
    },
    {
        name = "raid loot roll selected uses raid color",
        event = "CHAT_MSG_LOOT",
        groupMembers = 10,
        inRaid = true,
        message = "Loot: You have selected Greed for: Malachite",
        expectPlain = "You Greed Malachite",
        requireColor = "|cffff7f00You|r |cffff7f00Greed|r",
    },
    {
        name = "group loot roll item uses party color",
        event = "CHAT_MSG_LOOT",
        groupMembers = 2,
        message = "You rolls 80: Malachite",
        expectPlain = "You roll 80 Malachite",
        requireColor = "|cffaaaaffYou|r |cffaaaaffroll 80|r",
    },
    {
        name = "loot roll won compact",
        event = "CHAT_MSG_LOOT",
        message = "Loot: You won: Sentry's Gloves of the Monkey",
        expectPlain = "You won Sentry's Gloves of the Monkey",
    },
    {
        name = "loot roll won strips leading semicolon",
        event = "CHAT_MSG_LOOT",
        message = "Loot: ; You won: Sentry's Gloves of the Monkey",
        expectPlain = "You won Sentry's Gloves of the Monkey",
        rejectPlain = ";",
    },
    {
        name = "self level up capitalization",
        event = "CHAT_MSG_SYSTEM",
        message = "Reached level 24.",
        expectPlain = "Reached level 24",
        rejectColor = "|cffc69b6d",
    },
    {
        name = "retail plain appearance collection",
        event = "CHAT_MSG_SYSTEM",
        isMainline = true,
        message = "Ragged Leather Bracers has been added to your appearance collection.",
        expectPlain = "+ Appearance: Ragged Leather Bracers",
        requireColors = { "|cffc8c8c8+|r", "|cffffffffAppearance: |r", "|cffff80ffRagged Leather Bracers|r" },
    },
    {
        name = "forever linked appearance collection",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        isMainline = true,
        message = "|cff1eff00|Hitem:1418::::::::|h[Ragged Leather Bracers]|h|r has been added to your appearance collection.",
        expectPlain = "+ Appearance: Ragged Leather Bracers",
        requireColors = { "|cffc8c8c8+|r", "|cffffffffAppearance: |r", "|cffff80ff|Hitem:1418::::::::|hRagged Leather Bracers|h|r" },
    },
    {
        name = "classic appearance collection remains unchanged",
        event = "CHAT_MSG_SYSTEM",
        message = "Ragged Leather Bracers has been added to your appearance collection.",
        expectPlain = "Ragged Leather Bracers has been added to your appearance collection.",
    },
    {
        name = "other player level up keeps name",
        event = "CHAT_MSG_SYSTEM",
        message = "Mirella has reached level 13.",
        expectPlain = "Mirella reached level 13",
    },
    {
        name = "guild chat level mention keeps channel color",
        path = "post",
        event = "CHAT_MSG_GUILD",
        message = "|cff40ff40G Durlock: Durlock the Warlock reached level 10|r",
        expectPlain = "G Durlock: Durlock the Warlock reached level 10",
        requireColor = "|cff40ff40",
        rejectColor = "|cffffffff",
    },
    {
        name = "guild prefix post-process compact",
        path = "post",
        event = "CHAT_MSG_GUILD",
        message = "|cff40ff40[Guild] Tester: looking for mats|r",
        expectPlain = "[G] Tester: looking for mats",
        requireColor = "|cff40ff40",
        rejectPlain = "[Guild]",
    },
    {
        name = "combat guild prefix post-process compact",
        path = "post",
        event = "CHAT_MSG_GUILD",
        inCombatLockdown = true,
        message = "|cff40ff40[Guild] Tester: still cleaning|r",
        expectPlain = "[G] Tester: still cleaning",
        requireColor = "|cff40ff40",
        rejectPlain = "[Guild]",
    },
    {
        name = "possessive reputation loss",
        event = "CHAT_MSG_COMBAT_FACTION_CHANGE",
        message = "Your Bloodsail Buccaneers reputation has decreased by 125.",
        expectPlain = "\226\136\146 125 Reputation: Bloodsail Buccaneers",
    },
    {
        name = "nameless level up stays unchanged",
        event = "CHAT_MSG_SYSTEM",
        message = "has reached level 13.",
        expectPlain = "has reached level 13.",
    },
    {
        name = "guild join",
        event = "CHAT_MSG_SYSTEM",
        message = "Uzaemon has joined the guild.",
        expectPlain = "Uzaemon joined the guild",
    },
    {
        name = "guild leave",
        event = "CHAT_MSG_SYSTEM",
        message = "Uzaemon has left the guild.",
        expectPlain = "Uzaemon left the guild",
    },
    {
        name = "friend online notice",
        event = "CHAT_MSG_SYSTEM",
        message = "Dreadwarden has come online.",
        expectPlain = "Dreadwarden came online",
        requireColor = "|cffffd200Dreadwarden came online|r",
    },
    {
        name = "friend offline notice",
        event = "CHAT_MSG_SYSTEM",
        message = "Dreadwarden has gone offline.",
        expectPlain = "Dreadwarden went offline",
        requireColor = "|cffffd200Dreadwarden went offline|r",
    },
    {
        name = "guild online notice",
        event = "CHAT_MSG_SYSTEM",
        message = "Wightwalker has come online.",
        expectPlain = "Wightwalker came online",
        requireColor = "|cff40ff40Wightwalker came online|r",
    },
    {
        name = "guild offline notice",
        event = "CHAT_MSG_SYSTEM",
        message = "Wightwalker has gone offline.",
        expectPlain = "Wightwalker went offline",
        requireColor = "|cff40ff40Wightwalker went offline|r",
    },
    {
        name = "loot method keeps display casing",
        event = "CHAT_MSG_SYSTEM",
        groupMembers = 2,
        message = "Looting changed to free-for-all.",
        expectPlain = "Loot: Free for all",
        requireColors = { "|cffffffffLoot: |r", "|cffaaaaffFree for all|r" },
    },
    {
        name = "quest accepted",
        event = "CHAT_MSG_SYSTEM",
        message = "Quest accepted: The Missing Diplomat",
        expectPlain = "+ Accepted: The Missing Diplomat",
    },
    {
        name = "quest completed keeps explicit title",
        event = "CHAT_MSG_SYSTEM",
        message = "Quest Completed: The Missing Diplomat",
        expectPlain = "+ Completed: The Missing Diplomat",
    },
    {
        name = "generic quest completion hides placeholder title",
        event = "CHAT_MSG_SYSTEM",
        message = "You have completed that quest.",
        expectPlain = "+ Completed",
        rejectPlain = "that quest",
    },
    {
        name = "quest share of a completed quest stays as written",
        event = "CHAT_MSG_SYSTEM",
        message = "Daddy Zugzug's attempt to share quest \"Amongst the Ruins\" failed. You have completed that quest.",
        expectPlain = "Daddy Zugzug's attempt to share quest \"Amongst the Ruins\" failed. You have completed that quest.",
    },
    {
        name = "completed daily quest stays as written",
        event = "CHAT_MSG_SYSTEM",
        message = "You have completed that daily quest today.",
        expectPlain = "You have completed that daily quest today.",
    },
    {
        name = "missing required quest stays as written",
        event = "CHAT_MSG_SYSTEM",
        message = "You have not completed the required quest.",
        expectPlain = "You have not completed the required quest.",
    },
    {
        name = "retail completed transmog set drops the set",
        event = "CHAT_MSG_SYSTEM",
        isMainline = true,
        message = "You've completed the set |cffff80ff|Htransmogset:4321|h[Head Chef's Uniform (Black)]|h|r.",
        expectPlain = "+ Completed: Head Chef's Uniform (Black)",
        rejectPlain = "the set",
        requireColors = { "|cffffffffCompleted: |r", "|cffff80ff|Htransmogset:4321|hHead Chef's Uniform (Black)|h|r" },
    },
    {
        name = "plain completed transmog set drops the set",
        event = "CHAT_MSG_SYSTEM",
        message = "You've completed the set Head Chef's Uniform (Black).",
        expectPlain = "+ Completed: Head Chef's Uniform (Black)",
        rejectPlain = "the set",
        requireColor = "|cffff80ffHead Chef's Uniform (Black)|r",
    },
    {
        name = "ready check initiated strips realm",
        event = "CHAT_MSG_SYSTEM",
        message = "Mirella-Grobbulus has initiated a ready check.",
        expectPlain = "Mirella initiated ready check",
    },
    {
        name = "not ready strips realm",
        event = "CHAT_MSG_SYSTEM",
        message = "Mirella-Grobbulus is not ready.",
        expectPlain = "Mirella not ready",
    },
    {
        name = "trade request strips realm",
        event = "CHAT_MSG_SYSTEM",
        message = "You have requested to trade with Mirella-Grobbulus.",
        expectPlain = "Requested to trade with Mirella",
    },
    {
        name = "retail money gain post-process hidden",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "You gained: 1 Gold 23 Silver 45 Copper.",
        expectHidden = true,
    },
    {
        name = "money loot uses the client's coin icon",
        event = "CHAT_MSG_MONEY",
        message = "You loot 5 Copper",
        expectPlain = "+ 5",
        requireColors = { "5|r|A:coin-copper:10:10:2:0|a" },
    },
    {
        name = "money loot shows every coin",
        event = "CHAT_MSG_MONEY",
        message = "You loot 1 Gold, 23 Silver, 45 Copper",
        expectPlain = "+ 1 23 45",
        requireColors = { "1|r|A:coin-gold:10:10:2:0|a ", "23|r|A:coin-silver:10:10:2:0|a ", "45|r|A:coin-copper:10:10:2:0|a" },
    },
    {
        name = "money line survives the post-processor",
        path = "post",
        event = "CHAT_MSG_MONEY",
        message = "+ 5|A:coin-copper:10:10:2:0|a",
        expectPlain = "+ 5",
        requireColors = { "5|A:coin-copper:10:10:2:0|a" },
    },
    {
        name = "money loss uses the minus sign",
        event = "CHAT_MSG_MONEY",
        message = "You paid 5 Copper",
        expectPlain = "\226\136\146 5",
    },
    {
        name = "repair cost uses the minus sign",
        event = "CHAT_MSG_MONEY",
        message = "You paid 7 Copper to repair your items",
        expectPlain = "\226\136\146 7",
    },
    {
        name = "auctionator hidden",
        event = "CHAT_MSG_SYSTEM",
        message = "Auctionator: scan complete",
        expectHidden = true,
    },
    {
        name = "notify system notice hidden",
        event = "CHAT_MSG_SYSTEM",
        message = "Notify system has been enabled.",
        expectHidden = true,
    },
    {
        name = "left the queue uses the minus sign",
        event = "CHAT_MSG_SYSTEM",
        message = "You are no longer queued.",
        expectPlain = "\226\136\146 Left the queue",
    },
    {
        name = "battle countdown: Warsong Gulch",
        event = "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        message = "The battle for Warsong Gulch begins in 1 minute.",
        expectPlain = "Warsong Gulch begins in 1 minute",
        requireColor = "|cff80b0ffWarsong Gulch|r",
    },
    {
        name = "battle countdown: the last seconds drop the war cry",
        event = "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        message = "The battle for Warsong Gulch begins in 30 seconds.  Prepare yourselves!",
        expectPlain = "Warsong Gulch begins in 30 seconds",
    },
    {
        name = "battle countdown: Arathi Basin's wording",
        event = "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        message = "The Battle for Arathi Basin will begin in 1 minute.",
        expectPlain = "Arathi Basin begins in 1 minute",
    },
    {
        name = "battle countdown: Alterac Valley's wording",
        event = "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        message = "2 minutes until the battle for Alterac Valley begins.",
        expectPlain = "Alterac Valley begins in 2 minutes",
    },
    {
        name = "battle start: Warsong Gulch",
        event = "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        message = "Let the battle for Warsong Gulch begin!",
        expectPlain = "Warsong Gulch has begun",
    },
    {
        name = "battle start: Arathi Basin",
        event = "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        message = "The Battle for Arathi Basin has begun!",
        expectPlain = "Arathi Basin has begun",
    },
    {
        name = "battle start: only the announcer is restyled",
        event = "CHAT_MSG_SAY",
        message = "Let the battle for Warsong Gulch begin!",
        expectPlain = "Let the battle for Warsong Gulch begin!",
    },
    {
        name = "generic reward: Forever's rank points arrive as a reputation line",
        event = "CHAT_MSG_COMBAT_FACTION_CHANGE",
        message = "You gain 100 Rank Points.",
        expectPlain = "+ 100 Rank Points",
    },
    {
        name = "experience lines keep their own styling",
        event = "CHAT_MSG_COMBAT_XP_GAIN",
        message = "You gain 250 experience.",
        expectPlain = "+ 250 EXP",
    },
    {
        name = "generic reward: arena points",
        event = "CHAT_MSG_COMBAT_HONOR_GAIN",
        message = "You have been awarded 5 arena points.",
        expectPlain = "+ 5 arena points",
        requireColor = "|cff00ccff",
    },
    {
        name = "generic reward: a server's own reward line",
        event = "CHAT_MSG_SYSTEM",
        message = "You have received 5 Bonus Tokens.",
        expectPlain = "+ 5 Bonus Tokens",
    },
    {
        name = "generic reward: a name with honor in it is not honor points",
        event = "CHAT_MSG_SYSTEM",
        message = "You have received 5 Honor Hold Favors.",
        expectPlain = "+ 5 Honor Hold Favors",
    },
    {
        name = "generic reward: players saying it stays chat",
        event = "CHAT_MSG_SAY",
        message = "You receive 5 tokens",
        expectPlain = "You receive 5 tokens",
    },
    {
        name = "generic reward: party chat stays chat",
        event = "CHAT_MSG_PARTY",
        message = "You have been awarded 5 tokens",
        expectPlain = "You have been awarded 5 tokens",
    },
    {
        name = "generic reward: whispers stay chat",
        event = "CHAT_MSG_WHISPER",
        message = "You gain 5 levels",
        expectPlain = "You gain 5 levels",
    },
    {
        name = "generic reward: only from the start of the line",
        event = "CHAT_MSG_SYSTEM",
        message = "Koji says You receive 5 tokens",
        expectPlain = "Koji says You receive 5 tokens",
    },
    {
        name = "generic reward: a number and earned somewhere in a line is no reward",
        event = "CHAT_MSG_SYSTEM",
        message = "At least 3 out of 5 players in your group are members of Foo. Guild achievements can be earned.",
        expectPlain = "At least 3 out of 5 players in your group are members of Foo. Guild achievements can be earned.",
    },
}

local failures = {}
local additionalChecks = 0

for _, fixture in ipairs(fixtures) do
    local hidden, out
    groupMembers = fixture.groupMembers or 0
    inRaid = fixture.inRaid or false
    inCombatLockdown = fixture.inCombatLockdown == true
    Carpenter.Client.isMainline = fixture.isMainline == true
    if fixture.path == "post" then
        local frame = {}
        local captured = nil
        local function originalAddMessage(_, message)
            captured = message
        end
        postProcessor.ProcessMessage(frame, originalAddMessage, fixture.message, {})
        hidden = captured == nil
        out = captured
    else
        hidden, out = filter(nil, fixture.event, fixture.message, fixture.author or "")
    end
    local outPlain = plain(out)

    if fixture.expectHidden then
        if hidden ~= true then
            failures[#failures + 1] = fixture.name .. ": expected hidden"
        end
    elseif hidden == true then
        failures[#failures + 1] = fixture.name .. ": unexpectedly hidden"
    elseif outPlain ~= fixture.expectPlain then
        failures[#failures + 1] = fixture.name .. ": expected [" .. fixture.expectPlain .. "] got [" .. tostring(outPlain) .. "]"
    elseif fixture.rejectPlain and outPlain and outPlain:find(fixture.rejectPlain, 1, true) then
        failures[#failures + 1] = fixture.name .. ": output used rejected text " .. fixture.rejectPlain
    elseif fixture.requireColor and (not out or not out:find(fixture.requireColor, 1, true)) then
        failures[#failures + 1] = fixture.name .. ": output did not include required color " .. fixture.requireColor
    elseif fixture.requireColors then
        for _, requiredColor in ipairs(fixture.requireColors) do
            if not out or not out:find(requiredColor, 1, true) then
                failures[#failures + 1] = fixture.name .. ": output did not include required color " .. requiredColor
                break
            end
        end
    elseif fixture.rejectColor and out and out:find(fixture.rejectColor, 1, true) then
        failures[#failures + 1] = fixture.name .. ": output used rejected color " .. fixture.rejectColor
    end
end
inCombatLockdown = false
Carpenter.Client.isMainline = false

-- A profession rank teaches two spells with one name, and the game announces
-- both: the second line is dropped, per chat frame and only for a moment.
do
    local frameA, frameB = {}, {}
    local first = "You have learned a new spell: |cff71d5ff|Hspell:7731|h[Fishing]|h|r."
    local second = "You have learned a new spell: |cff71d5ff|Hspell:7733|h[Fishing]|h|r."
    local function Learn(frame, message)
        local hidden, out = filter(frame, "CHAT_MSG_SYSTEM", message, "")
        additionalChecks = additionalChecks + 1
        return hidden, plain(out)
    end
    local function expectShown(label, hidden, out, expected)
        if hidden == true or out ~= expected then
            failures[#failures + 1] = "learned twice: " .. label .. ", got hidden=" .. tostring(hidden) .. " [" .. tostring(out) .. "]"
        end
    end

    now = now + 100
    local hidden, out = Learn(frameA, first)
    expectShown("the first line should show", hidden, out, "+ Learned: [Fishing]")
    -- The same message reaches every chat frame showing system messages.
    hidden, out = Learn(frameB, first)
    expectShown("another chat frame should show its own copy", hidden, out, "+ Learned: [Fishing]")
    hidden = Learn(frameA, second)
    if hidden ~= true then
        failures[#failures + 1] = "learned twice: the same name again should be dropped"
    end
    hidden, out = Learn(frameA, "You have learned a new spell: |cff71d5ff|Hspell:45694|h[Fish Bowl]|h|r.")
    expectShown("a different name should show", hidden, out, "+ Learned: [Fish Bowl]")
    now = now + 10
    hidden, out = Learn(frameA, first)
    expectShown("the same name later should show again", hidden, out, "+ Learned: [Fishing]")

    -- The ranked line shows and the bare name that follows it is dropped.
    now = now + 100
    hidden, out = Learn(frameA, "You have learned a new spell: |cff71d5ff|Hspell:3102|h[Cooking (Journeyman)]|h|r.")
    expectShown("the ranked line should show", hidden, out, "+ Learned: [Cooking (Journeyman)]")
    hidden = Learn(frameA, "You have learned a new spell: |cff71d5ff|Hspell:3413|h[Cooking]|h|r.")
    if hidden ~= true then
        failures[#failures + 1] = "learned twice: the bare name after its ranked line should be dropped"
    end

    -- Two ranks of one spell are separate lessons.
    now = now + 100
    hidden, out = Learn(frameA, "You have learned a new spell: |cff71d5ff|Hspell:1757|h[Sinister Strike (Rank 2)]|h|r.")
    expectShown("rank 2 should show", hidden, out, "+ Learned: [Sinister Strike (Rank 2)]")
    hidden, out = Learn(frameA, "You have learned a new spell: |cff71d5ff|Hspell:1758|h[Sinister Strike (Rank 3)]|h|r.")
    expectShown("rank 3 right after rank 2 should show", hidden, out, "+ Learned: [Sinister Strike (Rank 3)]")
    now = now + 100
end

do
    local emoteSenders = {
        { "You bow before Toxic Masculnity.", "T", "" },
        { "You bow before Holy Capone.", "T", "T" },
        { "Merrek Grimaldus salutes you with respect.", "Merrek Grimaldus", "Merrek Grimaldus" },
        { "Merrek salutes you with respect.", "Merrek", "Merrek" },
        { "Ann waves at Anneliese.", "Ann", "Ann" },
        { "Anneliese waves at you.", "Ann", "" },
    }
    for _, case in ipairs(emoteSenders) do
        local hidden, out, author = filter(nil, "CHAT_MSG_TEXT_EMOTE", case[1], case[2])
        if hidden == true or out ~= case[1] then
            failures[#failures + 1] = "text emote must pass through unchanged: " .. case[1]
        elseif author ~= case[3] then
            failures[#failures + 1] = "text emote sender for [" .. case[1] .. "] expected [" .. case[3] .. "] got [" .. tostring(author) .. "]"
        end
    end
end

do
    local keys = {
        "LOOT_ITEM",
        "LOOT_ITEM_MULTIPLE",
        "LOOT_ITEM_PUSHED",
        "LOOT_ITEM_PUSHED_MULTIPLE",
        "LOOT_ITEM_SELF",
        "LOOT_ITEM_SELF_MULTIPLE",
        "LOOT_ITEM_PUSHED_SELF",
        "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
        "LOOT_ITEM_CREATED_SELF",
        "LOOT_ITEM_CREATED_SELF_MULTIPLE",
        "CREATED_ITEM",
        "CREATED_ITEM_MULTIPLE",
    }
    local saved = {}
    for _, key in ipairs(keys) do
        saved[key] = _G[key]
        _G[key] = nil
    end

    LOOT_ITEM = "Beute: %2$s fuer %1$s."
    LOOT_ITEM_MULTIPLE = "Beute: %2$sx%3$d fuer %1$s."
    LOOT_ITEM_SELF = "Erhalten: %s."
    LOOT_ITEM_SELF_MULTIPLE = "Erhalten: %sx%d."

    local utils = ns.Private.ChatCleanerUtils
    local loot = ns.Private.ChatCleanerLoot
    local countColor = "|cffc8c8c8"
    local localizedFormatter = loot.Create({
        CleanPunctuation = utils.CleanPunctuation,
        StripBrackets = utils.StripBrackets,
        SpaceBeforeX = utils.SpaceBeforeX,
        GetItemLinkFromMessage = utils.GetItemLinkFromMessage,
        GetItemLinkWithQualityColor = utils.GetItemLinkWithQualityColor,
        FormatItemCountSuffix = function(text) return utils.FormatItemCountSuffix(text, countColor) end,
        FormatReceivedDisplay = function(rawDisplay, sourceMessage)
            return utils.FormatReceivedDisplay(rawDisplay, sourceMessage, { CountColor = countColor })
        end,
        ShouldSkipGenericReceive = utils.ShouldSkipGenericReceive,
        SelfLootPatterns = loot.BuildSelfLootPatterns(),
        GroupLootPatterns = loot.BuildGroupLootPatterns(),
        RollPatterns = {},
        RollPatternsFallback = {},
        ColorPlus = countColor,
        ColorLootLiteral = "|cffffffff",
        ColorGreen = "|cff00ff00",
        GetChannelMessageColor = function() return "|cffffffff" end,
    })

    local groupOut = localizedFormatter.FormatGroupLootMessage("CHAT_MSG_LOOT", "Beute: Seidenstoff fuer Malagas.", "")
    additionalChecks = additionalChecks + 1
    if plain(groupOut) ~= "Malagas + Seidenstoff" then
        failures[#failures + 1] = "localized group loot format: expected [Malagas + Seidenstoff] got [" .. tostring(plain(groupOut)) .. "]"
    end

    local groupStackOut = localizedFormatter.FormatGroupLootMessage("CHAT_MSG_LOOT", "Beute: Seidenstoffx3 fuer Malagas.", "")
    additionalChecks = additionalChecks + 1
    if plain(groupStackOut) ~= "Malagas + Seidenstoff (3)" then
        failures[#failures + 1] = "localized group loot stack format: expected [Malagas + Seidenstoff (3)] got [" .. tostring(plain(groupStackOut)) .. "]"
    end

    local selfOut = localizedFormatter.FormatSelfLootMessage("CHAT_MSG_LOOT", "Erhalten: Malachitx3.", countColor .. "+|r ")
    additionalChecks = additionalChecks + 1
    if plain(selfOut) ~= "+ Malachit (3)" then
        failures[#failures + 1] = "localized self loot stack format: expected [+ Malachit (3)] got [" .. tostring(plain(selfOut)) .. "]"
    end

    for _, key in ipairs(keys) do
        _G[key] = saved[key]
    end
end

-- Roll results on other clients take their type from Blizzard's global, not
-- from English words in the message.
do
    local keys = { "LOOT_ROLL_NEED", "LOOT_ROLL_GREED", "LOOT_ROLL_DISENCHANT", "LOOT_ROLL_WON" }
    local saved = {}
    for _, key in ipairs(keys) do saved[key] = _G[key] end

    LOOT_ROLL_NEED = "%s hat 'Bedarf' für: %s ausgewählt"
    LOOT_ROLL_GREED = "%s hat 'Gier' für: %s ausgewählt"
    LOOT_ROLL_DISENCHANT = "%s hat 'Entzauberung' für: %s ausgewählt"
    LOOT_ROLL_WON = "%s gewinnt: %s"

    local utils = ns.Private.ChatCleanerUtils
    local loot = ns.Private.ChatCleanerLoot
    local localizedFormatter = loot.Create({
        CleanPunctuation = utils.CleanPunctuation,
        StripBrackets = utils.StripBrackets,
        SpaceBeforeX = utils.SpaceBeforeX,
        GetItemLinkFromMessage = utils.GetItemLinkFromMessage,
        GetItemLinkWithQualityColor = utils.GetItemLinkWithQualityColor,
        RollPatterns = loot.BuildRollPatterns(),
        RollPatternsFallback = {},
        ColorLootLiteral = "|cffffffff",
    })

    local cases = {
        { "Malagas hat 'Bedarf' für: [Seidenstoff] ausgewählt", "Malagas Need Seidenstoff" },
        { "Malagas hat 'Entzauberung' für: [Seidenstoff] ausgewählt", "Malagas Disenchant Seidenstoff" },
        { "Malagas gewinnt: [Seidenstoff]", "Malagas won Seidenstoff" },
    }
    for _, case in ipairs(cases) do
        local out = localizedFormatter.FormatLootRollMessage("CHAT_MSG_LOOT", case[1])
        additionalChecks = additionalChecks + 1
        if plain(out) ~= case[2] then
            failures[#failures + 1] = "localized roll: expected [" .. case[2] .. "] got [" .. tostring(plain(out)) .. "]"
        end
    end

    for _, key in ipairs(keys) do _G[key] = saved[key] end
end

do
    local hookCalls = 0
    local restoreCalls = 0
    _G.ChatFrame1._fixtureHooked = nil

    local lifecycle = ns.Private.ChatCleanerLifecycle.Create({
        FilterImpl = function() return false, "", "" end,
        HookChatFrameAddMessage = function(frame)
            if frame ~= _G.ChatFrame1 or frame._fixtureHooked then return end
            frame._fixtureHooked = true
            hookCalls = hookCalls + 1
        end,
        RestoreChatFrameAddMessage = function(frame)
            if frame ~= _G.ChatFrame1 then return end
            frame._fixtureHooked = false
            restoreCalls = restoreCalls + 1
        end,
    })

    inCombatLockdown = true
    lifecycle.Enable()
    additionalChecks = additionalChecks + 1
    if hookCalls ~= 1 then
        failures[#failures + 1] = "chat cleaner lifecycle: expected post-process hook while in combat"
    end

    lifecycle.Disable()
    inCombatLockdown = false
    additionalChecks = additionalChecks + 1
    if restoreCalls ~= 1 then
        failures[#failures + 1] = "chat cleaner lifecycle: expected post-process restore on disable"
    end
end

do
    local originalChatFrame = _G.ChatFrame1
    local captured = {}
    local frame = {
        AddMessage = function(_, message)
            captured[#captured + 1] = message
        end,
    }
    _G.ChatFrame1 = frame

    local lifecycle = ns.Private.ChatCleanerLifecycle.Create({
        FilterImpl = function() return false, "", "" end,
        HookChatFrameAddMessage = postProcessor.HookChatFrameAddMessage,
        RestoreChatFrameAddMessage = postProcessor.RestoreChatFrameAddMessage,
    })

    inCombatLockdown = true
    lifecycle.Enable()
    frame:AddMessage("|cff40ff40[Guild] Tester: still cleaning|r")
    frame:AddMessage("Lionginas died of fatigue in The Merchant Coast! They were level 32")
    lifecycle.Disable()
    inCombatLockdown = false
    _G.ChatFrame1 = originalChatFrame

    additionalChecks = additionalChecks + 1
    if plain(captured[1]) ~= "[G] Tester: still cleaning" then
        failures[#failures + 1] = "chat cleaner lifecycle combat guild: expected compact guild prefix got [" .. tostring(plain(captured[1])) .. "]"
    end

    additionalChecks = additionalChecks + 1
    if plain(captured[2]) ~= "Lionginas died from fatigue! Level 32" then
        failures[#failures + 1] = "chat cleaner lifecycle combat death: expected formatted death got [" .. tostring(plain(captured[2])) .. "]"
    end
end

do
    local calls = 0
    local original = function() calls = calls + 1 end
    local frame = { AddMessage = original }

    postProcessor.HookChatFrameAddMessage(frame)
    additionalChecks = additionalChecks + 1
    if frame.AddMessage == original or frame._CP_AddMessageHooked ~= true then
        failures[#failures + 1] = "post-process hook restore: expected hook to install"
    end

    postProcessor.RestoreChatFrameAddMessage(frame)
    additionalChecks = additionalChecks + 1
    if frame.AddMessage ~= original or frame._CP_AddMessageHooked ~= false then
        failures[#failures + 1] = "post-process hook restore: expected original AddMessage to be restored"
    end

    postProcessor.HookChatFrameAddMessage(frame)
    postProcessor.RestoreChatFrameAddMessage(frame)
    additionalChecks = additionalChecks + 1
    if frame.AddMessage ~= original or calls ~= 0 then
        failures[#failures + 1] = "post-process hook restore: expected rehook to keep original AddMessage"
    end
end

do
    local printed = {}
    local originalPrint = print
    print = function(message)
        printed[#printed + 1] = tostring(message)
    end

    local session = ns.Private.ChatCleanerSessions.Create({
        FormatMoney = function(amount) return tostring(amount or 0) end,
        ColorPlus = "|cffffffff",
        ColorMinus = "|cffffffff",
    })
    local onMerchantEvent = session.merchantFrame._scripts.OnEvent
    if type(onMerchantEvent) == "function" then
        currentMoney = 10000
        onMerchantEvent(session.merchantFrame, "MERCHANT_SHOW")
        currentMoney = 12500
        onMerchantEvent(session.merchantFrame, "PLAYER_ENTERING_WORLD")
        onMerchantEvent(session.merchantFrame, "MERCHANT_CLOSED")
    else
        failures[#failures + 1] = "merchant zoning guard: merchant session event handler was not registered"
    end

    print = originalPrint

    additionalChecks = additionalChecks + 1
    if type(onMerchantEvent) == "function" and #printed ~= 0 then
        failures[#failures + 1] = "merchant zoning guard: expected no summary got " .. tostring(#printed)
    end
end

do
    local printed = {}
    local originalPrint = print
    print = function(message)
        printed[#printed + 1] = tostring(message)
    end

    local session = ns.Private.ChatCleanerSessions.Create({
        FormatMoney = function(amount) return tostring(amount or 0) end,
        ColorPlus = "|cffffffff",
        ColorMinus = "|cffffffff",
    })
    local onMerchantEvent = session.merchantFrame._scripts.OnEvent
    if type(onMerchantEvent) == "function" then
        currentMoney = 10000
        onMerchantEvent(session.merchantFrame, "MERCHANT_SHOW")
        currentMoney = 12500
        onMerchantEvent(session.merchantFrame, "MERCHANT_CLOSED")
        onMerchantEvent(session.merchantFrame, "MERCHANT_CLOSED")
    else
        failures[#failures + 1] = "merchant double close: merchant session event handler was not registered"
    end

    print = originalPrint

    additionalChecks = additionalChecks + 1
    if type(onMerchantEvent) == "function" and #printed ~= 1 then
        failures[#failures + 1] = "merchant double close: expected 1 summary got " .. tostring(#printed)
    elseif type(onMerchantEvent) == "function" and plain(printed[1]) ~= "+ 2500" then
        failures[#failures + 1] = "merchant double close: expected [+ 2500] got [" .. tostring(plain(printed[1])) .. "]"
    end
end

do
    -- Turning Chat Cleaner off restores everything it changed.
    local originalEditBox = _G.ChatFrame1EditBox
    local region = {
        texture = "Interface\\ChatFrame\\UI-ChatInputBorder-Left",
        alpha = 0.8,
        coords = { 0, 1, 0, 1, 0.25, 1, 0.25, 0 },
    }
    function region:IsObjectType(objectType) return objectType == "Texture" end
    function region:GetTexture() return self.texture end
    function region:SetTexture(texture) self.texture = texture end
    function region:GetAlpha() return self.alpha end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:GetTexCoord() return unpack(self.coords) end
    function region:SetTexCoord(...) self.coords = { ... } end
    _G.ChatFrame1EditBox = { GetRegions = function() return region end }

    local blizzardLevelUp = "Congratulations, you have reached level %d!"
    _G.LEVEL_UP = blizzardLevelUp
    _G.CHAT_FLAG_AFK = "<Away>"
    _G.CHAT_FLAG_DND = "<Busy>"

    local system = ns.Private.ChatCleanerSystem.Create({})
    local lifecycle = ns.Private.ChatCleanerLifecycle.Create({
        FilterImpl = function() return false, "", "" end,
        ApplyLevelUpGlobalStringStyling = system.ApplyLevelUpGlobalStringStyling,
        RestoreLevelUpGlobalStringStyling = system.RestoreLevelUpGlobalStringStyling,
    })

    additionalChecks = additionalChecks + 1
    if _G.CHAT_FLAG_AFK ~= "<Away>" then
        failures[#failures + 1] = "chat cleaner revert: AFK flag changed before the feature was enabled"
    end

    lifecycle.Enable()
    additionalChecks = additionalChecks + 1
    if region.texture ~= nil or region.alpha ~= 0 or _G.LEVEL_UP == blizzardLevelUp or _G.CHAT_FLAG_AFK ~= "AFK " then
        failures[#failures + 1] = "chat cleaner revert: expected enable to restyle edit box, level up and flags"
    end

    region.coords = { 0, 0, 0, 0, 0, 0, 0, 0 }
    lifecycle.Disable()
    additionalChecks = additionalChecks + 1
    if region.texture ~= "Interface\\ChatFrame\\UI-ChatInputBorder-Left" or region.alpha ~= 0.8 or region.coords[5] ~= 0.25 then
        failures[#failures + 1] = "chat cleaner revert: expected edit box texture, alpha and coords restored"
    end
    additionalChecks = additionalChecks + 1
    if _G.LEVEL_UP ~= blizzardLevelUp then
        failures[#failures + 1] = "chat cleaner revert: expected LEVEL_UP restored got [" .. tostring(_G.LEVEL_UP) .. "]"
    end
    additionalChecks = additionalChecks + 1
    if _G.CHAT_FLAG_AFK ~= "<Away>" or _G.CHAT_FLAG_DND ~= "<Busy>" then
        failures[#failures + 1] = "chat cleaner revert: expected AFK/DND flags restored"
    end

    _G.ChatFrame1EditBox = originalEditBox
end

do
    -- Show Input Box Texture keeps the edit box as Blizzard drew it, and
    -- switching it while Chat Cleaner is on applies right away.
    local originalEditBox = _G.ChatFrame1EditBox
    local blizzardTexture = "Interface\\ChatFrame\\UI-ChatInputBorder-Left"
    local region = { texture = blizzardTexture, alpha = 1, coords = { 0, 1, 0, 1, 0, 1, 0, 1 } }
    function region:IsObjectType(objectType) return objectType == "Texture" end
    function region:GetTexture() return self.texture end
    function region:SetTexture(texture) self.texture = texture end
    function region:GetAlpha() return self.alpha end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:GetTexCoord() return unpack(self.coords) end
    function region:SetTexCoord(...) self.coords = { ... } end
    _G.ChatFrame1EditBox = { GetRegions = function() return region end }

    CarpenterDB = { chatEditBoxTextureEnabled = true }
    local lifecycle = ns.Private.ChatCleanerLifecycle.Create({
        FilterImpl = function() return false, "", "" end,
    })

    lifecycle.ApplyEditBox()
    additionalChecks = additionalChecks + 1
    if region.texture ~= blizzardTexture or region.alpha ~= 1 then
        failures[#failures + 1] = "edit box texture: switching the option before Chat Cleaner is on should change nothing"
    end

    lifecycle.Enable()
    additionalChecks = additionalChecks + 1
    if region.texture ~= blizzardTexture or region.alpha ~= 1 then
        failures[#failures + 1] = "edit box texture: expected the texture kept when the option is on"
    end

    CarpenterDB.chatEditBoxTextureEnabled = false
    lifecycle.ApplyEditBox()
    additionalChecks = additionalChecks + 1
    if region.texture ~= nil or region.alpha ~= 0 then
        failures[#failures + 1] = "edit box texture: expected the texture hidden once the option is off"
    end

    CarpenterDB.chatEditBoxTextureEnabled = true
    lifecycle.ApplyEditBox()
    additionalChecks = additionalChecks + 1
    if region.texture ~= blizzardTexture or region.alpha ~= 1 then
        failures[#failures + 1] = "edit box texture: expected the texture back once the option is on again"
    end

    lifecycle.Disable()
    CarpenterDB = nil
    _G.ChatFrame1EditBox = originalEditBox
end

-- A chat window's history as ScrollingMessageFrame keeps it: entries with the
-- message, color, chat type id and time, rewritten in place by
-- TransformMessages.
local function NewHistoryChatFrame()
    local frame = { _CP_AddMessagePostHooked = true, _CP_AddMessageHooked = true, historyBuffer = { elements = {} } }
    function frame:Add(message, typeID)
        local entry = { message = message, r = 1, g = 1, b = 0, extraData = { typeID or 1, n = 1 }, timestamp = now }
        table.insert(self.historyBuffer.elements, entry)
        return entry
    end
    function frame:Text(entry)
        for _, current in ipairs(self.historyBuffer.elements) do
            if current == entry then return current.message end
        end
        -- A rewritten line is a new entry in the same place.
        for index, current in ipairs(self.historyBuffer.elements) do
            if current.replaced == entry then return current.message end
        end
    end
    function frame:TransformMessages(predicate, transform)
        for index, entry in ipairs(self.historyBuffer.elements) do
            local extra = entry.extraData
            if predicate(entry.message, entry.r, entry.g, entry.b, unpack(extra, 1, extra.n)) then
                local message, r, g, b, typeID = transform(entry.message, entry.r, entry.g, entry.b, unpack(extra, 1, extra.n))
                self.historyBuffer.elements[index] = {
                    message = message, r = r, g = g, b = b, extraData = { typeID, n = 1 },
                    timestamp = now, replaced = entry,
                }
            end
        end
    end
    return frame
end

-- Group lines hidden during chat lockdown never reach addon filters on
-- Forever; they are found in the chat history and rewritten from the roster,
-- deaths, and battleground timing. Times follow two real battleground logs.
do
    local HIDDEN = {}
    issecretvalue = function(value) return value == HIDDEN end
    local inLockdown = true
    C_ChatInfo = { InChatMessagingLockdown = function() return inLockdown end }
    Carpenter.Client.isForever = true
    local realSystemInfo = ChatTypeInfo.SYSTEM
    ChatTypeInfo.SYSTEM = { r = 1, g = 1, b = 0, id = 1 }

    local frame1, frame2 = NewHistoryChatFrame(), NewHistoryChatFrame()
    local realChatFrame1, realChatFrame2, realWindows = ChatFrame1, ChatFrame2, NUM_CHAT_WINDOWS
    ChatFrame1, ChatFrame2, NUM_CHAT_WINDOWS = frame1, frame2, 2

    -- A hidden system line reaches both windows, which show system messages.
    local function Hidden()
        return { frame1:Add(HIDDEN), frame2:Add(HIDDEN) }
    end
    local function Shown(line, frame)
        local text = (frame or frame1):Text(line[frame == frame2 and 2 or 1])
        if text == HIDDEN then return "<hidden>" end
        return plain(text)
    end
    local function Expect(line, expected, label)
        additionalChecks = additionalChecks + 1
        local got = Shown(line)
        if got ~= expected then
            failures[#failures + 1] = "hidden lines: " .. label .. ": expected [" .. expected .. "] got [" .. tostring(got) .. "]"
        end
    end

    local members = {}
    local dead = {}
    local realUnitName = UnitName
    UnitName = function(unit)
        local member = members[unit]
        if member then return member[1], member[2] end
        return realUnitName(unit)
    end
    UnitIsUnit = function(a, b) return a == b or (a == "raid1" and b == "player") end
    UnitIsDeadOrGhost = function(unit) return dead[unit] == true end

    local feature = registeredChatFeatures[#registeredChatFeatures].feature
    feature.Enable()
    local social = ns.Private.ChatCleaner.SocialFormatter
    local hiddenLines = ns.Private.ChatCleaner.HiddenLines
    local eventFrame
    for _, created in ipairs(createdFrames) do
        if created._events.PLAYER_ENTERING_BATTLEGROUND and created._events.UNIT_HEALTH then
            eventFrame = created
        end
    end
    additionalChecks = additionalChecks + 1
    if not (hiddenLines and eventFrame) then
        failures[#failures + 1] = "hidden lines: the matcher and its events should be set up"
    else
        local function Fire(event, ...) eventFrame._scripts.OnEvent(eventFrame, event, ...) end
        local base = 5000
        local function At(seconds) now = base + seconds end

        -- Zoning in with a party: the first hidden line is "Notify system has
        -- been disabled".
        At(0)
        members.party1 = { "Fufel", "Shmerz" }
        inRaid, groupMembers = false, 2
        Fire("PLAYER_ENTERING_WORLD")
        Fire("PLAYER_ENTERING_BATTLEGROUND")
        local notifyOff = Hidden()
        -- The battleground raid replaces the party at once, with its own lines;
        -- that's no one joining.
        At(0.37)
        members.party1 = nil
        members.raid1, members.raid2, members.raid3, members.raid4 =
            { "Tester", "" }, { "Tahlya", "Dawnsorrow" }, { "Fufel", "Shmerz" }, { "Gorb", "Garnsson" }
        inRaid, groupMembers = true, 4
        local formed = Hidden()
        Fire("GROUP_ROSTER_UPDATE")
        hiddenLines.Update()
        Expect(notifyOff, "", "the notify line on zoning in is emptied")
        Expect(formed, "<hidden>", "lines that come with the raid forming stay")

        -- A join under a second later takes its own line, not the burst's
        -- (seen in game: the name landed on a burst line).
        At(1.28)
        local firstJoin = Hidden()
        members.raid5 = { "Damoz", "Lifesong" }
        groupMembers = 5
        Fire("GROUP_ROSTER_UPDATE")
        hiddenLines.Update()
        Expect(firstJoin, "Damoz Lifesong joined", "a join right after zoning in gets its own line")
        Expect(formed, "<hidden>", "a join right after zoning in leaves the burst alone")

        -- A join: the line comes a moment before the roster has the player.
        At(2.69)
        local joined = Hidden()
        hiddenLines.Update()
        Expect(joined, "<hidden>", "a line waits for its roster change")
        At(2.79)
        members.raid6 = { "Peti", "Lucko" }
        groupMembers = 6
        Fire("GROUP_ROSTER_UPDATE")
        hiddenLines.Update()
        Expect(joined, "Peti Lucko joined", "a join is named from the roster")
        additionalChecks = additionalChecks + 1
        if Shown(joined, frame2) ~= "Peti Lucko joined" then
            failures[#failures + 1] = "hidden lines: every window showing the line gets it rewritten"
        end

        -- Blizzard's batched repeat of the join, 30 s in.
        -- Blizzard's batches print to the main window only. With the call
        -- stack hidden, a batch line falls back to the timing rule.
        local realDebugstack = debugstack
        debugstack = function() return HIDDEN end
        At(30.01)
        local batch = { frame1:Add(HIDDEN) }
        hiddenLines.OnHiddenLineAdded(frame1)
        Expect(batch, "<hidden>", "a batch line with a hidden stack isn't emptied as it's added")
        hiddenLines.Update()
        Expect(batch, "<hidden>", "a batched line waits for a join to claim it")
        -- A join right after the batch line takes its own line, the nearest
        -- (seen in game: the name landed on the batch line).
        At(30.16)
        local batchJoin = Hidden()
        members.raid7 = { "Rathica", "Cryptmender" }
        groupMembers = 7
        Fire("GROUP_ROSTER_UPDATE")
        hiddenLines.Update()
        Expect(batchJoin, "Rathica Cryptmender joined", "a join beside a batch line gets its own line")
        At(30.7)
        hiddenLines.Update()
        Expect(batch, "", "a batched join line is emptied")

        -- A batch line from Blizzard's battleground chat filter is emptied as
        -- it's added, before the window redraws.
        debugstack = function()
            return "[string \"@Interface/AddOns/Blizzard_ChatFrame/Mainline/BattlegroundChatFilters.lua\"]:120: in function <...>"
        end
        At(35.02)
        local quickBatch = { frame1:Add(HIDDEN) }
        hiddenLines.OnHiddenLineAdded(frame1)
        Expect(quickBatch, "", "a batch line is emptied as it's added")
        debugstack = realDebugstack

        -- "Notify system has been enabled" follows the start by a few seconds,
        -- but only once no roster change claims it.
        At(112.70)
        Fire("CHAT_MSG_BG_SYSTEM_NEUTRAL", "Let the battle for Warsong Gulch begin!")
        At(115.34)
        local notifyOn = Hidden()
        hiddenLines.Update()
        Expect(notifyOn, "<hidden>", "the start notice waits a moment")
        At(116.0)
        hiddenLines.Update()
        Expect(notifyOn, "", "the notify line after the start is emptied")

        -- After the first minute a departure sends two lines: one says who.
        At(134.73)
        local left = Hidden()
        At(134.98)
        local leftAgain = Hidden()
        members.raid4, members.raid5, members.raid6, members.raid7 = members.raid5, members.raid6, members.raid7, nil
        groupMembers = 6
        Fire("GROUP_ROSTER_UPDATE")
        hiddenLines.Update()
        Expect(leftAgain, "Gorb Garnsson left", "a departure is named on the line nearest the change")
        Expect(left, "", "the other line of a departure is emptied")

        -- A death, by first name.
        At(150.0)
        dead.raid2 = true
        Fire("UNIT_HEALTH", "raid2")
        At(150.1)
        local died = Hidden()
        hiddenLines.Update()
        Expect(died, "Tahlya died", "a death is named")

        -- Two deaths and two lines at once: no telling which is which.
        At(170.0)
        dead.raid3, dead.raid4 = true, true
        Fire("UNIT_HEALTH", "raid3")
        Fire("UNIT_HEALTH", "raid4")
        At(170.05)
        local deathA, deathB = Hidden(), Hidden()
        hiddenLines.Update()
        Expect(deathA, "<hidden>", "two deaths at once leave the first line alone")
        Expect(deathB, "<hidden>", "two deaths at once leave the second line alone")

        -- A line with no known cause stays as the game wrote it.
        At(200)
        local unknown = Hidden()
        hiddenLines.Update()
        At(204)
        hiddenLines.Update()
        Expect(unknown, "<hidden>", "an unexplained line stays")

        -- Out of lockdown, nothing is touched.
        inLockdown = false
        At(220)
        local outside = Hidden()
        members.raid7 = { "Ward", "Ender" }
        groupMembers = 7
        Fire("GROUP_ROSTER_UPDATE")
        hiddenLines.Update()
        Expect(outside, "<hidden>", "nothing changes outside lockdown")
    end

    feature.Disable()
    inRaid, groupMembers = false, 0
    UnitName, UnitIsUnit, UnitIsDeadOrGhost = realUnitName, nil, nil
    ChatFrame1, ChatFrame2, NUM_CHAT_WINDOWS = realChatFrame1, realChatFrame2, realWindows
    ChatTypeInfo.SYSTEM = realSystemInfo
    C_ChatInfo = nil
    Carpenter.Client.isForever = nil
    issecretvalue = nil
end

-- WoW Forever hides skill-ups during chat lockdown too, and they never reach
-- addon filters either. Each is rewritten in the chat history from the skill
-- rank that rose within a moment of it.
do
    local HIDDEN = {}
    issecretvalue = function(value) return value == HIDDEN end
    local inLockdown = true
    C_ChatInfo = { InChatMessagingLockdown = function() return inLockdown end }
    local realSystemInfo, realSkillInfo = ChatTypeInfo.SYSTEM, ChatTypeInfo.SKILL
    local SKILL_ID = 2
    ChatTypeInfo.SYSTEM = { r = 1, g = 1, b = 0, id = 1 }
    ChatTypeInfo.SKILL = { r = 0.33, g = 0.33, b = 1, id = SKILL_ID }
    local skills = {
        { skillID = 162, name = "Unarmed", rank = 34 },
        { skillID = 95, name = "Defense", rank = 110 },
    }
    C_SkillInfo = {
        GetNumSkillLines = function() return #skills end,
        GetSkillLineInfo = function(index) return skills[index] end,
    }
    -- Timers wait here until a check runs them.
    local realTimer = C_Timer
    local timers = {}
    C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
    local function RunTimers()
        local due = timers
        timers = {}
        for _, callback in ipairs(due) do callback() end
    end

    local frame1, frame2 = NewHistoryChatFrame(), NewHistoryChatFrame()
    local realChatFrame1, realChatFrame2, realWindows = ChatFrame1, ChatFrame2, NUM_CHAT_WINDOWS
    ChatFrame1, ChatFrame2, NUM_CHAT_WINDOWS = frame1, frame2, 2

    local feature = registeredChatFeatures[#registeredChatFeatures].feature
    feature.Enable()
    local hiddenLines = ns.Private.ChatCleaner.HiddenLines
    local skillFrame
    for _, created in ipairs(createdFrames) do
        if created._events.SKILL_LINES_CHANGED and created._events.CHAT_MSG_SKILL then
            skillFrame = created
        end
    end
    additionalChecks = additionalChecks + 1
    if not (hiddenLines and skillFrame) then
        failures[#failures + 1] = "hidden skill-up: the matcher and its events should be set up"
    else
        local function Fire(event, ...) skillFrame._scripts.OnEvent(skillFrame, event, ...) end
        local function RanksChanged() Fire("SKILL_LINES_CHANGED") end
        -- The game adds the hidden line to both windows, then tells addons.
        local function SkillUp()
            local line = { frame1:Add(HIDDEN, SKILL_ID), frame2:Add(HIDDEN, SKILL_ID) }
            Fire("CHAT_MSG_SKILL", HIDDEN)
            return line
        end
        local function Shown(line, index)
            local frame = index == 2 and frame2 or frame1
            local text = frame:Text(line[index or 1])
            if text == HIDDEN then return "<hidden>" end
            return plain(text)
        end
        local function Expect(line, expected, label)
            for index = 1, 2 do
                additionalChecks = additionalChecks + 1
                local got = Shown(line, index)
                if got ~= expected then
                    failures[#failures + 1] = "hidden skill-up: " .. label .. " (window " .. index .. "): expected [" ..
                        expected .. "] got [" .. tostring(got) .. "]"
                end
            end
        end
        local base = 8000
        local function At(seconds) now = base + seconds end

        -- The rank goes up a moment before the line.
        At(0)
        skills[1].rank = 35
        RanksChanged()
        At(0.02)
        Expect(SkillUp(), "+ 35 Skill: Unarmed", "a rank reported just before the line styles it")

        -- The line comes first and waits for its rank.
        At(5)
        local early = SkillUp()
        Expect(early, "<hidden>", "a line waits for its rank")
        At(5.03)
        skills[2].rank = 111
        RanksChanged()
        Expect(early, "+ 111 Skill: Defense", "a rank reported just after the line styles it")

        -- Two skills rising together: each line takes one.
        At(10)
        skills[1].rank, skills[2].rank = 36, 112
        RanksChanged()
        local a, b = SkillUp(), SkillUp()
        for index = 1, 2 do
            local shownA, shownB = Shown(a, index), Shown(b, index)
            additionalChecks = additionalChecks + 1
            if not ((shownA == "+ 36 Skill: Unarmed" and shownB == "+ 112 Skill: Defense")
                or (shownA == "+ 112 Skill: Defense" and shownB == "+ 36 Skill: Unarmed")) then
                failures[#failures + 1] = "hidden skill-up: two at once (window " .. index ..
                    "), expected one line per skill, got [" .. tostring(shownA) .. "] and [" .. tostring(shownB) .. "]"
            end
        end

        -- A rank that changes without SKILL_LINES_CHANGED is found by the
        -- late pass.
        At(15)
        local quiet = SkillUp()
        skills[1].rank = 37
        Expect(quiet, "<hidden>", "a line waits while the rank hasn't changed")
        At(15.5)
        RunTimers()
        Expect(quiet, "+ 37 Skill: Unarmed", "the late pass finds a rank that changed quietly")

        -- A skill-up shown readably (just before lockdown) claims its rise, so
        -- a hidden line right after doesn't repeat it.
        At(20)
        skills[1].rank = 38
        RanksChanged()
        filter(nil, "CHAT_MSG_SKILL", "Your skill in Unarmed has increased to 38.", "", "", "", "", "", 0, 0, "", 0, 2001)
        At(20.5)
        local afterShown = SkillUp()
        At(24)
        hiddenLines.Update()
        Expect(afterShown, "<hidden>", "a skill-up shown readably isn't repeated on a hidden line")

        -- A rise no line claimed doesn't land on a line much later, and a new
        -- rise isn't held up behind it.
        At(30)
        skills[2].rank = 113
        RanksChanged()
        At(40)
        local late = SkillUp()
        At(44)
        hiddenLines.Update()
        Expect(late, "<hidden>", "an old rise doesn't style a later line")
        At(50)
        skills[1].rank = 39
        RanksChanged()
        Expect(SkillUp(), "+ 39 Skill: Unarmed", "a new rise isn't held up by an old one")

        -- Right after entering a battleground, a skill-up isn't taken for the
        -- "Notify system" line, and a skill rank never names a join.
        Carpenter.Client.isForever = true
        At(60)
        hiddenLines.EnteredBattleground()
        At(60.1)
        local inBattle = SkillUp()
        hiddenLines.Update()
        Expect(inBattle, "<hidden>", "a skill-up isn't emptied as a battleground notice")
        At(60.2)
        skills[2].rank = 114
        RanksChanged()
        Expect(inBattle, "+ 114 Skill: Defense", "a skill-up in a battleground still gets its rank")
        hiddenLines.LeftBattleground()
        Carpenter.Client.isForever = nil

        -- Out of lockdown, nothing is touched.
        inLockdown = false
        At(70)
        skills[1].rank = 40
        RanksChanged()
        Expect(SkillUp(), "<hidden>", "nothing changes outside lockdown")
    end

    feature.Disable()
    C_Timer = realTimer
    ChatFrame1, ChatFrame2, NUM_CHAT_WINDOWS = realChatFrame1, realChatFrame2, realWindows
    ChatTypeInfo.SYSTEM, ChatTypeInfo.SKILL = realSystemInfo, realSkillInfo
    C_ChatInfo, C_SkillInfo = nil, nil
    issecretvalue = nil
end

-- Retail and Forever: Blizzard code prints through AddMessage and keeps
-- running, so the line is edited after it is added rather than replacing
-- AddMessage, which would taint that code.
do
    local HIDDEN = {}
    issecretvalue = function(value) return value == HIDDEN end
    local realHook = hooksecurefunc
    hooksecurefunc = function(target, method, hook)
        local original = target[method]
        target[method] = function(...)
            original(...)
            hook(...)
        end
    end

    local frame = { lines = {} }
    local function original(self, message, r, g, b)
        table.insert(self.lines, { message, r, g, b })
    end
    frame.AddMessage = original
    function frame:TransformMessages(predicate, transform)
        for i, line in ipairs(self.lines) do
            if predicate(line[1], line[2], line[3], line[4]) then
                self.lines[i] = { transform(line[1], line[2], line[3], line[4]) }
            end
        end
    end
    -- Removing a line rebuilds Blizzard's chat history from the addon's
    -- answer, which taints it for every later AddMessage.
    local removals = 0
    function frame:RemoveMessagesByPredicate()
        removals = removals + 1
    end

    postProcessor.HookChatFrameAddMessage(frame)
    additionalChecks = additionalChecks + 1
    if frame._CP_AddMessagePostHooked ~= true or frame._CP_OriginalAddMessage ~= nil then
        failures[#failures + 1] = "post-hook: expected a secure post-hook instead of a replaced AddMessage"
    end

    frame:AddMessage("Gorb Garnsson has left the battle.", 1, 1, 0)
    additionalChecks = additionalChecks + 1
    local last = frame.lines[#frame.lines]
    if not last or plain(last[1]) ~= "Gorb Garnsson left" or last[2] ~= 1 then
        failures[#failures + 1] = "post-hook: expected the added line restyled with its color kept, got [" .. tostring(last and last[1]) .. "]"
    end

    -- Hidden lines are left alone. A line the post-processor always hides is
    -- emptied, never removed.
    local handledFrame
    postProcessor.SetHiddenLineHandler(function(hiddenFrame) handledFrame = hiddenFrame end)
    frame:AddMessage(HIDDEN, 1, 1, 0)
    additionalChecks = additionalChecks + 1
    if handledFrame ~= frame then
        failures[#failures + 1] = "post-hook: a hidden line should go to the hidden line handler"
    end
    postProcessor.SetHiddenLineHandler(ns.Private.ChatCleaner.HiddenLines.OnHiddenLineAdded)
    frame:AddMessage("Auctionator: scan complete", 1, 1, 1)
    additionalChecks = additionalChecks + 1
    if #frame.lines ~= 3 or frame.lines[2][1] ~= HIDDEN or frame.lines[3][1] ~= "" or removals ~= 0 then
        failures[#failures + 1] = "post-hook: expected the hidden line kept and the Auctionator line emptied, got "
            .. #frame.lines .. " lines, " .. removals .. " removals"
    end

    -- Blizzard's money receipt after a merchant or mailbox repeats Chat
    -- Cleaner's own money line, so it is emptied too.
    frame:AddMessage("You gained: |cffffffff28|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t 68|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t|r", 1, 1, 0)
    additionalChecks = additionalChecks + 1
    if #frame.lines ~= 4 or frame.lines[4][1] ~= "" or frame.lines[4][2] ~= 1 then
        failures[#failures + 1] = "post-hook: expected the money receipt emptied, got [" .. tostring(frame.lines[#frame.lines][1]) .. "]"
    end

    -- The chat filter drops those lines before they are added: the in-game
    -- path through the real filters.
    local registered = {}
    local realAddFilter, realRemoveFilter = ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter
    ChatFrame_AddMessageEventFilter = function(event, callback) registered[event] = callback end
    ChatFrame_RemoveMessageEventFilter = function(event) registered[event] = nil end
    local lifecycle = ns.Private.ChatCleanerLifecycle.Create({
        FilterImpl = filter,
        ShouldDropBeforeAdd = postProcessor.ShouldDropBeforeAdd,
        ShouldDropChannelNotice = postProcessor.ShouldDropChannelNotice,
    })
    lifecycle.Enable()

    local function Deliver(event, message)
        local results = { registered[event](frame, event, message, "") }
        if results[1] then return end
        frame:AddMessage(results[2], 1, 1, 0)
    end

    additionalChecks = additionalChecks + 1
    if registered.CHAT_MSG_CHANNEL_NOTICE(frame, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED") ~= true
        or registered.CHAT_MSG_CHANNEL_NOTICE(frame, "CHAT_MSG_CHANNEL_NOTICE", "YOU_LEFT") ~= true
        or registered.CHAT_MSG_CHANNEL_NOTICE(frame, "CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED") ~= false then
        failures[#failures + 1] = "post-hook: expected changed and left channel notices dropped before they are added"
    end

    -- A Forever honor gain prints twice: the first line is restyled, the second never added.
    local linesBefore = #frame.lines
    Deliver("CHAT_MSG_CURRENCY", "You receive currency: |cnIQ1:|Hcurrency:1901:0|h[Honor Points]|h|rx4")
    Deliver("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 4 Honor.")
    additionalChecks = additionalChecks + 1
    if #frame.lines ~= linesBefore + 1 or plain(frame.lines[#frame.lines][1]) ~= "+ 4 Honor Points" then
        failures[#failures + 1] = "post-hook: expected one honor line, got " .. (#frame.lines - linesBefore)
            .. " ending in [" .. tostring(plain(frame.lines[#frame.lines][1])) .. "]"
    end

    -- Two gains of one kind are two lines.
    linesBefore = #frame.lines
    Deliver("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 5 Honor.")
    Deliver("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 5 Honor.")
    additionalChecks = additionalChecks + 1
    if #frame.lines ~= linesBefore + 2 then
        failures[#failures + 1] = "post-hook: expected two honor lines for two gains, got " .. (#frame.lines - linesBefore)
    end

    -- A player's words are never dropped, even when they read like a dropped line.
    linesBefore = #frame.lines
    Deliver("CHAT_MSG_GUILD", "+ Honor Points x5")
    additionalChecks = additionalChecks + 1
    if #frame.lines ~= linesBefore + 1 or removals ~= 0 then
        failures[#failures + 1] = "post-hook: expected guild chat kept and nothing removed"
    end

    lifecycle.Disable()
    ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter = realAddFilter, realRemoveFilter

    -- Turning Chat Cleaner off leaves later lines untouched.
    postProcessor.RestoreChatFrameAddMessage(frame)
    frame:AddMessage("Gorb Garnsson has left the battle.", 1, 1, 0)
    additionalChecks = additionalChecks + 1
    if frame.lines[#frame.lines][1] ~= "Gorb Garnsson has left the battle." then
        failures[#failures + 1] = "post-hook: expected no edits once restored"
    end

    hooksecurefunc = realHook
    issecretvalue = nil
end

-- /roll results: the roller's name takes their class color, found on a
-- visible unit or remembered from their chat messages.
do
    -- The in-game path: the chat filter formats the line, then the chat
    -- frame's AddMessage hook post-processes it.
    local function Roll(message)
        local _, filtered = filter(nil, "CHAT_MSG_SYSTEM", message, "")
        local captured
        postProcessor.ProcessMessage({}, function(_, text) captured = text end, filtered, {})
        return captured
    end
    local warriorColor, mageColor = "|cffc79c6e", "|cff40c7eb"

    -- Your own roll reads "You roll", which keeps the plain roll color.
    local out = Roll("Tester rolls 29 (1-100)")
    additionalChecks = additionalChecks + 1
    if plain(out) ~= "You roll 29 (1-100)" or out:find(warriorColor, 1, true) then
        failures[#failures + 1] = "roll: your own roll should read You without a class color, got [" .. tostring(out) .. "]"
    end

    out = Roll("Koji Kurosawa rolls 77 (1-100)")
    additionalChecks = additionalChecks + 1
    if plain(out) ~= "Koji Kurosawa rolls 77 (1-100)" or out:find(warriorColor, 1, true) or out:find(mageColor, 1, true) then
        failures[#failures + 1] = "roll: an unknown roller should keep the plain color, got [" .. tostring(out) .. "]"
    end

    -- WoW Forever: UnitName returns the surname separately, while the roll
    -- line names the player in full.
    local realUnitName, realUnitClass = UnitName, UnitClass
    Carpenter.Client.isForever = true
    UnitName = function(unit)
        if unit == "player" then return "Koji", "Kurosawa" end
        if unit == "party1" then return "Merrek", "Grimaldus" end
    end
    UnitClass = function(unit)
        if unit == "player" then return "Rogue", "ROGUE" end
        if unit == "party1" then return "Priest", "PRIEST" end
        return nil, nil
    end
    out = Roll("Koji Kurosawa rolls 29 (1-100)")
    additionalChecks = additionalChecks + 1
    if plain(out) ~= "Koji Kurosawa rolls 29 (1-100)" or not out:find("|cfffff569Koji Kurosawa|r", 1, true) then
        failures[#failures + 1] = "roll: Forever surnames should still find your class, got [" .. tostring(out) .. "]"
    end
    -- The class lookup itself also finds party members by their full name.
    groupMembers = 1
    local social = ns.Private.ChatCleanerSocial.Create({})
    additionalChecks = additionalChecks + 1
    if social.GetPlayerClassColor("Merrek Grimaldus") ~= "|cffffffff" then
        failures[#failures + 1] = "roll: Forever surnames should find a party member's class, got " .. tostring(social.GetPlayerClassColor("Merrek Grimaldus"))
    end
    groupMembers = 0

    -- Being removed from a group is red, like leaving one or a disband.
    for _, line in ipairs({ "You have been removed from the group.", "You have been removed from the raid." }) do
        local removed = social.FormatSystemSocialMessage(line)
        additionalChecks = additionalChecks + 1
        if removed ~= "|cffff4040Removed from the group|r" then
            failures[#failures + 1] = "group: being removed should be red, got [" .. tostring(removed) .. "]"
        end
    end

    -- In a party or raid the roll keeps that chat's color, not the class color.
    groupMembers = 2
    out = Roll("Koji Kurosawa rolls 29 (1-100)")
    additionalChecks = additionalChecks + 1
    if not out or out:find("|cfffff569", 1, true) or not out:find("|cffaaaaffKoji Kurosawa|r", 1, true) then
        failures[#failures + 1] = "roll: in a party the roller should use the party color, got [" .. tostring(out) .. "]"
    end
    inRaid = true
    out = Roll("Koji Kurosawa rolls 29 (1-100)")
    additionalChecks = additionalChecks + 1
    if not out or out:find("|cfffff569", 1, true) or not out:find("|cffff7f00Koji Kurosawa|r", 1, true) then
        failures[#failures + 1] = "roll: in a raid the roller should use the raid color, got [" .. tostring(out) .. "]"
    end
    inRaid = false
    groupMembers = 0
    Carpenter.Client.isForever = nil
    UnitName, UnitClass = realUnitName, realUnitClass

    GetPlayerInfoByGUID = function(guid)
        if guid == "Player-1-0000KOJI" then return "Mage", "MAGE" end
    end
    filter(nil, "CHAT_MSG_SAY", "1v1", "Koji Kurosawa", "Common", "", "", "", 0, 0, "", 7, 1, "Player-1-0000KOJI")
    out = Roll("Koji Kurosawa rolls 77 (1-100)")
    additionalChecks = additionalChecks + 1
    if plain(out) ~= "Koji Kurosawa rolls 77 (1-100)" or not out:find(mageColor .. "Koji Kurosawa|r", 1, true) then
        failures[#failures + 1] = "roll: a roller seen in chat should use their class color, got [" .. tostring(out) .. "]"
    end
    GetPlayerInfoByGUID = nil
end

-- Honor lines keep the amount the game gave, and only the game's own lines count.
do
    -- The in-game path. Each line is a new gain, past the duplicate window.
    local function Honor(event, message)
        now = now + 60
        local hidden, filtered = filter(nil, event, message, "")
        if hidden then return nil end
        local captured
        postProcessor.ProcessMessage({}, function(_, text) captured = text end, filtered or message, {})
        return captured
    end

    -- Each client's own wording, from its COMBATLOG_HONOR* and CURRENCY_GAINED* strings.
    local amounts = {
        -- Forever and Retail
        { "CHAT_MSG_CURRENCY", "You receive currency: |cnIQ1:|Hcurrency:1901:0|h[Honor Points]|h|rx4", "4" },
        { "CHAT_MSG_CURRENCY", "You receive currency: |cffffffff|Hcurrency:1901:0|h[Honor Points]|h|rx4", "4" },
        { "CHAT_MSG_CURRENCY", "You receive currency: |cnIQ1:|Hcurrency:1792:0|h[Honor]|h|rx4", "4" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 4 Honor.", "4" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies (Honorable Kill). You gain 4 Honor.", "4" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies (Honorable Kill: Private). You gain 4 Honor.", "4" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies (Honorable Kill: Private). You gain 4 Honor (2 Rested bonus).", "4" },
        -- Classic
        { "CHAT_MSG_CURRENCY", "You receive currency: |cffffffff|Hcurrency:1901:0|h[Honor Points]|h|r x3.", "3" },
        { "CHAT_MSG_CURRENCY", "You receive currency: |cffe6cc80|Hcurrency:392:0|h[Honor Points]|h|r x12.", "12" },
        { "CHAT_MSG_SYSTEM", "You have been awarded 3 honor points.", "3" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 3 honor points.", "3" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies, honorable kill Rank: Private (Estimated Honor Points: 3)", "3" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies, honorable kill Rank: Private (3 Honor Points)", "3" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies, honorable kill Rank: Private (3 Honor Points, +2 Rested)", "3" },
        { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies, honorable kill (3 Honor Points)", "3" },
    }
    for _, case in ipairs(amounts) do
        local out = Honor(case[1], case[2])
        additionalChecks = additionalChecks + 1
        if plain(out) ~= "+ " .. case[3] .. " Honor Points" then
            failures[#failures + 1] = "honor: [" .. case[2] .. "] should read + " .. case[3] .. " Honor Points, got [" .. tostring(plain(out)) .. "]"
        end
    end

    -- One gain prints a currency line and an award or kill line, in either order.
    -- What reaches a chat frame, oldest first, with the clock moved by "wait".
    local CURRENCY_4 = { "CHAT_MSG_CURRENCY", "You receive currency: |cnIQ1:|Hcurrency:1901:0|h[Honor Points]|h|rx4" }
    local CURRENCY_5 = { "CHAT_MSG_CURRENCY", "You receive currency: |cnIQ1:|Hcurrency:1901:0|h[Honor Points]|h|rx5" }
    local AWARD_4 = { "CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 4 Honor." }
    local AWARD_5 = { "CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 5 Honor." }
    local KILL_4 = { "CHAT_MSG_COMBAT_HONOR_GAIN", "Koji Kurosawa dies (Honorable Kill). You gain 4 Honor." }
    local WAIT = { wait = 4 }

    local function Shown(frame, lines)
        local shown = {}
        for _, line in ipairs(lines) do
            if line.wait then
                now = now + line.wait
            else
                local _, filtered = filter(nil, line[1], line[2], "")
                postProcessor.ProcessMessage(frame, function(_, text)
                    shown[#shown + 1] = plain(text)
                end, filtered or line[2], {})
            end
        end
        now = now + 60
        return table.concat(shown, " / ")
    end

    local gains = {
        { "a currency line then its award", { CURRENCY_4, AWARD_4 }, "+ 4 Honor Points" },
        { "an award then its currency line", { AWARD_4, CURRENCY_4 }, "+ 4 Honor Points" },
        { "a currency line then its kill", { CURRENCY_4, KILL_4 }, "+ 4 Honor Points" },
        { "two gains in a row", { CURRENCY_4, AWARD_4, CURRENCY_4, AWARD_4 }, "+ 4 Honor Points / + 4 Honor Points" },
        { "two gains of different amounts", { CURRENCY_4, AWARD_4, CURRENCY_5, AWARD_5 }, "+ 4 Honor Points / + 5 Honor Points" },
        { "two currency lines", { CURRENCY_4, CURRENCY_4 }, "+ 4 Honor Points / + 4 Honor Points" },
        { "two kills", { KILL_4, KILL_4 }, "+ 4 Honor Points / + 4 Honor Points" },
        { "an award of another amount", { CURRENCY_4, AWARD_5 }, "+ 4 Honor Points / + 5 Honor Points" },
        { "an award after the window", { CURRENCY_4, WAIT, AWARD_4 }, "+ 4 Honor Points / + 4 Honor Points" },
    }
    for _, gain in ipairs(gains) do
        local got = Shown({}, gain[2])
        additionalChecks = additionalChecks + 1
        if got ~= gain[3] then
            failures[#failures + 1] = "honor: " .. gain[1] .. " should show [" .. gain[3] .. "], got [" .. got .. "]"
        end
    end

    -- Every chat frame showing these lines gets one line of its own.
    local generalFrame, lootFrame = {}, {}
    local general, loot = {}, {}
    for _, line in ipairs({ CURRENCY_4, AWARD_4 }) do
        local _, filtered = filter(nil, line[1], line[2], "")
        postProcessor.ProcessMessage(generalFrame, function(_, text) general[#general + 1] = plain(text) end, filtered or line[2], {})
        postProcessor.ProcessMessage(lootFrame, function(_, text) loot[#loot + 1] = plain(text) end, filtered or line[2], {})
    end
    now = now + 60
    additionalChecks = additionalChecks + 1
    if table.concat(general, " / ") ~= "+ 4 Honor Points" or table.concat(loot, " / ") ~= "+ 4 Honor Points" then
        failures[#failures + 1] = "honor: each chat frame should show the gain once, got ["
            .. table.concat(general, " / ") .. "] and [" .. table.concat(loot, " / ") .. "]"
    end

    -- Chat goes straight to the chat frame, so these skip the filter. Guild color
    -- first: its digits used to end up as the amount.
    local chatLines = {
        "|cff40ff40|Hchannel:GUILD|h[Guild]|h |Hplayer:Bob:1:GUILD|h[Bob]|h: honor points are capped at 75000|r",
        "|cffaaaaff|Hchannel:PARTY|h[Party]|h |Hplayer:Bob:2:PARTY|h[Bob]|h: I have 20 honor points|r",
        "|cffffffff|Hplayer:Bob:3:SAY|h[Bob]|h says: anyone got 20 honor?|r",
        "|cffff80ff|Hplayer:Bob:4:WHISPER|h[Bob]|h whispers: I need 1500 Honor Points for the shoulders|r",
        "|cffff80ff|HBNplayer:Bob:5:6:BN_WHISPER:Bob|h[Bob]|h whispers: 3 honor points left|r",
        "|cffff4040Herald yells: The victors earn 300 Honor Points!|r",
        "|cffffffff|Hplayer:Bob:7:SAY|h[Bob]|h says: Foo dies, honorable kill (3 Honor Points)|r",
    }
    for _, line in ipairs(chatLines) do
        now = now + 60
        local captured
        postProcessor.ProcessMessage({}, function(_, text) captured = text end, line, {})
        local message = plain(line):gsub("^.-: ", "", 1):gsub("^.- yells: ", "", 1)
        additionalChecks = additionalChecks + 1
        if not captured or not captured:find(message, 1, true) then
            failures[#failures + 1] = "honor: chat should stay as written [" .. line .. "], got [" .. tostring(captured) .. "]"
        end
    end

    -- Other lines that only mention honor stay as the filter styled them.
    local others = {
        { "CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Honor Hold increased by 50.", "+ 50 Reputation: Honor Hold" },
        { "CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:20560:0|h[Alterac Valley Mark of Honor]|h|rx3.", "Alterac Valley Mark of Honor" },
        { "CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:24579:0|h[Mark of Honor Hold]|h|rx5.", "Mark of Honor Hold" },
        { "CHAT_MSG_SYSTEM", "Quest accepted: Honor the Dead", "+ Accepted: Honor the Dead" },
    }
    for _, case in ipairs(others) do
        local out = plain(Honor(case[1], case[2]))
        additionalChecks = additionalChecks + 1
        if not out or not out:find(case[3], 1, true) or out:find("Honor Points", 1, true) then
            failures[#failures + 1] = "honor: [" .. case[2] .. "] should not become an honor gain, got [" .. tostring(out) .. "]"
        end
    end
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("chat-cleaner fixtures: " .. (#fixtures + additionalChecks) .. " passed")
