#!/usr/bin/env lua
-- Offline fixture checks for Hide Surnames: first names on unit frames and
-- nameplates, NPCs and hidden names left alone, and Blizzard's text put back.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

unpack = unpack or table.unpack

local function fail(message)
    io.stderr:write("hide-surnames fixture failed: " .. message .. "\n")
    os.exit(1)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

function wipe(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

local SECRET_NAME = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(value)
    return value == SECRET_NAME
end

-- Forever returns the first name and surname separately.
local units = {
    target = { player = true, name = "Koji", surname = "Kurosawa" },
    focus = { player = false, name = "Hogger" },
    nameplate1 = { player = true, name = "Aiko", surname = "Tanaka" },
    nameplate2 = { player = true, name = SECRET_NAME, surname = SECRET_NAME },
}

function UnitIsPlayer(unit)
    return units[unit] ~= nil and units[unit].player
end

function UnitName(unit)
    local info = units[unit]
    if not info then return nil end
    return info.name, info.surname
end

local function FullName(unit)
    local info = units[unit]
    if info.surname then return info.name .. " " .. info.surname end
    return info.name
end

local function NewFontString()
    local fontString = { text = "", shown = true }
    function fontString:SetText(text) self.text = text end
    function fontString:GetText() return self.text end
    function fontString:IsShown() return self.shown end
    return fontString
end

local function NewUnitFrame(unit)
    return { unit = unit, name = NewFontString() }
end

-- Stand-ins for Blizzard's name writers, which Forever fills with the full name.
function UnitFrame_Update(frame)
    frame.name:SetText(FullName(frame.overrideName or frame.unit))
end

function CompactUnitFrame_UpdateName(frame, show)
    if frame.UpdateNameOverride and frame:UpdateNameOverride() then return end
    if show == false then
        frame.name.shown = false
        return
    end
    if units[frame.unit].name ~= SECRET_NAME then
        frame.name:SetText(FullName(frame.unit))
    end
    frame.name.shown = true
end

function hooksecurefunc(name, handler)
    local original = _G[name]
    _G[name] = function(...)
        local results = { original(...) }
        handler(...)
        return unpack(results)
    end
end

local registeredFeature
CarpenterDB = { hideSurnamesEnabled = true }
Carpenter = {
    IsEnabled = function(_, key)
        return CarpenterDB[key] == true
    end,
    RegisterFeature = function(_, key, feature)
        if key == "hideSurnamesEnabled" then
            registeredFeature = feature
        end
    end,
    SafeHook = function(_, target, handler)
        if type(_G[target]) ~= "function" then return false end
        hooksecurefunc(target, handler)
        return true
    end,
}

TargetFrame = NewUnitFrame("target")
FocusFrame = NewUnitFrame("focus")
local plate1 = { UnitFrame = NewUnitFrame("nameplate1") }
local plate2 = { UnitFrame = NewUnitFrame("nameplate2") }
C_NamePlate = { GetNamePlates = function() return { plate1, plate2 } end }

-- Names already on screen before the option turns on.
UnitFrame_Update(TargetFrame)
CompactUnitFrame_UpdateName(plate1.UnitFrame)

local ns = { Private = {} }
assert(loadfile(repo .. "/Core/Nameplates.lua"))("Carpenter", ns)
Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/HideSurnames.lua"))("Carpenter", ns)
if not registeredFeature then fail("Hide Surnames did not register its feature") end

registeredFeature:Enable()
assertEqual(TargetFrame.name.text, "Koji", "enabling did not shorten the target name already shown")
assertEqual(plate1.UnitFrame.name.text, "Aiko", "enabling did not shorten the nameplate already shown")

UnitFrame_Update(FocusFrame)
assertEqual(FocusFrame.name.text, "Hogger", "NPC names must stay as Blizzard wrote them")

TargetFrame.unit = "focus"
UnitFrame_Update(TargetFrame)
assertEqual(TargetFrame.name.text, "Hogger", "a unit frame that switched to an NPC kept a player's name")
TargetFrame.unit = "target"
UnitFrame_Update(TargetFrame)
assertEqual(TargetFrame.name.text, "Koji", "unit frame update did not shorten the player's name")

CompactUnitFrame_UpdateName(plate2.UnitFrame)
assertEqual(plate2.UnitFrame.name.text, SECRET_NAME, "secret first names should still reach SetText")

plate1.UnitFrame.name:SetText("Hidden Text")
CompactUnitFrame_UpdateName(plate1.UnitFrame, false)
assertEqual(plate1.UnitFrame.name.text, "Hidden Text", "hidden nameplate names must not be rewritten")
CompactUnitFrame_UpdateName(plate1.UnitFrame)
assertEqual(plate1.UnitFrame.name.text, "Aiko", "nameplate update did not shorten the player's name")

local preview = NewUnitFrame("nameplate1")
preview.UpdateNameOverride = function(frame)
    frame.name:SetText("Preview Name")
    return false
end
CompactUnitFrame_UpdateName(preview)
assertEqual(preview.name.text, "Aiko Tanaka", "frames with a name override must keep Blizzard's name")

local forbidden = NewUnitFrame("nameplate1")
forbidden.IsForbidden = function() return true end
CompactUnitFrame_UpdateName(forbidden)
assertEqual(forbidden.name.text, "Aiko Tanaka", "forbidden frames must not be touched")

CarpenterDB.hideSurnamesEnabled = false
registeredFeature:Disable()
assertEqual(TargetFrame.name.text, "Koji Kurosawa", "disabling did not restore the target's full name")
assertEqual(plate1.UnitFrame.name.text, "Aiko Tanaka", "disabling did not restore the nameplate's full name")
assertEqual(FocusFrame.name.text, "Hogger", "disabling rewrote an NPC name")

UnitFrame_Update(TargetFrame)
assertEqual(TargetFrame.name.text, "Koji Kurosawa", "hooks kept shortening names after disabling")

print("hide-surnames fixtures: passed")
