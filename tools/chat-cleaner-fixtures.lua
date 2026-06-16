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
    Client = { isRetail = false },
    IsEnabled = function(_, key) return key == "chatCleanerEnabled" end,
    RegisterFeature = function() end,
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
function CreateFrame()
    local frame = { _scripts = {} }
    function frame:RegisterEvent() end
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
    {
        name = "player links keep original color",
        path = "post",
        event = "CHAT_MSG_CHANNEL",
        message = "|Hplayer:Tester|h[Tester]|h says hi",
        expectPlain = "Tester says hi",
        rejectColor = "|cffc69b6d",
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
        expectPlain = "- 125 Reputation: Bloodsail Buccaneers",
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
        name = "auctionator hidden",
        event = "CHAT_MSG_SYSTEM",
        message = "Auctionator: scan complete",
        expectHidden = true,
    },
}

local failures = {}
local additionalChecks = 0

for _, fixture in ipairs(fixtures) do
    local hidden, out
    groupMembers = fixture.groupMembers or 0
    inRaid = fixture.inRaid or false
    inCombatLockdown = fixture.inCombatLockdown == true
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

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("chat-cleaner fixtures: " .. (#fixtures + additionalChecks) .. " passed")
