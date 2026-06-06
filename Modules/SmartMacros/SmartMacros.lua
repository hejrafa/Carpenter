--[[ Carpenter - SmartMacros ]]
-- Schedules consumable macro refreshes; scanner and builder logic lives in helper modules.

local _, ns = ...
local addonFrame = CreateFrame("Frame")

local Data = ns and ns.Private and ns.Private.SmartMacroData or {}
local Scanner = ns and ns.Private and ns.Private.SmartMacroScanner or {}
local Builder = ns and ns.Private and ns.Private.SmartMacroBuilder or {}

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("smartMacrosEnabled")
end

local function IsRetail()
    return Data.IsRetail and Data.IsRetail()
end

local function GetActiveItems()
    return Data.GetActiveItems and Data.GetActiveItems() or {}
end

local lastBagFingerprint

local function ProcessUpdate(forceRescan)
    if not IsEnabled() then return end
    if InCombatLockdown() then
        addonFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local bagFingerprint = Scanner.GetBagFingerprint and Scanner.GetBagFingerprint() or ""
    if not forceRescan and bagFingerprint == lastBagFingerprint then
        return
    end
    lastBagFingerprint = bagFingerprint

    local bestItems, needsItemInfoRetry = {}, false
    if Scanner.GetBestItems then
        bestItems, needsItemInfoRetry = Scanner.GetBestItems()
    end

    for key, config in pairs(GetActiveItems()) do
        local best = bestItems[key]
        local body = (key == "Pot" and Builder.BuildHealthMacroBody)
            and Builder.BuildHealthMacroBody(best, bestItems.Healthstone)
            or (Builder.BuildMacroBody and Builder.BuildMacroBody(best) or "#showtooltip\n")

        if Builder.UpdateMacro then
            Builder.UpdateMacro(config.name, body, true)
            if config.legacyName then
                Builder.UpdateMacro(config.legacyName, body, false)
            end
        end
    end

    if IsRetail() and Builder.DeleteMacroByName and Data.Items then
        Builder.DeleteMacroByName(Data.Items.Band.name)
        Builder.DeleteMacroByName(Data.Items.Band.legacyName)
    end

    if needsItemInfoRetry then
        addonFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    else
        addonFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
end

local isDirty = false
local forceNextUpdate = false
local updateScheduled = false
local lastUpdateTime = 0

local function RunScheduledUpdate()
    updateScheduled = false
    if not isDirty then return end
    if not IsEnabled() then
        isDirty = false
        return
    end
    if InCombatLockdown() then
        addonFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local now = GetTime and GetTime() or 0
    if lastUpdateTime > 0 and now - lastUpdateTime < 2 then
        updateScheduled = true
        if Carpenter and Carpenter.Defer then
            Carpenter:Defer("SmartMacros:update", 2 - (now - lastUpdateTime), RunScheduledUpdate)
        else
            C_Timer.After(2 - (now - lastUpdateTime), RunScheduledUpdate)
        end
        return
    end

    isDirty = false
    local forceRescan = forceNextUpdate
    forceNextUpdate = false
    lastUpdateTime = now
    if Carpenter and Carpenter.Profile then
        Carpenter:Profile("SmartMacros:ProcessUpdate", ProcessUpdate, forceRescan)
    else
        ProcessUpdate(forceRescan)
    end
end

local function MarkDirty(delay, forceRescan)
    if not IsEnabled() then return end
    isDirty = true
    forceNextUpdate = forceNextUpdate or forceRescan
    if updateScheduled then return end
    updateScheduled = true
    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("SmartMacros:update", delay or 0.75, RunScheduledUpdate)
    else
        C_Timer.After(delay or 0.75, RunScheduledUpdate)
    end
end

addonFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        MarkDirty(0.25)
    elseif event == "PLAYER_ENTERING_WORLD" then
        MarkDirty(1.5, true)
    elseif event == "BAG_UPDATE" then
        MarkDirty(0.75, true)
    elseif event == "BAG_UPDATE_DELAYED" then
        MarkDirty(1.0)
    elseif event == "BAG_UPDATE_COOLDOWN" then
        MarkDirty(0.5, true)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        self:UnregisterEvent(event)
        MarkDirty(2.0, true)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        MarkDirty(0.5, true)
    end
end)

ns.UpdateSmartMacros = function()
    MarkDirty(0.25, true)
end

local feature = {}

function feature:Enable()
    addonFrame:RegisterEvent("BAG_UPDATE")
    addonFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    addonFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    addonFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    MarkDirty(1.5, true)
end

function feature:Disable()
    addonFrame:UnregisterAllEvents()
    isDirty = false
    updateScheduled = false
    forceNextUpdate = false
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("smartMacrosEnabled", feature)
end


SLASH_CARPENTERSMARTMACROS1 = "/cpmacros"
SlashCmdList["CARPENTERSMARTMACROS"] = function()
    if Scanner.GetBestItems then
        Scanner.GetBestItems(true)
    end
end
