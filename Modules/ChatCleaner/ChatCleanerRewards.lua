--[[ Carpenter - ChatCleaner auction/currency/reward helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Rewards = ns.Private.ChatCleanerRewards or {}
ns.Private.ChatCleanerRewards = Rewards

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
    local colorHonor = config.ColorHonor or "|cffff4040"
    local colorPalered = config.ColorPalered or "|cffcc8080"
    local colorMinus = config.ColorMinus or "|cffc8c8c8"
    local colorAuctionHouse = config.ColorAuctionHouse or "|cffffb347"
    local colorAuctionExpired = config.ColorAuctionExpired or "|cffff4040"
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

    local function ParseMoneyAmount(message)
        local gold = tonumber(message:match("(%d+) Gold") or message:match("(%d+) gold")) or 0
        local silver = tonumber(message:match("(%d+) Silver") or message:match("(%d+) silver")) or 0
        local copper = tonumber(message:match("(%d+) Copper") or message:match("(%d+) copper")) or 0
        return gold * 10000 + silver * 100 + copper
    end

    function api.FormatCurrencyGain(amount, currency)
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

        if message:find("Arena Points", 1, true) then
            local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("[%[%]]", "")
            local arenaPoints =
                clean:match("You receive currency:%s*Arena Points%s*x(%d+)") or
                clean:match("You receive currency:%s*Arena Points%s+(%d+)") or
                clean:match("Arena Points%s*x(%d+)") or
                clean:match("(%d+)%s*[Aa]rena%s+[Pp]oints")

            if arenaPoints then
                return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_ARENA_POINTS_LABEL", "Arena Points:") .. " |r" .. colorPurple .. arenaPoints .. "|r")
            end
        end

        local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("[%[%]]", "")
        local moneyGain = parseRetailMoneyGain(clean)
        if moneyGain and moneyGain > 0 then
            if event == "CHAT_MSG_CURRENCY" then
                return spaceBeforeX(prefixPlus .. formatMoney(moneyGain))
            end
            return nil
        end

        local gainedAmount, gainedCurrency = clean:match("^You gained:%s*(.-)%s+x(%d+)%s*%.?$")
        if not gainedAmount then
            gainedAmount, gainedCurrency = clean:match("^You gained:%s*x?(%d+)%s*(%D.+)%s*%.?$")
            if gainedAmount and gainedCurrency then
                return api.FormatCurrencyGain(gainedAmount, gainedCurrency)
            end
        else
            return api.FormatCurrencyGain(gainedCurrency, gainedAmount)
        end

        local currency, currencyAmount = clean:match("You receive currency:%s*(.-)%s+x(%d+)%s*%.?$")
        if not currency then
            currency, currencyAmount = clean:match("You receive currency:%s*(.-)%s+(%d+)%s*%.?$")
        end
        if currency and currencyAmount then
            return api.FormatCurrencyGain(currencyAmount, currency)
        elseif clean:find("You receive currency:", 1, true) then
            currency = clean:match("You receive currency:%s*(.-)%s*%.?$")
            currency = currency and cleanPunctuation(currency:gsub("^%s+", ""):gsub("%s+$", ""))
            if currency and currency ~= "" then
                local name, amount = currency:match("^(.-)%s*x(%d+)$")
                if name and amount then
                    return api.FormatCurrencyGain(amount, name)
                end

                amount, name = currency:match("^x?(%d+)%s*(%D.+)$")
                if amount and name then
                    return api.FormatCurrencyGain(amount, name)
                end
                return prefixPlus .. colorCyan .. currency .. "|r"
            end
        end

        return nil
    end

    function api.FormatLootShareMoney(message, prefixPlus)
        if not message or type(message) ~= "string" then return nil end

        local shareGold = tonumber(message:match("Your share of the loot is (%d+) gold") or
            message:match("Your share of the loot is (%d+) Gold") or
            message:match("Your share: (%d+) gold") or
            message:match("Your share: (%d+) Gold")) or 0
        local shareSilver = tonumber(message:match("Your share of the loot is %d+ gold, (%d+) silver") or
            message:match("Your share of the loot is %d+ Gold, (%d+) Silver") or
            message:match("Your share: %d+ gold, (%d+) silver") or
            message:match("Your share: %d+ Gold, (%d+) Silver")) or 0
        local shareCopper = tonumber(message:match("Your share of the loot is %d+ gold, %d+ silver, (%d+) copper") or
            message:match("Your share of the loot is %d+ Gold, %d+ Silver, (%d+) Copper") or
            message:match("Your share: %d+ gold, %d+ silver, (%d+) copper") or
            message:match("Your share: %d+ Gold, %d+ Silver, (%d+) Copper")) or 0

        local altGold = tonumber(message:match("You receive (%d+) gold.*share") or
            message:match("You receive (%d+) Gold.*share")) or 0
        local altSilver = tonumber(message:match("You receive %d+ gold, (%d+) silver.*share") or
            message:match("You receive %d+ Gold, (%d+) Silver.*share")) or 0
        local altCopper = tonumber(message:match("You receive %d+ gold, %d+ silver, (%d+) copper.*share") or
            message:match("You receive %d+ Gold, %d+ Silver, (%d+) Copper.*share")) or 0

        if shareGold > 0 or shareSilver > 0 or shareCopper > 0 then
            local totalShare = shareGold * 10000 + shareSilver * 100 + shareCopper
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_LOOT_SHARE_LABEL", "Loot Share:") .. " |r" .. formatMoney(totalShare))
        elseif altGold > 0 or altSilver > 0 or altCopper > 0 then
            local totalAlt = altGold * 10000 + altSilver * 100 + altCopper
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_LOOT_SHARE_LABEL", "Loot Share:") .. " |r" .. formatMoney(totalAlt))
        end

        return nil
    end

    function api.FormatMoneyMessage(event, message, prefixPlus, prefixMinus)
        if not (event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM") or type(message) ~= "string" then return nil end

        local lowerMessage = message:lower()
        if lowerMessage:find("repaired") and lowerMessage:find("item") and lastRepairAmount and (GetTime() - lastRepairTime) < repairDedupSeconds then
            return true
        end

        local retailGain = parseRetailMoneyGain(message)
        if retailGain and retailGain > 0 then
            return true
        end

        local compactGold, compactSilver, compactCopper = message:match("^You gained:%s*(%d+)%D+(%d+)%D+(%d+)%s*%.?$")
        if compactGold and compactSilver and compactCopper then
            local total = (tonumber(compactGold) or 0) * 10000 + (tonumber(compactSilver) or 0) * 100 + (tonumber(compactCopper) or 0)
            if total > 0 then return true end
        end

        local total = ParseMoneyAmount(message)
        if total <= 0 then return nil end

        if merchantFrame.isOpen or mailTracker.isOpen then
            return true
        end

        local isGain = lowerMessage:find("receive") or lowerMessage:find("gain") or lowerMessage:find("reward") or
            lowerMessage:find("earned") or lowerMessage:find("earn")
        local isLoss = lowerMessage:find("lost") or lowerMessage:find("spent") or lowerMessage:find("paid") or lowerMessage:find("cost")
        local isRepair = lowerMessage:find("repair")

        if isGain or not isLoss then
            return spaceBeforeX(prefixPlus .. formatMoney(total))
        end

        if merchantFrame.isOpen then
            if isRepair then lastRepairAmount, lastRepairTime = total, GetTime() end
            return true
        end
        if isRepair then
            lastRepairAmount, lastRepairTime = total, GetTime()
            return spaceBeforeX(colorMinus .. "-|r " .. formatMoney(total, colorPalered))
        end
        if lastRepairAmount and total == lastRepairAmount and (GetTime() - lastRepairTime) < repairDedupSeconds then
            return true
        end
        return spaceBeforeX(prefixMinus .. formatMoney(total, colorPalered))
    end

    function api.FormatQuestMoneyReward(message, prefixPlus)
        if not message or type(message) ~= "string" then return nil end

        local total = ParseMoneyAmount(message)
        if total <= 0 then return nil end

        local lowerMessage = message:lower()
        local isQuestReward = lowerMessage:find("quest") or lowerMessage:find("reward") or lowerMessage:find("complete") or
            lowerMessage:find("turn in") or lowerMessage:find("finish")
        if isQuestReward then
            return spaceBeforeX(prefixPlus .. formatMoney(total))
        end

        return nil
    end

    function api.FormatAuctionDisplay(rawItem, sourceMessage)
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
            local itemLink = getItemLinkFromMessage(message)
            if itemLink then
                local display = getItemLinkWithQualityColor(itemLink)
                return spaceBeforeX(prefixPlus .. colorAuctionHouse .. T("CHAT_BUYER_FOUND_LABEL", "Buyer found:") .. " |r" .. display)
            end
            return spaceBeforeX(prefixPlus .. message)
        end

        local buyerItem = message:match("A buyer has been found for your (.+)") or
            message:match("Buyer found for your (.+)") or
            message:match("Buyer found: (.+)") or
            message:match("A buyer has been found for (.+)")
        if buyerItem then
            buyerItem = buyerItem:gsub("^auction of%s+", ""):gsub("^your auction of%s+", "")
            local display = api.FormatAuctionDisplay(buyerItem, message)
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
            local display = api.FormatAuctionDisplay(createdItem, message)
            return spaceBeforeX(prefixPlus .. colorAuctionHouse .. T("CHAT_AUCTION_CREATED_LABEL", "Auction created:") .. " |r" .. display)
        end

        local wonItem = message:match("You won an auction for (.+)") or
            message:match("You won auction for (.+)") or
            message:match("You have won the auction for (.+)") or
            message:match("Auction won: (.+)") or
            message:match("Won auction: (.+)")
        if wonItem then
            if getItemLinkFromMessage(message) then
                return spaceBeforeX(prefixPlus .. message)
            end
            local display = colorWhite .. cleanPunctuation(stripBrackets(wonItem)) .. "|r"
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_AUCTION_WON_LABEL", "Auction won:") .. " |r" .. display)
        end

        local expiredItem = message:match("Your auction of (.+) has expired") or
            message:match("Auction expired: (.+)") or
            message:match("Your auction of (.+) expired") or
            message:match("Auction for (.+) has expired")
        if expiredItem then
            local cleanItem = cleanPunctuation(stripBrackets(expiredItem))
            return spaceBeforeX(prefixMinus .. colorAuctionExpired .. T("CHAT_AUCTION_EXPIRED_LABEL", "Auction expired:") .. " |r" .. colorWhite .. cleanItem .. "|r")
        end

        local cancelledItem = message:match("You cancelled your auction of (.+)") or
            message:match("Auction cancelled: (.+)") or
            message:match("Cancelled auction: (.+)")
        if cancelledItem then
            local cleanItem = cleanPunctuation(stripBrackets(cancelledItem))
            return spaceBeforeX(prefixMinus .. T("CHAT_AUCTION_CANCELLED_LABEL", "Auction cancelled:") .. " |r" .. colorWhite .. cleanItem .. "|r")
        end

        return nil
    end

    function api.FormatRefundDisplay(message)
        local refundItem, refundCount = message:match("^You are refunded:%s*(.+)%sx(%d+)[%.%s]*$") or
            message:match("^[Yy]ou are refunded:%s*(.+)%sx(%d+)[%.%s]*$")
        if not refundItem or not refundCount then return nil end

        local count = tonumber(refundCount) or 1
        local itemLink = getItemLinkFromMessage(message)
        local display
        if itemLink then
            display = getItemLinkWithQualityColor(itemLink)
        else
            display = cleanPunctuation(stripBrackets(refundItem:gsub("x%d+", "")))
        end
        display = spaceBeforeX(display)
        return spaceBeforeX(colorWhite .. T("CHAT_REFUNDED_LABEL", "Refunded:") .. " |r" .. display .. " " .. colorPlus .. "(" .. count .. ")|r")
    end

    function api.FormatGenericReward(message, prefixPlus)
        local lowerMsg = message:lower()
        local rewardAmount, rewardType =
            message:match("You have been awarded (%d+) (.+)") or
            message:match("You have received (%d+) (.+)") or
            message:match("You receive (%d+) (.+)") or
            message:match("You gain (%d+) (.+)") or
            message:match("You earn (%d+) (.+)") or
            message:match("You were awarded (%d+) (.+)") or
            message:match("Rewarded with (%d+) (.+)") or
            message:match("Received (%d+) (.+)") or
            message:match("(%d+) (.+) received") or
            message:match("(%d+) (.+) awarded") or
            message:match("(%d+) (.+) earned") or
            message:match("(%d+) (.+) gained")

        if not rewardAmount or not rewardType then return nil end

        local skip = lowerMsg:find("experience") or lowerMsg:find(" gold") or lowerMsg:find(" silver") or
            lowerMsg:find(" copper") or lowerMsg:find("reputation") or lowerMsg:find("loot:") or
            rewardType:match("^[Ee]xperience") or rewardType:match("^[Gg]old") or rewardType:match("^[Ss]ilver") or
            rewardType:match("^[Cc]opper")
        if skip or #rewardType:gsub("%s", "") <= 0 then return nil end

        local clean = cleanPunctuation(stripBrackets(rewardType))
        if #clean <= 0 then return nil end

        local isHonor = clean:lower():find("honor")
        local color = isHonor and colorHonor or colorCyan
        local display = isHonor and T("CHAT_HONOR_POINTS", "Honor Points") or clean
        return spaceBeforeX(prefixPlus .. colorWhite .. rewardAmount .. " |r" .. color .. display .. "|r")
    end

    return api
end
