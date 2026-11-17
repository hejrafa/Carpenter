--[[ Carpenter - ChatCleaner ]]
local _, ns = ...
local L = Carpenter.L
local IsSecret = Carpenter.Secret.IsSecret

local Utils = ns.Private.ChatCleanerUtils
local ChatCleanerLoot = ns.Private.ChatCleanerLoot
local ChatCleanerSessions = ns.Private.ChatCleanerSessions
local ChatCleanerSystem = ns.Private.ChatCleanerSystem
local ChatCleanerRewards = ns.Private.ChatCleanerRewards
local ChatCleanerSocial = ns.Private.ChatCleanerSocial
local ChatCleanerPostProcess = ns.Private.ChatCleanerPostProcess
local ChatCleanerLifecycle = ns.Private.ChatCleanerLifecycle

-- Chat Cleaner's palette, after Goldpaw's ChatCleaner
-- (github.com/GoldpawsStuff/ChatCleaner): gray + and − signs, white amounts
-- and labels, and an accent for each kind of thing named.
local Colors = ns.Private.Colors
local ColorPlus         = Colors.gray.colorCode        -- "+" and "−" signs, counts
local ColorMinus        = Colors.gray.colorCode
local ColorWhite        = Colors.white.colorCode       -- amounts and labels
local ColorLootLiteral  = Colors.white.colorCode       -- loot and roll words
local ColorPalered      = Colors.palered.colorCode     -- money lost
local ColorOffwhite     = "|cfff0f0f0"                 -- group lines with no group color
local ColorYellow       = "|cffffd200"                 -- quests, friends, the top level
local ColorGreen        = "|cff00ff00"                 -- joins, bare loot items
local ColorOrange       = "|cffff8000"
local ColorDarkorange   = "|cffff6600"
local ColorRed          = "|cffff0000"                 -- the game's red, as on its Horde battleground lines
local ColorPurple       = "|cffb794f4"                 -- skill and spell names
local ColorTransmog     = "|cffff80ff"                 -- Blizzard's appearance collection pink
local ColorBluePurple   = "|cff9d8cff"                 -- reputation factions
local ColorTeal         = "|cff00ccaa"                 -- discovered zones
local ColorQueue        = "|cff80b0ff"                 -- battleground and queue names
local ColorCyan         = "|cff00ccff"                 -- generic rewards
local ColorAuctionHouse = "|cffffb347"                 -- buyer found, auction created
local ColorRestedBar    = "|cff3399ff"                 -- the XP bar's rested and normal blues
local ColorNormalBar    = "|cff9940ff"

local PREFIX_PLUS = ColorPlus .. "+|r "
local PREFIX_MINUS = ColorMinus .. Carpenter.MinusSign .. "|r "

local ParseRetailMoneyGain = Utils.ParseRetailMoneyGain
local StripBrackets = Utils.StripBrackets
local CleanPunctuation = Utils.CleanPunctuation
local SpaceBeforeX = Utils.SpaceBeforeX
local RemoveLinkBrackets = Utils.RemoveLinkBrackets
local GetItemLinkFromMessage = Utils.GetItemLinkFromMessage
local GetItemLinkWithQualityColor = Utils.GetItemLinkWithQualityColor
local ShouldSkipGenericReceive = Utils.ShouldSkipGenericReceive

local function FormatMoney(amount, amountColor)
    return Utils.FormatMoney(amount, amountColor or ColorWhite, Carpenter.MoneyIcons)
end

local function FormatItemCountSuffix(text)
    return Utils.FormatItemCountSuffix(text, ColorPlus)
end

local function FormatReceivedDisplay(rawDisplay, sourceMessage)
    return Utils.FormatReceivedDisplay(rawDisplay, sourceMessage, { CountColor = ColorPlus })
end

-- A chat type's color as the player set it, as a color code.
local function ChatTypeColor(chatType, fallback)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if not info or not info.r then return fallback end
    return Utils.ColorCode(info.r, info.g, info.b)
end

-- The party or raid chat color, for group lines like "X joins".
local function GetPartyOrRaidMessageColor()
    return ChatTypeColor(IsInRaid() and "RAID" or "PARTY", ColorOffwhite)
end

local GROUP_CHAT_TYPE_BY_EVENT = {
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER",
}

