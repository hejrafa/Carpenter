--[[ Carpenter - ClassHealthColors unit frames ]]
-- Colors player, target, focus, and party health bars by player class.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassHealth = ns.Private.ClassHealthColors or {}

local function IsRetailClient()
    return ClassHealth.IsRetail and ClassHealth.IsRetail()
end

local function RestoreDefaultUnitColor(bar, unit, force)
    if not bar then return end
    if not force and not bar._Carpenter_IsUnitClassColored then return end

    local wasClassColored = ClassHealth.ClearBarState(bar)
    if IsRetailClient() then
        if wasClassColored or force then
            bar:SetStatusBarColor(1, 1, 1)
        end
        return
    end

    if not unit or not ClassHealth.UnitExists(unit) then return end

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

local Unit = ns.Private.Unit or {}
local PARTY_MEMBER_FRAME_COUNT = 5
local FOREVER_PARTY_CLASS_COLOR_CVAR = "raidFramesDisplayClassColor"
local secureCallFunction = securecallfunction
local foreverPartyClassColorOriginal
local foreverPartyClassColorManaged = false
local pendingForeverPartyClassColor
local foreverPartyClassColorDriver = CreateFrame("Frame")
foreverPartyClassColorDriver:Hide()

local function IsForeverClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isForever == true
end

local function GetForeverPartyClassColorCVarAPI()
    if C_CVar and type(C_CVar.GetCVar) == "function" and type(C_CVar.SetCVar) == "function" then
        return C_CVar.GetCVar, C_CVar.SetCVar
    end
    if type(GetCVar) == "function" and type(SetCVar) == "function" then
        return GetCVar, SetCVar
    end
end

local function SetForeverPartyClassColor(enabled)
    if not IsForeverClient() or type(secureCallFunction) ~= "function" then return false end

    local getter, setter = GetForeverPartyClassColorCVarAPI()
    if not getter or not setter then return false end

    if enabled then
        if not foreverPartyClassColorManaged then
            local ok, value = pcall(getter, FOREVER_PARTY_CLASS_COLOR_CVAR)
            if not ok or value == nil then return false end
            foreverPartyClassColorOriginal = value
            foreverPartyClassColorManaged = true
        end

        secureCallFunction(setter, FOREVER_PARTY_CLASS_COLOR_CVAR, "1")
        return true
    end

    if foreverPartyClassColorManaged then
        secureCallFunction(setter, FOREVER_PARTY_CLASS_COLOR_CVAR, foreverPartyClassColorOriginal or "0")
        foreverPartyClassColorOriginal = nil
        foreverPartyClassColorManaged = false
    end
    return true
end

local function ApplyForeverPartyClassColor(enabled)
    if not IsForeverClient() then return false end

    if InCombatLockdown and InCombatLockdown() then
        pendingForeverPartyClassColor = enabled
        foreverPartyClassColorDriver:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end

    pendingForeverPartyClassColor = nil
    foreverPartyClassColorDriver:UnregisterAllEvents()
    return SetForeverPartyClassColor(enabled)
end

foreverPartyClassColorDriver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and pendingForeverPartyClassColor ~= nil then
        ApplyForeverPartyClassColor(pendingForeverPartyClassColor)
    end
end)

local function GetUnitFrameHealthBar(unit)
    return Unit.FrameHealthBar and Unit.FrameHealthBar(unit) or nil
end

-- Party frames moved around when Edit Mode reached Classic, so try the nested
-- container shapes before falling back to the old globals.
local function GetPartyHealthBar(index)
    local member = PartyFrame and PartyFrame["MemberFrame" .. index]
    if member then
        local container = member.HealthBarsContainer or member.HealthBarContainer
        local bar = (container and (container.HealthBar or container.healthBar))
            or member.HealthBar
            or member.healthBar
            or member.healthbar
        if bar then
            return bar, member.unit or member.displayedUnit
        end
    end

    local legacy = _G["PartyMemberFrame" .. index]
    local bar = _G["PartyMemberFrame" .. index .. "HealthBar"]
        or (legacy and (legacy.HealthBar or legacy.healthBar or legacy.healthbar))
    if bar then
        return bar, "party" .. index
    end
end

local function UpdateHealthBarColor(bar, unit)
    if not bar then return end
    if not ClassHealth.IsUnitFrameEnabled() then return end
    if not unit or not ClassHealth.UnitExists(unit) then
        RestoreDefaultUnitColor(bar, unit, true)
        return
    end
    if not ClassHealth.IsPlayerUnit(unit) then
        RestoreDefaultUnitColor(bar, unit, true)
        return
    end

    if IsRetailClient() then
        if not ClassHealth.ApplyUnitFrameClassColor(bar, unit) then
            RestoreDefaultUnitColor(bar, unit, true)
        end
        return
    end

    HookUnitFrameHealthBar(bar, unit)
    if not ClassHealth.ApplyUnitFrameClassColor(bar, unit) then
        RestoreDefaultUnitColor(bar, unit, true)
    end
end

local function UpdatePartyHealthBarColor(bar, unit)
    -- Retail-style compact party frames expose restricted StatusBar state. Never
    -- mutate those bars: Forever class coloring is delegated to Blizzard through
    -- raidFramesDisplayClassColor instead.
    if IsRetailClient() then return end
    UpdateHealthBarColor(bar, unit)
end

local function RefreshPartyFrameColors(onlyUnit)
    for i = 1, PARTY_MEMBER_FRAME_COUNT do
        local partyBar, partyUnit = GetPartyHealthBar(i)
        if partyBar and (not onlyUnit or partyUnit == onlyUnit) then
            UpdatePartyHealthBarColor(partyBar, partyUnit)
        end
    end
end

local function RefreshUnitFrameColors()
    UpdateHealthBarColor(GetUnitFrameHealthBar("player"), "player")
    UpdateHealthBarColor(GetUnitFrameHealthBar("target"), "target")
    UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
    UpdateHealthBarColor(GetUnitFrameHealthBar("focus"), "focus")

    RefreshPartyFrameColors()
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
            RefreshPartyFrameColors("player")
        elseif unit and unit:find("party") then
            RefreshPartyFrameColors(unit)
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
    ApplyForeverPartyClassColor(true)
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
    ApplyForeverPartyClassColor(false)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("player"), "player", true)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("target"), "target", true)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("targettarget"), "targettarget", true)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("focus"), "focus", true)

    for i = 1, PARTY_MEMBER_FRAME_COUNT do
        local partyBar, partyUnit = GetPartyHealthBar(i)
        if not IsRetailClient() then
            RestoreDefaultUnitColor(partyBar, partyUnit, true)
        end
    end

    unitFrameDriver:UnregisterAllEvents()
    unitFrameDriver:Hide()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("classHealthColorsEnabled", unitFrameFeature)
end
