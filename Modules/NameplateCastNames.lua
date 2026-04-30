--[[ Carpenter - NameplateCastNames ]]
-- Clones TargetFrameSpellBar (+ icon) and anchors it below each enemy nameplate.
-- The game's built-in nameplate castbar is suppressed via CVar + per-plate HookScript.

local MIN_CAST_DURATION = 0.5
local SCALE = 0.9   -- bar height relative to TargetFrameSpellBar
local GAP   = 6     -- px between nameplate bottom and our widget

-- Active cast table: plate -> { startTimeMS, endTimeMS, isChannel }
local activeCasts = {}

-- Single OnUpdate driver for smooth bar progress across all nameplates
local _, ns = ...
local L = ns and ns.L or {}
local driver = CreateFrame("Frame")
driver:Hide()

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("nameplateCastNamesEnabled")
end

driver:SetScript("OnUpdate", function()
    local now = GetTime() * 1000
    local any = false
    for plate, info in pairs(activeCasts) do
        if plate.CP_Bar then
            local pct = (now - info.startTimeMS) / (info.endTimeMS - info.startTimeMS)
            pct = math.max(0, math.min(1, pct))
            if info.isChannel then pct = 1 - pct end
            plate.CP_Bar:SetValue(pct)
            -- Move the spark to the leading edge of the fill
            if plate.CP_Spark then
                plate.CP_Spark:ClearAllPoints()
                plate.CP_Spark:SetPoint("CENTER", plate.CP_Bar, "LEFT", pct * plate.CP_Bar:GetWidth(), 0)
            end
            any = true
        end
    end
    if not any then driver:Hide() end
end)

local function ShowBar(plate, name, icon, startTimeMS, endTimeMS, isChannel)
    if not plate.CP_Widget then return end
    plate.CP_CastText:SetText(name or "")
    plate.CP_Bar:SetValue(isChannel and 1 or 0)
    -- Color: read the same color tables the unit frame castbar uses internally
    local ref = TargetFrameSpellBar
    local color = isChannel
        and (ref and ref.channelColor or { r = 0, g = 1, b = 0 })
        or  (ref and ref.castColor    or { r = 1, g = 0.7, b = 0 })
    plate.CP_Bar:SetStatusBarColor(color.r, color.g, color.b)
    -- Icon
    if plate.CP_IconTex then
        if icon then
            plate.CP_IconTex:SetTexture(icon)
            plate.CP_IconFrame:Show()
        else
            plate.CP_IconFrame:Hide()
        end
    end
    plate.CP_Widget:Show()
    if plate.CP_Spark then plate.CP_Spark:Show() end
    if plate.CP_NativeCastBar then plate.CP_NativeCastBar:Hide() end
    activeCasts[plate] = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, isChannel = isChannel }
    driver:Show()
end

local function HideBar(plate)
    if not plate.CP_Widget then return end
    plate.CP_Widget:Hide()
    if plate.CP_IconFrame then plate.CP_IconFrame:Hide() end
    if plate.CP_Spark then plate.CP_Spark:Hide() end
    activeCasts[plate] = nil
end

local function UpdateCast(plate, unit)
    if not plate or not plate.CP_Widget then return end
    if not IsEnabled() then
        HideBar(plate)
        return
    end

    local name, _, icon, startTimeMS, endTimeMS = UnitCastingInfo(unit)
    local dur = (name and endTimeMS and startTimeMS) and (endTimeMS - startTimeMS) / 1000 or 0
    local isChannel = false
    if not name or dur < MIN_CAST_DURATION then
        name, _, icon, startTimeMS, endTimeMS = UnitChannelInfo(unit)
        dur = (name and endTimeMS and startTimeMS) and (endTimeMS - startTimeMS) / 1000 or 0
        isChannel = true
    end
    if not name or dur < MIN_CAST_DURATION then name = nil end
    if name == "Fishing" and not UnitIsPlayer(unit) then name = nil end

    if name then
        ShowBar(plate, name, icon, startTimeMS, endTimeMS, isChannel)
    else
        if plate.CP_CastText and plate.CP_CastText:GetText() == (L.INTERRUPTED or "Interrupted") then return end
        HideBar(plate)
    end
