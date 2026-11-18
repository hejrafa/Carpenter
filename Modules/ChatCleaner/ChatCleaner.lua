--[[ Carpenter - ChatCleaner ]]
local _, ns = ...
local IsSecret = Carpenter.Secret.IsSecret

local Utils = ns.Private.ChatCleanerUtils
local Palette = Utils.Palette
local SpaceBeforeX = Utils.SpaceBeforeX
local ChatCleanerLoot = ns.Private.ChatCleanerLoot
local ChatCleanerSessions = ns.Private.ChatCleanerSessions
local ChatCleanerSystem = ns.Private.ChatCleanerSystem
local ChatCleanerRewards = ns.Private.ChatCleanerRewards
local ChatCleanerSocial = ns.Private.ChatCleanerSocial
local ChatCleanerPostProcess = ns.Private.ChatCleanerPostProcess
local ChatCleanerLifecycle = ns.Private.ChatCleanerLifecycle

local socialFormatter = ChatCleanerSocial.Create()
local FormatBattlegroundAndGroupNotice = socialFormatter.FormatBattlegroundAndGroupNotice
local FormatSystemSocialMessage = socialFormatter.FormatSystemSocialMessage
local RememberSenderClass = socialFormatter.RememberSenderClass

-- Roll names take their class color only outside a group; in a party or raid
-- they keep that chat's color, like the rest of the roll line.
local function GetPlayerNameColor(name)
    if GetNumGroupMembers() > 0 then return nil end
    return socialFormatter.GetPlayerClassColor(name)
end

local lootFormatter = ChatCleanerLoot.Create({ GetPlayerNameColor = GetPlayerNameColor })
local FormatSelfLootMessage = lootFormatter.FormatSelfLootMessage
local FormatGroupLootMessage = lootFormatter.FormatGroupLootMessage
local FormatLootRollMessage = lootFormatter.FormatLootRollMessage

local sessionTracker = ChatCleanerSessions.Create()

local systemFormatter = ChatCleanerSystem.Create()
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
    MerchantFrame = sessionTracker.merchantFrame,
    MailTracker = sessionTracker.mailTracker,
})
local FormatCurrencyMessage = rewardFormatter.FormatCurrencyMessage
local FormatMoneyMessage = rewardFormatter.FormatMoneyMessage
local FormatAuctionMessage = rewardFormatter.FormatAuctionMessage
local FormatRefundMessage = rewardFormatter.FormatRefundMessage
local FormatGenericReward = rewardFormatter.FormatGenericReward

