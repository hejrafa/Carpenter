--[[ Carpenter - EnchantWarning ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}
local L = (Carpenter and Carpenter.L) or {}
-- Warns before weapon enchantments expire.

local hasWarnedMH = false
local hasWarnedOH = false
local lastEnchantNameMH = nil
local lastEnchantNameOH = nil

-- Delay logic for zone transitions
local INITIAL_DELAY = 5 -- Seconds to wait after loading screen
local delayTimer = 0

-- Create a hidden tooltip to scan enchant names
local scanTooltip = CreateFrame("GameTooltip", "CarpenterScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

-- Turns a time-left format such as ITEM_ENCHANT_TIME_LEFT_MIN ("%s (%d min)")
-- into a pattern that captures the enchant name, in the client's language.
local function FormatToPattern(format)
    format = format:gsub("%%%d%$([sd])", "%%%1")      -- positional "%1$s" -> "%s"
    format = format:gsub("|4[^;]*;", "\001")          -- plural markup "|4hour:hrs;"
    format = format:gsub("%%s", "\002"):gsub("%%d", "\003")
    format = format:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    format = format:gsub("\001", ".-"):gsub("\002", "(.-)"):gsub("\003", "%%d+")
    return "^" .. format .. "$"
end

local timeLeftPatterns
local function GetTimeLeftPatterns()
    if not timeLeftPatterns then
        timeLeftPatterns = {}
        for _, key in ipairs({ "ITEM_ENCHANT_TIME_LEFT_SEC", "ITEM_ENCHANT_TIME_LEFT_MIN", "ITEM_ENCHANT_TIME_LEFT_HOURS", "ITEM_ENCHANT_TIME_LEFT_DAYS" }) do
            local format = _G[key]
            if type(format) == "string" and format:gsub("%%%d%$s", "%%s"):find("%s", 1, true) then
                timeLeftPatterns[#timeLeftPatterns + 1] = FormatToPattern(format)
            end
        end
        -- English fallback for clients without the strings above.
        timeLeftPatterns[#timeLeftPatterns + 1] = "^(.-) %(%d+ %a+%)$"
    end
    return timeLeftPatterns
end

local function GetEnchantNameFromLine(text)
    for _, pattern in ipairs(GetTimeLeftPatterns()) do
        local name = text:match(pattern)
        if name and name ~= "" then
            return name
        end
    end
    return nil
end

ns.Private.EnchantWarning = { GetEnchantNameFromLine = GetEnchantNameFromLine }

local function ParseEnchantLine(text, r, g, b)
    if type(text) ~= "string" or IsSecret(text) then
        return nil
    end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or IsSecret(r) or IsSecret(g) or IsSecret(b) then
        return nil
    end
    -- Green text indicates enchants
    if g > 0.9 and r < 0.5 and b < 0.5 then
        -- Temporary enchants end in a time left such as "(15 min)"; keep the name.
        return GetEnchantNameFromLine(text)
    end
    return nil
end

local function GetEnchantName(slot)
    -- Scan weapon tooltip for temp enchant (green text)
    -- slot 16 = main hand, slot 17 = off hand

    -- WoW Forever reads tooltip data directly instead of filling a hidden tooltip.
    local client = Carpenter and Carpenter.Client
    if client and client.isForever and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem("player", slot)
        for _, line in ipairs(data and data.lines or {}) do
            local color = line.leftColor
            local name = color and ParseEnchantLine(line.leftText, color.r, color.g, color.b)
            if name then
                return name
            end
        end
        return nil
    end

    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem("player", slot)

    -- Look through all tooltip lines for green text that contains a time remaining pattern
    for i = 1, scanTooltip:NumLines() do
        local line = _G["CarpenterScanTooltipTextLeft" .. i]
        if line then
            local name = ParseEnchantLine(line:GetText(), line:GetTextColor())
            if name then
                scanTooltip:Hide()
                return name
            end
        end
    end

    scanTooltip:Hide()
    return nil
end

local function CheckEnchantments()
    -- Don't check if disabled
    if not (Carpenter and Carpenter:IsEnabled("enchantWarningEnabled")) then
        return
    end

    -- Skip check if we are in the initial loading delay
    if delayTimer > 0 then
        return
    end

    -- Skip tooltip scan when any item tooltip is visible so SetInventoryItem does not
    -- refresh the comparison tooltip (flicker fix for inspect, loot rolls, bags, etc.)
    if MerchantFrame and MerchantFrame:IsShown() then
        return
    end
    if GameTooltip and GameTooltip:IsVisible() and GameTooltip.GetItem then
        local _, itemLink = GameTooltip:GetItem()
        if itemLink and itemLink ~= "" then
            return
        end
    end
    local bagsOpen = false
    for i = 0, 4 do
        if IsBagOpen(i) then bagsOpen = true break end
    end
    if bagsOpen and GameTooltip and GameTooltip:IsVisible() then
        return
    end

    -- Check hand enchants
    local hasMainEnchant, mainTimeLeft, _, _, hasOffEnchant, offTimeLeft = GetWeaponEnchantInfo()
    if IsSecret(hasMainEnchant) or IsSecret(mainTimeLeft) or IsSecret(hasOffEnchant) or IsSecret(offTimeLeft) then
        return
    end

    -- Main hand logic
    if hasMainEnchant then
        local secondsLeft = mainTimeLeft / 1000
        local currentName = GetEnchantName(16)

        if currentName then lastEnchantNameMH = currentName end
        local displayName = lastEnchantNameMH or (L.MAIN_HAND_POISON or "Main Hand Poison")

        if secondsLeft <= 120 and secondsLeft > 110 and not hasWarnedMH then
            UIErrorsFrame:AddMessage(string.format(L.ENCHANT_FALLING_OFF_SOON or "%s wears off in 2 min!", displayName), 1.0, 0.5, 0.0, 1.0, 5)
            hasWarnedMH = true
        end

        if secondsLeft > 120 then
            hasWarnedMH = false
        end
    else
        if lastEnchantNameMH then
            UIErrorsFrame:AddMessage(string.format(L.ENCHANT_NO_LONGER_ON_WEAPON or "%s has worn off your weapon!", lastEnchantNameMH), 1.0, 0.1, 0.0, 1.0, 5)
            lastEnchantNameMH = nil
        end
        hasWarnedMH = false
    end

    -- Off hand logic
    if hasOffEnchant then
        local secondsLeft = offTimeLeft / 1000
        local currentName = GetEnchantName(17)

        if currentName then lastEnchantNameOH = currentName end
        local displayName = lastEnchantNameOH or (L.OFF_HAND_POISON or "Off Hand Poison")

        if secondsLeft <= 120 and secondsLeft > 110 and not hasWarnedOH then
            UIErrorsFrame:AddMessage(string.format(L.ENCHANT_FALLING_OFF_SOON or "%s wears off in 2 min!", displayName), 1.0, 0.5, 0.0, 1.0, 5)
            hasWarnedOH = true
        end

        if secondsLeft > 120 then
            hasWarnedOH = false
        end
    else
        if lastEnchantNameOH then
            UIErrorsFrame:AddMessage(string.format(L.ENCHANT_NO_LONGER_ON_WEAPON or "%s has worn off your weapon!", lastEnchantNameOH), 1.0, 0.1, 0.0, 1.0, 5)
            lastEnchantNameOH = nil
        end
        hasWarnedOH = false
    end
end

-- Fix for zone transitions (Battlegrounds, Dungeons, etc.)
local transitionFrame = CreateFrame("Frame")
transitionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
transitionFrame:SetScript("OnEvent", function()
    hasWarnedMH = false
    hasWarnedOH = false
    -- Start delay timer to prevent false "dropped" messages during loading
    delayTimer = INITIAL_DELAY
end)

-- Check every 1 second; enchant warnings do not need per-frame updates.
C_Timer.NewTicker(1, function()
    if delayTimer > 0 then
        delayTimer = delayTimer - 1
    end

    CheckEnchantments()
end)
