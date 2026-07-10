--[[ Carpenter - Thistle Tea Macro ]]
-- Part of the Rogue Macros feature alongside the poison macros. Brewing
-- Thistle Tea normally means opening Cooking, finding the recipe, and pressing
-- Create All at a fire. This creates a macro that does all of it in one press:
-- it opens Cooking and the addon crafts every available Thistle Tea as soon as
-- the trade skill window is ready.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local L = (Carpenter and Carpenter.L) or {}

local FEATURE_KEY = "poisonMacrosEnabled"
local MACRO_NAME = "CarpenterTea"
local TEA_ITEM_ID = 7676
local COOKING_SPELL_ID = 2550
local PENDING_SECONDS = 3
local DYNAMIC_MACRO_ICON = "INV_Misc_QuestionMark"

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local frame = CreateFrame("Frame")
local pendingUntil
local expandedThisAttempt = false

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

local function IsSupportedClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic and not Carpenter.Client.isRetail
end

local function IsRogue()
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

local function GetTeaName()
    if not GetItemInfo then return nil end
    return GetItemInfo(TEA_ITEM_ID)
end

local function GetCookingName()
    local name = GetSpellInfo and GetSpellInfo(COOKING_SPELL_ID)
    return name or "Cooking"
end

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Carpenter: " .. message)
    end
end

local function IsCookingWindowOpen()
    if type(GetTradeSkillLine) ~= "function" then return false end
    return GetTradeSkillLine() == GetCookingName()
end

local function FindTeaSkillIndex(teaName)
    if type(GetNumTradeSkills) ~= "function" or type(GetTradeSkillInfo) ~= "function" then return nil end
    local target = teaName:lower()
    for index = 1, GetNumTradeSkills() do
        local name, skillType, numAvailable = GetTradeSkillInfo(index)
        if name and skillType ~= "header" and name:lower() == target then
            return index, numAvailable or 0
        end
    end
end

local function TryBrew()
    if not pendingUntil then return end
    if GetTime() > pendingUntil then
        pendingUntil = nil
        return
    end
    if not IsCookingWindowOpen() then return end

    local teaName = GetTeaName()
    if not teaName then
        pendingUntil = nil
        Print(L.THISTLE_TEA_NOT_LOADED or "Thistle Tea item data is not loaded yet. Try again.")
        return
    end

    local index, numAvailable = FindTeaSkillIndex(teaName)
    if not index then
        -- Collapsed headers hide recipes from the scan; expand everything once
        -- and let the resulting TRADE_SKILL_UPDATE retry the search.
        if not expandedThisAttempt and type(ExpandTradeSkillSubClass) == "function" then
            expandedThisAttempt = true
            ExpandTradeSkillSubClass(0)
            return
        end
        pendingUntil = nil
        Print(L.THISTLE_TEA_NO_RECIPE or "Thistle Tea recipe not found in Cooking.")
        return
    end

    pendingUntil = nil
    if numAvailable < 1 then
        Print(L.THISTLE_TEA_MISSING or "Missing ingredients for Thistle Tea.")
        return
    end

    if type(DoTradeSkill) == "function" then
        DoTradeSkill(index, numAvailable)
    end
end

function _G.Carpenter_BrewThistleTea()
    if not IsEnabled() or not IsSupportedClient() or not IsRogue() then return end
    pendingUntil = GetTime() + PENDING_SECONDS
    expandedThisAttempt = false
    TryBrew()
end

local function BuildMacroBody()
    local teaName = GetTeaName()
    local tooltipLine = teaName and ("#showtooltip " .. teaName) or "#showtooltip"
    local body = tooltipLine
        .. "\n/cast " .. GetCookingName()
        .. "\n/run Carpenter_BrewThistleTea()"
    return body, teaName ~= nil
end

local function UpdateMacro()
    if not IsEnabled() or not IsSupportedClient() or not IsRogue() then return end
    if InCombatLockdown() then
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local body, hasItemName = BuildMacroBody()
    local macroIndex = GetMacroIndexByName(MACRO_NAME)
    if macroIndex == 0 then
        CreateMacro(MACRO_NAME, DYNAMIC_MACRO_ICON, body, 1)
    else
        local _, _, currentBody = GetMacroInfo(macroIndex)
        if currentBody ~= body then
            EditMacro(macroIndex, MACRO_NAME, DYNAMIC_MACRO_ICON, body)
        end
    end

    if hasItemName then
        frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    else
        frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    end
end

local function ScheduleMacroUpdate(delay)
    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ThistleTeaMacro:update", delay or 0.5, UpdateMacro)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.5, UpdateMacro)
    else
        UpdateMacro()
    end
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        TryBrew()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        ScheduleMacroUpdate(0.25)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ScheduleMacroUpdate(1.5)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if arg1 == TEA_ITEM_ID then
            self:UnregisterEvent(event)
            ScheduleMacroUpdate(0.5)
        end
    end
end)

local feature = {}

function feature:Enable()
    if not IsSupportedClient() or not IsRogue() then return end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_UPDATE")
    ScheduleMacroUpdate(1.5)
end

function feature:Disable()
    frame:UnregisterAllEvents()
    pendingUntil = nil
end

-- Enabled/disabled by PoisonMacros.lua as part of the shared
-- poisonMacrosEnabled feature.
ns.Private.ThistleTeaMacro = feature
