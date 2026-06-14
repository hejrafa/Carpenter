--[[ Carpenter - ChatCleaner utilities ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Utils = ns.Private.ChatCleanerUtils or {}
ns.Private.ChatCleanerUtils = Utils

local LINK_OPEN  = "\255\255CP_L\255\255"
local LINK_CLOSE = "\255\255CP_R\255\255"
local PATTERN_MAGIC = "([%^%$%(%)%%%.%[%]%*%+%-%?])"

function Utils.EscapePattern(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub(PATTERN_MAGIC, "%%%1")
end

function Utils.ParseRetailMoneyGain(message)
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

function Utils.SpaceBeforeX(s)
    if not s or type(s) ~= "string" then return s end
    return s:gsub("(|r)x(%d+)", "%1 x%2"):gsub("([^%s])x(%d+)", "%1 x%2")
end

function Utils.GetFirstPlayerLink(text)
    if not text or type(text) ~= "string" then return nil end
    return text:match("(|Hplayer:[^|]+|h%[[^%]]*%]|h)") or text:match("(|Hplayer:[^|]+|h[^|]*|h)")
end

function Utils.RemoveLinkBrackets(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub("(|H.-|h)%[(.-)%]|h", "%1%2|h")
end

function Utils.GetItemLinkFromMessage(text)
    if not text or type(text) ~= "string" then return nil end
    return text:match("(|Hitem:[^|]+|h%[[^%]]*%]|h)") or text:match("(|Hitem:[^|]+|h[^|]*|h)")
end

function Utils.FormatMoney(amount, amountColor, icons)
    amountColor = amountColor or "|cffffffff"
    icons = icons or {}

    local gold = floor(amount / 10000)
    local silver = floor((amount % 10000) / 100)
    local copper = amount % 100
    local text = ""

    if gold > 0 then
        text = text .. amountColor .. gold .. "|r " .. (icons.Gold or "") .. " "
    end
    if silver > 0 or gold > 0 then
        text = text .. amountColor .. silver .. "|r " .. (icons.Silver or "") .. " "
    end

    return text .. amountColor .. copper .. "|r " .. (icons.Copper or "")
end

function Utils.GetItemLinkWithQualityColor(itemLink)
    if not itemLink or not itemLink:find("|Hitem:") then return itemLink end

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
        return base .. " " .. (countColor or "|cffc8c8c8") .. "(" .. count .. ")|r"
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
        lower:find("your share") or
        lower:find(" share")
end

function Utils.FormatReceivedDisplay(rawDisplay, sourceMessage, options)
    if not rawDisplay or rawDisplay == "" then return nil end
    options = options or {}

    local itemLink = Utils.GetItemLinkFromMessage(sourceMessage or rawDisplay)
    local display = itemLink and Utils.GetItemLinkWithQualityColor(itemLink) or Utils.CleanPunctuation(Utils.StripBrackets(rawDisplay))
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

function Utils.MakeLootPattern(fmt)
    return Utils.MakeFormatPattern(fmt)
end
