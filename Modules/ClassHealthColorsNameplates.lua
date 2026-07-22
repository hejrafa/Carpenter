--[[ Carpenter - ClassHealthColors nameplates ]]
-- Colors enemy player nameplate health bars by player class.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassHealth = ns.Private.ClassHealthColors or {}
local Nameplates = ns.Private.Nameplates or {}

local function GetNameplateHealthBar(plate)
    return Nameplates.GetHealthBar and Nameplates.GetHealthBar(plate) or nil
end

local function RestoreSelectionColor(bar, unit)
    local r, g, b = ClassHealth.GetSelectionColor(unit)
    if r and g and b then
        (bar._Carpenter_OrigSetStatusBarColor or bar.SetStatusBarColor)(bar, r, g, b)
    end
end

local function ColorNameplateForUnit(plate, unit)
    if not plate or not unit or not ClassHealth.UnitExists(unit) then return end

    local bar = GetNameplateHealthBar(plate)
    if not bar then return end

    -- Only color player nameplates. NPCs may reuse bars previously assigned to
    -- players, so clear Carpenter state only when we know we touched the bar.
    if not ClassHealth.IsPlayerUnit(unit) then
        if ClassHealth.ClearBarState(bar) then
            RestoreSelectionColor(bar, unit)
        end
        return
    end

    if not bar._Carpenter_NameplateHooked then
        bar._Carpenter_NameplateHooked = true
        bar._Carpenter_OrigSetStatusBarColor = bar.SetStatusBarColor

        bar.SetStatusBarColor = function(self, r, g, b, ...)
            if ClassHealth.IsNameplateEnabled() and self._Carpenter_IsClassColored and self._Carpenter_ClassColor then
                local c = self._Carpenter_ClassColor
                return self._Carpenter_OrigSetStatusBarColor(self, c.r, c.g, c.b, ...)
            end
            return self._Carpenter_OrigSetStatusBarColor(self, r, g, b, ...)
        end
    end

    ClassHealth.ClearBarState(bar)

    if not ClassHealth.IsNameplateEnabled() then
        RestoreSelectionColor(bar, unit)
        return
    end

    if ClassHealth.ApplyNameplateClassColor(bar, unit) then
        return
    end

    RestoreSelectionColor(bar, unit)
end

local function RefreshAllNameplates()
    for _, plate in pairs((Nameplates.GetAll and Nameplates.GetAll()) or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            ColorNameplateForUnit(plate, unit)
        end
    end
end

local nameplateDriver = CreateFrame("Frame")
nameplateDriver:Hide()

local function HandleNameplateEvent(self, event, unit)
    if not ClassHealth.IsNameplateEnabled() then
        self:Hide()
        return
    end
    self:Show()

    if event == "NAME_PLATE_UNIT_ADDED" and unit then
        local plate = Nameplates.GetForUnit and Nameplates.GetForUnit(unit)
        if plate then
            ColorNameplateForUnit(plate, unit)
        end
    else
        RefreshAllNameplates()
    end
end

nameplateDriver:SetScript("OnEvent", function(...)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("ClassHealthColors:Nameplates", HandleNameplateEvent, ...)
    end
    return HandleNameplateEvent(...)
end)

local function StartNameplateTicker()
    if Carpenter and Carpenter.StartTicker then
        Carpenter:StartTicker("ClassHealthColors:nameplates", 0.1, function()
            if ClassHealth.IsNameplateEnabled() then
                RefreshAllNameplates()
            end
        end)
    end
end

local function StopNameplateTicker()
    if Carpenter and Carpenter.StopTicker then
        Carpenter:StopTicker("ClassHealthColors:nameplates")
    end
end

local nameplateFeature = {}

function nameplateFeature:Enable()
    nameplateDriver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    nameplateDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
    nameplateDriver:RegisterEvent("GROUP_ROSTER_UPDATE")
    nameplateDriver:RegisterEvent("UNIT_FACTION")
    nameplateDriver:Show()
    StartNameplateTicker()
    RefreshAllNameplates()
end

function nameplateFeature:Disable()
    nameplateDriver:UnregisterAllEvents()
    StopNameplateTicker()
    nameplateDriver:Hide()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("nameplateClassHealthEnabled", nameplateFeature)
end
