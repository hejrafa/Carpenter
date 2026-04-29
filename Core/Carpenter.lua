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
    -- Unit Frames
    classHealthColorsEnabled = false,
    threatIndicatorEnabled = false,
    unitFrameDebuffsEnabled = false,
    unitFrameClassIconEnabled = false,
    hideUnitFrameCombatTextEnabled = false,
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
