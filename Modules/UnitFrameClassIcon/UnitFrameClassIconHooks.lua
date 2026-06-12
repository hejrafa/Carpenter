--[[ Carpenter - Unit Frame Class Icon hooks and refresh scheduling ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassIcon = ns.Private.UnitFrameClassIcon or {}
ns.Private.UnitFrameClassIcon = ClassIcon

local REFRESH_FOLLOWUP_DELAYS = { 0.05, 0.25, 0.75, 1.25 }
local unitSetPortraitHookInstalled = false
local portraitTextureHookInstalled = false
local portraitUpdateHookInstalled = false

function ClassIcon.ScheduleUnitRefresh(unit)
    if not unit then return end

    local function Refresh()
        ClassIcon.UpdateUnit(unit)
    end

    Refresh()

    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("UnitFrameClassIcon:" .. unit, REFRESH_FOLLOWUP_DELAYS, Refresh)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.25, Refresh)
        C_Timer.After(0.75, Refresh)
        C_Timer.After(1.25, Refresh)
    end
end

local function ScheduleUnitRefreshForUnitEvent(unit)
    if unit == "player" then
        ClassIcon.ScheduleUnitRefresh("player")
        if UnitIsUnit and UnitIsUnit("target", "player") then
            ClassIcon.ScheduleUnitRefresh("target")
        end
        if UnitIsUnit and UnitIsUnit("targettarget", "player") then
            ClassIcon.ScheduleUnitRefresh("targettarget")
        end
    elseif unit == "target" then
        ClassIcon.ScheduleUnitRefresh("target")
        ClassIcon.ScheduleUnitRefresh("targettarget")
    elseif unit == "targettarget" then
        ClassIcon.ScheduleUnitRefresh("targettarget")
    elseif unit == "focus" then
        ClassIcon.ScheduleUnitRefresh("focus")
    end
end

local function RefreshUnitForPortraitTexture(texture, unit)
    if ClassIcon.IsApplying() or (texture and texture.CP_ClassIconApplying) then return end

    if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
        ClassIcon.ScheduleUnitRefresh(unit)
        return
    end

    if texture == PlayerPortrait then
        ClassIcon.ScheduleUnitRefresh("player")
    elseif texture == TargetFramePortrait then
        ClassIcon.ScheduleUnitRefresh("target")
    elseif texture == _G.FocusFramePortrait or (_G.FocusFrame and texture == _G.FocusFrame.portrait) then
        ClassIcon.ScheduleUnitRefresh("focus")
    elseif ClassIcon.IsTargetTargetPortrait(texture) then
        ClassIcon.ScheduleUnitRefresh("targettarget")
    end
end

local function RefreshUnitForFrame(frameObject)
    if ClassIcon.IsApplying() then return end

    local unit = frameObject and frameObject.unit
    if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
        ClassIcon.ScheduleUnitRefresh(unit)
    elseif frameObject == PlayerFrame then
        ClassIcon.ScheduleUnitRefresh("player")
    elseif frameObject == TargetFrame then
        ClassIcon.ScheduleUnitRefresh("target")
    elseif frameObject == _G.FocusFrame then
        ClassIcon.ScheduleUnitRefresh("focus")
    elseif frameObject == _G.TargetFrameToT or frameObject == _G.TargetofTargetFrame or frameObject == _G.TargetOfTargetFrame then
        ClassIcon.ScheduleUnitRefresh("targettarget")
    end
end

local function UnitSetPortraitTexture_Hook(texture, unit)
    if ClassIcon.ShouldShow(unit) then
        local _, class = UnitClass(unit)
        if class and ClassIcon.ApplyClassIconToPortrait(texture, class) then
            return
        end
    end

    if texture then
        texture.CP_ClassIconDirectApplied = nil
    end
    if ClassIcon.OriginalUnitSetPortraitTexture then
        ClassIcon.OriginalUnitSetPortraitTexture(texture, unit)
    end
    ClassIcon.ResetPortraitTexCoords(texture)
end

function ClassIcon.InstallHooks()
    if not unitSetPortraitHookInstalled and type(UnitSetPortraitTexture) == "function" and UnitSetPortraitTexture ~= UnitSetPortraitTexture_Hook then
        ClassIcon.OriginalUnitSetPortraitTexture = UnitSetPortraitTexture
        UnitSetPortraitTexture = UnitSetPortraitTexture_Hook
        unitSetPortraitHookInstalled = true
    end

    if not portraitTextureHookInstalled and Carpenter and Carpenter.SafeHook then
        portraitTextureHookInstalled = Carpenter:SafeHook("SetPortraitTexture", RefreshUnitForPortraitTexture)
    end

    if portraitUpdateHookInstalled then return end
    if not Carpenter or not Carpenter.SafeHook then return end

    local hooked = false
    hooked = Carpenter:SafeHook("UnitFramePortrait_Update", RefreshUnitForFrame) or hooked
    hooked = Carpenter:SafeHook("TargetFrame_Update", function()
        if ClassIcon.IsApplying() then return end
        ClassIcon.ScheduleUnitRefresh("target")
        ClassIcon.ScheduleUnitRefresh("targettarget")
    end) or hooked
    hooked = Carpenter:SafeHook("TargetofTarget_Update", function()
        if ClassIcon.IsApplying() then return end
        ClassIcon.ScheduleUnitRefresh("targettarget")
    end) or hooked
    hooked = Carpenter:SafeHook("TargetFrameToT_Update", function()
        if ClassIcon.IsApplying() then return end
        ClassIcon.ScheduleUnitRefresh("targettarget")
    end) or hooked
    hooked = Carpenter:SafeHook("FocusFrame_Update", function()
        if ClassIcon.IsApplying() then return end
        ClassIcon.ScheduleUnitRefresh("focus")
    end) or hooked

    portraitUpdateHookInstalled = hooked == true
end

function ClassIcon.HandleEvent(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        ClassIcon.ScheduleUnitRefresh("target")
        ClassIcon.ScheduleUnitRefresh("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        ClassIcon.ScheduleUnitRefresh("focus")
    elseif event == "UNIT_TARGET" and unit == "target" then
        ClassIcon.ScheduleUnitRefresh("targettarget")
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then
        ScheduleUnitRefreshForUnitEvent(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ClassIcon.RefreshAll()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, ClassIcon.RefreshAll)
        end
    elseif event == "UNIT_PORTRAIT_UPDATE" and unit then
        if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
            ClassIcon.ScheduleUnitRefresh(unit)
        end
    end
end

function ClassIcon.RegisterUnitRefreshEvent(frame, event, optional)
    if Carpenter and Carpenter.SafeRegisterUnitEvent and
        Carpenter:SafeRegisterUnitEvent(frame, event, "player", "target", "targettarget", "focus") then
        return true
    end

    if not optional and Carpenter and Carpenter.SafeRegisterEvent then
        return Carpenter:SafeRegisterEvent(frame, event)
    end

    return false
end
