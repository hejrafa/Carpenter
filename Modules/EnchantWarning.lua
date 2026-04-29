--[[ Carpenter - EnchantWarning ]]
-- Warns before weapon enchantments expire.

local checkFrame = CreateFrame("Frame")
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

local function GetEnchantName(slot)
    -- Scan weapon tooltip for temp enchant (green text)
    -- slot 16 = main hand, slot 17 = off hand
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem("player", slot)

    -- Look through all tooltip lines for green text that contains a time remaining pattern
    for i = 1, scanTooltip:NumLines() do
        local line = _G["CarpenterScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                local r, g, b = line:GetTextColor()
                -- Green text indicates enchants
                if g and g > 0.9 and r and r < 0.5 and b and b < 0.5 then
                    -- Check if the line contains a time indicator like "(15 min)" or "(30 sec)"
                    if text:find("%(%d+ min%)") or text:find("%(%d+ sec%)") or text:find("%(%d+ hr%)") then
                        -- Strip the time part for a cleaner message
                        local name = text:gsub(" %(%d+ %a+%)", "")
                        scanTooltip:Hide()
                        return name
                    end
                end
            end
        end
    end

    scanTooltip:Hide()
    return nil
end

local function CheckEnchantments()
    -- Don't check if disabled
    if not CarpenterDB or not CarpenterDB.enchantWarningEnabled then
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

    -- Main hand logic
    if hasMainEnchant then
        local secondsLeft = mainTimeLeft / 1000
        local currentName = GetEnchantName(16)

        if currentName then lastEnchantNameMH = currentName end
        local displayName = lastEnchantNameMH or "Main Hand Poison"

        if secondsLeft <= 120 and secondsLeft > 110 and not hasWarnedMH then
            UIErrorsFrame:AddMessage(displayName .. " falling off in 2 min", 1.0, 0.5, 0.0, 1.0, 5)
            hasWarnedMH = true
        end

        if secondsLeft > 120 then
            hasWarnedMH = false
        end
    else
        if lastEnchantNameMH then
            UIErrorsFrame:AddMessage(lastEnchantNameMH .. " is no longer on the weapon", 1.0, 0.1, 0.0, 1.0, 5)
            lastEnchantNameMH = nil
        end
        hasWarnedMH = false
    end

    -- Off hand logic
    if hasOffEnchant then
        local secondsLeft = offTimeLeft / 1000
        local currentName = GetEnchantName(17)

        if currentName then lastEnchantNameOH = currentName end
        local displayName = lastEnchantNameOH or "Off Hand Poison"

        if secondsLeft <= 120 and secondsLeft > 110 and not hasWarnedOH then
            UIErrorsFrame:AddMessage(displayName .. " falling off in 2 min", 1.0, 0.5, 0.0, 1.0, 5)
            hasWarnedOH = true
        end

        if secondsLeft > 120 then
            hasWarnedOH = false
        end
    else
        if lastEnchantNameOH then
            UIErrorsFrame:AddMessage(lastEnchantNameOH .. " is no longer on the weapon", 1.0, 0.1, 0.0, 1.0, 5)
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

-- Check every 1 second and handle delay timer
checkFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Handle loading delay
    if delayTimer > 0 then
        delayTimer = delayTimer - elapsed
    end

    self.timer = (self.timer or 0) + elapsed
    if self.timer >= 1 then
        CheckEnchantments()
        self.timer = 0
    end
end)
