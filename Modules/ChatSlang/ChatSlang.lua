--[[ Carpenter - Chat Slang tooltips ]]
-- Turns known abbreviations in player chat into hover links. Hovering one
-- explains the term and spells the whole line out in plain words.
--
-- Links use Blizzard's "addon" link type, which SetItemRef routes to an
-- EventRegistry event instead of the ItemRef tooltip, and hovering is read from
-- the chat frame's own EventRegistry events. No chat frame scripts are replaced.
local _, ns = ...
ns.Private = ns.Private or {}

local Engine = ns.Private.ChatSlangEngine
local L = ns.L or Carpenter.L or {}

local FEATURE_KEY = "chatSlangTooltipsEnabled"
local LINK_PREFIX = "addon:Carpenter:slang:"
local MAX_CACHED_MESSAGES = 200

local CHAT_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_EMOTE",
}

-- Recent lines by id, plus the converted text of each source line, so every
-- chat frame that shows the same line reuses one id.
local messages = {}
local messageOrder = {}
local convertedBySource = {}
local nextMessageID = 0
local tooltipShown = false
local filtersRegistered = false
local callbacksRegistered = false
local callbackOwner = {}

local function EncodeKey(key)
    return (key:gsub("[^%w_%-]", function(char)
        return ("%%%02X"):format(char:byte())
    end))
end

local function DecodeKey(encoded)
    return (encoded:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function Remember(id, record)
    messages[id] = record
    convertedBySource[record.source] = record.converted
    messageOrder[#messageOrder + 1] = id
    if #messageOrder > MAX_CACHED_MESSAGES then
        local oldest = messages[table.remove(messageOrder, 1)]
        if oldest then
            messages[oldest.id] = nil
            if convertedBySource[oldest.source] == oldest.converted then
                convertedBySource[oldest.source] = nil
            end
        end
    end
end

local function Convert(message)
    if not Engine or not Engine.IsPlainString(message) then return message end
    if message:find("|H" .. LINK_PREFIX, 1, true) then return message end

    local cached = convertedBySource[message]
    if cached then return cached end

    local id = nextMessageID + 1
    local converted, plainWords, terms = Engine.Process(message, function(term, index, written)
        return "|H" .. LINK_PREFIX .. id .. ":" .. index .. ":" .. EncodeKey(term.key) .. "|h" .. written .. "|h"
    end)
    if not converted then return message end

    nextMessageID = id
    Remember(id, {
        id = id,
        source = message,
        converted = converted,
        plainWords = plainWords,
        terms = terms,
    })
    return converted
end

local function ChatFilter(_, _, message, ...)
    if not Engine.IsPlainString(message) then
        return false, message, ...
    end
    local ok, converted = pcall(Convert, message)
    return false, ok and converted or message, ...
end

local function ParseLink(link)
    if not Engine.IsPlainString(link) then return nil end
    local id, index, encodedKey = link:match("^" .. LINK_PREFIX .. "(%d+):(%d+):(.+)$")
    if not id then return nil end

    local record = messages[tonumber(id)]
    local term = record and record.terms[tonumber(index)]
    if term then return term, record end

    -- The line scrolled out of the cache: explain the bare glossary entry.
    local entry = Engine.Lookup(DecodeKey(encodedKey))
    if not entry then return nil end
    return { key = entry.key, entry = entry, meaning = entry.title, uncertain = false }, nil
end

local function EscapeTooltipText(text)
    return (text:gsub("|", "||"))
end

local function ShowTooltip(chatFrame, link)
    local term, record = ParseLink(link)
    if not term or not GameTooltip then return end

    local entry = term.entry
    local meaning = term.uncertain and entry.title or term.meaning:gsub(":$", "")

    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR_RIGHT", 12, 12)
    GameTooltip:SetText(term.key, 1, 0.82, 0)
    GameTooltip:AddLine(meaning, 1, 1, 1, true)
    GameTooltip:AddLine(entry.desc, 0.75, 0.75, 0.75, true)

    if term.uncertain then
        GameTooltip:AddLine(L.SLANG_TOOLTIP_UNCLEAR, 1, 0.65, 0.25, true)
    elseif term.fromContext and entry.title:find(" / ", 1, true) then
        GameTooltip:AddLine(L.SLANG_TOOLTIP_ALSO:format(entry.title), 0.55, 0.55, 0.55, true)
    end

    if record and record.plainWords ~= record.source then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.SLANG_TOOLTIP_PLAIN_WORDS, 1, 0.82, 0)
        GameTooltip:AddLine(EscapeTooltipText(record.plainWords), 0.65, 0.85, 1, true)
    elseif entry.example then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.SLANG_TOOLTIP_EXAMPLE, 1, 0.82, 0)
        GameTooltip:AddLine(EscapeTooltipText(entry.example.sentence), 0.65, 0.85, 1, true)
        GameTooltip:AddLine(EscapeTooltipText(entry.example.meaning), 0.75, 0.75, 0.75, true)
    end

    GameTooltip:Show()
    tooltipShown = true
end

local function HideTooltip()
    if not tooltipShown then return end
    tooltipShown = false
    if GameTooltip then GameTooltip:Hide() end
end

local function OnHyperlinkEnter(_, chatFrame, link)
    if not Engine.IsPlainString(link) or link:sub(1, #LINK_PREFIX) ~= LINK_PREFIX then return end
    local ok = pcall(ShowTooltip, chatFrame, link)
    if not ok then HideTooltip() end
end

local function OnHyperlinkLeave()
    HideTooltip()
end

local function AddEventFilter(event, filter)
    local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add) == "function" then add(event, filter) end
end

local function RemoveEventFilter(event, filter)
    local remove = ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    if type(remove) == "function" then remove(event, filter) end
end

local feature = {}

function feature:Enable()
    if not Engine then return end
    if not filtersRegistered then
        filtersRegistered = true
        for _, event in ipairs(CHAT_EVENTS) do
            AddEventFilter(event, ChatFilter)
        end
    end
    if not callbacksRegistered and EventRegistry and EventRegistry.RegisterCallback then
        callbacksRegistered = true
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", OnHyperlinkEnter, callbackOwner)
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnHyperlinkLeave, callbackOwner)
    end
end

function feature:Disable()
    if filtersRegistered then
        filtersRegistered = false
        for _, event in ipairs(CHAT_EVENTS) do
            RemoveEventFilter(event, ChatFilter)
        end
    end
    if callbacksRegistered then
        callbacksRegistered = false
        EventRegistry:UnregisterCallback("ChatFrame.OnHyperlinkEnter", callbackOwner)
        EventRegistry:UnregisterCallback("ChatFrame.OnHyperlinkLeave", callbackOwner)
    end
    HideTooltip()
end

-- Exposed for tools/chat-slang-fixtures.lua.
ns.Private.ChatSlang = {
    Convert = Convert,
    ParseLink = ParseLink,
}

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
