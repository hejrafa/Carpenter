#!/usr/bin/env lua
-- Offline fixture checks for Action Cam CVar and warning ownership.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local createdFrames = {}
local cvarWrites = {}
local uiWarningUnregisters = 0
local internalWarningUnregisters = 0

CarpenterDB = { actionCamEnabled = false }
Carpenter = {
    Client = { isRetail = true },
    IsEnabled = function(_, key)
        return CarpenterDB[key] == true
    end,
    Profile = function(_, _, callback, ...)
        return callback(...)
    end,
}

UIParent = {
    scripts = {},
    UnregisterEvent = function(_, event)
        if event == "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED" then
            uiWarningUnregisters = uiWarningUnregisters + 1
        end
    end,
    HookScript = function(self, script, handler)
        self.scripts[script] = handler
    end,
}

GameEvent = {
    UnregisterInternalEvent = function(event)
        if event == "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED" then
            internalWarningUnregisters = internalWarningUnregisters + 1
        end
    end,
}

C_Timer = {
    After = function(_, callback)
        callback()
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

function SetCVar(name, value)
    cvarWrites[#cvarWrites + 1] = { name = name, value = value }
end

local function loadAddonFile(path)
    local chunk, err = loadfile(repo .. "/" .. path)
    if not chunk then error(err) end
    return chunk("Carpenter", {})
end

local function fail(message)
    io.stderr:write("action-cam fixture failed: " .. message .. "\n")
    os.exit(1)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

local function fire(frame, event, ...)
    local handler = frame.scripts.OnEvent
    if not handler then fail("frame has no OnEvent handler") end
    handler(frame, event, ...)
end

loadAddonFile("Modules/ActionCam.lua")

local eventFrame = createdFrames[1]
if not eventFrame then fail("Action Cam did not create its event frame") end

-- A normal login and reload with the option off must not touch experimental
-- camera state or take ownership of Blizzard's warning handler.
fire(eventFrame, "ADDON_LOADED", "Carpenter")
fire(eventFrame, "PLAYER_LOGIN")
fire(eventFrame, "PLAYER_ENTERING_WORLD")
assertEqual(#cvarWrites, 0, "disabled startup wrote camera CVars")
assertEqual(uiWarningUnregisters, 0, "disabled startup unregistered the UIParent warning")
assertEqual(internalWarningUnregisters, 0, "disabled startup unregistered the 12.1 warning")

-- Enabling Action Cam is the first point at which Carpenter may write camera
-- CVars and suppress the corresponding warning.
CarpenterDB.actionCamEnabled = true
Carpenter_ApplyActionCam()
assertEqual(#cvarWrites, 7, "enabling Action Cam did not apply all camera settings")
assertEqual(uiWarningUnregisters, 1, "enabling Action Cam did not suppress the UIParent warning")
assertEqual(internalWarningUnregisters, 1, "enabling Action Cam did not suppress the 12.1 warning")

-- Turning it off restores Carpenter's six experimental CVars exactly once.
CarpenterDB.actionCamEnabled = false
Carpenter_ApplyActionCam()
assertEqual(#cvarWrites, 13, "disabling Action Cam did not restore its experimental CVars")
Carpenter_ApplyActionCam()
assertEqual(#cvarWrites, 13, "disabled refresh rewrote camera CVars")

-- The text-error fallback follows the same ownership rule: with Action Cam off,
-- Carpenter must pass an experimental-camera warning through to Blizzard.
local passedErrorMessages = 0
UIErrorsFrame = {
    onEvent = function(_, event)
        if event == "UI_ERROR_MESSAGE" then
            passedErrorMessages = passedErrorMessages + 1
        end
    end,
    GetScript = function(self, script)
        if script == "OnEvent" then return self.onEvent end
    end,
    SetScript = function(self, script, handler)
        if script == "OnEvent" then self.onEvent = handler end
    end,
}

loadAddonFile("Modules/HideErrorMessages.lua")
local warning = "You have enabled one or more experimental camera features, which may contribute to visual discomfort."
UIErrorsFrame:onEvent("UI_ERROR_MESSAGE", 1, warning)
assertEqual(passedErrorMessages, 1, "disabled Action Cam hid Blizzard's warning text")

CarpenterDB.actionCamEnabled = true
UIErrorsFrame:onEvent("UI_ERROR_MESSAGE", 1, warning)
assertEqual(passedErrorMessages, 1, "enabled Action Cam did not hide its warning text")

print("action-cam fixtures: passed")
