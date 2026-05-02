local addonName, ns = ...
ns = ns or {}

Carpenter = Carpenter or {}
ns.Private = ns.Private or {}

CarpenterDB = CarpenterDB or {}

local L = ns.L or Carpenter.L or {}

local defaults = {
    -- Action Bars
    hideMacroNamesEnabled = false,
    hideKeybindsEnabled = false,
    actionBarFaderEnabled = false,
    actionBarRangeEnabled = false,
    hideStanceBarEnabled = false,
    -- Interface
    menuTransparencyEnabled = false,
    smallerExpBarEnabled = false,
    minimapClutterEnabled = false,
    enhanceTooltipEnabled = false,
    scaleExtraAbilityEnabled = false,
    -- Unit Frames
    classHealthColorsEnabled = false,
    threatIndicatorEnabled = false,
    unitFrameDebuffsEnabled = false,
    unitFrameClassIconEnabled = false,
    hideUnitFrameCombatTextEnabled = false,
    cleanUpUnitFramesEnabled = false,
    hideUnitFramePvPIconEnabled = false,
    hideUnitFramePowerBarEnabled = false,
    hideBossFramesEnabled = false,
    hideRestAnimationEnabled = false,
    hideHealthLossFxEnabled = false,
    hideGroupIndicatorEnabled = false,
    hideRealmIndicatorEnabled = false,
    hidePlayerCornerIconEnabled = false,
    hidePartyFrameTitleEnabled = false,
    hideTargetReputationColorEnabled = false,
    -- Nameplates
    debuffTrackerEnabled = false,
    nameplateComboEnabled = false,
    nameplateCastNamesEnabled = false,
    nameplateClassHealthEnabled = false,
    raidTargetIconAlignedEnabled = false,
    -- Chat
    chatFilterEnabled = false,
    filterGuildRecruitEnabled = false,
    filterTradeBotsEnabled = false,
    filterGamblingEnabled = false,
    filterDuplicatesEnabled = false,
    filterRestedXPEnabled = false,
    chatCleanerEnabled = false,
    hideChatButtonsEnabled = false,
    -- Automations
    autoCarrotEnabled = false,
    autoCarrotSlot = 14,
    smartMacrosEnabled = false,
    autoTrackQuestsEnabled = false,
    autoSellGreys = false,
    autoRepair = false,
    -- Text
    enchantWarningEnabled = false,
    hideErrorMessagesEnabled = false,
    -- Immersion
    actionCamEnabled = false,
}

Carpenter.Defaults = defaults
Carpenter.MerchantState = _G["Carpenter_MerchantState"] or {}
_G["Carpenter_MerchantState"] = Carpenter.MerchantState

ns.Private.Colors = ns.Private.Colors or {
    gray = { colorCode = "|cffc8c8c8" },
    white = { colorCode = "|cffffffff" },
    palered = { colorCode = "|cffd97a5c" },
    quality = {
        [0] = { colorCode = "|cff9d9d9d" },
    },
}

function Carpenter:IsEnabled(key, defaultWhenUnset)
    if Carpenter.IsFeatureAvailable and not Carpenter:IsFeatureAvailable(key) then
        return false
    end
    if not CarpenterDB then
        return defaultWhenUnset == true
    end
    if CarpenterDB[key] == nil then
        return defaultWhenUnset == true
    end
    return CarpenterDB[key] == true
end

