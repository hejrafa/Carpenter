--[[ Carpenter - ClassHealthColors shared helpers ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Unit = ns.Private.Unit or {}
local Shared = ns.Private.ClassHealthColors or {}
ns.Private.ClassHealthColors = Shared

function Shared.IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

function Shared.IsUnitFrameEnabled()
    return Carpenter and Carpenter:IsEnabled("classHealthColorsEnabled")
end

function Shared.IsPlayerUnit(unit)
    return Unit.IsPlayer and Unit.IsPlayer(unit)
end

function Shared.UnitExists(unit)
    if Unit.Exists then return Unit.Exists(unit) end
    return unit and UnitExists and UnitExists(unit)
end

function Shared.GetClassColor(unit)
    return Unit.ClassColor and Unit.ClassColor(unit) or nil
end

function Shared.GetSelectionColor(unit)
    if Unit.SelectionColor then
        return Unit.SelectionColor(unit)
    end
    if not unit or not UnitExists(unit) then return nil, nil, nil end
    return UnitSelectionColor(unit)
end

function Shared.ClearBarState(bar)
    if not bar then return false end

    local wasClassColored = bar._Carpenter_IsUnitClassColored or bar._Carpenter_IsClassColored
    bar._Carpenter_IsUnitClassColored = false
    bar._Carpenter_IsClassColored = false
    bar._Carpenter_ClassColor = nil

    if wasClassColored and bar.SetStatusBarDesaturated then
        bar:SetStatusBarDesaturated(false)
    end

    return wasClassColored
end

function Shared.ApplyUnitFrameClassColor(bar, unit)
    if not bar then return false end
    local color = Shared.GetClassColor(unit)
    if not color then return false end

    if bar.SetStatusBarDesaturated then
        bar:SetStatusBarDesaturated(true)
    end
    bar._Carpenter_IsUnitClassColored = true
    bar:SetStatusBarColor(color.r, color.g, color.b)
    return true
end

function Shared.ApplyNameplateClassColor(bar, unit)
    if not bar then return false end
    local color = Shared.GetClassColor(unit)
    if not color then return false end

    if bar.SetStatusBarDesaturated then
        bar:SetStatusBarDesaturated(true)
    end
    bar._Carpenter_IsClassColored = true
    bar._Carpenter_ClassColor = color
    bar:SetStatusBarColor(color.r, color.g, color.b)
    return true
end
