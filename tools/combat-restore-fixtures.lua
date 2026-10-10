#!/usr/bin/env lua
-- Verifies features turned off in combat restore their frames once combat ends.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local inCombat = false
local pendingTimers = {}
local eventFrames = {}

local function NewFrame(protected)
    local frame = {
        alpha = 1,
        scale = 1,
        mouse = true,
        shown = true,
        events = {},
    }
    function frame:IsProtected() return protected end
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:GetScale() return self.scale end
    function frame:SetScale(scale)
        assert(not (protected and inCombat), "protected frame rescaled in combat")
        self.scale = scale
    end
    function frame:EnableMouse(enabled)
        assert(not (protected and inCombat), "protected frame mouse changed in combat")
        self.mouse = enabled
    end
    function frame:SetMouseClickEnabled(enabled)
        assert(not (protected and inCombat), "protected frame clicks changed in combat")
        self.mouse = enabled
    end
    function frame:IsShown() return self.shown end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, handler) self.handler = handler end
    function frame:HookScript() end
    return frame
end

function CreateFrame()
    local frame = NewFrame(false)
    eventFrames[#eventFrames + 1] = frame
    return frame
end

function InCombatLockdown() return inCombat end
function hooksecurefunc() end
C_Timer = {
    After = function(_, callback)
        pendingTimers[#pendingTimers + 1] = callback
    end,
}

local function RunTimers()
    while #pendingTimers > 0 do
        local timers = pendingTimers
        pendingTimers = {}
        for _, callback in ipairs(timers) do
            callback()
        end
    end
end

local function Fire(event)
    for _, frame in ipairs(eventFrames) do
        if frame.events[event] and frame.handler then
            frame.handler(frame, event)
        end
    end
    RunTimers()
end

CarpenterDB = {}
Carpenter = {
    Client = { isRetail = true },
    Features = {},
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(self, key, feature) self.Features[key] = feature end,
    After = function(_, _, callback) pendingTimers[#pendingTimers + 1] = callback end,
}

local function Toggle(key, enabled)
    CarpenterDB[key] = enabled
    local feature = Carpenter.Features[key]
    if enabled then feature:Enable() else feature:Disable() end
    RunTimers()
end

local bossFrame = NewFrame(true)
local ns = {
    Private = {
        RetailUnitFrameCleanerTargets = {
            GetBossFrames = function() return { bossFrame } end,
        },
        RetailUnitFrameCleanerRealm = {
            Apply = function() end,
            ApplyForUnit = function() end,
        },
    },
}
setmetatable(ns.Private.RetailUnitFrameCleanerTargets, {
    __index = function() return function() return {} end end,
})

local function Load(path)
    local chunk = assert(loadfile(repo .. "/" .. path))
    chunk("Carpenter", ns)
end

Load("Modules/RetailUnitFrameCleanerVisuals.lua")
Load("Modules/RetailUnitFrameCleaner.lua")

ExtraActionBarFrame = NewFrame(true)
Load("Modules/ExtraAbilityScale.lua")

-- Hide Boss Frames: turned off in combat, restored after combat.
Toggle("hideBossFramesEnabled", true)
assert(bossFrame.alpha == 0 and bossFrame.mouse == false, "boss frames should hide")

inCombat = true
Toggle("hideBossFramesEnabled", false)
assert(bossFrame.alpha == 0, "boss frames should wait for combat to end")

inCombat = false
Fire("PLAYER_REGEN_ENABLED")
assert(bossFrame.alpha == 1 and bossFrame.mouse == true, "boss frames should restore after combat")

-- Extra Ability Scale: turned off in combat, restored after combat.
Toggle("scaleExtraAbilityEnabled", true)
assert(math.abs(ExtraActionBarFrame.scale - 0.8) < 0.001, "extra ability should scale down")

inCombat = true
Toggle("scaleExtraAbilityEnabled", false)
assert(math.abs(ExtraActionBarFrame.scale - 0.8) < 0.001, "extra ability should wait for combat to end")

inCombat = false
Fire("PLAYER_REGEN_ENABLED")
assert(ExtraActionBarFrame.scale == 1, "extra ability should restore after combat")

print("combat restore fixtures passed")
