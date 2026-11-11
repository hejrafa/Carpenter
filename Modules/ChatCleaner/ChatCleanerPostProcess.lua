--[[ Carpenter - ChatCleaner AddMessage post-processing helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local PostProcess = ns.Private.ChatCleanerPostProcess or {}
ns.Private.ChatCleanerPostProcess = PostProcess

local channelReplacements = {}

local function AddBracketReplacement(globalName, short)
    local tag = _G[globalName]
    if not tag or type(tag) ~= "string" then return end

    local label = tag:match("%[(.-)%]")
    if not label or label == "" then return end

    label = label:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    table.insert(channelReplacements, { "%[" .. label .. "%]", "[" .. short .. "]" })
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
            table.insert(channelReplacements, { "%[" .. label .. "%]", "|cffff0000!|r" })
        end
    end
end

local function ApplyChannelStyling(text)
    if not text or type(text) ~= "string" then return text end

    for _, entry in ipairs(channelReplacements) do
        text = text:gsub(entry[1], entry[2])
    end

    text = text:gsub("|Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%s%-%s.-%]|h", "|Hchannel:%1:%2|h%3.|h")
    text = text:gsub("|Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%]|h", "|Hchannel:%1:%2|h%3.|h")
    -- Lines with no sender, like Local Defense's, read "3. : text". The colon was
    -- meant to follow the name, so it goes too.
    text = text:gsub("(|Hchannel:[^|]*|h%d+%.|h) : ", "%1 ")
    text = text:gsub("^Changed Channel: |Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%]|h", "|Hchannel:%1:%2|h%3. %4|h")

    return text
end

-- The game's own honor lines, as their visible text reads once the chat filter has
-- styled them. Only these count: color codes hold digits too (the 8 in |cffc8c8c8),
-- and players and NPCs can mention honor points in chat. One gain can print both
-- kinds, a currency line and an award or kill line.
local HONOR_LINES = {
    { kind = "currency", pattern = "^%s*%+%s*Honor Points%s+x(%d+)" },                       -- + Honor Points x4
    { kind = "currency", pattern = "^%s*%+%s*Honor%s+x(%d+)" },                              -- + Honor x4
    { kind = "award", pattern = "^%s*%+%s*(%d+) Honor Points" },                             -- + 4 Honor Points, from "You have been awarded 4 Honor."
    { kind = "award", pattern = "^%s*You have been awarded (%d+) [Hh]onor" },                -- You have been awarded 4 Honor.
    { kind = "award", pattern = "^[^:]- dies %(Honorable Kill.-%)%. You gain (%d+) Honor" }, -- Foo dies (Honorable Kill: Private). You gain 4 Honor.
    { kind = "award", pattern = "^[^:]- dies, honorable kill.-Honor Points: (%d+)" },        -- Foo dies, honorable kill Rank: Private (Estimated Honor Points: 4)
    { kind = "award", pattern = "^[^:]- dies, honorable kill.-%((%d+) Honor Points" },       -- Foo dies, honorable kill (4 Honor Points, +2 Rested)
}

local function ParseHonorLine(plainText)
    for _, line in ipairs(HONOR_LINES) do
        local amount = plainText:match(line.pattern)
        if amount then return amount, line.kind end
    end
    return nil
end

function PostProcess.Create(config)
    config = config or {}
    local applyChannelStyling = config.ApplyChannelStyling or ApplyChannelStyling
    local removeLinkBrackets = config.RemoveLinkBrackets or function(text) return text end
    local formatLevelUpRewardMessage = config.FormatLevelUpRewardMessage or function() return nil end
    local formatAppearanceCollectionMessage = config.FormatAppearanceCollectionMessage or function() return nil end
    local parseRetailMoneyGain = config.ParseRetailMoneyGain or function() return nil end
    local spaceBeforeX = config.SpaceBeforeX or function(text) return text end
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorLootLiteral = config.ColorLootLiteral or "|cffc8c8c8"
    local colorGreen = config.ColorGreen or "|cff00ff00"
    local getChannelMessageColor = config.GetChannelMessageColor or function() return colorLootLiteral end
    local getPlayerNameColor = config.GetPlayerNameColor or function() return nil end
    local colorRed = config.ColorRed or "|cffff4040"
    local honorDelay = config.HonorDelay or 3
    local joinDedupDelay = config.JoinDedupDelay or 8
    local L = config.L or (Carpenter and Carpenter.L) or {}

    local lastHonorByFrame = {}
    local lastJoinKey, lastJoinTime = nil, nil

    local api = {}

    local function T(key, fallback, ...)
        local text = L[key] or fallback or key
        if select("#", ...) > 0 then
            return string.format(text, ...)
        end
        return text
    end

    local function Trim(text)
        return (text and text:gsub("^%s+", ""):gsub("%s+$", "") or "")
    end

    -- For the first minute of a battleground, Blizzard collects joins and
    -- leaves and prints them as one line straight to the chat frame, so no
    -- chat filter ever sees them.
    local function FormatBattleRosterLine(plain)
        local joinedList = plain:match("^%s*%d+%s+players have joined the battle:%s*(.-)%.?%s*$")
        if joinedList and Trim(joinedList) ~= "" then
            return colorGreen .. T("CHAT_PLAYER_JOINED", "%s joined", Trim(joinedList)) .. "|r"
        end
        local leftList = plain:match("^%s*%d+%s+players have left the battle:%s*(.-)%.?%s*$")
        if leftList and Trim(leftList) ~= "" then
            return colorRed .. T("CHAT_PLAYER_LEFT", "%s left", Trim(leftList)) .. "|r"
        end
        local joinedCount = plain:match("^%s*(%d+)%s+players have joined the battle%.?%s*$")
        if joinedCount then
            return colorGreen .. T("CHAT_PLAYERS_JOINED", "%s players joined", joinedCount) .. "|r"
        end
        local leftCount = plain:match("^%s*(%d+)%s+players have left the battle%.?%s*$")
        if leftCount then
            return colorRed .. T("CHAT_PLAYERS_LEFT", "%s players left", leftCount) .. "|r"
        end
        local joinedName = plain:match("^%s*(.-)%s+has joined the battle%.?%s*$")
        if joinedName and Trim(joinedName) ~= "" then
            return colorGreen .. T("CHAT_PLAYER_JOINED", "%s joined", Trim(joinedName)) .. "|r"
        end
        local leftName = plain:match("^%s*(.-)%s+has left the battle%.?%s*$")
        if leftName and Trim(leftName) ~= "" then
            return colorRed .. T("CHAT_PLAYER_LEFT", "%s left", Trim(leftName)) .. "|r"
        end
        return nil
    end

    local function StyleBareLootItem(item)
        if not item or item == "" or item:find("|Hitem:", 1, true) then return item end
        return colorGreen .. item .. "|r"
    end

    local function StyledLootName(name)
        name = Trim(name):gsub("^Loot:%s*", ""):gsub("^[:;]+%s*", ""):gsub("%-.*$", "")
        if name == "" or name == "Loot" then return nil end
        if name == "You" then
            return colorLootLiteral .. (L.CHAT_YOU or "You") .. "|r"
        end
        return colorLootLiteral .. name .. "|r"
    end

    local function Literal(text)
        if text and type(text) == "string" then
            text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*:%s*$", "")
        end
        if not text or text == "" then return "" end
        return colorLootLiteral .. text .. "|r"
    end

    local function SelectedRollText(typeWord)
        local rollType = typeWord and T("CHAT_ROLL_" .. typeWord:upper(), typeWord) or ""
        return rollType
    end

    local function FormatDirectLootWin(text)
        if not text or type(text) ~= "string" then return nil end

        local prefix = text:match("^(.-)[Ll]oot:%s*.-%s+[Ww]on:%s*.+$")
        local name, item = text:match("[Ll]oot:%s*(.-)%s+[Ww]on:%s*(.+)$")
        if not name or not item then return nil end

        local nameOut = StyledLootName(name)
        if not nameOut then return nil end

        item = Trim(item):gsub("%s+[Ll]oot%s*$", "")
        if item == "" then return nil end

        return (prefix or "") .. nameOut .. " " .. Literal(T("CHAT_WON_LABEL", "won:")) .. " " .. item
    end

    local function StripColorCodes(text)
        if not text or type(text) ~= "string" then return "" end
        return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    end

    local function HasChatChannelPrefix(plainText)
        if not plainText or type(plainText) ~= "string" then return false end
        return plainText:match("^%s*[PGROI!][%s:][^:]+:") ~= nil
            or plainText:match("^%s*%d+%.[^:]+:") ~= nil
    end

    local function IsRollPayload(text)
        if not text or type(text) ~= "string" then return false end
        local lower = text:lower()
        return lower:find("has selected", 1, true) or
            lower:find("have selected", 1, true) or
            lower:find("selected ", 1, true) or
            lower:find("passed on", 1, true) or
            lower:find(" won", 1, true) or
            lower:find("roll", 1, true)
    end

    local function ExtractBareLootItem(text)
        if not text or type(text) ~= "string" then return nil end

        return text:match("^%s*[Ll]oot:%s*(.+)$") or
            text:match("^%s*|c%x%x%x%x%x%x%x%x[Ll]oot:%s*|r%s*(.+)$") or
            text:match("^%s*|c%x%x%x%x%x%x%x%x[Ll]oot|r:%s*(.+)$") or
            text:match("^%s*|c%x%x%x%x%x%x%x%x[Ll]oot:%s*(.+)|r%s*$") or
            StripColorCodes(text):match("^%s*[Ll]oot:%s*(.+)$")
    end

    local function FormatBareLoot(text)
        if not text or type(text) ~= "string" then return nil end

        local item = ExtractBareLootItem(text)
        if not item or IsRollPayload(StripColorCodes(item)) then return nil end

        item = Trim(item):gsub("%.+$", "")
        if item == "" then return nil end

        local lootLabelColor = getChannelMessageColor("CHAT_MSG_LOOT") or colorLootLiteral
        return lootLabelColor .. "Loot|r " .. colorPlus .. "+|r " .. StyleBareLootItem(item)
    end

    local function FormatHardcoreDeathMessage(plainText)
        if not plainText or type(plainText) ~= "string" then return nil end

        local text = plainText:gsub("^%s*%d+%.:?%s*", ""):gsub("^%s*:%s*", "")
        local playerName, cause, level = text:match("^%s*(%S+)%s+(.+)%!%s*[Tt]hey were level%s+(%d+)%s*%.?%s*$")
        if not playerName or playerName == "" or not level then return nil end

        local lowerCause = cause:lower()
        local causeLabel = nil
        if lowerCause:find("drowned to death", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_DROWNED", "drowned")
        elseif lowerCause:find("fell to death", 1, true) or
            lowerCause:find("fell to their death", 1, true) or
            lowerCause:find("fell to his death", 1, true) or
            lowerCause:find("fell to her death", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_FELL", "fell")
        elseif lowerCause:find("burned to death", 1, true) or
            lowerCause:find("burnt to death", 1, true) or
            lowerCause:find("burned to a crisp", 1, true) or
            lowerCause:find("burnt to a crisp", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_BURNED", "burned")
        elseif lowerCause:find("died from fatigue", 1, true) or
            lowerCause:find("died to fatigue", 1, true) or
            lowerCause:find("died of fatigue", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_FATIGUE", "died from fatigue")
        elseif lowerCause:find("has been slain", 1, true) or lowerCause:find("was slain", 1, true) then
            local killer = cause:match("[Hh]as been slain by%s+(.+)$") or cause:match("[Ww]as slain by%s+(.+)$")
            if killer then
                killer = Trim(killer):gsub("%s+in%s+.+$", "")
            end
            causeLabel = killer and killer ~= "" and T("CHAT_HARDCORE_DEATH_SLAIN_BY", "was slain by %s", killer) or T("CHAT_HARDCORE_DEATH_SLAIN", "slain")
        elseif lowerCause:find("was killed", 1, true) or lowerCause:find("died to", 1, true) or
            lowerCause:find("died from", 1, true) or lowerCause:find("died in", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_DIED", "died")
        end
        if not causeLabel then return nil end

        playerName = Trim(playerName):gsub("%-.*$", "")
        if playerName == "" then return nil end

        return colorRed .. T("CHAT_HARDCORE_DEATH", "%s %s! Level %s", playerName, causeLabel, level) .. "|r"
    end

    -- Rollers get their class color, like names in say and party chat.
    local function RollNameColor(name)
        return getPlayerNameColor(name) or colorLootLiteral
    end

    local function StyleLootRollNames(text)
        if not text or type(text) ~= "string" then return text end

        local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%s+", " ")
        local lower = plain:lower()
        local isLootRoll = lower:find("has selected") or lower:find("passed on") or lower:find(" won ") or lower:find(" won:") or lower:find(" wins ") or
            plain:find(" by .+%s*$") or lower:find("won by ") or lower:find("winner:") or
            lower:find("receives loot") or lower:find("receives item") or lower:find(" creates:") or lower:find(" rolls ") or lower:find(" roll ")
        if not isLootRoll then return text end

        text = text:gsub("^%s*[Ll]oot%s*:?%s*", "")
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)[Ll]oot%s*:?%s*", "%1")
        text = text:gsub("(%])%s*[Ll]oot%s*:?%s*", "%1 ")
        text = text:gsub("(%])|r%s*[Ll]oot%s*:?%s*", "%1|r ")
        text = text:gsub("(|r)%s*[Ll]oot%s*:?%s*", "%1 ")
        text = text:gsub("(%s+has selected %w+)%s+for%s*:%s*", "%1: ")
        text = text:gsub("%s+[Ll]oot%s*$", "")
        text = text:gsub(" x(%d+)(|r)?%s*$", function(count, reset)
            return " " .. colorPlus .. "(" .. count .. ")|r" .. (reset or "")
        end)

        local nameAtEnd = plain:match(" by ([^|%[%]]+)%s*$") or plain:match(" won by ([^|%[%]]+)%s*$") or plain:match(" [Ww]inner:?%s+([^|%[%]]+)%s*$")
        if nameAtEnd then
            nameAtEnd = Trim(nameAtEnd):gsub("%-.*$", "")
            if nameAtEnd ~= "" then
                local didReplace
                text = text:gsub(" by ([^|%[%]]+)%s*(|r)?%s*$", function(name, reset)
                    didReplace = true
                    local short = Trim(name):gsub("%-.*$", "")
                    return " by " .. colorLootLiteral .. short .. "|r" .. (reset or "")
                end, 1)
                if not didReplace then
                    text = text:gsub(" ([Ww]inner:?%s+)([^|%[%]]+)%s*(|r)?%s*$", function(label, name, reset)
                        didReplace = true
                        local short = Trim(name):gsub("%-.*$", "")
                        return " " .. label .. colorLootLiteral .. short .. "|r" .. (reset or "")
                    end, 1)
                end
                if didReplace then return text end
            end
        end

        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives loot:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. colorLootLiteral .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives item:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. colorLootLiteral .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+creates:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. colorLootLiteral .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(.-)%s+has selected%s+(%w+)%s*:%s*(.+)$", function(name, typeWord, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" and typeWord then
                return colorLootLiteral .. short .. "|r " .. Literal(SelectedRollText(typeWord)) .. " " .. item
            end
            return name .. " " .. typeWord .. ": " .. item
        end)
        text = text:gsub("^(.-)%s+passed on[:%s]+(.+)$", function(name, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                return colorLootLiteral .. short .. "|r " .. Literal(T("CHAT_PASSED_LABEL", "passed:")) .. " " .. item
            end
            return name .. " passed: " .. item
        end)
        text = text:gsub("^(.-)%s+[Ww]on:%s*(.+)$", function(name, item)
            local nameOut = StyledLootName(name)
            if nameOut then
                return nameOut .. " " .. Literal(T("CHAT_WON_LABEL", "won:")) .. " " .. item
            end
            return name .. " won: " .. item
        end)
        text = text:gsub("^(.-)%s+(rolls?)%s+(%d+)%s*:%s*(.+)$", function(name, rollWord, rollNumber, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return colorLootLiteral .. (L.CHAT_YOU or "You") .. "|r " .. Literal("roll " .. rollNumber .. ":") .. " " .. item
                end
                return RollNameColor(short) .. short .. "|r " .. Literal(rollWord .. " " .. rollNumber .. ":") .. " " .. item
            end
            return name .. " " .. rollWord .. " " .. rollNumber .. ": " .. item
        end)
        text = text:gsub("^(.-)%s+(rolls?)%s+(%d+)%s+(%(%d+%-%d+%))%s*$", function(name, rollWord, rollNumber, rangeText)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return colorLootLiteral .. (L.CHAT_YOU or "You") .. "|r " .. Literal("roll " .. rollNumber .. " " .. rangeText)
                end
                return RollNameColor(short) .. short .. "|r " .. Literal(rollWord .. " " .. rollNumber .. " " .. rangeText)
            end
            return name .. " " .. rollWord .. " " .. rollNumber .. " " .. rangeText
        end)
        text = text:gsub("^(.-)%s+(rolls?)%s+(%d+)%s*$", function(name, rollWord, rollNumber)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return colorLootLiteral .. (L.CHAT_YOU or "You") .. "|r " .. Literal("roll " .. rollNumber)
                end
                return RollNameColor(short) .. short .. "|r " .. Literal(rollWord .. " " .. rollNumber)
            end
            return name .. " " .. rollWord .. " " .. rollNumber
        end)

        return text
    end

    -- keepLine: the line is already in the chat frame and can only be restyled,
    -- so lines that would be dropped are kept as they are.
    function api.ProcessMessage(frame, originalAddMessage, message, args, keepLine)
        message = applyChannelStyling(tostring(message))
        message = removeLinkBrackets(message)

        local plain = StripColorCodes(message)
        local appearanceCollectionMessage = formatAppearanceCollectionMessage("CHAT_MSG_SYSTEM", message, plain, colorPlus .. "+|r ")
        if appearanceCollectionMessage then
            return originalAddMessage(frame, appearanceCollectionMessage, unpack(args))
        end

        local directLootWin = FormatDirectLootWin(message)
        if directLootWin then
            return originalAddMessage(frame, directLootWin, unpack(args))
        end

        message = StyleLootRollNames(message)

        plain = StripColorCodes(message)
        local bareLootMessage = FormatBareLoot(message)
        if bareLootMessage then
            return originalAddMessage(frame, bareLootMessage, unpack(args))
        end

        local hardcoreDeathMessage = FormatHardcoreDeathMessage(plain)
        if hardcoreDeathMessage then
            return originalAddMessage(frame, hardcoreDeathMessage, unpack(args))
        end

        if not HasChatChannelPrefix(plain) then
            local styledLevelReward = formatLevelUpRewardMessage(plain)
            if styledLevelReward then
                return originalAddMessage(frame, styledLevelReward, unpack(args))
            end
        end

        -- Blizzard's money receipt after a merchant or mailbox ("You gained:"),
        -- which repeats Chat Cleaner's own money lines, and other lines that are
        -- always hidden. A line already in the chat frame can't be removed
        -- without tainting it, so it is emptied instead.
        if parseRetailMoneyGain(plain) or plain:find("^Changed Channel:") or plain:find("^Left Channel:") or plain:find("^Auctionator:") then
            if keepLine then
                return originalAddMessage(frame, "", unpack(args))
            end
            return
        end

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
        if not keepLine and joinKey and lastJoinKey == joinKey and (GetTime() - lastJoinTime) < joinDedupDelay then
            return
        end
        if joinKey and (isShortForm or joinPlayers) then
            lastJoinKey, lastJoinTime = joinKey, GetTime()
        end

        local rosterLine = FormatBattleRosterLine(plain)
        if rosterLine then
            -- A styled long-form join reads like the short form, so a short
            -- duplicate right after it is dropped too.
            if joinKey then
                lastJoinKey, lastJoinTime = joinKey, GetTime()
            end
            return originalAddMessage(frame, rosterLine, unpack(args))
        end

        local honor, honorKind = ParseHonorLine(plain)
        if honor then
            -- The other kind of line with the same amount right after is the same
            -- gain. Two lines of one kind are two gains, and each chat frame gets
            -- its own copy of the lines.
            local last = lastHonorByFrame[frame]
            if not keepLine and last and last.kind ~= honorKind and last.amount == honor and (GetTime() - last.time) < honorDelay then
                lastHonorByFrame[frame] = nil
                return
            end
            lastHonorByFrame[frame] = { kind = honorKind, amount = honor, time = GetTime() }
            local styled = spaceBeforeX(colorPlus .. "+|r " .. "|cffffffff" .. honor .. " |r|cffffffffHonor Points|r")
            return originalAddMessage(frame, styled, unpack(args))
        end

        return originalAddMessage(frame, message, unpack(args))
    end

    local function IsSecret(value)
        return issecretvalue ~= nil and issecretvalue(value) == true
    end

    -- What the post-processor would print for a line: the new text, or
    -- nothing when the line should go.
    local function ResolveMessage(frame, message, args, keepLine)
        local added, result = false, nil
        api.ProcessMessage(frame, function(_, text)
            added, result = true, text
        end, message, args, keepLine)
        return added, result
    end

    -- Blizzard's own code calls AddMessage and keeps running afterwards; the
    -- battleground join batching clears its list of hidden player names right
    -- after printing. If that code is tainted it errors every frame, and the
    -- same line prints again and again.
    --
    -- A replaced AddMessage taints it directly. Removing a line taints it too:
    -- RemoveMessagesByPredicate rebuilds the chat history after reading the
    -- addon's answer, so the history's index ends up tainted, and every later
    -- AddMessage reads it. Restyling a line only touches the line itself.
    --
    -- So where the chat frame offers Blizzard's secure line edits, lines are
    -- restyled after they are added, and lines that should go are dropped by
    -- the chat filter before they are added.
    local function CanEditAfterAdd(frame)
        return issecretvalue ~= nil
            and hooksecurefunc ~= nil
            and type(frame.AddMessage) == "function"
            and type(frame.TransformMessages) == "function"
    end

    local function EditsAfterAdd(frame)
        return frame ~= nil and frame._CP_AddMessagePostHooked == true and frame._CP_AddMessageHooked == true
            and Carpenter ~= nil and Carpenter:IsEnabled("chatCleanerEnabled")
    end

    -- Lines without a sender, which the chat frame prints as they are.
    local DROP_BEFORE_ADD_EVENTS = {
        CHAT_MSG_SYSTEM = true,
        CHAT_MSG_BG_SYSTEM_ALLIANCE = true,
        CHAT_MSG_BG_SYSTEM_HORDE = true,
        CHAT_MSG_BG_SYSTEM_NEUTRAL = true,
        CHAT_MSG_COMBAT_HONOR_GAIN = true,
        CHAT_MSG_COMBAT_XP_GAIN = true,
        CHAT_MSG_COMBAT_MISC_INFO = true,
        CHAT_MSG_CURRENCY = true,
        CHAT_MSG_MONEY = true,
        CHAT_MSG_LOOT = true,
    }

    -- Called by the chat filter with the line it is about to let through:
    -- true when the post-processor would drop it (a repeated honor gain or
    -- join, for example).
    function api.ShouldDropBeforeAdd(frame, event, text)
        if not DROP_BEFORE_ADD_EVENTS[event] or not EditsAfterAdd(frame) then return false end
        if type(text) ~= "string" or IsSecret(text) then return false end
        local added = ResolveMessage(frame, text, {}, false)
        return not added
    end

    -- "Changed Channel" and "Left Channel" lines. Blizzard updates the chat
    -- frame's channel list for a departure only when it prints the line, but
    -- leaving a stale name in that list is harmless.
    function api.ShouldDropChannelNotice(frame, notice)
        if not EditsAfterAdd(frame) or IsSecret(notice) then return false end
        return notice == "YOU_CHANGED" or notice == "YOU_LEFT"
    end

    local function IsSameLine(text, original)
        return not IsSecret(text) and text == original
    end

    local function ReplaceLine(frame, original, replacement)
        frame:TransformMessages(function(text)
            return IsSameLine(text, original)
        end, function(_, ...)
            return replacement, ...
        end)
    end

    local function EditAddedLine(frame, message, ...)
        local added, result = ResolveMessage(frame, message, { ... }, true)
        if added and result ~= message then
            ReplaceLine(frame, message, result)
        end
    end

    -- Lines whose text the game hides go to ChatCleanerHiddenLines.
    local hiddenLineHandler
    function api.SetHiddenLineHandler(handler)
        hiddenLineHandler = handler
    end

    local function OnLineAdded(frame, message, ...)
        if not frame._CP_AddMessageHooked then return end
        if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then return end
        if IsSecret(message) then
            if hiddenLineHandler then pcall(hiddenLineHandler, frame) end
            return
        end
        if type(message) ~= "string" then return end

        if Carpenter.Profile then
            pcall(Carpenter.Profile, Carpenter, "ChatCleaner:AddMessage", EditAddedLine, frame, message, ...)
        else
            pcall(EditAddedLine, frame, message, ...)
        end
    end

    function api.HookChatFrameAddMessage(frame)
        if not frame or frame._CP_AddMessageHooked then return end
        if frame._CP_AddMessagePostHooked or CanEditAfterAdd(frame) then
            if not frame._CP_AddMessagePostHooked then
                if not pcall(hooksecurefunc, frame, "AddMessage", OnLineAdded) then return end
                frame._CP_AddMessagePostHooked = true
            end
            frame._CP_AddMessageHooked = true
            return
        end

        local originalAddMessage = frame._CP_OriginalAddMessage or frame.AddMessage
        if not originalAddMessage then return end
        frame._CP_OriginalAddMessage = originalAddMessage

        frame.AddMessage = function(self, message, ...)
            if not (Carpenter and Carpenter:IsEnabled("chatCleanerEnabled")) then
                return originalAddMessage(self, message, ...)
            end

            local originalMessage = message
            local args = { ... }
            local ok = pcall(function()
                local function RunPostProcess()
                    return api.ProcessMessage(self, originalAddMessage, message, args)
                end

                if Carpenter and Carpenter.Profile then
                    return Carpenter:Profile("ChatCleaner:AddMessage", RunPostProcess)
                end
                return RunPostProcess()
            end)
            if not ok then
                originalAddMessage(self, originalMessage, unpack(args))
            end
        end
        frame._CP_AddMessageHooked = true
    end

    function api.RestoreChatFrameAddMessage(frame)
        if not frame or not frame._CP_AddMessageHooked then return end
        -- A secure hook can't be removed; it goes quiet instead.
        if frame._CP_AddMessagePostHooked then
            frame._CP_AddMessageHooked = false
            return
        end
        if not frame._CP_OriginalAddMessage then return end
        frame.AddMessage = frame._CP_OriginalAddMessage
        frame._CP_AddMessageHooked = false
    end

    return api
end
