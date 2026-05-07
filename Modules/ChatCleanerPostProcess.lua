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
    text = text:gsub("^Changed Channel: |Hchannel:(.-):(%d+)|h%[(%d+)%. (.-)%]|h", "|Hchannel:%1:%2|h%3. %4|h")

    return text
end

function PostProcess.Create(config)
    config = config or {}
    local applyChannelStyling = config.ApplyChannelStyling or ApplyChannelStyling
    local removeLinkBrackets = config.RemoveLinkBrackets or function(text) return text end
    local getClassColorForName = config.GetClassColorForName or function() return "|cfff0f0f0" end
    local formatLevelUpRewardMessage = config.FormatLevelUpRewardMessage or function() return nil end
    local parseRetailMoneyGain = config.ParseRetailMoneyGain or function() return nil end
    local spaceBeforeX = config.SpaceBeforeX or function(text) return text end
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorRed = config.ColorRed or "|cffff4040"
    local honorDelay = config.HonorDelay or 3
    local joinDedupDelay = config.JoinDedupDelay or 8
    local L = config.L or (Carpenter and Carpenter.L) or {}

    local lastStyledHonor = nil
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

    local function StyledLootName(name)
        name = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
        if name == "" or name == "Loot" then return nil end
        if name == "You" then
            return getClassColorForName(UnitName("player") or "You") .. (L.CHAT_YOU or "You") .. "|r"
        end
        return getClassColorForName(name) .. name .. "|r"
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

        return (prefix or "") .. nameOut .. " " .. T("CHAT_WON_LABEL", "won:") .. " " .. item
    end

    local function StripColorCodes(text)
        if not text or type(text) ~= "string" then return "" end
        return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
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
        elseif lowerCause:find("burned to death", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_BURNED", "burned")
        elseif lowerCause:find("died from fatigue", 1, true) or lowerCause:find("died to fatigue", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_FATIGUE", "died from fatigue")
        elseif lowerCause:find("has been slain", 1, true) or lowerCause:find("was slain", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_SLAIN", "slain")
        elseif lowerCause:find("was killed", 1, true) or lowerCause:find("died to", 1, true) or
            lowerCause:find("died from", 1, true) or lowerCause:find("died in", 1, true) then
            causeLabel = T("CHAT_HARDCORE_DEATH_DIED", "died")
        end
        if not causeLabel then return nil end

        playerName = Trim(playerName):gsub("%-.*$", "")
        if playerName == "" then return nil end

        return colorRed .. T("CHAT_HARDCORE_DEATH", "%s %s! Level %s", playerName, causeLabel, level) .. "|r"
    end

    local function ClassColorPlayerNames(text)
        if not text or type(text) ~= "string" then return text end
        return text:gsub("(|c%x%x%x%x%x%x%x%x)?(|Hplayer:([^:|]+)(:[^|]*)?|h.-|h)", function(_, link, playerName)
            return getClassColorForName(playerName) .. link
        end)
    end

    local function ClassColorLootRollNames(text)
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
                    return " by " .. getClassColorForName(short) .. short .. "|r" .. (reset or "")
                end, 1)
                if not didReplace then
                    text = text:gsub(" ([Ww]inner:?%s+)([^|%[%]]+)%s*(|r)?%s*$", function(label, name, reset)
                        didReplace = true
                        local short = Trim(name):gsub("%-.*$", "")
                        return " " .. label .. getClassColorForName(short) .. short .. "|r" .. (reset or "")
                    end, 1)
                end
                if didReplace then return text end
            end
        end

        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives loot:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. getClassColorForName(short) .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+receives item:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. getClassColorForName(short) .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(|c%x%x%x%x%x%x%x%x)?%s*([^|%[%]%s]+)(%s+creates:%s*)(.-)$", function(prefix, name, literal, tail)
            local short = Trim(name):gsub("%-.*$", "")
            if short ~= "" and short ~= "You" and short ~= "Loot" then
                return (prefix or "") .. getClassColorForName(short) .. short .. "|r" .. literal .. tail
            end
            return (prefix or "") .. short .. literal .. tail
        end)
        text = text:gsub("^(.-)%s+has selected%s+(%w+)%s*:%s*(.+)$", function(name, typeWord, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" and typeWord then
                return getClassColorForName(short) .. short .. "|r " .. typeWord .. ": " .. item
            end
            return name .. " " .. typeWord .. ": " .. item
        end)
        text = text:gsub("^(.-)%s+passed on[:%s]+(.+)$", function(name, item)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                return getClassColorForName(short) .. short .. "|r passed: " .. item
            end
            return name .. " passed: " .. item
        end)
        text = text:gsub("^(.-)%s+[Ww]on:%s*(.+)$", function(name, item)
            local nameOut = StyledLootName(name)
            if nameOut then
                return nameOut .. " " .. T("CHAT_WON_LABEL", "won:") .. " " .. item
            end
            return name .. " won: " .. item
        end)
        text = text:gsub("^(.-)%s+rolls?%s+(%d+)", function(name, rollNumber)
            local short = Trim(name):gsub("^Loot:%s*", ""):gsub("%-.*$", "")
            if short ~= "" and short ~= "Loot" then
                if short == "You" then
                    return getClassColorForName(UnitName("player") or "You") .. (L.CHAT_YOU or "You") .. "|r rolls " .. rollNumber
                end
                return getClassColorForName(short) .. short .. "|r rolls " .. rollNumber
            end
            return name .. " rolls " .. rollNumber
        end)

        return text
    end

    function api.ProcessMessage(frame, originalAddMessage, message, args)
        message = applyChannelStyling(tostring(message))
        message = removeLinkBrackets(message)

        local directLootWin = FormatDirectLootWin(message)
        if directLootWin then
            return originalAddMessage(frame, directLootWin, unpack(args))
        end

        message = ClassColorPlayerNames(message)
        message = ClassColorLootRollNames(message)

        local plain = StripColorCodes(message)
        local hardcoreDeathMessage = FormatHardcoreDeathMessage(plain)
        if hardcoreDeathMessage then
            return originalAddMessage(frame, hardcoreDeathMessage, unpack(args))
        end

        local styledLevelReward = formatLevelUpRewardMessage(plain)
        if styledLevelReward then
            return originalAddMessage(frame, styledLevelReward, unpack(args))
        end

        if parseRetailMoneyGain(plain) then
            return
        end
        if plain:find("^Changed Channel:") or plain:find("^Left Channel:") or plain:find("^Auctionator:") then
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
        if joinKey and lastJoinKey == joinKey and (GetTime() - lastJoinTime) < joinDedupDelay then
            return
        end
        if joinKey and (isShortForm or joinPlayers) then
            lastJoinKey, lastJoinTime = joinKey, GetTime()
        end

        if plain:lower():find("honor") then
            local honor = message:match("Estimated Honor Points: (%d+)") or message:match("Honor Points: (%d+)") or
                message:match("honor points: (%d+)") or message:match("Honor points: (%d+)") or
                message:match("honor points (%d+)") or message:match("(%d+) honor points") or
                message:match("(%d+) honor point") or message:match("(%d+) Honor Point") or
                message:match("(%d+) Honor Points") or message:match("(%d+) honor") or
                message:match("honor: (%d+)") or message:match("Honor: (%d+)") or message:match("(%d+) Honor") or
                message:match("%+(%d+)%).*[Hh]onor") or message:match("[Hh]onor.*%+(%d+)") or
                message:match("(%d+).*[Hh]onor [Pp]oint") or message:match("%[Honor [Pp]oints%].*x(%d+)") or
                message:match("x(%d+).*%[Honor [Pp]oints%]") or message:match("%[Honor [Pp]oints%].*(%d+)") or
                message:match("currency.*[Hh]onor.*x(%d+)") or message:match("[Rr]eceive currency.*[Hh]onor.*(%d+)")
            if honor then
                if lastStyledHonor and (GetTime() - lastStyledHonor) < honorDelay then
                    if not plain:find("^[%+%-]%s*%d+%s*%w*Honor") then
                        return
                    end
                else
                    local styled = spaceBeforeX(colorPlus .. "+|r " .. "|cffffffff" .. honor .. " |r|cffffffffHonor Points|r")
                    lastStyledHonor = GetTime()
                    return originalAddMessage(frame, styled, unpack(args))
                end
            end
        end

        return originalAddMessage(frame, message, unpack(args))
    end

    function api.HookChatFrameAddMessage(frame)
        if not frame or frame._CP_AddMessageHooked then return end
        local originalAddMessage = frame.AddMessage
        if not originalAddMessage then return end

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

    return api
end
