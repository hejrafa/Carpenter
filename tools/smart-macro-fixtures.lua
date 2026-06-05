#!/usr/bin/env lua
-- Offline fixture checks for Smart Macro bag scanning.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local ns = { Private = {} }
local registeredFeatures = {}
local createdFrames = {}
local tooltipByItemID = {}

SlashCmdList = {}

Carpenter = {
    Client = { isRetail = false },
    IsEnabled = function(_, key) return key == "smartMacrosEnabled" end,
    RegisterFeature = function(_, key, feature) registeredFeatures[key] = feature end,
    Defer = function() end,
    Profile = function(_, _, callback, ...)
        return callback(...)
    end,
}

local bagSlots = {
    [0] = {
        [1] = {
            itemID = 117,
            count = 3,
            link = "|Hitem:117::::::::|h[Tough Jerky]|h",
            texture = "Interface\\Icons\\INV_Misc_Food_16",
        },
    },
}

local itemInfoByID = {
    [117] = { name = "Tough Jerky", itemLevel = 5, reqLevel = 1, itemType = "Consumable", itemSubType = "Food & Drink", classID = 0, subClassID = 5 },
    [159] = { name = "Refreshing Spring Water", itemLevel = 5, reqLevel = 1, itemType = "Consumable", itemSubType = "Food & Drink", classID = 0, subClassID = 5 },
    [8952] = { name = "Roasted Quail", itemLevel = 45, reqLevel = 35, itemType = "Consumable", itemSubType = "Food & Drink", classID = 0, subClassID = 5 },
    [19013] = { name = "Major Healthstone", itemLevel = 60, reqLevel = 0, itemType = "Consumable", itemSubType = "Other", classID = 0, subClassID = 0 },
    [22829] = { name = "Super Healing Potion", itemLevel = 65, reqLevel = 55, itemType = "Consumable", itemSubType = "Potion", classID = 0, subClassID = 1 },
    [27667] = { name = "Spicy Crawdad", itemLevel = 65, reqLevel = 55, itemType = "Consumable", itemSubType = "Food & Drink", classID = 0, subClassID = 5 },
    [30703] = { name = "Conjured Mountain Spring Water", itemLevel = 65, reqLevel = 55, itemType = "Consumable", itemSubType = "Food & Drink", classID = 0, subClassID = 5 },
}

local function GetMaxSlot(bag)
    local maxSlot = 0
    for slot in pairs(bagSlots[bag] or {}) do
        if slot > maxSlot then maxSlot = slot end
    end
    return maxSlot
end

function GetContainerNumSlots(bag)
    return GetMaxSlot(bag)
end

GetContainerItemID = nil

function GetContainerItemLink(bag, slot)
    local item = bagSlots[bag] and bagSlots[bag][slot]
    return item and item.link or nil
end

function GetContainerItemInfo(bag, slot)
    local item = bagSlots[bag] and bagSlots[bag][slot]
    if not item then return nil end
    return item.texture, item.count, false, nil, nil, nil, item.link, nil, nil, item.itemID
end

function GetItemInfo(item)
    local itemID = type(item) == "number" and item or tonumber(tostring(item or ""):match("item:(%d+)"))
    local info = itemID and itemInfoByID[itemID]
    if not info then return nil end
    local link = "|Hitem:" .. itemID .. "::::::::|h[" .. info.name .. "]|h"
    return info.name, link, 1, info.itemLevel, info.reqLevel, info.itemType, info.itemSubType, nil, nil, nil, nil, info.classID, info.subClassID
end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(script, handler) self[script] = handler end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

function GetTime() return 1000 end
function InCombatLockdown() return false end
function UnitLevel() return 70 end
function UnitHealthMax() return 1000 end
function UnitPowerMax() return 1000 end

C_Timer = { After = function(_, callback) callback() end }

ns.Private.SmartMacroTooltip = {
    ContainsAny = function(text, hints)
        if not text or not hints then return false end
        for _, hint in ipairs(hints) do
            if text:find(hint, 1, true) then return true end
        end
        return false
    end,
    Read = function(_, _, item)
        return tooltipByItemID[item.itemID] or { text = "", useText = "", isFoodAndDrink = false }
    end,
    GetSpellText = function() return "" end,
}

ns.Private.SmartMacroBuilder = {
    BuildMacroBody = function() return "#showtooltip\n" end,
    BuildHealthMacroBody = function() return "#showtooltip\n" end,
    UpdateMacro = function() end,
    DeleteMacroByName = function() end,
}

local function loadAddonFile(path)
    local chunk, err = loadfile(repo .. "/" .. path)
    if not chunk then error(err) end
    return chunk("Carpenter", ns)
end

loadAddonFile("Modules/SmartMacroData.lua")
loadAddonFile("Modules/SmartMacroClassifier.lua")
loadAddonFile("Modules/SmartMacroScanner.lua")
loadAddonFile("Modules/SmartMacros.lua")