end

local function SetupPlate(plate, unit)
    if not plate or plate.CP_Widget then return end

    local castBar   = plate.UnitFrame and plate.UnitFrame.CastBar or plate.CastBar
    local healthBar = (plate.UnitFrame and plate.UnitFrame.HealthBar) or plate.HealthBar
    local anchor    = castBar or plate

    -- Suppress the game's built-in nameplate castbar for this plate.
    -- HookScript persists across the plate's lifetime and re-hides if the
    -- game tries to show it again, while respecting our feature toggle.
    if castBar then
        castBar:HookScript("OnShow", function(self)
            if IsEnabled() then
                self:Hide()
            end
        end)
        if IsEnabled() then
            castBar:Hide()
        end
    end

    -- Total width (icon + 2px gap + bar) matches the nameplate health bar width
    local ref   = TargetFrameSpellBar
    local refH  = (ref and ref:GetHeight() and ref:GetHeight() > 0) and ref:GetHeight() or 13
    local barH  = 8
    local iconSize = math.max(1, math.floor(barH * 1.6))  -- match the unit frame castbar icon proportion
    local rawW
    if healthBar and healthBar:GetWidth() and healthBar:GetWidth() > 0 then
        rawW = math.floor(healthBar:GetWidth())
    else
        rawW = tonumber(GetCVar("nameplateWidth")) or math.floor((ref and ref:GetWidth() and ref:GetWidth() > 0) and ref:GetWidth() or 110)
    end
    local totalW = math.floor(rawW * 0.83)
    -- Guard: ensure totalW is large enough to hold the icon, and barW is always positive
    totalW = math.max(iconSize + 10, totalW)
    local barW = math.max(4, totalW - iconSize - 2)  -- 2px gap between icon and bar left edge

    -- Icon frame (plate child, inherits strata + alpha from nameplate)
    local iconFrame = CreateFrame("Frame", nil, plate)
    iconFrame:SetSize(iconSize, iconSize)
    iconFrame:Hide()

    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(iconFrame)
    -- Default tex coords (0,1,0,1) — preserves the natural dark border baked into spell icons

    -- Main bar (plate child, inherits strata + alpha from nameplate)
    local widget = CreateFrame("StatusBar", nil, plate)
    widget:SetSize(barW, barH)
    -- Shift right by half the icon+gap width so the full assembly is centered under the nameplate
    widget:SetPoint("TOP", anchor, "BOTTOM", math.floor((iconSize + 2) / 2), -GAP)
    widget:Hide()

    -- Icon sits 2px to the left of the bar, vertically centered
    iconFrame:SetPoint("RIGHT", widget, "LEFT", -2, 0)

    -- Fill — same texture and color as the reference
    local sbTexPath = ref
        and ref:GetStatusBarTexture()
        and ref:GetStatusBarTexture():GetTexture()
        or "Interface\\TargetingFrame\\UI-StatusBar"
    widget:SetStatusBarTexture(sbTexPath)
    if ref then
        local r, g, b = ref:GetStatusBarColor()
        widget:SetStatusBarColor(r or 1, g or 0.7, b or 0)
    end
    widget:SetMinMaxValues(0, 1)
    widget:SetValue(0)

    -- Dark background
    local bg = widget:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(sbTexPath)
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
    bg:SetAllPoints(widget)

    -- Border — copied from reference, height trimmed by 4px
    if ref and ref.Border then
        local refBorder = ref.Border
        local refW = (ref:GetWidth()  and ref:GetWidth()  > 0) and ref:GetWidth()  or barW
        local refH = (ref:GetHeight() and ref:GetHeight() > 0) and ref:GetHeight() or barH
        local scaleW = barW / refW
        local scaleH = barH / refH
        local bW, bH = refBorder:GetSize()
        if bW and bH and bW > 0 and bH > 0 then
            local border = widget:CreateTexture(nil, "OVERLAY")
            border:SetTexture(refBorder:GetTexture())
            border:SetSize(math.max(1, math.floor(bW * scaleW)), math.max(1, math.floor(bH * scaleH - 4)))
            border:SetPoint("CENTER", widget, "CENTER", 0, 0)
            local lr, lg, lb, la = refBorder:GetVertexColor()
            if lr then border:SetVertexColor(lr, lg, lb, la) end
        end
    end

    -- Spark / glow — child of widget; child frames naturally draw above
    -- parent textures/FontStrings, so no explicit SetFrameLevel needed.
    local sparkFrame = CreateFrame("Frame", nil, widget)
    local spark = sparkFrame:CreateTexture(nil, "ARTWORK")
    local refSpark = ref and ref.Spark
    if refSpark and refSpark:GetTexture() then
        spark:SetTexture(refSpark:GetTexture())
        local sw, sh = refSpark:GetSize()
        local sparkH = math.floor(barH * 2)
        local ratio  = (sh and sh > 0) and (sparkH / sh) or 1
        sparkFrame:SetSize(math.max(1, math.floor((sw or 10) * ratio)), math.max(1, sparkH))
    else
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        sparkFrame:SetSize(10, math.max(1, math.floor(barH * 2)))
    end
    spark:SetAllPoints(sparkFrame)
    spark:SetBlendMode("ADD")
    sparkFrame:SetPoint("CENTER", widget, "LEFT", 0, 0)
    sparkFrame:Hide()

    -- Spell name text
    local text = widget:CreateFontString(nil, "OVERLAY")
    local fontSet = false
    if ref and ref.Text then
        local font, size, flags = ref.Text:GetFont()
        if font and size and size > 0 then
            text:SetFont(font, 8, flags)
            fontSet = true
        end
    end
    if not fontSet then
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8)
    end
    text:SetPoint("CENTER", widget, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)

    plate.CP_NativeCastBar = castBar
    plate.CP_Widget        = widget
    plate.CP_Bar           = widget
    plate.CP_CastText      = text
    plate.CP_IconFrame     = iconFrame
    plate.CP_IconTex       = iconTex
    plate.CP_Spark         = sparkFrame

    UpdateCast(plate, unit)
