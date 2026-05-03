--[[ Carpenter - SmartMacros ]]
-- Builds consumable macros for the best matching item name in the player's bags.

local _, ns = ...
local addonFrame = CreateFrame("Frame")

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
local GetBagItemInfo = (C_Container and C_Container.GetContainerItemInfo) or _G.GetContainerItemInfo
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemSpell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

local ITEMS = {
    Food = { name = "CarpenterFood", legacyName = "ClassicFood" },
    Water = { name = "CarpenterWater", legacyName = "ClassicWater" },
    Pot = { name = "CarpenterHP", legacyName = "ClassicHP" },
    Mana = { name = "CarpenterMana", legacyName = "ClassicMana" },
    Band = { name = "CarpenterBand", legacyName = "ClassicBand" },
}

local RETAIL_ITEMS = {
    Food = ITEMS.Food,
    Water = ITEMS.Water,
    Pot = ITEMS.Pot,
    Mana = ITEMS.Mana,
}

local INTERNAL_CATEGORIES = {
    Healthstone = true,
}

local CLASS_HEAL_SPELLS = {
    RECUPERATE = 1248165,
    CRIMSON_VIAL = 185311,
}

local FOOD_NAME_HINTS = {
    "apple", "banana", "basilisk", "bean", "berry", "bleu", "bread", "brie", "brisket", "burger", "cake",
    "catfish", "cheese", "cherry", "chops", "clam", "clefthoof", "cod", "cookie", "cornbread", "crab",
    "dumpling", "egg", "fish", "fruit", "ham", "haunch", "jerky", "lobster", "mackerel", "meat", "mild",
    "morel", "muffin", "mushroom", "mutton", "omelet", "pie", "pork", "pumpkin", "quail", "ravager dog",
    "ribs", "roll", "salmon", "sausage", "serpent", "shank", "sharp", "snapper", "sporeling", "steak",
    "stew", "strudel", "talbuk", "tenderloin", "trout", "truffle", "tuber", "warp burger", "watermelon",
    "wolf", "yellowtail", "zesty",
}

local WATER_NAME_HINTS = {
    "drink", "juice", "milk", "spring water", "water",
}

local TOOLTIP_KEYWORDS = {
    use = { "use:", "benutzen:" },
    health = { "health", "gesundheit" },
    healthstone = { "healthstone", "gesundheitsstein" },
    mana = { "mana" },
    foodAndDrink = { "remain seated while", "sitzen bleiben" },
    conjured = { "conjured item", "conjured", "mana bun", "mana strudel", "mana biscuit", "mana cake", "mana pie", "herbeigezauberter gegenstand", "herbeigezaubert" },
}

-- Hard fallback for common Classic/TBC foods in case item info or tooltip text is sparse.
local KNOWN_FOOD_IDS = {
    [117] = true, [414] = true, [422] = true, [787] = true, [1113] = true, [1114] = true, [1487] = true,
    [1707] = true, [2070] = true, [2287] = true, [2679] = true, [2680] = true, [2681] = true, [2682] = true,
    [2683] = true, [2684] = true, [2685] = true, [2687] = true, [2888] = true, [3662] = true, [3663] = true,
    [3664] = true, [3665] = true, [3666] = true, [3726] = true, [3727] = true, [3728] = true, [3729] = true,
    [3770] = true, [3771] = true, [4592] = true, [4593] = true, [4594] = true, [4599] = true, [4601] = true,
    [4602] = true, [4604] = true, [4605] = true, [4606] = true, [4607] = true, [4608] = true, [5472] = true,
    [5473] = true, [5474] = true, [5476] = true, [5477] = true, [5525] = true, [6038] = true, [6290] = true,
    [6316] = true, [6887] = true, [8364] = true, [8950] = true, [8952] = true, [8953] = true, [8957] = true,
    [9681] = true, [12209] = true, [12210] = true, [12213] = true, [12214] = true, [12215] = true, [12216] = true,
    [12217] = true, [12218] = true, [12224] = true, [13810] = true, [13927] = true, [13928] = true, [13929] = true,
    [13930] = true, [13931] = true, [13932] = true, [13933] = true, [13934] = true, [13935] = true, [16766] = true,
    [17119] = true, [17222] = true, [17406] = true, [18254] = true, [19304] = true, [19696] = true, [21023] = true,
    [21030] = true, [21031] = true, [21033] = true, [22324] = true, [22645] = true, [22895] = true, [23495] = true,
    [27635] = true, [27636] = true, [27651] = true, [27655] = true, [27656] = true, [27657] = true, [27658] = true,
    [27659] = true, [27660] = true, [27661] = true, [27662] = true, [27663] = true, [27664] = true, [27665] = true,
    [27666] = true, [27667] = true, [27668] = true, [27669] = true, [27671] = true, [27854] = true, [27855] = true,
    [27856] = true, [27857] = true, [28486] = true, [29393] = true, [29448] = true, [30458] = true, [31672] = true,
    [33052] = true, [33053] = true, [33872] = true, [34062] = true, [35563] = true, [35565] = true,
}

