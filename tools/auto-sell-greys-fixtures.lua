#!/usr/bin/env lua
-- Offline fixture for Forever's namespaced item/container APIs.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local ns = {
    L = { SOLD_JUNK_ITEMS = "Sold junk items" },
    Private = {
        Colors = {
            gray = { colorCode = "" },
            quality = { [0] = { colorCode = "" } },
        },
    },
}

local addonFrame
local registeredFeature
local sold = {}
local messages = {}

function CreateFrame()
    addonFrame = { events = {} }
    function addonFrame:SetScript(_, handler) self.OnEvent = handler end
    function addonFrame:RegisterEvent(event) self.events[event] = true end
    function addonFrame:UnregisterAllEvents() self.events = {} end
    return addonFrame
end

function IsShiftKeyDown() return false end

C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemLink = function(bag, slot)
        if bag ~= 0 then return nil end
        return slot == 1 and "|Hitem:6948|h[Hearthstone]|h" or "|Hitem:1001|h[Chipped Fang]|h"
    end,
    GetContainerItemInfo = function(bag, slot)
        if bag ~= 0 then return nil end
        if slot == 1 then
            return { itemID = 6948, hyperlink = "|Hitem:6948|h[Hearthstone]|h", stackCount = 1, quality = 1, hasNoValue = true }
        end
        return { itemID = 1001, hyperlink = "|Hitem:1001|h[Chipped Fang]|h", stackCount = 2, quality = 0, hasNoValue = false }
    end,
    UseContainerItem = function(bag, slot)
        sold[#sold + 1] = { bag = bag, slot = slot }
    end,
}

C_Item = {
    GetItemInfo = function(item)
        local itemID = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
        if itemID == 1001 then
            return "Chipped Fang", "|Hitem:1001|h[Chipped Fang]|h", 0, 1, 1, "Miscellaneous", "Junk", 1, "", 0, 123
        end
        return "Hearthstone", "|Hitem:6948|h[Hearthstone]|h", 1, 1, 1, "Miscellaneous", "Junk", 1, "", 0, 0
    end,
}

GetItemInfo = nil
GetContainerNumSlots = nil
GetContainerItemInfo = nil
GetContainerItemLink = nil
UseContainerItem = nil

Carpenter = {
    MerchantState = {},
    IsEnabled = function(_, key) return key == "autoSellGreys" end,
    After = function(_, _, callback) callback() end,
    AddChatMessage = function(_, message) messages[#messages + 1] = message end,
    FormatMoney = function(_, amount) return tostring(amount) end,
    RegisterFeature = function(_, key, feature)
        if key == "autoSellGreys" then registeredFeature = feature end
    end,
}

local chunk = assert(loadfile(repo .. "/Modules/AutoSellGreys.lua"))
chunk("Carpenter", ns)

assert(registeredFeature and registeredFeature.Enable, "Auto Sell Greys feature was not registered")
registeredFeature:Enable()
assert(addonFrame.events.MERCHANT_SHOW, "MERCHANT_SHOW was not registered")

addonFrame:OnEvent("MERCHANT_SHOW")

assert(#sold == 1, "expected exactly one junk stack to be sold")
assert(sold[1].bag == 0 and sold[1].slot == 2, "expected the grey item in bag 0 slot 2 to be sold")
assert(Carpenter.MerchantState.autoSoldJunk == true, "merchant state did not record the automatic sale")
assert(Carpenter.MerchantState.autoSoldAmount == 246, "expected two items worth 123 copper each")
assert(#messages == 1 and messages[1]:find("246", 1, true), "sale summary did not include the vendor value")

print("auto-sell-greys fixtures: passed")
