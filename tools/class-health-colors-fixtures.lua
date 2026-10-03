#!/usr/bin/env lua
-- Verifies Retail-style (Retail and Forever) party class colors tint the fill
-- texture without writing protected StatusBar state or CVars.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local PARTY_ATLAS = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health"
local PARTY_STATUS_ATLAS = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status"
local VEHICLE_ATLAS = "UI-HUD-UnitFrame-Party-PortraitOn-Vehicle-Bar-Health"

local registeredFeature
local playerBar = { applications = 0 }
local cvarWrites = 0
local secretClass = false

function playerBar:SetStatusBarColor()
    self.applications = self.applications + 1
end

function playerBar:SetStatusBarDesaturated() end

local partyTexture = { atlas = PARTY_ATLAS, color = { 1, 1, 1 } }

function partyTexture:SetAtlas(atlas) self.atlas = atlas end
function partyTexture:GetAtlas() return self.atlas end
function partyTexture:SetVertexColor(r, g, b) self.color = { r, g, b } end

local partyBar = { HealthBarTexture = partyTexture, statusBarWrites = 0 }

function partyBar:SetStatusBarColor()
    self.statusBarWrites = self.statusBarWrites + 1
    error("Retail-style party bars must not receive SetStatusBarColor")
end

function partyBar:SetStatusBarDesaturated()
    error("Retail-style party bars must not receive SetStatusBarDesaturated")
end

local member = {
    unit = "party1",
    state = "player",
    frameType = "Party",
    HealthBarContainer = { HealthBar = partyBar },
}

function member:ToPlayerArt()
    self.state = "player"
    partyTexture:SetAtlas(PARTY_ATLAS)
end

function member:ToVehicleArt()
    self.state = "vehicle"
    partyTexture:SetAtlas(VEHICLE_ATLAS)
end

PartyFrame = { MemberFrame1 = member }
TextureKitConstants = { UseAtlasSize = true }

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
                elseif unit == "party1" and not secretClass then
                    return { r = 0.9, g = 0.1, b = 0.3 }
                end
            end,
            Exists = function(unit) return unit == "player" or unit == "party1" end,
            IsPlayer = function(unit) return unit == "player" or unit == "party1" end,
        },
    },
}

Carpenter = {
    Client = { isRetail = true, isForever = true },
    IsEnabled = function(_, key) return key == "classHealthColorsEnabled" and Carpenter.enabled end,
    RegisterFeature = function(_, key, feature)
        if key == "classHealthColorsEnabled" then registeredFeature = feature end
    end,
    enabled = true,
}

C_CVar = {
    GetCVar = function() return "0" end,
    SetCVar = function() cvarWrites = cvarWrites + 1 end,
}

function hooksecurefunc(target, method, hook)
    local original = target[method]
    target[method] = function(...)
        original(...)
        hook(...)
    end
end

function InCombatLockdown() return false end

function CreateFrame()
    local frame = { events = {} }
    function frame:Hide() end
    function frame:Show() end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, handler) self.OnEvent = handler end
    return frame
end

local function AssertColor(expected, message)
    local actual = partyTexture.color
    assert(actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3], message)
end

local sharedChunk = assert(loadfile(repo .. "/Modules/ClassHealthColorsShared.lua"))
sharedChunk("Carpenter", ns)
local unitFramesChunk = assert(loadfile(repo .. "/Modules/ClassHealthColorsUnitFrames.lua"))
unitFramesChunk("Carpenter", ns)

assert(registeredFeature and registeredFeature.Enable, "Class Health Colors feature was not registered")
registeredFeature:Enable()
assert(playerBar.applications == 1, "player health bar should still be class colored")
assert(partyTexture.atlas == PARTY_STATUS_ATLAS, "party fill should switch to the grayscale status atlas")
AssertColor({ 0.9, 0.1, 0.3 }, "party fill should be tinted with the class color")

member:ToPlayerArt()
assert(partyTexture.atlas == PARTY_STATUS_ATLAS, "Blizzard art refresh should be followed by a recolor")
AssertColor({ 0.9, 0.1, 0.3 }, "party fill should keep its class color after an art refresh")

member:ToVehicleArt()
assert(partyTexture.atlas == VEHICLE_ATLAS, "vehicle art must be left to Blizzard")
AssertColor({ 1, 1, 1 }, "vehicle art must not keep the class tint")

member:ToPlayerArt()
AssertColor({ 0.9, 0.1, 0.3 }, "leaving the vehicle should restore the class tint")

registeredFeature:Disable()
Carpenter.enabled = false
assert(partyTexture.atlas == PARTY_ATLAS, "disabling should restore Blizzard's party health atlas")
AssertColor({ 1, 1, 1 }, "disabling should clear the class tint")

member:ToPlayerArt()
assert(partyTexture.atlas == PARTY_ATLAS, "art hooks must stay inert while disabled")

Carpenter.enabled = true
secretClass = true
registeredFeature:Enable()
assert(partyTexture.atlas == PARTY_ATLAS, "secret class tokens should leave Blizzard's art alone")
AssertColor({ 1, 1, 1 }, "secret class tokens should not tint the party fill")
registeredFeature:Disable()

assert(partyBar.statusBarWrites == 0, "party StatusBar colors must never be written")
assert(cvarWrites == 0, "party class colors must not change CVars")

print("class-health-colors fixtures: passed")
