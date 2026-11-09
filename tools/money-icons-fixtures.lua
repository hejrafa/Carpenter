#!/usr/bin/env lua
-- Pins which coin art money lines use: Retail and Forever match their newer
-- money frames, and the Classic clients keep the older files.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local function LoadCore(client)
    SlashCmdList = {}
    floor = math.floor
    CarpenterDB = {}
    Carpenter = { Client = client }
    function CreateFrame()
        local frame = {}
        function frame:RegisterEvent() end
        function frame:UnregisterEvent() end
        function frame:SetScript() end
        return frame
    end
    assert(loadfile(repo .. "/Core/Carpenter.lua"))("Carpenter", { Private = {} })
    return Carpenter
end

local function CheckClients(clients, expected, description)
    for name, client in pairs(clients) do
        local core = LoadCore(client)
        local money = core:FormatMoney(12345, "")
        assert(money == expected, name .. " should " .. description .. ", got " .. money)
    end
end

CheckClients({
    Retail = { isMainline = true, isRetail = true },
    Forever = { isMainline = true, isForever = true },
}, "1|r|A:coin-gold:10:10:2:0|a 23|r|A:coin-silver:10:10:2:0|a 45|r|A:coin-copper:10:10:2:0|a", "use the newer coins, right after each amount")

CheckClients({
    TBC = { isTBC = true, isClassic = true },
    Vanilla = { isVanilla = true, isClassic = true },
}, "1|r|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t 23|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t 45|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", "keep the older coins, right after each amount")

-- Smaller amounts leave out the coins they don't need.
local core = LoadCore({ isMainline = true, isRetail = true })
assert(core:FormatMoney(45, "") == "45|r|A:coin-copper:10:10:2:0|a", "copper alone should show one coin, got " .. core:FormatMoney(45, ""))

-- The minus sign lines up with "+", except where the chat font couldn't be checked.
for locale, expected in pairs({
    enUS = "\226\136\146",
    deDE = "\226\136\146",
    ruRU = "\226\136\146",
    koKR = "-",
    zhCN = "-",
    zhTW = "-",
}) do
    GetLocale = function() return locale end
    core = LoadCore({ isMainline = true, isForever = true })
    assert(core.MinusSign == expected, locale .. " has the wrong minus sign")
end
GetLocale = nil

print("money icons fixtures: passed")
