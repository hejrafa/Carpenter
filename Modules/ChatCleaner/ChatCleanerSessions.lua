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

    -- The mailbox opens and closes differently per client. Retail and
    -- Forever open it through the interaction manager and don't send
    -- MAIL_SHOW (Postal watches the same events there); Classic sends
    -- MAIL_SHOW, and TBC Anniversary doesn't always send MAIL_CLOSED, so the
    -- mail window closing ends the visit too. The first close sums up.
    local MAIL_INTERACTION = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo
    local mailLastMoney = 0
    local mailTotalCollected = 0
    local mailTracker = CreateFrame("Frame")
    mailTracker.isOpen = false

    local function CloseMailVisit()
        if not mailTracker.isOpen then return end
        mailTracker.isOpen = false
        PrintSummary(mailTotalCollected)
        mailTotalCollected = 0
    end

    local mailFrameHooked = false
    local function OpenMailVisit()
        if mailTracker.isOpen then return end
        mailTracker.isOpen = true
        mailLastMoney = GetMoney()
        mailTotalCollected = 0
        -- Some clients load the mail window with the first mailbox.
        if not mailFrameHooked and _G.MailFrame then
            _G.MailFrame:HookScript("OnHide", CloseMailVisit)
            mailFrameHooked = true
        end
    end

    mailTracker:SetScript("OnEvent", function(self, event, interaction)
        if event == "MAIL_SHOW" then
            OpenMailVisit()
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            if interaction == MAIL_INTERACTION then OpenMailVisit() end
        elseif event == "MAIL_CLOSED" then
            CloseMailVisit()
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            if interaction == MAIL_INTERACTION then CloseMailVisit() end
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
        if MAIL_INTERACTION then
            mailTracker:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
            mailTracker:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
        end
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
