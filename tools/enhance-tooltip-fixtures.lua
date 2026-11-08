#!/usr/bin/env lua
-- Offline fixture checks for Enhance Tooltip's level lines: the class is appended
-- when the game shows "Level 60 Orc Priest" alone, and left off when the game
-- already lists the class on its own spec line ("Shadow Priest"). A level the game
-- hides as "??" stays hidden, for players and mobs alike.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end
local H = dofile(repo .. "/tools/fixture-harness.lua")(repo, "enhance-tooltip")
local fail, assertEqual = H.fail, H.assertEqual

unpack = unpack or table.unpack


local function stripColors(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

LEVEL = "Level"
function GetLocale() return "enUS" end
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 } }
function GetCreatureDifficultyColor() return { r = 1, g = 1, b = 0 } end
function hooksecurefunc() end

local target = { exists = true, player = true, name = "Thrall", class = "Priest", token = "PRIEST", race = "Orc", level = 60 }
function UnitExists(unit) return unit == "player" or (unit == "target" and target.exists) end
function UnitIsPlayer(unit) return unit == "target" and target.player end
function UnitClass() return target.class, target.token end
function UnitRace() return target.race end
function UnitLevel() return target.level end
function UnitName(unit) return unit == "target" and target.name or nil end
function UnitReaction() return target.reaction or 5 end
function UnitIsDeadOrGhost() return false end
function UnitIsPVP() return false end
function UnitIsUnit() return false end
function UnitCanAttack() return target.canAttack == true end
function UnitPlayerControlled() return target.player == true end
function UnitCreatureType() return target.creatureType end
function UnitClassification() return target.classification end

local function NewFontString()
    local fontString = { text = "" }
    function fontString:SetText(text) self.text = text end
    function fontString:GetText() return self.text end
    function fontString:SetTextColor() end
    return fontString
end

local scripts = {}
GameTooltip = {
    lines = {},
    HasScript = function(_, name) return name == "OnTooltipSetUnit" end,
    HookScript = function(_, name, handler) scripts[name] = handler end,
    GetUnit = function() return target.name, "target" end,
    GetChildren = function() return end,
    NumLines = function(self) return #self.lines end,
    IsShown = function() return true end,
    Show = function() end,
    AddLine = function(self, text)
        local line = NewFontString()
        line:SetText(text)
        self.lines[#self.lines + 1] = line
        _G["GameTooltipTextLeft" .. #self.lines] = line
    end,
}

local function SetTooltipLines(...)
    for i = 1, #GameTooltip.lines do
        _G["GameTooltipTextLeft" .. i] = nil
    end
    GameTooltip.lines = {}
    for _, text in ipairs({ ... }) do
        GameTooltip:AddLine(text)
    end
end

local function TooltipText()
    local out = {}
    for i, line in ipairs(GameTooltip.lines) do
        out[i] = stripColors(line:GetText())
    end
    return out
end

local eventHandler
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, handler) eventHandler = handler end,
    }
end

CarpenterDB = { enhanceTooltipEnabled = true }
Carpenter = {
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function() end,
    Client = { isMainline = false },
}

local ns = { Private = {} }
assert(loadfile(repo .. "/Core/Unit.lua"))("Carpenter", ns)
Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/EnhanceTooltip.lua"))("Carpenter", ns)
eventHandler(nil, "PLAYER_LOGIN")
assert(scripts.OnTooltipSetUnit, "module should hook OnTooltipSetUnit")

-- Classic-style tooltip: the game puts the class on the level line, so keep it.
SetTooltipLines("Thrall", "Level 60 Orc Priest")
scripts.OnTooltipSetUnit(GameTooltip)
local text = TooltipText()
assertEqual(text[2], "Level 60 Orc Priest", "class stays on the level line without a spec line")

-- Reapplying over our own output must not duplicate or drop anything.
scripts.OnTooltipSetUnit(GameTooltip)
text = TooltipText()
assertEqual(text[2], "Level 60 Orc Priest", "reapply keeps the level line stable")

-- Retail/Forever-style tooltip: the game lists the spec and class on its own
-- line, so the level line must not repeat the class.
SetTooltipLines("Thrall", "Level 60 Orc Priest", "Shadow Priest")
scripts.OnTooltipSetUnit(GameTooltip)
text = TooltipText()
assertEqual(text[2], "Level 60 Orc", "class is dropped from the level line when a spec line exists")
assertEqual(text[3], "Shadow Priest", "spec line is left alone")

scripts.OnTooltipSetUnit(GameTooltip)
text = TooltipText()
assertEqual(text[2], "Level 60 Orc", "reapply with a spec line keeps the class off the level line")
assertEqual(text[3], "Shadow Priest", "reapply leaves the spec line alone")

