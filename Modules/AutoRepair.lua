--[[ Carpenter - AutoRepair ]]
local _, ns = ...
local f = CreateFrame("Frame")
local L = ns and ns.L or {}

-- Grey + prefix, warm muted red‑orange text for repair (loss)
local Colors = ns and ns.Private and ns.Private.Colors
local ColorPlus   = Colors and Colors.gray and Colors.gray.colorCode or "|cffc8c8c8"
local ColorRepair = Colors and Colors.palered and Colors.palered.colorCode or "|cffd97a5c"

-- How long the server gets to refuse a guild repair before it counts as done.
local GUILD_REPAIR_RESULT_SECONDS = 0.5

-- The cost of a guild repair the server hasn't answered yet.
local pendingGuildRepairCost

local function ReportRepair(label, cost)
    Carpenter:AddChatMessage((ColorPlus .. "-|r ") .. ColorRepair .. label .. ": " .. Carpenter:FormatMoney(cost) .. "|r")
end

local function RepairWithOwnGold()
    local repairCost, canRepair = GetRepairAllCost()
    if canRepair and repairCost > 0 and GetMoney() >= repairCost then
        RepairAllItems()
        local M = Carpenter.MerchantState
        M.autoRepaired = true
        M.autoRepairAmount = -repairCost
        ReportRepair(L.GEAR_REPAIRED or "Gear repaired", repairCost)
    end
end

-- Whether the player's daily guild allowance covers the repair. The guild
-- leader's allowance reads -1, meaning no limit. The bank's own balance isn't
-- reliable until its window has been opened, so a short balance is left for
-- the server to refuse.
local function CanGuildPay(cost)
    if not (CarpenterDB and CarpenterDB.autoRepairGuildFundsEnabled == true) then return false end
    if not (CanGuildBankRepair and GetGuildBankWithdrawMoney and CanGuildBankRepair()) then return false end
    local allowance = GetGuildBankWithdrawMoney()
    return allowance == -1 or (allowance ~= nil and allowance >= cost)
end

local function RepairWithGuildFunds(cost)
    pendingGuildRepairCost = cost
    RepairAllItems(true)
    Carpenter:Defer("AutoRepair:guildResult", GUILD_REPAIR_RESULT_SECONDS, function()
        if not pendingGuildRepairCost then return end
        -- The player's gold isn't the guild's, so it stays out of the merchant
        -- summary's repair amount. Anything they did pay still shows there.
        ReportRepair(L.GEAR_REPAIRED_GUILD or "Gear repaired with guild funds", pendingGuildRepairCost)
        pendingGuildRepairCost = nil
    end)
end

-- A short guild bank refuses the repair, and one that splits the cost refuses
-- it if the player can't cover their part.
local function IsGuildRepairRefused(message)
    if issecretvalue and issecretvalue(message) then return false end
    return message == ERR_GUILD_NOT_ENOUGH_MONEY or message == ERR_NOT_ENOUGH_MONEY
end

f:SetScript("OnEvent", function(self, event, _, message)
    if event == "MERCHANT_SHOW" then
        -- Defer so ChatCleaner's MERCHANT_SHOW runs first; then we set repair flags.
        Carpenter:After(0, function()
            if not Carpenter:IsEnabled("autoRepair") or IsShiftKeyDown() or not CanMerchantRepair() then return end
            local repairCost, canRepair = GetRepairAllCost()
            if not canRepair or repairCost <= 0 then return end
            if CanGuildPay(repairCost) then
                RepairWithGuildFunds(repairCost)
            else
                RepairWithOwnGold()
            end
        end)
    elseif event == "UI_ERROR_MESSAGE" and pendingGuildRepairCost and IsGuildRepairRefused(message) then
        pendingGuildRepairCost = nil
        RepairWithOwnGold()
    end
end)

local feature = {}

function feature:Enable()
    f:RegisterEvent("MERCHANT_SHOW")
    f:RegisterEvent("UI_ERROR_MESSAGE")
end

function feature:Disable()
    f:UnregisterAllEvents()
    pendingGuildRepairCost = nil
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("autoRepair", feature)
end
