--[[ Carpenter - Unit Frame Class Icon apply/restore state ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassIcon = ns.Private.UnitFrameClassIcon or {}
ns.Private.UnitFrameClassIcon = ClassIcon

local overlays = {}
local classIconApplyingDepth = 0

function ClassIcon.IsApplying()
    return classIconApplyingDepth > 0
end

local function BeginClassIconApply(portrait)
    classIconApplyingDepth = classIconApplyingDepth + 1
    if portrait then
        portrait.CP_ClassIconApplying = true
    end
end

local function EndClassIconApply(portrait)
    if portrait then
        portrait.CP_ClassIconApplying = nil
    end
    classIconApplyingDepth = math.max(0, classIconApplyingDepth - 1)
end

local function IsDebuffPortraitActive(unit)
    local debuffTracker = ns.Private and ns.Private.DebuffTracker
    return debuffTracker and debuffTracker.IsPortraitIconActive and debuffTracker.IsPortraitIconActive(unit)
end

local function HookPortraitMethod(portrait, method, marker, handler)
    if not portrait or not portrait[method] or portrait[marker] then return end

    local hooked = Carpenter and Carpenter.SafeHook and Carpenter:SafeHook(portrait, method, handler)
    if hooked then
        portrait[marker] = true
    end
end

function ClassIcon.HookPortraitRefresh(unit, portrait)
    if not portrait then return end

    HookPortraitMethod(portrait, "SetAlpha", "CP_ClassIconAlphaHooked", function(_, alpha)
        if ClassIcon.IsApplying() or portrait.CP_ClassIconApplying then return end
        if alpha and alpha > 0 and ClassIcon.ShouldShow(unit) then
            ClassIcon.UpdateUnit(unit)
        end
    end)

    local function OnPortraitChanged()
        if ClassIcon.IsApplying() or portrait.CP_ClassIconApplying then return end
        if ClassIcon.ShouldShow(unit) and ClassIcon.ScheduleUnitRefresh then
            ClassIcon.ScheduleUnitRefresh(unit)
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

    BeginClassIconApply(portrait)
    portrait:SetAlpha(alpha)
    EndClassIconApply(portrait)
end

function ClassIcon.ApplyClassIconToPortrait(portrait, class)
    if not portrait or not portrait.SetTexture then return false end

    BeginClassIconApply(portrait)
    local applied = ClassIcon.SetClassIconOnTexture(portrait, class)
    EndClassIconApply(portrait)

    if applied then
        portrait.CP_ClassIconDirectApplied = true
    end

    return applied
end

function ClassIcon.ResetPortraitTexCoords(portrait)
    if not portrait or not portrait.SetTexCoord then return end

    BeginClassIconApply(portrait)
    portrait:SetTexCoord(0, 1, 0, 1)
    EndClassIconApply(portrait)
end

local function RestorePortraitTexture(unit, portrait)
    if not portrait or not portrait.CP_ClassIconDirectApplied then return end

    portrait.CP_ClassIconDirectApplied = nil
    BeginClassIconApply(portrait)
    local restored = false
    if ClassIcon.OriginalUnitSetPortraitTexture then
        restored = pcall(ClassIcon.OriginalUnitSetPortraitTexture, portrait, unit)
    end
    if not restored and type(SetPortraitTexture) == "function" then
        restored = pcall(SetPortraitTexture, portrait, unit)
    end
    EndClassIconApply(portrait)
    ClassIcon.ResetPortraitTexCoords(portrait)
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
    local portrait, parent = ClassIcon.GetPortraitAndParent(unit)
    if not portrait or not parent then return nil end

    ClassIcon.HookPortraitRefresh(unit, portrait)

    local overlay = overlays[unit]
    if not overlay then
        overlay = CreateFrame("Frame", nil, parent)
        local texture = overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
        texture:SetAllPoints(overlay)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if overlay.CreateMaskTexture then
            local mask = overlay:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            mask:SetAllPoints(overlay)
            texture:AddMaskTexture(mask)
        end
        overlay.texture = texture
        overlays[unit] = overlay
    end

    PositionOverlay(overlay, portrait, parent)
    return overlay
end

function ClassIcon.UpdateUnit(unit)
    local portrait = ClassIcon.GetPortraitAndParent(unit)
    if not portrait then return end

    local show = ClassIcon.ShouldShow(unit)
    if not show then
        if overlays[unit] then overlays[unit]:Hide() end
        RestorePortraitTexture(unit, portrait)
        SetPortraitAlpha(portrait, 1)
        return
    end

    local _, class
    if ns.Private.Unit and ns.Private.Unit.Class then
        _, class = ns.Private.Unit.Class(unit)
    else
        _, class = UnitClass(unit)
    end
    if not class then
        if overlays[unit] then overlays[unit]:Hide() end
        RestorePortraitTexture(unit, portrait)
        SetPortraitAlpha(portrait, 1)
        return
    end

    ClassIcon.HookPortraitRefresh(unit, portrait)

    if ClassIcon.ApplyClassIconToPortrait(portrait, class) then
        if overlays[unit] then overlays[unit]:Hide() end
        if not IsDebuffPortraitActive(unit) then
            SetPortraitAlpha(portrait, 1)
        end
        return
    end

    local overlay = GetOrCreateOverlay(unit)
    if not overlay then return end

    ClassIcon.SetClassIconOnTexture(overlay.texture, class)
    overlay:Show()
    SetPortraitAlpha(portrait, 0)
end
