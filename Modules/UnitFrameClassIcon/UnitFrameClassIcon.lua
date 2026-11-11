--[[ Carpenter - UnitFrameClassIcon ]]
-- Classic/TBC class portrait feature registration. Helpers live in Modules/UnitFrameClassIcon/.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassIcon = ns.Private.UnitFrameClassIcon or {}
ns.Private.UnitFrameClassIcon = ClassIcon

function ClassIcon.RefreshAll()
    ClassIcon.InstallHooks()
    ClassIcon.UpdateUnit("player")
    ClassIcon.UpdateUnit("target")
    ClassIcon.UpdateUnit("targettarget")
    ClassIcon.UpdateUnit("focus")
end

ClassIcon.RefreshUnit = ClassIcon.UpdateUnit

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", ClassIcon.HandleEvent)

local feature = {}

function feature:Enable()
    Carpenter:SafeRegisterEvent(frame, "PLAYER_TARGET_CHANGED")
    Carpenter:SafeRegisterEvent(frame, "PLAYER_FOCUS_CHANGED")
    Carpenter:SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")
    Carpenter:SafeRegisterEvent(frame, "UNIT_PORTRAIT_UPDATE")
    Carpenter:SafeRegisterUnitEvent(frame, "UNIT_TARGET", "target")
    ClassIcon.RegisterUnitRefreshEvent(frame, "UNIT_HEALTH")
    ClassIcon.RegisterUnitRefreshEvent(frame, "UNIT_HEALTH_FREQUENT", true)
    ClassIcon.RegisterUnitRefreshEvent(frame, "UNIT_MAXHEALTH")
    ClassIcon.RegisterUnitRefreshEvent(frame, "UNIT_FLAGS")

    ClassIcon.RefreshAll()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, ClassIcon.RefreshAll)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
    ClassIcon.UpdateUnit("player")
    ClassIcon.UpdateUnit("target")
    ClassIcon.UpdateUnit("targettarget")
    ClassIcon.UpdateUnit("focus")
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("unitFrameClassIconEnabled", feature)
end
