--[[ Carpenter - ChatFilter ]]
-- Filters spam (gambling, bots, recruitment) and duplicate messages.
local lastMessages = {}
local messageHistory = {}
local MAX_HISTORY = 25
local THROTTLE_TIME = 45
local filtersRegistered = false
local pruneCounter = 0

local chatEvents = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_YELL",
    "CHAT_MSG_SAY",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER"
}

-- =========================
-- Helper Functions
-- =========================

local function IsGlobalDuplicate(msg)
    if not CarpenterDB or not CarpenterDB.filterDuplicatesEnabled then return false end
    -- Normalize: remove spaces and lowercase
    local cleanMsg = msg:gsub("%s+", ""):lower()

    for _, historyMsg in ipairs(messageHistory) do
        if historyMsg == cleanMsg then return true end
    end

    table.insert(messageHistory, 1, cleanMsg)
    if #messageHistory > MAX_HISTORY then table.remove(messageHistory) end
    return false
end

-- =========================
-- Spam Databases
-- =========================

-- RestedXP level-up / announcer spam (Say, Yell, Party, Raid, General) - filtered when Filter is on
local RestedXPPatterns = {
    "restedxp", "rested xp", "restedxp guides", "just leveled from", "just leveled", "just hit level",
    "reached level", "leveled to", "level up", "with restedxp", "ding!?", "hit level %d", "hit %d+",
    "level %d+ with", "level %d+ in", "using restedxp"
}

local SpamPatterns = {
    Gambling = { "deathroll", "death roll", "betting", "casino", "payout", "gold roll", "minimum bet", "max bet", "hosting", "roll for gold", "rolls for gold", "rolling for gold", "!leaderboard" },
    GuildRecruitment = {
        "guild", "recruiting", "recruit", "raiding", "active members",
        "recrute", "guilde", "recherche joueurs",                 -- FR
        "gilde", "sucht", "mitglieder",                           -- DE
        "gildia", "rekrutuje", "zapraszamy", "polska", "polacy",  -- PL
        "søger", "söker", "rekrutterer", "nordic", "skandinavisk" -- SCAN
    },
    TradeBots = {
        "wts boost", "wts", "wtb", "lfw", "wtf", "enchant", "gallywix", "selling run", "carry", "reliable gold", "fast delivery",
        "WWW%.", "%.COM", "%.NET", "%.ORG", "USD", "EUR", "PAYPAL", "G2G"
    }
}

-- =========================
-- Main Chat Filter
-- =========================

local function ChatSpamFilter(self, event, msg, author, ...)
    -- 1. Main toggle check for the Filter module
    if not (Carpenter and Carpenter:IsEnabled("chatFilterEnabled")) then return false, msg, author, ... end

    -- 2. RestedXP level-up spam (Say, Yell, Party, Raid, General) - when option is on
    local isRestedXPEvent = (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or
        event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or
        event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or
        (event == "CHAT_MSG_CHANNEL" and select(7, ...) == "General"))
    if isRestedXPEvent and CarpenterDB.filterRestedXPEnabled then
        local plainMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
        local lower = plainMsg:lower()
        for _, p in ipairs(RestedXPPatterns) do
            if lower:find(p) then return true end
        end
    end

    -- 2b. Filter messages containing "@" in Say, Yell, General, or Trade (when Filter is on)
    if msg:find("@") then
        if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
            return true
        end
        if event == "CHAT_MSG_CHANNEL" then
            local channelBaseName = select(7, ...)
            if channelBaseName == "General" or channelBaseName == "Trade" then
                return true
            end
        end
    end

    -- 3. SAFETY: Always allow Party, Raid, Whisper, and Say (except RestedXP above)
    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID" or
        event == "CHAT_MSG_PARTY_LEADER" or event == "CHAT_MSG_RAID_LEADER" or
        event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_SAY" then
        return false, msg, author, ...
    end

    local cleanMsg = msg:lower()
    local sender = author or "Unknown"
    local playerName = UnitName and UnitName("player") or nil

    -- 4. Toggleable Category Filters
    if CarpenterDB.filterGamblingEnabled then
        for _, p in ipairs(SpamPatterns.Gambling) do
            if cleanMsg:find(p) then return true end
        end
    end

    if CarpenterDB.filterGuildRecruitEnabled then
        for _, p in ipairs(SpamPatterns.GuildRecruitment) do
            if cleanMsg:find(p) then return true end
        end
    end

    if CarpenterDB.filterTradeBotsEnabled then
        for _, p in ipairs(SpamPatterns.TradeBots) do
            if cleanMsg:find(p) then return true end
        end
    end

    -- 5. Duplicate Detection & Throttling
    if CarpenterDB.filterDuplicatesEnabled then
        -- Never apply duplicate/throttle logic to the player's own messages
        local isPlayer =
            playerName and
            sender and
            sender:match("^[^-]+") == playerName

        if not isPlayer then
            -- Check if message is a near-identical duplicate of something recent
            if IsGlobalDuplicate(msg) then return true end

            -- Local Throttling: prevent the same person from repeating the same thing too fast
            local now = GetTime()
            pruneCounter = pruneCounter + 1
            if pruneCounter >= 50 then
                pruneCounter = 0
                local cutoff = now - (THROTTLE_TIME * 2)
                for key, seenAt in pairs(lastMessages) do
                    if seenAt < cutoff then
                        lastMessages[key] = nil
                    end
                end
            end

            local msgKey = sender .. ":" .. cleanMsg
            if lastMessages[msgKey] and (now - lastMessages[msgKey] < THROTTLE_TIME) then
                return true
            end
            lastMessages[msgKey] = now
        end
    end

    return false, msg, author, ...
end

-- =========================
-- Event Handling
-- =========================

local function RegisterFilters()
    if filtersRegistered then return end
    filtersRegistered = true
    for _, chatEvent in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(chatEvent, ChatSpamFilter)
    end
end

local function UnregisterFilters()
    if not filtersRegistered then return end
    filtersRegistered = false
    if ChatFrame_RemoveMessageEventFilter then
        for _, chatEvent in ipairs(chatEvents) do
            ChatFrame_RemoveMessageEventFilter(chatEvent, ChatSpamFilter)
        end
    end
end

local feature = {}

function feature:Enable()
    RegisterFilters()
end

function feature:Disable()
    UnregisterFilters()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("chatFilterEnabled", feature)
end
