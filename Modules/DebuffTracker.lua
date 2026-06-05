--[[ Carpenter - DebuffTracker ]]
-- Displays important debuffs/CC on Nameplates and replaces Target/Party Portraits.

local addonName, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}
local Unit = ns.Private.Unit or {}
local Nameplates = ns.Private.Nameplates or {}
local Icons = ns.Private.DebuffTrackerIcons or {}
local CreateBaseIcon = Icons.CreateBaseIcon
local GetDebuffColor = Icons.GetDebuffColor
local SetIconCooldown = Icons.SetIconCooldown
local SetStackText = Icons.SetStackText
local SyncNameplateIconLayers = Icons.SyncNameplateIconLayers

-- Slows / movement debuffs: show on nameplates but NOT on unit frame portraits (root spell IDs)
local DEBUFFS_HIDDEN_ON_UNIT_FRAME = {
    [3409] = true,   -- Crippling Poison
    [1715] = true,   -- Hamstring
    [23694] = true,  -- Improved Hamstring
    [18223] = true,  -- Curse of Exhaustion
    [12548] = true,  -- Frost Shock
    [2974] = true,   -- Wing Clip
    [19229] = true,  -- Wing Clip (root effect)
    [31589] = true,  -- Slow (Mage)
}

-- Configuration for "Important" Debuffs (CC, Stuns, Roots)
local IMPORTANT_DEBUFFS = {
    -- Mage
    ["Polymorph"] = true,
    ["Frost Nova"] = true,
    ["Frostbite"] = true,
    ["Invisibility"] = true,
    -- Rogue
    ["Kidney Shot"] = true,
    ["Cheap Shot"] = true,
    ["Gouge"] = true,
    ["Sap"] = true,
    ["Blind"] = true,
    -- Warlock
    ["Fear"] = true,
    ["Seduction"] = true,
    ["Death Coil"] = true,
    ["Banish"] = true,
    -- Warrior
    ["Intimidating Shout"] = true,
    ["Mace Stun"] = true,
    -- Priest
    ["Psychic Scream"] = true,
    ["Silence"] = true,
    -- Druid
    ["Entangling Roots"] = true,
    ["Hibernating"] = true,
    ["Bash"] = true,
    -- Paladin
    ["Hammer of Justice"] = true,
    -- Hunter
    ["Freezing Trap"] = true,
    ["Scatter Shot"] = true,
}

local NAMEPLATE_ONLY_DEBUFF_TYPES = {
    ["Deep Wounds"] = "Bleed",
    ["Garrote"] = "Bleed",
    ["Lacerate"] = "Bleed",
    ["Pounce Bleed"] = "Bleed",
    ["Rake"] = "Bleed",
    ["Rend"] = "Bleed",
    ["Rip"] = "Bleed",
    ["Rupture"] = "Bleed",
}

-- Check settings for Nameplates
local function IsNameplateEnabled()
    return Carpenter and Carpenter:IsEnabled("debuffTrackerEnabled")
end

-- Check settings for Unit Frames (Portraits)
local function IsUnitFrameEnabled()
    return Carpenter and Carpenter:IsEnabled("unitFrameDebuffsEnabled")
end

local function IsUnitFrameBuffsEnabled()
    return Carpenter and Carpenter:IsEnabled("unitFrameBuffsEnabled")
end

local function IsImportantNameplateDebuff(name, spellId)
    if IMPORTANT_DEBUFFS[name] then
        return true, nil
    end

    local nameplateOnlyType = NAMEPLATE_ONLY_DEBUFF_TYPES[name]
    if nameplateOnlyType then
        return true, nameplateOnlyType
    end

    if spellId and CarpenterSpellData then
        if CarpenterSpellData.IsImportantNameplateDebuff and CarpenterSpellData.IsImportantNameplateDebuff(spellId) then
            if CarpenterSpellData.IsBleedDebuff and CarpenterSpellData.IsBleedDebuff(spellId) then
                return true, "Bleed"
            end
            if CarpenterSpellData.IsPoisonDebuff and CarpenterSpellData.IsPoisonDebuff(spellId) then
                return true, "Poison"
            end
            return true, nil
        end

        if CarpenterSpellData.IsImportantDebuff and CarpenterSpellData.IsImportantDebuff(spellId) then
            return true, nil
        end
    end

    return false, nil
end

-- =========================================================
-- Unit Frame Logic (Portrait Replacements)
-- =========================================================

local portraitIcons = {}

local function IsPartyUnit(unit)
    if Unit.IsPartyUnit then return Unit.IsPartyUnit(unit) end
    return type(unit) == "string" and unit:match("^party%d$")
end

local function IsNPCPartyUnit(unit)
    if Unit.IsNPCPartyUnit then return Unit.IsNPCPartyUnit(unit) end
    return IsPartyUnit(unit) and UnitExists(unit) and not UnitIsPlayer(unit)
