--[[ Carpenter - ChatCleaner ]]
local _, ns = ...
local f = CreateFrame("Frame")

-- Shared Carpenter color palette
local Colors = ns and ns.Private and ns.Private.Colors

-- Muted tones: light grey chrome; soft off-whites and subtle tints so chat isn’t flat or harsh
-- Goldpaw ChatCleaner-style (github.com/GoldpawsStuff/ChatCleaner): gray +/-, offwhite names, white amounts, yellow quest, green cleared, palered losses
local ColorGray       = Colors and Colors.gray and Colors.gray.colorCode or "|cffc8c8c8"
local ColorPlus       = ColorGray
local ColorMinus      = ColorGray
local ColorLootLiteral= ColorGray

local ColorOffwhite   = Colors and Colors.offwhite and Colors.offwhite.colorCode or "|cfff0f0f0"
local ColorWhite      = Colors and Colors.white and Colors.white.colorCode or "|cffffffff"
local ColorYellow     = "|cffffd200"
local ColorGreen      = Colors and Colors.green and Colors.green.colorCode or "|cff00ff00"
local ColorOrange     = Colors and Colors.quest and Colors.quest.orange and Colors.quest.orange.colorCode or "|cffff8000"
local ColorDarkorange = Colors and Colors.quest and Colors.quest.red and Colors.quest.red.colorCode or "|cffff6600"
local ColorPalered    = Colors and Colors.palered and Colors.palered.colorCode or "|cffcc8080"
local ColorRed        = Colors and Colors.red and Colors.red.colorCode or "|cffff4040"

-- Accent colors
local ColorPurple     = Colors and Colors.xpValue and Colors.xpValue.colorCode or "|cffb794f4"         -- Skill / spell names
local ColorBluePurple = Colors and Colors.faction and Colors.faction.Alliance and Colors.faction.Alliance.colorCode or "|cff9d8cff" -- Reputation faction
local ColorTeal       = Colors and Colors.power and Colors.power.ESSENCE and Colors.power.ESSENCE.colorCode or "|cff00ccaa"        -- Discovery zone
local ColorQueue      = Colors and Colors.zone and Colors.zone.sanctuary and Colors.zone.sanctuary.colorCode or "|cff80b0ff"       -- BG / queue name
local ColorCyan       = Colors and Colors.power and Colors.power.MANA and Colors.power.MANA.colorCode or "|cff00ccff"              -- Generic rewards
local ColorHonor      = Colors and Colors.red and Colors.red.colorCode or "|cffff4040"
local ColorAuctionExpired = ColorRed
local ColorSold           = ColorGray
local ColorAuctionHouse   = "|cffffb347"   -- Amber for buyer found, auction created
local ColorRepair         = ColorGray

-- Same tones as shared XP colors
local ColorRestedBar = Colors and Colors.restedValue and Colors.restedValue.colorCode or "|cff3399ff"
local ColorNormalBar = Colors and Colors.xpValue and Colors.xpValue.colorCode or "|cff9940ff"

-- Money Icons
local GoldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

local function FormatMoney(amount, amountColor)
    amountColor = amountColor or ColorWhite
    local gold = floor(amount / 10000)
    local silver = floor((amount % 10000) / 100)
    local copper = amount % 100
    local str = ""
    if gold > 0 then
        str = str .. amountColor .. gold .. "|r " .. GoldIcon .. " "
    end
    if silver > 0 or gold > 0 then
        str = str .. amountColor .. silver .. "|r " .. silverIcon .. " "
    end
    str = str .. amountColor .. copper .. "|r " .. copperIcon
    return str
end

local function ParseRetailMoneyGain(message)
    if not message or type(message) ~= "string" then return nil end

    local text = message
        :gsub("|T.-UI%-GoldIcon.-|t", " gold")
        :gsub("|T.-UI%-SilverIcon.-|t", " silver")
        :gsub("|T.-UI%-CopperIcon.-|t", " copper")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")

    local body = text:match("^You gained:%s*(.-)%s*%.?$")
    if not body or body == "" then return nil end

    local gold = tonumber(body:match("(%d+)%s*[Gg]old") or body:match("(%d+)%s*g")) or 0
    local silver = tonumber(body:match("(%d+)%s*[Ss]ilver") or body:match("(%d+)%s*s")) or 0
    local copper = tonumber(body:match("(%d+)%s*[Cc]opper") or body:match("(%d+)%s*c")) or 0

    if gold > 0 or silver > 0 or copper > 0 then
        return gold * 10000 + silver * 100 + copper
    end

    local numbers = {}
    for value in body:gmatch("(%d+)") do
        numbers[#numbers + 1] = tonumber(value) or 0
    end
    if #numbers == 3 then
        return (numbers[1] * 10000) + (numbers[2] * 100) + numbers[3]
    elseif #numbers == 2 then
        return (numbers[1] * 100) + numbers[2]
    elseif #numbers == 1 then
        return numbers[1]
    end

    return nil
end

local LINK_OPEN  = "\255\255CP_L\255\255"
local LINK_CLOSE = "\255\255CP_R\255\255"

local function StripBrackets(text)
    if not text or type(text) ~= "string" then return text end
    -- Preserve brackets inside WoW links (|H...|h[text]|h) so quest/item links still work
    text = text:gsub("|h%[", "|h" .. LINK_OPEN)
    text = text:gsub("%]|h", LINK_CLOSE .. "|h")
    text = text:gsub("%[", ""):gsub("%]", "")
    text = text:gsub(LINK_OPEN, "["):gsub(LINK_CLOSE, "]")
    return text
end

local function CleanPunctuation(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub("%.+$", "")
end

local function SpaceBeforeX(s)
    if not s or type(s) ~= "string" then return s end
    return s:gsub("(|r)x(%d+)", "%1 x%2"):gsub("([^%s])x(%d+)", "%1 x%2")
end

local function FormatCurrencyGain(amount, currency)
    amount = amount and tostring(amount)
    currency = currency and tostring(currency)
    if not amount or amount == "" or not currency or currency == "" then return nil end

    currency = CleanPunctuation(currency:gsub("^%s+", ""):gsub("%s+$", ""))
    local leadingAmount, leadingName = currency:match("^x?(%d+)%s*(%D.+)$")
    if leadingAmount and leadingName then
        amount = leadingAmount
        currency = leadingName:gsub("^%s+", ""):gsub("%s+$", "")
    end

    local trailingName, trailingAmount = currency:match("^(.-)%s*x(%d+)$")
    if trailingName and trailingAmount then
        amount = trailingAmount
        currency = trailingName:gsub("^%s+", ""):gsub("%s+$", "")
    end

    return (ColorPlus .. "+|r ") .. ColorCyan .. currency .. "|r " .. ColorWhite .. "x" .. amount .. "|r"
end

-- Return item link with quality color (Goldpaw-style: GetItemInfo colored link; fallback ITEM_QUALITY_COLORS)
local function GetItemLinkWithQualityColor(itemLink)
    if not itemLink or not itemLink:find("|Hitem:") then return itemLink end
    local name, link, quality = GetItemInfo(itemLink)
    if link and link ~= "" then
        return link
    end
    -- Fallback: get quality by item ID when link not cached (e.g. just looted)
    local itemId = itemLink:match("|Hitem:(%d+):")
    if itemId then
        name, link, quality = GetItemInfo(tonumber(itemId))
        if link and link ~= "" then return link end
    end
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        local r = math.floor((c.r or 1) * 255)
        local g = math.floor((c.g or 1) * 255)
        local b = math.floor((c.b or 1) * 255)
        local hex = string.format("|cff%02x%02x%02x", r, g, b)
        return hex .. itemLink .. "|r"
    end
    return itemLink
end

-- Blizzard party/raid message color (for system messages like "X joins", "Group leader")
local function GetPartyOrRaidMessageColor()
    local info = ChatTypeInfo["RAID"] or ChatTypeInfo["PARTY"]
    if not info then
        return ColorOffwhite
    end
    if IsInRaid() then
        info = ChatTypeInfo["RAID"]
    else
        info = ChatTypeInfo["PARTY"]
    end
    if not info or not info.r then
        return ColorOffwhite
    end
    local r = math.floor((info.r or 1) * 255)
    local g = math.floor((info.g or 1) * 255)
    local b = math.floor((info.b or 1) * 255)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

-- Get first player link from message (|Hplayer:Name|h[Name]|h or |Hplayer:Name|hName|h) so we can preserve it for class coloring
local function GetFirstPlayerLink(text)
    if not text or type(text) ~= "string" then return nil end
    return text:match("(|Hplayer:[^|]+|h%[[^%]]*%]|h)") or text:match("(|Hplayer:[^|]+|h[^|]*|h)")
end

-- Cache inviter/joiner name -> class color (when "Name joins" we learn their class; use for "Name invited you" next time)
local playerNameToClassColor = {}

-- Return |cffRRGGBB class color for a player name (if in party/raid), else white
local function GetClassColorForName(playerName)
    if not playerName or playerName == "" then return ColorOffwhite end
    -- Strip server/realm suffix (e.g. "Name-ServerName") so we match UnitName() which returns "Name"
    local shortName = playerName:gsub("%-[^%-]+$", "")
    if shortName == "" then shortName = playerName end

    if RAID_CLASS_COLORS then
        -- Special-case the local player so we always get their class color,
        -- even when not present in party/raid unit lists.
        local myName = UnitName("player")
        if myName and (shortName == myName or playerName == myName) then
            local _, myClass = UnitClass("player")
            local c = myClass and RAID_CLASS_COLORS[myClass]
            if c then
                local r, g, b = math.floor((c.r or 1) * 255), math.floor((c.g or 1) * 255), math.floor((c.b or 1) * 255)
                return string.format("|cff%02x%02x%02x", r, g, b)
            end
        end

        local numGroup = GetNumGroupMembers and GetNumGroupMembers() or 0
        local prefix, count = "party", (numGroup > 0 and numGroup) or 0
        if count == 0 and IsInRaid() then
            count = GetNumGroupMembers and GetNumGroupMembers() or 0
            prefix = "raid"
        end
        for i = 1, count do
            local unit = prefix .. i
            local name = UnitName(unit)
            if name and (name == shortName or name == playerName or name:find(shortName) or shortName:find(name)) then
                local _, class = UnitClass(unit)
                if class and RAID_CLASS_COLORS[class] then
                    local c = RAID_CLASS_COLORS[class]
                    local r, g, b = math.floor((c.r or 1) * 255), math.floor((c.g or 1) * 255), math.floor((c.b or 1) * 255)
                    return string.format("|cff%02x%02x%02x", r, g, b)
                end
                break
            end
        end
    end
    return ColorOffwhite
end

-- Replace player link colors with class color so every player name in chat uses their class color
local function ClassColorPlayerNames(text)
    if not text or type(text) ~= "string" then return text end
    -- Match optional existing color + player link (|Hplayer:Name or Name:ID|h...|h); :ID is optional
    return text:gsub("(|c%x%x%x%x%x%x%x%x)?(|Hplayer:([^:|]+)(:[^|]*)?|h.-|h)", function(_, link, pname)
        return GetClassColorForName(pname) .. link
    end)
end

-- Apply class color to player names in loot roll messages; strip "Loot: ", " for:" -> ": ", strip trailing " Loot"
local function ClassColorLootRollNames(text)
    if not text or type(text) ~= "string" then return text end
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
    local trim = function(s) return (s and s:gsub("^%s+", ""):gsub("%s+$", "") or "") end
    local lower = plain:lower()
    local isLootRoll = lower:find("has selected") or lower:find("passed on") or lower:find(" won ") or lower:find(" wins ") or
        plain:find(" by .+%s*$") or lower:find("won by ") or lower:find("winner:") or
        lower:find("receives loot") or lower:find("receives item") or lower:find(" creates:") or lower:find(" rolls ") or lower:find(" roll ")
    if not isLootRoll then return text end
    -- Strip "Loot: " from group roll messages (at start, after [P]/[R], or after ]|r); " has selected X for: " -> " has selected X: "; strip trailing " Loot"
    text = text:gsub("^%s*[Ll]oot%s*:?%s*", "")
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)[Ll]oot%s*:?%s*", "%1")  -- "|cff00ff00Loot: Name" -> "|cff00ff00Name"
    text = text:gsub("(%])%s*[Ll]oot%s*:?%s*", "%1 ")       -- "[P] Loot: Name" -> "[P] Name"
    text = text:gsub("(%])|r%s*[Ll]oot%s*:?%s*", "%1|r ")  -- "[P]|r Loot: Name" -> "[P]|r Name"
    text = text:gsub("(|r)%s*[Ll]oot%s*:?%s*", "%1 ")      -- "|r Loot: Name" (e.g. after channel) -> "|r Name"
    text = text:gsub("(%s+has selected %w+)%s+for%s*:%s*", "%1: ")
    text = text:gsub("%s+[Ll]oot%s*$", "")
    -- Style item count: " x2" -> " (2)"
    text = text:gsub(" x(%d+)(|r)?%s*$", function(count, r)
        return " " .. ColorPlus .. "(" .. count .. ")|r" .. (r or "")
    end)
    -- Roll result: "... by Name" / "Winner: Name" -> class color name at end
    local nameAtEnd = plain:match(" by ([^|%[%]]+)%s*$") or plain:match(" won by ([^|%[%]]+)%s*$") or plain:match(" [Ww]inner:?%s+([^|%[%]]+)%s*$")
    if nameAtEnd then
        nameAtEnd = trim(nameAtEnd):gsub("%-.*$", "")
        if nameAtEnd ~= "" then
            local didReplace
            text = text:gsub(" by ([^|%[%]]+)%s*(|r)?%s*$", function(n, r)
                didReplace = true
                return " by " .. GetClassColorForName(trim(n):gsub("%-.*$", "")) .. trim(n):gsub("%-.*$", "") .. "|r" .. (r or "")
            end, 1)
            if not didReplace then
                text = text:gsub(" ([Ww]inner:?%s+)([^|%[%]]+)%s*(|r)?%s*$", function(label, n, r)
                    didReplace = true
                    return " " .. label .. GetClassColorForName(trim(n):gsub("%-.*$", "")) .. trim(n):gsub("%-.*$", "") .. "|r" .. (r or "")
                end, 1)
            end
            if didReplace then return text end
        end
    end
    -- "Name receives loot:" / "Name creates:" etc. (group loot) - class color name only
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives loot:%s*)(.-)$", function(prefix, n, literal, tail)
        n = trim(n):gsub("%-.*$", "")
        if n ~= "" and n ~= "You" and n ~= "Loot" then
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r" .. literal .. tail
        end
        return (prefix or "") .. n .. literal .. tail
    end, 1)
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives item:%s*)(.-)$", function(prefix, n, literal, tail)
        n = trim(n):gsub("%-.*$", "")
        if n ~= "" and n ~= "You" and n ~= "Loot" then
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r" .. literal .. tail
        end
        return (prefix or "") .. n .. literal .. tail
    end, 1)
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+creates:%s*)(.-)$", function(prefix, n, literal, tail)
        n = trim(n):gsub("%-.*$", "")
        if n ~= "" and n ~= "You" and n ~= "Loot" then
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r" .. literal .. tail
        end
        return (prefix or "") .. n .. literal .. tail
    end, 1)
    -- "Name has selected Greed: Item" -> "Name Greed: Item" (Loot: already stripped)
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+has selected %w+%s*:?%s*)(.-)$", function(prefix, n, rest, tail)
        n = trim(n):gsub("%-.*$", "")
        local typeWord = rest:match("(%w+)%s*:?%s*$")  -- Need, Greed, Disenchant
        if n ~= "" and n ~= "Loot" and typeWord then
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r " .. typeWord .. ": " .. trim(tail)
        end
        return (prefix or "") .. n .. rest .. tail
    end, 1)
    -- "Loot: Name passed on: Item" / "Name passed on Item" -> "Name passed: Item"
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)%s+passed on[:%s]+(.-)$", function(prefix, n, tail)
        n = trim(n):gsub("%-.*$", "")
        local itemPart = trim(tail)
        if n ~= "" and n ~= "Loot" then
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r passed: " .. itemPart
        end
        return (prefix or "") .. n .. " passed: " .. itemPart
    end, 1)
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+won%s+)(.-)$", function(prefix, n, rest, tail)
        n = trim(n):gsub("%-.*$", "")
        if n ~= "" and n ~= "Loot" then
            -- Normalize " won " + ": Item" -> " won: Item"
            local itemPart = tail:gsub("^%s*:?%s*", "")
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r won: " .. itemPart
        end
        return (prefix or "") .. n .. rest .. tail
    end, 1)
    text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+wins%s+)(.-)$", function(prefix, n, rest, tail)
        n = trim(n):gsub("%-.*$", "")
        if n ~= "" and n ~= "Loot" then
            return (prefix or "") .. GetClassColorForName(n) .. n .. "|r" .. rest .. tail
        end
        return (prefix or "") .. n .. rest .. tail
    end, 1)
    -- "You have selected ..." / "You won ..." -> color You
    local youColor = GetClassColorForName(UnitName("player") or "You")
    text = text:gsub("^(You)(%s+have selected )", youColor .. "%1|r%2", 1)
    text = text:gsub("^(You)(%s+won%s+)", youColor .. "%1|r%2", 1)
    text = text:gsub("^(You)(%s+rolls?%s+)", youColor .. "%1|r%2", 1)
    return text
