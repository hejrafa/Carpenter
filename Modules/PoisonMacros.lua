--[[ Carpenter - Poison Macros ]]
-- Creates Rogue poison application macros for Classic Era and TBC.

local _, ns = ...
ns.Private = ns.Private or {}

local frame = CreateFrame("Frame")

local POISON_MACROS = {
    {
        key = "Instant",
        macroName = "CarpenterInstant",
        missingText = "No Instant Poison found.",
        icon = "Ability_Poisons",
        itemIDs = {
            6947,  -- Instant Poison
            6949,  -- Instant Poison II
            6950,  -- Instant Poison III
            8926,  -- Instant Poison IV
            8927,  -- Instant Poison V
            8928,  -- Instant Poison VI
            21927, -- Instant Poison VII
        },
    },
    {
        key = "Crippling",
        macroName = "CarpenterCrippling",
        missingText = "No Crippling Poison found.",
        icon = "Ability_PoisonSting",
        itemIDs = {
            3775, -- Crippling Poison
            3776, -- Crippling Poison II
        },
    },
}

local poisonByItemID = {}
for _, config in ipairs(POISON_MACROS) do
    for rank, itemID in ipairs(config.itemIDs) do
        poisonByItemID[itemID] = {
            key = config.key,
            rank = rank,
        }
    end
end

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("poisonMacrosEnabled")
end

local function IsSupportedClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic and not Carpenter.Client.isRetail
end

local function IsRogue()
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

local function GetNameFromLink(itemLink)
    if not itemLink then return nil end
    return itemLink:match("|h%[(.-)%]|h") or itemLink:match("%[(.-)%]")
end

local function GetItemName(itemID, itemLink)
    local name
    if GetItemInfo then
        name = GetItemInfo(itemLink or itemID)
    end
    return name or GetNameFromLink(itemLink)
end

local function GetBagFingerprint()
    local parts = {}
    for bag = 0, 4 do
        local slots = GetNumSlots and GetNumSlots(bag) or 0
        parts[#parts + 1] = bag .. ":" .. slots
        for slot = 1, slots do
            local itemID = GetItemID and GetItemID(bag, slot)
            local itemLink = GetItemLink and GetItemLink(bag, slot)
            if not itemID and itemLink then
                itemID = tonumber(itemLink:match("item:(%d+)"))
            end
            if itemID and poisonByItemID[itemID] then
                parts[#parts + 1] = tostring(itemID)
            end
        end
    end
    return table.concat(parts, ";")
end

local function GetBestPoisons()
    local best = {}
    local needsRetry = false

    for bag = 0, 4 do
        local slots = GetNumSlots and GetNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = GetItemID and GetItemID(bag, slot)
            local itemLink = GetItemLink and GetItemLink(bag, slot)
            if not itemID and itemLink then
                itemID = tonumber(itemLink:match("item:(%d+)"))
            end

            local poisonInfo = itemID and poisonByItemID[itemID]
            if poisonInfo then
                local name = GetItemName(itemID, itemLink)
                if not name then
                    needsRetry = true
                end

                local current = best[poisonInfo.key]
                if not current or poisonInfo.rank > current.rank or (poisonInfo.rank == current.rank and itemID > current.itemID) then
                    best[poisonInfo.key] = {
                        itemID = itemID,
                        name = name,
                        rank = poisonInfo.rank,
                    }
                end
            end
        end
    end

    return best, needsRetry
end

local function BuildMacroBody(poison, missingText)
    if poison and poison.name then
        return "#showtooltip " .. poison.name .. "\n/use " .. poison.name .. "\n/use [button:1] 16; [button:2] 17"
    end
    return "#showtooltip\n/run print(\"Carpenter: " .. missingText .. "\")"
end

local function UpdateMacro(name, icon, body)
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex == 0 then
        CreateMacro(name, icon or "INV_Misc_QuestionMark", body, 1)
        return
    end

    local _, _, currentBody = GetMacroInfo(macroIndex)
    if currentBody ~= body then
        EditMacro(macroIndex, name, icon, body)
    end
end

local lastBagFingerprint

local function ProcessUpdate(forceRescan)
    if not IsEnabled() or not IsSupportedClient() or not IsRogue() then return end
    if InCombatLockdown() then
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local bagFingerprint = GetBagFingerprint()
    if not forceRescan and bagFingerprint == lastBagFingerprint then
        return
    end
    lastBagFingerprint = bagFingerprint

    local bestPoisons, needsRetry = GetBestPoisons()
    for _, config in ipairs(POISON_MACROS) do
        UpdateMacro(config.macroName, config.icon, BuildMacroBody(bestPoisons[config.key], config.missingText))
    end

    if needsRetry then
        frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    else
        frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
end

local isDirty = false
local forceNextUpdate = false
local updateScheduled = false

local function RunScheduledUpdate()
    updateScheduled = false
    if not isDirty then return end
    isDirty = false

    local forceRescan = forceNextUpdate
    forceNextUpdate = false
    if Carpenter and Carpenter.Profile then
        Carpenter:Profile("PoisonMacros:ProcessUpdate", ProcessUpdate, forceRescan)
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
        Carpenter:Defer("PoisonMacros:update", delay or 0.75, RunScheduledUpdate)
    else
        C_Timer.After(delay or 0.75, RunScheduledUpdate)
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        MarkDirty(0.25, true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        MarkDirty(1.5, true)
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        MarkDirty(0.75, true)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        self:UnregisterEvent(event)
        MarkDirty(1.0, true)
    end
end)

ns.UpdatePoisonMacros = function()
    MarkDirty(0.25, true)
end

local feature = {}

function feature:Enable()
    if not IsSupportedClient() then return end
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    MarkDirty(1.5, true)
end

function feature:Disable()
    frame:UnregisterAllEvents()
    isDirty = false
    forceNextUpdate = false
    updateScheduled = false
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("poisonMacrosEnabled", feature)
end

SLASH_CARPENTERPOISONMACROS1 = "/cppoisons"
SlashCmdList["CARPENTERPOISONMACROS"] = function()
    MarkDirty(0.25, true)
end
