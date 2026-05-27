#!/usr/bin/env lua
-- Offline fixture checks for Smart Macro bag scanning.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local ns = { Private = {} }
local registeredFeatures = {}
local createdFrames = {}

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

function GetContainerNumSlots(bag)
    return bag == 0 and 1 or 0
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
function UnitHealthMax() return 1000 end
function UnitPowerMax() return 1000 end

C_Timer = { After = function(_, callback) callback() end }

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
if classifier.MatchesCategory(foodItem, weakBuffTooltip, "", "Food") then
    failures[#failures + 1] = "food category: expected buff food to stay out of the recovery food macro"
end
if not classifier.MatchesCategory(foodItem, weakBuffTooltip, "", "WellFed") then
    failures[#failures + 1] = "well fed category: expected buff food to match"
end
if classifier.ScoreItem(foodItem, strongBuffTooltip, "", "WellFed") <= classifier.ScoreItem(foodItem, weakBuffTooltip, "", "WellFed") then
    failures[#failures + 1] = "well fed scoring: expected stronger buff food to beat weaker buff food"
end
fixtureCount = fixtureCount + 4

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