function Carpenter:After(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    elseif delay == 0 then
        callback()
    end
end

local GoldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local SilverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local CopperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

function Carpenter:FormatMoney(amount, amountColor)
    amountColor = amountColor or ns.Private.Colors.white.colorCode
    amount = amount or 0

    local gold = floor(amount / 10000)
    local silver = floor((amount % 10000) / 100)
    local copper = amount % 100
    local str = ""

    if gold > 0 then
        str = str .. amountColor .. gold .. "|r " .. GoldIcon .. " "
    end
    if silver > 0 or gold > 0 then
        str = str .. amountColor .. silver .. "|r " .. SilverIcon .. " "
    end

    return str .. amountColor .. copper .. "|r " .. CopperIcon
end

function Carpenter:AddChatMessage(msg)
    local frame = DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
        frame:AddMessage(msg, 1, 1, 1)
    else
        print(msg)
    end
end

function Carpenter_InitializeSettings()
    if CarpenterDB and Carpenter.Client and Carpenter.Client.isRetail and
        CarpenterDB.hideUnitFrameCombatTextEnabled == true and
        CarpenterDB.cleanUpUnitFramesEnabled ~= true then
        CarpenterDB.cleanUpUnitFramesEnabled = true
    end

    if CarpenterDB and CarpenterDB.cleanUpUnitFramesEnabled == nil then
        local legacyCleanUpKeys = {
            "hideUnitFramePvPIconEnabled",
            "hideRestAnimationEnabled",
            "hideHealthLossFxEnabled",
            "hideRealmIndicatorEnabled",
            "hidePlayerCornerIconEnabled",
            "hidePartyFrameTitleEnabled",
            "hideTargetReputationColorEnabled",
        }
        for _, key in ipairs(legacyCleanUpKeys) do
            if CarpenterDB[key] == true then
                CarpenterDB.cleanUpUnitFramesEnabled = true
                break
            end
        end
    end

    for key, value in pairs(defaults) do
        if CarpenterDB[key] == nil then
            CarpenterDB[key] = value
        end
    end
end

SLASH_CARPENTER1 = "/carpenter"
SLASH_CARPENTER2 = "/cp"
SlashCmdList["CARPENTER"] = function()
    if type(Carpenter_OpenConfig) == "function" then
        Carpenter_OpenConfig()
    else
        print("|cffff0000Carpenter:|r " .. (L.CONFIG_NOT_LOADED or "Config UI not loaded."))
    end
end

Carpenter.Perf = Carpenter.Perf or {
    enabled = false,
    data = {},
    startedAt = nil,
}

function Carpenter:Profile(label, callback, ...)
    if not self.Perf or not self.Perf.enabled or type(callback) ~= "function" or not debugprofilestop then
        return callback(...)
    end

    local start = debugprofilestop()
    local results = { callback(...) }
    local elapsed = debugprofilestop() - start
    local bucket = self.Perf.data[label]
    if not bucket then
        bucket = { calls = 0, total = 0, max = 0 }
        self.Perf.data[label] = bucket
    end
    bucket.calls = bucket.calls + 1
    bucket.total = bucket.total + elapsed
    if elapsed > bucket.max then bucket.max = elapsed end
    return unpack(results)
end

local function ResetPerf()
    Carpenter.Perf.data = {}
    Carpenter.Perf.startedAt = debugprofilestop and debugprofilestop() or nil
end

local function PrintPerf()
    local rows = {}
    for label, bucket in pairs(Carpenter.Perf.data or {}) do
        rows[#rows + 1] = {
            label = label,
            calls = bucket.calls or 0,
            total = bucket.total or 0,
            max = bucket.max or 0,
        }
    end
    table.sort(rows, function(a, b) return a.total > b.total end)

    local window = Carpenter.Perf.startedAt and debugprofilestop and ((debugprofilestop() - Carpenter.Perf.startedAt) / 1000) or nil
    print("|cff00aaffCarpenter perf|r " .. (Carpenter.Perf.enabled and "enabled" or "disabled"))
    if window and window > 0 then
        local total = 0
        for _, bucket in pairs(Carpenter.Perf.data or {}) do
            total = total + (bucket.total or 0)
        end
        print(string.format("Sample window: %.1fs, measured Carpenter CPU: %.2fms (%.4f%% of wall time)", window, total, (total / (window * 1000)) * 100))
    end
    if #rows == 0 then
        print("No Carpenter samples yet.")
        return
    end
    for i = 1, math.min(#rows, 12) do
        local row = rows[i]
        local avg = row.calls > 0 and (row.total / row.calls) or 0
        print(string.format("%s: %.2fms total, %.2fms max, %.3fms avg, %d calls", row.label, row.total, row.max, avg, row.calls))
    end
end

SLASH_CARPENTERPERF1 = "/cpperf"
SlashCmdList["CARPENTERPERF"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" or msg == "start" then
        Carpenter.Perf.enabled = true
        ResetPerf()
        print("|cff00aaffCarpenter perf enabled.|r Fly around, then run /cpperf.")
    elseif msg == "off" or msg == "stop" then
        Carpenter.Perf.enabled = false
        PrintPerf()
    elseif msg == "reset" then
        ResetPerf()
        print("|cff00aaffCarpenter perf reset.|r")
    else
        PrintPerf()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, addon)
    if (event == "ADDON_LOADED" and addon == addonName) or event == "PLAYER_ENTERING_WORLD" then
        Carpenter_InitializeSettings()
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end
end)
