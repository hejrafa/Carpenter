#!/usr/bin/env lua
-- Verifies the Retail and WoW Forever chat filter: WTS and WTB posts in the
-- General channel are hidden; Trade, other channels, your own posts and
-- lines the game hides from addons are shown as they came.

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
expect(adds, 1, "enabling twice adds the filter once")
local filter = filters.CHAT_MSG_CHANNEL
if not filter then fail("no filter on CHAT_MSG_CHANNEL") end
for event in pairs(filters) do
    if event ~= "CHAT_MSG_CHANNEL" then fail("only channel chat is filtered, not " .. event) end
end

-- Runs a CHAT_MSG_CHANNEL line through the filter: true when it's hidden.
local function Hidden(text, channelID, guid)
    local results = { n = 0 }
    local function Pack(...) results = { n = select("#", ...), ... } end
    Pack(filter({}, "CHAT_MSG_CHANNEL", text, "Seller-Realm", "Common", "1. General - Stormwind City",
        "", "", channelID, 1, "General - Stormwind City", 7, 100, guid or OTHER_GUID))
    if results.n ~= 1 then fail("the filter hands values back to the chat frame for: " .. tostring(text)) end
    return results[1]
end

-- General: WTS and WTB as words go.
expect(Hidden("WTS [Arcanite Bar] 40g", GENERAL), true, "WTS in General is hidden")
expect(Hidden("wtb runecloth, pst", GENERAL), true, "lowercase wtb in General is hidden")
expect(Hidden("[WTS] portals to Darnassus", GENERAL), true, "bracketed WTS is hidden")
expect(Hidden("LFG Deadmines or WTB a run", GENERAL), true, "WTB mid-line is hidden")
expect(Hidden("Wts: mageweave bags", GENERAL), true, "WTS with a colon is hidden")
expect(Hidden("WTS/WTB enchants", GENERAL), true, "WTS/WTB is hidden")

-- General: ordinary chat and words that only contain the letters stay.
expect(Hidden("anyone know where the newts are?", GENERAL), false, "a word ending in wts stays")
expect(Hidden("WTSing all day", GENERAL), false, "a longer word stays")
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

feature:Disable()
feature:Disable()
expect(removes, 1, "disabling twice removes the filter once")
expect(filters.CHAT_MSG_CHANNEL, nil, "the filter is gone when turned off")

print("chat-filter-general fixtures passed")