end

-- Convert trailing "x2" style counts into " (2)" to match cleaner loot style
local function FormatItemCountSuffix(text)
    if not text or type(text) ~= "string" then return text end
    local base, count = text:match("^(.-)%sx(%d+)$")
    if base and count then
        -- Wrap entire count including parentheses in light grey to override any item quality color
        return base .. " " .. ColorPlus .. "(" .. count .. ")|r"
    end
    return text
end

-- =========================
-- Channel & Prefix Styling (General/Trade/Group)
-- =========================

local channelReplacements = {}

local function AddBracketReplacement(globalName, short)
    local tag = _G[globalName]
    if not tag or type(tag) ~= "string" then return end
    local label = tag:match("%[(.-)%]")
    if not label or label == "" then return end
    -- Escape magic chars in label for gsub pattern
    label = label:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local pattern = "%[" .. label .. "%]"
    local replacement = "[" .. short .. "]"
    table.insert(channelReplacements, { pattern, replacement })
end

AddBracketReplacement("CHAT_PARTY_LEADER_GET", "PL")
AddBracketReplacement("CHAT_PARTY_GET", "P")
AddBracketReplacement("CHAT_RAID_LEADER_GET", "RL")
AddBracketReplacement("CHAT_RAID_GET", "R")
AddBracketReplacement("CHAT_INSTANCE_CHAT_LEADER_GET", "IL")
AddBracketReplacement("CHAT_INSTANCE_CHAT_GET", "I")
AddBracketReplacement("CHAT_GUILD_GET", "G")
AddBracketReplacement("CHAT_OFFICER_GET", "O")

do
    local rwTag = _G.CHAT_RAID_WARNING_GET
    if rwTag and type(rwTag) == "string" then
        local label = rwTag:match("%[(.-)%]")
        if label and label ~= "" then
            label = label:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            local pattern = "%[" .. label .. "%]"
            local replacement = "|cffff0000!|r"
            table.insert(channelReplacements, { pattern, replacement })
        end
    end
end

local function ApplyChannelStyling(text)
    if not text or type(text) ~= "string" then return text end

    -- Compact group/channel prefixes like [Party], [Raid], [Guild], etc.
    for _, entry in ipairs(channelReplacements) do
        text = text:gsub(entry[1], entry[2])
    end

    -- Shorten numbered channels:
    -- "[1. General - Stormwind]" -> "1."
    text = text:gsub("|Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%s%-%s.-%]|h", "|Hchannel:%1:%2|h%3.|h")
    text = text:gsub("|Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%]|h", "|Hchannel:%1:%2|h%3.|h")

    -- Compact "Changed Channel" notice:
    -- "Changed Channel: [1. General]" -> "1. General"
    text = text:gsub("^Changed Channel: |Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%]|h", "|Hchannel:%1:%2|h%3. %4|h")

    return text
end

-- Remove visual brackets around link text while keeping links clickable.
-- Examples:
--   "|Hitem:123|h[Icefin Bluefish]|h" -> "|Hitem:123|hIcefin Bluefish|h"
--   "|Hplayer:Name|h[Name]|h"         -> "|Hplayer:Name|hName|h"
local function RemoveLinkBrackets(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub("(|H.-|h)%[(.-)%]|h", "%1%2|h")
end

-- Get first item link from text; works both with brackets |Hitem:...|h[Name]|h and without (after RemoveLinkBrackets).
local function GetItemLinkFromMessage(text)
    if not text or type(text) ~= "string" then return nil end
    return text:match("(|Hitem:[^|]+|h%[[^%]]*%]|h)") or text:match("(|Hitem:[^|]+|h[^|]*|h)")
end

local function ShouldSkipGenericReceive(text)
    if not text or type(text) ~= "string" then return true end

    local lower = text:lower()
    return lower:find("currency:") or
        lower:find(" reputation") or
        lower:find("experience") or
        lower:find(" honor") or
        lower:find(" gold") or
        lower:find(" silver") or
        lower:find(" copper") or
        lower:find("your share") or
        lower:find(" share")
end

local function FormatReceivedDisplay(rawDisplay, sourceMessage)
    if not rawDisplay or rawDisplay == "" then return nil end

    local itemLink = GetItemLinkFromMessage(sourceMessage or rawDisplay)
    local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(rawDisplay))
    display = display:gsub("^%s+", ""):gsub("%s+$", "")
    display = display:gsub("^an?%s+item:%s*", "")
    display = display:gsub("^item:%s*", "")
    display = display:gsub("^loot:%s*", "")
    display = SpaceBeforeX(display)
    display = FormatItemCountSuffix(display)

    if display == "" then return nil end
    return display
end

-- Build a Lua pattern from a Blizzard format string (Goldpaw-style: %s -> (.+), %d -> (%d+))
local function MakeLootPattern(fmt)
    if not fmt or type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%[%d%$]*s", "(.+)"):gsub("%%[%d%$]*d", "(%%d+)"):gsub("%.", "%%.")
    return p
end

-- Localized " receives loot: " / " creates: " etc. from Blizzard (between the %s placeholders)
local function GetReceivesLootLiteral()
    local fmt = _G.LOOT_ITEM or "%s receives loot: %s."
    return (fmt:gsub("%%[%d%$]*s", ""):gsub("%%[%d%$]*d", ""):gsub("%.", ""):gsub("^%s+", " "):gsub("%s+$", " "))
end
local function GetCreatesLiteral()
    local fmt = _G.CREATED_ITEM or "%s creates: %s."
    return (fmt:gsub("%%[%d%$]*s", ""):gsub("%%[%d%$]*d", ""):gsub("%.", ""):gsub("^%s+", " "):gsub("%s+$", " "))
end

-- Group loot patterns from Blizzard globals (localized "receives loot:", "creates:", etc.)
local GroupLootPatterns = {}
do
    local globals = {
        "LOOT_ITEM",           -- "%s receives loot: %s."
        "LOOT_ITEM_MULTIPLE",  -- "%s receives loot: %sx%d."
        "LOOT_ITEM_PUSHED",    -- "%s receives item: %s."
        "LOOT_ITEM_PUSHED_MULTIPLE",
        "CREATED_ITEM",        -- "%s creates: %s."
        "CREATED_ITEM_MULTIPLE",
    }
    for _, g in ipairs(globals) do
        local fmt = _G[g]
        if fmt and type(fmt) == "string" then
            local pattern = MakeLootPattern(fmt)
            if pattern then
                table.insert(GroupLootPatterns, { pattern = pattern, global = g })
            end
        end
    end
end

-- Loot roll patterns (Goldpaw-style): need/greed/pass/disenchant/won from Blizzard globals
local RollPatterns = {}
do
    local rollGlobals = {
        "LOOT_ROLL_NEED",      -- "%s has selected need for %s"
        "LOOT_ROLL_GREED",     -- "%s has selected greed for %s"
        "LOOT_ROLL_DISENCHANT", -- "%s has selected disenchant for %s"
        "LOOT_ROLL_WON",       -- "%s won %s"
    }
    for _, g in ipairs(rollGlobals) do
        local fmt = _G[g]
        if fmt and type(fmt) == "string" and not fmt:find("|H") then
            local pattern = MakeLootPattern(fmt)
            if pattern then
                local literal = (fmt:gsub("%%[%d%$]*s", ""):gsub("%%[%d%$]*d", ""):gsub("^%s+", " "):gsub("%s+$", " "))
                -- Relaxed: roll-type word any casing (Need/need, Greed/greed, etc.)
                local relaxed = pattern:gsub(" need ", " .- "):gsub(" greed ", " .- "):gsub(" passed on ", " .- on "):gsub(" disenchant ", " .- "):gsub(" won ", " .- ")
                table.insert(RollPatterns, { pattern = relaxed, literal = literal })
            end
        end
    end
end
-- Fallback roll patterns when globals missing or different (e.g. Classic locale): name first, then literal, then item
local RollPatternsFallback = {
    { pattern = "^(.-)%s+has selected .- for%s+(.+)$", literal = " has selected for " },
    -- Handles both "Loot: You passed on: Item" and "You passed on Item"
    { pattern = "^(.-)%s+passed on[:%s]+(.+)$", literal = " passed on " },
    { pattern = "^(.-)%s+won%s+(.+)$", literal = " won " },
}

-- Track roll type (Need/Greed/Disenchant) per item per player for "Name Type roll N: Item" formatting
local rollTypeByItem = {}
local function getRollItemKey(itemPart, msg)
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
local function getRollType(itemKey, playerName)
    if not itemKey or itemKey == "" then return "Greed" end
    local t = rollTypeByItem[itemKey]
    if not t then return "Greed" end
    return t[playerName] or t["You"] or "Greed"
end
local function setRollType(itemKey, playerName, rollType)
    if not itemKey or itemKey == "" then return end
    rollTypeByItem[itemKey] = rollTypeByItem[itemKey] or {}
    rollTypeByItem[itemKey][playerName] = rollType
end
local function clearRollItem(itemKey)
    if itemKey and itemKey ~= "" then rollTypeByItem[itemKey] = nil end
end

-- System messages (Goldpaw-style): "Name leaves the party", "Name is Away", "You are no longer Away", etc.
-- Build patterns from Blizzard globals so they work in all locales
local SystemMessagePatterns = {}
do
    local singleNameGlobals = {
        "LEFT_PARTY",       -- "%s leaves the party."
        "JOINED_PARTY",     -- "%s joins the party."
        "CHAT_AFK_GET",     -- "%s is Away:"
        "CHAT_DND_GET",     -- "%s does not wish to be disturbed:"
        "INVITATION",      -- "%s invites you to a group."
    }
    for _, g in ipairs(singleNameGlobals) do
        local fmt = _G[g]
        if fmt and type(fmt) == "string" and not fmt:find("|H") then
            local numS = select(2, fmt:gsub("%%[%d%$]*s", "%%s"))
            if numS == 1 then
                local pattern = MakeLootPattern(fmt)
                if pattern then
                    local literal = (fmt:gsub("%%[%d%$]*s", ""):gsub("%%[%d%$]*d", ""):gsub(":%s*$", ""):gsub("^%s+", " "):gsub("%s+$", ""))
                    if literal and literal ~= "" then
                        table.insert(SystemMessagePatterns, { pattern = pattern, literal = literal, key = g })
                    end
                end
            end
        end
    end
end

-- Extract item link from auction/chat text, or return text with auction phrasing stripped
local function AuctionItemOnly(text)
    if not text or type(text) ~= "string" then return text end
    text = text:gsub("^%s*auction of %s*", ""):gsub("^%s*your %s*", "")
    local link = GetItemLinkFromMessage(text)
    if link then return link end
    text = text:gsub("%s+has been sold.*$", ""):gsub("%s+for %d+ [gGsScC].*$", ""):gsub("%s+%(sold%).*$", ""):gsub("%s+x%d+%s*$", "")
    return CleanPunctuation(StripBrackets(text))
end

-- =========================
-- Merchant: track open/closed; suppress per-message gold and show net change when closed (+ from selling, − from buying/repair)
-- Shared state with AutoSellGreys/AutoRepair.
-- =========================
local MerchantState = Carpenter and Carpenter.MerchantState or _G["Carpenter_MerchantState"] or {}
_G["Carpenter_MerchantState"] = MerchantState

local merchantFrame = CreateFrame("Frame")
local merchantMoneyAtOpen = 0
local merchantZoningGuard = false  -- ignore MERCHANT_CLOSED during/after zone transition (hearth, etc.) when GetMoney() can be wrong
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_CLOSED")
merchantFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
merchantFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        -- New merchant interaction: clear any previous auto-sell/auto-repair markers
        MerchantState.autoSoldJunk = false
        MerchantState.autoSoldAmount = nil
        MerchantState.autoRepaired = false
        MerchantState.autoRepairAmount = nil
        merchantZoningGuard = false
        self.isOpen = true
        merchantMoneyAtOpen = GetMoney()
    elseif event == "PLAYER_ENTERING_WORLD" then
        merchantZoningGuard = true
        self.isOpen = false
    elseif event == "MERCHANT_CLOSED" then
        if merchantZoningGuard then
            self.isOpen = false
            return
        end
        local current = GetMoney()
        local net = current - merchantMoneyAtOpen
        -- Subtract out the known auto-sell and auto-repair contributions so the
        -- ChatCleaner summary only reflects *additional* buy/sell activity.
        local adjusted = net
        if MerchantState.autoSoldJunk and type(MerchantState.autoSoldAmount) == "number" then
            adjusted = adjusted - MerchantState.autoSoldAmount
        end
        if MerchantState.autoRepaired and type(MerchantState.autoRepairAmount) == "number" then
            adjusted = adjusted - MerchantState.autoRepairAmount
        end
        -- If nothing remains once we subtract junk sold and gear repaired,
        -- then the dedicated AutoSellGreys/AutoRepair lines already told
        -- the whole story; skip the generic merchant summary.
        if adjusted == 0 then
            -- Defer clearing so late CHAT_MSG_MONEY from auto-sell/auto-repair
            -- is still suppressed and doesn't duplicate the gain message.
            C_Timer.After(0.5, function() self.isOpen = false end)
            return
        end
        net = adjusted
        -- Sanity: you can't lose more than you have; if reported loss > current gold, GetMoney() was wrong (e.g. during zone transition)
        if net < 0 and (-net) > current then
            C_Timer.After(0.5, function() self.isOpen = false end)
            return
        end
        if net > 0 then
            print((ColorPlus .. "+|r ") .. FormatMoney(net))
        elseif net < 0 then
            print((ColorMinus .. "-|r ") .. FormatMoney(-net))
        end
        -- Defer clearing so any CHAT_MSG_MONEY from this session (e.g. last sale) is still suppressed and we don't show the amount twice
        C_Timer.After(0.5, function() self.isOpen = false end)
    end
