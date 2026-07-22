--[[ Carpenter - Debuff tracker icon helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Icons = ns.Private.DebuffTrackerIcons or {}
ns.Private.DebuffTrackerIcons = Icons

-- Blizzard Debuff Type Colors
local DEBUFF_COLORS = {
    ["Magic"]   = { r = 0.20, g = 0.60, b = 1.00 },
    ["Curse"]   = { r = 0.60, g = 0.00, b = 1.00 },
    ["Disease"] = { r = 0.60, g = 0.40, b = 0 },
    ["Poison"]  = { r = 0.00, g = 0.60, b = 0 },
    ["Bleed"]   = { r = 0.85, g = 0.05, b = 0.02 },
    ["none"]    = { r = 0.80, g = 0, b = 0 },    -- Default red
}

-- Shared so the nameplate container and icon layout stay in step with the icons
local NAMEPLATE_ICON_SIZE = 30
Icons.NAMEPLATE_ICON_SIZE = NAMEPLATE_ICON_SIZE

local NAMEPLATE_COOLDOWN_TEXT_SIZE = 12
local UNIT_FRAME_COOLDOWN_TEXT_SIZE = 24
local EXTERNAL_COOLDOWN_COUNT_ADDONS = {
    "OmniCC",
    "tullaCC",
    "tdCooldown2",
    "CooldownCount",
}

function Icons.GetDebuffColor(debuffType)
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

function Icons.SetStackText(frame, count)
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

function Icons.SetIconCooldown(frame, startTime, duration, expirationTime)
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

function Icons.SyncNameplateIconLayers(frame)
    if not frame or not frame.GetFrameLevel then return end

    local baseLevel = frame:GetFrameLevel() or 0
    if frame.cooldown and frame.cooldown.SetFrameLevel then
        frame.cooldown:SetFrameLevel(baseLevel + 1)
    end
    if frame.overlay and frame.overlay.SetFrameLevel then
        frame.overlay:SetFrameLevel(baseLevel + 2)
    end
end

function Icons.CreateBaseIcon(parent, isNameplate)
    local f = CreateFrame("Frame", nil, parent)

    if isNameplate then
        f:SetSize(NAMEPLATE_ICON_SIZE, NAMEPLATE_ICON_SIZE)
        f.icon = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

        -- Keep the swipe above the icon, with text/border on a separate overlay above it.
        f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cooldown:SetAllPoints(f.icon)
        f.cooldown:SetReverse(true)
        if f.cooldown.SetDrawSwipe then
            f.cooldown:SetDrawSwipe(true)
        end
        if f.cooldown.SetSwipeColor then
            f.cooldown:SetSwipeColor(0, 0, 0, 0.6)
        end
        if f.cooldown.SetBlingTexture then
            f.cooldown:SetBlingTexture("", 0, 0, 0, 0)
        end
        -- Keep Blizzard's native text hidden while allowing cooldown-count addons to attach.
        f.cooldown:SetHideCountdownNumbers(true)

        f.overlay = CreateFrame("Frame", nil, f)
        f.overlay:SetAllPoints(f)

        f.cooldownText = f.overlay:CreateFontString(nil, "OVERLAY")
        f.cooldownText:SetPoint("CENTER", f, "CENTER", 0, 0)
        StyleCooldownText(f.cooldownText, NAMEPLATE_COOLDOWN_TEXT_SIZE)

        f.stackText = f.overlay:CreateFontString(nil, "OVERLAY")
        f.stackText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
        StyleStackText(f.stackText)

        -- Border always on top
        f.border = f.overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        f.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        f.border:SetAllPoints(f)
        f.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        Icons.SyncNameplateIconLayers(f)
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
