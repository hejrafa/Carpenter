--[[ Carpenter - ClassHealthColors ]]
-- Colors unit frame health bars (Target, Focus, Party, etc.) and enemy player
-- nameplate health bars based on their class.

-- =========================
-- Shared Helpers
-- =========================

local function IsUnitFrameEnabled()
    return Carpenter and Carpenter:IsEnabled("classHealthColorsEnabled")
end

local function IsNameplateEnabled()
    return Carpenter and Carpenter:IsEnabled("nameplateClassHealthEnabled")
end

-- Apply class color to a given health bar; returns true if applied.
local function ApplyClassColor(bar, unit)
    if not unit or not bar or not UnitExists(unit) then return false end
    if not UnitIsPlayer(unit) then return false end

    local _, class = UnitClass(unit)
    local color = class and RAID_CLASS_COLORS[class]
    if not color then return false end

    bar:SetStatusBarColor(color.r, color.g, color.b)
    return true
end

-- =========================
-- Unit Frames (player/target/focus/party)
-- =========================
local function UpdateHealthBarColor(bar, unit)
    if not IsUnitFrameEnabled() then return end
    ApplyClassColor(bar, unit)
end

-- Hook into the Blizzard function that manages Health Bar coloring
-- This handles Target, Focus, and standard Party frames
hooksecurefunc("UnitFrameHealthBar_Update", function(self)
    UpdateHealthBarColor(self, self.unit)
end)

hooksecurefunc("HealthBar_OnValueChanged", function(self)
    UpdateHealthBarColor(self, self.unit)
end)

-- Event listener for unit changes to force update immediately
local unitFrameDriver = CreateFrame("Frame")
unitFrameDriver:RegisterEvent("PLAYER_TARGET_CHANGED")
unitFrameDriver:RegisterEvent("PLAYER_FOCUS_CHANGED")
unitFrameDriver:RegisterEvent("UNIT_HEALTH")
unitFrameDriver:RegisterEvent("GROUP_ROSTER_UPDATE") -- Added for party changes
unitFrameDriver:RegisterEvent("PLAYER_ENTERING_WORLD")

unitFrameDriver:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        UpdateHealthBarColor(TargetFrameHealthBar, "target")
    elseif event == "PLAYER_FOCUS_CHANGED" and FocusFrameHealthBar then
        UpdateHealthBarColor(FocusFrameHealthBar, "focus")
    elseif event == "UNIT_HEALTH" then
        if unit == "target" then
            UpdateHealthBarColor(TargetFrameHealthBar, "target")
        elseif unit == "focus" and FocusFrameHealthBar then
            UpdateHealthBarColor(FocusFrameHealthBar, "focus")
        elseif unit:find("party") then
            -- Handle party1, party2, etc.
            for i = 1, 4 do
                local partyBar = _G["PartyMemberFrame" .. i .. "HealthBar"]
                if partyBar and unit == "party" .. i then
                    UpdateHealthBarColor(partyBar, unit)
                end
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Refresh all party frames when someone joins/leaves
        for i = 1, 4 do
            local partyBar = _G["PartyMemberFrame" .. i .. "HealthBar"]
            if partyBar then
                UpdateHealthBarColor(partyBar, "party" .. i)
            end
        end
    end
end)

-- =========================
-- Nameplates
-- =========================

local function ColorNameplateForUnit(plate, unit)
    if not plate or not unit or not UnitExists(unit) then return end

    -- Try to locate the health bar on the current nameplate implementation
    local bar = (plate.UnitFrame and (plate.UnitFrame.healthBar or plate.UnitFrame.HealthBar))
        or plate.healthBar
        or plate.HealthBar

    if not bar then return end

    -- Only color enemy *player* nameplates. For NPCs clear our flags and only set the bar
    -- when this nameplate was recycled from a player (had our class color), so the mob
    -- doesn't keep the player's color. Otherwise leave the bar alone so Blizzard controls
    -- reaction/tapped (grey) etc.
    if not UnitIsPlayer(unit) then
        local wasClassColored = bar._Carpenter_IsClassColored
        bar._Carpenter_IsClassColored = false
        bar._Carpenter_ClassColor = nil
        if wasClassColored then
            local r, g, b = UnitSelectionColor(unit)
            if r and g and b then
                (bar._Carpenter_OrigSetStatusBarColor or bar.SetStatusBarColor)(bar, r, g, b)
            end
        end
        return
    end

    -- Ensure we have a per-bar hook so Blizzard threat / damage coloring
    -- can't briefly override our desired class color (which shows up as
    -- a red flicker on heal ticks).
    if not bar._Carpenter_NameplateHooked then
        bar._Carpenter_NameplateHooked = true
        bar._Carpenter_OrigSetStatusBarColor = bar.SetStatusBarColor

        bar.SetStatusBarColor = function(self, r, g, b, ...)
            -- If class-colored nameplates are enabled AND this bar has a
            -- stored class color, always enforce that color instead of any
            -- temporary red threat / damage flashes.
            if IsNameplateEnabled() and self._Carpenter_IsClassColored and self._Carpenter_ClassColor then
                local c = self._Carpenter_ClassColor
                return self._Carpenter_OrigSetStatusBarColor(self, c.r, c.g, c.b, ...)
            end

            -- Fallback to Blizzard's original behavior
            return self._Carpenter_OrigSetStatusBarColor(self, r, g, b, ...)
        end
    end

    -- Reset flags; they'll be re-set if we successfully apply a class color.
    bar._Carpenter_IsClassColored = false
    bar._Carpenter_ClassColor = nil

    if not IsNameplateEnabled() then
        -- When disabled, fall back to Blizzard's selection coloring
        local r, g, b = UnitSelectionColor(unit)
        if r and g and b then
            bar:SetStatusBarColor(r, g, b)
        end
        return
    end

    -- Try to apply class color; if that fails, use default selection color
    if ApplyClassColor(bar, unit) then
        -- Cache the class color on the bar so our hook can keep it stable
        local _, class = UnitClass(unit)
        local color = class and RAID_CLASS_COLORS[class]
        if color then
            bar._Carpenter_IsClassColored = true
            bar._Carpenter_ClassColor = color
        end
        return
    end

    local r, g, b = UnitSelectionColor(unit)
    if r and g and b then
        bar:SetStatusBarColor(r, g, b)
    end
end

local function RefreshAllNameplates()
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            ColorNameplateForUnit(plate, unit)
        end
    end
end

local nameplateDriver = CreateFrame("Frame")
nameplateDriver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nameplateDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
nameplateDriver:RegisterEvent("GROUP_ROSTER_UPDATE")
nameplateDriver:RegisterEvent("UNIT_FACTION")

nameplateDriver:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" and unit then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            ColorNameplateForUnit(plate, unit)
        end
    else
        RefreshAllNameplates()
    end
end)

-- Periodic refresh so Blizzard's threat coloring does not stick over class colors.
local elapsed = 0
nameplateDriver:SetScript("OnUpdate", function(self, delta)
    if not IsNameplateEnabled() then return end
    elapsed = elapsed + delta
    if elapsed >= 0.1 then
        RefreshAllNameplates()
        elapsed = 0
    end
end)
