#!/usr/bin/env lua
-- Verifies Poison Warning warns two minutes before a weapon enchant ends and
-- when it wears off, both on WoW Forever (C_Item.GetWeaponEnchantInfo per
-- slot) and on Classic (the old GetWeaponEnchantInfo global).

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local failures = {}
local function check(condition, message)
    if not condition then failures[#failures + 1] = message end
end

local function Run(clientName, setupClient)
    local messages = {}
    local ticker
    local enchant = { has = true, msLeft = 115000 }

    ITEM_ENCHANT_TIME_LEFT_MIN = "%s (%d min)"
    ITEM_ENCHANT_TIME_LEFT_SEC = "%s (%d sec)"
    UIErrorsFrame = { AddMessage = function(_, text) messages[#messages + 1] = text end }
    UIParent, WorldFrame = {}, {}
    MerchantFrame, GameTooltip = nil, nil
    IsBagOpen = function() return false end
    CreateFrame = function(_, name)
        local frameObject = {}
        function frameObject:SetOwner() end
        function frameObject:ClearLines() end
        function frameObject:SetInventoryItem() end
        function frameObject:NumLines() return 1 end
        function frameObject:Hide() end
        function frameObject:RegisterEvent() end
        function frameObject:SetScript() end
        if name then _G[name] = frameObject end
        return frameObject
    end
    _G.CarpenterScanTooltipTextLeft1 = {
        GetText = function() return enchant.has and "Instant Poison VI (2 min)" or nil end,
        GetTextColor = function() return 0, 1, 0 end,
    }
    C_Timer = { NewTicker = function(_, callback)
        ticker = { callback = callback, Cancel = function(self) self.cancelled = true end }
        return ticker
    end }

    setupClient(enchant)

    local feature
    CarpenterDB = { enchantWarningEnabled = true }
    Carpenter = {
        L = {},
        Client = clientName == "forever" and { isForever = true, isRetail = true } or { isVanilla = true },
        IsEnabled = function(_, key) return CarpenterDB[key] == true end,
        RegisterFeature = function(_, _, registered) feature = registered end,
    }

    assert(loadfile(repo .. "/Modules/EnchantWarning.lua"))("Carpenter", { Private = {} })
    feature:Enable()
    assert(ticker, clientName .. ": enabling should start the check")

    -- Two minutes left: warn once.
    ticker.callback()
    ticker.callback()
    check(#messages == 1 and messages[1]:find("Instant Poison VI", 1, true) and messages[1]:find("2 min", 1, true),
        clientName .. ": expected one two-minute warning, got [" .. table.concat(messages, " | ") .. "]")

    -- The enchant wears off.
    enchant.has = false
    ticker.callback()
    check(#messages == 2 and messages[2]:find("worn off", 1, true),
        clientName .. ": expected a worn off message, got [" .. tostring(messages[2]) .. "]")

    feature:Disable()
    check(ticker.cancelled, clientName .. ": disabling should stop the check")
end

-- WoW Forever: per-slot enchant lists, no old global.
Run("forever", function(enchant)
    GetWeaponEnchantInfo = nil
    Enum = { WeaponSlot = { MainHand = 0, OffHand = 1, Ranged = 2 } }
    C_Item = {
        GetWeaponEnchantInfo = function(slot)
            if slot == Enum.WeaponSlot.MainHand and enchant.has then
                return { { hasEnchant = true, timeLeft = enchant.msLeft, charges = 0, enchantID = 1, enchantType = 0 } }
            end
            return {}
        end,
    }
    C_TooltipInfo = {
        GetInventoryItem = function()
            if not enchant.has then return { lines = {} } end
            return { lines = { { leftText = "Instant Poison VI (2 min)", leftColor = { r = 0, g = 1, b = 0 } } } }
        end,
    }
end)

-- Classic: the old global.
Run("classic", function(enchant)
    C_Item, C_TooltipInfo, Enum = nil, nil, nil
    GetWeaponEnchantInfo = function()
        return enchant.has, enchant.has and enchant.msLeft or nil, nil, nil, false, nil
    end
end)

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("enchant warning fixtures passed")
