--[[ Carpenter - ChatCleaner loot helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Utils = ns.Private.ChatCleanerUtils or {}
local Loot = ns.Private.ChatCleanerLoot or {}
ns.Private.ChatCleanerLoot = Loot

local function StripBrackets(text)
    return Utils.StripBrackets and Utils.StripBrackets(text) or text
end

local function CleanPunctuation(text)
    return Utils.CleanPunctuation and Utils.CleanPunctuation(text) or text
end

local function GetItemLinkFromMessage(text)
    return Utils.GetItemLinkFromMessage and Utils.GetItemLinkFromMessage(text) or nil
end

local function MakeLootPattern(fmt)
    return Utils.MakeLootPattern and Utils.MakeLootPattern(fmt) or nil
end

function Loot.BuildGroupLootPatterns()
    local patterns = {}
    local globals = {
        "LOOT_ITEM",
        "LOOT_ITEM_MULTIPLE",
        "LOOT_ITEM_PUSHED",
        "LOOT_ITEM_PUSHED_MULTIPLE",
        "CREATED_ITEM",
        "CREATED_ITEM_MULTIPLE",
    }

    for _, globalName in ipairs(globals) do
        local fmt = _G[globalName]
        if fmt and type(fmt) == "string" then
            local pattern = MakeLootPattern(fmt)
            if pattern then
                patterns[#patterns + 1] = { pattern = pattern, global = globalName }
            end
        end
    end

    return patterns
end

function Loot.BuildRollPatterns()
    local patterns = {}
    local globals = {
        "LOOT_ROLL_NEED",
        "LOOT_ROLL_GREED",
        "LOOT_ROLL_DISENCHANT",
        "LOOT_ROLL_WON",
    }

    for _, globalName in ipairs(globals) do
        local fmt = _G[globalName]
        if fmt and type(fmt) == "string" and not fmt:find("|H") then
            local pattern = MakeLootPattern(fmt)
            if pattern then
                local literal = (fmt:gsub("%%[%d%$]*s", ""):gsub("%%[%d%$]*d", ""):gsub("^%s+", " "):gsub("%s+$", " "))
                local relaxed = pattern:gsub(" need ", " .- "):gsub(" greed ", " .- "):gsub(" passed on ", " .- on "):gsub(" disenchant ", " .- "):gsub(" won ", " .- ")
                patterns[#patterns + 1] = { pattern = relaxed, literal = literal }
            end
        end
    end

    return patterns
end

Loot.RollPatternsFallback = {
    { pattern = "^(.-)%s+has selected .- for%s+(.+)$", literal = " has selected for " },
    { pattern = "^(.-)%s+passed on[:%s]+(.+)$", literal = " passed on " },
    { pattern = "^(.-)%s+won%s+(.+)$", literal = " won " },
}

local rollTypeByItem = {}

function Loot.GetRollItemKey(itemPart, msg)
    if not itemPart or itemPart == "" then
        local link = GetItemLinkFromMessage(msg or "")
        if link then
            local name = GetItemInfo(link)
            if name then return name end
        end
        return ""
    end

    local plain = (itemPart:gsub("|H.-|h(.-)|h", "%1")):gsub("^%s+", ""):gsub("%s+$", "")
    return CleanPunctuation(StripBrackets(plain)) or ""
end

function Loot.GetRollType(itemKey, playerName)
    if not itemKey or itemKey == "" then return "Greed" end
    local itemRolls = rollTypeByItem[itemKey]
    if not itemRolls then return "Greed" end
    return itemRolls[playerName] or itemRolls["You"] or "Greed"
end

function Loot.SetRollType(itemKey, playerName, rollType)
    if not itemKey or itemKey == "" then return end
    rollTypeByItem[itemKey] = rollTypeByItem[itemKey] or {}
    rollTypeByItem[itemKey][playerName] = rollType
end

function Loot.ClearRollItem(itemKey)
    if itemKey and itemKey ~= "" then
        rollTypeByItem[itemKey] = nil
    end
end

function Loot.Create(config)
    config = config or {}
    local cleanPunctuation = config.CleanPunctuation or CleanPunctuation
    local stripBrackets = config.StripBrackets or StripBrackets
    local spaceBeforeX = config.SpaceBeforeX or function(text) return text end
    local getItemLinkFromMessage = config.GetItemLinkFromMessage or GetItemLinkFromMessage
    local getItemLinkWithQualityColor = config.GetItemLinkWithQualityColor or function(link) return link end
    local getClassColorForName = config.GetClassColorForName or function() return "|cfff0f0f0" end
    local formatItemCountSuffix = config.FormatItemCountSuffix or function(text) return text end
    local formatReceivedDisplay = config.FormatReceivedDisplay or function() return nil end
    local shouldSkipGenericReceive = config.ShouldSkipGenericReceive or function() return true end
    local groupLootPatterns = config.GroupLootPatterns or Loot.BuildGroupLootPatterns()
    local rollPatterns = config.RollPatterns or Loot.BuildRollPatterns()
    local rollPatternsFallback = config.RollPatternsFallback or Loot.RollPatternsFallback
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorLootLiteral = config.ColorLootLiteral or "|cffc8c8c8"
    local L = config.L or (Carpenter and Carpenter.L) or {}

    local function T(key, fallback, ...)
        local text = L[key] or fallback or key
        if select("#", ...) > 0 then
            return string.format(text, ...)
        end
        return text
    end

    local function You()
        return L.CHAT_YOU or "You"
    end

    local api = {}

    local function StripTrailingLoot(display)
        if not display or type(display) ~= "string" then return display end
        return display:gsub("%s+[Ll]oot%s*$", ""):gsub("|r%s*$", "|r")
    end

    local function BuildDisplayFromMessage(message)
        local itemLink = getItemLinkFromMessage(message)
        if itemLink then
            local display = getItemLinkWithQualityColor(itemLink)
            display = spaceBeforeX(display)
            local stackCount = message:match(" x(%d+)%s*%.?%s*$") or message:match("x(%d+)%s*%.?%s*$")
            if stackCount then
                display = display .. " " .. colorPlus .. "(" .. stackCount .. ")|r"
            end
            return display
        end
        return nil
    end

    local function BuildRollDisplay(itemPart, fromMsg)
        local itemLink = getItemLinkFromMessage(fromMsg or "")
        local display
        if itemLink then
            display = getItemLinkWithQualityColor(itemLink)
            display = spaceBeforeX(display)
            local stackCount = (fromMsg or ""):match(" x(%d+)%s*(|r)?%s*$") or (fromMsg or ""):match(" x(%d+)%s* by ")
            if stackCount then
                display = display .. " " .. colorPlus .. "(" .. stackCount .. ")|r"
            end
        else
            display = cleanPunctuation(stripBrackets(itemPart or ""))
            display = spaceBeforeX(display)
            display = formatItemCountSuffix(display)
        end
        return StripTrailingLoot(display)
    end

    function api.FormatSelfLootMessage(event, message, prefixPlus)
        local item = message:match("You receive loot: (.+)") or message:match("You create: (.+)") or
            message:match("You receive item: (.+)") or message:match("You receive items: (.+)") or
            message:match("You received item: (.+)") or message:match("You received items: (.+)")
        if item then
            local display = formatReceivedDisplay(item, message)
            if display then return prefixPlus .. display end
        end

        if event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_CURRENCY" then
            local receivePayload =
                message:match("^[Yy]ou receive:%s*(.+)$") or
                message:match("^[Yy]ou received:%s*(.+)$") or
                message:match("^[Yy]ou receive an? item:%s*(.+)$") or
                message:match("^[Yy]ou received an? item:%s*(.+)$") or
                message:match("^[Yy]ou receive an?%s+(.+)$") or
                message:match("^[Yy]ou received an?%s+(.+)$") or
                message:match("^[Yy]ou receive%s+(.+)$") or
                message:match("^[Yy]ou received%s+(.+)$")

            if receivePayload and not shouldSkipGenericReceive(message) then
                local display = formatReceivedDisplay(receivePayload, message)
                if display then return prefixPlus .. display end
            end
        end

        return nil
    end

    function api.FormatGroupLootMessage(event, message, author)
        local isGroupLootEvent = event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or
            event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_YELL"
        if not isGroupLootEvent then return nil end

        local function StyleGroupLoot(name, display)
            if not name or name == "" or name == "You" then return nil end
            local nameColor = getClassColorForName(name)
            return spaceBeforeX(nameColor .. name .. "|r" .. colorLootLiteral .. ": " .. colorPlus .. "+|r " .. display)
        end

        local plainLoot = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
        local lowerPlain = plainLoot:lower()
        for _, entry in ipairs(groupLootPatterns) do
            local name, itemPart = plainLoot:match(entry.pattern)
            if name then
                name = name:gsub("^%s+", ""):gsub("%s+$", "")
                local display = BuildDisplayFromMessage(message)
                if not display then
                    display = cleanPunctuation(stripBrackets(itemPart or ""))
                    display = spaceBeforeX(display)
                    display = formatItemCountSuffix(display)
                end
                local out = StyleGroupLoot(name, display)
                if out then return out end
            end
        end

        local name, itemPart = plainLoot:match("^%s*(.-)%s+receives loot:%s*(.+)$") or
            plainLoot:match("^%s*(.-)%s+receives item:%s*(.+)$") or
            plainLoot:match("^%s*(.-)%s+creates:%s*(.+)$") or
            plainLoot:match("^%s*(.-)%s+conjures:%s*(.+)$")
        if name then
            name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            if name == "" and author and author ~= "" then name = author:gsub("%-.*$", "") end
        end
        if (not name or name == "") and author and author ~= "" then
            if lowerPlain:find("receives loot:") or lowerPlain:find("receives item:") or lowerPlain:find(" creates:") or lowerPlain:find(" conjures:") then
                name = author:gsub("%-.*$", "")
                itemPart = message
            end
        end
        if name and name ~= "" and name ~= "You" then
            local display = BuildDisplayFromMessage(message)
            if not display and itemPart then
                display = cleanPunctuation(stripBrackets(itemPart:gsub("|H.-|h(.-)|h", "%1")))
                display = spaceBeforeX(display)
                display = formatItemCountSuffix(display)
            end
            if display then return StyleGroupLoot(name, display) end
        end

        return nil
    end

    function api.FormatLootRollMessage(event, message)
        if event ~= "CHAT_MSG_LOOT" and event ~= "CHAT_MSG_SYSTEM" then return nil end

        local playerName = UnitName("player") or ""
        local plainRoll = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
        local coreRoll = plainRoll:gsub("^%s*%b[]%s*", "")
        local function NameOut(name)
            local isYou = name:lower() == "you"
            if isYou then
                return getClassColorForName(UnitName("player") or "You") .. You() .. "|r", true
            end
            local short = name:gsub("%-.*$", "")
            return getClassColorForName(short) .. short .. "|r", false
        end

        local looseYouType, looseYouItem = plainRoll:match("[Yy]ou%s+have%s+selected%s+(%S+).-[Ff]or%s*:?%s*(.+)$")
        if looseYouType and looseYouItem then
            local itemLink = getItemLinkFromMessage(message)
            local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(looseYouItem))
            local nameOut = getClassColorForName(UnitName("player") or "You") .. You() .. "|r"
            return spaceBeforeX(nameOut .. " " .. looseYouType .. ": " .. display)
        end

        local directWinName, directWinItem = plainRoll:match("^%s*%b[]%s*[Ll]oot:%s*(.-)%s+[Ww]on:%s*(.+)$")
        if not directWinName then
            directWinName, directWinItem = plainRoll:match("^%s*[Ll]oot:%s*(.-)%s+[Ww]on:%s*(.+)$")
        end
        if directWinName and directWinItem then
            directWinName = directWinName:gsub("^%s+", ""):gsub("%s+$", "")
            local itemLink = getItemLinkFromMessage(message)
            local display = itemLink and getItemLinkWithQualityColor(itemLink) or BuildRollDisplay(directWinItem, message)
            local nameOut = NameOut(directWinName)
            return spaceBeforeX(nameOut .. " " .. T("CHAT_WON_LABEL", "won:") .. " " .. display)
        end

        local afterLootPass = coreRoll:match("^[^:]-:%s*(.+)$") or coreRoll
        local passName, passItem = afterLootPass:match("^(.-)%s+passed on[:%s]+(.+)$")
        if passName and passItem then
            passName = passName:gsub("^%s+", ""):gsub("%s+$", "")
            if passName ~= "" and passName ~= "Loot" then
                local itemLink = getItemLinkFromMessage(message)
                local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(passItem))
                local nameOut = NameOut(passName)
                return spaceBeforeX(nameOut .. " passed: " .. display)
            end
        end

        local afterLoot = coreRoll:match("^[^:]-:%s*(.+)$") or coreRoll
        local selName, selType, selItem = afterLoot:match("^(.-)%s+has selected%s+(%S+)%s*:%s*(.+)$")
        if not selName then
            selName, selType, selItem = afterLoot:match("^(.-)%s+has selected%s+(%S+).-%s+for%s*:?%s*(.+)$")
        end
        if selName and selType and selItem then
            selName = selName:gsub("^%s+", ""):gsub("%s+$", "")
            local itemLink = getItemLinkFromMessage(message)
            local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(selItem))
            local nameOut = NameOut(selName)
            return spaceBeforeX(nameOut .. " " .. selType .. ": " .. display)
        end

        local youType, youItem = afterLoot:match("^[Yy]ou%s+have%s+selected%s+(%S+).-[Ff]or%s*: ?(.+)$")
        if not youType then
            youType, youItem = afterLoot:match("^[Yy]ou%s+have%s+selected%s+(%S+)%s+for%s+(.+)$")
        end
        if youType and youItem then
            local itemLink = getItemLinkFromMessage(message)
            local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(youItem))
            return spaceBeforeX(getClassColorForName(UnitName("player") or "You") .. You() .. "|r " .. youType .. ": " .. display)
        end

        local wonName, wonItem = afterLoot:match("^(.-)%s+[Ww]on:%s*(.+)$")
        if not wonName then wonName, wonItem = afterLoot:match("^(.-)%s+[Ww]on%s+(.+)$") end
        if not wonName then wonName, wonItem = coreRoll:match("^(.-)%s+[Ww]on:%s*(.+)$") end
        if not wonName then wonName, wonItem = coreRoll:match("^(.-)%s+[Ww]on%s+(.+)$") end
        if wonName and wonItem then
            wonName = wonName:gsub("^%s+", ""):gsub("%s+$", "")
            local itemLink = getItemLinkFromMessage(message)
            local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(wonItem))
            local nameOut = NameOut(wonName)
            return spaceBeforeX(nameOut .. " " .. T("CHAT_WON_LABEL", "won:") .. " " .. display)
        end

        local wonItem2, wonBy = coreRoll:match("^%s*[Ll]oot:%s*(.-)%s+won by%s+(.+)$")
        if wonItem2 and wonBy then
            wonBy = wonBy:gsub("^%s+", ""):gsub("%s+$", "")
            local itemLink = getItemLinkFromMessage(message)
            local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(wonItem2))
            local nameOut = NameOut(wonBy)
            return spaceBeforeX(nameOut .. " " .. T("CHAT_WON_LABEL", "won:") .. " " .. display)
        end

        local function RollTypeWord(literal)
            if not literal then return "Greed" end
            local lower = literal:lower()
            if lower:find("need") then return "Need" end
            if lower:find("greed") then return "Greed" end
            if lower:find("passed on") or lower:find("pass") then return "Pass" end
            if lower:find("disenchant") then return "Disenchant" end
            if lower:find(" won ") or lower:find(" wins ") then return "Won" end
            return "Greed"
        end

        local function TryRollEntry(entry)
            local name, itemPart = coreRoll:match(entry.pattern)
            if not name or name == "" then return nil end
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            if name:find("^Loot: ") then name = name:gsub("^Loot:%s*", ""):gsub("^%s+", ""):gsub("%s+$", "") end
            if name == "" or name == "Loot" then return nil end

            local display = BuildRollDisplay(itemPart, message)
            local isYou = name == "You" or name == playerName
            local displayName = isYou and "You" or name
            local shortName = name:gsub("%-.*$", "")
            local nameColor = getClassColorForName(displayName)
            local typeWord = RollTypeWord(entry.literal)
            local itemKey = Loot.GetRollItemKey(itemPart, message)

            if typeWord == "Pass" then
                return spaceBeforeX(nameColor .. displayName .. "|r " .. T("CHAT_PASSED_LABEL", "passed:") .. " " .. display)
            end
            if typeWord == "Won" then
                Loot.ClearRollItem(itemKey)
                return spaceBeforeX(nameColor .. displayName .. "|r " .. T("CHAT_WON_LABEL", "won:") .. " " .. display)
            end
            Loot.SetRollType(itemKey, shortName, typeWord)
            if isYou then Loot.SetRollType(itemKey, "You", typeWord) end
            if isYou then
                local youColor = getClassColorForName(UnitName("player") or "You")
                return spaceBeforeX(youColor .. You() .. "|r " .. T("CHAT_SELECTED_ROLL", "selected %s:", T("CHAT_ROLL_" .. typeWord:upper(), typeWord)) .. " " .. display)
            end
            if display and display ~= "" then
                return spaceBeforeX(nameColor .. displayName .. "|r " .. T("CHAT_SELECTED_ROLL", "selected %s:", T("CHAT_ROLL_" .. typeWord:upper(), typeWord)) .. " " .. display)
            end
            return true
        end

        for _, entry in ipairs(rollPatterns) do
            local result = TryRollEntry(entry)
            if result ~= nil then return result end
        end
        for _, entry in ipairs(rollPatternsFallback) do
            local result = TryRollEntry(entry)
            if result ~= nil then return result end
        end

        local rollName, rollNum, rollItemPart = coreRoll:match("^%s*(.-)%s+rolls?%s+(%d+)%s*:?%s*(.*)$")
        if rollName and rollNum and rollName ~= "" then
            rollName = rollName:gsub("^Loot:%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if rollName ~= "" and rollName ~= "Loot" then
                local itemKey = Loot.GetRollItemKey(rollItemPart, message)
                local isYouRoll = rollName == "You" or rollName == playerName
                local isSimpleRange = rollItemPart == nil or rollItemPart == "" or rollItemPart:match("^%(%d+%-%d+%)%s*$")
                if isSimpleRange then
                    local rangeText = rollItemPart and rollItemPart:match("%(%d+%-%d+%)") or "(1-100)"
                    local blue = "|cff33aaff"
                    if isYouRoll then
                        return spaceBeforeX(blue .. T("CHAT_YOU_ROLL", "You roll %s %s", rollNum, rangeText) .. "|r")
                    end
                    return spaceBeforeX(blue .. T("CHAT_PLAYER_ROLLS_RANGE", "%s rolls %s %s", rollName:gsub("%-.*$", ""), rollNum, rangeText) .. "|r")
                end

                local display = BuildRollDisplay(rollItemPart, message)
                if display and display ~= "" then
                    if isYouRoll then
                        return spaceBeforeX(getClassColorForName(UnitName("player") or "You") .. You() .. "|r " .. T("CHAT_ROLL_LABEL", "roll %s:", rollNum) .. " " .. display)
                    end
                    return spaceBeforeX(getClassColorForName(rollName) .. rollName .. "|r " .. T("CHAT_ROLLS_LABEL", "rolls %s:", rollNum) .. " " .. display)
                end
                local _ = Loot.GetRollType(itemKey, isYouRoll and "You" or rollName:gsub("%-.*$", ""))
            end
        end

        local nameAtEnd = coreRoll:match(" by ([^|%[%]]+)%s*$") or coreRoll:match(" [Ww]inner:?%s+([^|%[%]]+)%s*$")
        if nameAtEnd then
            nameAtEnd = cleanPunctuation(nameAtEnd:gsub("^%s+", ""):gsub("%s+$", "")):gsub("%-.*$", "")
            if nameAtEnd ~= "" then
                local isWinner = not not coreRoll:match(" [Ww]inner:?%s+[^|%[%]]+%s*$")
                local rollNum = coreRoll:match("(%d+)%s+for") or coreRoll:match("[--]%s*(%d+)%s*%.?%s*[Ww]inner") or coreRoll:match("[--]%s*(%d+)")
                local itemLink = getItemLinkFromMessage(message)
                local forPart = coreRoll:match(" for (.+) by ") or coreRoll:match(" for (.+)%.?%s*[Ww]inner") or ""
                local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(forPart))
                display = spaceBeforeX(display)
                local stackCount = message:match(" x(%d+)%s*(|r)?%s*$") or message:match(" x(%d+)%s* by ") or message:match(" x(%d+)%s*%.?%s*[Ww]inner")
                if stackCount then display = display .. " " .. colorPlus .. "(" .. stackCount .. ")|r" end
                if not itemLink then display = formatItemCountSuffix(display) end
                display = StripTrailingLoot(display)
                local itemKey = Loot.GetRollItemKey(forPart, message)
                local isYou = nameAtEnd == playerName or nameAtEnd == "You"
                local displayName = isYou and "You" or nameAtEnd
                local nameColor = getClassColorForName(displayName)
                if isWinner then
                    Loot.ClearRollItem(itemKey)
                    return spaceBeforeX(nameColor .. displayName .. "|r " .. T("CHAT_WON_LABEL", "won:") .. " " .. display)
                end
                if not rollNum or not display or display == "" then
                    return spaceBeforeX(message)
                end
                if isYou then
                    return spaceBeforeX(T("CHAT_YOU_ROLL_ITEM", "You roll %s:", rollNum) .. " " .. display)
                end
                return spaceBeforeX(nameColor .. displayName .. "|r " .. T("CHAT_ROLLS_LABEL", "rolls %s:", rollNum) .. " " .. display)
            end
        end

        return nil
    end

    return api
end
