--[[ Carpenter - UnitFrameClassIcon ]]
-- Replaces the player, target, and focus unit frame portrait (avatar) with the unit's class icon.
-- Uses the same circular mask as the default portrait. Works with DebuffTracker: when a debuff
-- is shown, DebuffTracker hides the portrait (our class icon) and shows its icon; when no debuff,
-- the portrait (class icon) is visible again.

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
    if (unit == "target" or unit == "focus" or unit == "targettarget") and UnitExists(unit) and UnitIsPlayer(unit) then
        return true
    end
    return false
end

-- Get portrait and parent for a unit (same logic as DebuffTracker).
local function GetPortraitAndParent(unit)
    local portrait
    if unit == "player" then
        portrait = PlayerPortrait
    elseif unit == "target" then
        portrait = TargetFramePortrait
    elseif unit == "focus" then
        portrait = _G.FocusFramePortrait or (_G.FocusFrame and _G.FocusFrame.portrait)
    elseif unit == "targettarget" then
        portrait = _G.TargetFrameToTPortrait or (_G.TargetFrameToT and _G.TargetFrameToT.portrait)
    end
    if not portrait then return nil, nil end
    local unitFrame = (unit == "player" and PlayerFrame) or (unit == "target" and TargetFrame) or (unit == "focus" and _G.FocusFrame) or (unit == "targettarget" and _G.TargetFrameToT)
    local parent = portrait.GetParent and portrait:GetParent() or unitFrame or UIParent
    if not parent or not parent.CreateFrame then
        parent = unitFrame or UIParent
    end
    return portrait, parent
end

-- Overlay frames when the default portrait is a Model (no SetTexture) or we use overlay for consistency.
local overlays = {}

local function GetOrCreateOverlay(unit)
    local portrait, parent = GetPortraitAndParent(unit)
    if not portrait or not parent then return nil end
    if overlays[unit] then
        return overlays[unit], portrait, parent
    end
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(math.max(0, (parent.GetFrameLevel and parent:GetFrameLevel() or 0) - 2))
    f:SetPoint("TOPLEFT", portrait, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT")
    local tex = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    tex:SetAllPoints(f)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if f.CreateMaskTexture then
        local mask = f:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(f)
        tex:AddMaskTexture(mask)
    end
    f.texture = tex
    f.portrait = portrait
    overlays[unit] = f
    return f, portrait, parent
end

local function UpdateUnitClassIcon(unit)
    local portrait, parent = GetPortraitAndParent(unit)
    if not portrait then return end

    local show = ShouldShowClassIcon(unit)
    if not show then
        if overlays[unit] then
            overlays[unit]:Hide()
        end
        if portrait.SetAlpha then
            portrait:SetAlpha(1)
        end
        return
    end

    local _, class = UnitClass(unit)
    if not class then
        if overlays[unit] then overlays[unit]:Hide() end
        if portrait.SetAlpha then portrait:SetAlpha(1) end
        return
    end

    local overlay = GetOrCreateOverlay(unit)
    if not overlay then return end

    SetClassIconOnTexture(overlay.texture, class)
    overlay:Show()
    if portrait.SetAlpha then
        portrait:SetAlpha(0)
    end
end

-- Also hook UnitSetPortraitTexture so that when the default UI tries to set the portrait (texture-based UIs), we show class icon instead.
local orig_UnitSetPortraitTexture
local hookInstalled

local function UnitSetPortraitTexture_Hook(texture, unit)
    if ShouldShowClassIcon(unit) then
        local _, class = UnitClass(unit)
        if class and texture and texture.SetTexture then
            SetClassIconOnTexture(texture, class)
            return
        end
    end
    if orig_UnitSetPortraitTexture then
        orig_UnitSetPortraitTexture(texture, unit)
    end
end

local function InstallHook()
    if hookInstalled then return end
    if type(UnitSetPortraitTexture) ~= "function" then return end
    if UnitSetPortraitTexture == UnitSetPortraitTexture_Hook then return end
    orig_UnitSetPortraitTexture = UnitSetPortraitTexture
    UnitSetPortraitTexture = UnitSetPortraitTexture_Hook
    hookInstalled = true
end

local function RefreshAll()
    InstallHook()
    UpdateUnitClassIcon("player")
    UpdateUnitClassIcon("target")
    UpdateUnitClassIcon("targettarget")
    UpdateUnitClassIcon("focus")
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateUnitClassIcon("target")
        UpdateUnitClassIcon("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        UpdateUnitClassIcon("focus")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshAll()
        -- Delayed refresh so default unit frames (and Model portraits) are fully built
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, RefreshAll)
        end
    elseif event == "UNIT_PORTRAIT_UPDATE" and unit then
        if unit == "player" or unit == "target" or unit == "targettarget" or unit == "focus" then
            UpdateUnitClassIcon(unit)
        end
    end
end)

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
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
