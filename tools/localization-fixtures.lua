#!/usr/bin/env lua
-- Verifies spell, tooltip, and enchant matching works on non-English clients.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local failures = {}
local function check(condition, message)
    if not condition then failures[#failures + 1] = message end
end

local function load(path, ns)
    local chunk = assert(loadfile(repo .. "/" .. path))
    chunk("Carpenter", ns or { Private = {} })
end

-- 1. Debuff names come from spell IDs in the client's language.
do
    local germanSpells = { [118] = "Verwandlung", [1943] = "Blutung", [999999] = nil }
    GetSpellInfo = function(spellId) return germanSpells[spellId] end
    C_Spell = nil
    CarpenterSpellData = nil
    load("SpellData.lua")

    local names = CarpenterSpellData.BuildLocalizedNameMap({ [118] = true, [1943] = "Bleed", [999999] = true })
    check(names["Verwandlung"] == true, "spell names: expected the German Polymorph name")
    check(names["Blutung"] == "Bleed", "spell names: expected values to carry over")
    local count = 0
    for _ in pairs(names) do count = count + 1 end
    check(count == 2, "spell names: spells missing from the client should be skipped")

    local tracker = io.open(repo .. "/Modules/DebuffTracker/DebuffTracker.lua"):read("*a")
    check(not tracker:find('%[%"%u%l[%a ]*%"%]%s*=%s*'), "debuff tracker: debuffs must be listed by spell ID, not English name")
end

-- 2. Poison Warning reads the enchant name in any language.
do
    local timers = {}
    CreateFrame = function()
        return { SetOwner = function() end, RegisterEvent = function() end, SetScript = function() end }
    end
    C_Timer = { NewTicker = function(_, callback) timers[#timers + 1] = callback end }
    UIParent, WorldFrame = {}, {}

    local cases = {
        { strings = { MIN = "%s (%d min)", SEC = "%s (%d sec)", HOURS = "%s (%d |4hour:hrs;)" },
          line = "Instant Poison VI (29 min)", name = "Instant Poison VI" },
        { strings = { MIN = "%s (%d Min.)", SEC = "%s (%d Sek.)", HOURS = "%s (%d |4Std.:Std.;)" },
          line = "Sofort wirkendes Gift VI (29 Min.)", name = "Sofort wirkendes Gift VI" },
        { strings = { MIN = "%1$s (%2$d мин.)", SEC = "%1$s (%2$d сек.)" },
          line = "Быстродействующий яд VI (45 сек.)", name = "Быстродействующий яд VI" },
        { strings = {}, line = "Deadly Poison (12 min)", name = "Deadly Poison" },
    }

    for _, case in ipairs(cases) do
        ITEM_ENCHANT_TIME_LEFT_MIN = case.strings.MIN
        ITEM_ENCHANT_TIME_LEFT_SEC = case.strings.SEC
        ITEM_ENCHANT_TIME_LEFT_HOURS = case.strings.HOURS
        ITEM_ENCHANT_TIME_LEFT_DAYS = nil
        local ns = { Private = {} }
        load("Modules/EnchantWarning.lua", ns)
        local name = ns.Private.EnchantWarning.GetEnchantNameFromLine(case.line)
        check(name == case.name, "poison warning: expected [" .. case.name .. "] got [" .. tostring(name) .. "]")
    end
end

-- 3. Consumable Macros pick up the client's own words.
do
    local locales = {
        ruRU = {
            strings = { HEALTH = "Здоровье", MANA = "Мана", ITEM_SPELL_TRIGGER_ONUSE = "Использование:" },
            spells = { [433] = "Еда", [430] = "Питье" },
            useLine = "Использование: Восполняет 61 ед. здоровья за 18 сек.",
            manaLine = "Восполняет 455 ед. маны.",
        },
        frFR = {
            strings = { HEALTH = "Points de vie", MANA = "Mana", ITEM_SPELL_TRIGGER_ONUSE = "Utiliser :" },
            spells = { [433] = "Nourriture", [430] = "Boisson" },
            useLine = "Utiliser : Rend 61 points de vie en 18 sec.",
            manaLine = "Rend 455 points de mana.",
        },
    }

    for locale, data in pairs(locales) do
        HEALTH, MANA, ITEM_SPELL_TRIGGER_ONUSE = data.strings.HEALTH, data.strings.MANA, data.strings.ITEM_SPELL_TRIGGER_ONUSE
        GetSpellInfo = function(spellId) return data.spells[spellId] end
        GetLocale = function() return locale end
        local ns = { Private = {} }
        load("Modules/SmartMacros/SmartMacroData.lua", ns)
        local smartData = ns.Private.SmartMacroData
        local keywords = smartData.TooltipKeywords

        local function has(text, list)
            text = text:lower()
            for _, keyword in ipairs(list) do
                if text:find(keyword, 1, true) then return true end
            end
            return false
        end

        check(has(data.useLine, keywords.use), locale .. ": expected the Use: line to be found")
        check(has(data.useLine, keywords.health), locale .. ": expected health to be found in the use line")
        check(has(data.manaLine, keywords.mana), locale .. ": expected mana to be found")
        check(has(data.spells[433], keywords.food), locale .. ": expected the Food spell name")
        check(has(data.spells[430], keywords.drink), locale .. ": expected the Drink spell name")
        check(smartData.IsEnglishClient() == false, locale .. ": should not count as an English client")
    end
end

-- 4. Duration-based checks for regeneration potions and buff food.
do
    local french = {
        HEALTH = "Points de vie", MANA = "Mana", ITEM_SPELL_TRIGGER_ONUSE = "Utiliser :",
        SPELL_STAT3_NAME = "Endurance",
        INT_SPELL_DURATION_SEC = "%d s", INT_SPELL_DURATION_MIN = "%d min",
        INT_SPELL_DURATION_HOURS = "%d |4heure:heures;",
    }
    for key, value in pairs(french) do _G[key] = value end
    GetSpellInfo = function() return nil end
    GetLocale = function() return "frFR" end
    UnitHealthMax = function() return 1000 end
    UnitPowerMax = function() return 1000 end

    local ns = { Private = {} }
    load("Modules/SmartMacros/SmartMacroData.lua", ns)
    load("Modules/SmartMacros/SmartMacroClassifier.lua", ns)
    local classifier = ns.Private.SmartMacroClassifier

    local potion = { itemID = 900001, name = "Potion de soins", itemType = "Consommable", itemSubType = "Potion",
        classID = 0, subClassID = 1, itemLevel = 20, reqLevel = 10 }

    local function Tooltip(useLine, extra)
        local useText = useLine:lower()
        return { text = useText .. (extra and (" " .. extra:lower()) or ""), useText = useText }
    end

    local regeneration = Tooltip("Utiliser : Rend 600 points de vie en 21 s.")
    check(not classifier.MatchesCategory(potion, regeneration, "", "Pot"),
        "frFR: a potion that heals over seconds should stay out of the health macro")

    local instant = Tooltip("Utiliser : Rend 455 à 585 points de vie.", "Temps de recharge restant : 45 s")
    check(classifier.MatchesCategory(potion, instant, "", "Pot"),
        "frFR: an instant healing potion on cooldown should still count")

    local food = { itemID = 900002, name = "Ragoût", itemType = "Consommable", itemSubType = "Nourriture et boissons",
        classID = 0, subClassID = 5, itemLevel = 25, reqLevel = 15 }
    local plainFood = Tooltip("Utiliser : Rend 552 points de vie en 21 s. Vous devez rester assis pendant que vous mangez.")
    local statFood = Tooltip("Utiliser : Rend 552 points de vie en 21 s. Vous gagnez 6 en Endurance pendant 15 min.")
    local plainScore = classifier.ScoreItem(food, plainFood, "", "Food")
    local statScore = classifier.ScoreItem(food, statFood, "", "Food")
    check(plainScore > statScore, "frFR: the plain Food macro should prefer food without a stat buff")
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("localization fixtures passed")
