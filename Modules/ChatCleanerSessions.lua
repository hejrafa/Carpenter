--[[ Carpenter - ChatCleaner merchant/mail session tracking ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Sessions = ns.Private.ChatCleanerSessions or {}
ns.Private.ChatCleanerSessions = Sessions

function Sessions.Create(config)
    config = config or {}
    local formatMoney = config.FormatMoney or function(amount) return tostring(amount or 0) end
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorMinus = config.ColorMinus or "|cffc8c8c8"

    local merchantState = Carpenter and Carpenter.MerchantState or _G["Carpenter_MerchantState"] or {}
    _G["Carpenter_MerchantState"] = merchantState

    local merchantFrame = CreateFrame("Frame")
    local merchantMoneyAtOpen = 0
    local merchantZoningGuard = false
    local merchantSession = 0

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
            merchantState.autoSoldJunk = false
            merchantState.autoSoldAmount = nil
            merchantState.autoRepaired = false
            merchantState.autoRepairAmount = nil
            merchantZoningGuard = false
            self.isOpen = true
            merchantMoneyAtOpen = GetMoney()
        elseif event == "PLAYER_ENTERING_WORLD" then
            merchantSession = merchantSession + 1
            merchantZoningGuard = true
            self.isOpen = false
        elseif event == "MERCHANT_CLOSED" then
            if merchantZoningGuard then
                self.isOpen = false
                return
            end

            local current = GetMoney()
            local net = current - merchantMoneyAtOpen
            local adjusted = net
            if merchantState.autoSoldJunk and type(merchantState.autoSoldAmount) == "number" then
                adjusted = adjusted - merchantState.autoSoldAmount
            end
            if merchantState.autoRepaired and type(merchantState.autoRepairAmount) == "number" then
                adjusted = adjusted - merchantState.autoRepairAmount
            end

            if adjusted == 0 then
                DeferMerchantClosed(self)
                return
            end

            net = adjusted
            if net < 0 and (-net) > current then
                DeferMerchantClosed(self)
                return
            end

            if net > 0 then
                print((colorPlus .. "+|r ") .. formatMoney(net))
            elseif net < 0 then
                print((colorMinus .. "-|r ") .. formatMoney(-net))
            end

            DeferMerchantClosed(self)
        end
    end)

    local mailLastMoney = 0
    local mailTotalCollected = 0
    local mailTracker = CreateFrame("Frame")
    mailTracker.isOpen = false

    local function IsMailFrameVisible()
        return _G.MailFrame and _G.MailFrame.IsVisible and _G.MailFrame:IsVisible()
    end

    mailTracker:SetScript("OnUpdate", function(self, elapsed)
        if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then
            self:Hide()
            return
        end

        self._t = (self._t or 0) + elapsed
        if self._t < 0.2 then return end
        self._t = 0

        local visible = IsMailFrameVisible()
        if visible and not self.isOpen then
            self.isOpen = true
            mailLastMoney = GetMoney()
            mailTotalCollected = 0
        elseif not visible and self.isOpen then
            self.isOpen = false
            if mailTotalCollected > 0 then
                print((colorPlus .. "+|r ") .. formatMoney(mailTotalCollected))
            end
            mailTotalCollected = 0
        end
    end)
    mailTracker:Hide()

    mailTracker:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_MONEY" and self.isOpen then
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
        mailTracker:RegisterEvent("PLAYER_MONEY")
        mailTracker:Show()
    end

    function api:Disable()
        merchantFrame:UnregisterAllEvents()
        merchantFrame.isOpen = false
        mailTracker:UnregisterAllEvents()
        mailTracker:Hide()
        mailTracker.isOpen = false
        mailTotalCollected = 0
    end

    return api
end
