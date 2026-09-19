#!/usr/bin/env lua
-- Verifies Forever colors compact party frames without writing StatusBar state.

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

function playerBar:SetStatusBarColor()
    self.applications = self.applications + 1
end

function playerBar:SetStatusBarDesaturated() end

function partyBar:GetStatusBarTexture()
    return partyFill
end

function partyBar:SetStatusBarColor()
    self.statusBarWrites = self.statusBarWrites + 1
    error("Forever compact party bars must not receive SetStatusBarColor")
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
    Client = { isRetail = true, isForever = true },
    IsEnabled = function(_, key) return key == "classHealthColorsEnabled" end,
    RegisterFeature = function(_, key, feature)
        if key == "classHealthColorsEnabled" then registeredFeature = feature end
    end,
}

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
    return driver
end

local sharedChunk = assert(loadfile(repo .. "/Modules/ClassHealthColorsShared.lua"))
sharedChunk("Carpenter", ns)
local unitFramesChunk = assert(loadfile(repo .. "/Modules/ClassHealthColorsUnitFrames.lua"))
unitFramesChunk("Carpenter", ns)

assert(registeredFeature and registeredFeature.Enable, "Class Health Colors feature was not registered")
registeredFeature:Enable()
assert(playerBar.applications == 1, "Forever should still color the player health bar")
assert(partyBar.statusBarWrites == 0, "Forever must not write compact party StatusBar colors")
assert(partyOverlay and partyOverlay.shown, "Forever should show the safe party-frame color overlay")
assert(partyOverlay.anchor == partyFill, "party-frame overlay should follow Blizzard's health fill")
assert(partyOverlay.color[1] == 0.2 and partyOverlay.color[2] == 0.4 and partyOverlay.color[3] == 0.8,
    "party-frame overlay should use the unit class color")

registeredFeature:Disable()
assert(not partyOverlay.shown, "disabling should hide the party-frame color overlay")
assert(partyBar.statusBarWrites == 0, "disabling must not write compact party StatusBar colors")

print("class-health-colors fixtures: passed")