local postProcessor = ChatCleanerPostProcess.Create({
    FormatLevelUpRewardMessage = FormatLevelUpRewardMessage,
    FormatAppearanceCollectionMessage = FormatAppearanceCollectionMessage,
    GetPlayerNameColor = GetPlayerNameColor,
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

local PLAYER_CHAT_EVENTS = {
    CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true, CHAT_MSG_BN_WHISPER = true,
    CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true, CHAT_MSG_CHANNEL = true,
    CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
}

-- The game's lines, through each formatter in the order they claim them:
-- each answers true (hide the line), its new text, or nil (not its line).
-- plain is the line without colors and links.
local FILTER_STEPS = {
    function(_, msg, plain) return FormatExperienceMessage(msg, plain) end,
    function(event, _, plain) return FormatBattlegroundAndGroupNotice(event, plain) end,
    function(event, _, plain)
        if IsLevelUpRewardEvent(event) then return FormatLevelUpRewardMessage(plain) end
    end,
    function(event, msg, plain)
        if event ~= "CHAT_MSG_SYSTEM" then return nil end
        return FormatQuestProgressMessage(event, msg, plain) or FormatSystemSocialMessage(plain)
    end,
    function(_, msg) return FormatReputationMessage(msg) end,
    function(event, msg) return FormatQueueNotice(msg, event) end,
    function(event, msg, plain) return FormatAppearanceCollectionMessage(event, msg, plain) end,
    function(_, msg) return FormatAuctionMessage(msg) end,
    function(event, msg) return FormatCurrencyMessage(event, msg) end,
    function(event, msg) return FormatMoneyMessage(event, msg) end,
    function(_, msg, plain, _, frame) return FormatSkillMessage(msg, plain, frame) end,
    function(event, msg) return FormatSelfLootMessage(event, msg) end,
    function(event, msg, _, author) return FormatGroupLootMessage(event, msg, author) end,
    function(event, msg) return FormatLootRollMessage(event, msg) end,
    function(_, msg) return FormatRefundMessage(msg) end,
    function(event, msg) return FormatGenericReward(event, msg) end,
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
        local playerName = lootFormatter.GroupLootPlayerName(msg, author)
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
        if Utils.GROUP_CHAT_TYPE_BY_EVENT[event] then
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
        return false, systemFormatter.FormatOwnDeath(recapID), author, ...
    end

    local plain = Utils.StripColorsAndLinks(msg)
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

-- Keeps group deaths, the roster, skill ranks and battleground queues
-- current, so hidden death, join, leave, skill-up and queue lines can be
-- rewritten from them in the chat history.
local HiddenLines = ns.Private.ChatCleanerHiddenLines

local hiddenLines = HiddenLines.Create({
    GetFrames = function()
        local frames = {}
        for i = 1, NUM_CHAT_WINDOWS do
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
    FormatSkillRise = systemFormatter.FormatSkillRise,
    GetQueueChanges = systemFormatter.GetQueueChanges,
    FormatQueueChange = systemFormatter.FormatQueueChange,
    IsActive = function()
        return Carpenter:IsEnabled("chatCleanerEnabled") and Utils.InChatLockdown()
    end,
    IsForever = function()
        return Carpenter.Client.isForever == true
    end,
    FormatOwnDeath = systemFormatter.OwnDeathLine,
    IsHiddenChatEvent = postProcessor.IsHiddenChatEvent,
    FormatHiddenChat = postProcessor.FormatHiddenChat,
})
ns.Private.ChatCleaner.HiddenLines = hiddenLines
postProcessor.SetHiddenLineHandler(hiddenLines.OnHiddenLineAdded)

-- "You are no longer queued." doesn't say which queue, and comes a moment
-- before the queue goes. Once it has, the line shown as "− Left the queue"
-- gets the queue's name.
local function NameShownQueueLines()
    for _, change in ipairs(systemFormatter.GetQueueChanges()) do
        if change.kind == "left" and change.name and not change.shownChecked then
            change.shownChecked = true
            change.named = hiddenLines.RenameShownLine(systemFormatter.LeftQueueText(),
                systemFormatter.FormatQueueChange(change), change.time - change.window)
        end
    end
end

-- The chat windows handle an event before Carpenter does, so a hidden line is
-- already in their history here and is rewritten before they redraw. A later
-- pass catches what has to wait.
local function UpdateHiddenLines(delay)
    if not delay then
        pcall(hiddenLines.Update)
        return
    end
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
    systemFormatter.RefreshSkillRanks()
    if event == "CHAT_MSG_SKILL" then
        if IsSecret(arg1) then
            UpdateHiddenLines()
            UpdateHiddenLines(SKILL_LATE_PASS)
        end
    elseif hiddenLines.HasPending() then
        UpdateHiddenLines()
    end
end)

local groupNoticeFrame = CreateFrame("Frame")
groupNoticeFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        -- These fire for every unit; only a group member's new death can
        -- explain a waiting line.
        if socialFormatter.NoteGroupMemberHealth(arg1) and hiddenLines.HasPending() then
            UpdateHiddenLines()
            UpdateHiddenLines(HiddenLines.DEATH_SETTLE_DELAY)
        end
    elseif event == "UNIT_NAME_UPDATE" then
        -- A player who joined before the game had their name.
        if socialFormatter.NoteMemberName(arg1) then
            UpdateHiddenLines()
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        if IsSecret(arg1) then
            UpdateHiddenLines()
            UpdateHiddenLines(0)
            UpdateHiddenLines(HiddenLines.START_NOTICE_GRACE + 0.05)
        end
    elseif event == "PLAYER_ENTERING_BATTLEGROUND" then
        hiddenLines.EnteredBattleground()
        for _, batchTime in ipairs(HiddenLines.BATCH_TIMES) do
            UpdateHiddenLines(batchTime + HiddenLines.BATCH_CHECK_DELAY)
        end
        UpdateHiddenLines()
    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        if socialFormatter.IsBattleStartAnnouncement(arg1) then
            hiddenLines.BattleBegan()
        end
    elseif event == "PLAYER_DEAD" then
        -- "[You died.]" can come up to a second after the event, so the
        -- passes run until just past that.
        hiddenLines.PlayerDied()
        UpdateHiddenLines()
        UpdateHiddenLines(0)
        UpdateHiddenLines(0.5)
        UpdateHiddenLines(1.1)
    elseif event == "GROUP_JOINED" then
        hiddenLines.GroupJoined(socialFormatter.GroupSetupLines())
        UpdateHiddenLines()
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        systemFormatter.RefreshQueues()
        NameShownQueueLines()
        UpdateHiddenLines()
    else
        -- PLAYER_ENTERING_WORLD, GROUP_ROSTER_UPDATE and PARTY_LEADER_CHANGED:
        -- a loading screen starts the roster afresh.
        if event == "PLAYER_ENTERING_WORLD" then
            hiddenLines.LeftBattleground()
        end
        socialFormatter.NoteGroupRoster(event == "PLAYER_ENTERING_WORLD")
        UpdateHiddenLines()
    end
end)

local GROUP_NOTICE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "UNIT_HEALTH", "UNIT_FLAGS",
    "UNIT_NAME_UPDATE", "CHAT_MSG_SYSTEM",
    "CHAT_MSG_BG_SYSTEM_NEUTRAL", "PLAYER_ENTERING_BATTLEGROUND", "GROUP_JOINED", "PLAYER_DEAD",
    "UPDATE_BATTLEFIELD_STATUS",
}

Carpenter:RegisterFeature("chatCleanerEnabled", {
    Enable = function()
        skillRankFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        skillRankFrame:RegisterEvent("SKILL_LINES_CHANGED")
        skillRankFrame:RegisterEvent("CHAT_MSG_SKILL")
        for _, event in ipairs(GROUP_NOTICE_EVENTS) do
            groupNoticeFrame:RegisterEvent(event)
        end
        systemFormatter.RefreshSkillRanks()
        socialFormatter.NoteGroupRoster(true)
        systemFormatter.RefreshQueues()
    end,
    Disable = function()
        skillRankFrame:UnregisterAllEvents()
        groupNoticeFrame:UnregisterAllEvents()
    end,
})
