--[[ Carpenter - EnchantWarning ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}
local L = (Carpenter and Carpenter.L) or {}
-- Warns before weapon enchantments expire.

-- One entry per weapon hand. name, expiresAt and charges describe the enchant
-- last seen on it; warned is set once its two-minute warning has shown.
local hands = {
    { slot = 16, fallbackKey = "MAIN_HAND_POISON", fallback = "Main Hand Poison" },
    { slot = 17, fallbackKey = "OFF_HAND_POISON", fallback = "Off Hand Poison" },
}

-- An enchant that disappears counts as worn off only if, when last seen, it
-- was this close to its end (checks run every second) or down to this few
-- charges. With more left, the client just isn't reporting it (around loading
-- screens), or the weapon was swapped and took its enchant along.
local EXPIRY_SLACK = 3
local LOW_CHARGES = 3

-- Delay logic for zone transitions
local INITIAL_DELAY = 5 -- Seconds to wait after loading screen
local delayTimer = 0
local loading = false

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

-- WoW Forever reads weapon enchants per slot through C_Item, like its own buff
-- frame; Classic clients still have the old global. Returns { has, msLeft,
-- charges } for the main hand and the off hand.
local function GetWeaponEnchants()
    if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.WeaponSlot then
        local function ReadSlot(slot)
            local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot)
            if ok and type(enchants) == "table" then
                for _, enchant in pairs(enchants) do
                    if enchant.hasEnchant then
                        return { has = true, msLeft = enchant.timeLeft, charges = enchant.charges }
                    end
                end
            end
            return { has = false }
        end

        return ReadSlot(Enum.WeaponSlot.MainHand), ReadSlot(Enum.WeaponSlot.OffHand)
    end

    if GetWeaponEnchantInfo then
        local hasMain, mainLeft, mainCharges, _, hasOff, offLeft, offCharges = GetWeaponEnchantInfo()
        return { has = hasMain, msLeft = mainLeft, charges = mainCharges },
            { has = hasOff, msLeft = offLeft, charges = offCharges }
    end
end

local function IsSecretEnchant(enchant)
    return IsSecret(enchant.has) or IsSecret(enchant.msLeft) or IsSecret(enchant.charges)
end

local function Forget(hand)
    hand.seen, hand.name, hand.expiresAt, hand.charges, hand.warned = nil, nil, nil, nil, false
end

local function DisplayName(hand)
    return hand.name or L[hand.fallbackKey] or hand.fallback
end

local function RanOut(hand, now)
    if hand.expiresAt and now >= hand.expiresAt - EXPIRY_SLACK then return true end
    local charges = hand.charges
    return type(charges) == "number" and charges > 0 and charges <= LOW_CHARGES
end

local function CheckHand(hand, enchant, now)
    if enchant.has then
        local secondsLeft = (tonumber(enchant.msLeft) or 0) / 1000
        local currentName = GetEnchantName(hand.slot)
        if currentName then hand.name = currentName end
        hand.seen = true
        -- A reading of no time left says nothing new: the one before it,
        -- a second earlier, already put the end that close.
        if secondsLeft > 0 then hand.expiresAt = now + secondsLeft end
        hand.charges = enchant.charges

        if secondsLeft <= 120 and secondsLeft > 110 and not hand.warned then
            UIErrorsFrame:AddMessage(string.format(L.ENCHANT_FALLING_OFF_SOON or "%s wears off in 2 min!", DisplayName(hand)), 1.0, 0.5, 0.0, 1.0, 5)
            hand.warned = true
        end
        if secondsLeft > 120 then
            hand.warned = false
        end
        return
    end

    if hand.seen and RanOut(hand, now) then
        UIErrorsFrame:AddMessage(string.format(L.ENCHANT_NO_LONGER_ON_WEAPON or "%s has worn off your weapon!", DisplayName(hand)), 1.0, 0.1, 0.0, 1.0, 5)
    end
    Forget(hand)
end

local function CheckEnchantments()
    -- Don't check if disabled
    if not (Carpenter and Carpenter:IsEnabled("enchantWarningEnabled")) then
        return
    end

    -- Skip check while loading and during the delay after it
    if loading or delayTimer > 0 then
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

    local mainHand, offHand = GetWeaponEnchants()
    if not mainHand or IsSecretEnchant(mainHand) or IsSecretEnchant(offHand) then
        return
    end

    local now = GetTime()
    CheckHand(hands[1], mainHand, now)
    CheckHand(hands[2], offHand, now)
end

-- Zone transitions (hearthstone, battlegrounds, dungeons): the client can
-- report no weapon enchant around a loading screen, so checks pause from
-- leaving the world until a moment after entering it.
local transitionFrame = CreateFrame("Frame")
transitionFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
transitionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
transitionFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        loading = true
        return
    end
    loading = false
    for _, hand in ipairs(hands) do
        hand.warned = false
    end
    delayTimer = INITIAL_DELAY
end)

