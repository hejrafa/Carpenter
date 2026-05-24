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
