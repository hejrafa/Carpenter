--[[ Carpenter - ChatCleaner ]]
local _, ns = ...
local L = (Carpenter and Carpenter.L) or (ns and ns.L) or {}

-- Shared Carpenter color palette
local Colors = ns and ns.Private and ns.Private.Colors

-- Muted tones: light grey chrome; soft off-whites and subtle tints so chat isn’t flat or harsh
-- Goldpaw ChatCleaner-style (github.com/GoldpawsStuff/ChatCleaner): gray +/-, offwhite names, white amounts, yellow quest, green cleared, palered losses
local ColorGray       = Colors and Colors.gray and Colors.gray.colorCode or "|cffc8c8c8"
local ColorPlus       = ColorGray
local ColorMinus      = ColorGray

local ColorOffwhite   = Colors and Colors.offwhite and Colors.offwhite.colorCode or "|cfff0f0f0"
local ColorWhite      = Colors and Colors.white and Colors.white.colorCode or "|cffffffff"
local ColorLootLiteral= ColorWhite
local ColorYellow     = "|cffffd200"
local ColorGreen      = Colors and Colors.green and Colors.green.colorCode or "|cff00ff00"
local ColorOrange     = Colors and Colors.quest and Colors.quest.orange and Colors.quest.orange.colorCode or "|cffff8000"
local ColorDarkorange = Colors and Colors.quest and Colors.quest.red and Colors.quest.red.colorCode or "|cffff6600"
local ColorPalered    = Colors and Colors.palered and Colors.palered.colorCode or "|cffcc8080"
local ColorRed        = Colors and Colors.red and Colors.red.colorCode or "|cffff4040"

-- Accent colors
local ColorPurple     = Colors and Colors.xpValue and Colors.xpValue.colorCode or "|cffb794f4"         -- Skill / spell names
local ColorBluePurple = Colors and Colors.faction and Colors.faction.Alliance and Colors.faction.Alliance.colorCode or "|cff9d8cff" -- Reputation faction
local ColorTeal       = Colors and Colors.power and Colors.power.ESSENCE and Colors.power.ESSENCE.colorCode or "|cff00ccaa"        -- Discovery zone
local ColorQueue      = Colors and Colors.zone and Colors.zone.sanctuary and Colors.zone.sanctuary.colorCode or "|cff80b0ff"       -- BG / queue name
local ColorCyan       = Colors and Colors.power and Colors.power.MANA and Colors.power.MANA.colorCode or "|cff00ccff"              -- Generic rewards
local ColorHonor      = Colors and Colors.red and Colors.red.colorCode or "|cffff4040"
local ColorAuctionExpired = ColorRed
local ColorSold           = ColorGray
local ColorAuctionHouse   = "|cffffb347"   -- Amber for buyer found, auction created
local ColorRepair         = ColorGray

-- Same tones as shared XP colors
local ColorRestedBar = Colors and Colors.restedValue and Colors.restedValue.colorCode or "|cff3399ff"
local ColorNormalBar = Colors and Colors.xpValue and Colors.xpValue.colorCode or "|cff9940ff"

-- Money Icons
local GoldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
local ChatCleanerUtils = ns and ns.Private and ns.Private.ChatCleanerUtils or {}
local ParseRetailMoneyGain = ChatCleanerUtils.ParseRetailMoneyGain
local StripBrackets = ChatCleanerUtils.StripBrackets
local CleanPunctuation = ChatCleanerUtils.CleanPunctuation
local SpaceBeforeX = ChatCleanerUtils.SpaceBeforeX
local RemoveLinkBrackets = ChatCleanerUtils.RemoveLinkBrackets
local GetItemLinkFromMessage = ChatCleanerUtils.GetItemLinkFromMessage
local ChatCleanerLoot = ns and ns.Private and ns.Private.ChatCleanerLoot or {}
local ChatCleanerSessions = ns and ns.Private and ns.Private.ChatCleanerSessions or {}
local ChatCleanerSystem = ns and ns.Private and ns.Private.ChatCleanerSystem or {}
local ChatCleanerRewards = ns and ns.Private and ns.Private.ChatCleanerRewards or {}
local ChatCleanerSocial = ns and ns.Private and ns.Private.ChatCleanerSocial or {}
local ChatCleanerPostProcess = ns and ns.Private and ns.Private.ChatCleanerPostProcess or {}
local ChatCleanerLifecycle = ns and ns.Private and ns.Private.ChatCleanerLifecycle or {}

