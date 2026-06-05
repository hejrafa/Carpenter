--[[ Carpenter - Debuff tracker Blizzard aura layering ]]
local _, ns = ...
ns.Private = ns.Private or {}

local AuraLayers = ns.Private.DebuffTrackerAuraLayers or {}
ns.Private.DebuffTrackerAuraLayers = AuraLayers

local AURA_BUTTON_KINDS = { "Buff", "Debuff" }
local context = {}
local auraLayerState = {
    frames = {},
    regions = {},
}

function AuraLayers.Configure(newContext)
    context = newContext or {}
end

local function IsUnitFrameEnabled()
    if context.IsUnitFrameEnabled then return context.IsUnitFrameEnabled() end
    return Carpenter and Carpenter:IsEnabled("unitFrameDebuffsEnabled")
end

local function GetAuraPart(aura, suffix, keys)
    if not aura then return nil end

    for _, key in ipairs(keys) do
        local part = aura[key]
        if type(part) == "table" or type(part) == "userdata" then
            return part
        end
    end

    local name = aura.GetName and aura:GetName()
    if name then
        return _G[name .. suffix]
    end
    return nil
end

local function SetManagedFrameLevel(frame, level)
    if not frame or not frame.SetFrameLevel then return end
    if not auraLayerState.frames[frame] and frame.GetFrameLevel then
        auraLayerState.frames[frame] = frame:GetFrameLevel()
    end
    frame:SetFrameLevel(level)
end

local function RestoreManagedFrameLevel(frame)
    if not frame or not frame.SetFrameLevel then return end
    local level = auraLayerState.frames[frame]
    if level then
        frame:SetFrameLevel(level)
        auraLayerState.frames[frame] = nil
    end
end

local function SetManagedAuraRegion(region, parent, drawLayer, subLevel)
    if not region then return end

    if not auraLayerState.regions[region] then
        local layer, oldSubLevel
        if region.GetDrawLayer then
            layer, oldSubLevel = region:GetDrawLayer()
        end

        auraLayerState.regions[region] = {
            parent = region.GetParent and region:GetParent() or nil,
            drawLayer = layer,
            subLevel = oldSubLevel,
        }
    end

    if parent and region.SetParent then
        region:SetParent(parent)
    end
    if region.SetDrawLayer then
        subLevel = math.max(-8, math.min(7, subLevel or 7))
        region:SetDrawLayer(drawLayer or "OVERLAY", subLevel)
    end
end

local function RestoreManagedAuraRegion(region)
    if not region then return end

    local state = auraLayerState.regions[region]
    if not state then return end

    if state.parent and region.SetParent then
        region:SetParent(state.parent)
    end
    if state.drawLayer and region.SetDrawLayer then
        region:SetDrawLayer(state.drawLayer, state.subLevel or 0)
    end

    auraLayerState.regions[region] = nil
end

local function GetAuraOverlay(aura)
    if not aura or not CreateFrame then return nil end
    if not aura._CarpenterAuraOverlay then
        local overlay = CreateFrame("Frame", nil, aura)
        overlay:SetAllPoints(aura)
        aura._CarpenterAuraOverlay = overlay
    end
    return aura._CarpenterAuraOverlay
end

local function SetBlizzardAuraButtonLayers(aura, topLevel)
    if not aura then return end

    SetManagedFrameLevel(aura, topLevel)

    local cooldown = GetAuraPart(aura, "Cooldown", { "Cooldown", "cooldown" })
    if cooldown then
        SetManagedFrameLevel(cooldown, topLevel + 1)
        if cooldown.SetDrawSwipe then
            cooldown:SetDrawSwipe(true)
        end
    end

    local overlay = GetAuraOverlay(aura)
    if overlay then
        SetManagedFrameLevel(overlay, topLevel + 2)
        overlay:Show()
    end

    SetManagedAuraRegion(GetAuraPart(aura, "Border", { "Border", "border", "DebuffBorder", "debuffBorder" }), overlay, "OVERLAY", 6)
    SetManagedAuraRegion(GetAuraPart(aura, "Count", { "Count", "count", "CountText", "countText" }), overlay, "OVERLAY", 7)
    SetManagedAuraRegion(GetAuraPart(aura, "Stealable", { "Stealable", "stealable" }), overlay, "OVERLAY", 7)
end

local function RestoreBlizzardAuraButtonLayers(aura)
    if not aura then return end

    RestoreManagedAuraRegion(GetAuraPart(aura, "Border", { "Border", "border", "DebuffBorder", "debuffBorder" }))
    RestoreManagedAuraRegion(GetAuraPart(aura, "Count", { "Count", "count", "CountText", "countText" }))
    RestoreManagedAuraRegion(GetAuraPart(aura, "Stealable", { "Stealable", "stealable" }))

    RestoreManagedFrameLevel(GetAuraPart(aura, "Cooldown", { "Cooldown", "cooldown" }))
    if aura._CarpenterAuraOverlay then
        aura._CarpenterAuraOverlay:Hide()
        RestoreManagedFrameLevel(aura._CarpenterAuraOverlay)
    end
    RestoreManagedFrameLevel(aura)
end

function AuraLayers.RaiseForUnitFrame(unitFrame)
    if not unitFrame or not unitFrame.GetFrameLevel then return end
    local prefix = unitFrame:GetName()
    if not prefix or prefix == "" then return end

    if not IsUnitFrameEnabled() then
        for i = 1, 32 do
            for _, kind in ipairs(AURA_BUTTON_KINDS) do
                RestoreBlizzardAuraButtonLayers(_G[prefix .. kind .. i])
            end
        end
        return
    end

    -- Aura row very high in hierarchy so it's never hidden by frame or other elements
    local topLevel = unitFrame:GetFrameLevel() + 2000
    for i = 1, 32 do
        for _, kind in ipairs(AURA_BUTTON_KINDS) do
            local aura = _G[prefix .. kind .. i]
            SetBlizzardAuraButtonLayers(aura, topLevel)
        end
    end
end

function AuraLayers.OnPositionsUpdated(unitFrame)
    AuraLayers.RaiseForUnitFrame(unitFrame)
end

function AuraLayers.Refresh()
    AuraLayers.RaiseForUnitFrame(TargetFrame)
    if _G.FocusFrame then
        AuraLayers.RaiseForUnitFrame(_G.FocusFrame)
    end
end
