--[[ Carpenter - Smart Macro scanner ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Scanner = ns.Private.SmartMacroScanner or {}
ns.Private.SmartMacroScanner = Scanner

local Data = ns.Private.SmartMacroData or {}

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
local GetBagItemInfo = (C_Container and C_Container.GetContainerItemInfo) or _G.GetContainerItemInfo
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemSpell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

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

local scanTooltip = CreateFrame("GameTooltip", "CP_SmartMacroScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsRetail()
    return Data.IsRetail and Data.IsRetail()
end

local function GetScanCategories()
    return Data.GetScanCategories and Data.GetScanCategories() or {}
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
    return text:find("well fed", 1, true) ~= nil
        or text:find("gut genährt", 1, true) ~= nil
        or text:find("satt", 1, true) ~= nil
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
        if not IsWellFedFood(tooltipData, spellText) then
            score = score + 2000000000
        end
        if IsConjuredFoodOrWater(item, tooltipData, category) then
            score = score + 1000000000
        end
        return score
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

Scanner.GetBagFingerprint = GetBagFingerprint
Scanner.GetBestItems = GetBestItems
Scanner.ContainsAny = ContainsAny
