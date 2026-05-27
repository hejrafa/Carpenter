--[[ Carpenter - Smart Macro item classifier ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Classifier = ns.Private.SmartMacroClassifier or {}
ns.Private.SmartMacroClassifier = Classifier

local Data = ns.Private.SmartMacroData or {}
local Tooltip = ns.Private.SmartMacroTooltip or {}

local FOOD_NAME_HINTS = Data.FoodNameHints or {}
local WATER_NAME_HINTS = Data.WaterNameHints or {}
local TOOLTIP_KEYWORDS = Data.TooltipKeywords or {}
local KNOWN_FOOD_IDS = Data.KnownFoodIDs or {}
local KNOWN_WATER_IDS = Data.KnownWaterIDs or {}
local KNOWN_CONJURED_FOOD_IDS = Data.KnownConjuredFoodIDs or {}
local KNOWN_CONJURED_WATER_IDS = Data.KnownConjuredWaterIDs or {}
local KNOWN_HEALTH_IDS = Data.KnownHealthIDs or {}
local KNOWN_MANA_IDS = Data.KnownManaIDs or {}
local KNOWN_HEALTHSTONE_IDS = Data.KnownHealthstoneIDs or {}
local KNOWN_BANDAGE_IDS = Data.KnownBandageIDs or {}

local CONSUMABLE_CLASS_ID = Data.ConsumableClassID or 0
local POTION_SUBCLASS_ID = Data.PotionSubclassID or 1
local FOOD_DRINK_SUBCLASS_ID = Data.FoodDrinkSubclassID or 5
local BANDAGE_SUBCLASS_ID = Data.BandageSubclassID or 7
local TRADESKILL_CLASS_ID = Data.TradeskillClassID or 7
local COOKING_SUBCLASS_ID = Data.CookingSubclassID or 8
local MISCELLANEOUS_CLASS_ID = Data.MiscellaneousClassID or 15
local REAGENT_SUBCLASS_ID = Data.ReagentSubclassID or 1

local function ContainsAny(text, hints)
    if Tooltip.ContainsAny then
        return Tooltip.ContainsAny(text, hints)
    end
    if not text or text == "" or not hints then return false end
    for _, hint in ipairs(hints) do
        if text:find(hint, 1, true) then return true end
    end
    return false
end

local function IsConsumableItem(item)
    if not item then return false end
    if item.classID == CONSUMABLE_CLASS_ID then return true end
    local itemType = item.itemType and item.itemType:lower() or ""
    return itemType:find("consumable", 1, true) ~= nil
end

local function IsKnownConsumableID(itemID)
    return itemID and (
        KNOWN_FOOD_IDS[itemID]
        or KNOWN_WATER_IDS[itemID]
        or KNOWN_HEALTH_IDS[itemID]
        or KNOWN_MANA_IDS[itemID]
        or KNOWN_HEALTHSTONE_IDS[itemID]
        or KNOWN_BANDAGE_IDS[itemID]
    )
end

local function ItemNameContainsHealthstone(item)
    local name = item and item.name and item.name:lower() or ""
    return ContainsAny(name, TOOLTIP_KEYWORDS.healthstone)
end

local function IsPotentialItem(item)
    if IsConsumableItem(item) or IsKnownConsumableID(item.itemID) then return true end
    if ItemNameContainsHealthstone(item) then return true end
    if item.classID == TRADESKILL_CLASS_ID and item.subClassID == COOKING_SUBCLASS_ID then return true end
    if item.classID == MISCELLANEOUS_CLASS_ID and item.subClassID == REAGENT_SUBCLASS_ID then return true end
    return false
end

local function IsFoodDrinkConsumable(item)
    if not IsConsumableItem(item) then return false end
    if item.subClassID == FOOD_DRINK_SUBCLASS_ID then return true end
    local subType = item.itemSubType and item.itemSubType:lower() or ""
    return subType:find("food", 1, true) ~= nil or subType:find("drink", 1, true) ~= nil
end

local function IsFoodDrinkItem(item, tooltipData)
    if IsFoodDrinkConsumable(item) then return true end
    if item.classID == TRADESKILL_CLASS_ID and item.subClassID == COOKING_SUBCLASS_ID then return true end
    if item.classID == MISCELLANEOUS_CLASS_ID and item.subClassID == REAGENT_SUBCLASS_ID then return true end
    return tooltipData and tooltipData.isFoodAndDrink == true
end

local function TooltipRestoresHealth(useText)
    if not useText or useText == "" then return false end
    return ContainsAny(useText, TOOLTIP_KEYWORDS.health)
end

local function TooltipRestoresMana(useText)
    if not useText or useText == "" then return false end
    return ContainsAny(useText, TOOLTIP_KEYWORDS.mana)
end

local function GetRestoreText(tooltipData)
    if not tooltipData then return "" end
    return (tooltipData.useText and tooltipData.useText ~= "" and tooltipData.useText) or tooltipData.text or ""
end

local function NormalizeTooltipNumber(value)
    if not value or value == "" then return 0 end
    value = value:gsub("%s+", "")

    if value:find(",", 1, true) and value:find(".", 1, true) then
        value = value:gsub(",", "")
    elseif value:find(",", 1, true) then
        local afterComma = value:match(",(%d+)$")
        if afterComma and #afterComma == 3 then
            value = value:gsub(",", "")
        else
            value = value:gsub(",", ".")
        end
    elseif value:find(".", 1, true) then
        local afterDot = value:match("%.([%d]+)$")
        if afterDot and #afterDot == 3 then
            value = value:gsub("%.", "")
        end
    end

    return tonumber(value) or 0
end

local function NormalizeRestoreValue(rawValue, percent, text, maxValue)
    local value = NormalizeTooltipNumber(rawValue)
    if (percent == "%" or text:find("%%", 1, true)) and maxValue and maxValue > 0 then
        value = maxValue * value / 100
    elseif text:find("million", 1, true) or text:find("millionen", 1, true) then
        value = value * 1000000
    end
    return value
end

local function ExtractRestoreValue(useText, keywords, maxValue)
    if not useText or useText == "" then return 0 end

    local healthPos = math.huge
    local manaPos = math.huge
    for _, keyword in ipairs(TOOLTIP_KEYWORDS.health) do
        local pos = useText:find(keyword, 1, true)
        if pos and pos < healthPos then healthPos = pos end
    end
    for _, keyword in ipairs(TOOLTIP_KEYWORDS.mana) do
        local pos = useText:find(keyword, 1, true)
        if pos and pos < manaPos then manaPos = pos end
    end

    local firstValue, firstPercent = useText:match("([%d%,%.]+)%s*(%%?)")
    if firstValue then
        if keywords == TOOLTIP_KEYWORDS.health and healthPos < math.huge and (healthPos <= manaPos or manaPos == math.huge) then
            return NormalizeRestoreValue(firstValue, firstPercent, useText, maxValue)
        elseif keywords == TOOLTIP_KEYWORDS.mana and manaPos < math.huge and (manaPos <= healthPos or healthPos == math.huge) then
            return NormalizeRestoreValue(firstValue, firstPercent, useText, maxValue)
        end
    end

    local best = 0
    for _, keyword in ipairs(keywords) do
        local searchStart = 1
        while true do
            local foundStart = useText:find(keyword, searchStart, true)
            if not foundStart then break end

            local beforeKeyword = useText:sub(1, foundStart - 1)
            local rawValue, percent = beforeKeyword:match("([%d%,%.]+)%s*(%%?)%D*$")
            if rawValue then
                local value = NormalizeRestoreValue(rawValue, percent, useText, maxValue)
                if value > best then best = value end
            end

            searchStart = foundStart + #keyword
        end
    end

    if best <= 0 then
        local rawValue, percent = useText:match("([%d%,%.]+)%s*(%%?)")
        if rawValue then
            best = NormalizeRestoreValue(rawValue, percent, useText, maxValue)
        end
    end

    return best
end

local function IsConjuredFoodOrWater(item, tooltipData, category)
    if category == "Food" and item.itemID and KNOWN_CONJURED_FOOD_IDS[item.itemID] then return true end
    if category == "Water" and item.itemID and KNOWN_CONJURED_WATER_IDS[item.itemID] then return true end

    local name = item.name and item.name:lower() or ""
    local tooltip = tooltipData and tooltipData.text or ""
    local spellText = tooltipData and tooltipData.spellText or ""
    return tooltipData and tooltipData.isConjured
        or ContainsAny(name, TOOLTIP_KEYWORDS.conjured)
        or ContainsAny(spellText, TOOLTIP_KEYWORDS.conjured)
        or ContainsAny(tooltip, TOOLTIP_KEYWORDS.conjured)
end

local function IsWellFedFood(tooltipData, spellText)
    local text = ((tooltipData and tooltipData.text) or "") .. " " .. (spellText or "")
    text = text:lower()
    return ContainsAny(text, TOOLTIP_KEYWORDS.wellFed)
end

local function StripWellFedTiming(text)
    if not text or text == "" then return "" end

    text = text:gsub("at least%s+[%d%,%.]+%s*seconds?", "")
    text = text:gsub("at least%s+[%d%,%.]+%s*sec", "")
    text = text:gsub("mindestens%s+[%d%,%.]+%s*sekunden?", "")
    text = text:gsub("[%d%,%.]+%s*seconds?", "")
    text = text:gsub("[%d%,%.]+%s*sec", "")
    text = text:gsub("[%d%,%.]+%s*sekunden?", "")
    text = text:gsub("[%d%,%.]+%s*minutes?", "")
    text = text:gsub("[%d%,%.]+%s*mins?", "")
    text = text:gsub("[%d%,%.]+%s*min", "")
    text = text:gsub("[%d%,%.]+%s*stunden?", "")
    text = text:gsub("[%d%,%.]+%s*hours?", "")
    text = text:gsub("[%d%,%.]+%s*hrs?", "")

    return text
end

local function ExtractWellFedBuffValue(tooltipData, spellText)
    local text = ((tooltipData and tooltipData.text) or "") .. " " .. (spellText or "")
    text = text:lower()

    local best = 0
    for _, keyword in ipairs(TOOLTIP_KEYWORDS.wellFed or {}) do
        local searchStart = 1
        while true do
            local foundStart = text:find(keyword, searchStart, true)
            if not foundStart then break end

            local segment = StripWellFedTiming(text:sub(foundStart, foundStart + 260))
            local total = 0
            for rawValue in segment:gmatch("[%+%-]?%d[%d%,%.]*") do
                local value = NormalizeTooltipNumber(rawValue:gsub("^%+", ""))
                if value > 0 then
                    total = total + value
                end
            end
            if total > best then best = total end

            searchStart = foundStart + #keyword
        end
    end

    return best
end

local function IsPotionItem(item)
    local name = item.name and item.name:lower() or ""
    local subType = item.itemSubType:lower()

    return IsConsumableItem(item) and (item.subClassID == POTION_SUBCLASS_ID or subType:find("potion", 1, true) or name:find("potion", 1, true))
end

local function IsHealthstoneItem(item, tooltip)
    local name = item.name and item.name:lower() or ""
    return (item.itemID and KNOWN_HEALTHSTONE_IDS[item.itemID])
        or ContainsAny(name, TOOLTIP_KEYWORDS.healthstone)
        or ContainsAny(tooltip, TOOLTIP_KEYWORDS.healthstone)
end

local function HasRegeneratingHealthEffect(text)
    if not text or text == "" then return false end
    return text:find("regenerate", 1, true)
        or text:find("regenerates", 1, true)
        or text:find("regeneration", 1, true)
        or text:find("over %d+ sec")
        or text:find("every %d+ sec")
end

local function HasImmediateHealthRestore(text)
    if not text or text == "" or HasRegeneratingHealthEffect(text) then return false end
    return text:find("restores %d+ health")
        or text:find("restores %d+ to %d+ health")
        or text:find("restore health", 1, true)
        or text:find("heals %d+")
end

local function IsBandageItem(item, tooltip)
    local name = item.name and item.name:lower() or ""
    local subType = item.itemSubType:lower()

    if item.itemID and KNOWN_BANDAGE_IDS[item.itemID] then return true end
    if not IsConsumableItem(item) then return false end
    return item.subClassID == BANDAGE_SUBCLASS_ID
        or subType:find("bandage", 1, true)
        or name:find("bandage", 1, true)
        or tooltip:find("bandage", 1, true)
end

local IsWater

local function IsFood(item, tooltipData, spellText)
    local tooltip = tooltipData.text
    local name = item.name and item.name:lower() or ""
    local itemType = item.itemType:lower()
    local itemSubType = item.itemSubType:lower()

    if IsPotionItem(item) or IsBandageItem(item, tooltip) then return false end
    if not IsFoodDrinkItem(item, tooltipData) then return false end
    if not TooltipRestoresHealth(GetRestoreText(tooltipData)) then return false end
    if item.itemID and KNOWN_FOOD_IDS[item.itemID] then return true end
    if spellText:find("food", 1, true) then return true end
    if tooltip:find("must remain seated while eating", 1, true) then return true end
    if tooltip:find("eat", 1, true) then return true end
    if ContainsAny(name, FOOD_NAME_HINTS) and not ContainsAny(name, WATER_NAME_HINTS) then return true end
    if itemSubType:find("food", 1, true) and not itemSubType:find("drink", 1, true) then return true end
    if itemType:find("consumable", 1, true) and tooltip:find("eat", 1, true) then return true end

    return false
end

IsWater = function(item, tooltipData, spellText)
    local tooltip = tooltipData.text
    local name = item.name and item.name:lower() or ""
    local itemSubType = item.itemSubType:lower()

    if IsPotionItem(item) or IsBandageItem(item, tooltip) then return false end
    if not IsFoodDrinkItem(item, tooltipData) then return false end
    if not TooltipRestoresMana(GetRestoreText(tooltipData)) then return false end
    if item.itemID and KNOWN_WATER_IDS[item.itemID] then return true end
    if spellText:find("drink", 1, true) then return true end
    if tooltip:find("must remain seated while drinking", 1, true) then return true end
    if ContainsAny(name, WATER_NAME_HINTS) then return true end
    if itemSubType:find("drink", 1, true) then return true end

    return false
end

local function IsHealthConsumable(item, tooltip, spellText)
    local name = item.name and item.name:lower() or ""

    if IsHealthstoneItem(item, tooltip) then return false end
    if HasRegeneratingHealthEffect(name) or HasRegeneratingHealthEffect(tooltip) or HasRegeneratingHealthEffect(spellText) then return false end
    if item.itemID and KNOWN_HEALTH_IDS[item.itemID] then return true end
    if not IsConsumableItem(item) then return false end
    if not IsPotionItem(item) then return false end
    if name:find("healing potion", 1, true) or name:find("health potion", 1, true) then return true end
    if spellText:find("healing potion", 1, true) or HasImmediateHealthRestore(spellText) then return true end
    if HasImmediateHealthRestore(tooltip) and not tooltip:find("mana", 1, true) then return true end

    return false
end

local function IsManaConsumable(item, tooltip, spellText)
    local name = item.name and item.name:lower() or ""

    if item.itemID and KNOWN_MANA_IDS[item.itemID] then return true end
    if not IsConsumableItem(item) then return false end
    if name:find("mana potion", 1, true) then return true end
    if not IsPotionItem(item) then return false end
    if spellText:find("mana potion", 1, true) or spellText:find("restore mana", 1, true) then return true end
    if tooltip:find("restores %d+ mana") or tooltip:find("restores %d+ to %d+ mana") then return true end

    return tooltip:find("mana", 1, true) ~= nil
end

local function IsBandage(item, tooltip)
    return IsBandageItem(item, tooltip)
end

local function ScoreItem(item, tooltipData, spellText, category)
    local tooltip = tooltipData.text
    local score = item.itemLevel or 0
    local name = item.name and item.name:lower() or ""

    if category == "Food" then
        score = ExtractRestoreValue(GetRestoreText(tooltipData), TOOLTIP_KEYWORDS.health, UnitHealthMax("player") or 0)
        if IsConjuredFoodOrWater(item, tooltipData, category) then
            score = score + 1000000000
        end
        return score
    elseif category == "WellFed" then
        local buffValue = ExtractWellFedBuffValue(tooltipData, spellText)
        local restoreValue = ExtractRestoreValue(GetRestoreText(tooltipData), TOOLTIP_KEYWORDS.health, UnitHealthMax("player") or 0)
        return (buffValue * 1000000) + restoreValue + ((item.itemLevel or 0) * 100) + (item.reqLevel or 0)
    elseif category == "Water" then
        score = ExtractRestoreValue(GetRestoreText(tooltipData), TOOLTIP_KEYWORDS.mana, UnitPowerMax("player", Enum and Enum.PowerType and Enum.PowerType.Mana or 0) or 0)
        if IsConjuredFoodOrWater(item, tooltipData, category) then
            score = score + 1000000000
        end
        return score
    elseif category == "Healthstone" then
        score = ExtractRestoreValue(GetRestoreText(tooltipData), TOOLTIP_KEYWORDS.health, UnitHealthMax("player") or 0)
        return score > 0 and score or (item.itemLevel or 0)
    end

    local isConjured = name:find("conjured", 1, true) or tooltip:find("conjured", 1, true)
    if isConjured then
        score = score + 100000
    end

    if category == "Food" and item.itemID and KNOWN_CONJURED_FOOD_IDS[item.itemID] then
        score = score + 150000
    elseif category == "Water" and item.itemID and KNOWN_CONJURED_WATER_IDS[item.itemID] then
        score = score + 150000
    end

    if category == "Pot" and (tooltip:find("healthstone", 1, true) or (item.itemID and KNOWN_HEALTHSTONE_IDS[item.itemID])) then
        score = score + 200000
    end

    return score
end

local function GetStableItemKey(item)
    if item.itemID then
        return "id:" .. item.itemID
    end
    return "name:" .. (item.name or "")
end

local function IsRawFoodName(item)
    local name = item and item.name and item.name:lower() or ""
    return name:find("%f[%a]raw%f[%A]") ~= nil
end

local function CompareRawFoodPreference(item, bestItem)
    local itemIsRaw = IsRawFoodName(item)
    local bestIsRaw = IsRawFoodName(bestItem)
    if itemIsRaw ~= bestIsRaw then
        return not itemIsRaw
    end
    return nil
end

local function IsBetterItem(item, score, bestItem, bestScore, category)
    if not bestItem then return true end
    if score ~= bestScore then return score > bestScore end

    if category == "Food" then
        local rawPreference = CompareRawFoodPreference(item, bestItem)
        if rawPreference ~= nil then return rawPreference end
    end

    return GetStableItemKey(item) > GetStableItemKey(bestItem)
end

local function MatchesCategory(item, tooltipData, spellText, category)
    local tooltip = tooltipData.text
    if category == "Food" then
        return IsFood(item, tooltipData, spellText) and not IsWellFedFood(tooltipData, spellText)
    elseif category == "WellFed" then
        return IsFood(item, tooltipData, spellText) and IsWellFedFood(tooltipData, spellText)
    elseif category == "Water" then
        return IsWater(item, tooltipData, spellText)
    elseif category == "Pot" then
        return IsHealthConsumable(item, tooltip, spellText)
    elseif category == "Healthstone" then
        return IsHealthstoneItem(item, tooltip)
    elseif category == "Mana" then
        return IsManaConsumable(item, tooltip, spellText)
    elseif category == "Band" then
        return IsBandage(item, tooltip)
    end
    return false
end

Classifier.IsConjuredFoodOrWater = IsConjuredFoodOrWater
Classifier.IsPotentialItem = IsPotentialItem
Classifier.IsBetterItem = IsBetterItem
Classifier.MatchesCategory = MatchesCategory
Classifier.ScoreItem = ScoreItem
