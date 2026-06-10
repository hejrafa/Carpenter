--[[ Carpenter - UnitFrameClassIcon ]]
-- Replaces the player, target, and focus unit frame portrait (avatar) with the unit's class icon.
-- Uses the same circular mask as the default portrait. Works with DebuffTracker: when a debuff
-- is shown, DebuffTracker hides the portrait (our class icon) and shows its icon; when no debuff,
-- the portrait (class icon) is visible again.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Unit = ns.Private.Unit or {}
local ClassIcon = ns.Private.UnitFrameClassIcon or {}
ns.Private.UnitFrameClassIcon = ClassIcon

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("unitFrameClassIconEnabled")
end

-- Class icon texture: same as default unit frame class icons (circular).
local CLASS_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- Fallback when CLASS_ICON_TCOORDS is missing (e.g. some Vanilla clients). 3x3 grid: left, right, top, bottom.
local FALLBACK_TCOORDS = {
    WARRIOR = { 0, 1/3, 0, 1/3 },
    PALADIN = { 1/3, 2/3, 0, 1/3 },
    HUNTER   = { 2/3, 1, 0, 1/3 },
    ROGUE    = { 0, 1/3, 1/3, 2/3 },
    PRIEST   = { 1/3, 2/3, 1/3, 2/3 },
    SHAMAN   = { 2/3, 1, 1/3, 2/3 },
    MAGE     = { 0, 1/3, 2/3, 1 },
    WARLOCK  = { 1/3, 2/3, 2/3, 1 },
    DRUID    = { 2/3, 1, 2/3, 1 },
}

local function GetClassTexCoords(class)
    if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
        local t = CLASS_ICON_TCOORDS[class]
        return t[1], t[2], t[3], t[4]
    end
    local t = FALLBACK_TCOORDS[class]
    if t then
        return t[1], t[2], t[3], t[4]
    end
    return nil
end

local function SetClassIconOnTexture(texture, class)
    if not texture or not class then return false end
    if not texture.SetTexture then return false end
    local l, r, t, b = GetClassTexCoords(class)
    if l then
        texture:SetTexture(CLASS_ICON_TEXTURE)
        texture:SetTexCoord(l, r, t, b)
        return true
    end
    return false
end

local function ShouldShowClassIcon(unit)
    if not IsEnabled() then return false end
    if unit == "player" then
        return true
    end
    if (unit == "target" or unit == "focus" or unit == "targettarget") and Unit.IsPlayer and Unit.IsPlayer(unit) then
        return true
    end
    return false
end

local function FindPortraitRegion(frame)
    if not frame or not frame.GetRegions then return nil end

    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        local name = region and region.GetName and region:GetName()
        if name and name:find("Portrait") and region.SetTexture then
            return region
        end
    end
    return nil
end

-- Get portrait and parent for a unit (same logic as DebuffTracker).
local function GetPortraitAndParent(unit)
    local portrait
    if unit == "player" then
        portrait = PlayerPortrait
            or (PlayerFrame and (PlayerFrame.portrait or PlayerFrame.Portrait))
            or FindPortraitRegion(PlayerFrame)
    elseif unit == "target" then
        portrait = TargetFramePortrait
            or (TargetFrame and (TargetFrame.portrait or TargetFrame.Portrait))
            or FindPortraitRegion(TargetFrame)
    elseif unit == "focus" then
        portrait = _G.FocusFramePortrait
            or (_G.FocusFrame and (_G.FocusFrame.portrait or _G.FocusFrame.Portrait))
            or FindPortraitRegion(_G.FocusFrame)
    elseif unit == "targettarget" then
        portrait = _G.TargetFrameToTPortrait
            or _G.TargetofTargetPortrait
            or _G.TargetOfTargetPortrait
            or (_G.TargetFrameToT and (_G.TargetFrameToT.portrait or _G.TargetFrameToT.Portrait))
            or FindPortraitRegion(_G.TargetFrameToT)
    end
    if not portrait then return nil, nil end
    local unitFrame = (unit == "player" and PlayerFrame)
        or (unit == "target" and TargetFrame)
        or (unit == "focus" and _G.FocusFrame)
        or (unit == "targettarget" and (_G.TargetFrameToT or _G.TargetofTargetFrame or _G.TargetOfTargetFrame))
    local parent = portrait.GetParent and portrait:GetParent() or unitFrame or UIParent
    if not parent or not parent.CreateFrame then
        parent = unitFrame or UIParent
    end
    return portrait, parent