-- =========================
-- Weapon buff timers (WoW Forever)
-- =========================
-- Right after a loading screen the game reports the weapon enchant with no
-- time left, and its real time only a few seconds later (seen in a log on
-- 2026-11-12, with and without Carpenter). Blizzard's buff frame reads it at
-- that moment and keeps the timer until its next update, which can be minutes
-- away, so the weapon buff shows "0 s" and blinks. Updating the frame from
-- here would taint the buff buttons, so a post-hook only corrects what a
-- stuck button shows, its time and alpha, from the time the game reports,
-- until the frame updates by itself.
local StuckTimers = {}
do
    -- A weapon buff button's ID is the weapon's inventory slot.
    local WEAPON_SLOT_KEYS = { [16] = "MainHand", [17] = "OffHand", [18] = "Ranged" }
    -- A game reading this close to zero agrees with Blizzard's timer.
    local AGREE_SECONDS = 2
    local RECHECK_SECONDS = 0.5

    local active = false
    local hooked = false
    local endsByInfo = setmetatable({}, { __mode = "k" })
    local nextCheckByInfo = setmetatable({}, { __mode = "k" })
    local loadFrame

    local function GameSecondsLeft(inventorySlot)
        local key = WEAPON_SLOT_KEYS[inventorySlot]
        local slot = key and Enum and Enum.WeaponSlot and Enum.WeaponSlot[key]
        if slot == nil or not (C_Item and C_Item.GetWeaponEnchantInfo) then return nil end
        local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot)
        if not ok or type(enchants) ~= "table" then return nil end
        for _, enchant in pairs(enchants) do
            local has, msLeft = enchant.hasEnchant, enchant.timeLeft
            if IsSecret(has) or IsSecret(msLeft) then return nil end
            if has then
                return type(msLeft) == "number" and msLeft / 1000 or nil
            end
        end
    end

    -- When the button's weapon buff should end, if Blizzard's timer is stuck
    -- at zero while the game reports time left.
    local function CorrectedEnd(button, timeLeft, now)
        local info = button.buttonInfo
        if type(info) ~= "table" then return nil end
        local ends = endsByInfo[info]
        if ends then return ends end
        if type(timeLeft) ~= "number" or IsSecret(timeLeft) or timeLeft > 0 then return nil end
        if (nextCheckByInfo[info] or 0) > now then return nil end
        nextCheckByInfo[info] = now + RECHECK_SECONDS
        local left = GameSecondsLeft(info.ID)
        if not left or left <= AGREE_SECONDS then return nil end
        endsByInfo[info] = now + left
        return endsByInfo[info]
    end

    -- Runs after Blizzard's UpdateDuration, which the button's OnUpdate calls
    -- each frame after setting its blink alpha.
    local function Correct(button, timeLeft)
        if not active or button.auraType ~= "TempEnchant" then return end
        local now = GetTime()
        local ends = CorrectedEnd(button, timeLeft, now)
        local left = ends and ends - now
        if not left or left <= 0 then return end

        local duration = button.Duration
        if duration and duration:IsShown() and SecondsToTimeAbbrev then
            duration:SetFormattedText(SecondsToTimeAbbrev(left))
            local color = left < (BUFF_DURATION_WARNING_TIME or 90) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
            if color then duration:SetVertexColor(color.r, color.g, color.b) end
        end
        -- Under the warning time a blink is right, and Blizzard already blinks.
        if left >= (BUFF_WARNING_TIME or 31) then
            local container = button:GetParent()
            button:SetAlpha(container and container.auraWarningMaxAlpha or 1)
        end
    end

    local function OnDurationUpdated(button, timeLeft)
        if active then pcall(Correct, button, timeLeft) end
    end

    local function Hook()
        if hooked then return true end
        local frame = _G.BuffFrame
        if not (frame and type(frame.auraFrames) == "table") then return false end
        for _, button in ipairs(frame.auraFrames) do
            if type(button) == "table" and type(button.UpdateDuration) == "function" then
                Carpenter:SafeHook(button, "UpdateDuration", OnDurationUpdated)
            end
        end
        hooked = true
        return true
    end

    function StuckTimers.Enable()
        local client = Carpenter and Carpenter.Client
        if not (client and client.isForever) then return end
        active = true
        if Hook() then return end
        if not loadFrame then
            loadFrame = CreateFrame("Frame")
            loadFrame:SetScript("OnEvent", function(self, _, addonName)
                if addonName == "Blizzard_BuffFrame" and Hook() then
                    self:UnregisterEvent("ADDON_LOADED")
                end
            end)
        end
        Carpenter:SafeRegisterEvent(loadFrame, "ADDON_LOADED")
    end

    function StuckTimers.Disable()
        active = false
        if loadFrame then loadFrame:UnregisterEvent("ADDON_LOADED") end
    end
end

-- Check every second while enabled; enchant warnings do not need per-frame updates.
local ticker

local feature = {}

function feature:Enable()
    StuckTimers.Enable()
    if ticker then return end
    ticker = C_Timer.NewTicker(1, function()
        if delayTimer > 0 then
            delayTimer = delayTimer - 1
        end

        CheckEnchantments()
    end)
end

function feature:Disable()
    StuckTimers.Disable()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    -- Forget the last enchant so turning it back on doesn't announce a stale one.
    for _, hand in ipairs(hands) do
        Forget(hand)
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("enchantWarningEnabled", feature)
end
