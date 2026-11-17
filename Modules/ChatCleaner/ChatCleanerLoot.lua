--[[ Carpenter - ChatCleaner loot helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Utils = ns.Private.ChatCleanerUtils
local Palette = Utils.Palette
local PREFIX_PLUS = Utils.PREFIX_PLUS
local T = Utils.T
local CleanPunctuation, StripBrackets, SpaceBeforeX = Utils.CleanPunctuation, Utils.StripBrackets, Utils.SpaceBeforeX
local GetItemLinkFromMessage = Utils.GetItemLinkFromMessage
local GetItemLinkWithQualityColor = Utils.GetItemLinkWithQualityColor
local Loot = ns.Private.ChatCleanerLoot or {}
ns.Private.ChatCleanerLoot = Loot

local ROLL_TYPE_KEYS = {
    need = "CHAT_ROLL_NEED", greed = "CHAT_ROLL_GREED", disenchant = "CHAT_ROLL_DISENCHANT", pass = "CHAT_ROLL_PASS",
}

-- The roll type a "has selected Need for:" line names, in the player's
-- language; nil for any other word, as in "You have selected no favorite
-- mounts appropriate for this area."
function Loot.RollTypeLabel(word)
    local key = ROLL_TYPE_KEYS[word:lower()]
    return key and T(key)
end

-- Loot lines from your group, and the yells some addons send for them.
local GROUP_LOOT_EVENTS = {
    CHAT_MSG_LOOT = true, CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
}

-- Text that makes a "Loot: ..." line a roll result rather than an item.
-- Whole phrases, so items like "Scroll of Agility" or "Troll Charm" aren't
-- taken for rolls.
function Loot.IsRollPayload(text)
    if not text or type(text) ~= "string" then return false end
    local lower = text:lower()
    return lower:find("has selected", 1, true) or lower:find("have selected", 1, true) or
        lower:find("passed on", 1, true) or lower:find("%f[%a]won%f[%A]") or
        lower:find("%f[%a]rolls?%f[%A]") or lower:find("%f[%a]rolled%f[%A]") or false
end

local function AddFormatPattern(patterns, spec)
    local fmt = spec and _G[spec.global]
    if fmt and type(fmt) == "string" then
        local pattern, fields = Utils.MakeFormatPattern(fmt, spec.fields, { AnchorStart = true, AnchorEnd = true })
        if pattern then
            patterns[#patterns + 1] = { pattern = pattern, fields = fields, global = spec.global }
        end
    end
end

local function MatchFormatEntry(text, entry)
    if not text or not entry or not entry.pattern then return nil end

    local captures = { text:match(entry.pattern) }
    if #captures == 0 then return nil end

    local values = {}
    if entry.fields then
        for index, field in ipairs(entry.fields) do
            if field and captures[index] then
                values[field] = captures[index]
            end
        end
    end

    if not values.name then values.name = captures[1] end
    if not values.item then values.item = captures[2] or captures[1] end
    if not values.count then values.count = captures[3] end
    return values
end

local function PlainLootText(message)
    if not message or type(message) ~= "string" then return "" end
    return message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
end

local function MatchFallbackGroupLoot(text)
    local name, itemPart = text:match("^%s*(.-)%s+receives loot:%s*(.+)$")
    if name then return name, itemPart end
    name, itemPart = text:match("^%s*(.-)%s+receives item:%s*(.+)$")
    if name then return name, itemPart end
    name, itemPart = text:match("^%s*(.-)%s+creates:%s*(.+)$")
    if name then return name, itemPart end
    name, itemPart = text:match("^%s*(.-)%s+conjures:%s*(.+)$")
    if name then return name, itemPart end
    return nil, nil
end

function Loot.GetGroupLootPlayerName(message, groupLootPatterns, author)
    local plainLoot = PlainLootText(message)
    for _, entry in ipairs(groupLootPatterns or {}) do
        local values = MatchFormatEntry(plainLoot, entry)
        if values and values.name then
            return (values.name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", ""))
        end
    end

    local name = MatchFallbackGroupLoot(plainLoot)
    if name then
        name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
        if name ~= "" then return name end
    end

    if author and author ~= "" then
        local lowerPlain = plainLoot:lower()
        if lowerPlain:find("receives loot:") or lowerPlain:find("receives item:") or lowerPlain:find(" creates:") or lowerPlain:find(" conjures:") then
            return author:gsub("%-.*$", "")
        end
    end

    return nil
end

function Loot.BuildGroupLootPatterns()
    local patterns = {}
    -- Each _MULTIPLE first: the single form's "(.+)" would take "x5" too.
    local specs = {
        { global = "LOOT_ITEM_MULTIPLE", fields = { "name", "item", "count" } },
        { global = "LOOT_ITEM", fields = { "name", "item" } },
        { global = "LOOT_ITEM_PUSHED_MULTIPLE", fields = { "name", "item", "count" } },
        { global = "LOOT_ITEM_PUSHED", fields = { "name", "item" } },
        { global = "LOOT_ITEM_BONUS_ROLL_MULTIPLE", fields = { "name", "item", "count" } },
        { global = "LOOT_ITEM_BONUS_ROLL", fields = { "name", "item" } },
        { global = "CREATED_ITEM_MULTIPLE", fields = { "name", "item", "count" } },
        { global = "CREATED_ITEM", fields = { "name", "item" } },
    }

    for _, spec in ipairs(specs) do
        AddFormatPattern(patterns, spec)
    end

    return patterns
end

function Loot.BuildSelfLootPatterns()
    local patterns = {}
    -- Each _MULTIPLE first: the single form's "(.+)" would take "x5" too.
    local specs = {
        { global = "LOOT_ITEM_SELF_MULTIPLE", fields = { "item", "count" } },
        { global = "LOOT_ITEM_SELF", fields = { "item" } },
        { global = "LOOT_ITEM_PUSHED_SELF_MULTIPLE", fields = { "item", "count" } },
        { global = "LOOT_ITEM_PUSHED_SELF", fields = { "item" } },
        { global = "LOOT_ITEM_CREATED_SELF_MULTIPLE", fields = { "item", "count" } },
        { global = "LOOT_ITEM_CREATED_SELF", fields = { "item" } },
    }

    for _, spec in ipairs(specs) do
        AddFormatPattern(patterns, spec)
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
    -- The roll type comes from the global itself; other clients' wording
    -- has no English "need" or "won" to read it from.
    local rollTypes = {
        LOOT_ROLL_NEED = "Need",
        LOOT_ROLL_GREED = "Greed",
        LOOT_ROLL_DISENCHANT = "Disenchant",
        LOOT_ROLL_WON = "Won",
    }

    for _, globalName in ipairs(globals) do
        local fmt = _G[globalName]
        if fmt and type(fmt) == "string" and not fmt:find("|H") then
            local pattern = Utils.MakeFormatPattern(fmt)
            if pattern then
                patterns[#patterns + 1] = { pattern = pattern, rollType = rollTypes[globalName] }
            end
        end
    end

    return patterns
end

function Loot.Create(config)
    config = config or {}
    local selfLootPatterns = Loot.BuildSelfLootPatterns()
    local groupLootPatterns = Loot.BuildGroupLootPatterns()
    local rollPatterns = Loot.BuildRollPatterns()
    -- Rollers' class colors, where the caller can tell them.
    local getPlayerNameColor = config.GetPlayerNameColor or function() return nil end

    local function You()
        return T("CHAT_YOU")
    end

    local api = {}

    local function StyleBareLootDisplay(display)
        if not display or display == "" or display:find("|Hitem:", 1, true) then return display end
        return Palette.green .. display .. "|r"
    end

    local function CleanRollActionText(text)
        if not text or text == "" then return "" end
        return (text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*:%s*$", ""))
    end

    local function StripTrailingLoot(display)
        if not display or type(display) ~= "string" then return display end
        return display:gsub("%s+[Ll]oot%s*$", ""):gsub("|r%s*$", "|r")
    end

    local function ItemWithCount(item, count)
        if not item or item == "" or not count or count == "" then return item end
        return item .. " x" .. count
    end

    local function BuildDisplayFromMessage(message)
        local itemLink = GetItemLinkFromMessage(message)
        if itemLink then
            local display = GetItemLinkWithQualityColor(itemLink)
            display = SpaceBeforeX(display)
            local stackCount = message:match(" x(%d+)%s*%.?%s*$") or message:match("x(%d+)%s*%.?%s*$")
            if stackCount then
                display = display .. " " .. Palette.gray .. "(" .. stackCount .. ")|r"
            end
            return display
        end
        return nil
    end

    -- The item a roll line names: its link in quality color, else its name.
    local function RollItemDisplay(message, rawItem)
        local itemLink = GetItemLinkFromMessage(message)
        return itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(rawItem))
    end

    local function BuildRollDisplay(itemPart, fromMsg)
        local itemLink = GetItemLinkFromMessage(fromMsg or "")
        local display
        if itemLink then
            display = GetItemLinkWithQualityColor(itemLink)
            display = SpaceBeforeX(display)
            local unclosed = (fromMsg or ""):gsub("|r", "")
            local stackCount = unclosed:match(" x(%d+)%s*$") or unclosed:match(" x(%d+)%s* by ")
            if stackCount then
                display = display .. " " .. Palette.gray .. "(" .. stackCount .. ")|r"
            end
        else
            display = CleanPunctuation(StripBrackets(itemPart or ""))
            display = SpaceBeforeX(display)
            display = Utils.FormatItemCountSuffix(display)
        end
        return StripTrailingLoot(display)
    end

    function api.FormatSelfLootMessage(event, message)
        local item
        for _, entry in ipairs(selfLootPatterns) do
            local values = MatchFormatEntry(message, entry)
            if values and values.item then
                item = ItemWithCount(values.item, values.count)
                break
            end
        end

        item = item or message:match("You receive loot: (.+)") or message:match("You create: (.+)") or
            message:match("You receive item: (.+)") or message:match("You receive items: (.+)") or
            message:match("You received item: (.+)") or message:match("You received items: (.+)")
        if not item then
            local lootPayload = message:match("^%s*[Ll]oot:%s*(.+)$")
            if lootPayload and not Loot.IsRollPayload(lootPayload) then
                local display = Utils.FormatReceivedDisplay(lootPayload, message)
                local lootLabelColor = Utils.LootLineColor(event)
                if display then return lootLabelColor .. "Loot|r " .. PREFIX_PLUS .. StyleBareLootDisplay(display) end
            end
        end
        if item then
            local display = Utils.FormatReceivedDisplay(item, message)
            if display then return PREFIX_PLUS .. display end
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

            if receivePayload and not Utils.ShouldSkipGenericReceive(message) then
                local display = Utils.FormatReceivedDisplay(receivePayload, message)
                if display then return PREFIX_PLUS .. display end
            end
        end

        return nil
    end

    function api.FormatGroupLootMessage(event, message, author)
        if not GROUP_LOOT_EVENTS[event] then return nil end

        local nameColor = Utils.LootLineColor(event)
        local function StyleGroupLoot(name, display)
            if not name or name == "" or name == "You" then return nil end
            return SpaceBeforeX(nameColor .. name .. " " .. Palette.gray .. "+|r " .. display)
        end
        local plainLoot = PlainLootText(message)
        local lowerPlain = plainLoot:lower()
        for _, entry in ipairs(groupLootPatterns) do
            local values = MatchFormatEntry(plainLoot, entry)
            if values and values.name then
                local name = values.name
                local itemPart = ItemWithCount(values.item, values.count)
                name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
                local display = BuildDisplayFromMessage(message)
                if not display then
                    display = CleanPunctuation(StripBrackets(itemPart or ""))
                    display = SpaceBeforeX(display)
                    display = Utils.FormatItemCountSuffix(display)
                end
                local out = StyleGroupLoot(name, display)
                if out then return out end
            end
        end

        local name, itemPart = MatchFallbackGroupLoot(plainLoot)
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
                display = CleanPunctuation(StripBrackets(itemPart:gsub("|H.-|h(.-)|h", "%1")))
                display = SpaceBeforeX(display)
                display = Utils.FormatItemCountSuffix(display)
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
        local function CleanRollName(name)
            if not name or type(name) ~= "string" then return "" end
            return name:gsub("^%s+", "")
                :gsub("%s+$", "")
                :gsub("^%s*[Ll]oot:%s*", "")
                :gsub("^%s*[:;]+%s*", "")
                :gsub("%-.*$", "")
                :gsub("^%s+", "")
                :gsub("%s+$", "")
        end
        local rollPrefixColor = Utils.LootLineColor(event)
        -- Rollers take their class color where GetPlayerNameColor gives one
        -- (outside a group); else the roll line's color.
        local function NameOut(name)
            name = CleanRollName(name)
            if name:lower() == "you" then
                return rollPrefixColor .. You() .. "|r"
            end
            return (getPlayerNameColor(name) or rollPrefixColor) .. name .. "|r"
        end
        local function RollLiteral(text)
            text = CleanRollActionText(text)
            if not text or text == "" then return "" end
            return rollPrefixColor .. text .. "|r"
        end
        local function RollLine(name, actionText, display)
            local nameOut = NameOut(name)
            local line = nameOut
            if actionText and actionText ~= "" then
                line = line .. " " .. RollLiteral(actionText)
            end
            if display and display ~= "" then
                line = line .. " " .. display
            end
            return SpaceBeforeX(line)
        end
        local function RollLineWithLocalizedName(name, localizedText)
            localizedText = localizedText or ""
            local nameOut = NameOut(name)
            local displayName = (name and name:gsub("%-.*$", "")) or ""
            if displayName:lower() == "you" then displayName = You() end

            if displayName ~= "" and localizedText:sub(1, #displayName) == displayName then
                local rest = localizedText:sub(#displayName + 1):gsub("^%s+", "")
                return SpaceBeforeX(nameOut .. " " .. RollLiteral(rest))
            end
            return SpaceBeforeX(nameOut .. " " .. RollLiteral(localizedText))
        end
        local youType, youItem = plainRoll:match("[Yy]ou%s+have%s+selected%s+(%S+).-[Ff]or%s*:?%s*(.+)$")
        local youRoll = youType and Loot.RollTypeLabel(youType)
        if youRoll then
            return RollLine("You", youRoll, RollItemDisplay(message, youItem))
        end

        local directWinName, directWinItem = plainRoll:match("^%s*%b[]%s*[Ll]oot:%s*(.-)%s+[Ww]on:%s*(.+)$")
        if not directWinName then
            directWinName, directWinItem = plainRoll:match("^%s*[Ll]oot:%s*(.-)%s+[Ww]on:%s*(.+)$")
        end
        if directWinName and directWinItem then
            directWinName = CleanRollName(directWinName)
            local itemLink = GetItemLinkFromMessage(message)
            local display = itemLink and GetItemLinkWithQualityColor(itemLink) or BuildRollDisplay(directWinItem, message)
            return RollLine(directWinName, T("CHAT_WON_LABEL"), display)
        end

        local afterLoot = coreRoll:match("^%s*[Ll]oot:%s*(.+)$") or coreRoll
        local passName, passItem = afterLoot:match("^(.-)%s+passed on[:%s]+(.+)$")
        if passName and passItem then
            passName = CleanRollName(passName)
            if passName ~= "" and passName ~= "Loot" then
                return RollLine(passName, T("CHAT_PASSED_LABEL"), RollItemDisplay(message, passItem))
            end
        end

        local selName, selType, selItem = afterLoot:match("^(.-)%s+has selected%s+(%S+)%s*:%s*(.+)$")
        if not selName then
            selName, selType, selItem = afterLoot:match("^(.-)%s+has selected%s+(%S+).-%s+for%s*:?%s*(.+)$")
        end
        local selRoll = selType and Loot.RollTypeLabel(selType)
        if selRoll then
            return RollLine(CleanRollName(selName), selRoll, RollItemDisplay(message, selItem))
        end

        local wonName, wonItem = afterLoot:match("^(.-)%s+[Ww]on:%s*(.+)$")
        if not wonName then wonName, wonItem = afterLoot:match("^(.-)%s+[Ww]on%s+(.+)$") end
        if not wonName then wonName, wonItem = coreRoll:match("^(.-)%s+[Ww]on:%s*(.+)$") end
        if not wonName then wonName, wonItem = coreRoll:match("^(.-)%s+[Ww]on%s+(.+)$") end
        if wonName and wonItem then
            return RollLine(CleanRollName(wonName), T("CHAT_WON_LABEL"), RollItemDisplay(message, wonItem))
        end

        local wonItem2, wonBy = coreRoll:match("^%s*[Ll]oot:%s*(.-)%s+won by%s+(.+)$")
        if wonItem2 and wonBy then
            return RollLine(CleanRollName(wonBy), T("CHAT_WON_LABEL"), RollItemDisplay(message, wonItem2))
        end

        -- Other clients' roll lines, from the game's own LOOT_ROLL_* strings;
        -- the roll type comes with the string.
        for _, entry in ipairs(rollPatterns) do
            local name, itemPart = coreRoll:match(entry.pattern)
            name = CleanRollName(name)
            if name ~= "" and name ~= "Loot" then
                local display = BuildRollDisplay(itemPart, message)
                local displayName = (name == "You" or name == playerName) and "You" or name
                if entry.rollType == "Won" then
                    return RollLine(displayName, T("CHAT_WON_LABEL"), display)
                end
                if not display or display == "" then return true end
                return RollLine(displayName, Loot.RollTypeLabel(entry.rollType), display)
            end
        end

        local rollName, rollNum, rollItemPart = coreRoll:match("^%s*(.-)%s+rolls?%s+(%d+)%s*:?%s*(.*)$")
        if rollName and rollNum and rollName ~= "" then
            rollName = CleanRollName(rollName)
            if rollName ~= "" and rollName ~= "Loot" then
                local isYouRoll = rollName == "You" or rollName == playerName
                local isSimpleRange = rollItemPart == nil or rollItemPart == "" or rollItemPart:match("^%(%d+%-%d+%)%s*$")
                if isSimpleRange then
                    local rangeText = rollItemPart and rollItemPart:match("%(%d+%-%d+%)") or "(1-100)"
                    local displayName = isYouRoll and "You" or rollName:gsub("%-.*$", "")
                    if isYouRoll then
                        return RollLineWithLocalizedName(displayName, T("CHAT_YOU_ROLL", rollNum, rangeText))
                    end
                    return RollLineWithLocalizedName(displayName, T("CHAT_PLAYER_ROLLS_RANGE", displayName, rollNum, rangeText))
                end

                local display = BuildRollDisplay(rollItemPart, message)
                if display and display ~= "" then
                    if isYouRoll then
                        return RollLine("You", T("CHAT_ROLL_LABEL", rollNum), display)
                    end
                    return RollLine(rollName, T("CHAT_ROLLS_LABEL", rollNum), display)
                end
            end
        end

        local nameAtEnd = coreRoll:match(" by ([^|%[%]]+)%s*$") or coreRoll:match(" [Ww]inner:?%s+([^|%[%]]+)%s*$")
        if nameAtEnd then
            nameAtEnd = CleanPunctuation(nameAtEnd:gsub("^%s+", ""):gsub("%s+$", "")):gsub("%-.*$", "")
            if nameAtEnd ~= "" then
                local isWinner = not not coreRoll:match(" [Ww]inner:?%s+[^|%[%]]+%s*$")
                local rollNum = coreRoll:match("(%d+)%s+for") or coreRoll:match("[--]%s*(%d+)%s*%.?%s*[Ww]inner") or coreRoll:match("[--]%s*(%d+)")
                local itemLink = GetItemLinkFromMessage(message)
                local forPart = coreRoll:match(" for (.+) by ") or coreRoll:match(" for (.+)%.?%s*[Ww]inner") or ""
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(forPart))
                display = SpaceBeforeX(display)
                local unclosed = message:gsub("|r", "")
                local stackCount = unclosed:match(" x(%d+)%s*$") or unclosed:match(" x(%d+)%s* by ") or unclosed:match(" x(%d+)%s*%.?%s*[Ww]inner")
                if stackCount then display = display .. " " .. Palette.gray .. "(" .. stackCount .. ")|r" end
                if not itemLink then display = Utils.FormatItemCountSuffix(display) end
                display = StripTrailingLoot(display)
                local isYou = nameAtEnd == playerName or nameAtEnd == "You"
                local displayName = isYou and "You" or nameAtEnd
                if isWinner then
                    return RollLine(displayName, T("CHAT_WON_LABEL"), display)
                end
                if not rollNum or not display or display == "" then
                    return nil
                end
                if isYou then
                    return RollLine("You", T("CHAT_ROLL_LABEL", rollNum), display)
                end
                return RollLine(displayName, T("CHAT_ROLLS_LABEL", rollNum), display)
            end
        end

        return nil
    end

    return api
end
