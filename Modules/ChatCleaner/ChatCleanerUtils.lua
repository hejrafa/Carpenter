--[[ Carpenter - ChatCleaner utilities ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Utils = ns.Private.ChatCleanerUtils or {}
ns.Private.ChatCleanerUtils = Utils
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local LINK_OPEN  = "\255\255CP_L\255\255"
local LINK_CLOSE = "\255\255CP_R\255\255"
local PATTERN_MAGIC = "([%^%$%(%)%%%.%[%]%*%+%-%?])"

-- Chat Cleaner's palette, after Goldpaw's ChatCleaner
-- (github.com/GoldpawsStuff/ChatCleaner): gray + and − signs, white amounts
-- and labels, and an accent for each kind of thing named.
local Colors = ns.Private.Colors
local Palette = {
    gray         = Colors.gray.colorCode,     -- "+" and "−" signs, counts
    white        = Colors.white.colorCode,    -- amounts, labels, loot and roll words
    palered      = Colors.palered.colorCode,  -- money lost
    offwhite     = "|cfff0f0f0",              -- group lines with no group color
    yellow       = "|cffffd200",              -- quests, friends, the top level
    green        = "|cff00ff00",              -- joins, bare loot items
    orange       = "|cffff8000",
    darkorange   = "|cffff6600",
    red          = "|cffff0000",              -- the game's red, as on its Horde battleground lines
    purple       = "|cffb794f4",              -- skill and spell names
    transmog     = "|cffff80ff",              -- Blizzard's appearance collection pink
    bluePurple   = "|cff9d8cff",              -- reputation factions
    teal         = "|cff00ccaa",              -- discovered zones
    queue        = "|cff80b0ff",              -- battleground and queue names
    cyan         = "|cff00ccff",              -- generic rewards
    auctionHouse = "|cffffb347",              -- buyer found, auction created
    restedBar    = "|cff3399ff",              -- the XP bar's rested and normal blues
    normalBar    = "|cff9940ff",
}
Utils.Palette = Palette
Utils.PREFIX_PLUS = Palette.gray .. "+|r "
Utils.PREFIX_MINUS = Palette.gray .. Carpenter.MinusSign .. "|r "

-- Chat Cleaner's own words in the player's language, filled in the way
-- string.format would.
function Utils.T(key, ...)
    local text = Carpenter.L[key]
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

-- One of the game's own strings, or the fallback where this client has none.
function Utils.GameText(key, fallback)
    local text = _G[key]
    if type(text) == "string" and text ~= "" then return text end
    return fallback
end

function Utils.Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The text without its color codes, and its links as their words.
function Utils.StripColorsAndLinks(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

-- Whether chat messaging lockdown hides the game's lines from addons now.
function Utils.InChatLockdown()
    return Carpenter.Secret.ReadableBool(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) == true
end

function Utils.EscapePattern(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub(PATTERN_MAGIC, "%%%1")
end

-- The copper in the game's money receipt, "You gained: <money>"
-- (GENERIC_MONEY_GAINED_RECEIPT), written with coin icons, coin words or
-- letters, or bare amounts; nil for any other line, a currency included.
function Utils.ParseRetailMoneyGain(message)
    if type(message) ~= "string" or not message:find("You gained:", 1, true) then return nil end

    local text = message
        :gsub("|T.-UI%-GoldIcon.-|t", " gold")
        :gsub("|T.-UI%-SilverIcon.-|t", " silver")
        :gsub("|T.-UI%-CopperIcon.-|t", " copper")
        :gsub("|A:coin%-gold.-|a", " gold")
        :gsub("|A:coin%-silver.-|a", " silver")
        :gsub("|A:coin%-copper.-|a", " copper")
        :gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")

    local body = text:match("^You gained:%s*(.-)%s*%.?$")
    if not body or body == "" then return nil end
    -- "1,234 gold": thousands separators go, so the whole amount is read.
    body = body:gsub("(%d)[,%.](%d%d%d)%f[%D]", "%1%2"):gsub("(%d)[,%.](%d%d%d)%f[%D]", "%1%2")

    local gold = tonumber(body:match("(%d+)%s*[Gg]old%f[%A]") or body:match("(%d+)%s*g%f[%A]")) or 0
    local silver = tonumber(body:match("(%d+)%s*[Ss]ilver%f[%A]") or body:match("(%d+)%s*s%f[%A]")) or 0
    local copper = tonumber(body:match("(%d+)%s*[Cc]opper%f[%A]") or body:match("(%d+)%s*c%f[%A]")) or 0

    if gold > 0 or silver > 0 or copper > 0 then
        return gold * 10000 + silver * 100 + copper
    end

    -- Bare amounts ("1 23 45") only when the receipt holds nothing else.
    if not body:find("^[%d%s]+$") then return nil end
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

function Utils.StripBrackets(text)
    if not text or type(text) ~= "string" then return text end
    text = text:gsub("|h%[", "|h" .. LINK_OPEN)
    text = text:gsub("%]|h", LINK_CLOSE .. "|h")
    text = text:gsub("%[", ""):gsub("%]", "")
    text = text:gsub(LINK_OPEN, "["):gsub(LINK_CLOSE, "]")
    return text
end

function Utils.CleanPunctuation(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub("%.+$", "")
end

-- "Linen Clothx5" as "Linen Cloth x5".
function Utils.SpaceBeforeX(s)
    if not s or type(s) ~= "string" then return s end
    return (s:gsub("([^%s])x(%d+)", "%1 x%2"))
end

-- A color code from 0-1 red, green and blue.
function Utils.ColorCode(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255), math.floor((g or 1) * 255),
        math.floor((b or 1) * 255))
end

-- A class's color code, or nil for a class the game has no color for.
function Utils.ClassColorCode(classFile)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then return nil end
    if type(color.colorStr) == "string" then return "|c" .. color.colorStr end
    return Utils.ColorCode(color.r, color.g, color.b)
end

-- A chat type's color as the player set it, as a color code.
function Utils.ChatTypeColor(chatType, fallback)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if not info or not info.r then return fallback end
    return Utils.ColorCode(info.r, info.g, info.b)
end

-- The party or raid chat color, for group lines like "X joins".
function Utils.GroupColor()
    return Utils.ChatTypeColor(IsInRaid() and "RAID" or "PARTY", Palette.offwhite)
end

function Utils.GuildColor()
    return Utils.ChatTypeColor("GUILD", Palette.green)
end

-- The chat type of each party and raid chat event.
local GROUP_CHAT_TYPE_BY_EVENT = {
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER",
}
Utils.GROUP_CHAT_TYPE_BY_EVENT = GROUP_CHAT_TYPE_BY_EVENT

-- The color of loot and roll lines: the chat's own color in party or raid
-- chat, the group's color for loot and system lines in a group, else white.
function Utils.LootLineColor(event)
    local chatType = GROUP_CHAT_TYPE_BY_EVENT[event]
    if not chatType and (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM") and GetNumGroupMembers() > 0 then
        chatType = IsInRaid() and "RAID" or "PARTY"
    end
    return chatType and Utils.ChatTypeColor(chatType, Palette.white) or Palette.white
end

function Utils.RemoveLinkBrackets(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub("(|H.-|h)%[(.-)%]|h", "%1%2|h")
end

function Utils.GetItemLinkFromMessage(text)
    if not text or type(text) ~= "string" then return nil end
    return text:match("(|Hitem:[^|]+|h%[[^%]]*%]|h)") or text:match("(|Hitem:[^|]+|h[^|]*|h)")
end

function Utils.GetItemLinkWithQualityColor(itemLink)
    if not itemLink or not itemLink:find("|Hitem:") then return itemLink end
    if not GetItemInfo then return itemLink end

    local name, link, quality = GetItemInfo(itemLink)
    if link and link ~= "" then
        return link
    end

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
        return string.format("|cff%02x%02x%02x", r, g, b) .. itemLink .. "|r"
    end

    return itemLink
end

function Utils.FormatItemCountSuffix(text, countColor)
    if not text or type(text) ~= "string" then return text end

    local base, count = text:match("^(.-)%sx(%d+)$")
    if base and count then
        return base .. " " .. (countColor or Palette.gray) .. "(" .. count .. ")|r"
    end

    return text
end

function Utils.ShouldSkipGenericReceive(text)
    if not text or type(text) ~= "string" then return true end

    local lower = text:lower()
    return lower:find("currency:") or
        lower:find(" reputation") or
        lower:find("experience") or
        lower:find(" honor") or
        lower:find(" gold") or
        lower:find(" silver") or
        lower:find(" copper") or
        lower:find(" share")
end

function Utils.FormatReceivedDisplay(rawDisplay, sourceMessage, options)
    if not rawDisplay or rawDisplay == "" then return nil end
    options = options or {}

    local itemLink = Utils.GetItemLinkFromMessage(sourceMessage or rawDisplay)
    local display
    if itemLink then
        -- The link alone would drop a stack's count: "|h[Linen Cloth]|h|rx5".
        display = Utils.GetItemLinkWithQualityColor(itemLink)
        local count = rawDisplay:gsub("|r", ""):match("x(%d+)%s*%.?%s*$")
        if count then display = display .. " x" .. count end
    else
        display = Utils.CleanPunctuation(Utils.StripBrackets(rawDisplay))
    end
    display = display:gsub("^%s+", ""):gsub("%s+$", "")
    display = display:gsub("^an?%s+item:%s*", "")
    display = display:gsub("^item:%s*", "")
    display = display:gsub("^loot:%s*", "")
    display = Utils.SpaceBeforeX(display)
    display = Utils.FormatItemCountSuffix(display, options.CountColor)

    if display == "" then return nil end
    return display
end

function Utils.MakeFormatPattern(fmt, fields, options)
    if not fmt or type(fmt) ~= "string" then return nil end
    fields = fields or {}
    options = options or {}

    local pattern = options.AnchorStart and "^%s*" or ""
    local captureFields = {}
    local cursor = 1
    local ordinal = 1

    while cursor <= #fmt do
        local percent = fmt:find("%", cursor, true)
        if not percent then
            pattern = pattern .. Utils.EscapePattern(fmt:sub(cursor))
            break
        end

        if percent > cursor then
            pattern = pattern .. Utils.EscapePattern(fmt:sub(cursor, percent - 1))
        end

        local nextChar = fmt:sub(percent + 1, percent + 1)
        if nextChar == "%" then
            pattern = pattern .. "%%"
            cursor = percent + 2
        else
            local token = fmt:match("^%%(%d+%$?[sd])", percent)
            if not token then
                token = fmt:match("^%%([sd])", percent)
            end

            if token then
                local position = token:match("^(%d+)%$")
                local field = fields[position and tonumber(position) or ordinal]
                captureFields[#captureFields + 1] = field
                ordinal = ordinal + 1

                if token:sub(-1) == "d" then
                    pattern = pattern .. "(%d+)"
                else
                    pattern = pattern .. "(.+)"
                end
                cursor = percent + #token + 1
            else
                pattern = pattern .. "%%"
                cursor = percent + 1
            end
        end
    end

    if options.AnchorEnd then
        pattern = pattern .. "%s*$"
    end

    return pattern, captureFields
end