local KNOWN_WATER_IDS = {
    [159] = true, [1179] = true, [1205] = true, [1645] = true, [1708] = true, [2136] = true, [2288] = true,
    [3772] = true, [5350] = true, [8077] = true, [8078] = true, [8766] = true, [8079] = true, [10841] = true,
    [18300] = true, [22018] = true, [28399] = true, [29395] = true, [30703] = true, [32453] = true, [33444] = true,
}

local KNOWN_CONJURED_FOOD_IDS = {
    [1113] = true, [1114] = true, [1487] = true, [8075] = true, [8076] = true, [22895] = true, [22019] = true,
    [34062] = true,
}

local KNOWN_CONJURED_WATER_IDS = {
    [5350] = true, [8077] = true, [8078] = true, [8079] = true, [10841] = true, [18300] = true, [22018] = true,
    [28399] = true, [30703] = true, [33312] = true,
}

local KNOWN_HEALTH_IDS = {
    [118] = true, [858] = true, [929] = true, [1710] = true, [3928] = true, [13446] = true, [22829] = true,
    [32947] = true, [43569] = true,
}

local KNOWN_MANA_IDS = {
    [2455] = true, [3385] = true, [3827] = true, [6149] = true, [13443] = true, [22832] = true, [32948] = true,
    [43570] = true,
}

local KNOWN_HEALTHSTONE_IDS = {
    [5509] = true, [5510] = true, [5511] = true, [5512] = true, [9421] = true, [19004] = true, [19005] = true,
    [19006] = true, [19007] = true, [19008] = true, [19009] = true, [19010] = true, [19011] = true, [19012] = true,
    [19013] = true, [22103] = true, [22104] = true, [22105] = true, [22106] = true, [22107] = true, [22108] = true,
}

local KNOWN_BANDAGE_IDS = {
    [1251] = true, [2581] = true, [3530] = true, [3531] = true, [6450] = true, [6451] = true, [8544] = true,
    [8545] = true, [14529] = true, [14530] = true, [21990] = true, [21991] = true, [34721] = true, [34722] = true,
}

