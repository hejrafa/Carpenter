--[[ Carpenter - AutoSellGreys ]]
local _, ns = ...
local f = CreateFrame("Frame")
local L = ns and ns.L or {}

-- Grey + prefix, grey text for junk (poor quality)
local Colors   = ns and ns.Private and ns.Private.Colors
local ColorPlus = Colors and Colors.gray and Colors.gray.colorCode or "|cffc8c8c8"
local ColorJunk = Colors and Colors.quality and Colors.quality[0] and Colors.quality[0].colorCode or "|cff9d9d9d"

local sellAttemptedThisMerchant = false
local GetItemDetails = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local function SellGreyItems()
    if sellAttemptedThisMerchant then return end
    sellAttemptedThisMerchant = true
    if not Carpenter:IsEnabled("autoSellGreys") then return end
    
    -- Don't sell if Shift is held
    if IsShiftKeyDown() then return end
    
    -- Handle API differences: Classic may not have C_Container
    local getNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getItemInfo = (C_Container and C_Container.GetContainerItemInfo) or GetContainerItemInfo
    local getItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
    local useContainerItem = (C_Container and C_Container.UseContainerItem) or _G.UseContainerItem

    if not getNumSlots or not getItemInfo or not useContainerItem then return end

    local function GetSlotInfo(bag, slot)
        local values = { getItemInfo(bag, slot) }
        if type(values[1]) == "table" then
            local info = values[1]
            return {
                hyperlink = info.hyperlink,
                itemID = info.itemID,
                stackCount = info.stackCount or info.quantity,
                quality = info.quality,
                hasNoValue = info.hasNoValue,
            }
        end

        return {
            hyperlink = values[7],
            itemID = values[10],
            stackCount = values[2],
            quality = values[4],
            hasNoValue = values[9],
        }
    end

    local totalSold = 0
    local totalValue = 0

    for bag = 0, 4 do
        local numSlots = getNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local info = GetSlotInfo(bag, slot)
                local itemLink = info.hyperlink or (getItemLink and getItemLink(bag, slot))
                local quality = info.quality
                local vendorPrice

                if GetItemDetails and (info.itemID or itemLink) then
                    local _, _, itemQuality, _, _, _, _, _, _, _, itemVendorPrice =
                        GetItemDetails(info.itemID or itemLink)
                    quality = quality or itemQuality
                    vendorPrice = itemVendorPrice
                end

                if quality == 0 and info.stackCount and info.stackCount > 0 and not info.hasNoValue then
                    useContainerItem(bag, slot)
                    totalSold = totalSold + info.stackCount
                    -- Track the total vendor value of junk sold so we can show
                    -- an immediate amount unaffected by repairs or purchases.
                    if vendorPrice and vendorPrice > 0 then
                        totalValue = totalValue + (vendorPrice * info.stackCount)
                    end
                end
            end
        end
    end
    
    if totalSold > 0 then
        -- Mark that this merchant session auto-sold junk so ChatCleaner
        -- can suppress its net summary when the only change was junk sold.
        local M = Carpenter.MerchantState
        M.autoSoldJunk = true
        M.autoSoldAmount = totalValue
        if totalValue > 0 then
            Carpenter:AddChatMessage((ColorPlus .. "+|r ") .. ColorJunk .. (L.SOLD_JUNK_ITEMS or "Sold junk items") .. ": " .. Carpenter:FormatMoney(totalValue) .. "|r")
        else
            Carpenter:AddChatMessage((ColorPlus .. "+|r ") .. ColorJunk .. (L.SOLD_JUNK_ITEMS or "Sold junk items") .. "|r")
        end
    end
end

f:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        -- Defer so ChatCleaner's MERCHANT_SHOW runs first and clears flags;
        -- then we set merchantAutoSoldJunk/Amount for MERCHANT_CLOSED suppression.
        Carpenter:After(0, SellGreyItems)
    elseif event == "MERCHANT_CLOSED" then
        sellAttemptedThisMerchant = false
    end
end)

local feature = {}

function feature:Enable()
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("MERCHANT_CLOSED")
end

function feature:Disable()
    f:UnregisterAllEvents()
    sellAttemptedThisMerchant = false
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("autoSellGreys", feature)
end
