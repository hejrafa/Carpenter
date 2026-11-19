#!/usr/bin/env lua
-- Offline fixture checks for the blocked action log.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "error-trace")
local assertEqual, assertTrue = H.assertEqual, H.assertTrue

H.installCreateFrame()
SlashCmdList = { RELOAD = function() end }
date = function() return "2026-11-19 22:00:00" end
debugstack = function() return "[C]: in function 'SetRaidTarget'\nTargetFrame.lua:698: in function 'SetRaidTargetIcon'" end

-- Who wrote each variable last, as the game tracks it.
local taintOf = {}
issecurevariable = function(tbl, key)
    local taint
    if key == nil then
        taint = taintOf[tbl]
    else
        taint = taintOf[tbl] and taintOf[tbl][key]
    end
    return taint == nil, taint
end

-- The game's own variables: one Carpenter wrote, one another addon wrote,
-- one the game wrote, and Carpenter's own.
StaticPopupDialogs = { CONFIRM = {} }
TargetFrame = { unit = "target", menuMixin = {}, _CarpenterHooked = true }
GameTooltip = { shoppingTooltips = {} }
SOUNDKIT = {}
CarpenterDB = {}
taintOf.StaticPopupDialogs = "Carpenter"
taintOf.SOUNDKIT = "OtherAddon"
taintOf.CarpenterDB = "Carpenter"
taintOf.SLASH_CARPENTER1 = "Carpenter"
taintOf[TargetFrame] = { menuMixin = "Carpenter", _CarpenterHooked = "Carpenter" }

H.carpenter({ AddonName = "Carpenter" })
H.load("Core/ErrorTrace.lua", { Private = {} })

local frame
for _, created in ipairs(H.createdFrames) do
    if created.events.ADDON_ACTION_FORBIDDEN then frame = created end
end
assertTrue(frame ~= nil, "the log should listen for blocked actions")

frame.scripts.OnEvent(frame, "ADDON_ACTION_FORBIDDEN", "OtherAddon", "SetRaidTarget()")
assertEqual(CarpenterDB.blockedActionLog, nil, "another addon's blocked action should not be logged")

frame.scripts.OnEvent(frame, "ADDON_ACTION_FORBIDDEN", "Carpenter", "SetRaidTarget()")
local entry = CarpenterDB.blockedActionLog and CarpenterDB.blockedActionLog[1]
assertTrue(entry ~= nil, "Carpenter's blocked action should be logged")
assertEqual(entry.action, "SetRaidTarget()", "the entry should name the blocked function")
assertTrue(entry.stack and entry.stack:find("SetRaidTargetIcon", 1, true) ~= nil, "the entry should keep the way to the blocked call")

local tainted = {}
for _, name in ipairs(entry.tainted or {}) do tainted[name] = true end
assertTrue(tainted.StaticPopupDialogs, "a game global Carpenter wrote should be listed")
assertTrue(tainted["TargetFrame.menuMixin"], "a game field Carpenter wrote should be listed")
assertTrue(not tainted.SOUNDKIT, "another addon's write should not be listed")
assertTrue(not tainted.CarpenterDB, "Carpenter's own globals should not be listed")
assertTrue(not tainted.SLASH_CARPENTER1, "Carpenter's slash command should not be listed")
assertTrue(not tainted["TargetFrame._CarpenterHooked"], "Carpenter's own keys should not be listed")

-- The log keeps the latest few.
for _ = 1, 10 do
    frame.scripts.OnEvent(frame, "ADDON_ACTION_BLOCKED", "Carpenter", "UNKNOWN()")
end
assertEqual(#CarpenterDB.blockedActionLog, 8, "the log should keep the latest eight")

print("error-trace fixtures passed")
