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

local ITEMS = {
    Food = { name = "CarpenterFood", legacyName = "ClassicFood" },
    Water = { name = "CarpenterWater", legacyName = "ClassicWater" },
    Pot = { name = "CarpenterHP", legacyName = "ClassicHP" },
    Mana = { name = "CarpenterMana", legacyName = "ClassicMana" },
    Band = { name = "CarpenterBand", legacyName = "ClassicBand" },
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

local scanTooltip = CreateFrame("GameTooltip", "CP_SmartMacroScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("smartMacrosEnabled")
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

local function ReadTooltip(bag, slot)
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)

    local text = ""
    for i = 1, scanTooltip:NumLines() do
        local left = _G["CP_SmartMacroScanTooltipTextLeft" .. i]
        local right = _G["CP_SmartMacroScanTooltipTextRight" .. i]
        local leftText = left and left:GetText()
        local rightText = right and right:GetText()
        if leftText then text = text .. " " .. leftText:lower() end
        if rightText then text = text .. " " .. rightText:lower() end
    end

    return text
end

local function GetSpellText(item)
    if not GetItemSpell then return "" end
    local spellName = GetItemSpell(item.link or item.itemID or "")
    return spellName and spellName:lower() or ""
end

local function IsFood(item, tooltip, spellText)
    local name = item.name and item.name:lower() or ""
    local itemType = item.itemType:lower()
    local itemSubType = item.itemSubType:lower()

    if item.itemID and KNOWN_FOOD_IDS[item.itemID] then return true end
    if spellText:find("food", 1, true) then return true end
    if tooltip:find("must remain seated while eating", 1, true) then return true end
    if tooltip:find("restores %d+ health") and not tooltip:find("mana", 1, true) then return true end
    if ContainsAny(name, FOOD_NAME_HINTS) and not ContainsAny(name, WATER_NAME_HINTS) then return true end
    if itemSubType:find("food", 1, true) and not itemSubType:find("drink", 1, true) then return true end
    if itemType:find("consumable", 1, true) and tooltip:find("eat", 1, true) then return true end

    return false
end

local function IsWater(item, tooltip, spellText)
    local name = item.name and item.name:lower() or ""
    local itemSubType = item.itemSubType:lower()

    if item.itemID and KNOWN_WATER_IDS[item.itemID] then return true end
    if spellText:find("drink", 1, true) then return true end
    if tooltip:find("must remain seated while drinking", 1, true) then return true end
    if tooltip:find("restores %d+ mana") then return true end
    if ContainsAny(name, WATER_NAME_HINTS) then return true end
    if itemSubType:find("drink", 1, true) then return true end

    return false
end

local function IsHealthConsumable(item, tooltip)
    local subType = item.itemSubType:lower()
    return tooltip:find("healthstone", 1, true) or
        ((item.subClassID == 1 or subType:find("potion", 1, true)) and tooltip:find("health", 1, true))
end

local function IsManaConsumable(item, tooltip)
    local subType = item.itemSubType:lower()
    return (item.subClassID == 1 or subType:find("potion", 1, true)) and tooltip:find("mana", 1, true)
end

local function IsBandage(item, tooltip)
    local subType = item.itemSubType:lower()
    return item.subClassID == 7 or subType:find("bandage", 1, true) or tooltip:find("bandage", 1, true)
end

local function ScoreItem(item, tooltip, spellText, category)
    local score = item.itemLevel or 0
    local name = item.name and item.name:lower() or ""

    local restores = tooltip:match("restores%s+(%d+)")
    if restores then
        score = score + tonumber(restores)
    end

    if name:find("conjured", 1, true) or tooltip:find("conjured", 1, true) then
        score = score + 100000
    end

    if category == "Food" and (tooltip:find("well fed", 1, true) or tooltip:find("%+%d+")) then
        score = score - 5000
    elseif category == "Pot" and tooltip:find("healthstone", 1, true) then
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

local function MatchesCategory(item, tooltip, spellText, category)
    if category == "Food" then
        return IsFood(item, tooltip, spellText)
    elseif category == "Water" then
        return IsWater(item, tooltip, spellText)
    elseif category == "Pot" then
        return IsHealthConsumable(item, tooltip)
    elseif category == "Mana" then
        return IsManaConsumable(item, tooltip)
    elseif category == "Band" then
        return IsBandage(item, tooltip)
    end
    return false
end

local function GetBestItem(category)
    local bestItem
    local bestScore = -1
    local playerLevel = UnitLevel("player") or 0

    for bag = 0, 4 do
        local numSlots = GetNumSlots and GetNumSlots(bag) or 0
        for slot = 1, numSlots do
            local item = GetSlotItem(bag, slot)
            if item and item.reqLevel <= playerLevel then
                local tooltip = ReadTooltip(bag, slot)
                local spellText = GetSpellText(item)

                if MatchesCategory(item, tooltip, spellText, category) then
                    local score = ScoreItem(item, tooltip, spellText, category)
                    if IsBetterItem(item, score, bestItem, bestScore) then
                        bestScore = score
                        bestItem = item
                    end
                end
            end
        end
    end

    return bestItem
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

local function BuildMacroBody(item)
    if not item or not item.name then
        return "#showtooltip\n"
    end

    return "#showtooltip " .. item.name .. "\n/use " .. item.name
end

local function ProcessUpdate()
    if not IsEnabled() then return end
    if InCombatLockdown() then
        addonFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    for key, config in pairs(ITEMS) do
        local best = GetBestItem(key)
        local body = BuildMacroBody(best)

        UpdateMacro(config.name, body, true)
        if config.legacyName then
            UpdateMacro(config.legacyName, body, false)
        end
    end
end

local isDirty = false

addonFrame:RegisterEvent("BAG_UPDATE")
addonFrame:RegisterEvent("BAG_UPDATE_DELAYED")
addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
addonFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

addonFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        isDirty = true
    elseif event == "PLAYER_ENTERING_WORLD" then
        ProcessUpdate()
    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" or event == "GET_ITEM_INFO_RECEIVED" then
        isDirty = true
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        isDirty = true
    end
end)

addonFrame:SetScript("OnUpdate", function(_, elapsed)
    if not isDirty then return end
    if InCombatLockdown() then return end

    isDirty = false
    ProcessUpdate()
end)

ns.UpdateSmartMacros = function()
    isDirty = true
end