local scanTooltip = CreateFrame("GameTooltip", "CP_SmartMacroScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local CONSUMABLE_CLASS_ID = 0
local POTION_SUBCLASS_ID = 1
local FOOD_DRINK_SUBCLASS_ID = 5
local BANDAGE_SUBCLASS_ID = 7
local TRADESKILL_CLASS_ID = 7
local COOKING_SUBCLASS_ID = 8
local MISCELLANEOUS_CLASS_ID = 15
local REAGENT_SUBCLASS_ID = 1

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("smartMacrosEnabled")
end

local function IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function GetActiveItems()
    return IsRetail() and RETAIL_ITEMS or ITEMS
end

local function GetScanCategories()
    local categories = {}
    for category in pairs(GetActiveItems()) do
        categories[category] = true
    end
    for category in pairs(INTERNAL_CATEGORIES) do
        categories[category] = true
    end
    return categories
end

local function ContainsAny(text, hints)
    if not text or text == "" then return false end
    for _, hint in ipairs(hints) do
        if text:find(hint, 1, true) then return true end
    end
    return false
end

local function GetNameFromLink(itemLink)
    if not itemLink then return nil end
    return itemLink:match("|h%[(.-)%]|h") or itemLink:match("%[(.-)%]")
end

local function GetSlotItem(bag, slot)
    local itemID = GetItemID and GetItemID(bag, slot)
    local itemLink = GetItemLink and GetItemLink(bag, slot)
    local texture

    if GetBagItemInfo then
        local info = GetBagItemInfo(bag, slot)
        if type(info) == "table" then
            itemID = itemID or info.itemID
            itemLink = itemLink or info.hyperlink
            texture = info.iconFileID or info.icon
        else
            local legacyTexture, _, _, _, _, _, legacyLink, _, _, legacyID = GetBagItemInfo(bag, slot)
            itemID = itemID or legacyID
            itemLink = itemLink or legacyLink
            texture = legacyTexture
        end
    end

    if not itemID and itemLink then
        itemID = tonumber(itemLink:match("item:(%d+)"))
    end

    if not itemID and not itemLink and not texture then
        return nil
    end

    local name, link, _, itemLevel, reqLevel, itemType, itemSubType, _, _, icon, _, classID, subClassID =
        GetItemInfo(itemLink or itemID or "")
    if GetItemInfoInstant then
        local _, _, _, _, instantIcon, instantClassID, instantSubClassID = GetItemInfoInstant(itemLink or itemID or "")
        icon = icon or instantIcon
        classID = classID or instantClassID
        subClassID = subClassID or instantSubClassID
    end
    name = name or GetNameFromLink(itemLink)
    link = link or itemLink
    icon = icon or texture

    return {
        bag = bag,
        slot = slot,
        itemID = itemID,
        name = name,
        link = link,
        itemLevel = itemLevel or 0,
        reqLevel = reqLevel or 0,
        itemType = itemType or "",
        itemSubType = itemSubType or "",
        icon = icon,
        classID = classID,
        subClassID = subClassID,
    }
end

local function AddTooltipLine(result, line)
    if not line or line == "" then return end
    local text = line:lower()
    result.text = result.text .. " " .. text
    local hasUse = ContainsAny(text, TOOLTIP_KEYWORDS.use)
    local hasRestore = ContainsAny(text, TOOLTIP_KEYWORDS.health) or ContainsAny(text, TOOLTIP_KEYWORDS.mana)
    if hasUse then
        result.awaitingUseText = true
    end
    if not result.useText and hasRestore and (hasUse or result.awaitingUseText) then
        result.useText = text
    end
    if result.awaitingUseText and text ~= "" and not hasUse then
        result.awaitingUseText = false
    end
    if not result.isFoodAndDrink and ContainsAny(text, TOOLTIP_KEYWORDS.foodAndDrink) then
        result.isFoodAndDrink = true
    end
    if ContainsAny(text, TOOLTIP_KEYWORDS.conjured) then
        result.isConjured = true
    end
end

local function ReadTooltip(bag, slot, item)
    local result = {
        text = "",
        useText = nil,
        awaitingUseText = false,
        isFoodAndDrink = false,
        isConjured = false,
    }

    if item and item.link and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local tooltipData = C_TooltipInfo.GetHyperlink(item.link, nil, nil, true)
        if tooltipData and tooltipData.lines then
            for i = 2, #tooltipData.lines do
                local line = tooltipData.lines[i]
                if IsRetail() and line then
                    AddTooltipLine(result, line.leftText)
                    AddTooltipLine(result, line.rightText)
                elseif line and line.type == 0 then
                    AddTooltipLine(result, line.leftText)
                end
            end
            if result.text ~= "" or not IsRetail() then
                return result
            end
        end
    end

    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)

    for i = 1, scanTooltip:NumLines() do
        local left = _G["CP_SmartMacroScanTooltipTextLeft" .. i]
        local right = _G["CP_SmartMacroScanTooltipTextRight" .. i]
        local leftText = left and left:GetText()
        local rightText = right and right:GetText()
        AddTooltipLine(result, leftText)
        AddTooltipLine(result, rightText)
    end

    return result
end

local function GetSpellText(item)
    if not GetItemSpell then return "" end
    local spellName = GetItemSpell(item.link or item.itemID or "")
    return spellName and spellName:lower() or ""
end

local function GetSpellName(spellID, fallback)
    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if type(spellInfo) == "table" and spellInfo.name then
            return spellInfo.name
        end
    end
    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name then return name end
    end
    return fallback
end

local function IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    if _G.IsPlayerSpell then
        return _G.IsPlayerSpell(spellID)
    end
    return false
end

local function GetCooldownRemaining(startTime, duration, isEnabled)
    if isEnabled == false or isEnabled == 0 or not duration or duration <= 1.5 or not startTime or startTime <= 0 then
        return 0
    end
    return math.max(0, startTime + duration - (GetTime and GetTime() or 0))
end

