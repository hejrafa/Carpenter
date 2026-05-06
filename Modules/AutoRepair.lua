--[[ Carpenter - AutoRepair ]]
local _, ns = ...
local f = CreateFrame("Frame")
local L = ns and ns.L or {}

-- Grey + prefix, warm muted red‑orange text for repair (loss)
local Colors = ns and ns.Private and ns.Private.Colors
local ColorPlus   = Colors and Colors.gray and Colors.gray.colorCode or "|cffc8c8c8"
local ColorRepair = Colors and Colors.palered and Colors.palered.colorCode or "|cffd97a5c"

f:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        -- Defer so ChatCleaner's MERCHANT_SHOW runs first; then we set repair flags.
        Carpenter:After(0, function()
            if not Carpenter:IsEnabled("autoRepair") or IsShiftKeyDown() or not CanMerchantRepair() then return end
            local repairCost, canRepair = GetRepairAllCost()
            if canRepair and repairCost > 0 and GetMoney() >= repairCost then
                RepairAllItems()
                local M = Carpenter.MerchantState
                M.autoRepaired = true
                M.autoRepairAmount = -repairCost
                Carpenter:AddChatMessage((ColorPlus .. "-|r ") .. ColorRepair .. (L.GEAR_REPAIRED or "Gear repaired") .. ": " .. Carpenter:FormatMoney(repairCost) .. "|r")
            end
        end)
    end
end)

local feature = {}

function feature:Enable()
    f:RegisterEvent("MERCHANT_SHOW")
end

function feature:Disable()
    f:UnregisterAllEvents()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("autoRepair", feature)
end
