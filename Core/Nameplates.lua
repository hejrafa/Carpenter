--[[ Carpenter - safe nameplate helpers ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Nameplates = ns.Private.Nameplates or {}
ns.Private.Nameplates = Nameplates

-- Shared look for Carpenter's aura icons on every client: the target frame's
-- debuff outline, and outlined white timer and stack numbers.
local AURA_BORDER_TEXTURE = "Interface\\Buttons\\UI-Debuff-Overlays"
local AURA_BORDER_TEX_COORDS = { 0.296875, 0.5703125, 0, 0.515625 }
Nameplates.AURA_TIMER_TEXT_SIZE = 12
Nameplates.AURA_STACK_TEXT_SIZE = 11

function Nameplates.StyleAuraBorder(texture)
    texture:SetTexture(AURA_BORDER_TEXTURE)
    texture:SetTexCoord(AURA_BORDER_TEX_COORDS[1], AURA_BORDER_TEX_COORDS[2], AURA_BORDER_TEX_COORDS[3], AURA_BORDER_TEX_COORDS[4])
end

function Nameplates.StyleAuraText(text, size)
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 0.9)
    text:SetShadowOffset(1, -1)
end

-- Matches the Classic nameplate timer: a plain number of seconds under a
-- minute, then whole minutes and hours, rounded up ("12", "2m", "1h").
local function CreateClassicDurationFormatter()
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local roundUp = Enum.NumericRuleFormatRounding.Up
    formatter:SetBreakpoints({
        { threshold = 0, step = 1, rounding = roundUp, format = "%d" },
        { threshold = 60, format = "%dm", components = { { div = 60, step = 1, rounding = roundUp } } },
        { threshold = 3600, format = "%dh", components = { { div = 3600, step = 1, rounding = roundUp } } },
    })
    return formatter
end

-- Fallback with a unit suffix on every value ("12s", "2m", "1h").
local function CreateSecondsDurationFormatter()
    local intervalCurve = C_CurveUtil.CreateCurve()
    intervalCurve:SetType(Enum.LuaCurveType.Step)
    intervalCurve:AddPoint(0, Enum.SecondsFormatterInterval.Seconds)
    intervalCurve:AddPoint(60, Enum.SecondsFormatterInterval.Minutes)
    intervalCurve:AddPoint(3600, Enum.SecondsFormatterInterval.Hours)

    local formatter = C_StringUtil.CreateSecondsFormatter()
    formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
    formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.StripIgnoreLocale)
    formatter:SetRounding(Enum.SecondsFormatterRounding.RoundUp)
    formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    formatter:SetMaxIntervalCurve(intervalCurve)
    formatter:SetDesiredUnitCount(1)
    return formatter
end

local durationFormatter
-- Built on first use: the formatter APIs only exist on Retail-style clients.
function Nameplates.GetAuraDurationFormatter()
    if durationFormatter == nil then
        local ok, formatter = pcall(CreateClassicDurationFormatter)
        if not ok then
            ok, formatter = pcall(CreateSecondsDurationFormatter)
        end
        durationFormatter = ok and formatter or false
    end
    return durationFormatter or nil
end

function Nameplates.CanQueryUnit(unit)
    if type(unit) ~= "string" or unit == "" then return false end
    return unit == "target"
        or unit == "focus"
        or unit == "mouseover"
        or unit:match("^nameplate%d+$") ~= nil
end

function Nameplates.GetForUnit(unit)
    if not Nameplates.CanQueryUnit(unit) or not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        return nil
    end

    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok then return plate end
end

-- The health bar is the part of a nameplate players actually see resize, so
-- anchor to it rather than the plate's outer bounds. Accepts either the plate
-- or its UnitFrame.
function Nameplates.GetHealthBar(frame)
    if not frame then return nil end
    local unitFrame = frame.UnitFrame
    return (unitFrame and (unitFrame.healthBar or unitFrame.HealthBar))
        or frame.healthBar
        or frame.HealthBar
end

function Nameplates.GetAll()
    if not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then
        return {}
    end

    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if ok and type(plates) == "table" then
        return plates
    end
    return {}
end