-- The color of loot and roll lines: the chat's own color in party or raid
-- chat, the group's color for loot and system lines in a group, else white.
local function GetChannelMessageColor(event)
    local chatType = GROUP_CHAT_TYPE_BY_EVENT[event]
    if not chatType and (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM") and GetNumGroupMembers() > 0 then
        chatType = IsInRaid() and "RAID" or "PARTY"
    end
    return chatType and ChatTypeColor(chatType, ColorLootLiteral) or ColorLootLiteral
end

local function GetGuildMessageColor()
    return ChatTypeColor("GUILD", ColorGreen)
end

local socialFormatter = ChatCleanerSocial.Create({
    L = L,
    GetPartyOrRaidMessageColor = GetPartyOrRaidMessageColor,
    CleanPunctuation = CleanPunctuation,
    ColorGreen = ColorGreen,
    ColorRed = ColorRed,
    ColorOrange = ColorOrange,
    ColorDarkorange = ColorDarkorange,
    ColorWhite = ColorWhite,
    ColorQueue = ColorQueue,
    ColorRestedBar = ColorRestedBar,
    ColorNormalBar = ColorNormalBar,
    ColorFriendNotice = ColorYellow,
    GetGuildMessageColor = GetGuildMessageColor,
})
local FormatBattlegroundAndGroupNotice = socialFormatter.FormatBattlegroundAndGroupNotice
local FormatSystemSocialMessage = socialFormatter.FormatSystemSocialMessage
local RememberSenderClass = socialFormatter.RememberSenderClass

local GroupLootPatterns = ChatCleanerLoot.BuildGroupLootPatterns()
local RollPatterns = ChatCleanerLoot.BuildRollPatterns()
-- Roll names take their class color only outside a group; in a party or raid
-- they keep that chat's color, like the rest of the roll line.
local function GetPlayerNameColor(name)
    if GetNumGroupMembers() > 0 then return nil end
    return socialFormatter.GetPlayerClassColor(name)
end
local lootFormatter = ChatCleanerLoot.Create({
    L = L,
    CleanPunctuation = CleanPunctuation,
    StripBrackets = StripBrackets,
    SpaceBeforeX = SpaceBeforeX,
    GetItemLinkFromMessage = GetItemLinkFromMessage,
    GetItemLinkWithQualityColor = GetItemLinkWithQualityColor,
    FormatItemCountSuffix = FormatItemCountSuffix,
    FormatReceivedDisplay = FormatReceivedDisplay,
    ShouldSkipGenericReceive = ShouldSkipGenericReceive,
    GroupLootPatterns = GroupLootPatterns,
    RollPatterns = RollPatterns,
    GetPlayerNameColor = GetPlayerNameColor,
    ColorPlus = ColorPlus,
    ColorLootLiteral = ColorLootLiteral,
    ColorGreen = ColorGreen,
    GetChannelMessageColor = GetChannelMessageColor,
})
local FormatSelfLootMessage = lootFormatter.FormatSelfLootMessage
local FormatGroupLootMessage = lootFormatter.FormatGroupLootMessage
local FormatLootRollMessage = lootFormatter.FormatLootRollMessage

local sessionTracker = ChatCleanerSessions.Create({
    FormatMoney = FormatMoney,
    ColorPlus = ColorPlus,
    ColorMinus = ColorMinus,
})

local systemFormatter = ChatCleanerSystem.Create({
    L = L,
    CleanPunctuation = CleanPunctuation,
    StripBrackets = StripBrackets,
    SpaceBeforeX = SpaceBeforeX,
    ColorPlus = ColorPlus,
    ColorMinus = ColorMinus,
    ColorWhite = ColorWhite,
    ColorBluePurple = ColorBluePurple,
    ColorQueue = ColorQueue,
    ColorPurple = ColorPurple,
    ColorTransmog = ColorTransmog,
    ColorTeal = ColorTeal,
    ColorYellow = ColorYellow,
    GetItemLinkFromMessage = GetItemLinkFromMessage,
    IsMainlineClient = function()
        return Carpenter.Client and Carpenter.Client.isMainline == true
    end,
    LearnedSkillDedupSeconds = 3,
})
local IsLevelUpRewardEvent = systemFormatter.IsLevelUpRewardEvent
local FormatExperienceMessage = systemFormatter.FormatExperienceMessage
local FormatQuestProgressMessage = systemFormatter.FormatQuestProgressMessage
local FormatLevelUpRewardMessage = systemFormatter.FormatLevelUpRewardMessage
local FormatReputationMessage = systemFormatter.FormatReputationMessage
local FormatQueueNotice = systemFormatter.FormatQueueNotice
local FormatSkillMessage = systemFormatter.FormatSkillMessage
local ClaimVisibleSkillRise = systemFormatter.ClaimVisibleSkillRise
local FormatAppearanceCollectionMessage = systemFormatter.FormatAppearanceCollectionMessage

local rewardFormatter = ChatCleanerRewards.Create({
    L = L,
    CleanPunctuation = CleanPunctuation,
    StripBrackets = StripBrackets,
    SpaceBeforeX = SpaceBeforeX,
    GetItemLinkFromMessage = GetItemLinkFromMessage,
    GetItemLinkWithQualityColor = GetItemLinkWithQualityColor,
    ParseRetailMoneyGain = ParseRetailMoneyGain,
    FormatMoney = FormatMoney,
    ColorPlus = ColorPlus,
    ColorWhite = ColorWhite,
    ColorCyan = ColorCyan,
    ColorPurple = ColorPurple,
    ColorHonor = ColorRed,
    ColorPalered = ColorPalered,
    ColorMinus = ColorMinus,
    ColorAuctionHouse = ColorAuctionHouse,
    ColorAuctionExpired = ColorRed,
    MerchantFrame = sessionTracker.merchantFrame,
    MailTracker = sessionTracker.mailTracker,
    RepairDedupSeconds = 2,
})
local FormatCurrencyMessage = rewardFormatter.FormatCurrencyMessage
local FormatMoneyMessage = rewardFormatter.FormatMoneyMessage
local FormatAuctionMessage = rewardFormatter.FormatAuctionMessage
local FormatRefundMessage = rewardFormatter.FormatRefundMessage
local FormatGenericReward = rewardFormatter.FormatGenericReward

local postProcessor = ChatCleanerPostProcess.Create({
    L = L,
    RemoveLinkBrackets = RemoveLinkBrackets,
    FormatLevelUpRewardMessage = FormatLevelUpRewardMessage,
    FormatAppearanceCollectionMessage = FormatAppearanceCollectionMessage,
    ParseRetailMoneyGain = ParseRetailMoneyGain,
    SpaceBeforeX = SpaceBeforeX,
    ColorPlus = ColorPlus,
    ColorLootLiteral = ColorLootLiteral,
    ColorGreen = ColorGreen,
    GetChannelMessageColor = GetChannelMessageColor,
    GetPlayerNameColor = GetPlayerNameColor,
    ColorRed = ColorRed,
    HonorDelay = 3,
    JoinDedupDelay = 8,
})
local HookChatFrameAddMessage = postProcessor.HookChatFrameAddMessage

local function IsNameByte(byte)
    return byte and (byte >= 128 or string.char(byte):match("[%w']") ~= nil)
end

-- Blizzard links a text emote's sender by replacing the first occurrence of the
-- sender name in the message. WoW Forever reports "T" as the sender of your own
-- emotes, so that replacement recolors the first capital T of a target's name.
-- Drop the sender when its first occurrence is only part of a word.
local function SafeTextEmoteSender(msg, author)
    if type(msg) ~= "string" or type(author) ~= "string" or author == "" then return author end

    local ok, safeAuthor = pcall(function()
        local first, last = msg:find(author, 1, true)
        if not first then return author end
        if IsNameByte(msg:byte(first - 1)) or IsNameByte(msg:byte(last + 1)) then
            return ""
        end
        return author
    end)
    return ok and safeAuthor or author
end

-- "[You died.]" is the game's Death Recap link. It reads "You died" in red,
-- as other deaths do, and still opens the recap when clicked.
local function FormatOwnDeath(recapID)
    local text = type(DEATH_RECAP_TEXT) == "string" and DEATH_RECAP_TEXT ~= "" and DEATH_RECAP_TEXT or "You died."
    text = text:gsub("%.%s*$", "")
    if recapID then
        return ColorRed .. "|Hdeath:" .. recapID .. "|h" .. text .. "|h|r"
    end
    return ColorRed .. text .. "|r"
end

-- The hidden "[You died.]" line rewritten: the latest recap's link when the
-- game gives it, else the words alone.
local function OwnDeathLine()
    local recapID
    if C_DeathRecap and C_DeathRecap.GetRecapLink then
        local ok, link = pcall(C_DeathRecap.GetRecapLink)
        if ok and not IsSecret(link) and type(link) == "string" then
            recapID = link:match("|Hdeath:(%d+)|h")
        end
    end
    return FormatOwnDeath(recapID)
end

local PLAYER_CHAT_EVENTS = {
    CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true, CHAT_MSG_BN_WHISPER = true,
    CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true, CHAT_MSG_CHANNEL = true,
    CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
}

local function StripColorsAndLinks(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

-- The game's lines, through each formatter in the order they claim them:
-- each answers true (hide the line), its new text, or nil (not its line).
-- plain is the line without colors and links.
local FILTER_STEPS = {
    function(_, msg, plain) return FormatExperienceMessage(msg, plain, PREFIX_PLUS) end,
    function(event, _, plain) return FormatBattlegroundAndGroupNotice(event, plain) end,
    function(event, _, plain)
        if IsLevelUpRewardEvent(event) then return FormatLevelUpRewardMessage(plain) end
    end,
    function(event, msg, plain)
        if event ~= "CHAT_MSG_SYSTEM" then return nil end
        return FormatQuestProgressMessage(event, msg, plain, PREFIX_PLUS) or FormatSystemSocialMessage(plain)
    end,
    function(_, msg) return FormatReputationMessage(msg) end,
    function(event, msg) return FormatQueueNotice(msg, event) end,
    function(event, msg, plain) return FormatAppearanceCollectionMessage(event, msg, plain, PREFIX_PLUS) end,
    function(_, msg) return FormatAuctionMessage(msg, PREFIX_PLUS, PREFIX_MINUS) end,
    function(event, msg) return FormatCurrencyMessage(event, msg, PREFIX_PLUS) end,
    function(event, msg) return FormatMoneyMessage(event, msg, PREFIX_PLUS, PREFIX_MINUS) end,
    function(_, msg, plain, _, frame) return FormatSkillMessage(msg, plain, PREFIX_PLUS, PREFIX_MINUS, frame) end,
    function(event, msg) return FormatSelfLootMessage(event, msg, PREFIX_PLUS) end,
    function(event, msg, _, author) return FormatGroupLootMessage(event, msg, author) end,
    function(event, msg) return FormatLootRollMessage(event, msg) end,
    function(_, msg) return FormatRefundMessage(msg) end,
    function(event, msg) return FormatGenericReward(event, msg, PREFIX_PLUS) end,
}

-- Lines that only add noise: channel changes (the prefixes already say
-- which channel) and Auctionator's own notes.
local function IsDroppedSystemLine(msg)
    return msg:find("^Changed Channel:") or msg:find("^Left Channel:") or msg:find("^Auctionator:")
        or msg:find("^|c%x%x%x%x%x%x%x%xAuctionator:")
end

local function ChatFilterImpl(frame, event, msg, author, ...)
    if not Carpenter:IsEnabled("chatCleanerEnabled") then
        return false, msg, author, ...
    end

    -- Retail and WoW Forever hide some chat text in battlegrounds and in combat
    -- inside instances, and don't pass those lines to addon filters at all;
    -- ChatCleanerHiddenLines rewrites them in the chat history instead. Should
    -- one get here anyway, it passes through untouched.
    if IsSecret(msg) or type(msg) ~= "string" then
        return false, msg, author, ...
    end

    if event == "CHAT_MSG_SKILL" then
        ClaimVisibleSkillRise(msg)
    end

    -- Chat events carry the sender's GUID (arg12); remember their class so
    -- later system lines about them, like /roll results, can be colored too.
    if author and author ~= "" then
        RememberSenderClass(author, select(10, ...))
    end

    if event == "CHAT_MSG_TEXT_EMOTE" then
        return false, msg, SafeTextEmoteSender(msg, author), ...
    end

    -- Blizzard formats a monster emote with the monster's name, and a
    -- numeric placeholder like %o paired with a name throws "bad argument
    -- #2 to 'format'". The name goes in here, and any other "%" is escaped
    -- so the formatter sees plain text.
    if event == "CHAT_MSG_MONSTER_EMOTE" then
        if author and author ~= "" then
            msg = msg:gsub("%%[sSoO]", (author:gsub("%%", "%%%%")))
        end
        msg = msg:gsub("%%", "%%%%")
    end

    -- A loot-announcing addon yelling your own loot repeats the loot line.
    -- On Forever the line names you "First Surname", UnitName only "First".
    if event == "CHAT_MSG_YELL" then
        local playerName = ChatCleanerLoot.GetGroupLootPlayerName(msg, GroupLootPatterns, author)
        local firstWord = playerName and playerName:match("^[^%s%-]+")
        if firstWord and (firstWord == "You" or firstWord == UnitName("player")) then
            return true
        end
    end

    -- Players' own words stay as they typed them: the formatters below are
    -- for the game's lines, and a player saying "Party converted to Raid" or
    -- "You receive 5 tokens" isn't one. Loot lines posted in party and raid
    -- chat are the exception, styled in the group's color.
    if PLAYER_CHAT_EVENTS[event] then
        if GROUP_CHAT_TYPE_BY_EVENT[event] then
            local groupLootMessage = FormatGroupLootMessage(event, msg, author)
            if groupLootMessage then
                return false, groupLootMessage, author, ...
            end
        end
        return false, msg, author, ...
    end

    if IsDroppedSystemLine(msg) then
        return true
    end

    local recapID = msg:match("|Hdeath:(%d+)|h")
    if recapID then
        return false, FormatOwnDeath(recapID), author, ...
    end

    local plain = StripColorsAndLinks(msg)
    for _, step in ipairs(FILTER_STEPS) do
        local result = step(event, msg, plain, author, frame)
        if result == true then return true end
        if result then return false, result, author, ... end
    end

    -- Blizzard writes some counts with no space before them ("Badgex5").
    return false, SpaceBeforeX(msg), author, ...
end

local chatCleanerFeature = ChatCleanerLifecycle.Create({
    FilterImpl = ChatFilterImpl,
    HookChatFrameAddMessage = HookChatFrameAddMessage,
    RestoreChatFrameAddMessage = postProcessor.RestoreChatFrameAddMessage,
    ShouldDropBeforeAdd = postProcessor.ShouldDropBeforeAdd,
    ShouldDropChannelNotice = postProcessor.ShouldDropChannelNotice,
    SessionTracker = sessionTracker,
})

ns.Private.ChatCleaner = ns.Private.ChatCleaner or {}
ns.Private.ChatCleaner.FilterImpl = ChatFilterImpl
ns.Private.ChatCleaner.PostProcessor = postProcessor
ns.Private.ChatCleaner.SocialFormatter = socialFormatter

Carpenter:RegisterFeature("chatCleanerEnabled", chatCleanerFeature)

-- The settings sidebar calls this when the input box texture option changes.
function Carpenter_ApplyChatEditBoxTexture()
    chatCleanerFeature.ApplyEditBox()
end

-- Inside battlegrounds, and in fights in instances, the game hides player
-- chat from addons. The chat window still keeps each line's event and its
-- values, and addon code may join hidden text into new text, so the line is
-- rebuilt as the post-processor styles a shown one: the short channel tag,
-- the sender as a player link, and the message. Event: chat type and the
-- player link's chat group.
local HIDDEN_CHAT_TYPES = {
    CHAT_MSG_GUILD = { "GUILD", "GUILD" },
    CHAT_MSG_OFFICER = { "OFFICER", "OFFICER" },
    CHAT_MSG_PARTY = { "PARTY", "PARTY" },
    CHAT_MSG_PARTY_LEADER = { "PARTY_LEADER", "PARTY" },
    CHAT_MSG_RAID = { "RAID", "RAID" },
    CHAT_MSG_RAID_LEADER = { "RAID_LEADER", "RAID" },
    CHAT_MSG_RAID_WARNING = { "RAID_WARNING", "RAID" },
    CHAT_MSG_INSTANCE_CHAT = { "INSTANCE_CHAT", "INSTANCE_CHAT" },
    CHAT_MSG_INSTANCE_CHAT_LEADER = { "INSTANCE_CHAT_LEADER", "INSTANCE_CHAT" },
}

local function IsHiddenChatEvent(event)
    return HIDDEN_CHAT_TYPES[event] ~= nil
end

-- The class color the game gives a sender's name, when the chat settings
-- color this chat type's names by class. The sender's ID is hidden too, but
-- UnitClassFromGUID takes a hidden ID from addons and leaves the class's file
-- name readable (per its API documentation).
local function HiddenSenderColor(chatType, guid)
    if not (guid and type(UnitClassFromGUID) == "function") then return nil end
    local util, info = ChatFrameUtil, ChatTypeInfo and ChatTypeInfo[chatType]
    if util and util.ShouldColorChatByClass and info then
        local ok, colored = pcall(util.ShouldColorChatByClass, info)
        if ok and not IsSecret(colored) and not colored then return nil end
    end
    local ok, _, classFile = pcall(UnitClassFromGUID, guid)
    if not ok or IsSecret(classFile) or type(classFile) ~= "string" then return nil end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then return nil end
    if type(color.colorStr) == "string" then return "|c" .. color.colorStr end
    return string.format("|cff%02x%02x%02x", math.floor((color.r or 1) * 255), math.floor((color.g or 1) * 255),
        math.floor((color.b or 1) * 255))
end

-- The sender as the game shows them: the short name (the realm left out
-- where the game would) in its class color. The name stays hidden; it is
-- only joined into the line.
local function HiddenSenderName(event, chatType, args)
    local name = args[2]
    local ok, short = pcall(Ambiguate, name, chatType == "GUILD" and "guild" or "none")
    if ok and short then name = short end
    local color = HiddenSenderColor(chatType, args[12])
    if color then return color .. name .. "|r" end
    return name
end

-- The chat timestamp the game puts before each line, when it's switched on.
local function ChatTimestamp()
    local util = ChatFrameUtil
    if not (util and util.GetTimestampFormat and TimeUtil and TimeUtil.BetterDate) then return "" end
    local ok, format = pcall(util.GetTimestampFormat)
    if not ok or not format then return "" end
    local okDate, stamp = pcall(TimeUtil.BetterDate, format, type(time) == "function" and time() or nil)
    return okDate and type(stamp) == "string" and stamp or ""
end

local function BuildHiddenChat(event, args)
    local types = HIDDEN_CHAT_TYPES[event]
    if not types or type(args) ~= "table" or not postProcessor.StyleChatPrefix then return nil end
    local prefix = postProcessor.StyleChatPrefix(_G["CHAT_" .. types[1] .. "_GET"])
    local message, author, lineID = args[1], args[2], args[11]
    if not (prefix and message and author) then return nil end
    local link = "|Hplayer:" .. author .. ":" .. (lineID or 0) .. ":" .. types[2] .. "|h"
        .. HiddenSenderName(event, types[1], args) .. "|h"
    return ChatTimestamp() .. string.format(prefix, link) .. message
end

local function FormatHiddenChat(event, args)
    local ok, text = pcall(BuildHiddenChat, event, args)
    if ok then return text end
end

-- Keeps group deaths, the roster, skill ranks and battleground queues
-- current, so hidden death, join, leave, skill-up and queue lines can be
-- rewritten from them in the chat history.
local HiddenLines = ns.Private.ChatCleanerHiddenLines

local function InChatMessagingLockdown()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then return false end
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    return ok and not IsSecret(locked) and locked == true
end

local hiddenLines = HiddenLines and HiddenLines.Create({
    GetFrames = function()
        local frames = {}
        for i = 1, NUM_CHAT_WINDOWS or 0 do
            local frame = _G["ChatFrame" .. i]
            if frame and frame._CP_AddMessagePostHooked and frame._CP_AddMessageHooked then
                frames[#frames + 1] = frame
            end
        end
        return frames
    end,
    GetChanges = socialFormatter.GetGroupChanges,
    FormatChange = socialFormatter.FormatGroupChange,
    GetSkillRises = systemFormatter.GetSkillRises,
    FormatSkillRise = systemFormatter.FormatSkillRise and function(rise)
        return systemFormatter.FormatSkillRise(rise, ColorPlus .. "+|r ")
    end,
    GetQueueChanges = systemFormatter.GetQueueChanges,
    FormatQueueChange = systemFormatter.FormatQueueChange,
    IsActive = function()
        return Carpenter ~= nil and Carpenter:IsEnabled("chatCleanerEnabled") and InChatMessagingLockdown()
    end,
    IsForever = function()
        return Carpenter ~= nil and Carpenter.Client ~= nil and Carpenter.Client.isForever == true
    end,
    FormatOwnDeath = OwnDeathLine,
    IsHiddenChatEvent = IsHiddenChatEvent,
    FormatHiddenChat = FormatHiddenChat,
})
ns.Private.ChatCleaner.HiddenLines = hiddenLines

if hiddenLines and postProcessor and postProcessor.SetHiddenLineHandler then
    postProcessor.SetHiddenLineHandler(hiddenLines.OnHiddenLineAdded)
end

-- "You are no longer queued." doesn't say which queue, and comes a moment
-- before the queue goes. Once it has, the line shown as "− Left the queue"
-- gets the queue's name.
local function NameShownQueueLines()
    if not (hiddenLines and systemFormatter.GetQueueChanges and systemFormatter.LeftQueueText) then return end
    for _, change in ipairs(systemFormatter.GetQueueChanges()) do
        if change.kind == "left" and change.name and not change.shownChecked then
            change.shownChecked = true
            change.named = hiddenLines.RenameShownLine(systemFormatter.LeftQueueText(),
                systemFormatter.FormatQueueChange(change), change.time - change.window)
        end
    end
end

-- The lines the game sends as it forms a battleground's group, in its order
-- (a probe's log): "Party converted to Raid" for a raid, then the loot method
-- and the loot threshold, styled as the chat filter styles them. Nil when the
-- loot settings can't be read.
local LOOT_METHOD_STRINGS = {
    freeforall = { "Freeforall", "ERR_SET_LOOT_FREEFORALL", "Looting set to Free for All." },
    roundrobin = { "Roundrobin", "ERR_SET_LOOT_ROUNDROBIN", "Looting set to Round Robin." },
    master = { "Masterlooter", "ERR_SET_LOOT_MASTER", "Looting set to Master Looter." },
    group = { "Group", "ERR_SET_LOOT_GROUP", "Looting set to Group Loot." },
    needbeforegreed = { "Needbeforegreed", "ERR_SET_LOOT_NBG", "Looting set to Need Before Greed." },
    personalloot = { "Personal", "ERR_SET_LOOT_PERSONAL", "Looting set to Personal." },
}

local function GameText(key, fallback)
    local text = _G[key]
    if type(text) == "string" and text ~= "" then return text end
    return fallback
end

-- The game's "Looting set to ..." line for the group's loot method, which
-- Retail-based clients give as an Enum.LootMethod value and Classic as a name.
local function LootMethodLine()
    local getter = C_PartyInfo and C_PartyInfo.GetLootMethod or _G.GetLootMethod
    if type(getter) ~= "function" then return nil end
    local ok, method = pcall(getter)
    if not ok or IsSecret(method) then return nil end
    for name, strings in pairs(LOOT_METHOD_STRINGS) do
        local enumValue = Enum and Enum.LootMethod and Enum.LootMethod[strings[1]]
        if method == name or (enumValue ~= nil and method == enumValue) then
            return GameText(strings[2], strings[3])
        end
    end
end

local function LootThresholdLine()
    if type(GetLootThreshold) ~= "function" then return nil end
    local ok, quality = pcall(GetLootThreshold)
    if not ok or IsSecret(quality) or type(quality) ~= "number" then return nil end
    local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if type(name) ~= "string" then return nil end
    return GameText("ERR_SET_LOOT_THRESHOLD_S", "Loot threshold set to %s."):format(name)
end

local function GroupSetupLines()
    local method, threshold = LootMethodLine(), LootThresholdLine()
    if not (method and threshold) then return nil end
    local texts = {}
    if IsInRaid() then
        texts[1] = FormatBattlegroundAndGroupNotice("CHAT_MSG_SYSTEM",
            GameText("ERR_PARTY_CONVERTED_TO_RAID", "Party converted to Raid"))
    end
    texts[#texts + 1] = FormatSystemSocialMessage and FormatSystemSocialMessage(method)
    texts[#texts + 1] = FormatSystemSocialMessage and FormatSystemSocialMessage(threshold)
    for index = 1, (IsInRaid() and 3 or 2) do
        if type(texts[index]) ~= "string" then return nil end
    end
    return texts
end

-- The chat windows handle an event before Carpenter does, so a hidden line is
-- already in their history here and is rewritten before they redraw. A later
-- pass catches what has to wait.
local function UpdateHiddenLines(delay)
    if not hiddenLines then return end
    if not delay then
        pcall(hiddenLines.Update)
        return
    end
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(delay, function()
        pcall(hiddenLines.Update)
    end)
end

-- Keeps the skill rank snapshot current. The game reports a new rank just
-- before or just after it adds the hidden skill-up, so both look for a match;
-- a late pass catches a rank that changed without SKILL_LINES_CHANGED.
local SKILL_LATE_PASS = 0.5
local skillRankFrame = CreateFrame("Frame")
skillRankFrame:SetScript("OnEvent", function(_, event, arg1)
    if systemFormatter.RefreshSkillRanks then
        systemFormatter.RefreshSkillRanks()
    end
    if event == "CHAT_MSG_SKILL" then
        if IsSecret(arg1) then
            UpdateHiddenLines()
            UpdateHiddenLines(SKILL_LATE_PASS)
        end
    elseif hiddenLines and hiddenLines.HasPending() then
        UpdateHiddenLines()
    end
end)

local groupNoticeFrame = CreateFrame("Frame")
groupNoticeFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        -- These fire for every unit; only a group member's new death can
        -- explain a waiting line.
        if socialFormatter.NoteGroupMemberHealth and socialFormatter.NoteGroupMemberHealth(arg1)
            and hiddenLines and hiddenLines.HasPending() then
            UpdateHiddenLines()
        end
        return
    elseif event == "CHAT_MSG_SYSTEM" then
        if IsSecret(arg1) then
            UpdateHiddenLines()
            UpdateHiddenLines(0)
            UpdateHiddenLines(HiddenLines.START_NOTICE_GRACE + 0.05)
        end
        return
    elseif event == "PLAYER_ENTERING_BATTLEGROUND" then
        if hiddenLines then
            hiddenLines.EnteredBattleground()
            for _, batchTime in ipairs(HiddenLines.BATCH_TIMES) do
                UpdateHiddenLines(batchTime + HiddenLines.BATCH_CHECK_DELAY)
            end
        end
        UpdateHiddenLines()
        return
    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        if hiddenLines and socialFormatter.IsBattleStartAnnouncement
            and socialFormatter.IsBattleStartAnnouncement(arg1) then
            hiddenLines.BattleBegan()
        end
        return
    elseif event == "PLAYER_DEAD" then
        if hiddenLines then hiddenLines.PlayerDied() end
        UpdateHiddenLines()
        UpdateHiddenLines(0)
        UpdateHiddenLines(0.5)
        UpdateHiddenLines(1.1)
        return
    elseif event == "GROUP_JOINED" then
        if hiddenLines then hiddenLines.GroupJoined(GroupSetupLines()) end
        UpdateHiddenLines()
        return
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        if systemFormatter.RefreshQueues then systemFormatter.RefreshQueues() end
        NameShownQueueLines()
        UpdateHiddenLines()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" and hiddenLines then
        hiddenLines.LeftBattleground()
    end
    if socialFormatter.NoteGroupRoster then
        socialFormatter.NoteGroupRoster(event == "PLAYER_ENTERING_WORLD")
    end
    UpdateHiddenLines()
end)

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("chatCleanerEnabled", {
        Enable = function()
            skillRankFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            skillRankFrame:RegisterEvent("SKILL_LINES_CHANGED")
            skillRankFrame:RegisterEvent("CHAT_MSG_SKILL")
            if systemFormatter.RefreshSkillRanks then
                systemFormatter.RefreshSkillRanks()
            end
            if socialFormatter.NoteGroupRoster then
                groupNoticeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
                groupNoticeFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
                groupNoticeFrame:RegisterEvent("UNIT_HEALTH")
                groupNoticeFrame:RegisterEvent("UNIT_FLAGS")
                groupNoticeFrame:RegisterEvent("CHAT_MSG_SYSTEM")
                groupNoticeFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
                groupNoticeFrame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
                groupNoticeFrame:RegisterEvent("GROUP_JOINED")
                groupNoticeFrame:RegisterEvent("PLAYER_DEAD")
                socialFormatter.NoteGroupRoster(true)
            end
            if systemFormatter.RefreshQueues then
                groupNoticeFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
                systemFormatter.RefreshQueues()
            end
        end,
        Disable = function()
            skillRankFrame:UnregisterAllEvents()
            groupNoticeFrame:UnregisterAllEvents()
        end,
    })
end
