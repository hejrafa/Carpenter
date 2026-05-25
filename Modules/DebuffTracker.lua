--[[ Carpenter - DebuffTracker ]]
-- Displays important debuffs/CC on Nameplates and replaces Target/Party Portraits.

local addonName, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}
local Unit = ns.Private.Unit or {}
local Nameplates = ns.Private.Nameplates or {}

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

-- Blizzard Debuff Type Colors
local DEBUFF_COLORS = {
    ["Magic"]   = { r = 0.20, g = 0.60, b = 1.00 },
    ["Curse"]   = { r = 0.60, g = 0.00, b = 1.00 },
    ["Disease"] = { r = 0.60, g = 0.40, b = 0 },
    ["Poison"]  = { r = 0.00, g = 0.60, b = 0 },
    ["Bleed"]   = { r = 0.85, g = 0.05, b = 0.02 },
    ["none"]    = { r = 0.80, g = 0, b = 0 },    -- Default red
}

local NAMEPLATE_COOLDOWN_TEXT_SIZE = 12
local UNIT_FRAME_COOLDOWN_TEXT_SIZE = 24
local EXTERNAL_COOLDOWN_COUNT_ADDONS = {
    "OmniCC",
    "tullaCC",
    "tdCooldown2",
    "CooldownCount",
}

local function GetDebuffColor(debuffType)
    local color = DEBUFF_COLORS[debuffType] or DEBUFF_COLORS["none"]
    return color.r, color.g, color.b
end

local function StyleCooldownText(text, size)
    if not text then return end
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 0.9)
    text:SetShadowOffset(1, -1)
end

local function StyleStackText(text)
    if not text then return end
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 0.9)
    text:SetShadowOffset(1, -1)
end

local function SetStackText(frame, count)
    if not frame or not frame.stackText then return end
    count = tonumber(count) or 0
    frame.stackText:SetText(count > 1 and tostring(count) or "")
end

local function FormatCooldownTime(remaining)
    if not remaining or remaining <= 0 then return "" end
    if remaining < 10 then
        return tostring(math.ceil(remaining))
    elseif remaining < 60 then
        return tostring(math.ceil(remaining))
    elseif remaining < 3600 then
        return tostring(math.ceil(remaining / 60)) .. "m"
    end
    return tostring(math.ceil(remaining / 3600)) .. "h"
end

local function HasExternalCooldownCount()
    for _, addonName in ipairs(EXTERNAL_COOLDOWN_COUNT_ADDONS) do
        if _G[addonName] then return true end
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName) then
            return true
        end
        if IsAddOnLoaded and IsAddOnLoaded(addonName) then
            return true
        end
    end
    return false
end

local function UpdateCooldownText(frame)
    if not frame or not frame.cooldownText then return end
    if HasExternalCooldownCount() then
        frame.cooldownExpirationTime = nil
        frame.cooldownText:SetText("")
        frame:SetScript("OnUpdate", nil)
        return
    end

    local expirationTime = frame.cooldownExpirationTime
    if not expirationTime or expirationTime <= 0 then
        frame.cooldownText:SetText("")
        return
    end

    local remaining = expirationTime - GetTime()
    if remaining <= 0 then
        frame.cooldownExpirationTime = nil
        frame.cooldownText:SetText("")
        frame:SetScript("OnUpdate", nil)
        return
    end

    frame.cooldownText:SetText(FormatCooldownTime(remaining))
end

local function SetIconCooldown(frame, startTime, duration, expirationTime)
    if not frame or not frame.cooldown then return end
    frame.cooldown:SetCooldown(startTime or 0, duration or 0)

    if frame.cooldownText then
        if HasExternalCooldownCount() then
            frame.cooldownExpirationTime = nil
            frame.cooldownText:SetText("")
            frame:SetScript("OnUpdate", nil)
            return
        end

        if duration and duration > 0 and expirationTime and expirationTime > 0 then
            frame.cooldownExpirationTime = expirationTime
            UpdateCooldownText(frame)
            frame:SetScript("OnUpdate", function(self)
                UpdateCooldownText(self)
            end)
        else
            frame.cooldownExpirationTime = nil
            frame.cooldownText:SetText("")
            frame:SetScript("OnUpdate", nil)
        end
    end