end

local function RestoreUnitPortrait(unit, portrait)
    if portraitIcons[unit] then
        portraitIcons[unit]:Hide()
    end
    if portrait then
        portrait:SetAlpha(1)
    end
end

-- Get the unit frame (parent of portrait) so we can layer debuff under frame textures but over portrait
local function GetUnitFrameForPortrait(unit)
    if unit == "player" and PlayerFrame then return PlayerFrame end
    if unit == "target" and TargetFrame then return TargetFrame end
    if unit == "focus" and _G.FocusFrame then return _G.FocusFrame end
    local partyIndex = unit:match("^party(%d)$")
    if partyIndex then
        local frame = _G["PartyMemberFrame" .. partyIndex]
        if frame then return frame end
    end
    return nil
end

local function GetPortraitForUnit(unit)
    if unit == "player" then return PlayerPortrait end
    if unit == "target" then return TargetFramePortrait end
    if unit == "focus" then return _G.FocusFramePortrait or (_G.FocusFrame and _G.FocusFrame.portrait) end
    local partyIndex = unit:match("^party(%d)$")
    if partyIndex then
        return _G["PartyMemberFrame" .. partyIndex .. "Portrait"]
    end
    return nil
end

local function UpdateUnitPortraitDebuff(unit)
    local portrait = GetPortraitForUnit(unit)
    local unitFrame = GetUnitFrameForPortrait(unit)
    local showDebuffs = IsUnitFrameEnabled()
    local showPlayerBuffs = unit == "player" and IsUnitFrameBuffsEnabled()

    if IsNPCPartyUnit(unit) then
        RestoreUnitPortrait(unit, portrait)
        return
    end

    -- If setting is off or unit doesn't exist, reset to default portrait
    if (not showDebuffs and not showPlayerBuffs) or not UnitExists(unit) then
        RestoreUnitPortrait(unit, portrait)
        return
    end

    if not portrait then return end

    -- Portrait can be a Texture (e.g. PlayerPortrait); CreateFrame requires a Frame. Use the portrait's parent so we sit in the same slot as the avatar.
    local portraitParent = portrait.GetParent and portrait:GetParent() or unitFrame or UIParent
    if not portraitParent or not portraitParent.CreateFrame then
        portraitParent = unitFrame or UIParent
    end

    -- Debuff replaces the avatar: same parent as portrait, same rect, portrait hidden when we show. Use portrait container's level so we stay under frame border/overlay.
    if not portraitIcons[unit] then
        portraitIcons[unit] = CreateBaseIcon(portraitParent, false)
        portraitIcons[unit]:SetPoint("TOPLEFT", portrait, "TOPLEFT")
        portraitIcons[unit]:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT")
        -- One level below portrait container so we sit in the portrait slot and stay under border/overlay; portrait is hidden (alpha 0) when we show so we replace the avatar
        local portraitLevel = portraitParent.GetFrameLevel and portraitParent:GetFrameLevel() or 0
        portraitIcons[unit]:SetFrameLevel(math.max(0, portraitLevel - 1))
    end

    local bestName, bestIcon, bestDuration, bestExpTime
    local maxRemaining = -1

    if showDebuffs then
        for i = 1, 40 do
            local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitDebuff(unit, i)
            if not name then break end

            local isImportant = IMPORTANT_DEBUFFS[name]
            if not isImportant and spellId and CarpenterSpellData and CarpenterSpellData.IsImportantDebuff then
                isImportant = CarpenterSpellData.IsImportantDebuff(spellId)
            end
            -- Unit frames: hide slows (Crippling Poison, Hamstring, etc.); nameplates still show them
            local rootId = (spellId and CarpenterSpellData and CarpenterSpellData.GetRootSpellId) and CarpenterSpellData.GetRootSpellId(spellId) or spellId
            local hiddenOnUnitFrame = rootId and DEBUFFS_HIDDEN_ON_UNIT_FRAME[rootId]
            if isImportant and not hiddenOnUnitFrame then
                local remaining = (expirationTime or 0) - GetTime()
                if remaining > maxRemaining then
                    maxRemaining = remaining
                    bestName, bestIcon, bestDuration, bestExpTime = name, icon, duration, expirationTime
                end
            end
        end
    end

    if not bestName and showPlayerBuffs then
        for i = 1, 40 do
            local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end

            local isImportant = spellId and CarpenterSpellData and CarpenterSpellData.IsImportantBuff and CarpenterSpellData.IsImportantBuff(spellId)
            if isImportant then
                local remaining = (expirationTime or 0) - GetTime()
                if remaining > maxRemaining then
                    maxRemaining = remaining
                    bestName, bestIcon, bestDuration, bestExpTime = name, icon, duration, expirationTime
                end
            end
        end
    end

    local iconFrame = portraitIcons[unit]
    if bestName then
        iconFrame.icon:SetTexture(bestIcon)
        if bestDuration and bestDuration > 0 and bestExpTime and bestExpTime > 0 then
            SetIconCooldown(iconFrame, bestExpTime - bestDuration, bestDuration, bestExpTime)
        else
            SetIconCooldown(iconFrame, 0, 0, nil)
        end
        iconFrame:Show()
        portrait:SetAlpha(0)
    else
        SetIconCooldown(iconFrame, 0, 0, nil)
        iconFrame:Hide()
        portrait:SetAlpha(1)
    end
