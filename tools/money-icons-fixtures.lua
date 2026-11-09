#!/usr/bin/env lua
-- Pins which coin art money lines use: Forever matches its newer money frames,
-- and every other client keeps the older files.

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

local core = LoadCore({ isMainline = true, isForever = true })
local expected = "1|r |A:coin-gold:14:14:2:0|a 23|r |A:coin-silver:14:14:2:0|a 45|r |A:coin-copper:14:14:2:0|a"
assert(core:FormatMoney(12345, "") == expected, "Forever should use its newer coins, got " .. core:FormatMoney(12345, ""))
assert(core:FormatMoney(45, "") == "45|r |A:coin-copper:14:14:2:0|a", "Forever should show copper alone, got " .. core:FormatMoney(45, ""))

expected = "1|r |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t 23|r |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t 45|r |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
for name, client in pairs({
    Retail = { isMainline = true, isRetail = true },
    TBC = { isTBC = true, isClassic = true },
    Vanilla = { isVanilla = true, isClassic = true },
}) do
    core = LoadCore(client)
    assert(core:FormatMoney(12345, "") == expected, name .. " should keep the older coins, got " .. core:FormatMoney(12345, ""))
end

print("money icons fixtures: passed")
