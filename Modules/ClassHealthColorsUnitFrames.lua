--[[ Carpenter - ClassHealthColors unit frames ]]
-- Colors player, target, focus, and party health bars by player class.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassHealth = ns.Private.ClassHealthColors or {}

local function RestoreDefaultUnitColor(bar, unit, force)
    if not bar or not unit or not ClassHealth.UnitExists(unit) then return end
    if not force and not bar._Carpenter_IsUnitClassColored then return end

    ClassHealth.ClearBarState(bar)
    -- Retail unit-frame bars can hold protected health values; leave their default
    -- repainting to Blizzard instead of calling back into protected update paths.
    if ClassHealth.IsRetail and ClassHealth.IsRetail() then return end

    if UnitFrameHealthBar_Update then
        bar._CarpenterRestoringDefault = true
        pcall(UnitFrameHealthBar_Update, bar, unit)
        bar._CarpenterRestoringDefault = false
        return
    end

    local r, g, b = ClassHealth.GetSelectionColor(unit)
    if r and g and b then
        bar:SetStatusBarColor(r, g, b)
    end
end

local function HookUnitFrameHealthBar(bar, unit)
    if not bar or bar._CarpenterUnitFrameClassColorHooked or not bar.SetStatusBarColor then return end
    if ClassHealth.IsRetail and ClassHealth.IsRetail() then return end
    bar._CarpenterUnitFrameClassColorHooked = true
    bar._CarpenterUnitFrameUnit = unit

    hooksecurefunc(bar, "SetStatusBarColor", function(self)
        local function Recolor()
            if self._CarpenterRestoringDefault or self._CarpenterRecoloring or not ClassHealth.IsUnitFrameEnabled() then return end
            self._CarpenterRecoloring = true
            if not ClassHealth.ApplyUnitFrameClassColor(self, self._CarpenterUnitFrameUnit) then
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

local function UpdateHealthBarColor(bar, unit)
    if not ClassHealth.IsUnitFrameEnabled() then return end
    if not ClassHealth.IsPlayerUnit(unit) then
        RestoreDefaultUnitColor(bar, unit, true)
        return
    end

    HookUnitFrameHealthBar(bar, unit)
    if not ClassHealth.ApplyUnitFrameClassColor(bar, unit) then
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

local unitFrameDriver = CreateFrame("Frame")
unitFrameDriver:Hide()

local function HandleUnitFrameEvent(self, event, unit)
    if not ClassHealth.IsUnitFrameEnabled() then return end

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