end

-- =========================================================
-- Blizzard aura row (buffs/debuffs under unit frame) - keep on top of frame
-- =========================================================

local AURA_BUTTON_KINDS = { "Buff", "Debuff" }
local auraLayerState = {
    frames = {},
    regions = {},
}

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

local function RaiseBlizzardAuraFrameLevels(unitFrame)
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

local function OnBlizzardAuraPositionsUpdated(self)
    RaiseBlizzardAuraFrameLevels(self)
end

local function RefreshBlizzardAuraFrameLayers()
    RaiseBlizzardAuraFrameLevels(TargetFrame)
    if _G.FocusFrame then
        RaiseBlizzardAuraFrameLevels(_G.FocusFrame)
    end
end

-- =========================================================
-- Nameplate Logic - Multiple Icons Growing from Center
-- =========================================================

local function GetNameplateContainer(self)
    if not self then return nil end
    if not self.CP_DebuffContainer then
        local parent = (self.GetParent and self:GetParent()) or self
        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(1, 26)
        container:SetPoint("BOTTOM", self, "TOP", 0, 4)
        self.CP_DebuffContainer = container
        self.CP_DebuffIcons = {}
    end
    self.CP_DebuffIcons = self.CP_DebuffIcons or {}
    if self.CP_DebuffContainer.SetFrameLevel and self.GetFrameLevel then
        self.CP_DebuffContainer:SetFrameLevel((self:GetFrameLevel() or 0) + 30)
    end
    return self.CP_DebuffContainer
end

local function HideNameplateDebuffs(self)
    if not self then return end
    if self.CP_DebuffIcons then
        for _, iconFrame in ipairs(self.CP_DebuffIcons) do
            SetIconCooldown(iconFrame, 0, 0, nil)
            SetStackText(iconFrame, 0)
            iconFrame:Hide()
        end
    end
    if self.CP_DebuffContainer then
        self.CP_DebuffContainer:Hide()
    end
end