-- A guild name that merely contains the class name is not a spec line.
SetTooltipLines("Thrall", "Priests of the Moon", "Level 60 Orc Priest")
scripts.OnTooltipSetUnit(GameTooltip)
text = TooltipText()
assertEqual(text[2], "Priests of the Moon", "guild line is left alone")
assertEqual(text[3], "Level 60 Orc Priest", "class stays when only a guild line mentions it")

-- Guild line plus a real spec line.
SetTooltipLines("Thrall", "Priests of the Moon", "Level 60 Orc Priest", "Shadow Priest")
scripts.OnTooltipSetUnit(GameTooltip)
text = TooltipText()
assertEqual(text[3], "Level 60 Orc", "class is dropped with a guild line and a spec line")
assertEqual(text[4], "Shadow Priest", "spec line survives under a guild line")

-- The game writes "??" for a unit too far above the player, even when UnitLevel
-- still returns the real level. Its line decides, so the number stays hidden.
local function Hover(...)
    SetTooltipLines(...)
    scripts.OnTooltipSetUnit(GameTooltip)
    return TooltipText()
end
local function RawLine(index)
    return GameTooltip.lines[index]:GetText()
end

text = Hover("Thrall", "Level ?? Orc Priest")
assertEqual(text[2], "Level ?? Orc Priest", "a player the game hides keeps ?? over the real level")
assert(RawLine(2):find("|cffff3333", 1, true), "a hidden level should be red")
scripts.OnTooltipSetUnit(GameTooltip)
assertEqual(TooltipText()[2], "Level ?? Orc Priest", "reapply keeps a hidden player level hidden")

text = Hover("Thrall", "Level ?? Orc Priest", "Shadow Priest")
assertEqual(text[2], "Level ?? Orc", "a hidden level drops the class when a spec line exists")

-- Only the level line counts: "??" elsewhere says nothing about the level.
text = Hover("Thrall", "What?? Guild", "Level 60 Orc Priest")
assertEqual(text[2], "What?? Guild", "a guild line with ?? is left alone")
assertEqual(text[3], "Level 60 Orc Priest", "a guild line with ?? doesn't hide the level")

target.level = -1
text = Hover("Thrall", "Level 60 Orc Priest")
assertEqual(text[2], "Level ?? Orc Priest", "a level of -1 still reads as ??")

-- A hostile mob, in range: the number stays, in its difficulty color.
target.player, target.reaction, target.canAttack = false, 2, true
target.name, target.creatureType, target.classification = "Ravenclaw Guardian", "Undead", "normal"
target.level = 20
text = Hover("Ravenclaw Guardian", "Level 20 Undead")
assertEqual(text[2], "Level 20 Undead ", "a mob in range shows its level")
assert(RawLine(2):find("|cffffff00", 1, true), "a mob in range keeps its difficulty color")

-- Too far above the player: hidden, whatever UnitLevel returns.
target.level = 40
text = Hover("Ravenclaw Guardian", "Level ?? Undead")
assertEqual(text[2], "Level ?? Undead ", "a mob the game hides keeps ?? over the real level")
assert(RawLine(2):find("|cffff3333", 1, true), "a hidden mob level should be red")
scripts.OnTooltipSetUnit(GameTooltip)
assertEqual(TooltipText()[2], "Level ?? Undead ", "reapply keeps a hidden mob level hidden")

target.classification = "elite"
text = Hover("Ravenclaw Guardian", "Level ?? Elite Undead")
assertEqual(text[2], "Level ?? Undead (Elite) ", "a hidden elite keeps its classification")

-- The level line can sit below a subtitle, which may itself hold "??".
target.classification = "normal"
text = Hover("Ravenclaw Guardian", "<Keeper??>", "Level 40 Undead")
assertEqual(text[2], "<Keeper??>", "a subtitle is left alone")
assertEqual(text[3], "Level 40 Undead ", "a subtitle with ?? doesn't hide the level")

text = Hover("Ravenclaw Guardian", "<Keeper>", "Level ?? Undead")
assertEqual(text[3], "Level ?? Undead ", "a hidden level is found below a subtitle")

target.level = -1
text = Hover("Ravenclaw Guardian", "Level 40 Undead")
assertEqual(text[2], "Level ?? Undead ", "a mob level of -1 still reads as ??")

-- No level line: nothing is written.
target.level = 20
text = Hover("Ravenclaw Guardian", "Undead")
assertEqual(text[2], "Undead", "a tooltip without a level line is left alone")

print("enhance-tooltip fixtures passed")
