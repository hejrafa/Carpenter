#!/usr/bin/env lua
-- Verifies action-button text is changed only outside combat and without hooks.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local eventFrame
local inCombat = false
local hookCount = 0
local secureCallCount = 0

local function NewTextRegion()
    return {
        alpha = 1,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
    }
end

local macroName = NewTextRegion()
local hotkey = NewTextRegion()
local button = { GetName = function() return "ActionButton1" end }
local stanceBar = {
    alpha = 1,
    SetAlpha = function(self, alpha) self.alpha = alpha end,
    GetAlpha = function(self) return self.alpha end,
    Hide = function() error("protected stance bars must not be hidden") end,
    SetParent = function() error("protected stance bars must not be reparented") end,
}

ActionButton1 = button
ActionButton1Name = macroName
ActionButton1HotKey = hotkey
StanceBar = stanceBar

CarpenterDB = {}
Carpenter = {
    Client = { isRetail = false },
    IsEnabled = function(_, key)
        return key == "hideMacroNamesEnabled"
            or key == "hideKeybindsEnabled"
            or key == "hideStanceBarEnabled"
    end,
}

function InCombatLockdown()
    return inCombat
end

function hooksecurefunc()
    hookCount = hookCount + 1
end

function securecallfunction(method, object, ...)
    secureCallCount = secureCallCount + 1
    return method(object, ...)
end

function CreateFrame()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:SetScript(_, handler) self.OnEvent = handler end
    return eventFrame
end

local chunk = assert(loadfile(repo .. "/Modules/HideUIElements.lua"))
chunk("Carpenter", {})

assert(eventFrame and eventFrame.OnEvent, "HideUIElements event handler was not installed")
eventFrame.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
assert(macroName.alpha == 0, "macro names should be hidden outside combat")
assert(hotkey.alpha == 0, "hotkeys should be hidden outside combat")
assert(stanceBar.alpha == 0, "stance bar should be visually hidden outside combat")
assert(hookCount == 0, "action-button text methods must not be hooked")

macroName.alpha = 1
hotkey.alpha = 1
inCombat = true
eventFrame.OnEvent(eventFrame, "UPDATE_SHAPESHIFT_FORMS")
assert(macroName.alpha == 1, "macro names must not be changed during combat")
assert(hotkey.alpha == 1, "hotkeys must not be changed during combat")

inCombat = false
eventFrame.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(macroName.alpha == 0, "macro names should be reapplied after combat")
assert(hotkey.alpha == 0, "hotkeys should be reapplied after combat")

Carpenter.Client.isRetail = true
macroName.alpha = 1
hotkey.alpha = 1
eventFrame.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
assert(macroName.alpha == 1, "Retail must not modify protected macro-name regions")
assert(hotkey.alpha == 1, "Retail must not modify protected hotkey regions")

Carpenter.Client.isForever = true
eventFrame.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
assert(macroName.alpha == 0, "Forever should hide macro names through a secure call")
assert(hotkey.alpha == 0, "Forever should hide hotkeys through a secure call")
assert(secureCallCount > 0, "Forever action-button text writes must use securecallfunction")

print("hide-ui-elements fixtures: passed")
