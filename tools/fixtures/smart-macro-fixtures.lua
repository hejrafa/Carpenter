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
    Client = { isMainline = false },
    IsEnabled = function(_, key) return key == "smartMacrosEnabled" end,
    RegisterFeature = function(_, key, feature) registeredFeatures[key] = feature end,
    Defer = function() end,
    Profile = function(_, _, callback, ...)
        return callback(...)
    end,
}
Carpenter = dofile(repo .. "/tools/fixtures/fixture-carpenter.lua")(Carpenter)

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

loadAddonFile("Modules/SmartMacros/SmartMacroData.lua")
loadAddonFile("Modules/SmartMacros/SmartMacroStatWeights.lua")
loadAddonFile("Modules/SmartMacros/SmartMacroClassifier.lua")
loadAddonFile("Modules/SmartMacros/SmartMacroScanner.lua")
loadAddonFile("Modules/SmartMacros/SmartMacros.lua")
loadAddonFile("Settings/ConfigSidebar.lua")

local failures = {}
local fixtureCount = 0
local scanner = ns.Private.SmartMacroScanner
local classifier = ns.Private.SmartMacroClassifier
local macroData = ns.Private.SmartMacroData
local configSidebar = ns.Private.ConfigSidebar

Carpenter.Client = { isMainline = true, isForever = true }
if not macroData.IsMainlineClient() then
    failures[#failures + 1] = "Forever API flavor: expected Retail tooltip behavior"
end
if not macroData.UsesClassicMacros() then
    failures[#failures + 1] = "Forever macro flavor: expected Classic macro behavior"
end
if not macroData.GetActiveItems().Band then
    failures[#failures + 1] = "Forever macro flavor: expected the Classic bandage macro"
end
local foreverPreviewOrder = configSidebar.GetSmartMacroPreviewOrder()
if foreverPreviewOrder[6] ~= "Band" then
    failures[#failures + 1] = "Forever settings pane: expected the Bandage macro preview"
end
Carpenter.Client = { isMainline = true, isForever = false, isClassic = false }
local retailPreviewOrder = configSidebar.GetSmartMacroPreviewOrder()
if #retailPreviewOrder ~= 5 then
    failures[#failures + 1] = "Retail settings pane: did not expect the Classic bandage macro preview"
end
Carpenter.Client = { isMainline = false, isForever = false }
fixtureCount = fixtureCount + 5

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

-- Empty macros point at an item grayed out with a 0 count, not a question mark.
do
    CarpenterDB = {}
    local playerGUID = "Player-1-00000001"
    UnitGUID = function(unit) return unit == "player" and playerGUID or nil end
    local builder = ns.Private.SmartMacroBuilder
    local macros = {}
    builder.BuildMacroBody = function(item) return item and item.name or "none" end
    builder.BuildHealthMacroBody = function(potion, healthstone)
        return (healthstone and healthstone.name or "-") .. "|" .. (potion and potion.name or "-")
    end
    builder.UpdateMacro = function(name, body, createIfMissing)
        if createIfMissing then macros[name] = body end
    end

    local deferred
    Carpenter.Defer = function(_, _, _, callback) deferred = callback end
    -- Forever uses the Classic macro set, bandages included.
    Carpenter.Client = { isMainline = true, isForever = true }
    -- Enabling above scheduled through the no-op Defer; start clean.
    registeredFeatures.smartMacrosEnabled:Disable()
    registeredFeatures.smartMacrosEnabled:Enable()
    local now = 1000
    GetTime = function() return now end
    local function RunUpdate()
        now = now + 10
        if not deferred then ns.UpdateSmartMacros() end
        assert(deferred, "smart macro update was not scheduled")
        local callback = deferred
        deferred = nil
        callback()
    end

    RunUpdate()
    if macros.CarpenterFood ~= "Roasted Quail" or macros.CarpenterHP ~= "Major Healthstone|Super Healing Potion" then
        failures[#failures + 1] = "fallback: macros should use the items in the bags"
    end

    local savedBag = bagSlots[0]
    bagSlots[0] = {}
    RunUpdate()
    if macros.CarpenterFood ~= "item:8952" then
        failures[#failures + 1] = "fallback: an emptied macro should keep its last item, got " .. tostring(macros.CarpenterFood)
    end
    if macros.CarpenterHP ~= "-|item:19013" then
        failures[#failures + 1] = "fallback: the health macro should keep the healthstone it showed, got " .. tostring(macros.CarpenterHP)
    end
    if macros.CarpenterMana ~= "item:2455" or macros.CarpenterBand ~= "item:1251" then
        failures[#failures + 1] = "fallback: macros that never had an item should use the slot's default item, got " .. tostring(macros.CarpenterMana) .. " / " .. tostring(macros.CarpenterBand)
    end

    -- After a reload, the last items come back from saved variables.
    loadAddonFile("Modules/SmartMacros/SmartMacros.lua")
    registeredFeatures.smartMacrosEnabled:Enable()
    macros = {}
    RunUpdate()
    if macros.CarpenterFood ~= "item:8952" or macros.CarpenterHP ~= "-|item:19013" then
        failures[#failures + 1] = "fallback: the last items should survive a reload, got " .. tostring(macros.CarpenterFood) .. " / " .. tostring(macros.CarpenterHP)
    end

    -- Another character keeps its own last items.
    playerGUID = "Player-1-00000002"
    macros = {}
    RunUpdate()
    if macros.CarpenterFood == "item:8952" then
        failures[#failures + 1] = "fallback: another character must not reuse this character's last food"
    end
    playerGUID = "Player-1-00000001"
    bagSlots[0] = savedBag
    fixtureCount = fixtureCount + 6
end

-- =========================
-- Durations, the client's way: German and Spanish write "|4one:many;" plurals.
-- =========================
do
    local strings = {
        deDE = {
            SECONDS_ABBR = "%d |4Sek.:Sek.;", INT_SPELL_DURATION_SEC = "%d Sek.",
            MINUTES_ABBR = "%d |4Min.:Min.;", INT_SPELL_DURATION_MIN = "%d Min.",
            HOURS_ABBR = "%d |4Std.:Std.;", INT_SPELL_DURATION_HOURS = "%d |4Stunde:Stunden;",
        },
        esES = {
            SECONDS_ABBR = "%d |4s:s;", INT_SPELL_DURATION_SEC = "%d s",
            MINUTES_ABBR = "%d |4min:min;", INT_SPELL_DURATION_MIN = "%d min",
            HOURS_ABBR = "%d |4h:h;", INT_SPELL_DURATION_HOURS = "%d |4h:h;",
        },
    }
    local samples = {
        deDE = { "benutzen: stellt 455 bis 585 gesundheit wieder her.", "benutzen: stellt im verlauf von 15 sek. 1000 gesundheit wieder her.", "erhaltet 15 beweglichkeit für 15 min." },
        esES = { "uso: restaura entre 455 y 585 p. de salud.", "uso: restaura 1000 p. de salud durante 15 s.", "obtienes 15 de agilidad durante 15 min." },
    }
    for locale, globals in pairs(strings) do
        for name, value in pairs(globals) do _G[name] = value end
        local localeNS = { Private = {} }
        local chunk = assert(loadfile(repo .. "/Modules/SmartMacros/SmartMacroData.lua"))
        chunk("Carpenter", localeNS)
        local localeData = localeNS.Private.SmartMacroData
        local texts = samples[locale]
        local checks = {
            { localeData.HasDuration(texts[1], localeData.SecondsDurationPatterns), false, "a plain potion isn't healing over time" },
            { localeData.HasDuration(texts[2], localeData.SecondsDurationPatterns), true, "a potion over seconds is healing over time" },
            { localeData.HasDuration(texts[3], localeData.LongDurationPatterns), true, "a buff in minutes has a duration" },
            { localeData.HasDuration(texts[1], localeData.LongDurationPatterns), false, "a plain potion has no buff duration" },
        }
        for _, check in ipairs(checks) do
            fixtureCount = fixtureCount + 1
            if check[1] ~= check[2] then
                failures[#failures + 1] = string.format("durations %s: %s", locale, check[3])
            end
        end
        for name in pairs(globals) do _G[name] = nil end
    end
end

-- =========================
-- Well Fed picks the stats the character uses.
-- =========================
do
    local statWeights = ns.Private.SmartMacroStatWeights
    local function BuffTooltip(buff)
        return {
            text = "use: restores 874 health over 27 sec. must remain seated while eating. if you spend at least 10 seconds eating you will become well fed and " .. buff .. " for 15 min.",
            useText = "use: restores 874 health over 27 sec.",
            isFoodAndDrink = true,
        }
    end
    local function Expect(label, actual, expected)
        fixtureCount = fixtureCount + 1
        if actual ~= expected then
            failures[#failures + 1] = string.format("well fed stats: %s: expected %s, got %s", label, tostring(expected), tostring(actual))
        end
    end
    local function Parse(buff)
        return classifier.ParseBuffStats(BuffTooltip(buff), "")
    end

    local stats = Parse("gain 15 agility")
    Expect("one stat", stats.agility, 15)
    Expect("fishing", Parse("gain 18 fishing skill").fishing, 18)
    stats = Parse("gain 2 stamina and spirit")
    Expect("one value for two stats, first", stats.stamina, 2)
    Expect("one value for two stats, second", stats.spirit, 2)
    stats = Parse("gain 20 attack power, 23 spell damage, 44 healing power, and 10 stamina")
    Expect("a list, attack power", stats.attackPower, 20)
    Expect("a list, spell damage", stats.spellDamage, 23)
    Expect("a list, healing power", stats.healing, 44)
    Expect("a list, stamina", stats.stamina, 10)
    stats = Parse("increase healing done by 44 and spirit by 20")
    Expect("values after their stats, healing", stats.healing, 44)
    Expect("values after their stats, spirit", stats.spirit, 20)
    stats = Parse("gain 1% critical strike chance")
    Expect("a percent of critical strike", stats.critPercent, 1)
    Expect("mana every 5 seconds", Parse("gain 8 mana every 5 seconds").mp5, 8)
    stats = classifier.ParseBuffStats({
        text = "use: restores 552 health over 21 sec. must remain seated while eating. if you eat for 10 seconds will also increase your agility by 10 for 10 min.",
        useText = "use: restores 552 health over 21 sec.",
        isFoodAndDrink = true,
    }, "")
    Expect("Classic's also-increases wording takes its own number", stats.agility, 10)
    stats = Parse("gain 15 agility for 10 min. additionally, experience gained from kills is increased by 5%")
    Expect("the experience rider is no stat", stats.critPercent, nil)
    Expect("a white fish has no hit rating", Parse("gain 15 stamina. a white fish").hitRating, nil)
    stats = classifier.ParseBuffStats({
        text = "benutzen: stellt 874 gesundheit wieder her. ihr werdet satt und erhaltet 15 beweglichkeit und 10 ausdauer für 15 min.",
        useText = "benutzen: stellt 874 gesundheit wieder her.",
        isFoodAndDrink = true,
    }, "")
    Expect("German, agility", stats.agility, 15)
    Expect("German, stamina", stats.stamina, 10)

    -- Classic's "also increases" food counts as Well Fed food.
    local alsoIncreasesFood = {
        text = "use: restores 552 health over 21 sec. must remain seated while eating. if you eat for 10 seconds will also increase your agility by 10 for 10 min.",
        useText = "use: restores 552 health over 21 sec.",
        isFoodAndDrink = true,
    }
    fixtureCount = fixtureCount + 1
    if not classifier.MatchesCategory(foodItem, alsoIncreasesFood, "", "WellFed") then
        failures[#failures + 1] = "well fed category: Classic's \"also increase your Agility\" food should count"
    end

    -- Which food each character reaches for.
    local foods = {
        agility = BuffTooltip("gain 15 agility"),
        attackPower = BuffTooltip("gain 30 attack power"),
        fishing = BuffTooltip("gain 18 fishing skill"),
        staminaSpirit = BuffTooltip("gain 12 stamina and spirit"),
        stamina = BuffTooltip("gain 15 stamina"),
        strength = BuffTooltip("gain 15 strength"),
        intellect = BuffTooltip("gain 15 intellect"),
        spellDamage = BuffTooltip("gain 21 spell damage"),
        healing = BuffTooltip("gain 33 healing power"),
    }
    local function Best(names)
        local weights = statWeights.GetWeights()
        local best, bestScore
        for _, name in ipairs(names) do
            local score = classifier.ScoreItem(foodItem, foods[name], "", "WellFed", weights)
            if not bestScore or score > bestScore then best, bestScore = name, score end
        end
        return best
    end
    local all = { "fishing", "staminaSpirit", "stamina", "strength", "intellect", "spellDamage", "healing", "agility", "attackPower" }

    local classToken, assignedRole, tabPoints = "ROGUE", "NONE", {}
    UnitClass = function() return classToken, classToken end
    UnitGroupRolesAssigned = function() return assignedRole end
    GetTalentTabInfo = function(tab) return "Tree " .. tab, "icon", tabPoints[tab] or 0 end
    Carpenter.Client = { isClassic = true, isVanilla = true }

    Expect("a rogue", Best(all), "agility")
    Expect("a rogue without agility food", Best({ "fishing", "staminaSpirit", "attackPower" }), "attackPower")
    Expect("a rogue's fishing food comes last", Best({ "fishing", "intellect", "staminaSpirit" }), "staminaSpirit")
    classToken = "MAGE"
    Expect("a mage", Best(all), "spellDamage")
    classToken = "WARRIOR"
    Expect("a warrior without talents", Best(all), "strength")
    tabPoints = { 5, 0, 21 }
    Expect("a protection warrior", Best(all), "stamina")
    classToken, tabPoints = "PRIEST", { 0, 0, 31 }
    Expect("a shadow priest", Best(all), "spellDamage")
    tabPoints = { 0, 31, 0 }
    Expect("a holy priest", Best(all), "healing")
    classToken, tabPoints, assignedRole = "ROGUE", {}, "TANK"
    Expect("anyone in a group's tank role", Best(all), "stamina")
    assignedRole = "NONE"

    -- WoW Forever: the points in each group of the class's talent tree.
    Carpenter.Client = { isMainline = true, isForever = true }
    classToken = "PALADIN"
    local groupSpent = { [11] = 0, [12] = 0, [13] = 0 }
    C_ClassTalents = { GetActiveConfigID = function() return 7 end }
    C_Traits = {
        GetConfigInfo = function() return { treeIDs = { 100 } } end,
        GetGroupDisplayInfoByTreeID = function()
            return {
                { groupID = 11, orderIndex = 0 }, { groupID = 12, orderIndex = 1 }, { groupID = 13, orderIndex = 2 },
            }
        end,
        GetGroupCurrencyInfo = function(_, groupIDs)
            local infos = {}
            for _, groupID in ipairs(groupIDs) do
                infos[#infos + 1] = { traitNodeGroupID = groupID, currencyInfos = { { spent = groupSpent[groupID] } } }
            end
            return infos
        end,
    }
    groupSpent[11] = 20
    Expect("a holy paladin on WoW Forever", Best(all), "healing")
    groupSpent[11], groupSpent[12] = 0, 20
    Expect("a protection paladin on WoW Forever", Best(all), "stamina")
    groupSpent[12], groupSpent[13] = 0, 20
    Expect("a retribution paladin on WoW Forever", Best(all), "strength")

    -- Retail: the spec's role and main stat.
    Carpenter.Client = { isMainline = true, isRetail = true }
    classToken = "DRUID"
    GetSpecialization = function() return 1 end
    GetSpecializationInfo = function() return 102, "Balance", "", 0, "DAMAGER", 4 end
    Expect("a balance druid on Retail", Best(all), "spellDamage")
    GetSpecializationInfo = function() return 103, "Feral", "", 0, "DAMAGER", 2 end
    Expect("a feral druid on Retail", Best(all), "agility")

    UnitClass, UnitGroupRolesAssigned, GetTalentTabInfo = nil, nil, nil
    C_ClassTalents, C_Traits, GetSpecialization, GetSpecializationInfo = nil, nil, nil, nil
    Carpenter.Client = { isMainline = false, isForever = false }

    -- A talent or role change rescans the bags.
    local roleEventsRegistered = false
    for _, frame in ipairs(createdFrames) do
        if frame.events.PLAYER_TALENT_UPDATE and frame.events.TRAIT_CONFIG_UPDATED and frame.events.PLAYER_ROLES_ASSIGNED then
            roleEventsRegistered = true
        end
    end
    Expect("talent and role changes rescan", roleEventsRegistered, true)
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("smart-macro fixtures: " .. fixtureCount .. " passed")