end

local function IsTargetTargetPortrait(texture)
    if not texture then return false end

    local targetTargetFrame = _G.TargetFrameToT
    return texture == _G.TargetFrameToTPortrait
        or texture == _G.TargetofTargetPortrait
        or texture == _G.TargetOfTargetPortrait
        or (targetTargetFrame and (
            texture == targetTargetFrame.portrait
            or texture == targetTargetFrame.Portrait
            or texture == FindPortraitRegion(targetTargetFrame)
        ))
end

-- Overlay frames when the default portrait is a Model (no SetTexture) or we use overlay for consistency.
local overlays = {}
local UpdateUnitClassIcon
local ScheduleUnitRefresh
local portraitTextureHookInstalled
local portraitUpdateHookInstalled
local REFRESH_FOLLOWUP_DELAYS = { 0.05, 0.25, 0.75, 1.25 }
local orig_UnitSetPortraitTexture
local hookInstalled

local function IsDebuffPortraitActive(unit)
    local debuffTracker = ns.Private and ns.Private.DebuffTracker
    return debuffTracker and debuffTracker.IsPortraitIconActive and debuffTracker.IsPortraitIconActive(unit)
end

local function HookPortraitMethod(portrait, method, marker, handler)
    if not hooksecurefunc or not portrait or not portrait[method] or portrait[marker] then return end
    portrait[marker] = true
    pcall(hooksecurefunc, portrait, method, handler)
end

local function HookPortraitRefresh(unit, portrait)
    if not portrait then return end

    HookPortraitMethod(portrait, "SetAlpha", "CP_ClassIconAlphaHooked", function(_, alpha)
        if portrait.CP_ClassIconApplying then return end
        if alpha and alpha > 0 and ShouldShowClassIcon(unit) then
            UpdateUnitClassIcon(unit)
        end
    end)

    local function OnPortraitChanged()
        if portrait.CP_ClassIconApplying then return end
        if ShouldShowClassIcon(unit) and ScheduleUnitRefresh then
            ScheduleUnitRefresh(unit)
        end
    end

    HookPortraitMethod(portrait, "SetTexture", "CP_ClassIconTextureHooked", OnPortraitChanged)
    HookPortraitMethod(portrait, "SetTexCoord", "CP_ClassIconTexCoordHooked", OnPortraitChanged)
    HookPortraitMethod(portrait, "Show", "CP_ClassIconShowHooked", OnPortraitChanged)
    HookPortraitMethod(portrait, "SetShown", "CP_ClassIconSetShownHooked", function(_, shown)
        if shown ~= false then
            OnPortraitChanged()
        end
    end)
end

local function SetPortraitAlpha(portrait, alpha)
    if not portrait or not portrait.SetAlpha then return end
    portrait.CP_ClassIconApplying = true
    portrait:SetAlpha(alpha)
    portrait.CP_ClassIconApplying = nil
end

local function ApplyClassIconToPortrait(portrait, class)
    if not portrait or not portrait.SetTexture then return false end

    portrait.CP_ClassIconApplying = true
    local applied = SetClassIconOnTexture(portrait, class)
    portrait.CP_ClassIconApplying = nil

    if applied then
        portrait.CP_ClassIconDirectApplied = true
    end

    return applied
end

local function RestorePortraitTexture(unit, portrait)
    if not portrait or not portrait.CP_ClassIconDirectApplied then return end

    portrait.CP_ClassIconApplying = true
    local restored = false
    if orig_UnitSetPortraitTexture then
        restored = pcall(orig_UnitSetPortraitTexture, portrait, unit)
    end
    if not restored and type(SetPortraitTexture) == "function" then
        restored = pcall(SetPortraitTexture, portrait, unit)
    end
    portrait.CP_ClassIconApplying = nil
    portrait.CP_ClassIconDirectApplied = nil
end