local function OnNameplateUpdate(self, unit)
    unit = unit or (self and self.unit)

    -- Respect Nameplate-specific setting
    if not IsNameplateEnabled() or not unit or not UnitExists(unit) then
        HideNameplateDebuffs(self)
        return
    end

    local container = GetNameplateContainer(self)
    if not container then return end
    local activeDebuffs = {}

    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end
        local isImportant, typeOverride = IsImportantNameplateDebuff(name, spellId)
        if isImportant then
            table.insert(activeDebuffs, {
                icon = icon,
                count = count,
                type = typeOverride or debuffType,
                dur = duration,
                exp = expirationTime
            })
        end
    end

    for _, iconFrame in ipairs(self.CP_DebuffIcons) do
        iconFrame:Hide()
    end

    if #activeDebuffs == 0 then
        HideNameplateDebuffs(self)
        return
    end

    container:Show()
    local spacing = 2
    local iconSize = 26
    local totalWidth = (#activeDebuffs * iconSize) + ((#activeDebuffs - 1) * spacing)
    container:SetWidth(totalWidth)

    for i, data in ipairs(activeDebuffs) do
        if not self.CP_DebuffIcons[i] then
            self.CP_DebuffIcons[i] = CreateBaseIcon(container, true)
        end

        local f = self.CP_DebuffIcons[i]
        if f.SetFrameLevel and container.GetFrameLevel then
            f:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
        end
        SyncNameplateIconLayers(f)
        f:ClearAllPoints()
        local offset = ((i - 1) * (iconSize + spacing)) - (totalWidth / 2) + (iconSize / 2)
        f:SetPoint("CENTER", container, "CENTER", offset, 0)

        f.icon:SetTexture(data.icon)
        SetStackText(f, data.count)
        local r, g, b = GetDebuffColor(data.type)
        f.border:SetVertexColor(r, g, b)
        if data.dur and data.dur > 0 and data.exp and data.exp > 0 then
            SetIconCooldown(f, data.exp - data.dur, data.dur, data.exp)
        else
            SetIconCooldown(f, 0, 0, nil)
        end
        -- Explicitly push border to OVERLAY to stay on top
        f.border:SetDrawLayer("OVERLAY", 7)
        f:Show()
    end
end

local function UpdateNameplateForUnit(unit)
    local plate = Nameplates.GetForUnit and Nameplates.GetForUnit(unit)
    if plate and plate.UnitFrame then
        OnNameplateUpdate(plate.UnitFrame, unit)
    end
end

local function RefreshAllNameplates()
    if not IsNameplateEnabled() then return end
    for _, plate in pairs((Nameplates.GetAll and Nameplates.GetAll()) or {}) do
        local unit = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
        if unit and plate.UnitFrame then
            OnNameplateUpdate(plate.UnitFrame, unit)
        end
    end
end

local function HideAllNameplateDebuffs()
    for _, plate in pairs((Nameplates.GetAll and Nameplates.GetAll()) or {}) do
        if plate and plate.UnitFrame then
            HideNameplateDebuffs(plate.UnitFrame)
        end
    end
end

local nameplateRefreshTickerActive = false

local function StartNameplateRefreshTicker()
    if nameplateRefreshTickerActive then return end
    nameplateRefreshTickerActive = true
    if Carpenter and Carpenter.StartTicker then
        Carpenter:StartTicker("DebuffTracker:nameplates", 0.2, RefreshAllNameplates)
    end
end

local function StopNameplateRefreshTicker()
    if not nameplateRefreshTickerActive then return end
    nameplateRefreshTickerActive = false
    if Carpenter and Carpenter.StopTicker then
        Carpenter:StopTicker("DebuffTracker:nameplates")
    end
end

-- =========================================================
-- Event Handling
-- =========================

local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

local function UpdateAllPartyPortraits()
    for _, partyUnit in ipairs(PARTY_UNITS) do
        UpdateUnitPortraitDebuff(partyUnit)
    end
end

function Carpenter_UpdateUnitFrameAuras()
    UpdateUnitPortraitDebuff("player")
    UpdateUnitPortraitDebuff("target")
    UpdateAllPartyPortraits()
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, unit)
    if not IsNameplateEnabled() and not IsUnitFrameEnabled() and not IsUnitFrameBuffsEnabled() then return end

    if event == "NAME_PLATE_UNIT_ADDED" then
        UpdateNameplateForUnit(unit)
    elseif event == "UNIT_AURA" then
        if unit == "target" or unit == "player" then
            UpdateUnitPortraitDebuff(unit)
        end
        if IsPartyUnit(unit) then
            UpdateUnitPortraitDebuff(unit)
        end
        UpdateNameplateForUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateUnitPortraitDebuff("target")
    elseif event == "GROUP_ROSTER_UPDATE" then
        UpdateAllPartyPortraits()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateUnitPortraitDebuff("player")
        UpdateUnitPortraitDebuff("target")
        UpdateAllPartyPortraits()
        RefreshBlizzardAuraFrameLayers()
    end
end)

local function RefreshEventSubscriptions()
    frame:UnregisterAllEvents()
    if not IsNameplateEnabled() then
        StopNameplateRefreshTicker()
        HideAllNameplateDebuffs()
    end

    RefreshBlizzardAuraFrameLayers()

    if not IsNameplateEnabled() and not IsUnitFrameEnabled() and not IsUnitFrameBuffsEnabled() then
        return
    end

    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if IsNameplateEnabled() then
        frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        StartNameplateRefreshTicker()
    end

    Carpenter_UpdateUnitFrameAuras()
    RefreshAllNameplates()
end

local function CreateAuraFeature()
    return {
        Enable = RefreshEventSubscriptions,
        Disable = RefreshEventSubscriptions,
    }
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("debuffTrackerEnabled", CreateAuraFeature())
    Carpenter:RegisterFeature("unitFrameDebuffsEnabled", CreateAuraFeature())
    Carpenter:RegisterFeature("unitFrameBuffsEnabled", CreateAuraFeature())
end

-- After Blizzard positions unit frame auras, set their frame level so the aura row draws on top
if TargetFrame_UpdateAuraPositions then
    hooksecurefunc("TargetFrame_UpdateAuraPositions", OnBlizzardAuraPositionsUpdated)
elseif TargetFrameMixin and TargetFrameMixin.UpdateAuraPositions then
    hooksecurefunc(TargetFrame, "UpdateAuraPositions", OnBlizzardAuraPositionsUpdated)
end
if _G.FocusFrame then
    if FocusFrame_UpdateAuraPositions then
        hooksecurefunc("FocusFrame_UpdateAuraPositions", OnBlizzardAuraPositionsUpdated)
    elseif FocusFrame.UpdateAuraPositions then
        hooksecurefunc(_G.FocusFrame, "UpdateAuraPositions", OnBlizzardAuraPositionsUpdated)
    end
end

hooksecurefunc("CompactUnitFrame_UpdateAuras", function(self)
    if IsNameplateEnabled() and self.unit and self.unit:find("nameplate") then
        OnNameplateUpdate(self, self.unit)
    end
end)
