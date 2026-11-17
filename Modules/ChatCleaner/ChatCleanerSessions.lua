--[[ Carpenter - ChatCleaner merchant and mailbox sessions ]]
-- While a merchant or the mailbox is open, the money lines that come one by
-- one are hidden (ChatCleanerRewards asks isOpen), and one line sums them up
-- when it closes: what you made or spent at the merchant, beyond what Auto
-- Sell Junk and Auto Repair already reported, and what you took from the
-- mail.
local _, ns = ...
ns.Private = ns.Private or {}

local Sessions = ns.Private.ChatCleanerSessions or {}
ns.Private.ChatCleanerSessions = Sessions

local Utils = ns.Private.ChatCleanerUtils

function Sessions.Create()
    -- Auto Sell Junk and Auto Repair note there what they did at this visit.
    local merchantState = Carpenter.MerchantState

    local function PrintSummary(amount)
        if amount > 0 then
            print(Utils.PREFIX_PLUS .. Carpenter:FormatMoney(amount))
        elseif amount < 0 then
            print(Utils.PREFIX_MINUS .. Carpenter:FormatMoney(-amount))
        end
    end

    local merchantFrame = CreateFrame("Frame")
    local merchantMoneyAtOpen = 0
    local merchantZoningGuard = false
    local merchantSession = 0
    local merchantClosedSession = nil

    -- The last sale's money line can come just after the merchant closes, so
    -- money lines stay hidden a moment longer.
    local function DeferMerchantClosed(frame)
        local closedSession = merchantSession
        C_Timer.After(0.5, function()
            if merchantSession == closedSession then
                frame.isOpen = false
            end
        end)
    end

    merchantFrame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            merchantSession = merchantSession + 1
            merchantClosedSession = nil
            merchantState.autoSoldJunk = false
            merchantState.autoSoldAmount = nil
            merchantState.autoRepaired = false
            merchantState.autoRepairAmount = nil
            merchantZoningGuard = false
            self.isOpen = true
            merchantMoneyAtOpen = GetMoney()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- A loading screen closes the merchant without a visit to sum up.
            merchantSession = merchantSession + 1
            merchantClosedSession = nil
            merchantZoningGuard = true
            self.isOpen = false
        elseif event == "MERCHANT_CLOSED" then
            if merchantZoningGuard then
                self.isOpen = false
                merchantClosedSession = merchantSession
                return
            end
            -- The game can send MERCHANT_CLOSED twice for one visit.
            if merchantClosedSession == merchantSession or not self.isOpen then
                return
            end
            merchantClosedSession = merchantSession

            -- What Auto Sell Junk earned and Auto Repair spent (noted as a
            -- negative amount) is already in chat, so both come off.
            local net = GetMoney() - merchantMoneyAtOpen
            if merchantState.autoSoldJunk and type(merchantState.autoSoldAmount) == "number" then
                net = net - merchantState.autoSoldAmount
            end
            if merchantState.autoRepaired and type(merchantState.autoRepairAmount) == "number" then
                net = net - merchantState.autoRepairAmount
            end
            PrintSummary(net)
            DeferMerchantClosed(self)
        end
    end)

    local mailLastMoney = 0
    local mailTotalCollected = 0
    local mailTracker = CreateFrame("Frame")
    mailTracker.isOpen = false

    mailTracker:SetScript("OnEvent", function(self, event)
        if event == "MAIL_SHOW" then
            if not self.isOpen then
                self.isOpen = true
                mailLastMoney = GetMoney()
                mailTotalCollected = 0
            end
        elseif event == "MAIL_CLOSED" then
            -- MAIL_CLOSED can come twice; the first one sums up.
            if self.isOpen then
                self.isOpen = false
                PrintSummary(mailTotalCollected)
                mailTotalCollected = 0
            end
        elseif event == "PLAYER_MONEY" and self.isOpen then
            local currentMoney = GetMoney()
            local diff = currentMoney - mailLastMoney
            if diff > 0 then
                mailTotalCollected = mailTotalCollected + diff
            end
            mailLastMoney = currentMoney
        end
    end)

    local api = {
        merchantFrame = merchantFrame,
        mailTracker = mailTracker,
    }

    function api:Enable()
        merchantFrame:RegisterEvent("MERCHANT_SHOW")
        merchantFrame:RegisterEvent("MERCHANT_CLOSED")
        merchantFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        mailTracker:RegisterEvent("MAIL_SHOW")
        mailTracker:RegisterEvent("MAIL_CLOSED")
        mailTracker:RegisterEvent("PLAYER_MONEY")
    end

    function api:Disable()
        merchantFrame:UnregisterAllEvents()
        merchantFrame.isOpen = false
        mailTracker:UnregisterAllEvents()
        mailTracker.isOpen = false
        mailTotalCollected = 0
    end

    return api
end