end

-- ── Events ──────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, unit)
    if not IsEnabled() then
        if event == "NAME_PLATE_UNIT_REMOVED" then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if plate then HideBar(plate) end
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        pcall(SetCVar, "nameplateShowEnemyCastBars", "0")
        for _, plate in pairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if u then SetupPlate(plate, u) end
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then SetupPlate(plate, unit) end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then HideBar(plate) end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if not plate and unit == "target" then
            for _, p in pairs(C_NamePlate.GetNamePlates()) do
                local u = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
                if u and UnitExists("target") and UnitIsUnit(u, "target") then
                    plate = p; unit = u; break
                end
            end
        end
        if plate and IsEnabled() then
            if not plate.CP_Widget then SetupPlate(plate, unit) end
            if plate.CP_Widget then
                plate.CP_CastText:SetText(L.INTERRUPTED or "Interrupted")
                plate.CP_Bar:SetValue(1)
                -- Red color — same as the unit frame castbar on interrupt
                local ref = TargetFrameSpellBar
                local color = ref and ref.failedColor or { r = 1, g = 0, b = 0 }
                plate.CP_Bar:SetStatusBarColor(color.r, color.g, color.b)
                -- Hide spark: bar is frozen, no animation
                if plate.CP_Spark then plate.CP_Spark:Hide() end
                -- Icon stays visible (same as unit frame castbar behaviour)
                plate.CP_Widget:Show()
                activeCasts[plate] = nil
                C_Timer.After(1.1, function()
                    if plate and plate.CP_CastText
                    and plate.CP_CastText:GetText() == (L.INTERRUPTED or "Interrupted") then
                        HideBar(plate)
                    end
                end)
            end
        end

    elseif event:find("UNIT_SPELLCAST") then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then UpdateCast(plate, unit) end
    end
end)

-- Safety ticker
C_Timer.NewTicker(0.5, function()
    if not IsEnabled() then return end
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            local casting    = UnitCastingInfo(unit)
            local channeling = UnitChannelInfo(unit)
            if casting or channeling or (plate.CP_Widget and plate.CP_Widget:IsShown()) then
                if not plate.CP_Widget then
                    SetupPlate(plate, unit)
                else
                    UpdateCast(plate, unit)
                end
            end
        end
    end
end)