end)


-- =========================
-- Mailbox Logic (Buffered Money Summary)
-- TBC Anniversary may not fire MAIL_SHOW/MAIL_CLOSED; use MailFrame visibility.
-- =========================
local mailLastMoney = 0
local mailTotalCollected = 0
local mailTracker = CreateFrame("Frame")
mailTracker.isOpen = false
mailTracker:RegisterEvent("PLAYER_MONEY")

local function IsMailFrameVisible()
    return _G.MailFrame and _G.MailFrame.IsVisible and _G.MailFrame:IsVisible()
end

mailTracker:SetScript("OnUpdate", function(self, elapsed)
    if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then
        self:Hide()
        return
    end

    self._t = (self._t or 0) + elapsed
    if self._t < 0.2 then return end
    self._t = 0

    local visible = IsMailFrameVisible()
    if visible and not self.isOpen then
        self.isOpen = true
        mailLastMoney = GetMoney()
        mailTotalCollected = 0
    elseif not visible and self.isOpen then
        self.isOpen = false
        if mailTotalCollected > 0 then
            print((ColorPlus .. "+|r ") .. FormatMoney(mailTotalCollected))
        end
        mailTotalCollected = 0
    end
end)
mailTracker:Hide()

mailTracker:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_MONEY" and self.isOpen then
        local currentMoney = GetMoney()
        local diff = currentMoney - mailLastMoney
        if diff > 0 then
            mailTotalCollected = mailTotalCollected + diff
        end
        mailLastMoney = currentMoney
    end
end)


-- =========================
-- Event Interceptors
-- =========================
local lastHonorKey, lastHonorTime = nil, 0
local HONOR_DEDUP_SEC = 5
local lastRepairAmount, lastRepairTime = nil, 0
local REPAIR_DEDUP_SEC = 2
local lastLearnedSkillName, lastLearnedSkillTime = nil, 0
local LEARNED_SKILL_DEDUP_SEC = 3

