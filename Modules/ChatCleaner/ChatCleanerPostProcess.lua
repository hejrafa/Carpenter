--[[ Carpenter - ChatCleaner AddMessage post-processing helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local PostProcess = ns.Private.ChatCleanerPostProcess or {}
ns.Private.ChatCleanerPostProcess = PostProcess

local Utils = ns.Private.ChatCleanerUtils
local Palette = Utils.Palette
local T, Trim, SpaceBeforeX = Utils.T, Utils.Trim, Utils.SpaceBeforeX

-- A repeat of a join or honor line within this long is the same one.
local JOIN_DEDUP_DELAY = 8
local HONOR_DELAY = 3
local IsRollPayload = ns.Private.ChatCleanerLoot.IsRollPayload
local RollTypeLabel = ns.Private.ChatCleanerLoot.RollTypeLabel
local IsSecret = Carpenter.Secret.IsSecret

-- Chat prefixes shortened: "[Party Leader]" to "PL", "[Raid Warning]" to a
-- red "!". The bracketed names come from the game's own strings.
local channelReplacements = {}
for _, entry in ipairs({
    { "CHAT_PARTY_LEADER_GET", "[PL]" }, { "CHAT_PARTY_GET", "[P]" },
    { "CHAT_RAID_LEADER_GET", "[RL]" }, { "CHAT_RAID_GET", "[R]" },
    { "CHAT_INSTANCE_CHAT_LEADER_GET", "[IL]" }, { "CHAT_INSTANCE_CHAT_GET", "[I]" },
    { "CHAT_GUILD_GET", "[G]" }, { "CHAT_OFFICER_GET", "[O]" },
    { "CHAT_RAID_WARNING_GET", "|cffff0000!|r" },
}) do
    local tag = _G[entry[1]]
    local label = type(tag) == "string" and tag:match("%[(.-)%]")
    if label and label ~= "" then
        table.insert(channelReplacements, { "%[" .. Utils.EscapePattern(label) .. "%]", entry[2] })
    end
end

-- A sender's AFK or DND flag ("<Away>", "<Busy>"), shown as "AFK" or "DND".
-- The game puts it right before the sender's player link. Chat Cleaner used
-- to set CHAT_FLAG_AFK and CHAT_FLAG_DND instead, but Blizzard's chat
-- formatter reads them before it edits the message, and on Retail and
-- Forever an edit of a hidden message from tainted code is an error.
local flagReplacements = {}
for globalName, short in pairs({ CHAT_FLAG_AFK = "AFK ", CHAT_FLAG_DND = "DND " }) do
    local flag = _G[globalName]
    if type(flag) == "string" and flag ~= "" then
        table.insert(flagReplacements, { Utils.EscapePattern(flag) .. "|Hplayer:", short .. "|Hplayer:" })
    end
end

local function ApplyChannelStyling(text)
    if not text or type(text) ~= "string" then return text end

    for _, entry in ipairs(flagReplacements) do
        text = text:gsub(entry[1], entry[2])
    end

    for _, entry in ipairs(channelReplacements) do
        text = text:gsub(entry[1], entry[2])
    end

    -- "[1. General - Mulgore]" becomes "1.".
    text = text:gsub("|Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%]|h", "|Hchannel:%1:%2|h%3.|h")
    -- Lines with no sender, like Local Defense's, read "3. : text". The colon was
    -- meant to follow the name, so it goes too.
    text = text:gsub("(|Hchannel:[^|]*|h%d+%.|h) : ", "%1 ")

    return text
end

-- The game's own honor lines, as their visible text reads once the chat filter has
-- styled them. Only these count: color codes hold digits too (the 8 in |cffc8c8c8),
-- and players and NPCs can mention honor points in chat. One gain can print both
-- kinds, a currency line and an award or kill line.
local HONOR_LINES = {
    { kind = "currency", pattern = "^%s*%+%s*Honor Points%s+x(%d+)" },                       -- + Honor Points x4
    { kind = "currency", pattern = "^%s*%+%s*Honor%s+x(%d+)" },                              -- + Honor x4
    { kind = "award", pattern = "^%s*%+%s*(%d+) Honor Points" },                             -- + 4 Honor Points, from "You have been awarded 4 Honor."
    { kind = "award", pattern = "^%s*You have been awarded (%d+) [Hh]onor" },                -- You have been awarded 4 Honor.
    { kind = "award", pattern = "^[^:]- dies %(Honorable Kill.-%)%. You gain (%d+) Honor" }, -- Foo dies (Honorable Kill: Private). You gain 4 Honor.
    { kind = "award", pattern = "^[^:]- dies, honorable kill.-Honor Points: (%d+)" },        -- Foo dies, honorable kill Rank: Private (Estimated Honor Points: 4)
    { kind = "award", pattern = "^[^:]- dies, honorable kill.-%((%d+) Honor Points" },       -- Foo dies, honorable kill (4 Honor Points, +2 Rested)
}

local function ParseHonorLine(plainText)
    for _, line in ipairs(HONOR_LINES) do
        local amount = plainText:match(line.pattern)
        if amount then return amount, line.kind end
    end
    return nil
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
    CHAT_MSG_SAY = { "SAY", "SAY" },
    CHAT_MSG_YELL = { "YELL", "YELL" },
    CHAT_MSG_EMOTE = { "EMOTE", "EMOTE" },
    CHAT_MSG_WHISPER = { "WHISPER", "WHISPER" },
    CHAT_MSG_WHISPER_INFORM = { "WHISPER_INFORM", "WHISPER" },
    CHAT_MSG_CHANNEL = { "CHANNEL", "CHANNEL" },
}

-- "[Orcish] " before words in a language other than yours, as the game
-- writes it: say and yell are measured against the language you speak to
-- everyone, the rest against your own. nil when the language is hidden.
local function LanguageHeader(chatType, language)
    if language == nil or language == "" then return "" end
    if IsSecret(language) or type(language) ~= "string" then return nil end
    local getDefault = (chatType == "SAY" or chatType == "YELL") and GetAlternativeDefaultLanguage or GetDefaultLanguage
    local ok, default = pcall(getDefault)
    if ok and language == default then return "" end
    return "[" .. language .. "] "
end

-- A channel line's number, as the post-processor shortens "[2. Trade]":
-- "2." linking to the channel. nil when the number is hidden.
local function ChannelTag(number)
    if IsSecret(number) or type(number) ~= "number" then return nil end
    return "|Hchannel:channel:" .. number .. "|h" .. number .. ".|h "
end

-- Where a chat sender's class comes from: their chat line, whose number
-- addons can always read, then their ID. In battlegrounds the game hides the
-- ID from addons, and the class it gives comes back hidden too.
local function ClassFromChatLine(lineID)
    return select(2, C_PlayerInfo.GetClass(PlayerLocation:CreateFromChatLineID(lineID)))
end

local function ClassFromUnitGUID(_, guid)
    return select(2, UnitClassFromGUID(guid))
end

local function ClassFromPlayerInfo(_, guid)
    return select(2, GetPlayerInfoByGUID(guid))
end

local CLASS_SOURCES = { ClassFromChatLine, ClassFromUnitGUID, ClassFromPlayerInfo }

-- A name in its class's color. A hidden class goes through the game's own
-- class color and color markup, which take hidden values from addons and
-- give back hidden text, as Class Colored Health colors its bars.
local function WrapInClassColor(name, source, lineID, guid)
    local classFile = source(lineID, guid)
    if IsSecret(classFile) then
        return C_ColorUtil.WrapTextInColor(name, C_ClassColor.GetClassColor(classFile))
    end
    local color = type(classFile) == "string" and Utils.ClassColorCode(classFile)
    if color then return color .. name .. "|r" end
end

-- A chat sender's name in their class color, whatever the game's chat
-- settings say: Chat Cleaner colors every sender, as it does names in loot
-- lines, and the game leaves names uncolored by default on Forever and the
-- classic clients. true and the name, or false when no source knows the
-- class. hiddenLine: the line is hidden already, so hidden text may join it.
local function ClassColoredSender(name, lineID, guid, hiddenLine)
    for _, source in ipairs(CLASS_SOURCES) do
        local ok, colored = pcall(WrapInClassColor, name, source, lineID, guid)
        if ok then
            if IsSecret(colored) then
                if hiddenLine then return true, colored end
            elseif type(colored) == "string" then
                return true, colored
            end
        end
    end
    return false
end

-- Sender links the game left uncolored, in the sender's class color. The
-- link names its chat line. A name the game colored already keeps its color.
local function ColorSenderNames(text)
    return (text:gsub("(|Hplayer:[^:|]*:(%d+)[^|]*|h)([^|]+)|h", function(link, lineID, name)
        lineID = tonumber(lineID)
        local chatInfo, guid = C_ChatInfo, nil
        if chatInfo and chatInfo.GetChatLineSenderGUID then
            local ok, value = pcall(chatInfo.GetChatLineSenderGUID, lineID)
            if ok then guid = value end
        end
        local found, colored = ClassColoredSender(name, lineID, guid, false)
        if found then return link .. colored .. "|h" end
    end))
end

-- The sender as the game shows them: the short name (the realm left out
-- where the game would) in its class color. The name stays hidden; it is
-- only joined into the line.
local function HiddenSenderName(chatType, args)
    local name = args[2]
    local ok, short = pcall(Ambiguate, name, chatType == "GUILD" and "guild" or "none")
    if ok and short then name = short end
    local found, colored = ClassColoredSender(name, args[11], args[12], true)
    if found then return colored end
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

function PostProcess.Create(config)
    config = config or {}
    local applyChannelStyling = ApplyChannelStyling
    local formatLevelUpRewardMessage = config.FormatLevelUpRewardMessage or function() return nil end
    local formatAppearanceCollectionMessage = config.FormatAppearanceCollectionMessage or function() return nil end
    local getPlayerNameColor = config.GetPlayerNameColor or function() return nil end

    -- Each chat window gets its own copy of a line, so repeats are told apart
    -- per window.
    local lastHonorByFrame = setmetatable({}, { __mode = "k" })
    local lastJoinByFrame = setmetatable({}, { __mode = "k" })

    local api = {}

    -- For the first minute of a battleground, Blizzard collects joins and
    -- leaves and prints them as one line straight to the chat frame, so no
    -- chat filter ever sees them.
    local function FormatBattleRosterLine(plain)
        local joinedList = plain:match("^%s*%d+%s+players have joined the battle:%s*(.-)%.?%s*$")
        if joinedList and Trim(joinedList) ~= "" then
            return Palette.green .. T("CHAT_PLAYER_JOINED", Trim(joinedList)) .. "|r"
        end
        local leftList = plain:match("^%s*%d+%s+players have left the battle:%s*(.-)%.?%s*$")
        if leftList and Trim(leftList) ~= "" then
            return Palette.red .. T("CHAT_PLAYER_LEFT", Trim(leftList)) .. "|r"
        end
        local joinedCount = plain:match("^%s*(%d+)%s+players have joined the battle%.?%s*$")
        if joinedCount then
            return Palette.green .. T("CHAT_PLAYERS_JOINED", joinedCount) .. "|r"
        end
        local leftCount = plain:match("^%s*(%d+)%s+players have left the battle%.?%s*$")
        if leftCount then
            return Palette.red .. T("CHAT_PLAYERS_LEFT", leftCount) .. "|r"
        end
        local joinedName = plain:match("^%s*(.-)%s+has joined the battle%.?%s*$")
        if joinedName and Trim(joinedName) ~= "" then
            return Palette.green .. T("CHAT_PLAYER_JOINED", Trim(joinedName)) .. "|r"
        end
        local leftName = plain:match("^%s*(.-)%s+has left the battle%.?%s*$")
        if leftName and Trim(leftName) ~= "" then
            return Palette.red .. T("CHAT_PLAYER_LEFT", Trim(leftName)) .. "|r"
        end
        return nil
    end

    local function StyleBareLootItem(item)
        if not item or item == "" or item:find("|Hitem:", 1, true) then return item end
        return Palette.green .. item .. "|r"
    end

    local function StyledLootName(name)
        name = Trim(name):gsub("^Loot:%s*", ""):gsub("^[:;]+%s*", ""):gsub("%-.*$", "")
        if name == "" or name == "Loot" then return nil end
        if name == "You" then
            return Palette.white .. T("CHAT_YOU") .. "|r"
        end
        return Palette.white .. name .. "|r"
    end

    local function Literal(text)
        if text and type(text) == "string" then
            text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*:%s*$", "")
        end
        if not text or text == "" then return "" end
        return Palette.white .. text .. "|r"
    end

    local function FormatDirectLootWin(text)
        if not text or type(text) ~= "string" then return nil end

        local prefix = text:match("^(.-)[Ll]oot:%s*.-%s+[Ww]on:%s*.+$")
        local name, item = text:match("[Ll]oot:%s*(.-)%s+[Ww]on:%s*(.+)$")
        if not name or not item then return nil end

        local nameOut = StyledLootName(name)
        if not nameOut then return nil end

        item = Trim(item):gsub("%s+[Ll]oot%s*$", "")
        if item == "" then return nil end

        return (prefix or "") .. nameOut .. " " .. Literal(T("CHAT_WON_LABEL")) .. " " .. item
    end

    local function HasChatChannelPrefix(plainText)
        if not plainText or type(plainText) ~= "string" then return false end
        return plainText:match("^%s*[PGROI!][%s:][^:]+:") ~= nil
            or plainText:match("^%s*%d+%.[^:]+:") ~= nil
    end

    local function ExtractBareLootItem(text)
        if not text or type(text) ~= "string" then return nil end

        return text:match("^%s*[Ll]oot:%s*(.+)$") or
            text:match("^%s*|c%x%x%x%x%x%x%x%x[Ll]oot:%s*|r%s*(.+)$") or
            text:match("^%s*|c%x%x%x%x%x%x%x%x[Ll]oot|r:%s*(.+)$") or
            text:match("^%s*|c%x%x%x%x%x%x%x%x[Ll]oot:%s*(.+)|r%s*$") or
            Utils.StripColorsAndLinks(text):match("^%s*[Ll]oot:%s*(.+)$")
    end

    local function FormatBareLoot(text)
        if not text or type(text) ~= "string" then return nil end

        local item = ExtractBareLootItem(text)
        if not item or IsRollPayload(Utils.StripColorsAndLinks(item)) then return nil end

        item = Trim(item):gsub("%.+$", "")
        if item == "" then return nil end

        local lootLabelColor = Utils.LootLineColor("CHAT_MSG_LOOT")
        return lootLabelColor .. "Loot|r " .. Utils.PREFIX_PLUS .. StyleBareLootItem(item)
    end

    local function FormatHardcoreDeathMessage(plainText)
        if not plainText or type(plainText) ~= "string" then return nil end

        local text = plainText:gsub("^%s*%d+%.:?%s*", ""):gsub("^%s*:%s*", "")
        local playerName, cause, level = text:match("^%s*(%S+)%s+(.+)%!%s*[Tt]hey were level%s+(%d+)%s*%.?%s*$")
        if not playerName or playerName == "" or not level then return nil end

        local lowerCause = cause:lower()
        local causeLabel = nil
        if lowerCause:find("drowned to death", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_DROWNED")
        elseif lowerCause:find("fell to death", 1, true) or
            lowerCause:find("fell to their death", 1, true) or
            lowerCause:find("fell to his death", 1, true) or
            lowerCause:find("fell to her death", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_FELL")
        elseif lowerCause:find("burned to death", 1, true) or
            lowerCause:find("burnt to death", 1, true) or
            lowerCause:find("burned to a crisp", 1, true) or
            lowerCause:find("burnt to a crisp", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_BURNED")
        elseif lowerCause:find("died from fatigue", 1, true) or
            lowerCause:find("died to fatigue", 1, true) or
            lowerCause:find("died of fatigue", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_FATIGUE")
        elseif lowerCause:find("has been slain", 1, true) or lowerCause:find("was slain", 1, true) then
            local killer = cause:match("[Hh]as been slain by%s+(.+)$") or cause:match("[Ww]as slain by%s+(.+)$")
            if killer then
                killer = Trim(killer):gsub("%s+in%s+.+$", "")
            end
            causeLabel = killer and killer ~= "" and T("CHAT_HARDCORE_DEATH_SLAIN_BY", killer) or T("CHAT_HARDCORE_DEATH_SLAIN")
        elseif lowerCause:find("was killed", 1, true) or lowerCause:find("died to", 1, true) or
            lowerCause:find("died from", 1, true) or lowerCause:find("died in", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_DIED")
        end
        if not causeLabel then return nil end

        playerName = Trim(playerName):gsub("%-.*$", "")
        if playerName == "" then return nil end

        return Palette.red .. T("CHAT_HARDCORE_DEATH", playerName, causeLabel, level) .. "|r"
    end

    -- Rollers get their class color, like names in say and party chat.
    local function RollNameColor(name)
        return getPlayerNameColor(name) or Palette.white
    end

    local function StyleLootRollNames(text)
        if not text or type(text) ~= "string" then return text end

        local plain = Utils.StripColorsAndLinks(text):gsub("%s+", " ")
        local lower = plain:lower()
        local isLootRoll = lower:find("has selected") or lower:find("passed on") or lower:find(" won ") or lower:find(" won:") or lower:find(" wins ") or
            plain:find(" by .+%s*$") or lower:find("won by ") or lower:find("winner:") or
            lower:find("receives loot") or lower:find("receives item") or lower:find(" creates:") or lower:find(" rolls ") or lower:find(" roll ")
        if not isLootRoll then return text end

        text = text:gsub("^%s*[Ll]oot%s*:?%s*", "")
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)[Ll]oot%s*:?%s*", "%1")
        text = text:gsub("(%])%s*[Ll]oot%s*:?%s*", "%1 ")
        text = text:gsub("(%])|r%s*[Ll]oot%s*:?%s*", "%1|r ")
        text = text:gsub("(|r)%s*[Ll]oot%s*:?%s*", "%1 ")
        text = text:gsub("(%s+has selected %w+)%s+for%s*:%s*", "%1: ")
        text = text:gsub("%s+[Ll]oot%s*$", "")

        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives loot:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. Palette.white .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives item:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. Palette.white .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+creates:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. Palette.white .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(.-)%s+has selected%s+(%w+)%s*:%s*(.+)$", function(name, typeWord, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            local roll = RollTypeLabel(typeWord)
            if short ~= "" and short ~= "Loot" and roll then
                return Palette.white .. short .. "|r " .. Literal(roll) .. " " .. item
            end
        end)
        text = text:gsub("^(.-)%s+passed on[:%s]+(.+)$", function(name, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                return Palette.white .. short .. "|r " .. Literal(T("CHAT_PASSED_LABEL")) .. " " .. item
            end
            return name .. " passed: " .. item
        end)
        text = text:gsub("^(.-)%s+[Ww]on:%s*(.+)$", function(name, item)
            local nameOut = StyledLootName(name)
            if nameOut then
                return nameOut .. " " .. Literal(T("CHAT_WON_LABEL")) .. " " .. item
            end
            return name .. " won: " .. item
        end)
        text = text:gsub("^(.-)%s+(rolls?)%s+(%d+)%s*:%s*(.+)$", function(name, rollWord, rollNumber, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return Palette.white .. T("CHAT_YOU") .. "|r " .. Literal(T("CHAT_ROLL_LABEL", rollNumber)) .. " " .. item
                end
                return RollNameColor(short) .. short .. "|r " .. Literal(rollWord .. " " .. rollNumber .. ":") .. " " .. item
            end
            return name .. " " .. rollWord .. " " .. rollNumber .. ": " .. item
        end)
        text = text:gsub("^(.-)%s+(rolls?)%s+(%d+)%s+(%(%d+%-%d+%))%s*$", function(name, rollWord, rollNumber, rangeText)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return Palette.white .. T("CHAT_YOU") .. "|r " .. Literal("roll " .. rollNumber .. " " .. rangeText)
                end
                return RollNameColor(short) .. short .. "|r " .. Literal(rollWord .. " " .. rollNumber .. " " .. rangeText)
            end
            return name .. " " .. rollWord .. " " .. rollNumber .. " " .. rangeText
        end)
        text = text:gsub("^(.-)%s+(rolls?)%s+(%d+)%s*$", function(name, rollWord, rollNumber)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return Palette.white .. T("CHAT_YOU") .. "|r " .. Literal("roll " .. rollNumber)
                end
                return RollNameColor(short) .. short .. "|r " .. Literal(rollWord .. " " .. rollNumber)
            end
            return name .. " " .. rollWord .. " " .. rollNumber
        end)

        return text
    end

    local function Unpack(args)
        return unpack(args, 1, args.n or #args)
    end

    -- Chat type ids of players' chat, where only the prefix, brackets,
    -- AFK/DND flag and the sender's class color are restyled: a player's
    -- words and emotes are never loot or roll lines. Read on first use, once
    -- the chat frames have set the ids.
    local PLAYER_CHAT_TYPES = {
        "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM",
        "GUILD", "OFFICER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
        "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
    }
    local playerChatTypeIDs
    local function IsPlayerChatLine(args)
        local typeID = args and args[4]
        if typeID == nil or IsSecret(typeID) or not ChatTypeInfo then return false end
        if not playerChatTypeIDs then
            playerChatTypeIDs = {}
            local function Add(info)
                if info and info.id ~= nil then playerChatTypeIDs[info.id] = true end
            end
            for _, chatType in ipairs(PLAYER_CHAT_TYPES) do Add(ChatTypeInfo[chatType]) end
            for index = 1, 20 do Add(ChatTypeInfo["CHANNEL" .. index]) end
        end
        return playerChatTypeIDs[typeID] == true
    end

    -- keepLine: the line is already in the chat frame and can only be restyled,
    -- so lines that would be dropped are kept as they are. args are the rest
    -- of AddMessage's values, packed with their count in n.
    function api.ProcessMessage(frame, originalAddMessage, message, args, keepLine)
        message = applyChannelStyling(tostring(message))
        message = Utils.RemoveLinkBrackets(message)
        if IsPlayerChatLine(args) then
            return originalAddMessage(frame, ColorSenderNames(message), Unpack(args))
        end

        local plain = Utils.StripColorsAndLinks(message)
        local appearanceCollectionMessage = formatAppearanceCollectionMessage("CHAT_MSG_SYSTEM", message, plain)
        if appearanceCollectionMessage then
            return originalAddMessage(frame, appearanceCollectionMessage, Unpack(args))
        end

        local directLootWin = FormatDirectLootWin(message)
        if directLootWin then
            return originalAddMessage(frame, directLootWin, Unpack(args))
        end

        message = StyleLootRollNames(message)

        plain = Utils.StripColorsAndLinks(message)
        local bareLootMessage = FormatBareLoot(message)
        if bareLootMessage then
            return originalAddMessage(frame, bareLootMessage, Unpack(args))
        end

        local hardcoreDeathMessage = FormatHardcoreDeathMessage(plain)
        if hardcoreDeathMessage then
            return originalAddMessage(frame, hardcoreDeathMessage, Unpack(args))
        end

        if not HasChatChannelPrefix(plain) then
            local styledLevelReward = formatLevelUpRewardMessage(plain)
            if styledLevelReward then
                return originalAddMessage(frame, styledLevelReward, Unpack(args))
            end
        end

        -- Blizzard's money receipt after a merchant or mailbox ("You gained:"),
        -- which repeats Chat Cleaner's own money lines, and other lines that are
        -- always hidden. A line already in the chat frame can't be removed
        -- without tainting it, so it is emptied instead.
        if Utils.ParseRetailMoneyGain(plain) or plain:find("^Changed Channel:") or plain:find("^Left Channel:") or plain:find("^Auctionator:") then
            if keepLine then
                return originalAddMessage(frame, "", Unpack(args))
            end
            return
        end

        -- The same join twice in a row ("X has joined the battle." then
        -- "X joined") shows once.
        local joinPlayers = plain:match("^(%d+)%s+players joined%s*$")
        local joinName = plain:match("^%s*(.-)%s+has joined the battle%.?%s*$") or
            (not plain:find("has joined the battle", 1, true) and plain:match("^%s*(.-)%s+joined%s*$"))
        local joinKey = joinPlayers and ("players:" .. joinPlayers) or (joinName and joinName ~= "" and joinName:lower())
        if joinKey then
            local last = lastJoinByFrame[frame]
            if not keepLine and last and last.key == joinKey and (GetTime() - last.time) < JOIN_DEDUP_DELAY then
                return
            end
            lastJoinByFrame[frame] = { key = joinKey, time = GetTime() }
        end

        local rosterLine = FormatBattleRosterLine(plain)
        if rosterLine then
            return originalAddMessage(frame, rosterLine, Unpack(args))
        end

        local honor, honorKind = ParseHonorLine(plain)
        if honor then
            -- The other kind of line with the same amount right after is the same
            -- gain. Two lines of one kind are two gains, and each chat frame gets
            -- its own copy of the lines.
            local last = lastHonorByFrame[frame]
            if not keepLine and last and last.kind ~= honorKind and last.amount == honor and (GetTime() - last.time) < HONOR_DELAY then
                lastHonorByFrame[frame] = nil
                return
            end
            lastHonorByFrame[frame] = { kind = honorKind, amount = honor, time = GetTime() }
            local styled = SpaceBeforeX(Utils.PREFIX_PLUS .. Palette.white .. honor .. " " .. T("CHAT_HONOR_POINTS") .. "|r")
            return originalAddMessage(frame, styled, Unpack(args))
        end

        return originalAddMessage(frame, message, Unpack(args))
    end

    -- What the post-processor would print for a line: the new text, or
    -- nothing when the line should go.
    local function ResolveMessage(frame, message, args, keepLine)
        local added, result = false, nil
        api.ProcessMessage(frame, function(_, text)
            added, result = true, text
        end, message, args, keepLine)
        return added, result
    end

    -- Blizzard's own code calls AddMessage and keeps running afterwards; the
    -- battleground join batching clears its list of hidden player names right
    -- after printing. If that code is tainted it errors every frame, and the
    -- same line prints again and again.
    --
    -- A replaced AddMessage taints it directly. Removing a line taints it too:
    -- RemoveMessagesByPredicate rebuilds the chat history after reading the
    -- addon's answer, so the history's index ends up tainted, and every later
    -- AddMessage reads it. Restyling a line only touches the line itself.
    --
    -- So where the chat frame offers Blizzard's secure line edits, lines are
    -- restyled after they are added, and lines that should go are dropped by
    -- the chat filter before they are added.
    local function CanEditAfterAdd(frame)
        return Carpenter.Secret.ClientHidesValues()
            and hooksecurefunc ~= nil
            and type(frame.AddMessage) == "function"
            and type(frame.TransformMessages) == "function"
    end

    local function EditsAfterAdd(frame)
        return frame ~= nil and frame._CP_AddMessagePostHooked == true and frame._CP_AddMessageHooked == true
            and Carpenter:IsEnabled("chatCleanerEnabled")
    end

    -- Lines without a sender, which the chat frame prints as they are.
    local DROP_BEFORE_ADD_EVENTS = {
        CHAT_MSG_SYSTEM = true,
        CHAT_MSG_BG_SYSTEM_ALLIANCE = true,
        CHAT_MSG_BG_SYSTEM_HORDE = true,
        CHAT_MSG_BG_SYSTEM_NEUTRAL = true,
        CHAT_MSG_COMBAT_HONOR_GAIN = true,
        CHAT_MSG_COMBAT_XP_GAIN = true,
        CHAT_MSG_COMBAT_MISC_INFO = true,
        CHAT_MSG_CURRENCY = true,
        CHAT_MSG_MONEY = true,
        CHAT_MSG_LOOT = true,
    }

    -- Called by the chat filter with the line it is about to let through:
    -- true when the post-processor would drop it (a repeated honor gain or
    -- join, for example).
    function api.ShouldDropBeforeAdd(frame, event, text)
        if not DROP_BEFORE_ADD_EVENTS[event] or not EditsAfterAdd(frame) then return false end
        if type(text) ~= "string" or IsSecret(text) then return false end
        local added = ResolveMessage(frame, text, {}, false)
        return not added
    end

    -- "Changed Channel" and "Left Channel" lines. Blizzard updates the chat
    -- frame's channel list for a departure only when it prints the line, but
    -- leaving a stale name in that list is harmless.
    function api.ShouldDropChannelNotice(frame, notice)
        if not EditsAfterAdd(frame) or IsSecret(notice) then return false end
        return notice == "YOU_CHANGED" or notice == "YOU_LEFT"
    end

    local function IsSameLine(text, original)
        return not IsSecret(text) and text == original
    end

    local function ReplaceLine(frame, original, replacement)
        frame:TransformMessages(function(text)
            return IsSameLine(text, original)
        end, function(_, ...)
            return replacement, ...
        end)
    end

    local function EditAddedLine(frame, message, ...)
        local added, result = ResolveMessage(frame, message, { n = select("#", ...), ... }, true)
        if added and result ~= message then
            ReplaceLine(frame, message, result)
        end
    end

    -- Lines whose text the game hides go to ChatCleanerHiddenLines.
    local hiddenLineHandler
    -- A chat line's prefix format, such as "|Hchannel:GUILD|h[Guild]|h %s: ",
    -- styled as the post-processor styles the line: "|Hchannel:GUILD|hG|h %s: ".
    function api.StyleChatPrefix(format)
        if type(format) ~= "string" then return nil end
        return (Utils.RemoveLinkBrackets(applyChannelStyling(format)))
    end

    function api.SetHiddenLineHandler(handler)
        hiddenLineHandler = handler
    end

    local function BuildHiddenChat(event, args)
        local types = HIDDEN_CHAT_TYPES[event]
        if not types or type(args) ~= "table" then return nil end
        local chatType = types[1]
        local prefix = api.StyleChatPrefix(_G["CHAT_" .. chatType .. "_GET"])
        local message, author, lineID = args[1], args[2], args[11]
        -- A hidden language leaves out the header, except in say and yell,
        -- where the other faction speaks its own: those lines stay as written.
        local language = LanguageHeader(chatType, args[3])
        if not language and chatType ~= "SAY" and chatType ~= "YELL" then language = "" end
        local channel = ""
        if chatType == "CHANNEL" then
            channel = ChannelTag(args[8])
            -- Each channel has its own chat settings, class colors included.
            chatType = channel and "CHANNEL" .. args[8]
        end
        if not (prefix and message and author and language and channel) then return nil end
        local link = "|Hplayer:" .. author .. ":" .. (lineID or 0) .. ":" .. types[2] .. "|h"
            .. HiddenSenderName(chatType, args) .. "|h"
        return ChatTimestamp() .. channel .. string.format(prefix, link) .. language .. message
    end

    function api.IsHiddenChatEvent(event)
        return HIDDEN_CHAT_TYPES[event] ~= nil
    end

    -- A hidden party, raid, guild or instance chat line rebuilt, or nil.
    function api.FormatHiddenChat(event, args)
        local ok, text = pcall(BuildHiddenChat, event, args)
        if ok then return text end
    end

    local function OnLineAdded(frame, message, ...)
        if not frame._CP_AddMessageHooked then return end
        if not Carpenter:IsEnabled("chatCleanerEnabled") then return end
        if IsSecret(message) then
            if hiddenLineHandler then pcall(hiddenLineHandler, frame) end
            return
        end
        if type(message) ~= "string" then return end

        pcall(Carpenter.Profile, Carpenter, "ChatCleaner:AddMessage", EditAddedLine, frame, message, ...)
    end

    function api.HookChatFrameAddMessage(frame)
        if not frame or frame._CP_AddMessageHooked then return end
        if frame._CP_AddMessagePostHooked or CanEditAfterAdd(frame) then
            if not frame._CP_AddMessagePostHooked then
                if not pcall(hooksecurefunc, frame, "AddMessage", OnLineAdded) then return end
                frame._CP_AddMessagePostHooked = true
            end
            frame._CP_AddMessageHooked = true
            return
        end

        local originalAddMessage = frame._CP_OriginalAddMessage or frame.AddMessage
        if not originalAddMessage then return end
        frame._CP_OriginalAddMessage = originalAddMessage

        frame.AddMessage = function(self, message, ...)
            if not Carpenter:IsEnabled("chatCleanerEnabled") then
                return originalAddMessage(self, message, ...)
            end

            local args = { n = select("#", ...), ... }
            local ok = pcall(Carpenter.Profile, Carpenter, "ChatCleaner:AddMessage", api.ProcessMessage, self,
                originalAddMessage, message, args)
            if not ok then
                originalAddMessage(self, message, Unpack(args))
            end
        end
        frame._CP_AddMessageHooked = true
    end

    function api.RestoreChatFrameAddMessage(frame)
        if not frame or not frame._CP_AddMessageHooked then return end
        -- A secure hook can't be removed; it goes quiet instead.
        if frame._CP_AddMessagePostHooked then
            frame._CP_AddMessageHooked = false
            return
        end
        if not frame._CP_OriginalAddMessage then return end
        frame.AddMessage = frame._CP_OriginalAddMessage
        frame._CP_AddMessageHooked = false
    end

    return api
end
