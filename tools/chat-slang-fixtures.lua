#!/usr/bin/env lua
-- Offline fixture checks for Slang Tooltips: which chat words link, which
-- meaning context picks, and that existing chat markup survives untouched.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local registeredFeature
local filters = {}
local callbacks = {}

Carpenter = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    RegisterFeature = function(_, key, feature)
        assert(key == "chatSlangTooltipsEnabled", "unexpected feature key " .. tostring(key))
        registeredFeature = feature
    end,
}
ChatFrame_AddMessageEventFilter = function(event, filter) filters[event] = filter end
ChatFrame_RemoveMessageEventFilter = function(event) filters[event] = nil end
EventRegistry = {
    RegisterCallback = function(_, event, func, owner) callbacks[event] = { func = func, owner = owner } end,
    UnregisterCallback = function(_, event) callbacks[event] = nil end,
}

local secret = {}
issecretvalue = function(value) return value == secret end

local ns = { Private = {}, L = Carpenter.L }
for _, file in ipairs({ "ChatSlangGlossary", "ChatSlangEngine", "ChatSlang" }) do
    local chunk = assert(loadfile(repo .. "/Modules/ChatSlang/" .. file .. ".lua"))
    chunk("Carpenter", ns)
end

local Engine = ns.Private.ChatSlangEngine
local ChatSlang = ns.Private.ChatSlang
assert(registeredFeature, "feature was not registered")

local function LinkedTerms(message)
    local converted = ChatSlang.Convert(message)
    local keys = {}
    for link, written in converted:gmatch("|H(addon:Carpenter:slang:[^|]+)|h(.-)|h") do
        local term = assert(ChatSlang.ParseLink(link), "link did not parse: " .. link)
        keys[#keys + 1] = written .. "=" .. term.meaning
    end
    return table.concat(keys, ", "), converted
end

local function Expect(message, expected)
    local actual = LinkedTerms(message)
    assert(actual == expected, ("%q\n  expected: %s\n  actual:   %s"):format(message, expected, actual))
end

-- Abbreviations link, everyday words in lower case stay plain.
Expect("LFM BRD, need DD, trinket HR, PST",
    "LFM=Looking for more players:, BRD=Blackrock Depths, DD=damage dealer, HR=reserved for a specified player, PST=whisper if interested")
Expect("if you need a tank i am around", "")
Expect("Meet in IF", "IF=Ironforge")
Expect("lfm brd", "lfm=Looking for more players:, brd=Blackrock Depths")

-- Context picks one meaning for ambiguous terms.
Expect("DM me for details", "DM=direct message")
Expect("LFM DM tribute", "LFM=Looking for more players:, DM=Dire Maul, tribute=Dire Maul Tribute Run")
Expect("Warlock, can I get an HS?", "HS=Healthstone")
Expect("oh idc what you say", "idc=I don't care")
Expect("Need an OH weapon", "OH=Off Hand")

-- Terms only match on word boundaries.
Expect("BRDX and XBRD", "")

-- Hyperlinks, colors, and textures pass through byte for byte.
local item = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"
local message = "WTS " .. item .. " PST {skull} |TInterface\\Icons\\INV_Misc_QuestionMark:0|t"
local linked, converted = LinkedTerms(message)
assert(linked == "WTS=Want to sell, PST=whisper if interested", linked)
assert(converted:find(item, 1, true), "item link was altered")
assert(converted:find("|TInterface\\Icons\\INV_Misc_QuestionMark:0|t", 1, true), "texture was altered")
local term, record = ChatSlang.ParseLink(converted:match("|H(addon:Carpenter:slang:[^|]+)|h"))
assert(term and record, "cached record missing")
assert(record.plainWords == "Want to sell [Thunderfury, Blessed Blade of the Windseeker] whisper if interested {skull} ",
    "plain words: " .. record.plainWords)

-- Item names never feed context: "Off Hand" needs real words around it.
Expect("oh |cff1eff00|Hitem:1::::::::60:::::|h[Sword of Weapons]|h|r", "")

-- Repeated lines reuse one id; already converted lines pass through.
assert(ChatSlang.Convert("WTB mats") == ChatSlang.Convert("WTB mats"), "repeat conversion changed")
local once = ChatSlang.Convert("LFG UBRS")
assert(ChatSlang.Convert(once) == once, "converted line was converted again")

-- Expired links fall back to the glossary entry; foreign links are ignored.
local fallback = ChatSlang.ParseLink("addon:Carpenter:slang:999999:1:PW%3AS")
assert(fallback and fallback.key == "PW:S", "expired link fallback failed")
assert(ChatSlang.ParseLink("addon:OtherAddon:thing") == nil, "foreign link parsed")
assert(ChatSlang.ParseLink(secret) == nil, "secret link parsed")

-- Secret and oversized messages are left alone.
assert(ChatSlang.Convert(secret) == secret, "secret message touched")
local long = string.rep("LFM ", 1100)
assert(ChatSlang.Convert(long) == long, "oversized message touched")
local _, count = ChatSlang.Convert(string.rep("LFM ", 20)):gsub("|Haddon:", "")
assert(count == 12, "expected 12 linked terms, got " .. count)

-- Enable and disable register and clear every hook.
registeredFeature:Enable()
assert(filters.CHAT_MSG_CHANNEL and filters.CHAT_MSG_SAY, "chat filters not registered")
assert(callbacks["ChatFrame.OnHyperlinkEnter"] and callbacks["ChatFrame.OnHyperlinkLeave"], "hover callbacks not registered")
local _, filtered = filters.CHAT_MSG_SAY(nil, "CHAT_MSG_SAY", "LFM", "Author")
assert(filtered:find("|Haddon:Carpenter:slang:", 1, true), "filter did not convert")
registeredFeature:Disable()
assert(next(filters) == nil and next(callbacks) == nil, "disable left hooks behind")

assert(Engine.Lookup("lfm").title == "Looking For More", "lookup failed")

print("chat slang fixtures passed")