end

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
-- Icon Creation & Management
-- =========================================================

local function CreateBaseIcon(parent, isNameplate)
    local f = CreateFrame("Frame", nil, parent)

    if isNameplate then
        f:SetSize(26, 26)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

        -- Cooldown frame for nameplates - set to a low level
        f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cooldown:SetAllPoints(f.icon)
        f.cooldown:SetReverse(true)
        -- Keep Blizzard's native text hidden while allowing cooldown-count addons to attach.
        f.cooldown:SetHideCountdownNumbers(true)
        f.cooldown:SetFrameLevel(f:GetFrameLevel())

        f.cooldownText = f:CreateFontString(nil, "OVERLAY")
        f.cooldownText:SetPoint("CENTER", f, "CENTER", 0, 0)
        StyleCooldownText(f.cooldownText, NAMEPLATE_COOLDOWN_TEXT_SIZE)

        f.stackText = f:CreateFontString(nil, "OVERLAY")
        f.stackText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
        StyleStackText(f.stackText)

        -- Border always on top
        f.border = f:CreateTexture(nil, "OVERLAY", nil, 7)
        f.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        f.border:SetAllPoints(f)
        f.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    else
        f:SetSize(64, 64)
        f:SetFrameLevel(0)
        local container = CreateFrame("Frame", nil, f)
        container:SetAllPoints(f)

        f.icon = container:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.icon:SetAllPoints(container)
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Unit Frames: Cooldown with circular swipe (BigDebuffs-style)
        f.cooldown = CreateFrame("Cooldown", nil, container)
        f.cooldown:SetAllPoints(container)
        f.cooldown:SetFrameLevel(1)
        f.cooldown:SetReverse(true)
        f.cooldown:SetHideCountdownNumbers(false)
        f.cooldown:SetBlingTexture("", 0, 0, 0, 0)

        -- Circular swipe: use portrait mask as swipe texture so the cooldown sweeps in a circle
        if f.cooldown.SetSwipeTexture then
            f.cooldown:SetSwipeTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        end
        f.cooldown:SetDrawSwipe(true)
        f.cooldown:SetSwipeColor(0, 0, 0, 0.6)
        -- Keep Blizzard's native text hidden while allowing cooldown-count addons to attach.
        f.cooldown:SetHideCountdownNumbers(true)

        f.cooldownText = container:CreateFontString(nil, "OVERLAY")
        f.cooldownText:SetPoint("CENTER", container, "CENTER", 0, 0)
        StyleCooldownText(f.cooldownText, UNIT_FRAME_COOLDOWN_TEXT_SIZE)

        -- Mask the icon so it stays circular like the portrait
        if container.CreateMaskTexture then
            local mask = container:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            mask:SetAllPoints(container)
            f.icon:AddMaskTexture(mask)
        end
    end

    f:Hide()
    return f
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

local function RaiseBlizzardAuraFrameLevels(unitFrame)
    if not unitFrame or not unitFrame.GetFrameLevel then return end
    local prefix = unitFrame:GetName()
    if not prefix or prefix == "" then return end
    -- Aura row very high in hierarchy so it's never hidden by frame or other elements
    local topLevel = unitFrame:GetFrameLevel() + 2000
    for i = 1, 32 do
        for _, kind in ipairs({ "Buff", "Debuff" }) do
            local aura = _G[prefix .. kind .. i]
            if aura and aura.SetFrameLevel then
                aura:SetFrameLevel(topLevel)
            end
        end
    end
end

local function OnBlizzardAuraPositionsUpdated(self)
    RaiseBlizzardAuraFrameLevels(self)
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
        -- Apply Blizzard aura row layering once at load (aura row on top)
        RaiseBlizzardAuraFrameLevels(TargetFrame)
        if _G.FocusFrame then RaiseBlizzardAuraFrameLevels(_G.FocusFrame) end
    end
end)

local function RefreshEventSubscriptions()
    frame:UnregisterAllEvents()
    if not IsNameplateEnabled() then
        StopNameplateRefreshTicker()
        HideAllNameplateDebuffs()
    end

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
