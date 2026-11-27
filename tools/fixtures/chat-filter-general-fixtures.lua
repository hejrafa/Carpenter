#!/usr/bin/env lua
-- Verifies the Retail and WoW Forever chat filter: WTS, WTB and LFW posts in the
-- General channel and in yells are hidden; Trade, other channels, say,
-- party, NPC yells, your own posts and lines the game hides from addons are
-- shown as they came.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local function fail(message)
    io.stderr:write("chat-filter-general fixture failed: " .. message .. "\n")
    os.exit(1)
end
local function expect(actual, expected, label)
    if actual ~= expected then
        fail(label .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local GENERAL, TRADE, CUSTOM = 1, 2, 0
local PLAYER_GUID, OTHER_GUID = "Player-1-0000001", "Player-1-0000002"

issecretvalue = function(value) return value == SECRET end
local feature
Carpenter = {
    RegisterFeature = function(_, key, registered)
        if key == "chatFilterEnabled" then feature = registered end
    end,
}
assert(loadfile(repo .. "/Core/Secret.lua"))()

local filters, adds, removes = {}, 0, 0
ChatFrameUtil = {
    AddMessageEventFilter = function(event, callback)
        adds = adds + 1
        filters[event] = callback
    end,
    RemoveMessageEventFilter = function(event, callback)
        if filters[event] ~= callback then fail("removed a filter that wasn't added") end
        removes = removes + 1
        filters[event] = nil
    end,
}
function UnitGUID(unit)
    if unit == "player" then return PLAYER_GUID end
end

assert(loadfile(repo .. "/Modules/ChatFilterGeneral.lua"))("Carpenter", {})
if not feature then fail("chatFilterEnabled was not registered") end

feature:Enable()
feature:Enable()
expect(adds, 2, "enabling twice adds each filter once")
local FILTERED = { CHAT_MSG_CHANNEL = true, CHAT_MSG_YELL = true }
for event in pairs(FILTERED) do
    if not filters[event] then fail("no filter on " .. event) end
end
for event in pairs(filters) do
    if not FILTERED[event] then fail("only channel chat and yells are filtered, not " .. event) end
end

local function Run(event, text, channelName, channelID, guid)
    local results = { n = 0 }
    local function Pack(...) results = { n = select("#", ...), ... } end
    Pack(filters[event]({}, event, text, "Seller-Realm", "Common", channelName,
        "", "", channelID, channelName ~= "" and 1 or 0, "", 7, 100, guid or OTHER_GUID))
    if results.n ~= 1 then fail("the filter hands values back to the chat frame for: " .. tostring(text)) end
    return results[1]
end

-- Runs a CHAT_MSG_CHANNEL line through the filter: true when it's hidden.
local function Hidden(text, channelID, guid)
    return Run("CHAT_MSG_CHANNEL", text, "1. General - Stormwind City", channelID, guid)
end

-- Runs a player yell through the filter: yells carry no channel.
local function HiddenYell(text, guid)
    return Run("CHAT_MSG_YELL", text, "", 0, guid)
end

-- General: WTS and WTB as words go.
expect(Hidden("WTS [Arcanite Bar] 40g", GENERAL), true, "WTS in General is hidden")
expect(Hidden("wtb runecloth, pst", GENERAL), true, "lowercase wtb in General is hidden")
expect(Hidden("[WTS] portals to Darnassus", GENERAL), true, "bracketed WTS is hidden")
expect(Hidden("LFG Deadmines or WTB a run", GENERAL), true, "WTB mid-line is hidden")
expect(Hidden("Wts: mageweave bags", GENERAL), true, "WTS with a colon is hidden")
expect(Hidden("WTS/WTB enchants", GENERAL), true, "WTS/WTB is hidden")
expect(Hidden("LFW Enchanter, all recipes, tips only", GENERAL), true, "LFW in General is hidden")
expect(Hidden("[lfw] Alchemist", GENERAL), true, "bracketed lowercase LFW is hidden")

-- General: ordinary chat and words that only contain the letters stay.
expect(Hidden("anyone know where the newts are?", GENERAL), false, "a word ending in wts stays")
expect(Hidden("WTSing all day", GENERAL), false, "a longer word stays")
expect(Hidden("LFWorld boss group", GENERAL), false, "a word starting with lfw stays")
expect(Hidden("Where is the Deadmines entrance?", GENERAL), false, "ordinary General chat stays")

-- Other channels are left alone.
expect(Hidden("WTS [Arcanite Bar] 40g", TRADE), false, "WTS in Trade stays")
expect(Hidden("WTB runecloth", CUSTOM), false, "WTB in a custom channel stays")
expect(Hidden("WTS portals", nil), false, "a line without a channel ID stays")

-- Your own posts stay, and so do lines the game hides from addons.
expect(Hidden("WTS [Arcanite Bar] 40g", GENERAL, PLAYER_GUID), false, "your own WTS stays")
expect(Hidden(SECRET, GENERAL), false, "a hidden line is shown as it came")
expect(Hidden("WTS portals", SECRET), false, "a hidden channel ID is shown as it came")
expect(Hidden("WTS portals", GENERAL, SECRET), true, "a hidden sender doesn't stop the filter")

-- Yells: WTS, WTB and LFW go, everything else stays.
expect(HiddenYell("WTS PORTALS / FOOD / WATER TIP WHAT U LIKE :)"), true, "a WTS yell is hidden")
expect(HiddenYell("wtb Righteous Orbs"), true, "a WTB yell is hidden")
expect(HiddenYell("LFW BLACKSMITH ALL ARMOR MATS YOU BRING"), true, "an LFW yell is hidden")
expect(HiddenYell("Lfw: Tailor, PST"), true, "LFW with a colon is hidden")
expect(HiddenYell("LFM MC - 2 SR + 1 Tank"), false, "an ordinary yell stays")
expect(HiddenYell("WTS portals", PLAYER_GUID), false, "your own WTS yell stays")
expect(HiddenYell("LFW Enchanter", PLAYER_GUID), false, "your own LFW yell stays")
expect(HiddenYell(SECRET), false, "a hidden yell is shown as it came")

feature:Disable()
feature:Disable()
expect(removes, 2, "disabling twice removes each filter once")
expect(next(filters), nil, "the filters are gone when turned off")

print("chat-filter-general fixtures passed")
