#!/usr/bin/env lua
-- Pins Action Cam's mounted zoom: the camera always comes back to the distance
-- from before mounting, including when a flight path follows a ground mount.
-- Flight paths count as mounted, as IsMounted() stays true on them.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

-- A small game: a camera, a clock, and the mount state.
local now = 0
local timers = {}
local zoom = 6
local mounted = false
local createdFrames = {}

function GetCameraZoom() return zoom end
function CameraZoomIn(amount) zoom = zoom - amount end
function CameraZoomOut(amount) zoom = zoom + amount end
function IsMounted() return mounted end
function SetCVar() end
function GetCVar() end
function SetView() end

C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
}

function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

UIParent = {
    scripts = {},
    HookScript = function(self, script, handler) self.scripts[script] = handler end,
}

CarpenterDB = { actionCamEnabled = true }
Carpenter = {
    Client = { isMainline = true, isForever = true },
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function() end,
}
Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/ActionCam.lua"))("Carpenter", {})

local frame = createdFrames[1]
local function Fire(event, ...)
    frame.scripts.OnEvent(frame, event, ...)
end

local function Run(seconds)
    local stop = now + seconds
    while now < stop do
        now = now + 0.01
        local pending = timers
        timers = {}
        for _, timer in ipairs(pending) do
            if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
        end
    end
end

local function SetMounted(state)
    mounted = state
    Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
end

local function CheckZoom(expected, message)
    assert(math.abs(zoom - expected) < 0.01, message .. ": expected " .. expected .. ", got " .. zoom)
end

Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD")
Run(0.5)
CheckZoom(6, "starting up on foot should leave the camera alone")

-- Mounting and dismounting comes back to where it started.
SetMounted(true)
Run(2)
CheckZoom(10, "mounting should move to the mounted distance")
SetMounted(false)
Run(2)
CheckZoom(6, "dismounting should come back")

-- Riding up to a flight master: the flight dismounts you, the camera starts back,
-- and the flight then counts as mounting again partway through.
SetMounted(true)
Run(2)
SetMounted(false)
Run(0.75)
assert(zoom < 10 and zoom > 6, "the camera should be partway back when the flight starts")
SetMounted(true)
Run(30)
CheckZoom(10, "the flight should use the mounted distance")
SetMounted(false)
Run(2)
CheckZoom(6, "landing should come back to the distance from before the mount")

-- Moving the camera mid-flight doesn't change where landing comes back to.
SetMounted(true)
Run(2)
CameraZoomOut(5)
Run(2)
SetMounted(false)
Run(2)
CheckZoom(6, "landing should ignore zooming during the flight")

-- Hiding and showing the UI mid-flight keeps the saved distance.
SetMounted(true)
Run(2)
UIParent.scripts.OnHide()
UIParent.scripts.OnShow()
Run(2)
CheckZoom(10, "showing the UI should keep the mounted distance")
SetMounted(false)
Run(2)
CheckZoom(6, "landing after hiding the UI should come back")

-- Landing is noticed from control coming back, without a mount event.
SetMounted(true)
Run(2)
mounted = false
Fire("PLAYER_CONTROL_GAINED")
Run(2)
CheckZoom(6, "getting control back should count as landing")

-- The model changing back counts too.
SetMounted(true)
Run(2)
mounted = false
Fire("UNIT_MODEL_CHANGED", "player")
Run(2)
CheckZoom(6, "the model changing back should count as landing")

-- An event just before the check restarts the wait: the mount state only catches
-- up after the second event here.
SetMounted(true)
Run(2)
Fire("UNIT_MODEL_CHANGED", "player")
Run(0.2)
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
Run(0.1)
mounted = false
Run(2)
CheckZoom(6, "the check should wait for the last event")

-- A different starting distance is kept too, including one past the mounted one.
CameraZoomOut(14)
Run(0.5)
SetMounted(true)
Run(2)
CheckZoom(10, "mounting from further away should move in")
SetMounted(false)
Run(2)
CheckZoom(20, "dismounting should go back out")

-- Turned off, mounting leaves the camera alone.
CarpenterDB.actionCamEnabled = false
SetMounted(true)
Run(2)
CheckZoom(20, "mounting with Action Cam off should not move the camera")

print("action cam zoom fixtures: passed")
