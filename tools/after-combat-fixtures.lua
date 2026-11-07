#!/usr/bin/env lua
-- Verifies Core's after-combat queue: a change combat held back runs once
-- when combat ends, a key queued twice runs once, a cancelled key never runs,
-- one failing callback doesn't stop the rest, and the end-of-combat event is
-- only listened to while something waits.

local root = assert(arg[1], "usage: lua tools/after-combat-fixtures.lua <addon-root>")

SlashCmdList = {}
floor = math.floor
CarpenterDB = {}
Carpenter = {
    Client = { isMainline = true },
}

local frames = {}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(_, handler) self.onEvent = handler end
    frames[#frames + 1] = frame
    return frame
end

local reportedErrors = {}
function geterrorhandler()
    return function(message) reportedErrors[#reportedErrors + 1] = tostring(message) end
end

local coreChunk = assert(loadfile(root .. "/Core/Carpenter.lua"))
coreChunk("Carpenter", { Private = {} })

local function Listening()
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_REGEN_ENABLED then return true end
    end
    return false
end

-- What the game does when combat ends.
local function EndCombat()
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_REGEN_ENABLED and frame.onEvent then
            frame.onEvent(frame, "PLAYER_REGEN_ENABLED")
        end
    end
end

local calls = {}
local function Record(name)
    return function() calls[#calls + 1] = name end
end

assert(not Listening(), "nothing should listen for the end of combat before a change waits")

-- A waiting change runs once combat ends, then the listener goes quiet.
Carpenter:AfterCombat("scale", Record("scale"))
assert(Listening(), "a waiting change should listen for the end of combat")
EndCombat()
assert(table.concat(calls, ",") == "scale", "the waiting change should run once, got " .. table.concat(calls, ","))
assert(not Listening(), "the listener should stop once the queue is empty")
EndCombat()
assert(#calls == 1, "a change should not run again at the next end of combat")

-- Queuing a key twice runs only the latest callback, once.
calls = {}
Carpenter:AfterCombat("sort", Record("first"))
Carpenter:AfterCombat("sort", Record("second"))
Carpenter:AfterCombat("macros", Record("macros"))
EndCombat()
table.sort(calls)
assert(table.concat(calls, ",") == "macros,second", "expected one run per key, got " .. table.concat(calls, ","))

-- A cancelled change never runs.
calls = {}
Carpenter:AfterCombat("arrow", Record("arrow"))
Carpenter:CancelAfterCombat("arrow")
EndCombat()
assert(#calls == 0, "a cancelled change should not run")

-- One failing callback is reported and the rest still run.
calls = {}
Carpenter:AfterCombat("broken", function() error("boom") end)
Carpenter:AfterCombat("fine", Record("fine"))
EndCombat()
assert(table.concat(calls, ",") == "fine", "a failing callback should not stop the others")
assert(#reportedErrors == 1 and reportedErrors[1]:find("boom", 1, true), "the failure should reach the error handler")

-- A callback that queues itself again waits for the next end of combat.
calls = {}
local retried = false
Carpenter:AfterCombat("retry", function()
    calls[#calls + 1] = "retry"
    if not retried then
        retried = true
        Carpenter:AfterCombat("retry", Record("again"))
    end
end)
EndCombat()
assert(table.concat(calls, ",") == "retry", "the first run should happen once")
assert(Listening(), "a change queued during the run should keep the listener on")
EndCombat()
assert(table.concat(calls, ",") == "retry,again", "the re-queued change should run at the next end of combat")
assert(not Listening(), "the listener should stop once the queue is empty again")

print("after-combat fixtures: passed")