local function PositionOverlay(overlay, portrait, parent)
    if overlay.SetParent and overlay:GetParent() ~= parent then
        overlay:SetParent(parent)
    end
    if overlay.ClearAllPoints then
        overlay:ClearAllPoints()
    end
    overlay:SetFrameLevel(math.max(0, (parent.GetFrameLevel and parent:GetFrameLevel() or 0) - 2))
    overlay:SetPoint("TOPLEFT", portrait, "TOPLEFT")
    overlay:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT")
    overlay.portrait = portrait
end

local function GetOrCreateOverlay(unit)
    local portrait, parent = GetPortraitAndParent(unit)
    if not portrait or not parent then return nil end
    HookPortraitRefresh(unit, portrait)

    local overlay = overlays[unit]
    if not overlay then
        overlay = CreateFrame("Frame", nil, parent)
        local tex = overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
        tex:SetAllPoints(overlay)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if overlay.CreateMaskTexture then
            local mask = overlay:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            mask:SetAllPoints(overlay)
            tex:AddMaskTexture(mask)
        end
        overlay.texture = tex
        overlays[unit] = overlay
    end

    PositionOverlay(overlay, portrait, parent)
    return overlay, portrait, parent
end

function UpdateUnitClassIcon(unit)
    local portrait, parent = GetPortraitAndParent(unit)
    if not portrait then return end

    local show = ShouldShowClassIcon(unit)
    if not show then
        if overlays[unit] then
            overlays[unit]:Hide()
        end
        RestorePortraitTexture(unit, portrait)
        SetPortraitAlpha(portrait, 1)
        return
    end

    local _, class
    if Unit.Class then
        _, class = Unit.Class(unit)
    else
        _, class = UnitClass(unit)
    end
    if not class then
        if overlays[unit] then overlays[unit]:Hide() end
        RestorePortraitTexture(unit, portrait)
        SetPortraitAlpha(portrait, 1)
        return
    end

    HookPortraitRefresh(unit, portrait)

    if ApplyClassIconToPortrait(portrait, class) then
        if overlays[unit] then
            overlays[unit]:Hide()
        end
        if not IsDebuffPortraitActive(unit) then
            SetPortraitAlpha(portrait, 1)
        end
        return
    end

    local overlay = GetOrCreateOverlay(unit)
    if not overlay then return end

    SetClassIconOnTexture(overlay.texture, class)
    overlay:Show()
    SetPortraitAlpha(portrait, 0)
end

function ScheduleUnitRefresh(unit)
    if not unit then return end

    local function Refresh()
        UpdateUnitClassIcon(unit)
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
        ScheduleUnitRefresh("player")
        if UnitIsUnit and UnitIsUnit("target", "player") then
            ScheduleUnitRefresh("target")
        end
        if UnitIsUnit and UnitIsUnit("targettarget", "player") then
            ScheduleUnitRefresh("targettarget")
        end
    elseif unit == "target" then
        ScheduleUnitRefresh("target")
        ScheduleUnitRefresh("targettarget")
    elseif unit == "targettarget" then
        ScheduleUnitRefresh("targettarget")
    elseif unit == "focus" then
        ScheduleUnitRefresh("focus")
    end
end

local function RefreshUnitForPortraitTexture(texture, unit)
    if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
        ScheduleUnitRefresh(unit)
        return
    end

    if texture == PlayerPortrait then
        ScheduleUnitRefresh("player")
    elseif texture == TargetFramePortrait then
        ScheduleUnitRefresh("target")
    elseif texture == _G.FocusFramePortrait or (_G.FocusFrame and texture == _G.FocusFrame.portrait) then
        ScheduleUnitRefresh("focus")
    elseif IsTargetTargetPortrait(texture) then
        ScheduleUnitRefresh("targettarget")
    end
end

local function RefreshUnitForFrame(frameObject)
    local unit = frameObject and frameObject.unit
    if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
        ScheduleUnitRefresh(unit)
    elseif frameObject == PlayerFrame then
        ScheduleUnitRefresh("player")
    elseif frameObject == TargetFrame then
        ScheduleUnitRefresh("target")
    elseif frameObject == _G.FocusFrame then
        ScheduleUnitRefresh("focus")
    elseif frameObject == _G.TargetFrameToT or frameObject == _G.TargetofTargetFrame or frameObject == _G.TargetOfTargetFrame then
        ScheduleUnitRefresh("targettarget")
    end