local moneyIcons = {
    Gold = GoldIcon,
    Silver = silverIcon,
    Copper = copperIcon,
}

local function FormatMoney(amount, amountColor)
    return ChatCleanerUtils.FormatMoney(amount, amountColor or ColorWhite, moneyIcons)
end

local GetItemLinkWithQualityColor = ChatCleanerUtils.GetItemLinkWithQualityColor or function(itemLink) return itemLink end
local ShouldSkipGenericReceive = ChatCleanerUtils.ShouldSkipGenericReceive or function() return true end

local function FormatItemCountSuffix(text)
    return ChatCleanerUtils.FormatItemCountSuffix(text, ColorPlus)
end

local function FormatReceivedDisplay(rawDisplay, sourceMessage)
    return ChatCleanerUtils.FormatReceivedDisplay(rawDisplay, sourceMessage, { CountColor = ColorPlus })
end

-- Blizzard party/raid message color (for system messages like "X joins", "Group leader")
local function GetPartyOrRaidMessageColor()
    local info = ChatTypeInfo["RAID"] or ChatTypeInfo["PARTY"]
    if not info then
        return ColorOffwhite
    end
    if IsInRaid() then
        info = ChatTypeInfo["RAID"]
    else
        info = ChatTypeInfo["PARTY"]
    end
    if not info or not info.r then
        return ColorOffwhite
    end
    local r = math.floor((info.r or 1) * 255)
    local g = math.floor((info.g or 1) * 255)
    local b = math.floor((info.b or 1) * 255)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local function GetChannelMessageColor(event)
    local chatTypeByEvent = {
        CHAT_MSG_PARTY = "PARTY",
        CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
        CHAT_MSG_RAID = "RAID",
        CHAT_MSG_RAID_LEADER = "RAID_LEADER",
    }
    local chatType = chatTypeByEvent[event]
    if not chatType and (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM") and GetNumGroupMembers and GetNumGroupMembers() > 0 then
        chatType = IsInRaid and IsInRaid() and "RAID" or "PARTY"
    end
    local info = chatType and ChatTypeInfo and ChatTypeInfo[chatType]
    if not info or not info.r then return ColorLootLiteral end

    local r = math.floor((info.r or 1) * 255)
    local g = math.floor((info.g or 1) * 255)
    local b = math.floor((info.b or 1) * 255)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local GroupLootPatterns = ChatCleanerLoot.BuildGroupLootPatterns and ChatCleanerLoot.BuildGroupLootPatterns() or {}
local RollPatterns = ChatCleanerLoot.BuildRollPatterns and ChatCleanerLoot.BuildRollPatterns() or {}
local RollPatternsFallback = ChatCleanerLoot.RollPatternsFallback or {}
local lootFormatter = ChatCleanerLoot.Create and ChatCleanerLoot.Create({
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
    RollPatternsFallback = RollPatternsFallback,
    ColorPlus = ColorPlus,
    ColorLootLiteral = ColorLootLiteral,
    ColorGreen = ColorGreen,
    GetChannelMessageColor = GetChannelMessageColor,
}) or {}
local FormatSelfLootMessage = lootFormatter.FormatSelfLootMessage
local FormatGroupLootMessage = lootFormatter.FormatGroupLootMessage
local FormatLootRollMessage = lootFormatter.FormatLootRollMessage

local sessionTracker = ChatCleanerSessions.Create and ChatCleanerSessions.Create({
    FormatMoney = FormatMoney,
    ColorPlus = ColorPlus,
    ColorMinus = ColorMinus,
}) or {}
local merchantFrame = sessionTracker.merchantFrame or {}
local mailTracker = sessionTracker.mailTracker or {}


local systemFormatter = ChatCleanerSystem.Create and ChatCleanerSystem.Create({
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
    ColorTeal = ColorTeal,
    ColorYellow = ColorYellow,
    LearnedSkillDedupSeconds = 3,
}) or {}
local IsLevelUpRewardEvent = systemFormatter.IsLevelUpRewardEvent
local FormatExperienceMessage = systemFormatter.FormatExperienceMessage
local FormatQuestProgressMessage = systemFormatter.FormatQuestProgressMessage
local FormatLevelUpRewardMessage = systemFormatter.FormatLevelUpRewardMessage
local FormatReputationMessage = systemFormatter.FormatReputationMessage
local FormatQueueNotice = systemFormatter.FormatQueueNotice
local FormatSkillMessage = systemFormatter.FormatSkillMessage
local ApplyLevelUpGlobalStringStyling = systemFormatter.ApplyLevelUpGlobalStringStyling

local rewardFormatter = ChatCleanerRewards.Create and ChatCleanerRewards.Create({
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
    ColorHonor = ColorHonor,
    ColorPalered = ColorPalered,
    ColorMinus = ColorMinus,
    ColorAuctionHouse = ColorAuctionHouse,
    ColorAuctionExpired = ColorAuctionExpired,
    MerchantFrame = merchantFrame,
    MailTracker = mailTracker,
    RepairDedupSeconds = 2,
}) or {}
local FormatCurrencyMessage = rewardFormatter.FormatCurrencyMessage
local FormatLootShareMoney = rewardFormatter.FormatLootShareMoney
local FormatMoneyMessage = rewardFormatter.FormatMoneyMessage
local FormatQuestMoneyReward = rewardFormatter.FormatQuestMoneyReward
local FormatAuctionMessage = rewardFormatter.FormatAuctionMessage
local FormatRefundDisplay = rewardFormatter.FormatRefundDisplay
local FormatGenericReward = rewardFormatter.FormatGenericReward

local socialFormatter = ChatCleanerSocial.Create and ChatCleanerSocial.Create({
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
}) or {}
local FormatBattlegroundAndGroupNotice = socialFormatter.FormatBattlegroundAndGroupNotice
local FormatSystemSocialMessage = socialFormatter.FormatSystemSocialMessage

local postProcessor = ChatCleanerPostProcess.Create and ChatCleanerPostProcess.Create({
    L = L,
    RemoveLinkBrackets = RemoveLinkBrackets,
    FormatLevelUpRewardMessage = FormatLevelUpRewardMessage,
    ParseRetailMoneyGain = ParseRetailMoneyGain,
    SpaceBeforeX = SpaceBeforeX,
    ColorPlus = ColorPlus,
    ColorLootLiteral = ColorLootLiteral,
    ColorGreen = ColorGreen,
    GetChannelMessageColor = GetChannelMessageColor,
    ColorRed = ColorRed,
    HonorDelay = 3,
    JoinDedupDelay = 8,
}) or {}
local HookChatFrameAddMessage = postProcessor.HookChatFrameAddMessage

local function ChatFilterImpl(self, event, msg, author, ...)
    if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then
        return false, msg, author, ...
    end

    -- Monster emotes: some locales/strings use format placeholders like "%s" or "%o"
    -- and Blizzard's MessageFormatter later calls string.format with extra args
    -- (player/mob links). That combination can throw "bad argument #2 to 'format'"
    -- if a numeric placeholder like %o is paired with a string argument.
    --
    -- For monster emotes, substitute the monster's name into any %s/%o-style
    -- placeholders ourselves, then escape remaining '%' so Blizzard's formatter
    -- sees a plain string and never interprets them as format codes.
    if event == "CHAT_MSG_MONSTER_EMOTE" and type(msg) == "string" then
        local name = author
        if not name or name == "" then
            name = select(1, ...) or ""
        end
        if name ~= "" then
            -- Replace common string/ordinal placeholders with the monster name
            msg = msg:gsub("%%[sSoO]", name)
        end
        -- Neutralize any remaining '%' so later string.format calls are safe
        msg = msg:gsub("%%", "%%%%")
    end

    -- Hide noisy "Changed Channel" notifications now that prefixes are compact
    if type(msg) == "string" and msg:find("^Changed Channel:") then
        return true
    end
    -- Hide "Left Channel: 1." / "Left Channel: 2." etc.
    if type(msg) == "string" and msg:find("^Left Channel:") then
        return true
    end

    -- Hide all Auctionator addon messages (they start with "Auctionator:")
    if type(msg) == "string" and (msg:find("^Auctionator:") or msg:find("^|c%x%x%x%x%x%x%x%x%xAuctionator:")) then
        return true
    end

    local prefixPlus = ColorPlus .. "+|r "
    local prefixMinus = ColorMinus .. "-|r "

    -- Early detection: Suppress loot messages that come through as CHAT_MSG_YELL
    -- Only process if the message ALREADY contains loot patterns - don't add "receives loot:" to regular yells
    if event == "CHAT_MSG_YELL" then
        local plainMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        -- Only process if message already contains loot patterns (actual loot messages, not regular yells)
        if plainMsg:find("receives loot:") or plainMsg:find("receives item:") or 
           plainMsg:find("creates:") or plainMsg:find("conjures:") then
            -- This is an actual loot message incorrectly sent as a yell - reformat it
            local playerName = author
            if not playerName or playerName == "" then
                -- Try to extract from message if author is missing
                playerName = plainMsg:match("^%s*(.-)%s+receives loot:") or
                             plainMsg:match("^%s*(.-)%s+receives item:") or
                             plainMsg:match("^%s*(.-)%s+creates:") or
                             plainMsg:match("^%s*(.-)%s+conjures:")
                if playerName then
                    playerName = playerName:gsub("%-.*", "") -- Remove server name if present
                    playerName = playerName:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
                end
            else
                -- Remove server name if present in author (format: "Name-Server")
                playerName = playerName:gsub("%-.*", "")
            end
            
            -- Other person's loot in yell: fall through so group loot block can style as "Name: Item (2)"
            if playerName and playerName ~= "" and playerName ~= UnitName("player") then
                -- fall through to group loot styling below
            else
                -- If we can't format it properly, suppress the yell version
                return true
            end
        end
        -- Regular yells with item links should pass through unchanged - don't add "receives loot:" to them
    end

    -- 1. Experience and discovery messages
    local plainSys = type(msg) == "string" and msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1") or ""
    local experienceMessage = FormatExperienceMessage and FormatExperienceMessage(msg, plainSys, prefixPlus)
    if experienceMessage then
        return false, experienceMessage, author, ...
    end

    -- 2.1 Battleground/party notices
    local groupNotice = FormatBattlegroundAndGroupNotice(event, plainSys)
    if groupNotice then
        return false, groupNotice, author, ...
    end

    -- 2.3 Level-up reward messages. These can arrive as SYSTEM, combat XP, or Vanilla combat misc messages.
    if IsLevelUpRewardEvent(event) then
        local styledLevelReward = FormatLevelUpRewardMessage(plainSys)
        if styledLevelReward then
            return false, styledLevelReward, author, ...
        end
    end

    -- 2.5. Quest Acceptance & Completion (check early, before other patterns)
    -- Only process quest messages from SYSTEM events (your own quests)
    if event == "CHAT_MSG_SYSTEM" then
        local plainMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        local questProgressMessage = FormatQuestProgressMessage and FormatQuestProgressMessage(event, msg, plainMsg, prefixPlus)
        if questProgressMessage == true then
            return true
        elseif questProgressMessage then
            return false, questProgressMessage, author, ...
        end

        do
            local systemSocialMessage = FormatSystemSocialMessage and FormatSystemSocialMessage(plainMsg)
            if systemSocialMessage == true then
                return true
            elseif systemSocialMessage then
                return false, systemSocialMessage, author, ...
            end
        end
    end

    -- 2. Reputation and queue/system notices
    local reputationMessage = FormatReputationMessage and FormatReputationMessage(msg)
    if reputationMessage then
        return false, reputationMessage, author, ...
    end

    local queueNotice = FormatQueueNotice and FormatQueueNotice(msg, event)
    if queueNotice == true then
        return true
    elseif queueNotice then
        return false, queueNotice, author, ...
    end

    -- 4. Auction Messages
    local auctionMessage = FormatAuctionMessage and FormatAuctionMessage(msg, prefixPlus, prefixMinus)
    if auctionMessage == true then
        return true
    elseif auctionMessage then
        return false, auctionMessage, author, ...
    end

    -- 5. Currency gains
    local currencyMessage = FormatCurrencyMessage and FormatCurrencyMessage(event, msg, prefixPlus)
    if currencyMessage then
        return false, currencyMessage, author, ...
    end

    -- 5. Money (Gains show +, losses show -; Merchant is handled by direct tracking above)
    local moneyMessage = FormatMoneyMessage and FormatMoneyMessage(event, msg, prefixPlus, prefixMinus)
    if moneyMessage == true then
        return true
    elseif moneyMessage then
        return false, moneyMessage, author, ...
    end

    -- 5b. Loot Share Money (party/raid split)
    local lootShareMoney = FormatLootShareMoney and FormatLootShareMoney(msg, prefixPlus)
    if lootShareMoney then
        return false, lootShareMoney, author, ...
    end

    -- 7. Learning Spells, Recipes, Abilities & Skill Increases
    local skillMessage = FormatSkillMessage and FormatSkillMessage(msg, plainSys, prefixPlus, prefixMinus)
    if skillMessage == true then
        return true
    elseif skillMessage then
        return false, skillMessage, author, ...
    end

    -- 6. Item Looting
    local selfLootMessage = FormatSelfLootMessage and FormatSelfLootMessage(event, msg, prefixPlus)
    if selfLootMessage then
        return false, selfLootMessage, author, ...
    end

    local groupLootMessage = FormatGroupLootMessage and FormatGroupLootMessage(event, msg, author)
    if groupLootMessage then
        return false, groupLootMessage, author, ...
    end

    local lootRollMessage = FormatLootRollMessage and FormatLootRollMessage(event, msg)
    if lootRollMessage == true then
        return true
    elseif lootRollMessage then
        return false, lootRollMessage, author, ...
    end

    -- 9. Quest Money Rewards - handle separately from generic rewards
    local questMoneyReward = FormatQuestMoneyReward and FormatQuestMoneyReward(msg, prefixPlus)
    if questMoneyReward then
        return false, questMoneyReward, author, ...
    end

    -- 10. Refunds like \"You are refunded: Item x10.\" → \"Refunded: Item (10)\"
    do
        local refundDisplay = FormatRefundDisplay(msg)
        if refundDisplay then
            return false, refundDisplay, author, ...
        end
    end

    -- 11. Generic rewards (awarded, received, earned, rewarded, badges, marks, tokens, points, etc.)
    local genericReward = FormatGenericReward(msg, prefixPlus)
    if genericReward then
        return false, genericReward, author, ...
    end

    -- 11. Pass through unchanged. If msg still contains Blizzard format placeholders (%s, %d),
    --     format it with variadic args so we never show literal "%s" in chat (default Blizz text).
    --     Skip this for monster emotes, which we pre-format above.
    if event ~= "CHAT_MSG_MONSTER_EMOTE" and type(msg) == "string" and (msg:find("%%s") or msg:find("%%d")) then
        local n = select("#", ...)
        local function try_format(...)
            local ok, res = pcall(string.format, msg, ...)
            return (ok and type(res) == "string" and not res:find("%%s")) and res or nil
        end
        local formatted = (n >= 1 and try_format(...)) or (author and author ~= "" and try_format(author))
        if formatted then
            msg = formatted
        end
    end
    return false, SpaceBeforeX(msg), author, ...
end

local chatCleanerFeature = ChatCleanerLifecycle.Create and ChatCleanerLifecycle.Create({
    FilterImpl = ChatFilterImpl,
    HookChatFrameAddMessage = HookChatFrameAddMessage,
    ApplyLevelUpGlobalStringStyling = ApplyLevelUpGlobalStringStyling,
    SessionTracker = sessionTracker,
}) or {}

ns.Private.ChatCleaner = ns.Private.ChatCleaner or {}
ns.Private.ChatCleaner.FilterImpl = ChatFilterImpl
ns.Private.ChatCleaner.PostProcessor = postProcessor

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("chatCleanerEnabled", chatCleanerFeature)
end