local function NormalizeSkillName(name)
    if not name or type(name) ~= "string" then return nil end
    name = CleanPunctuation(StripBrackets(name))
    name = name:gsub("%s*%b()%s*$", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:lower()
end

local function IsLevelUpRewardEvent(event)
    return event == "CHAT_MSG_SYSTEM" or
        event == "CHAT_MSG_COMBAT_XP_GAIN" or
        event == "CHAT_MSG_COMBAT_MISC_INFO"
end

local function FormatLevelUpRewardMessage(plainText)
    if not plainText or type(plainText) ~= "string" then return nil end

    local plainLower = plainText:lower()
    local levelColor = GetClassColorForName(UnitName("player") or "")

    local function TrimName(name)
        if not name or name == "" then return nil end
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        name = name:gsub("^%*%s*", ""):gsub("%s*%*$", "")
        name = name:gsub("^%[", ""):gsub("%]$", "")
        name = name:gsub("%-.*$", "")
        if name == "" then return nil end
        return name
    end

    local function FormatOtherPlayerLevel(name, levelNum)
        name = TrimName(name)
        if not name or not levelNum then return nil end
        if name:lower() == "you" then return nil end

        local nameColor = GetClassColorForName(name)
        return nameColor .. name .. "|r " .. levelColor .. "Reached Level " .. levelNum .. "|r"
    end

    local otherName, otherLevel = plainText:match("^%s*(.-)%s+[Hh]as%s+[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
    local styledOther = FormatOtherPlayerLevel(otherName, otherLevel)
    if styledOther then return styledOther end

    otherName, otherLevel = plainText:match("^%s*(.-)%s+[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
    styledOther = FormatOtherPlayerLevel(otherName, otherLevel)
    if styledOther then return styledOther end

    otherName, otherLevel = plainText:match("^%s*[Cc]ongratulations%s+to%s+(.+)%s+on%s+[Rr]eaching%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$") or
        plainText:match("^%s*[Cc]ongratulations%s+to%s+(.+)%s+for%s+[Rr]eaching%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
    styledOther = FormatOtherPlayerLevel(otherName, otherLevel)
    if styledOther then return styledOther end

    local levelNum = plainText:match("[Rr]eached%s+level%s+(%d+)") or plainText:match("[Rr]each%s+level%s+(%d+)") or
        plainText:match("[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
    if levelNum and plainLower:find("level") and (plainLower:find("reached") or plainLower:find("reach") or plainLower:find("congratulations")) then
        return levelColor .. "Reached Level " .. levelNum .. "|r"
    end

    local hitAmount = plainText:match("[Yy]ou%s+have%s+gained%s+(%d+)%s+[Hh]it [Pp]oint") or
        plainText:match("[Hh]ave%s+gained%s+(%d+)%s+[Hh]it [Pp]oint") or
        plainText:match("[Gg]ained%s*:?.-%s*(%d+)%s+[Hh]it [Pp]oint")
    if hitAmount and plainLower:find("hit point") then
        local n = tonumber(hitAmount) or 0
        local word = (n == 1) and "Hit Point" or "Hit Points"
        return ColorPlus .. "+|r " .. levelColor .. hitAmount .. " " .. word .. "|r"
    end

    local talentAmount = plainText:match("[Yy]ou%s+have%s+gained%s+(%d+)%s+[Tt]alent [Pp]oint") or
        plainText:match("[Hh]ave%s+gained%s+(%d+)%s+[Tt]alent [Pp]oint") or
        plainText:match("[Gg]ained%s*:?.-%s*(%d+)%s+[Tt]alent [Pp]oint")
    if talentAmount and plainLower:find("talent point") then
        local n = tonumber(talentAmount) or 0
        local word = (n == 1) and "Talent Point" or "Talent Points"
        return ColorPlus .. "+|r " .. levelColor .. talentAmount .. " " .. word .. "|r"
    end

    if plainText:match("[Yy]our%s+%w+%s+increases%s+by%s+%d+") or plainText:match("[Ii]ncreases:%s*%w+%s+by%s+%d+") then
        local stats = {}
        for statName, statBy in plainText:gmatch("[Yy]our%s+(%w+)%s+increases%s+by%s+(%d+)") do
            statName = statName:sub(1, 1):upper() .. statName:sub(2):lower()
            stats[#stats + 1] = statBy .. " " .. statName
        end
        for statName, statBy in plainText:gmatch("[Ii]ncreases:%s*(%w+)%s+by%s+(%d+)") do
            statName = statName:sub(1, 1):upper() .. statName:sub(2):lower()
            stats[#stats + 1] = statBy .. " " .. statName
        end
        if #stats > 0 then
            return ColorPlus .. "+|r " .. levelColor .. table.concat(stats, ", ") .. "|r"
        end
    end

    return nil
end

local originalLevelUpGlobals = nil

local function ApplyLevelUpGlobalStringStyling()
    if originalLevelUpGlobals then return end

    originalLevelUpGlobals = {
        LEVEL_UP = _G.LEVEL_UP,
        LEVEL_UP_HEALTH = _G.LEVEL_UP_HEALTH,
        LEVEL_UP_HEALTH_MANA = _G.LEVEL_UP_HEALTH_MANA,
        LEVEL_UP_CHAR_POINTS = _G.LEVEL_UP_CHAR_POINTS,
        LEVEL_UP_STAT = _G.LEVEL_UP_STAT,
    }

    local levelColor = GetClassColorForName(UnitName("player") or "")
    _G.LEVEL_UP = levelColor .. "Reached Level %d|r"
    _G.LEVEL_UP_HEALTH = ColorPlus .. "+|r " .. levelColor .. "%d Hit Points|r"
    _G.LEVEL_UP_HEALTH_MANA = ColorPlus .. "+|r " .. levelColor .. "%d Hit Points|r, " .. ColorPlus .. "+|r " .. levelColor .. "%d Mana|r"
    _G.LEVEL_UP_CHAR_POINTS = ColorPlus .. "+|r " .. levelColor .. "%d Talent Points|r"
    _G.LEVEL_UP_STAT = "Your %s increases by %d"
end

local function ChatFilterImpl(self, event, msg, author, ...)
    if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then
        return false, msg, author, ...
    end

    -- Monster emotes: some locales/strings use format placeholders like "%s" or "%o"
    -- and Blizzard's MessageFormatter later calls string.format with extra args
    -- (player/mob links). That combination can throw "bad argument #2 to 'format'"
    -- if a numeric placeholder like %o is paired with a string argument.
    --
    -- For monster emotes, substitute the monster's name into any %s/%o-style
    -- placeholders ourselves, then escape remaining '%' so Blizzard's formatter
    -- sees a plain string and never interprets them as format codes.
    if event == "CHAT_MSG_MONSTER_EMOTE" and type(msg) == "string" then
        local name = author
        if not name or name == "" then
            name = select(1, ...) or ""
        end
        if name ~= "" then
            -- Replace common string/ordinal placeholders with the monster name
            msg = msg:gsub("%%[sSoO]", name)
        end
        -- Neutralize any remaining '%' so later string.format calls are safe
        msg = msg:gsub("%%", "%%%%")
    end

    -- Hide noisy "Changed Channel" notifications now that prefixes are compact
    if type(msg) == "string" and msg:find("^Changed Channel:") then
        return true
    end
    -- Hide "Left Channel: 1." / "Left Channel: 2." etc.
    if type(msg) == "string" and msg:find("^Left Channel:") then
        return true
    end

    -- Hide all Auctionator addon messages (they start with "Auctionator:")
    if type(msg) == "string" and (msg:find("^Auctionator:") or msg:find("^|c%x%x%x%x%x%x%x%x%xAuctionator:")) then
        return true
    end

    local prefixPlus = ColorPlus .. "+|r "
    local prefixMinus = ColorMinus .. "-|r "

    -- Early detection: Suppress loot messages that come through as CHAT_MSG_YELL
    -- Only process if the message ALREADY contains loot patterns - don't add "receives loot:" to regular yells
    if event == "CHAT_MSG_YELL" then
        local plainMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        -- Only process if message already contains loot patterns (actual loot messages, not regular yells)
        if plainMsg:find("receives loot:") or plainMsg:find("receives item:") or 
           plainMsg:find("creates:") or plainMsg:find("conjures:") then
            -- This is an actual loot message incorrectly sent as a yell - reformat it
            local playerName = author
            if not playerName or playerName == "" then
                -- Try to extract from message if author is missing
                playerName = plainMsg:match("^%s*(.-)%s+receives loot:") or
                             plainMsg:match("^%s*(.-)%s+receives item:") or
                             plainMsg:match("^%s*(.-)%s+creates:") or
                             plainMsg:match("^%s*(.-)%s+conjures:")
                if playerName then
                    playerName = playerName:gsub("%-.*", "") -- Remove server name if present
                    playerName = playerName:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
                end
            else
                -- Remove server name if present in author (format: "Name-Server")
                playerName = playerName:gsub("%-.*", "")
            end
            
            -- Other person's loot in yell: fall through so group loot block can style as "Name: Item (2)"
            if playerName and playerName ~= "" and playerName ~= UnitName("player") then
                -- fall through to group loot styling below
            else
                -- If we can't format it properly, suppress the yell version
                return true
            end
        end
        -- Regular yells with item links should pass through unchanged - don't add "receives loot:" to them
    end

    -- 1. Discovery Experience (handle before regular XP to format with zone name); all white except zone (teal)
    local discoveredZone, discoveredXP = msg:match("Discovered (.+): (%d+) experience gained")
    if discoveredZone and discoveredXP then
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. discoveredXP .. " EXP: " .. "|r" .. ColorTeal .. discoveredZone .. "|r"), author, ...
    end
    -- 1b. "Exploring a new zone: ZoneName" / "Explored: ZoneName" (system message, often default yellow -> white)
    local plainSys = type(msg) == "string" and msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1") or ""
    local exploredZone = plainSys:match("^%s*[Ee]xploring a new zone:%s*(.+)$") or plainSys:match("^%s*[Ee]xplored:%s*(.+)$") or plainSys:match("^%s*[Dd]iscovered:%s*(.+)$")
    if exploredZone and exploredZone ~= "" then
        exploredZone = exploredZone:gsub("^%s+", ""):gsub("%s+$", "")
        return false, SpaceBeforeX(ColorWhite .. "Exploring a new zone: " .. exploredZone .. "|r"), author, ...
    end

    -- 2. Regular Experience Gains
    local xp = msg:match("You gain (%d+) experience") or msg:match("Experience gained: (%d+)")
    if xp then
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. xp .. " |r" .. ColorWhite .. "EXP|r"), author, ...
    end

    -- 2.1 Battleground join/leave: "Name has joined the battle" → "Name joined", "Name has left the battle" → "Name left"
    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        -- "5 players have joined the battle." → "5 players joined" (green, same as name join)
        local numPlayersJoin = plainSys:match("^(%d+)%s+players have joined the battle%.?%s*$")
        if numPlayersJoin then
            return false, ColorGreen .. numPlayersJoin .. " players joined|r", author, ...
        end
        local bgJoin = plainSys:match("^%s*(.-)%s+has joined the battle%.?%s*$")
        if bgJoin and bgJoin ~= "" then
            bgJoin = bgJoin:gsub("^%s+", ""):gsub("%s+$", "")
            if bgJoin ~= "" then
                return false, ColorGreen .. bgJoin .. " joined|r", author, ...
            end
        end
        local bgLeave = plainSys:match("^%s*(.-)%s+has left the battle%.?%s*$")
        if bgLeave and bgLeave ~= "" then
            bgLeave = bgLeave:gsub("^%s+", ""):gsub("%s+$", "")
            if bgLeave ~= "" then
                return false, ColorRed .. bgLeave .. " left|r", author, ...
            end
        end
    end

    -- "The flag has been reset." / "Your flag has been reset." etc. → "Flag reset" (orange)
    local plainLower = plainSys:lower()
    if plainLower:find("flag") and plainLower:find("has been reset") then
        return false, ColorOrange .. "Flag reset|r", author, ...
    end

    -- 2.2 Party/battleground system messages (SYSTEM or BG events) — same color as other raid messages
    local groupColor = GetPartyOrRaidMessageColor()
    if plainSys:find("Party converted to Raid") then
        return false, groupColor .. "Party converted to Raid|r", author, ...
    end
    if plainSys:find("Raid converted to Party") then
        return false, groupColor .. "Raid converted to Party|r", author, ...
    end
    local raidJoin = plainSys:match("^%s*(.-)%s+has joined the raid group%.?%s*$")
    if raidJoin and raidJoin ~= "" then
        raidJoin = raidJoin:gsub("^%s+", ""):gsub("%s+$", "")
        return false, groupColor .. raidJoin .. " joined the raid|r", author, ...
    end
    local raidLeave = plainSys:match("^%s*(.-)%s+has left the raid group%.?%s*$")
    if raidLeave and raidLeave ~= "" then
        raidLeave = raidLeave:gsub("^%s+", ""):gsub("%s+$", "")
        return false, groupColor .. raidLeave .. " left the raid|r", author, ...
    end
    if plainSys:find("You are in both a party and a battleground group") then
        return false, groupColor .. "You are in a party and a battleground group|r", author, ...
    end
    if plainSys:find("You may communicate with your party") and plainSys:find("/p") and plainSys:find("/bg") then
        return false, groupColor .. "Communicate with your party with \"/p\" and with your battleground group with \"/bg\"|r", author, ...
    end
    if plainSys:find("The battle has ended") and (plainSys:find("battleground will close") or plainSys:find("close in")) then
        return false, ColorWhite .. "The battle has ended|r", author, ...
    end

    -- 2.3 Level-up reward messages. These can arrive as SYSTEM, combat XP, or Vanilla combat misc messages.
    if IsLevelUpRewardEvent(event) then
        local styledLevelReward = FormatLevelUpRewardMessage(plainSys)
        if styledLevelReward then
            return false, styledLevelReward, author, ...
        end
    end

    -- 2.5. Quest Acceptance & Completion (check early, before other patterns)
    -- Only process quest messages from SYSTEM events (your own quests)
    if event == "CHAT_MSG_SYSTEM" then
        -- Strip color codes for pattern matching but extract quest name from original to preserve links
        local plainMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        local lowerPlainMsg = plainMsg:lower()
        
        -- Quest acceptance
        local questAccepted = nil
        if lowerPlainMsg:find("quest accepted:") then
            questAccepted = msg:match("[Qq]uest [Aa]ccepted: (.+)")
            if not questAccepted then
                -- Try without colon
                questAccepted = msg:match("[Qq]uest [Aa]ccepted (.+)")
            end
        end
        
        -- Quest completion - match patterns that indicate YOUR quest completion
        local questCompleted = nil
        -- "Questname completed." format (quest name first, then " completed.")
        questCompleted = msg:match("^(.+) [Cc]ompleted%.?%s*$")
        if not questCompleted then
            -- Try other formats
            questCompleted = msg:match("[Qq]uest [Cc]ompleted: (.+)") or
                            msg:match("[Qq]uest [Cc]ompleted (.+)") or
                            msg:match("[Yy]ou [Hh]ave [Cc]ompleted: (.+)") or
                            msg:match("[Yy]ou [Hh]ave [Cc]ompleted (.+)") or
                            msg:match("[Yy]ou [Cc]ompleted: (.+)") or
                            msg:match("[Yy]ou [Cc]ompleted (.+)")
        end
        if not questCompleted and lowerPlainMsg:find("you") and lowerPlainMsg:find("completed") then
            questCompleted = msg:match("[Yy]ou.-[Cc]ompleted:? (.+)")
        end
        
        if questAccepted then
            return false,
                SpaceBeforeX(prefixPlus ..
                ColorWhite .. "Accepted: " .. "|r" .. ColorYellow .. CleanPunctuation(StripBrackets(questAccepted)) .. "|r"),
                author, ...
        elseif questCompleted then
            -- Clean up the quest name (remove trailing periods, etc.)
            local cleanQuest = CleanPunctuation(StripBrackets(questCompleted))
            return false,
                SpaceBeforeX(prefixPlus ..
                ColorWhite .. "Completed: " .. "|r" .. ColorYellow .. cleanQuest .. "|r"),
                author, ...
        else
            -- Goldpaw-style: style boring yellow system messages (left group, joined, AFK, DND, etc.)
            local plainMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")

            -- Self messages: "You are no longer Away.", "You are now Away.", DND equivalents
            if _G.CLEARED_AFK and plainMsg == _G.CLEARED_AFK then
                return false, ColorGreen .. "Back|r", author, ...
            end
            if _G.CLEARED_DND and plainMsg == _G.CLEARED_DND then
                return false, ColorGreen .. "Available|r", author, ...
            end
            -- "You are now Away." / "You are now Away: custom" / "You are now AFK: custom"
            if _G.MARKED_AFK and plainMsg == _G.MARKED_AFK then
                return false, ColorOrange .. "AFK|r", author, ...
            end
            local afkCustom = plainMsg:match("^You are now Away: (.+)$") or plainMsg:match("^You are now AFK: (.+)$")
            if afkCustom and afkCustom ~= "" then
                return false, ColorOrange .. "AFK: " .. afkCustom .. "|r", author, ...
            end
            if _G.MARKED_DND and plainMsg:match("^You are now Busy") then
                return false, ColorDarkorange .. "Busy|r", author, ...
            end
            -- PvP flag: "You are now flagged for PvP combat and will remain so until toggled off."
            if plainMsg:match("^You are now flagged for PvP combat") then
                return false, ColorRed .. "Flagged for PvP|r", author, ...
            end
            -- "You feel rested." -> "Rested" (same blue as rested XP bar)
            if plainMsg:match("^You feel rested%.?%s*$") or (plainMsg:lower():find("feel rested") and plainMsg:lower():find("you")) then
                return false, ColorRestedBar .. "Rested|r", author, ...
            end
            -- "You feel normal." -> "Normal" (same purple as normal XP bar)
            if plainMsg:match("^You feel normal%.?%s*$") or (plainMsg:lower():find("feel normal") and plainMsg:lower():find("you")) then
                return false, ColorNormalBar .. "Normal|r", author, ...
            end

            -- Ready / role checks
            -- "The Ready Check has failed." → "Ready Check failed" (red)
            if plainMsg:find("Ready Check") and plainMsg:find("failed") then
                return false, ColorRed .. "Ready Check failed|r", author, ...
            end
            -- "Kohji is not ready." → "Kohji not ready" (red)
            local notReadyName = plainMsg:match("^%s*(.-)%s+is not ready%.?%s*$")
            if notReadyName and notReadyName ~= "" then
                notReadyName = notReadyName:gsub("^%s+", ""):gsub("%s+$", "")
                local short = notReadyName:gsub("%-.*$", "")
                return false, ColorRed .. short .. " not ready|r", author, ...
            end
            -- "Skandalnudel is already in a group." → "Skandalnudel already in a group" (red)
            local alreadyInGroup = plainMsg:match("^%s*(.-)%s+is already in a group%.?%s*$")
            if alreadyInGroup and alreadyInGroup ~= "" then
                alreadyInGroup = alreadyInGroup:gsub("^%s+", ""):gsub("%s+$", "")
                local short = alreadyInGroup:gsub("%-.*$", "")
                return false, ColorRed .. short .. " already in a group|r", author, ...
            end
            -- "You aren't in a party." / "You are not in a party." → "Not in a party" (red)
            if plainMsg:match("^%s*[Yy]ou aren't in a party%.?%s*$") or plainMsg:match("^%s*[Yy]ou are not in a party%.?%s*$") then
                return false, ColorRed .. "Not in a party|r", author, ...
            end
            -- "Crusader is now the loot master." → "Crusader is loot master" (orange)
            local lootMaster = plainMsg:match("^%s*(.-)%s+is now the loot master%.?%s*$")
            if lootMaster and lootMaster ~= "" then
                lootMaster = lootMaster:gsub("^%s+", ""):gsub("%s+$", "")
                local short = lootMaster:gsub("%-.*$", "")
                return false, ColorOrange .. short .. " is loot master|r", author, ...
            end
            -- "A ready check has been initiated. Your group will be queued when all members have indicated they are ready." → "Ready check"
            if plainMsg:find("ready check") and plainMsg:find("initiated") and plainMsg:find("queued") then
                return false, ColorOrange .. "Ready check|r", author, ...
            end
            -- "Subtikka has initiated a ready check."
            local rcName = plainMsg:match("^%s*(.-)%s+has initiated a ready check%.?%s*$")
            if rcName and rcName ~= "" then
                rcName = rcName:gsub("^%s+", ""):gsub("%s+$", "")
                local short = rcName:gsub("%-.*$", "")
                local nameColor = GetClassColorForName(short)
                return false, nameColor .. short .. "|r " .. ColorOrange .. "initiated ready check|r", author, ...
            end
            -- "Subtikka is now Tank" / "Subtikka is now Healer." / "Kohji is now Damage."
            -- Capture the name and a single word role, then validate allowed roles in code.
            local roleName, roleWord = plainMsg:match("^%s*(.-)%s+is now%s+([%a]+)%.?%s*$")
            if roleName and roleWord then
                roleName = roleName:gsub("^%s+", ""):gsub("%s+$", "")
                local short = roleName:gsub("%-.*$", "")
                local nameColor = GetClassColorForName(short)
                -- Normalize role to capitalized form
                local lowerRole = roleWord:lower()
                if lowerRole == "tank" or lowerRole == "healer" or lowerRole == "damage" then
                    local prettyRole = (lowerRole == "tank" and "Tank") or
                                       (lowerRole == "healer" and "Healer") or
                                       (lowerRole == "damage" and "Damage")
                    return false, nameColor .. short .. "|r " .. ColorOrange .. prettyRole .. "|r", author, ...
                end
            end

            -- Daily quest cap tracking
            -- "You can only complete 24 more daily quests today."
            local remainingDaily = plainMsg:match("^%s*You can only complete%s+(%d+)%s+more daily quests today%.?%s*$")
            if remainingDaily then
                local total = 25
                local rem = tonumber(remainingDaily) or 0
                local done = total - rem
                if done < 0 then done = 0 end
                if done > total then done = total end
                return false, ColorRestedBar .. done .. "/" .. total .. "|r " .. ColorWhite .. "daily quests today|r", author, ...
            end
            -- "You have already completed 25 daily quests today."
            local doneDaily = plainMsg:match("^%s*You have already completed%s+(%d+)%s+daily quests today%.?%s*$")
            if doneDaily then
                local total = 25
                local done = tonumber(doneDaily) or 0
                if done < 0 then done = 0 end
                if done > total then done = total end
                return false, ColorRestedBar .. done .. "/" .. total .. "|r " .. ColorWhite .. "daily quests today|r", author, ...
            end

            -- Trade request: "You have requested to trade with Name." → "Requested to trade with Name"
            local tradeTarget = plainMsg:match("^You have requested to trade with%s+(.+)%.$") or plainMsg:match("^You have requested to trade with%s+(.+)$")
            if tradeTarget and tradeTarget ~= "" then
                tradeTarget = tradeTarget:gsub("^%s+", ""):gsub("%s+$", "")
                if tradeTarget ~= "" then
                    local short = tradeTarget:gsub("%-.*$", "")
                    return false, ColorGreen .. "Requested to trade with " .. short .. "|r", author, ...
                end
            end

            -- Instance / battle join/leave notifications
            -- "Name has joined the instance group." → "Name joined" (green)
            local instJoin = plainMsg:match("^%s*(.-)%s+has joined the instance group%.?%s*$")
            if instJoin and instJoin ~= "" then
                instJoin = instJoin:gsub("^%s+", ""):gsub("%s+$", "")
                if instJoin ~= "" then
                    return false, ColorGreen .. instJoin .. " joined|r", author, ...
                end
            end
            -- "Name has left the instance group." → "Name left" (red)
            local instLeave = plainMsg:match("^%s*(.-)%s+has left the instance group%.?%s*$")
            if instLeave and instLeave ~= "" then
                instLeave = instLeave:gsub("^%s+", ""):gsub("%s+$", "")
                if instLeave ~= "" then
                    return false, ColorRed .. instLeave .. " left|r", author, ...
                end
            end
            -- "5 players have joined the battle." → "5 players joined" (green)
            local numPlayers = plainMsg:match("^(%d+)%s+players have joined the battle%.?%s*$")
            if numPlayers then
                return false, ColorGreen .. numPlayers .. " players joined|r", author, ...
            end
            -- "Notify system has been enabled/disabled." → hide
            if plainMsg:match("^Notify system has been (enabled|disabled)%.?%s*$") then
                return true
            end

            -- Party/raid system messages: shortened text, Blizzard party/raid color, class-colored names
            local groupColor = GetPartyOrRaidMessageColor()
            -- "Name has invited you to join a group." / "Name invites you to a group." → "Name invited you" (green when class unknown, else class + party/raid)
            local inviter = plainMsg:match("^%s*(.-)%s+has invited you to join a group%.?%s*$") or
                           plainMsg:match("^%s*(.-)%s+invites you to [a ]?group%.?%s*$") or
                           plainMsg:match("^%s*(.-)%s+invites you to join a group%.?%s*$")
            if inviter and inviter ~= "" then
                inviter = inviter:gsub("^%s+", ""):gsub("%s+$", "")
                -- Strip surrounding brackets like "[Name]" → "Name" so output is "Name invited you"
                inviter = inviter:gsub("^%[(.-)%]$", "%1")
                if inviter ~= "" then
                    local shortName = inviter:gsub("%-[^%-]+$", "")
                    local playerLink = GetFirstPlayerLink(msg)
                    local nameColor = playerNameToClassColor[shortName] or playerNameToClassColor[inviter] or GetClassColorForName(inviter)
                    local knownClass = (nameColor ~= ColorOffwhite)
                    if knownClass then
                        local namePart = playerLink or (nameColor .. inviter .. "|r")
                        return false, namePart .. groupColor .. " invited you|r", author, ...
                    else
                        return false, ColorGreen .. inviter .. " invited you|r", author, ...
                    end
                end
            end
            -- "[Name] invited you" (e.g. from party channel) → "Name invited you"
            local bracketInviter = plainMsg:match("%[([^%]]+)%]%s*invited you") or plainMsg:match("^%s*%[([^%]]+)%]%s*invited you")
            if bracketInviter and bracketInviter ~= "" then
                bracketInviter = bracketInviter:gsub("^%s+", ""):gsub("%s+$", "")
                if bracketInviter ~= "" then
                    local shortName = bracketInviter:gsub("%-[^%-]+$", "")
                    local playerLink = GetFirstPlayerLink(msg)
                    local nameColor = playerNameToClassColor[shortName] or playerNameToClassColor[bracketInviter] or GetClassColorForName(bracketInviter)
                    local knownClass = (nameColor ~= ColorOffwhite)
                    if knownClass then
                        local namePart = playerLink or (nameColor .. bracketInviter .. "|r")
                        return false, namePart .. groupColor .. " invited you|r", author, ...
                    else
                        return false, ColorGreen .. bracketInviter .. " invited you|r", author, ...
                    end
                end
            end
            -- "You have invited Name to join your group." → "Invited Name" (all green; we don't know their class)
            local youInvited = plainMsg:match("^%s*You have invited%s+(.-)%s+to join your group%.?%s*$")
            if youInvited and youInvited ~= "" then
                youInvited = youInvited:gsub("^%s+", ""):gsub("%s+$", "")
                if youInvited ~= "" then
                    return false, ColorGreen .. "Invited " .. youInvited .. "|r", author, ...
                end
            end
            -- "Name declines your group invitation." → "Name declines" (all red)
            local decliner = plainMsg:match("^%s*(.-)%s+declines your group invitation%.?%s*$") or plainMsg:match("^%s*(.-)%s+declines%.?%s*$")
            if decliner and decliner ~= "" then
                decliner = decliner:gsub("^%s+", ""):gsub("%s+$", "")
                if decliner ~= "" then
                    return false, ColorRed .. decliner .. " declines|r", author, ...
                end
            end
            -- "Your group has been disbanded." → "Group disbanded" (red)
            if plainMsg:match("^%s*Your group has been disbanded%.?%s*$") then
                return false, ColorRed .. "Group disbanded|r", author, ...
            end
            -- "You leave the group." / "You left the raid." etc. → "Left party" or "Left raid" (red; use message to tell which)
            if plainMsg:match("^%s*You leave the group%.?%s*$") or plainMsg:match("^%s*You left the group%.?%s*$") or
               plainMsg:match("^%s*You have left the group%.?%s*$") or plainMsg:match("^%s*You leave the raid%.?%s*$") or
               plainMsg:match("^%s*You left the raid%.?%s*$") or plainMsg:match("^%s*You have left the raid%.?%s*$") then
                local leftRaid = plainMsg:lower():find("raid")
                return false, ColorRed .. (leftRaid and "Left raid|r" or "Left party|r"), author, ...
            end
            -- "Dungeon Difficulty: X" / "... set to X" → "Dungeon Difficulty: X" (Normal=white, Heroic=orange)
            local dungeonDifficultyLabel = _G.DUNGEON_DIFFICULTY or "Dungeon Difficulty"
            if plainMsg:find(dungeonDifficultyLabel, 1, true) then
                local difficulty = plainMsg:match("set to (%w+)") or plainMsg:match(dungeonDifficultyLabel:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. ":%s*(%w+)")
                if difficulty then
                    difficulty = difficulty:gsub("^%s+", ""):gsub("%s+$", "")
                    local diffColor = (difficulty:lower() == "heroic") and ColorOrange or ColorWhite
                    return false, groupColor .. dungeonDifficultyLabel .. ": |r" .. diffColor .. difficulty .. "|r", author, ...
                end
            end
            -- "You have been removed from the group" → "Removed from the group"
            if plainMsg:match("^%s*You have been removed from the group%.?%s*$") or plainMsg:match("^%s*You have been removed from the raid%.?%s*$") then
                return false, groupColor .. "Removed from the group|r", author, ...
            end
            -- "Name joins the party." / "Name joins the raid." → "Name joins" (all green; cache class for "invited you")
            local joiner = plainMsg:match("^%s*(.-)%s+joins the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+joins the raid%.?%s*$")
            if joiner and joiner ~= "" then
                joiner = joiner:gsub("^%s+", ""):gsub("%s+$", "")
                if joiner ~= "" then
                    local joinerShort = joiner:gsub("%-[^%-]+$", "")
                    local c = GetClassColorForName(joiner)
                    playerNameToClassColor[joinerShort] = c
                    playerNameToClassColor[joiner] = c
                    return false, ColorGreen .. joiner .. " joins|r", author, ...
                end
            end
            -- "Name is now the group leader." / "Name is now the raid leader." → "Name is now group leader" (party color)
            local newLeader = plainMsg:match("^%s*(.-)%s+is now the group leader%.?%s*$") or plainMsg:match("^%s*(.-)%s+is now the raid leader%.?%s*$")
            if newLeader and newLeader ~= "" then
                newLeader = newLeader:gsub("^%s+", ""):gsub("%s+$", "")
                if newLeader ~= "" then
                    return false, groupColor .. newLeader .. " is now group leader|r", author, ...
                end
            end
            -- "You are now the group leader." → "You are now group leader"
            if plainMsg:match("^%s*You are now the group leader%.?%s*$") or plainMsg:match("^%s*You are now the raid leader%.?%s*$") then
                return false, groupColor .. "You are now group leader|r", author, ...
            end
            -- "Looting changed to Free for All." / "Loot method set to X" etc. → "Loot: X" (white label, party/raid color value)
            local lootMethod = plainMsg:match("[Ll]ooting changed to%s+(.+)$") or plainMsg:match("[Ll]oot method set to%s+(.+)$") or
                              plainMsg:match("[Ll]oot method changed to%s+(.+)$") or plainMsg:match("[Ll]oot%s+changed to%s+(.+)$")
            if lootMethod and lootMethod ~= "" then
                lootMethod = lootMethod:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.?%s*$", "")
                if lootMethod ~= "" then
                    return false, ColorWhite .. "Loot: |r" .. groupColor .. lootMethod .. "|r", author, ...
                end
            end
            -- "Name has died." → "Name died" (all red)
            local died = plainMsg:match("^%s*(.-)%s+has died%.?%s*$")
            if died and died ~= "" then
                died = died:gsub("^%s+", ""):gsub("%s+$", "")
                if died ~= "" then
                    return false, ColorRed .. died .. " died|r", author, ...
                end
            end
            -- "Name leaves the party." / "Name leaves the raid." → "Name leaves party" / "Name leaves raid" (red)
            local leaver = plainMsg:match("^%s*(.-)%s+leaves the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+leaves the raid%.?%s*$")
            if leaver and leaver ~= "" then
                leaver = leaver:gsub("^%s+", ""):gsub("%s+$", "")
                if leaver ~= "" then
                    local leavesRaid = plainMsg:lower():find("leaves the raid")
                    local suffix = leavesRaid and " leaves raid" or " leaves party"
                    return false, ColorRed .. leaver .. suffix .. "|r", author, ...
                end
            end

            -- Name-based system messages (invites, Away, DND): use default Blizzard text so names show and no %s
            -- (we do not replace these; JOINED_PARTY/LEFT_PARTY are already passed through)
        end
    end

    -- 2. Reputation Standing Changes (e.g. "You are now Neutral with Lower City.")
    local standing, standingFaction = msg:match("You are now (.-) with (.+)")
    if standing and standingFaction then
        local cleanFaction = CleanPunctuation(StripBrackets(standingFaction))
        return false,
            SpaceBeforeX(prefixPlus ..
            ColorWhite .. standing .. ": |r" .. ColorBluePurple .. cleanFaction .. "|r"),
            author, ...
    end

    -- 2a. Reputation Gains (numeric)
    local repMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%[", ""):gsub("%]", "")
    local faction, amount = repMsg:match("Your reputation with (.-) has increased by (%d+)")
    if not faction then faction, amount = repMsg:match("Your (.-) reputation has increased by (%d+)") end
    if not faction then faction, amount = repMsg:match("Your Warband's reputation with (.-) increased by (%d+)") end
    if not faction then faction, amount = repMsg:match("Reputation with (.-) increased by (%d+)%.?") end
    if not faction then amount, faction = repMsg:match("(%d+) reputation with (.-) gained") end
    if not faction then
        faction, amount = repMsg:match("^(.-)%s+judges your Warband more worthy%.?%s*(%d+)%s+reputation gained")
    end

    if faction and amount then
        faction = CleanPunctuation(StripBrackets(faction))
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. amount .. " Reputation: |r" .. ColorBluePurple .. faction .. "|r"),
            author, ...
    end

    -- 2b. Reputation Decreases
    local repFaction, repAmount = msg:match("Your reputation with (.-) has decreased by (%d+)")
    if not repFaction then repFaction, repAmount = msg:match("Reputation with (.-) decreased by (%d+)") end
    if not repFaction then repAmount, repFaction = msg:match("(%d+) reputation with (.-) lost") end
    if not repFaction then repFaction, repAmount = msg:match("(.-) reputation decreased by (%d+)") end

    if repFaction and repAmount then
        return false, SpaceBeforeX(prefixMinus .. ColorWhite .. repAmount .. " Reputation: |r" .. ColorBluePurple .. repFaction .. "|r"),
            author, ...
    end

    -- 3. Queue Join Messages
    local queueMsg = msg:lower()
    local battlegroundName = msg:match("Battle for (.+)") or msg:match("(.+) begins") or msg:match "(.+)"
    
    -- Queue join patterns
    if queueMsg:find("joined the queue") or queueMsg:find("joined queue") or
       queueMsg:find("entering battleground") or queueMsg:find("entered battleground") or
       queueMsg:find("battlefield queue") then
        local bgType = "Unknown"
        -- Prefer full battleground names; avoid short abbreviations like \"av\" that can match words like \"have\"
        if queueMsg:find("alterac valley", 1, true) then
            bgType = "Alterac Valley"
        elseif queueMsg:find("warsong gulch", 1, true) then
            bgType = "Warsong Gulch"
        elseif queueMsg:find("arathi basin", 1, true) then
            bgType = "Arathi Basin"
        elseif queueMsg:find("eye of the storm", 1, true) then
            bgType = "Eye of the Storm"
        elseif queueMsg:find("strand of the ancients", 1, true) then
            bgType = "Strand of the Ancients"
        elseif queueMsg:find("isle of conquest", 1, true) then
            bgType = "Isle of Conquest"
        elseif queueMsg:find("arena", 1, true) or queueMsg:find("2v2", 1, true) or queueMsg:find("3v3", 1, true) or queueMsg:find("5v5", 1, true) then
            bgType = "Arena"
        end
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. "Joined the queue: |r" .. ColorQueue .. bgType .. "|r"), author, ...
    end

    if msg:match("^You are now saved to this instance%.?$") then
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. "Saved to instance|r"), author, ...
    end
    

    
    -- Victory/Defeat messages (suppress both)
    if queueMsg:find("victory") or queueMsg:find("win") or queueMsg:find("won") then
        if queueMsg:find("honor") or queueMsg:find("arena") or queueMsg:find("battleground") or queueMsg:find("battle") then
            return true
        end
    elseif queueMsg:find("defeat") or queueMsg:find("lose") or queueMsg:find("lost") then
        if queueMsg:find("honor") or queueMsg:find("arena") or queueMsg:find("battleground") or queueMsg:find("battle") then
            return true
        end
    end

    -- 4. Auction Messages
    if msg:lower():find("bid accepted") then
        return true
    end

    -- Buyer found messages - preserve item link and quality color from original msg
    -- Plain "Buyer found." (no visible item name)
    if msg == "Buyer found." or msg == "Buyer found" then
        local itemLink = GetItemLinkFromMessage(msg)
        if itemLink then
            local display = GetItemLinkWithQualityColor(itemLink)
            return false, SpaceBeforeX(prefixPlus .. ColorAuctionHouse .. "Buyer found: |r" .. display), author, ...
        end
        -- Fallback: we don't know the item; keep the original text but still apply the + prefix styling
        return false, SpaceBeforeX(prefixPlus .. msg), author, ...
    end

    local buyerItem = msg:match("A buyer has been found for your (.+)") or 
                     msg:match("Buyer found for your (.+)") or
                     msg:match("Buyer found: (.+)") or
                     msg:match("A buyer has been found for (.+)")
    if buyerItem then
        -- Normalize phrasing like "auction of Major Mana Potion" -> "Major Mana Potion"
        buyerItem = buyerItem:gsub("^auction of%s+", ""):gsub("^your auction of%s+", "")
        local itemLink = GetItemLinkFromMessage(msg)
        local display
        if itemLink then
            display = GetItemLinkWithQualityColor(itemLink)
        else
            -- Use the raw buyerItem so we don't strip the item link payload
            display = buyerItem
            if display and display:find("|Hitem:") then
                display = GetItemLinkWithQualityColor(display)
            elseif not display or not display:find("|H") then
                display = ColorWhite .. CleanPunctuation(StripBrackets(display or "")) .. "|r"
            end
        end
        return false, SpaceBeforeX(prefixPlus .. ColorAuctionHouse .. "Buyer found: |r" .. display), author, ...
    end

    -- Auction created / listed
    -- Plain "Auction created." (no visible item name) - hide this redundant line
    if msg == "Auction created." or msg == "Auction created" then
        return true
    end

    local createdItem = msg:match("Your auction of (.+) has been created") or
                        msg:match("Your auction of (.+) has been listed") or
                        msg:match("Auction created: (.+)") or
                        msg:match("Auction listed: (.+)") or
                        msg:match("You have created an auction for (.+)") or
                        msg:match("You have listed (.+)")
    if createdItem then
        local itemLink = GetItemLinkFromMessage(msg)
        local display
        if itemLink then
            display = GetItemLinkWithQualityColor(itemLink)
        else
            -- Use the raw createdItem so we don't strip the item link payload
            display = createdItem
            if display and display:find("|Hitem:") then
                display = GetItemLinkWithQualityColor(display)
            elseif not display or not display:find("|H") then
                display = ColorWhite .. CleanPunctuation(StripBrackets(display or "")) .. "|r"
            end
        end
        return false, SpaceBeforeX(prefixPlus .. ColorAuctionHouse .. "Auction created: |r" .. display), author, ...
    end

    -- Auction won (you bought something) - preserve item link for clickability (client stores link payload with original msg)
    local wonItem = msg:match("You won an auction for (.+)") or msg:match("You won auction for (.+)") or
                    msg:match("You have won the auction for (.+)") or msg:match("Auction won: (.+)") or
                    msg:match("Won auction: (.+)")
    if wonItem then
        -- Prepend prefix only so the original message (and its link) is unchanged; rebuilt links often aren't clickable
        if GetItemLinkFromMessage(msg) then
            return false, SpaceBeforeX(prefixPlus .. msg), author, ...
        end
        local display = ColorWhite .. CleanPunctuation(StripBrackets(wonItem)) .. "|r"
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. "Auction won: |r" .. display), author, ...
    end
    
    -- Auction expired messages
    local expiredItem = msg:match("Your auction of (.+) has expired") or
                       msg:match("Auction expired: (.+)") or
                       msg:match("Your auction of (.+) expired") or
                       msg:match("Auction for (.+) has expired")
    if expiredItem then
        local cleanItem = CleanPunctuation(StripBrackets(expiredItem))
        return false, SpaceBeforeX(prefixMinus .. ColorAuctionExpired .. "Auction expired: |r" .. ColorWhite .. cleanItem .. "|r"), author, ...
    end
    
    -- Cancelled auction messages
    local cancelledItem = msg:match("You cancelled your auction of (.+)") or
                          msg:match("Auction cancelled: (.+)") or
                          msg:match("Cancelled auction: (.+)")
    if cancelledItem then
        local cleanItem = CleanPunctuation(StripBrackets(cancelledItem))
        return false, SpaceBeforeX(prefixMinus .. "Auction cancelled: |r" .. ColorWhite .. cleanItem .. "|r"), author, ...
    end

    -- 5. Arena Points (message may contain color codes / item links, e.g. "|cff...|Hcurrency:1901|h[Arena Points]|h|r x580.")
    if (event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_CURRENCY") and type(msg) == "string" and msg:find("Arena Points") then
        -- Strip all WoW escape sequences (color codes, hyperlinks, brackets) for a clean match
        local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("[%[%]]", "")
        local arenaPoints =
            clean:match("You receive currency:%s*Arena Points%s*x(%d+)") or
            clean:match("You receive currency:%s*Arena Points%s+(%d+)") or
            clean:match("Arena Points%s*x(%d+)") or
            clean:match("(%d+)%s*[Aa]rena%s+[Pp]oints")

        if arenaPoints then
            return false, SpaceBeforeX(prefixPlus .. ColorWhite .. "Arena Points: |r" .. ColorPurple .. arenaPoints .. "|r"), author, ...
        end
    end

    -- 5a. Retail currency gains: "You receive currency: Voidlight Marl x207"
    if (event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_CURRENCY") and type(msg) == "string" then
        local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("[%[%]]", "")
        local moneyGain = ParseRetailMoneyGain(clean)
        if moneyGain and moneyGain > 0 then
            if event == "CHAT_MSG_CURRENCY" then
                return false, SpaceBeforeX(prefixPlus .. FormatMoney(moneyGain)), author, ...
            end
        else
            local gainedAmount, gainedCurrency = clean:match("^You gained:%s*(.-)%s+x(%d+)%s*%.?$")
            if not gainedAmount then
                gainedAmount, gainedCurrency = clean:match("^You gained:%s*x?(%d+)%s*(%D.+)%s*%.?$")
                if gainedAmount and gainedCurrency then
                    local formatted = FormatCurrencyGain(gainedAmount, gainedCurrency)
                    if formatted then
                        return false, formatted, author, ...
                    end
                end
            else
                local formatted = FormatCurrencyGain(gainedCurrency, gainedAmount)
                if formatted then
                    return false, formatted, author, ...
                end
            end

            local currency, currencyAmount = clean:match("You receive currency:%s*(.-)%s+x(%d+)%s*%.?$")
            if not currency then
                currency, currencyAmount = clean:match("You receive currency:%s*(.-)%s+(%d+)%s*%.?$")
            end
            if currency and currencyAmount then
                local formatted = FormatCurrencyGain(currencyAmount, currency)
                if formatted then
                    return false, formatted, author, ...
                end
            elseif clean:find("You receive currency:", 1, true) then
                currency = clean:match("You receive currency:%s*(.-)%s*%.?$")
                currency = currency and CleanPunctuation(currency:gsub("^%s+", ""):gsub("%s+$", ""))
                if currency and currency ~= "" then
                    local name, amount = currency:match("^(.-)%s*x(%d+)$")
                    if name and amount then
                        local formatted = FormatCurrencyGain(amount, name)
                        if formatted then
                            return false, formatted, author, ...
                        end
                    end

                    amount, name = currency:match("^x?(%d+)%s*(%D.+)$")
                    if amount and name then
                        local formatted = FormatCurrencyGain(amount, name)
                        if formatted then
                            return false, formatted, author, ...
                        end
                    end
                    return false, prefixPlus .. ColorCyan .. currency .. "|r", author, ...
                end
            end
        end
    end

    -- 4b. Suppress duplicate "items have been repaired" when we already showed repair cost as "- amount"
    if msg:lower():find("repaired") and msg:lower():find("item") and lastRepairAmount and (GetTime() - lastRepairTime) < REPAIR_DEDUP_SEC then
        return true
    end

    -- 5. Money (Gains show +, losses show -; Merchant is handled by direct tracking above)
    if (event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM") then
        local retailGain = ParseRetailMoneyGain(msg)
        if retailGain and retailGain > 0 then
            return true
        end

        local compactGold, compactSilver, compactCopper = msg:match("^You gained:%s*(%d+)%D+(%d+)%D+(%d+)%s*%.?$")
        if compactGold and compactSilver and compactCopper then
            local total = (tonumber(compactGold) or 0) * 10000 + (tonumber(compactSilver) or 0) * 100 + (tonumber(compactCopper) or 0)
            if total > 0 then
                return true
            end
        end

        local gold = tonumber(msg:match("(%d+) Gold") or msg:match("(%d+) gold")) or 0
        local silver = tonumber(msg:match("(%d+) Silver") or msg:match("(%d+) silver")) or 0
        local copper = tonumber(msg:match("(%d+) Copper") or msg:match("(%d+) copper")) or 0

        local total = gold * 10000 + silver * 100 + copper

        if total > 0 then
            -- While merchant is open: suppress money messages so AutoSellGreys/AutoRepair can print their styled lines
            if merchantFrame.isOpen then
                return true
            end
            -- Suppress per-letter money messages while mailbox is open (summary shown when closed)
            if mailTracker.isOpen then
                return true
            end
            
            local lowerMsg = msg:lower()
            local isGain = lowerMsg:find("receive") or lowerMsg:find("gain") or lowerMsg:find("reward") or
                lowerMsg:find("earned") or lowerMsg:find("earn") -- Removed "loot" and "obtained" to let item patterns handle them
            local isLoss = lowerMsg:find("lost") or lowerMsg:find("spent") or lowerMsg:find("paid") or lowerMsg:find("cost")
            local isRepair = lowerMsg:find("repair")
            
            if isGain or not isLoss then
                return false, SpaceBeforeX(prefixPlus .. FormatMoney(total)), author, ...
            else
                -- While merchant is open: suppress repair/loss so AutoRepair can print its styled line
                if merchantFrame.isOpen then
                    if isRepair then lastRepairAmount, lastRepairTime = total, GetTime() end
                    return true
                end
                if isRepair then
                    lastRepairAmount, lastRepairTime = total, GetTime()
                    return false, SpaceBeforeX((ColorMinus .. "-|r ") .. FormatMoney(total, ColorPalered)), author, ...
                end
                if lastRepairAmount and total == lastRepairAmount and (GetTime() - lastRepairTime) < REPAIR_DEDUP_SEC then
                    return true
                end
                return false, SpaceBeforeX(prefixMinus .. FormatMoney(total, ColorPalered)), author, ...
            end
        end
    end

    -- 5b. Loot Share Money (party/raid split)
    local shareGold = tonumber(msg:match("Your share of the loot is (%d+) gold") or 
                          msg:match("Your share of the loot is (%d+) Gold") or 
                          msg:match("Your share: (%d+) gold") or 
                          msg:match("Your share: (%d+) Gold")) or 0
    local shareSilver = tonumber(msg:match("Your share of the loot is %d+ gold, (%d+) silver") or 
                          msg:match("Your share of the loot is %d+ Gold, (%d+) Silver") or
                          msg:match("Your share: %d+ gold, (%d+) silver") or 
                          msg:match("Your share: %d+ Gold, (%d+) Silver")) or 0
    local shareCopper = tonumber(msg:match("Your share of the loot is %d+ gold, %d+ silver, (%d+) copper") or 
                             msg:match("Your share of the loot is %d+ Gold, %d+ Silver, (%d+) Copper") or
                             msg:match("Your share: %d+ gold, %d+ silver, (%d+) copper") or 
                             msg:match("Your share: %d+ Gold, %d+ Silver, (%d+) Copper")) or 0
    
    -- Also catch simpler "You receive X gold as your share" patterns
    local altGold = tonumber(msg:match("You receive (%d+) gold.*share") or 
                           msg:match("You receive (%d+) Gold.*share")) or 0
    local altSilver = tonumber(msg:match("You receive %d+ gold, (%d+) silver.*share") or 
                             msg:match("You receive %d+ Gold, (%d+) Silver.*share")) or 0
    local altCopper = tonumber(msg:match("You receive %d+ gold, %d+ silver, (%d+) copper.*share") or 
                              msg:match("You receive %d+ Gold, %d+ Silver, (%d+) Copper.*share")) or 0
    
    if (shareGold > 0 or shareSilver > 0 or shareCopper > 0) then
        local totalShare = shareGold * 10000 + shareSilver * 100 + shareCopper
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. "Loot Share: |r" .. FormatMoney(totalShare)), author, ...
    elseif (altGold > 0 or altSilver > 0 or altCopper > 0) then
        local totalAlt = altGold * 10000 + altSilver * 100 + altCopper
        return false, SpaceBeforeX(prefixPlus .. ColorWhite .. "Loot Share: |r" .. FormatMoney(totalAlt)), author, ...
    end

    -- 7. Learning Spells, Recipes, Abilities & Skill Increases
    local learned = msg:match("You have learned a new spell: (.+)") or msg:match("You have learned: (.+)") or
        msg:match("You have learned how to create:? (.+)") or msg:match("You have learned the recipe:? (.+)") or
        msg:match("Recipe learned: (.+)") or msg:match("You have learned a new ability: (.+)") or
        msg:match("You have learned the ability: (.+)") or msg:match("Ability learned: (.+)")
    if learned then
        local display = CleanPunctuation(StripBrackets(learned))
        display = display:gsub("^a new item: ", ""):gsub("^a new spell: ", ""):gsub("^a new ability: ", "")
        if display:match("%b()%s*$") then
            lastLearnedSkillName = NormalizeSkillName(display)
            lastLearnedSkillTime = GetTime and GetTime() or 0
        end
        return false,
            SpaceBeforeX(prefixPlus ..
            ColorWhite .. "Learned: " .. "|r" .. ColorPurple .. display .. "|r"), author,
            ...
    end

    -- 7a. Unlearning Talents, Spells, Abilities
    local unlearned = msg:match("You have unlearned: (.+)") or msg:match("You have unlearned (.+)") or
        msg:match("Talent unlearned: (.+)") or msg:match("You have forgotten: (.+)") or
        msg:match("You have forgotten (.+)") or msg:match("Spell unlearned: (.+)") or
        msg:match("Ability unlearned: (.+)")
    if unlearned then
        local display = CleanPunctuation(StripBrackets(unlearned))
        display = display:gsub("^a new item: ", ""):gsub("^a new spell: ", ""):gsub("^a new ability: ", "")
        return false,
            SpaceBeforeX(prefixMinus ..
            ColorWhite .. "Unlearned: " .. "|r" .. ColorPurple .. display .. "|r"), author,
            ...
    end

    -- Skill Learned: "You have gained the Subtlety skill."
    local gainedSkill = plainSys:match("[Yy]ou have gained the (.-) skill[%.,!]?%s*$")
    if gainedSkill then
        local display = CleanPunctuation(StripBrackets(gainedSkill))
        local now = GetTime and GetTime() or 0
        if lastLearnedSkillName and NormalizeSkillName(display) == lastLearnedSkillName and (now - lastLearnedSkillTime) <= LEARNED_SKILL_DEDUP_SEC then
            return true
        end
        return false,
            SpaceBeforeX(prefixPlus ..
            ColorWhite .. "Skill: |r" .. ColorPurple .. display .. "|r"), author, ...
    end

    -- Skill Increase: "Your skill in Bows has increased to 286."
    local skill, sRank = msg:match("Your skill in (.-) has increased to (%d+)")
    if skill and sRank then
        return false,
            SpaceBeforeX(prefixPlus ..
            ColorWhite .. sRank .. " Skill: |r" .. ColorPurple .. skill .. "|r"), author, ...
    end

    -- 6. Item Looting 
    -- Self loot and created items
    local item = msg:match("You receive loot: (.+)") or msg:match("You create: (.+)") or
        msg:match("You receive item: (.+)") or msg:match("You receive items: (.+)") or
        msg:match("You received item: (.+)") or msg:match("You received items: (.+)")
    if item then
        local display = FormatReceivedDisplay(item, msg)
        if display then
            return false, prefixPlus .. display, author, ...
        end
    end

    -- 6a. Generic receive messages not covered by Blizzard's loot globals:
    -- "You receive: Item", "You received Item x5", "You receive an item: Item", etc.
    if (event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_CURRENCY") and type(msg) == "string" then
        local receivePayload =
            msg:match("^[Yy]ou receive:%s*(.+)$") or
            msg:match("^[Yy]ou received:%s*(.+)$") or
            msg:match("^[Yy]ou receive an? item:%s*(.+)$") or
            msg:match("^[Yy]ou received an? item:%s*(.+)$") or
            msg:match("^[Yy]ou receive an?%s+(.+)$") or
            msg:match("^[Yy]ou received an?%s+(.+)$") or
            msg:match("^[Yy]ou receive%s+(.+)$") or
            msg:match("^[Yy]ou received%s+(.+)$")

        if receivePayload and not ShouldSkipGenericReceive(msg) then
            local display = FormatReceivedDisplay(receivePayload, msg)
            if display then
                return false, prefixPlus .. display, author, ...
            end
        end
    end

    -- Other player receives loot/creates: style as "Name: Item (2)" (runs for LOOT, PARTY, RAID, YELL so group loot is styled regardless of channel)
    local isGroupLootEvent = (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or
        event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_YELL")
    if isGroupLootEvent then
        local function styleGroupLoot(name, display)
            if not name or name == "" or name == "You" then return nil end
            local nameColor = GetClassColorForName(name)
            return SpaceBeforeX(nameColor .. name .. "|r" .. ColorLootLiteral .. ": " .. "|r" .. display)
        end
        local function buildDisplayFromMsg(message)
            local itemLink = GetItemLinkFromMessage(message)
            if itemLink then
                local d = GetItemLinkWithQualityColor(itemLink)
                d = SpaceBeforeX(d)
                local stackCount = message:match(" x(%d+)%s*%.?%s*$") or message:match("x(%d+)%s*%.?%s*$")
                if stackCount then d = d .. " " .. ColorPlus .. "(" .. stackCount .. ")|r" end
                return d
            end
            return nil
        end
        local plainLoot = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
        local lowerPlain = plainLoot:lower()
        -- 1) Try Blizzard global patterns
        for _, entry in ipairs(GroupLootPatterns) do
            local name, itemPart = plainLoot:match(entry.pattern)
            if name then
                name = name:gsub("^%s+", ""):gsub("%s+$", "")
                local display = buildDisplayFromMsg(msg)
                if not display then
                    display = CleanPunctuation(StripBrackets(itemPart or ""))
                    display = SpaceBeforeX(display)
                    display = FormatItemCountSuffix(display)
                end
                local out = styleGroupLoot(name, display)
                if out then return false, out, author, ... end
            end
        end
        -- 2) Fallback: literal "Name receives loot: ..." / "receives loot: ..." (name from message or author)
        local name, itemPart = plainLoot:match("^%s*(.-)%s+receives loot:%s*(.+)$") or
            plainLoot:match("^%s*(.-)%s+receives item:%s*(.+)$") or
            plainLoot:match("^%s*(.-)%s+creates:%s*(.+)$") or
            plainLoot:match("^%s*(.-)%s+conjures:%s*(.+)$")
        if name then
            name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "") -- trim and strip realm
            if name == "" and author and author ~= "" then name = author:gsub("%-.*$", "") end
        end
        if not name or name == "" then
            -- 3) Message may be "receives loot: [item]" with looter in author (common in PARTY/RAID)
            if (lowerPlain:find("receives loot:") or lowerPlain:find("receives item:") or lowerPlain:find(" creates:") or lowerPlain:find(" conjures:")) and author and author ~= "" then
                name = author:gsub("%-.*$", "")
                itemPart = msg -- keep links for buildDisplayFromMsg
            end
        end
        if name and name ~= "" and name ~= "You" then
            local display = buildDisplayFromMsg(msg)
            if not display and itemPart then
                display = CleanPunctuation(StripBrackets(itemPart:gsub("|H.-|h(.-)|h", "%1")))
                display = SpaceBeforeX(display)
                display = FormatItemCountSuffix(display)
            end
            if display then
                local out = styleGroupLoot(name, display)
                if out then return false, out, author, ... end
            end
        end
    end

    -- Loot roll messages: "Greed: Item", "Name Type roll N: Item", "Name won: Item", "Name passed on: Item"
    if event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM" then
        local playerName = UnitName("player") or ""
        local function stripTrailingLoot(display)
            if not display or type(display) ~= "string" then return display end
            return display:gsub("%s+[Ll]oot%s*$", ""):gsub("|r%s*$", "|r")
        end
        local plainRoll = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
        -- Strip leading channel/role tags like "[P]", "[R]", "[G]" so patterns can see "Loot: ..."
        local coreRoll = plainRoll:gsub("^%s*%b[]%s*", "")

        -- Simple fallback for selection/win lines that didn't match Blizzard globals, e.g.:
        -- "Loot: Name has selected Need: Item"
        -- "Loot: You have selected Greed for: Item"
        -- "Loot: Name won: Item"
        do
            -- First, handle your own "You have selected Greed/Need for: Item" line as robustly as possible.
            -- Use a loose, unanchored match so it works with prefixes like "[P] Loot:" and minor format differences.
            local looseYouType, looseYouItem =
                plainRoll:match("[Yy]ou%s+have%s+selected%s+(%S+).-[Ff]or%s*:?%s*(.+)$")
            if looseYouType and looseYouItem then
                local itemLink = GetItemLinkFromMessage(msg)
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(looseYouItem))
                local youColor = GetClassColorForName(UnitName("player") or "You")
                return false, SpaceBeforeX(youColor .. "You|r " .. looseYouType .. ": " .. display), author, ...
            end

            -- Very common explicit winner format:
            -- "Loot: Forestwar won: Libram of the Eternal Rest"
            -- Handle this up front in case it slips past Blizzard's LOOT_ROLL_WON globals.
            local directWinName, directWinItem =
                plainRoll:match("^%s*%b[]%s*[Ll]oot:%s*(%S+)%s+[Ww]on:%s*(.+)$") or
                plainRoll:match("^%s*[Ll]oot:%s*(%S+)%s+[Ww]on:%s*(.+)$")
            if directWinName and directWinItem then
                local isYou = directWinName:lower() == "you"
                local itemLink = GetItemLinkFromMessage(msg)
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(directWinItem))
                local nameOut
                if isYou then
                    local youColor = GetClassColorForName(UnitName("player") or "You")
                    nameOut = youColor .. "You|r"
                else
                    local short = directWinName:gsub("%-.*$", "")
                    nameOut = GetClassColorForName(short) .. short .. "|r"
                end
                return false, SpaceBeforeX(nameOut .. " won: " .. display), author, ...
            end

            -- Pass: "Loot: You passed on: Item" / "Loot: Name passed on: Item" -> always show as "Name passed: Item"
            local afterLootPass = coreRoll:match("^[^:]-:%s*(.+)$") or coreRoll
            local passName, passItem = afterLootPass:match("^(.-)%s+passed on[:%s]+(.+)$")
            if passName and passItem then
                passName = passName:gsub("^%s+", ""):gsub("%s+$", "")
                if passName ~= "" and passName ~= "Loot" then
                    local itemLink = GetItemLinkFromMessage(msg)
                    local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(passItem))
                    local isYou = passName:lower() == "you"
                    local nameOut
                    if isYou then
                        nameOut = GetClassColorForName(UnitName("player") or "You") .. "You|r"
                    else
                        local short = passName:gsub("%-.*$", "")
                        nameOut = GetClassColorForName(short) .. short .. "|r"
                    end
                    return false, SpaceBeforeX(nameOut .. " passed: " .. display), author, ...
                end
            end

            -- Selection lines, e.g.:
            -- "Loot: Name has selected Need: Item"
            -- "Loot: Name has selected Need for: Item"
            -- "Loot: Name has selected Greed: Item"
            -- Normalize everything after "Loot:" to a simple "Name has selected Type ...":
            local selName, selType, selItem
            do
                local afterLoot = coreRoll
                local lootPart = coreRoll:match("^[^:]-:%s*(.+)$")
                if lootPart then
                    afterLoot = lootPart
                end
                -- First try "Name has selected Type: Item"
                selName, selType, selItem =
                    afterLoot:match("^(.-)%s+has selected%s+(%S+)%s*:%s*(.+)$")
                if not selName then
                    -- Then try "Name has selected Type for: Item" or "Name has selected Type for Item"
                    selName, selType, selItem =
                        afterLoot:match("^(.-)%s+has selected%s+(%S+).-%s+for%s*:?%s*(.+)$")
                end
            end
            if selName and selType and selItem then
                selName = selName:gsub("^%s+", ""):gsub("%s+$", "")
                local isYou = selName:lower() == "you"
                local itemLink = GetItemLinkFromMessage(msg)
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(selItem))
                local nameOut
                if isYou then
                    local youColor = GetClassColorForName(UnitName("player") or "You")
                    nameOut = youColor .. "You|r"
                else
                    local short = selName:gsub("%-.*$", "")
                    nameOut = GetClassColorForName(short) .. short .. "|r"
                end
                -- "Name Need: Item" / "You Greed: Item"
                local mid = " " .. selType .. ": "
                return false, SpaceBeforeX(nameOut .. mid .. display), author, ...
            end
            -- Handle "Loot: You have selected Greed for: Item" (your client) and close variants.
            -- Normalize to the text after "Loot:" (if present), then look for "You have selected <Type> ... for: <Item>".
            local youType, youItem
            do
                local afterLoot = coreRoll
                local lootBody = coreRoll:match("^[^:]-:%s*(.+)$")
                if lootBody then
                    afterLoot = lootBody
                end
                -- Examples matched:
                -- "You have selected Greed for: Der'izu Helm of the Invoker"
                -- "You have selected Need for: Item"
                youType, youItem =
                    afterLoot:match("^[Yy]ou%s+have%s+selected%s+(%S+).-[Ff]or%s*: ?(.+)$") or
                    afterLoot:match("^[Yy]ou%s+have%s+selected%s+(%S+)%s+for%s+(.+)$")
            end
            if youType and youItem then
                local itemLink = GetItemLinkFromMessage(msg)
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(youItem))
                local youColor = GetClassColorForName(UnitName("player") or "You")
                -- "You Need: Item"
                return false, SpaceBeforeX(youColor .. "You|r " .. youType .. ": " .. display), author, ...
            end
            -- Winner lines with name first:
            -- Target the exact forms you see in-game, e.g.:
            -- "Loot: Casters won: Ravenclaw Band"
            -- Normalize after \"Loot:\" and then match \"Name won: Item\".
            local wonName, wonItem
            do
                local afterLoot = coreRoll
                local lootPart = coreRoll:match("^[^:]-:%s*(.+)$")
                if lootPart then
                    afterLoot = lootPart
                end
                -- 1) Exact \"Name won: Item\" (your current client format)
                wonName, wonItem = afterLoot:match("^(.-)%s+[Ww]on:%s*(.+)$")
                if not wonName then
                    -- 2) Fallback \"Name won Item\" (no colon after won)
                    wonName, wonItem = afterLoot:match("^(.-)%s+[Ww]on%s+(.+)$")
                end
                if not wonName then
                    -- 3) Bare \"Name won: Item\" without Loot prefix (just in case)
                    wonName, wonItem =
                        coreRoll:match("^(.-)%s+[Ww]on:%s*(.+)$") or
                        coreRoll:match("^(.-)%s+[Ww]on%s+(.+)$")
                end
            end
            if wonName and wonItem then
                wonName = wonName:gsub("^%s+", ""):gsub("%s+$", "")
                local isYou = wonName:lower() == "you"
                local itemLink = GetItemLinkFromMessage(msg)
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(wonItem))
                local nameOut
                if isYou then
                    local youColor = GetClassColorForName(UnitName("player") or "You")
                    nameOut = youColor .. "You|r"
                else
                    local short = wonName:gsub("%-.*$", "")
                    nameOut = GetClassColorForName(short) .. short .. "|r"
                end
                return false, SpaceBeforeX(nameOut .. " won: " .. display), author, ...
            end
            -- "Loot: Item won by Name" (item first, then winner)
            local wonItem2, wonBy = coreRoll:match("^%s*[Ll]oot:%s*(.-)%s+won by%s+(.+)$")
            if wonItem2 and wonBy then
                wonBy = wonBy:gsub("^%s+", ""):gsub("%s+$", "")
                local isYou = wonBy:lower() == "you"
                local itemLink = GetItemLinkFromMessage(msg)
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or CleanPunctuation(StripBrackets(wonItem2))
                local nameOut
                if isYou then
                    local youColor = GetClassColorForName(UnitName("player") or "You")
                    nameOut = youColor .. "You|r"
                else
                    local short = wonBy:gsub("%-.*$", "")
                    nameOut = GetClassColorForName(short) .. short .. "|r"
                end
                return false, SpaceBeforeX(nameOut .. " won: " .. display), author, ...
            end
        end
        local function rollTypeWord(literal)
            if not literal then return "Greed" end
            local lower = literal:lower()
            if lower:find("need") then return "Need" end
            if lower:find("greed") then return "Greed" end
            if lower:find("passed on") or lower:find("pass") then return "Pass" end
            if lower:find("disenchant") then return "Disenchant" end
            if lower:find(" won ") or lower:find(" wins ") then return "Won" end
            return "Greed"
        end
        local function buildRollDisplay(itemPart, fromMsg)
            local itemLink = GetItemLinkFromMessage(fromMsg or msg)
            local display
            if itemLink then
                display = GetItemLinkWithQualityColor(itemLink)
                display = SpaceBeforeX(display)
                local stackCount = (fromMsg or msg):match(" x(%d+)%s*(|r)?%s*$") or (fromMsg or msg):match(" x(%d+)%s* by ")
                if stackCount then display = display .. " " .. ColorPlus .. "(" .. stackCount .. ")|r" end
            else
                display = CleanPunctuation(StripBrackets(itemPart or ""))
                display = SpaceBeforeX(display)
                display = FormatItemCountSuffix(display)
            end
            return stripTrailingLoot(display)
        end
        local function tryRollEntry(entry, ...)
            local name, itemPart = coreRoll:match(entry.pattern)
            if name and name ~= "" then
                name = name:gsub("^%s+", ""):gsub("%s+$", "")
                if name:find("^Loot: ") then name = name:gsub("^Loot:%s*", ""):gsub("^%s+", ""):gsub("%s+$", "") end
                if name ~= "" and name ~= "Loot" then
                    local display = buildRollDisplay(itemPart, msg)
                    local isYou = (name == "You" or name == playerName)
                    local displayName = isYou and "You" or name
                    local shortName = name:gsub("%-.*$", "") -- strip realm
                    local nameColor = GetClassColorForName(displayName)
                    local typeWord = rollTypeWord(entry.literal)
                    local itemKey = getRollItemKey(itemPart, msg)

                    if typeWord == "Pass" then
                        return false, SpaceBeforeX(nameColor .. displayName .. "|r passed: " .. display), author, ...
                    end
                    if typeWord == "Won" then
                        clearRollItem(itemKey)
                        return false, SpaceBeforeX(nameColor .. displayName .. "|r won: " .. display), author, ...
                    end
                    -- Need / Greed / Disenchant
                    setRollType(itemKey, shortName, typeWord)
                    if isYou then setRollType(itemKey, "You", typeWord) end
                    if isYou then
                        local youColor = GetClassColorForName(UnitName("player") or "You")
                        return false, SpaceBeforeX(youColor .. "You|r selected " .. typeWord .. ": " .. display), author, ...
                    else
                        -- Other players: show their selection as "Name selected Type: Item" instead of suppressing
                        if display and display ~= "" then
                            return false, SpaceBeforeX(nameColor .. displayName .. "|r selected " .. typeWord .. ": " .. display), author, ...
                        end
                        return true -- fallback: suppress if we couldn't build a proper display
                    end
                end
            end
        end
        for _, entry in ipairs(RollPatterns) do
            local ok, a, b, c = tryRollEntry(entry, ...)
            if ok == false then return a, b, c end
            if ok == true then return true end -- suppressed
        end
        for _, entry in ipairs(RollPatternsFallback) do
            local ok, a, b, c = tryRollEntry(entry, ...)
            if ok == false then return a, b, c end
            if ok == true then return true end
        end
        -- "Name rolls N: Item" / "You roll N: Item" -> loot roll summary
        -- Also handles simple world /roll messages like "Name rolls N (1-100)"
        local rollName, rollNum, rollItemPart = coreRoll:match("^%s*(.-)%s+rolls?%s+(%d+)%s*:?%s*(.*)$")
        if rollName and rollNum and rollName ~= "" then
            rollName = rollName:gsub("^Loot:%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if rollName ~= "" and rollName ~= "Loot" then
                local itemKey = getRollItemKey(rollItemPart, msg)
                local isYouRoll = (rollName == "You" or rollName == playerName)

                -- Detect plain world /roll (no item, just range like "(1-100)")
                local isSimpleRange = (rollItemPart == nil or rollItemPart == "" or rollItemPart:match("^%(%d+%-%d+%)%s*$"))
                if isSimpleRange then
                    local rangeText = rollItemPart and rollItemPart:match("%(%d+%-%d+%)") or "(1-100)"
                    local blue = "|cff33aaff"
                    local reset = "|r"
                    if isYouRoll then
                        -- Blue world roll for you
                        return false, SpaceBeforeX(blue .. "You roll " .. rollNum .. " " .. rangeText .. reset), author, ...
                    else
                        local shortName = rollName:gsub("%-.*$", "")
                        -- Blue world roll for others (fixed color instead of class color)
                        return false, SpaceBeforeX(blue .. shortName .. " rolls " .. rollNum .. " " .. rangeText .. reset), author, ...
                    end
                end

                -- Loot roll with an item
                local rollType = getRollType(itemKey, isYouRoll and "You" or rollName:gsub("%-.*$", ""))
                local display = buildRollDisplay(rollItemPart, msg)
                if display and display ~= "" then
                    if isYouRoll then
                        local youColor = GetClassColorForName(UnitName("player") or "You")
                        -- "You roll 95: Item"
                        return false, SpaceBeforeX(youColor .. "You|r roll " .. rollNum .. ": " .. display), author, ...
                    else
                        local nameColor = GetClassColorForName(rollName)
                        -- "Name rolls 95: Item"
                        return false, SpaceBeforeX(nameColor .. rollName .. "|r rolls " .. rollNum .. ": " .. display), author, ...
                    end
                end
            end
        end
        -- Roll result: "... for Item. N - Name" / "Winner: Name" -> "Name Type roll N: Item" / "Name won: Item"
        local nameAtEnd = coreRoll:match(" by ([^|%[%]]+)%s*$") or coreRoll:match(" [Ww]inner:?%s+([^|%[%]]+)%s*$")
        if nameAtEnd then
            nameAtEnd = nameAtEnd:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            if nameAtEnd ~= "" then
                local isWinner = not not coreRoll:match(" [Ww]inner:?%s+[^|%[%]]+%s*$")
                local rollNum = coreRoll:match("(%d+)%s+for") or coreRoll:match("[--]%s*(%d+)%s*%.?%s*[Ww]inner") or coreRoll:match("[--]%s*(%d+)")
                local itemLink = GetItemLinkFromMessage(msg)
                local forPart = coreRoll:match(" for (.+) by ") or coreRoll:match(" for (.+)%.?%s*[Ww]inner") or ""
                local display = itemLink and GetItemLinkWithQualityColor(itemLink) or (CleanPunctuation(StripBrackets(forPart)))
                display = SpaceBeforeX(display)
                local stackCount = msg:match(" x(%d+)%s*(|r)?%s*$") or msg:match(" x(%d+)%s* by ") or msg:match(" x(%d+)%s*%.?%s*[Ww]inner")
                if stackCount then display = display .. " " .. ColorPlus .. "(" .. stackCount .. ")|r" end
                if not itemLink then display = FormatItemCountSuffix(display) end
                display = stripTrailingLoot(display)
                local itemKey = getRollItemKey(forPart, msg)
                local isYou = (nameAtEnd == playerName or nameAtEnd == "You")
                local displayName = isYou and "You" or nameAtEnd
                local shortName = nameAtEnd:gsub("%-.*$", "")
                local nameColor = GetClassColorForName(displayName)
                if isWinner then
                    clearRollItem(itemKey)
                    return false, SpaceBeforeX(nameColor .. displayName .. "|r won: " .. display), author, ...
                else
                    -- Non-winner roll summary from result line: "Name rolls 95: Item"
                    local rollType = getRollType(itemKey, shortName)
                    if isYou then
                        return false, SpaceBeforeX("You roll " .. (rollNum or "?") .. ": " .. display), author, ...
                    else
                        return false, SpaceBeforeX(nameColor .. displayName .. "|r rolls " .. (rollNum or "?") .. ": " .. display), author, ...
                    end
                end
            end
        end
    end

    -- 9. Quest Money Rewards - handle separately from generic rewards
    local lowerMsg = msg:lower()
    local gold = tonumber(msg:match("(%d+) Gold") or msg:match("(%d+) gold")) or 0
    local silver = tonumber(msg:match("(%d+) Silver") or msg:match("(%d+) silver")) or 0
    local copper = tonumber(msg:match("(%d+) Copper") or msg:match("(%d+) copper")) or 0

    if (gold > 0 or silver > 0 or copper > 0) then
        local total = gold * 10000 + silver * 100 + copper
        -- Check if this is a quest reward (contains quest-related keywords)
        local isQuestReward = lowerMsg:find("quest") or lowerMsg:find("reward") or lowerMsg:find("complete") or
            lowerMsg:find("turn in") or lowerMsg:find("finish")
        if isQuestReward then
            return false, SpaceBeforeX(prefixPlus .. FormatMoney(total)), author, ...
        end
    end

    -- 10. Refunds like \"You are refunded: Item x10.\" → \"Refunded: Item (10)\"
    do
        local refundItem, refundCount = msg:match("^You are refunded:%s*(.+)%sx(%d+)[%.%s]*$") or msg:match("^[Yy]ou are refunded:%s*(.+)%sx(%d+)[%.%s]*$")
        if refundItem and refundCount then
            local count = tonumber(refundCount) or 1
            local itemLink = GetItemLinkFromMessage(msg)
            local display
            if itemLink then
                display = GetItemLinkWithQualityColor(itemLink)
            else
                display = CleanPunctuation(StripBrackets(refundItem:gsub("x%d+","")))
            end
            display = SpaceBeforeX(display)
            return false, SpaceBeforeX(ColorWhite .. "Refunded: |r" .. display .. " " .. ColorPlus .. "(" .. count .. ")|r"), author, ...
        end
    end

    -- 11. Generic rewards (awarded, received, earned, rewarded, badges, marks, tokens, points, etc.)
    local lowerMsg = msg:lower()
    local rewardAmount, rewardType =
        msg:match("You have been awarded (%d+) (.+)") or
        msg:match("You have received (%d+) (.+)") or
        msg:match("You receive (%d+) (.+)") or
        msg:match("You gain (%d+) (.+)") or
        msg:match("You earn (%d+) (.+)") or
        msg:match("You were awarded (%d+) (.+)") or
        msg:match("Rewarded with (%d+) (.+)") or
        msg:match("Received (%d+) (.+)") or
        msg:match("(%d+) (.+) received") or
        msg:match("(%d+) (.+) awarded") or
        msg:match("(%d+) (.+) earned") or
        msg:match("(%d+) (.+) gained")
    if rewardAmount and rewardType then
        local skip = lowerMsg:find("experience") or lowerMsg:find(" gold") or lowerMsg:find(" silver") or
            lowerMsg:find(" copper") or lowerMsg:find("reputation") or lowerMsg:find("loot:") or
            rewardType:match("^[Ee]xperience") or rewardType:match("^[Gg]old") or rewardType:match("^[Ss]ilver") or
            rewardType:match("^[Cc]opper")
        if not skip and #rewardType:gsub("%s", "") > 0 then
            local clean = CleanPunctuation(StripBrackets(rewardType))
            if #clean > 0 then
                local isHonor = clean:lower():find("honor")
                local color = isHonor and ColorHonor or ColorCyan
                local display = isHonor and "Honor Points" or clean
                return false, SpaceBeforeX(prefixPlus .. ColorWhite .. rewardAmount .. " |r" .. color .. display .. "|r"), author, ...
            end
        end
    end

    -- 11. Pass through unchanged. If msg still contains Blizzard format placeholders (%s, %d),
    --     format it with variadic args so we never show literal "%s" in chat (default Blizz text).
    --     Skip this for monster emotes, which we pre-format above.
    if event ~= "CHAT_MSG_MONSTER_EMOTE" and type(msg) == "string" and (msg:find("%%s") or msg:find("%%d")) then
        local n = select("#", ...)
        local function try_format(...)
            local ok, res = pcall(string.format, msg, ...)
            return (ok and type(res) == "string" and not res:find("%%s")) and res or nil
        end
        local formatted = (n >= 1 and try_format(...)) or (author and author ~= "" and try_format(author))
        if formatted then
            msg = formatted
        end
    end
    return false, SpaceBeforeX(msg), author, ...
end

-- Safe wrapper so any Lua error in the filter doesn't trigger "Interface action failed because of an AddOn"
-- Must return ALL values from the filter (msg, author, arg4, arg5, ...); returning only 4 causes Blizzard's
-- MessageEventHandler to receive nil for trailing args and call strlen(nil) on CHAT_MSG_LOOT etc.
-- Coerce any nil to "" so Blizzard code that does strlen(arg) never gets nil.
local function ChatFilter(self, event, msg, author, ...)
    local function RunFilter(...)
        return pcall(ChatFilterImpl, ...)
    end
    local results
    if Carpenter and Carpenter.Profile then
        results = { Carpenter:Profile("ChatCleaner:Filter", RunFilter, self, event, msg, author, ...) }
    else
        results = { RunFilter(self, event, msg, author, ...) }
    end
    local ok = results[1]
    if not ok then
        return false, (msg or ""), (author or ""), ...
    end
    table.remove(results, 1)
    for i = 1, #results do
        if results[i] == nil then
            results[i] = ""
        end
    end
    return unpack(results)
end

-- =========================
-- AddMessage hook: style honor messages and suppress duplicates
-- =========================
local function StripColorCodes(t)
    if not t or type(t) ~= "string" then return "" end
    return t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
end

local lastStyledHonor = nil
local HONOR_DELAY = 3 -- seconds
local lastJoinKey, lastJoinTime = nil, nil
local JOIN_DEDUP_DELAY = 8 -- seconds (Blizzard can fire "Name has joined the battle" several seconds after our styled "Name joined")

local function HookChatFrameAddMessage(frame)
    if not frame or frame._CP_AddMessageHooked then return end
    local orig = frame.AddMessage
    if not orig then return end
    frame.AddMessage = function(self, msg, ...)
        if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then
            return orig(self, msg, ...)
        end

        local origMsg = msg
        local args = { ... }
        local ok = pcall(function()
            local function ProcessMessage()
            msg = ApplyChannelStyling(tostring(msg))
            msg = RemoveLinkBrackets(msg)
            msg = ClassColorPlayerNames(msg)
            msg = ClassColorLootRollNames(msg)
            local plain = StripColorCodes(msg)
            local lowerPlain = plain:lower()

            local styledLevelReward = FormatLevelUpRewardMessage(plain)
            if styledLevelReward then
                return orig(self, styledLevelReward, unpack(args))
            end

            if ParseRetailMoneyGain(plain) then
                return
            end

            -- Fully suppress remaining "Changed Channel" lines
            if plain:find("^Changed Channel:") then
                return
            end
            if plain:find("^Left Channel:") then
                return
            end
            -- Hide all Auctionator addon messages
            if plain:find("^Auctionator:") then
                return
            end

            -- Suppress duplicate "Name has joined the battle" (Blizzard often fires this seconds after our styled "Name joined")
            local isLongForm = plain:match("^%s*(.-)%s+has joined the battle%.?%s*$")
            local isShortForm = not plain:find("has joined the battle") and plain:match("^%s*(.-)%s+joined%s*$")
            local joinPlayers = plain:match("^(%d+)%s+players joined%s*$")
            local joinKey = nil
            if joinPlayers then
                joinKey = "players:" .. joinPlayers
            elseif isLongForm and isLongForm:gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
                joinKey = (isLongForm:gsub("^%s+", ""):gsub("%s+$", "")):lower()
            elseif isShortForm and isShortForm:gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
                joinKey = (isShortForm:gsub("^%s+", ""):gsub("%s+$", "")):lower()
            end
            if joinKey and lastJoinKey == joinKey and (GetTime() - lastJoinTime) < JOIN_DEDUP_DELAY then
                return -- suppress duplicate join message
            end
            -- Only record when we show our short form (or "N players joined") so the later Blizzard long form is suppressed
            if joinKey and (isShortForm or joinPlayers) then
                lastJoinKey, lastJoinTime = joinKey, GetTime()
            end

            -- Other person's loot (receives loot/creates/conjures): pass through with default colors (no restyling)

            -- Loot roll messages: pass through with default colors (no restyling)
            -- Check for honor messages and style them
            if plain:lower():find("honor") then
                local honor = msg:match("Estimated Honor Points: (%d+)") or msg:match("Honor Points: (%d+)") or
                    msg:match("honor points: (%d+)") or msg:match("Honor points: (%d+)") or
                    msg:match("honor points (%d+)") or msg:match("(%d+) honor points") or
                    msg:match("(%d+) honor point") or msg:match("(%d+) Honor Point") or
                    msg:match("(%d+) Honor Points") or msg:match("(%d+) honor") or
                    msg:match("honor: (%d+)") or msg:match("Honor: (%d+)") or msg:match("(%d+) Honor") or
                    msg:match("%+(%d+)%).*[Hh]onor") or msg:match("[Hh]onor.*%+(%d+)") or msg:match("(%d+).*[Hh]onor [Pp]oint") or
                    msg:match("%[Honor [Pp]oints%].*x(%d+)") or msg:match("x(%d+).*%[Honor [Pp]oints%]") or
                    msg:match("%[Honor [Pp]oints%].*(%d+)") or msg:match("currency.*[Hh]onor.*x(%d+)") or
                    msg:match("[Rr]eceive currency.*[Hh]onor.*(%d+)")
                
                if honor then
                    -- Check if this is a duplicate of our styled message
                    if lastStyledHonor and (GetTime() - lastStyledHonor) < HONOR_DELAY then
                        if not plain:find("^[%+%-]%s*%d+%s*%w*Honor") then
                            return -- suppress duplicate default message
                        end
                    else
                        -- Style the honor message
                        local styled = SpaceBeforeX((ColorPlus .. "+|r ") .. "|cffffffff" .. honor .. " |r|cffffffffHonor Points|r")
                        lastStyledHonor = GetTime()
                        return orig(self, styled, unpack(args))
                    end
                end
            end
            orig(self, msg, unpack(args))
            end

            if Carpenter and Carpenter.Profile then
                return Carpenter:Profile("ChatCleaner:AddMessage", ProcessMessage)
            end
            return ProcessMessage()
        end)
        if not ok then
            orig(self, origMsg, unpack(args))
        end
    end
    frame._CP_AddMessageHooked = true
end

-- =========================
-- Registration & Initialization
-- =========================
local function RegisterChatFilters()
    local chatEvents = {
        -- Combat/Log Events
        "CHAT_MSG_COMBAT_XP_GAIN",
        "CHAT_MSG_COMBAT_MISC_INFO",
        "CHAT_MSG_COMBAT_HONOR_GAIN",
        "CHAT_MSG_COMBAT_FACTION_CHANGE",
        "CHAT_MSG_MONEY",
        "CHAT_MSG_LOOT",
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_SKILL",
        "CHAT_MSG_BG_SYSTEM_ALLIANCE",
        "CHAT_MSG_BG_SYSTEM_HORDE",
        "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        "CHAT_MSG_AUCTION_LISTED",
        "CHAT_MSG_AUCTION_REMOVED",
        "CHAT_MSG_AUCTION_WON",
        "CHAT_MSG_AUCTION_OUTBIDDED",
        "CHAT_MSG_AUCTION_EXPIRED",
        "CHAT_MSG_AUCTION_CANCELLED",
        "CHAT_MSG_CURRENCY",
        -- Monster emotes (sanitize stray % format sequences before Blizzard formats them)
        "CHAT_MSG_MONSTER_EMOTE",
        -- Standard Chat Events for Bracket Removal
        "CHAT_MSG_CHANNEL",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_SAY",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_YELL",
    }
    for _, event in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(event, ChatFilter)
    end
end

-- =========================
-- Texture Removal (Clean EditBox)
-- =========================
local function CleanEditBox()
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            local regions = { eb:GetRegions() }
            for _, region in ipairs(regions) do
                if region:IsObjectType("Texture") then
                    region:SetTexture(nil)
                    region:SetAlpha(0)
                end
            end
            if eb.cp_bg then
                eb.cp_bg:Hide()
            end
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function(self, event)
    C_Timer.After(0, function()
        for i = 1, NUM_CHAT_WINDOWS do
            HookChatFrameAddMessage(_G["ChatFrame" .. i])
        end
    end)

    if Carpenter and Carpenter:IsEnabled("chatCleanerEnabled") then
        ApplyLevelUpGlobalStringStyling()
        RegisterChatFilters()
        CleanEditBox()
        mailTracker:Show()
    end

    -- Strip brackets from flags
    _G.CHAT_FLAG_AFK = "AFK "
    _G.CHAT_FLAG_DND = "DND "
end)