end

local function UnitSetPortraitTexture_Hook(texture, unit)
    if ShouldShowClassIcon(unit) then
        local _, class = UnitClass(unit)
        if class and ApplyClassIconToPortrait(texture, class) then
            return
        end
    end
    if orig_UnitSetPortraitTexture then
        orig_UnitSetPortraitTexture(texture, unit)
    end
end

local function InstallHook()
    if not hookInstalled and type(UnitSetPortraitTexture) == "function" and UnitSetPortraitTexture ~= UnitSetPortraitTexture_Hook then
        orig_UnitSetPortraitTexture = UnitSetPortraitTexture
        UnitSetPortraitTexture = UnitSetPortraitTexture_Hook
        hookInstalled = true
    end

    if hooksecurefunc and type(SetPortraitTexture) == "function" and not portraitTextureHookInstalled then
        local ok = pcall(hooksecurefunc, "SetPortraitTexture", RefreshUnitForPortraitTexture)
        portraitTextureHookInstalled = ok == true
    end

    if hooksecurefunc and not portraitUpdateHookInstalled then
        local hooked = false
        if type(UnitFramePortrait_Update) == "function" then
            hooked = pcall(hooksecurefunc, "UnitFramePortrait_Update", RefreshUnitForFrame) or hooked
        end
        if type(TargetFrame_Update) == "function" then
            hooked = pcall(hooksecurefunc, "TargetFrame_Update", function()
                ScheduleUnitRefresh("target")
                ScheduleUnitRefresh("targettarget")
            end) or hooked
        end
        if type(TargetofTarget_Update) == "function" then
            hooked = pcall(hooksecurefunc, "TargetofTarget_Update", function()
                ScheduleUnitRefresh("targettarget")
            end) or hooked
        end
        if type(TargetFrameToT_Update) == "function" then
            hooked = pcall(hooksecurefunc, "TargetFrameToT_Update", function()
                ScheduleUnitRefresh("targettarget")
            end) or hooked
        end
        if type(FocusFrame_Update) == "function" then
            hooked = pcall(hooksecurefunc, "FocusFrame_Update", function()
                ScheduleUnitRefresh("focus")
            end) or hooked
        end
        portraitUpdateHookInstalled = hooked == true
    end
end

local function RefreshAll()
    InstallHook()
    UpdateUnitClassIcon("player")
    UpdateUnitClassIcon("target")
    UpdateUnitClassIcon("targettarget")
    UpdateUnitClassIcon("focus")
end

ClassIcon.RefreshUnit = UpdateUnitClassIcon
ClassIcon.RefreshAll = RefreshAll

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        ScheduleUnitRefresh("target")
        ScheduleUnitRefresh("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        ScheduleUnitRefresh("focus")
    elseif event == "UNIT_TARGET" and unit == "target" then
        ScheduleUnitRefresh("targettarget")
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then
        ScheduleUnitRefreshForUnitEvent(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshAll()
        -- Delayed refresh so default unit frames (and Model portraits) are fully built
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, RefreshAll)
        end
    elseif event == "UNIT_PORTRAIT_UPDATE" and unit then
        if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
            ScheduleUnitRefresh(unit)
        end
    end
end)

local feature = {}

local function RegisterUnitRefreshEvent(event, optional)
    if frame.RegisterUnitEvent then
        local ok = pcall(frame.RegisterUnitEvent, frame, event, "player", "target", "targettarget", "focus")
        if ok then return end
    end
    if not optional then
        frame:RegisterEvent(event)
    end
end

function feature:Enable()
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    frame:RegisterUnitEvent("UNIT_TARGET", "target")
    RegisterUnitRefreshEvent("UNIT_HEALTH")
    RegisterUnitRefreshEvent("UNIT_HEALTH_FREQUENT", true)
    RegisterUnitRefreshEvent("UNIT_MAXHEALTH")
    RegisterUnitRefreshEvent("UNIT_FLAGS")
    RefreshAll()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, RefreshAll)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
    UpdateUnitClassIcon("player")
    UpdateUnitClassIcon("target")
    UpdateUnitClassIcon("targettarget")
    UpdateUnitClassIcon("focus")
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("unitFrameClassIconEnabled", feature)
end
