--[[ Carpenter - Chat Filter for WoW Forever and Retail ]]
-- Hides WTS and WTB posts in the General channel. Trade, party, say and yell
-- are left alone, and so are your own posts.
--
-- General is told by its zone channel ID (ChatChannels 1), which is the same
-- in every language and never secret. A post the game hides from addons is
-- shown as it came.
local Secret = Carpenter and Carpenter.Secret or {}
local ReadableString = Secret.ReadableString or function(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value
end
local ReadableNumber = Secret.ReadableNumber or function(value)
    if type(value) ~= "number" then return nil end
    return value
end

local GENERAL_CHANNEL_ID = 1

-- Whole words only: "WTS", "[WTB]" and "wts:" count, "WTSing" doesn't.
local TRADE_WORD_PATTERNS = { "%f[%w]wts%f[%W]", "%f[%w]wtb%f[%W]" }

local function IsTradePost(text)
    local lower = text:lower()
    for _, pattern in ipairs(TRADE_WORD_PATTERNS) do
        if lower:find(pattern) then return true end
    end
    return false
end

-- CHAT_MSG_CHANNEL: text, playerName, languageName, channelName,
-- playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName,
-- languageID, lineID, guid. True hides the line; false alone shows it as
-- it came, so nothing is handed back to the chat frame.
local function Filter(_, _, text, _, _, _, _, _, zoneChannelID, _, _, _, _, guid)
    if ReadableNumber(zoneChannelID) ~= GENERAL_CHANNEL_ID then return false end
    local message = ReadableString(text)
    if not message or not IsTradePost(message) then return false end
    local sender = ReadableString(guid)
    local player = UnitGUID and ReadableString(UnitGUID("player"))
    if sender and sender == player then return false end
    return true
end

local function AddFilter()
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then add("CHAT_MSG_CHANNEL", Filter) end
end

local function RemoveFilter()
    local remove = (ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter) or ChatFrame_RemoveMessageEventFilter
    if remove then remove("CHAT_MSG_CHANNEL", Filter) end
end

local registered = false
local feature = {}

function feature:Enable()
    if registered then return end
    registered = true
    AddFilter()
end

function feature:Disable()
    if not registered then return end
    registered = false
    RemoveFilter()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("chatFilterEnabled", feature)
end
