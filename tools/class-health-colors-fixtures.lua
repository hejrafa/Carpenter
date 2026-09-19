#!/usr/bin/env lua
-- Verifies Forever delegates compact party class colors to Blizzard's native
-- CVar without writing protected StatusBar state.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local registeredFeature
local playerBar = { applications = 0 }
local partyFill = {}
local partyOverlay
local partyBar = { statusBarWrites = 0 }
local driver
local inCombat = false
local cvarValue = "0"
local cvarSetCalls = 0
local secureCallCount = 0
local createdFrames = {}

function playerBar:SetStatusBarColor()
    self.applications = self.applications + 1
end

function playerBar:SetStatusBarDesaturated() end

function partyBar:GetStatusBarTexture()
    return partyFill
end

function partyBar:SetStatusBarColor()
    self.statusBarWrites = self.statusBarWrites + 1
    error("Retail compact party bars must not receive SetStatusBarColor")
end

function partyBar:CreateTexture()
    partyOverlay = {
        shown = false,
        SetAllPoints = function(self, anchor) self.anchor = anchor end,
        ClearAllPoints = function(self) self.anchor = nil end,
        SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a } end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
    return partyOverlay
end

local ns = {
    Private = {
        Unit = {
            FrameHealthBar = function(unit)
                if unit == "player" then return playerBar end
                return nil
            end,
            ClassColor = function(unit)
                if unit == "player" then
                    return { r = 0.2, g = 0.4, b = 0.8 }
                end
            end,
            Exists = function(unit) return unit == "player" end,
            IsPlayer = function(unit) return unit == "player" end,
        },
    },
}

Carpenter = {
    Client = { isRetail = true, isForever = false },
    IsEnabled = function(_, key) return key == "classHealthColorsEnabled" end,
    RegisterFeature = function(_, key, feature)
        if key == "classHealthColorsEnabled" then registeredFeature = feature end
    end,
}

C_CVar = {
    GetCVar = function(name)
        assert(name == "raidFramesDisplayClassColor")
        return cvarValue
    end,
    SetCVar = function(name, value)
        assert(name == "raidFramesDisplayClassColor")
        cvarValue = value
        cvarSetCalls = cvarSetCalls + 1
    end,
}

function securecallfunction(func, ...)
    secureCallCount = secureCallCount + 1
    return func(...)
end

function InCombatLockdown()
    return inCombat
end

PartyFrame = {
    MemberFrame1 = { HealthBar = partyBar, unit = "player" },
}

function CreateFrame()
    driver = { events = {} }
    function driver:Hide() end
    function driver:Show() end
    function driver:RegisterEvent(event) self.events[event] = true end
    function driver:RegisterUnitEvent(event) self.events[event] = true end
    function driver:UnregisterAllEvents() self.events = {} end
    function driver:SetScript(_, handler) self.OnEvent = handler end
    createdFrames[#createdFrames + 1] = driver
    return driver
end

local sharedChunk = assert(loadfile(repo .. "/Modules/ClassHealthColorsShared.lua"))
sharedChunk("Carpenter", ns)
local unitFramesChunk = assert(loadfile(repo .. "/Modules/ClassHealthColorsUnitFrames.lua"))
unitFramesChunk("Carpenter", ns)

assert(registeredFeature and registeredFeature.Enable, "Class Health Colors feature was not registered")
registeredFeature:Enable()
assert(playerBar.applications == 1, "Retail should still color the player health bar")
assert(partyBar.statusBarWrites == 0, "Retail must not write compact party StatusBar colors")
assert(partyOverlay == nil, "Retail must not add regions to compact party health bars")
assert(cvarSetCalls == 0, "mainline must not change the Forever party class-color CVar")

registeredFeature:Disable()
assert(partyBar.statusBarWrites == 0, "disabling must not write compact party StatusBar colors")

Carpenter.Client.isForever = true
playerBar.applications = 0
registeredFeature:Enable()
assert(playerBar.applications == 1, "Forever should still color the player health bar")
assert(partyBar.statusBarWrites == 0, "Forever must not write compact party StatusBar colors")
assert(partyOverlay == nil, "Forever must not add regions to compact party health bars")
assert(cvarValue == "1", "Forever should enable Blizzard's native party class colors")
assert(secureCallCount > 0, "Forever must change the class-color CVar through securecallfunction")

registeredFeature:Disable()
assert(partyBar.statusBarWrites == 0, "Forever disabling must not write compact party StatusBar colors")
assert(cvarValue == "0", "Forever should restore the original party class-color CVar")

inCombat = true
registeredFeature:Enable()
assert(cvarValue == "0", "Forever must defer its class-color CVar change during combat")
inCombat = false
assert(createdFrames[1] and createdFrames[1].OnEvent, "Forever CVar driver was not installed")
createdFrames[1].OnEvent(createdFrames[1], "PLAYER_REGEN_ENABLED")
assert(cvarValue == "1", "Forever should apply deferred class colors after combat")
registeredFeature:Disable()
assert(cvarValue == "0", "Forever should restore the CVar after a deferred enable")

print("class-health-colors fixtures: passed")
