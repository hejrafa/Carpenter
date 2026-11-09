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
}, "1|r |A:coin-gold:14:14:2:0|a 23|r |A:coin-silver:14:14:2:0|a 45|r |A:coin-copper:14:14:2:0|a", "use the newer coins")

CheckClients({
    TBC = { isTBC = true, isClassic = true },
    Vanilla = { isVanilla = true, isClassic = true },
}, "1|r |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t 23|r |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t 45|r |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", "keep the older coins")

-- Smaller amounts leave out the coins they don't need.
local core = LoadCore({ isMainline = true, isRetail = true })
assert(core:FormatMoney(45, "") == "45|r |A:coin-copper:14:14:2:0|a", "copper alone should show one coin, got " .. core:FormatMoney(45, ""))

print("money icons fixtures: passed")
