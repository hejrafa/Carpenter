--[[ Carpenter - Smart Macro scanner ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Scanner = ns.Private.SmartMacroScanner or {}
ns.Private.SmartMacroScanner = Scanner

local Data = ns.Private.SmartMacroData or {}
local Tooltip = ns.Private.SmartMacroTooltip or {}
local Classifier = ns.Private.SmartMacroClassifier or {}

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
local GetBagItemInfo = (C_Container and C_Container.GetContainerItemInfo) or _G.GetContainerItemInfo
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

local function GetScanCategories()
    return Data.GetScanCategories and Data.GetScanCategories() or {}
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

local function GetBagFingerprint()
    local parts = {}
    for bag = 0, 4 do
        local numSlots = GetNumSlots and GetNumSlots(bag) or 0
        parts[#parts + 1] = bag .. ":" .. numSlots
        for slot = 1, numSlots do
            local itemID = GetItemID and GetItemID(bag, slot)
            local itemLink = GetItemLink and GetItemLink(bag, slot)
            local texture, stackCount

            if GetBagItemInfo then
                local info = GetBagItemInfo(bag, slot)
                if type(info) == "table" then
                    itemID = itemID or info.itemID
                    itemLink = itemLink or info.hyperlink
                    texture = info.iconFileID or info.icon
                    stackCount = info.stackCount or info.quantity
                else
                    local legacyTexture, legacyCount, _, _, _, _, legacyLink, _, _, legacyID = GetBagItemInfo(bag, slot)
                    itemID = itemID or legacyID
                    itemLink = itemLink or legacyLink
                    texture = legacyTexture
                    stackCount = legacyCount
                end
            end

            if not itemID and itemLink then
                itemID = tonumber(itemLink:match("item:(%d+)"))
            end

            parts[#parts + 1] = table.concat({
                tostring(itemID or itemLink or texture or 0),
                tostring(stackCount or 0),
            }, ":")
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

                if Classifier.IsPotentialItem and Classifier.IsPotentialItem(item) then
                    local tooltipData = Tooltip.Read and Tooltip.Read(bag, slot, item) or { text = "" }
                    local spellText = Tooltip.GetSpellText and Tooltip.GetSpellText(item) or ""
                    tooltipData.spellText = spellText

                    for category in pairs(GetScanCategories()) do
                        if Classifier.MatchesCategory and Classifier.MatchesCategory(item, tooltipData, spellText, category) then
                            local score = Classifier.ScoreItem(item, tooltipData, spellText, category)
                            if debugOutput and (category == "Food" or category == "WellFed" or category == "Water") then
                                print(string.format(
                                    "|cff00aaffCarpenter %s candidate:|r %s id=%s score=%s conjured=%s use=%s",
                                    category,
                                    item.name or "?",
                                    tostring(item.itemID or "?"),
                                    tostring(score),
                                    tostring(Classifier.IsConjuredFoodOrWater and Classifier.IsConjuredFoodOrWater(item, tooltipData, category) and true or false),
                                    tooltipData.useText or "?"
                                ))
                            end
                            if Classifier.IsBetterItem and Classifier.IsBetterItem(item, score, bestItems[category], bestScores[category] or -1, category) then
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
        for _, category in ipairs({ "Food", "WellFed", "Water" }) do
            local item = bestItems[category]
            print(string.format("|cff00aaffCarpenter best %s:|r %s score=%s", category, item and item.name or "none", tostring(bestScores[category] or "none")))
        end
    end

    return bestItems, needsItemInfoRetry
end

Scanner.GetBagFingerprint = GetBagFingerprint
Scanner.GetBestItems = GetBestItems
Scanner.ContainsAny = Tooltip.ContainsAny
