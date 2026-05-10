#!/usr/bin/env lua
-- Offline fixture checks for Chat Cleaner formatting.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

unpack = unpack or table.unpack
floor = math.floor

local ns = { Private = {} }
Carpenter = {
    L = {},
    Client = { isRetail = false },
    IsEnabled = function(_, key) return key == "chatCleanerEnabled" end,
    RegisterFeature = function() end,
    Profile = function(_, _, callback, ...)
        return callback(...)
    end,
}

RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
}
ITEM_QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1.00, g = 1.00, b = 1.00 },
    [2] = { r = 0.12, g = 1.00, b = 0.00 },
    [3] = { r = 0.00, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
}
ChatTypeInfo = {
    PARTY = { r = 0.67, g = 0.67, b = 1 },
    RAID = { r = 1, g = 0.50, b = 0 },
}

CHAT_PARTY_LEADER_GET = "[Party Leader] %s: "
CHAT_PARTY_GET = "[Party] %s: "
CHAT_RAID_LEADER_GET = "[Raid Leader] %s: "
CHAT_RAID_GET = "[Raid] %s: "
CHAT_INSTANCE_CHAT_LEADER_GET = "[Instance Leader] %s: "
CHAT_INSTANCE_CHAT_GET = "[Instance] %s: "
CHAT_GUILD_GET = "[Guild] %s: "
CHAT_OFFICER_GET = "[Officer] %s: "
CHAT_RAID_WARNING_GET = "[Raid Warning] %s: "

LOOT_ITEM = "%s receives loot: %s."
LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
LOOT_ITEM_PUSHED = "%s receives item: %s."
LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d."
CREATED_ITEM = "%s creates: %s."
CREATED_ITEM_MULTIPLE = "%s creates: %sx%d."
LOOT_ROLL_NEED = "%s has selected Need for: %s"
LOOT_ROLL_GREED = "%s has selected Greed for: %s"
LOOT_ROLL_DISENCHANT = "%s has selected Disenchant for: %s"
LOOT_ROLL_WON = "%s won: %s"

NUM_CHAT_WINDOWS = 1
_G.ChatFrame1 = { AddMessage = function() end }
_G.ChatFrame1EditBox = {
    GetRegions = function() return nil end,
}

local now = 1000
function GetTime() return now end
function GetLocale() return "enUS" end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
function UnitName(unit)
    if unit == "player" then return "Tester" end
    return nil
end
function UnitClass(unit)
    if unit == "player" then return "Warrior", "WARRIOR" end
    return nil, nil
end
function GetItemInfo(item)
    if type(item) == "string" then
        local name = item:match("|h%[(.-)%]|h") or item:match("%[(.-)%]")
        if name then return name, item, 2 end
    end
    return nil, nil, nil
end
function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:UnregisterAllEvents() end
    function frame:SetScript() end
    function frame:Hide() self.hidden = true end
    function frame:Show() self.hidden = false end
    function frame:IsShown() return not self.hidden end
    return frame
end
function ChatFrame_AddMessageEventFilter() end
function ChatFrame_RemoveMessageEventFilter() end

C_Timer = {
    After = function(_, callback) callback() end,
}

local function loadAddonFile(path)
    local chunk, err = loadfile(repo .. "/" .. path)
    if not chunk then error(err) end
    return chunk("Carpenter", ns)
end

loadAddonFile("Localization/enUS.lua")
loadAddonFile("Modules/ChatCleanerUtils.lua")
loadAddonFile("Modules/ChatCleanerLoot.lua")
loadAddonFile("Modules/ChatCleanerSessions.lua")
loadAddonFile("Modules/ChatCleanerSystem.lua")
loadAddonFile("Modules/ChatCleanerRewards.lua")
loadAddonFile("Modules/ChatCleanerSocial.lua")
loadAddonFile("Modules/ChatCleanerPostProcess.lua")
loadAddonFile("Modules/ChatCleanerLifecycle.lua")
loadAddonFile("Modules/ChatCleaner.lua")

local filter = ns.Private.ChatCleaner and ns.Private.ChatCleaner.FilterImpl
assert(type(filter) == "function", "ChatCleaner filter was not exposed")
local postProcessor = ns.Private.ChatCleaner and ns.Private.ChatCleaner.PostProcessor
assert(type(postProcessor) == "table" and type(postProcessor.ProcessMessage) == "function", "ChatCleaner post-processor was not exposed")

local function plain(text)
    if not text then return text end
    return text
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1")
        :gsub("|T.-|t", "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local fixtures = {
    {
        name = "fatigue death",
        path = "post",
        event = "CHAT_MSG_SYSTEM",
        message = "Lionginas died of fatigue in The Merchant Coast! They were level 32",
        expectPlain = "Lionginas died from fatigue! Level 32",
    },
    {
        name = "player links keep original color",
        path = "post",
        event = "CHAT_MSG_CHANNEL",
        message = "|Hplayer:Tester|h[Tester]|h says hi",
        expectPlain = "Tester says hi",
        rejectColor = "|cffc69b6d",
    },
    {
        name = "loot roll range",
        event = "CHAT_MSG_LOOT",
        message = "Yantiparazi rolls 40 (1-100)",
        expectPlain = "Yantiparazi rolls 40 (1-100)",
        rejectColor = "|cffc69b6d",
    },
    {
        name = "self level up capitalization",
        event = "CHAT_MSG_SYSTEM",
        message = "Reached level 24.",
        expectPlain = "Reached level 24",
        rejectColor = "|cffc69b6d",
    },
    {
        name = "guild join",
        event = "CHAT_MSG_SYSTEM",
        message = "Uzaemon has joined the guild.",
        expectPlain = "Uzaemon joined the guild",
    },
    {
        name = "guild leave",
        event = "CHAT_MSG_SYSTEM",
        message = "Uzaemon has left the guild.",
        expectPlain = "Uzaemon left the guild",
    },
    {
        name = "quest accepted",
        event = "CHAT_MSG_SYSTEM",
        message = "Quest accepted: The Missing Diplomat",
        expectPlain = "+ Accepted: The Missing Diplomat",
    },
    {
        name = "auctionator hidden",
        event = "CHAT_MSG_SYSTEM",
        message = "Auctionator: scan complete",
        expectHidden = true,
    },
}

local failures = {}

for _, fixture in ipairs(fixtures) do
    local hidden, out
    if fixture.path == "post" then
        local frame = {}
        local captured = nil
        local function originalAddMessage(_, message)
            captured = message
        end
        postProcessor.ProcessMessage(frame, originalAddMessage, fixture.message, {})
        hidden = captured == nil
        out = captured
    else
        hidden, out = filter(nil, fixture.event, fixture.message, fixture.author or "")
    end
    local outPlain = plain(out)

    if fixture.expectHidden then
        if hidden ~= true then
            failures[#failures + 1] = fixture.name .. ": expected hidden"
        end
    elseif hidden == true then
        failures[#failures + 1] = fixture.name .. ": unexpectedly hidden"
    elseif outPlain ~= fixture.expectPlain then
        failures[#failures + 1] = fixture.name .. ": expected [" .. fixture.expectPlain .. "] got [" .. tostring(outPlain) .. "]"
    elseif fixture.rejectColor and out and out:find(fixture.rejectColor, 1, true) then
        failures[#failures + 1] = fixture.name .. ": output used rejected color " .. fixture.rejectColor
    end
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("chat-cleaner fixtures: " .. #fixtures .. " passed")