local function GetSpellCooldownRemaining(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
        if type(cooldownInfo) == "table" then
            return GetCooldownRemaining(cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.isEnabled)
        end
    end
    if _G.GetSpellCooldown then
        local startTime, duration, isEnabled = _G.GetSpellCooldown(spellID)
        return GetCooldownRemaining(startTime, duration, isEnabled)
    end
    return 0
end

local function GetItemCooldownRemaining(item)
    if not item then return 0 end
    local itemKey = item.itemID or item.name
    if C_Item and C_Item.GetItemCooldown and itemKey then
        local startTime, duration, isEnabled = C_Item.GetItemCooldown(itemKey)
        if type(startTime) == "table" then
            return GetCooldownRemaining(startTime.startTime, startTime.duration, startTime.isEnabled)
        end
        return GetCooldownRemaining(startTime, duration, isEnabled)
    end
    if _G.GetItemCooldown and itemKey then
        local startTime, duration, isEnabled = _G.GetItemCooldown(itemKey)
        return GetCooldownRemaining(startTime, duration, isEnabled)
    end
    return 0
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

local function IsPotentialSmartMacroItem(item)
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
    if not TooltipRestoresHealth(tooltipData.useText) then return false end
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
    if not TooltipRestoresMana(tooltipData.useText) then return false end
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
    if item.itemID and KNOWN_HEALTH_IDS[item.itemID] then return true end
    if not IsConsumableItem(item) then return false end
    if not IsPotionItem(item) then return false end
    if name:find("healing potion", 1, true) or name:find("health potion", 1, true) then return true end
    if spellText:find("healing potion", 1, true) or spellText:find("restore health", 1, true) or spellText:find("heal", 1, true) then return true end
    if (tooltip:find("restores %d+ health") or tooltip:find("restores %d+ to %d+ health") or tooltip:find("heals %d+")) and not tooltip:find("mana", 1, true) then return true end

    return tooltip:find("health", 1, true) ~= nil
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
        score = ExtractRestoreValue(tooltipData.useText, TOOLTIP_KEYWORDS.health, UnitHealthMax("player") or 0)
        if IsConjuredFoodOrWater(item, tooltipData, category) then
            score = score + 1000000000
        end
        return score
    elseif category == "Water" then
        score = ExtractRestoreValue(tooltipData.useText, TOOLTIP_KEYWORDS.mana, UnitPowerMax("player", Enum and Enum.PowerType and Enum.PowerType.Mana or 0) or 0)
        if IsConjuredFoodOrWater(item, tooltipData, category) then
            score = score + 1000000000
        end
        return score
    elseif category == "Healthstone" then
        score = ExtractRestoreValue(tooltipData.useText, TOOLTIP_KEYWORDS.health, UnitHealthMax("player") or 0)
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

    if category == "Food" and (tooltip:find("well fed", 1, true) or tooltip:find("%+%d+")) then
        score = score - 5000
    elseif category == "Pot" and (tooltip:find("healthstone", 1, true) or (item.itemID and KNOWN_HEALTHSTONE_IDS[item.itemID])) then
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

local function IsBetterItem(item, score, bestItem, bestScore)
    if not bestItem then return true end
    if score ~= bestScore then return score > bestScore end

    return GetStableItemKey(item) > GetStableItemKey(bestItem)
end

local function MatchesCategory(item, tooltipData, spellText, category)
    local tooltip = tooltipData.text
    if category == "Food" then
        return IsFood(item, tooltipData, spellText)
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

local function GetBagFingerprint()
    local parts = {}
    for bag = 0, 4 do
        local numSlots = GetNumSlots and GetNumSlots(bag) or 0
        parts[#parts + 1] = bag .. ":" .. numSlots
        for slot = 1, numSlots do
            parts[#parts + 1] = GetItemID and (GetItemID(bag, slot) or 0) or 0
        end
    end
    return table.concat(parts, ";")
end

local function GetBestItems(debugOutput)
    local bestItems = {}
    local bestScores = {}
    local playerLevel = UnitLevel("player") or 0
    local needsItemInfoRetry = false

    for bag = 0, 4 do
        local numSlots = GetNumSlots and GetNumSlots(bag) or 0
        for slot = 1, numSlots do
            local item = GetSlotItem(bag, slot)
            if item and item.reqLevel <= playerLevel then
                if not item.name then
                    needsItemInfoRetry = true
                end

                if IsPotentialSmartMacroItem(item) then
                    local tooltipData = ReadTooltip(bag, slot, item)
                    local spellText = GetSpellText(item)
                    tooltipData.spellText = spellText

                    for category in pairs(GetScanCategories()) do
                        if MatchesCategory(item, tooltipData, spellText, category) then
                            local score = ScoreItem(item, tooltipData, spellText, category)
                            if debugOutput and (category == "Food" or category == "Water") then
                                print(string.format(
                                    "|cff00aaffCarpenter %s candidate:|r %s id=%s score=%s conjured=%s use=%s",
                                    category,
                                    item.name or "?",
                                    tostring(item.itemID or "?"),
                                    tostring(score),
                                    tostring(IsConjuredFoodOrWater(item, tooltipData, category) and true or false),
                                    tooltipData.useText or "?"
                                ))
                            end
                            if IsBetterItem(item, score, bestItems[category], bestScores[category] or -1) then
                                bestScores[category] = score
                                bestItems[category] = item
                            end
                        end
                    end
                end
            end
        end
    end

    if debugOutput then
        for _, category in ipairs({ "Food", "Water" }) do
            local item = bestItems[category]
            print(string.format("|cff00aaffCarpenter best %s:|r %s score=%s", category, item and item.name or "none", tostring(bestScores[category] or "none")))
        end
    end

    return bestItems, needsItemInfoRetry
end

local function UpdateMacro(name, body, createIfMissing)
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex == 0 then
        if createIfMissing then
            CreateMacro(name, "INV_Misc_QuestionMark", body, 1)
        end
        return
    end

    local _, _, curBody = GetMacroInfo(macroIndex)
    if curBody ~= body then
        EditMacro(macroIndex, name, nil, body)
    end
end

local function DeleteMacroByName(name)
    if not DeleteMacro then return end
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex > 0 then
        DeleteMacro(macroIndex)
    end
end

local function BuildHealthMacroBody(potion, healthstone)
    local lines = {}
    local entries = {}
    local recuperate = GetSpellName(CLASS_HEAL_SPELLS.RECUPERATE, "Recuperate")
    local crimsonVial = GetSpellName(CLASS_HEAL_SPELLS.CRIMSON_VIAL, "Crimson Vial")
    local _, class = UnitClass("player")
    local tooltip

    if recuperate and (IsRetail() or IsSpellKnown(CLASS_HEAL_SPELLS.RECUPERATE)) then
        tooltip = tooltip or ("[nocombat] " .. recuperate)
        entries[#entries + 1] = {
            line = "/cast [nocombat] " .. recuperate,
            stopLine = "/stopmacro [nocombat]",
        }
    end

    if class == "ROGUE" and crimsonVial and IsSpellKnown(CLASS_HEAL_SPELLS.CRIMSON_VIAL) then
        tooltip = tooltip and (tooltip .. "; [combat] " .. crimsonVial) or ("[combat] " .. crimsonVial)
        entries[#entries + 1] = {
            line = "/castsequence [@player,combat] reset=combat " .. crimsonVial,
        }
    end

    if healthstone and healthstone.name then
        tooltip = tooltip and (tooltip .. "; " .. healthstone.name) or healthstone.name
        entries[#entries + 1] = {
            line = "/use " .. healthstone.name,
        }
    end

    if potion and potion.name then
        tooltip = tooltip and (tooltip .. "; " .. potion.name) or potion.name
        entries[#entries + 1] = {
            line = "/use " .. potion.name,
        }
    end

    lines[#lines + 1] = tooltip and ("#showtooltip " .. tooltip) or "#showtooltip"

    for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry.line
        if entry.stopLine then
            lines[#lines + 1] = entry.stopLine
        end
    end

    return table.concat(lines, "\n")
end

local function BuildMacroBody(item)
    if not item or not item.name then
        return "#showtooltip\n"
    end

    return "#showtooltip " .. item.name .. "\n/use " .. item.name
end

local lastBagFingerprint

local function ProcessUpdate(forceRescan)
    if not IsEnabled() then return end
    if InCombatLockdown() then
        addonFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local bagFingerprint = GetBagFingerprint()
    if not forceRescan and bagFingerprint == lastBagFingerprint then
        return
    end
    lastBagFingerprint = bagFingerprint

    local bestItems, needsItemInfoRetry = GetBestItems()
    for key, config in pairs(GetActiveItems()) do
        local best = bestItems[key]
        local body = (key == "Pot")
            and BuildHealthMacroBody(best, bestItems.Healthstone)
            or BuildMacroBody(best)

        UpdateMacro(config.name, body, true)
        if config.legacyName then
            UpdateMacro(config.legacyName, body, false)
        end
    end

    if IsRetail() then
        DeleteMacroByName(ITEMS.Band.name)
        DeleteMacroByName(ITEMS.Band.legacyName)
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
        C_Timer.After(2 - (now - lastUpdateTime), RunScheduledUpdate)
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
    C_Timer.After(delay or 0.75, RunScheduledUpdate)
end

addonFrame:RegisterEvent("BAG_UPDATE_DELAYED")
addonFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

addonFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        MarkDirty(0.25)
    elseif event == "PLAYER_ENTERING_WORLD" then
        MarkDirty(1.5, true)
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

SLASH_CARPENTERSMARTMACROS1 = "/cpmacros"
SlashCmdList["CARPENTERSMARTMACROS"] = function()
    GetBestItems(true)
end