local failures = {}
local fixtureCount = 0
local scanner = ns.Private.SmartMacroScanner
local classifier = ns.Private.SmartMacroClassifier
local firstFingerprint = scanner.GetBagFingerprint()

bagSlots[0][1] = {
    itemID = 159,
    count = 1,
    link = "|Hitem:159::::::::|h[Refreshing Spring Water]|h",
    texture = "Interface\\Icons\\INV_Drink_07",
}

local secondFingerprint = scanner.GetBagFingerprint()

if not firstFingerprint:find("117:3", 1, true) then
    failures[#failures + 1] = "fingerprint fallback: expected first fingerprint to include item 117 count 3, got " .. firstFingerprint
end
if not secondFingerprint:find("159:1", 1, true) then
    failures[#failures + 1] = "fingerprint fallback: expected second fingerprint to include item 159 count 1, got " .. secondFingerprint
end
if firstFingerprint == secondFingerprint then
    failures[#failures + 1] = "fingerprint fallback: expected bag content change to alter fingerprint"
end
fixtureCount = fixtureCount + 2

local rawFood = { name = "Raw Brilliant Smallfish", itemID = 9001 }
local cookedFood = { name = "Brilliant Smallfish", itemID = 1001 }
local crawdadFood = { name = "Spicy Crawdad", itemID = 9002 }
local plainFood = { name = "Plain Food", itemID = 1002 }

if classifier.IsBetterItem(rawFood, 100, cookedFood, 100, "Food") then
    failures[#failures + 1] = "raw food tie-break: expected cooked food to beat raw food with matching score"
end
if not classifier.IsBetterItem(rawFood, 101, cookedFood, 100, "Food") then
    failures[#failures + 1] = "raw food tie-break: expected higher-scoring raw food to remain eligible"
end
if not classifier.IsBetterItem(crawdadFood, 100, plainFood, 100, "Food") then
    failures[#failures + 1] = "raw food tie-break: expected crawdad to avoid matching the standalone raw word"
end
fixtureCount = fixtureCount + 3

local foodItem = {
    name = "Roasted Quail",
    itemID = 8952,
    itemLevel = 45,
    reqLevel = 35,
    itemType = "Consumable",
    itemSubType = "Food & Drink",
    classID = ns.Private.SmartMacroData.ConsumableClassID,
    subClassID = ns.Private.SmartMacroData.FoodDrinkSubclassID,
}
local normalFoodTooltip = {
    text = "use: restores 874 health over 27 sec. must remain seated while eating.",
    useText = "use: restores 874 health over 27 sec.",
    isFoodAndDrink = true,
}
local weakBuffTooltip = {
    text = "use: restores 874 health over 27 sec. must remain seated while eating. if you spend at least 10 seconds eating you will become well fed and gain 8 stamina and spirit for 15 min.",
    useText = "use: restores 874 health over 27 sec.",
    isFoodAndDrink = true,
}
local strongBuffTooltip = {
    text = "use: restores 874 health over 27 sec. must remain seated while eating. if you spend at least 10 seconds eating you will become well fed and gain 20 stamina and spirit for 15 min.",
    useText = "use: restores 874 health over 27 sec.",
    isFoodAndDrink = true,
}

if classifier.MatchesCategory(foodItem, normalFoodTooltip, "", "WellFed") then
    failures[#failures + 1] = "well fed category: expected plain recovery food to be excluded"
end
if not classifier.MatchesCategory(foodItem, weakBuffTooltip, "", "Food") then
    failures[#failures + 1] = "food category: expected buff food to remain available as recovery fallback"
end
if not classifier.MatchesCategory(foodItem, weakBuffTooltip, "", "WellFed") then
    failures[#failures + 1] = "well fed category: expected buff food to match"
end
if classifier.ScoreItem(foodItem, weakBuffTooltip, "", "Food") >= classifier.ScoreItem(foodItem, normalFoodTooltip, "", "Food") then
    failures[#failures + 1] = "food scoring: expected normal recovery food to beat buff food when both are available"
end
if classifier.ScoreItem(foodItem, strongBuffTooltip, "", "WellFed") <= classifier.ScoreItem(foodItem, weakBuffTooltip, "", "WellFed") then
    failures[#failures + 1] = "well fed scoring: expected stronger buff food to beat weaker buff food"
end
fixtureCount = fixtureCount + 5

local potionItem = {
    name = "Slow Health Regeneration Potion",
    itemID = 990001,
    itemLevel = 40,
    reqLevel = 30,
    itemType = "Consumable",
    itemSubType = "Potion",
    classID = ns.Private.SmartMacroData.ConsumableClassID,
    subClassID = ns.Private.SmartMacroData.PotionSubclassID,
}
local regenerationTooltip = {
    text = "use: regenerates 400 health over 20 sec.",
    useText = "use: regenerates 400 health over 20 sec.",
}

if classifier.MatchesCategory(potionItem, regenerationTooltip, "", "Pot") then
    failures[#failures + 1] = "health potion category: expected regeneration potions to be excluded from immediate health macro"
end
fixtureCount = fixtureCount + 1

local healthstoneItem = {
    name = "Major Healthstone",
    itemID = 19013,
    itemLevel = 60,
    reqLevel = 0,
    itemType = "Consumable",
    itemSubType = "Other",
    classID = ns.Private.SmartMacroData.ConsumableClassID,
    subClassID = 0,
}
local healthstoneTooltip = {
    text = "use: instantly restores 2080 health. healthstone.",
    useText = "use: instantly restores 2080 health.",
}

if not classifier.MatchesCategory(healthstoneItem, healthstoneTooltip, "", "Healthstone") then
    failures[#failures + 1] = "healthstone category: expected known healthstones to match the internal healthstone category"
end
if classifier.MatchesCategory(healthstoneItem, healthstoneTooltip, "", "Pot") then
    failures[#failures + 1] = "healthstone category: expected healthstones to stay out of the potion category"
end
fixtureCount = fixtureCount + 2

tooltipByItemID = {
    [8952] = {
        text = "use: restores 2148 health over 30 sec. must remain seated while eating.",
        useText = "use: restores 2148 health over 30 sec.",
        isFoodAndDrink = true,
    },
    [19013] = healthstoneTooltip,
    [22829] = {
        text = "use: restores 1500 to 2500 health.",
        useText = "use: restores 1500 to 2500 health.",
    },
    [27667] = {
        text = "use: restores 7500 health over 30 sec. must remain seated while eating. if you spend at least 10 seconds eating you will become well fed and gain 30 stamina and 20 spirit for 30 min.",
        useText = "use: restores 7500 health over 30 sec.",
        isFoodAndDrink = true,
    },
    [30703] = {
        text = "conjured item. use: restores 7200 mana over 30 sec. must remain seated while drinking.",
        useText = "use: restores 7200 mana over 30 sec.",
        isFoodAndDrink = true,
        isConjured = true,
    },
}

bagSlots[0] = {
    [1] = { itemID = 8952, count = 2, link = "|Hitem:8952::::::::|h[Roasted Quail]|h", texture = "Interface\\Icons\\INV_Misc_Food_15" },
    [2] = { itemID = 27667, count = 1, link = "|Hitem:27667::::::::|h[Spicy Crawdad]|h", texture = "Interface\\Icons\\INV_Misc_Food_66" },
    [3] = { itemID = 30703, count = 4, link = "|Hitem:30703::::::::|h[Conjured Mountain Spring Water]|h", texture = "Interface\\Icons\\INV_Drink_18" },
    [4] = { itemID = 19013, count = 1, link = "|Hitem:19013::::::::|h[Major Healthstone]|h", texture = "Interface\\Icons\\INV_Stone_04" },
    [5] = { itemID = 22829, count = 3, link = "|Hitem:22829::::::::|h[Super Healing Potion]|h", texture = "Interface\\Icons\\INV_Potion_54" },
}

local bestItems, needsItemInfoRetry = scanner.GetBestItems()
if not bestItems.Food or bestItems.Food.itemID ~= 8952 then
    failures[#failures + 1] = "scanner best items: expected normal food to beat Well Fed food for Food"
end
if not bestItems.WellFed or bestItems.WellFed.itemID ~= 27667 then
    failures[#failures + 1] = "scanner best items: expected Well Fed macro to pick buff food"
end
if not bestItems.Water or bestItems.Water.itemID ~= 30703 then
    failures[#failures + 1] = "scanner best items: expected water macro to pick conjured water"
end
if not bestItems.Healthstone or bestItems.Healthstone.itemID ~= 19013 then
    failures[#failures + 1] = "scanner best items: expected internal healthstone category to track healthstones"
end
if not bestItems.Pot or bestItems.Pot.itemID ~= 22829 then
    failures[#failures + 1] = "scanner best items: expected potion category to pick healing potion"
end
if needsItemInfoRetry then
    failures[#failures + 1] = "scanner best items: did not expect item info retry with complete fixture data"
end
fixtureCount = fixtureCount + 6

local feature = registeredFeatures.smartMacrosEnabled
if not feature or type(feature.Enable) ~= "function" then
    failures[#failures + 1] = "smart macro feature was not registered"
else
    feature:Enable()
    local addonFrame = createdFrames[1]
    if not addonFrame or not addonFrame.events.BAG_UPDATE then
        failures[#failures + 1] = "smart macro feature did not register BAG_UPDATE"
    end
end
fixtureCount = fixtureCount + 1

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("smart-macro fixtures: " .. fixtureCount .. " passed")
