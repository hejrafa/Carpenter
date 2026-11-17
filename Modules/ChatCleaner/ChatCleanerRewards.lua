--[[ Carpenter - ChatCleaner auction/currency/reward helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Rewards = ns.Private.ChatCleanerRewards or {}
ns.Private.ChatCleanerRewards = Rewards

-- The chat filter also sees what players say, so only the game's own lines count,
-- and only from the start of the line.
local GENERIC_REWARD_EVENTS = {
    CHAT_MSG_SYSTEM = true,
    CHAT_MSG_CURRENCY = true,
    CHAT_MSG_LOOT = true,
    CHAT_MSG_COMBAT_HONOR_GAIN = true,
    CHAT_MSG_COMBAT_MISC_INFO = true,
    -- WoW Forever reports "You gain 100 Rank Points." as a reputation line.
    CHAT_MSG_COMBAT_FACTION_CHANGE = true,
}

local GENERIC_REWARD_PATTERNS = {
    "^You have been awarded (%d+) (.+)",
    "^You have received (%d+) (.+)",
    "^You receive (%d+) (.+)",
    "^You gain (%d+) (.+)",
    "^You earn (%d+) (.+)",
    "^You were awarded (%d+) (.+)",
    "^Rewarded with (%d+) (.+)",
    "^Received (%d+) (.+)",
}

function Rewards.Create(config)
    config = config or {}
    local cleanPunctuation = config.CleanPunctuation or function(text) return text end
    local stripBrackets = config.StripBrackets or function(text) return text end
    local spaceBeforeX = config.SpaceBeforeX or function(text) return text end
    local getItemLinkFromMessage = config.GetItemLinkFromMessage or function() return nil end
    local getItemLinkWithQualityColor = config.GetItemLinkWithQualityColor or function(link) return link end
    local parseRetailMoneyGain = config.ParseRetailMoneyGain or function() return nil end
    local formatMoney = config.FormatMoney or function(amount) return tostring(amount or 0) end
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorWhite = config.ColorWhite or "|cffffffff"
    local colorCyan = config.ColorCyan or "|cff00ccff"
    local colorPurple = config.ColorPurple or "|cffb794f4"
    local colorHonor = config.ColorHonor or "|cffff0000"
    local colorPalered = config.ColorPalered or "|cffcc8080"
    local colorMinus = config.ColorMinus or "|cffc8c8c8"
    local colorAuctionHouse = config.ColorAuctionHouse or "|cffffb347"
    local colorAuctionExpired = config.ColorAuctionExpired or "|cffff0000"
    local merchantFrame = config.MerchantFrame or {}
    local mailTracker = config.MailTracker or {}
    local repairDedupSeconds = config.RepairDedupSeconds or 2
    local L = config.L or (Carpenter and Carpenter.L) or {}
    local lastRepairAmount, lastRepairTime = nil, 0

    local api = {}

    local function T(key, fallback, ...)
        local text = L[key] or fallback or key
        if select("#", ...) > 0 then
            return string.format(text, ...)
        end
        return text
    end

    -- "5 Gold, 2 Silver" as copper. The coin word has to end there, so
    -- "5 Golden Tokens" isn't money.
    local function ParseMoneyAmount(message)
        local gold = tonumber(message:match("(%d+) [Gg]old%f[%A]")) or 0
        local silver = tonumber(message:match("(%d+) [Ss]ilver%f[%A]")) or 0
        local copper = tonumber(message:match("(%d+) [Cc]opper%f[%A]")) or 0
        return gold * 10000 + silver * 100 + copper
    end

    local function StripMarkup(message)
        return (message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("[%[%]]", ""))
    end

    local function FormatCurrencyGain(amount, currency)
        amount = amount and tostring(amount)
        currency = currency and tostring(currency)
        if not amount or amount == "" or not currency or currency == "" then return nil end

        currency = cleanPunctuation(currency:gsub("^%s+", ""):gsub("%s+$", ""))
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

        return (colorPlus .. "+|r ") .. colorCyan .. currency .. "|r " .. colorWhite .. "x" .. amount .. "|r"
    end

    function api.FormatCurrencyMessage(event, message, prefixPlus)
        if not (event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_CURRENCY") or type(message) ~= "string" then return nil end

        local clean = StripMarkup(message)
        if clean:find("Arena Points", 1, true) then
            local arenaPoints = clean:match("Arena Points%s*x?(%d+)") or clean:match("(%d+)%s*Arena Points")
            if arenaPoints then
                return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_ARENA_POINTS_LABEL", "Arena Points:") .. " |r" .. colorPurple .. arenaPoints .. "|r")
            end
        end

        local moneyGain = parseRetailMoneyGain(clean)
        if moneyGain and moneyGain > 0 then
            if event == "CHAT_MSG_CURRENCY" then
                return spaceBeforeX(prefixPlus .. formatMoney(moneyGain))
            end
            return nil
        end

        local gainedName, gainedAmount = clean:match("^You gained:%s*(.-)%s+x(%d+)%s*%.?$")
        if gainedName then
            return FormatCurrencyGain(gainedAmount, gainedName)
        end
        gainedAmount, gainedName = clean:match("^You gained:%s*x?(%d+)%s*(%D.+)%s*%.?$")
        if gainedAmount then
            return FormatCurrencyGain(gainedAmount, gainedName)
        end

        local currency, currencyAmount = clean:match("You receive currency:%s*(.-)%s+x(%d+)%s*%.?$")
        if not currency then
            currency, currencyAmount = clean:match("You receive currency:%s*(.-)%s+(%d+)%s*%.?$")
        end
        if currency and currencyAmount then
            return FormatCurrencyGain(currencyAmount, currency)
        elseif clean:find("You receive currency:", 1, true) then
            currency = clean:match("You receive currency:%s*(.-)%s*%.?$")
            currency = currency and cleanPunctuation(currency:gsub("^%s+", ""):gsub("%s+$", ""))
            if currency and currency ~= "" then
                local name, amount = currency:match("^(.-)%s*x(%d+)$")
                if name and amount then
                    return FormatCurrencyGain(amount, name)
                end

                amount, name = currency:match("^x?(%d+)%s*(%D.+)$")
                if amount and name then
                    return FormatCurrencyGain(amount, name)
                end
                return prefixPlus .. colorCyan .. currency .. "|r"
            end
        end

        return nil
    end

    function api.FormatMoneyMessage(event, message, prefixPlus, prefixMinus)
        if not (event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM") or type(message) ~= "string" then return nil end

        local lowerMessage = message:lower()
        if lowerMessage:find("repaired") and lowerMessage:find("item") and lastRepairAmount and (GetTime() - lastRepairTime) < repairDedupSeconds then
            return true
        end

        -- Retail's "You gained:" receipt repeats Chat Cleaner's own money lines.
        local retailGain = parseRetailMoneyGain(message)
        if retailGain and retailGain > 0 then
            return true
        end

        local total = ParseMoneyAmount(message)
        if total <= 0 then return nil end

        if merchantFrame.isOpen or mailTracker.isOpen then
            return true
        end

        local isGain = lowerMessage:find("receive") or lowerMessage:find("gain") or lowerMessage:find("reward") or
            lowerMessage:find("earn")
        local isLoss = lowerMessage:find("lost") or lowerMessage:find("spent") or lowerMessage:find("paid") or lowerMessage:find("cost")
        local isRepair = lowerMessage:find("repair")

        if isGain or not isLoss then
            return spaceBeforeX(prefixPlus .. formatMoney(total))
        end

        if isRepair then
            lastRepairAmount, lastRepairTime = total, GetTime()
        elseif lastRepairAmount and total == lastRepairAmount and (GetTime() - lastRepairTime) < repairDedupSeconds then
            return true
        end
        return spaceBeforeX(prefixMinus .. formatMoney(total, colorPalered))
    end

    -- An auction's item: its link in quality color, else the name in white.
    local function FormatAuctionDisplay(rawItem, sourceMessage)
        local itemLink = getItemLinkFromMessage(sourceMessage or rawItem or "")
        if itemLink then
            return getItemLinkWithQualityColor(itemLink)
        end

        local display = rawItem
        if display and display:find("|Hitem:") then
            return getItemLinkWithQualityColor(display)
        end
        if not display or not display:find("|H") then
            return colorWhite .. cleanPunctuation(stripBrackets(display or "")) .. "|r"
        end
        return display
    end

    function api.FormatAuctionMessage(message, prefixPlus, prefixMinus)
        if not message or type(message) ~= "string" then return nil end

        if message:lower():find("bid accepted") then
            return true
        end

        if message == "Buyer found." or message == "Buyer found" then
            return spaceBeforeX(prefixPlus .. message)
        end

        local buyerItem = message:match("A buyer has been found for your (.+)") or
            message:match("Buyer found for your (.+)") or
            message:match("Buyer found: (.+)") or
            message:match("A buyer has been found for (.+)")
        if buyerItem then
            buyerItem = buyerItem:gsub("^auction of%s+", ""):gsub("^your auction of%s+", "")
            local display = FormatAuctionDisplay(buyerItem, message)
            return spaceBeforeX(prefixPlus .. colorAuctionHouse .. T("CHAT_BUYER_FOUND_LABEL", "Buyer found:") .. " |r" .. display)
        end

        if message == "Auction created." or message == "Auction created" then
            return true
        end

        local createdItem = message:match("Your auction of (.+) has been created") or
            message:match("Your auction of (.+) has been listed") or
            message:match("Auction created: (.+)") or
            message:match("Auction listed: (.+)") or
            message:match("You have created an auction for (.+)") or
            message:match("You have listed (.+)")
        if createdItem then
            local display = FormatAuctionDisplay(createdItem, message)
            return spaceBeforeX(prefixPlus .. colorAuctionHouse .. T("CHAT_AUCTION_CREATED_LABEL", "Auction created:") .. " |r" .. display)
        end

        local wonItem = message:match("You won an auction for (.+)") or
            message:match("You won auction for (.+)") or
            message:match("You have won the auction for (.+)") or
            message:match("Auction won: (.+)") or
            message:match("Won auction: (.+)")
        if wonItem then
            local display = FormatAuctionDisplay(wonItem, message)
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_AUCTION_WON_LABEL", "Auction won:") .. " |r" .. display)
        end

        local expiredItem = message:match("Your auction of (.+) has expired") or
            message:match("Auction expired: (.+)") or
            message:match("Your auction of (.+) expired") or
            message:match("Auction for (.+) has expired")
        if expiredItem then
            local display = FormatAuctionDisplay(expiredItem, message)
            return spaceBeforeX(prefixMinus .. colorAuctionExpired .. T("CHAT_AUCTION_EXPIRED_LABEL", "Auction expired:") .. " |r" .. display)
        end

        local cancelledItem = message:match("You cancelled your auction of (.+)") or
            message:match("Auction cancelled: (.+)") or
            message:match("Cancelled auction: (.+)")
        if cancelledItem then
            local display = FormatAuctionDisplay(cancelledItem, message)
            return spaceBeforeX(prefixMinus .. colorWhite .. T("CHAT_AUCTION_CANCELLED_LABEL", "Auction cancelled:") .. " |r" .. display)
        end

        return nil
    end

    -- "You are refunded: Badge of Justice x10." as "Refunded: Badge of Justice (10)".
    function api.FormatRefundMessage(message)
        if type(message) ~= "string" then return nil end
        local refundItem, refundCount = message:match("^[Yy]ou are refunded:%s*(.+)%sx(%d+)[%.%s]*$")
        if not refundItem then return nil end

        local itemLink = getItemLinkFromMessage(message)
        local display = itemLink and getItemLinkWithQualityColor(itemLink) or cleanPunctuation(stripBrackets(refundItem))
        return spaceBeforeX(colorWhite .. T("CHAT_REFUNDED_LABEL", "Refunded:") .. " |r" .. display .. " " .. colorPlus .. "(" .. refundCount .. ")|r")
    end

    function api.FormatGenericReward(event, message, prefixPlus)
        if not GENERIC_REWARD_EVENTS[event] then return nil end

        local lowerMsg = message:lower()
        local rewardAmount, rewardType
        for _, pattern in ipairs(GENERIC_REWARD_PATTERNS) do
            rewardAmount, rewardType = message:match(pattern)
            if rewardAmount then break end
        end

        if not rewardAmount or not rewardType then return nil end

        local skip = lowerMsg:find("experience") or lowerMsg:find(" gold%f[%A]") or lowerMsg:find(" silver%f[%A]") or
            lowerMsg:find(" copper%f[%A]") or lowerMsg:find("reputation") or lowerMsg:find("loot:")
        if skip or not rewardType:find("%S") then return nil end

        local clean = cleanPunctuation(stripBrackets(rewardType))
        if #clean <= 0 then return nil end

        local lowerClean = clean:lower()
        local isHonor = lowerClean == "honor" or lowerClean:find("^honor points?$")
        local isRankPoints = lowerClean:find("^rank points?$")
        local color = isHonor and colorHonor or isRankPoints and colorWhite or colorCyan
        local display = isHonor and T("CHAT_HONOR_POINTS", "Honor Points") or
            isRankPoints and T("CHAT_RANK_POINTS", "Rank Points") or clean
        return spaceBeforeX(prefixPlus .. colorWhite .. rewardAmount .. " |r" .. color .. display .. "|r")
    end

    return api
end
