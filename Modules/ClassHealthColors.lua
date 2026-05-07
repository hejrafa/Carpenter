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

local function IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function GetClassColor(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local _, class = UnitClass(unit)
    return class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

local function RestoreDefaultUnitColor(bar, unit, force)
    if not bar or not unit or not UnitExists(unit) then return end
    if not force and not bar._Carpenter_IsUnitClassColored then return end

    bar._Carpenter_IsUnitClassColored = false
    if UnitFrameHealthBar_Update then
        bar._CarpenterRestoringDefault = true
        pcall(UnitFrameHealthBar_Update, bar, unit)
        bar._CarpenterRestoringDefault = false
        return
    end

    local r, g, b = UnitSelectionColor(unit)
    if r and g and b then
        bar:SetStatusBarColor(r, g, b)
    end
end

-- Apply class color to a given health bar; returns true if applied.
local function ApplyClassColor(bar, unit)
    if not bar then return false end
    local color = GetClassColor(unit)
    if not color then return false end

    if bar.SetStatusBarDesaturated then
        bar:SetStatusBarDesaturated(true)
    end
    bar._Carpenter_IsUnitClassColored = true
    bar:SetStatusBarColor(color.r, color.g, color.b)
    return true
end

local function HookUnitFrameHealthBar(bar, unit)
    if not bar or bar._CarpenterUnitFrameClassColorHooked or not bar.SetStatusBarColor then return end
    if IsRetail() then return end
    bar._CarpenterUnitFrameClassColorHooked = true
    bar._CarpenterUnitFrameUnit = unit

    hooksecurefunc(bar, "SetStatusBarColor", function(self)
        local function Recolor()
            if self._CarpenterRestoringDefault or self._CarpenterRecoloring or not IsUnitFrameEnabled() then return end
            self._CarpenterRecoloring = true
            if not ApplyClassColor(self, self._CarpenterUnitFrameUnit) then
                RestoreDefaultUnitColor(self, self._CarpenterUnitFrameUnit)
            end
            self._CarpenterRecoloring = false
        end
        if Carpenter and Carpenter.Profile then
            return Carpenter:Profile("ClassHealthColors:SetStatusBarColorHook", Recolor)
        end
        return Recolor()
    end)
end

local function GetUnitFrameHealthBar(unit)
    if unit == "target" then
        return (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
                and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
                and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar)
            or TargetFrameHealthBar
            or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar)
    elseif unit == "targettarget" then
        return (TargetFrameToT and TargetFrameToT.HealthBar)
            or TargetFrameToTHealthBar
            or (TargetFrameToT and TargetFrameToT.healthbar)
    elseif unit == "focus" then
        return (FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain
                and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
                and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar)
            or FocusFrameHealthBar
            or (FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar)
    elseif unit == "player" then
        return (PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
                and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer
                and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar)
            or PlayerFrameHealthBar
            or (PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBar)
    end
end

-- =========================
-- Unit Frames (player/target/focus/party)
-- =========================
local function UpdateHealthBarColor(bar, unit)
    if not IsUnitFrameEnabled() then return end
    HookUnitFrameHealthBar(bar, unit)
    if not ApplyClassColor(bar, unit) then
        RestoreDefaultUnitColor(bar, unit, true)
    end
end

local function RefreshUnitFrameColors()
    UpdateHealthBarColor(GetUnitFrameHealthBar("player"), "player")
    UpdateHealthBarColor(GetUnitFrameHealthBar("target"), "target")
    UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
    UpdateHealthBarColor(GetUnitFrameHealthBar("focus"), "focus")

    for i = 1, 4 do
        local partyMember = PartyFrame and PartyFrame["MemberFrame" .. i]
        local partyBar = (partyMember and partyMember.HealthBarContainer and partyMember.HealthBarContainer.HealthBar)
            or _G["PartyMemberFrame" .. i .. "HealthBar"]
        if partyBar then
            UpdateHealthBarColor(partyBar, "party" .. i)
        end
    end
end

-- Event listener for unit changes to force update immediately
local unitFrameDriver = CreateFrame("Frame")
unitFrameDriver:Hide()

local function HandleUnitFrameEvent(self, event, unit)
    if not IsUnitFrameEnabled() then return end

    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        RefreshUnitFrameColors()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, RefreshUnitFrameColors)
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        RefreshUnitFrameColors()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, RefreshUnitFrameColors)
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
        if unit == "target" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("target"), "target")
            UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
        elseif unit == "targettarget" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
        elseif unit == "focus" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("focus"), "focus")
        elseif unit == "player" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("player"), "player")
        elseif unit and unit:find("party") then
            -- Handle party1, party2, etc.
            for i = 1, 4 do
                local partyMember = PartyFrame and PartyFrame["MemberFrame" .. i]
                local partyBar = (partyMember and partyMember.HealthBarContainer and partyMember.HealthBarContainer.HealthBar)
                    or _G["PartyMemberFrame" .. i .. "HealthBar"]
                if partyBar and unit == "party" .. i then
                    UpdateHealthBarColor(partyBar, unit)
                end
            end
        end
    elseif event == "UNIT_TARGET" and unit == "target" then
        UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
    elseif event == "GROUP_ROSTER_UPDATE" then
        RefreshUnitFrameColors()
    end
end

unitFrameDriver:SetScript("OnEvent", function(...)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("ClassHealthColors:UnitFrames", HandleUnitFrameEvent, ...)
    end
    return HandleUnitFrameEvent(...)
end)

local unitFrameFeature = {}

function unitFrameFeature:Enable()
    unitFrameDriver:RegisterEvent("PLAYER_TARGET_CHANGED")
    unitFrameDriver:RegisterEvent("PLAYER_FOCUS_CHANGED")
    unitFrameDriver:RegisterUnitEvent("UNIT_HEALTH", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_FLAGS", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_FACTION", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_TARGET", "target")
    unitFrameDriver:RegisterEvent("GROUP_ROSTER_UPDATE")
    unitFrameDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
    unitFrameDriver:Show()
    RefreshUnitFrameColors()
end

function unitFrameFeature:Disable()
    unitFrameDriver:UnregisterAllEvents()
    unitFrameDriver:Hide()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("classHealthColorsEnabled", unitFrameFeature)
end

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
nameplateDriver:Hide()

local function HandleNameplateEvent(self, event, unit)
    if not IsNameplateEnabled() then
        self:Hide()
        return
    end
    self:Show()

    if event == "NAME_PLATE_UNIT_ADDED" and unit then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
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
            if IsNameplateEnabled() then
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
