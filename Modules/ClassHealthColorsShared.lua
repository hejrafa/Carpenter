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

-- Forever treats compact-unit-frame StatusBar colors as restricted state. Writing
-- the color directly makes Blizzard's later GetStatusBarColor results secret and
-- taints CompactUnitFrame_UpdateHealthColor. A texture anchored to the existing
-- fill follows the bar's value without changing that protected state.
function Shared.ApplyCompactUnitFrameClassColor(bar, unit)
    if not bar then return false end
    local color = Shared.GetClassColor(unit)
    if not color then return false end

    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not fill or not bar.CreateTexture then return false end

    local overlay = bar._Carpenter_ClassColorOverlay
    if not overlay then
        overlay = bar:CreateTexture(nil, "ARTWORK", nil, 7)
        if not overlay then return false end
        bar._Carpenter_ClassColorOverlay = overlay
    end

    if overlay._Carpenter_Anchor ~= fill then
        if overlay.ClearAllPoints then
            overlay:ClearAllPoints()
        end
        overlay:SetAllPoints(fill)
        overlay._Carpenter_Anchor = fill
    end

    if overlay.SetColorTexture then
        overlay:SetColorTexture(color.r, color.g, color.b, 1)
    else
        overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
        overlay:SetVertexColor(color.r, color.g, color.b, 1)
    end
    overlay:Show()
    return true
end

function Shared.ClearCompactUnitFrameClassColor(bar)
    local overlay = bar and bar._Carpenter_ClassColorOverlay
    if not overlay then return false end
    overlay:Hide()
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
