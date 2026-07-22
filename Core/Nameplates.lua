--[[ Carpenter - safe nameplate helpers ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Nameplates = ns.Private.Nameplates or {}
ns.Private.Nameplates = Nameplates

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
