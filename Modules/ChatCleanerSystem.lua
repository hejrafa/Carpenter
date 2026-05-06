--[[ Carpenter - ChatCleaner system/level helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local System = ns.Private.ChatCleanerSystem or {}
ns.Private.ChatCleanerSystem = System

function System.Create(config)
    config = config or {}
    local cleanPunctuation = config.CleanPunctuation or function(text) return text end
    local stripBrackets = config.StripBrackets or function(text) return text end
    local spaceBeforeX = config.SpaceBeforeX or function(text) return text end
    local getClassColorForName = config.GetClassColorForName or function() return "|cfff0f0f0" end
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorMinus = config.ColorMinus or "|cffc8c8c8"
    local colorWhite = config.ColorWhite or "|cffffffff"
    local colorBluePurple = config.ColorBluePurple or "|cff9d8cff"
    local colorQueue = config.ColorQueue or "|cff80b0ff"
    local colorPurple = config.ColorPurple or "|cffb794f4"
    local colorTeal = config.ColorTeal or "|cff00ccaa"
    local colorYellow = config.ColorYellow or "|cffffd200"

    local api = {}
    local originalLevelUpGlobals = nil
    local lastLearnedSkillName, lastLearnedSkillTime = nil, 0
    local learnedSkillDedupSeconds = config.LearnedSkillDedupSeconds or 3

    function api.NormalizeSkillName(name)
        if not name or type(name) ~= "string" then return nil end
        name = cleanPunctuation(stripBrackets(name))
        name = name:gsub("%s*%b()%s*$", "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        return name:lower()
    end

    function api.IsLevelUpRewardEvent(event)
        return event == "CHAT_MSG_SYSTEM" or
            event == "CHAT_MSG_COMBAT_XP_GAIN" or
            event == "CHAT_MSG_COMBAT_MISC_INFO"
    end

    function api.FormatLevelUpRewardMessage(plainText)
        if not plainText or type(plainText) ~= "string" then return nil end

        local plainLower = plainText:lower()
        local levelColor = getClassColorForName(UnitName("player") or "")

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

            local nameColor = getClassColorForName(name)
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
            return colorPlus .. "+|r " .. levelColor .. hitAmount .. " " .. word .. "|r"
        end

        local talentAmount = plainText:match("[Yy]ou%s+have%s+gained%s+(%d+)%s+[Tt]alent [Pp]oint") or
            plainText:match("[Hh]ave%s+gained%s+(%d+)%s+[Tt]alent [Pp]oint") or
            plainText:match("[Gg]ained%s*:?.-%s*(%d+)%s+[Tt]alent [Pp]oint")
        if talentAmount and plainLower:find("talent point") then
            local n = tonumber(talentAmount) or 0
            local word = (n == 1) and "Talent Point" or "Talent Points"
            return colorPlus .. "+|r " .. levelColor .. talentAmount .. " " .. word .. "|r"
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
                return colorPlus .. "+|r " .. levelColor .. table.concat(stats, ", ") .. "|r"
            end
        end

        return nil
    end

    function api.FormatExperienceMessage(message, plainText, prefixPlus)
        if not message or type(message) ~= "string" then return nil end
        plainText = (type(plainText) == "string" and plainText) or message

        local discoveredZone, discoveredXP = message:match("Discovered (.+): (%d+) experience gained")
        if discoveredZone and discoveredXP then
            return spaceBeforeX(prefixPlus .. colorWhite .. discoveredXP .. " EXP: " .. "|r" .. colorTeal .. discoveredZone .. "|r")
        end

        local exploredZone = plainText:match("^%s*[Ee]xploring a new zone:%s*(.+)$") or
            plainText:match("^%s*[Ee]xplored:%s*(.+)$") or
            plainText:match("^%s*[Dd]iscovered:%s*(.+)$")
        if exploredZone and exploredZone ~= "" then
            exploredZone = exploredZone:gsub("^%s+", ""):gsub("%s+$", "")
            return spaceBeforeX(colorWhite .. "Exploring a new zone: " .. exploredZone .. "|r")
        end

        local xp = message:match("You gain (%d+) experience") or message:match("Experience gained: (%d+)")
        if xp then
            return spaceBeforeX(prefixPlus .. colorWhite .. xp .. " |r" .. colorWhite .. "EXP|r")
        end

        return nil
    end

    function api.FormatQuestProgressMessage(event, message, plainText, prefixPlus)
        if event ~= "CHAT_MSG_SYSTEM" or not message or type(message) ~= "string" then return nil end
        plainText = (type(plainText) == "string" and plainText) or message

        local lowerPlainText = plainText:lower()
        local questAccepted = nil
        if lowerPlainText:find("quest accepted:") then
            questAccepted = message:match("[Qq]uest [Aa]ccepted: (.+)") or message:match("[Qq]uest [Aa]ccepted (.+)")
        end

        local questCompleted = message:match("^(.+) [Cc]ompleted%.?%s*$")
        if not questCompleted then
            questCompleted = message:match("[Qq]uest [Cc]ompleted: (.+)") or
                message:match("[Qq]uest [Cc]ompleted (.+)") or
                message:match("[Yy]ou [Hh]ave [Cc]ompleted: (.+)") or
                message:match("[Yy]ou [Hh]ave [Cc]ompleted (.+)") or
                message:match("[Yy]ou [Cc]ompleted: (.+)") or
                message:match("[Yy]ou [Cc]ompleted (.+)")
        end
        if not questCompleted and lowerPlainText:find("you") and lowerPlainText:find("completed") then
            questCompleted = message:match("[Yy]ou.-[Cc]ompleted:? (.+)")
        end

        if questAccepted then
            return spaceBeforeX(prefixPlus .. colorWhite .. "Accepted: " .. "|r" .. colorYellow .. cleanPunctuation(stripBrackets(questAccepted)) .. "|r")
        elseif questCompleted then
            local cleanQuest = cleanPunctuation(stripBrackets(questCompleted))
            return spaceBeforeX(prefixPlus .. colorWhite .. "Completed: " .. "|r" .. colorYellow .. cleanQuest .. "|r")
        end

        return nil
    end

    function api.FormatReputationMessage(message)
        if not message or type(message) ~= "string" then return nil end

        local standing, standingFaction = message:match("You are now (.-) with (.+)")
        if standing and standingFaction then
            local cleanFaction = cleanPunctuation(stripBrackets(standingFaction))
            return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. standing .. ": |r" .. colorBluePurple .. cleanFaction .. "|r")
        end

        local repMsg = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("%[", ""):gsub("%]", "")
        local faction, amount = repMsg:match("Your reputation with (.-) has increased by (%d+)")
        if not faction then faction, amount = repMsg:match("Your (.-) reputation has increased by (%d+)") end
        if not faction then faction, amount = repMsg:match("Your Warband's reputation with (.-) increased by (%d+)") end
        if not faction then faction, amount = repMsg:match("Reputation with (.-) increased by (%d+)%.?") end
        if not faction then amount, faction = repMsg:match("(%d+) reputation with (.-) gained") end
        if not faction then
            faction, amount = repMsg:match("^(.-)%s+judges your Warband more worthy%.?%s*(%d+)%s+reputation gained")
        end
        if faction and amount then
            faction = cleanPunctuation(stripBrackets(faction))
            return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. amount .. " Reputation: |r" .. colorBluePurple .. faction .. "|r")
        end

        local repFaction, repAmount = message:match("Your reputation with (.-) has decreased by (%d+)")
        if not repFaction then repFaction, repAmount = message:match("Reputation with (.-) decreased by (%d+)") end
        if not repFaction then repAmount, repFaction = message:match("(%d+) reputation with (.-) lost") end
        if not repFaction then repFaction, repAmount = message:match("(.-) reputation decreased by (%d+)") end
        if repFaction and repAmount then
            return spaceBeforeX(colorMinus .. "-|r " .. colorWhite .. repAmount .. " Reputation: |r" .. colorBluePurple .. repFaction .. "|r")
        end

        return nil
    end

    function api.FormatQueueNotice(message)
        if not message or type(message) ~= "string" then return nil end

        local queueMsg = message:lower()
        if queueMsg:find("joined the queue") or queueMsg:find("joined queue") or
           queueMsg:find("entering battleground") or queueMsg:find("entered battleground") or
           queueMsg:find("battlefield queue") then
            local bgType = "Unknown"
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
            return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. "Joined the queue: |r" .. colorQueue .. bgType .. "|r")
        end

        if message:match("^You are now saved to this instance%.?$") then
            return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. "Saved to instance|r")
        end

        local hasWin = queueMsg:find("victory") or queueMsg:find("win") or queueMsg:find("won")
        local hasLoss = queueMsg:find("defeat") or queueMsg:find("lose") or queueMsg:find("lost")
        local isBattle = queueMsg:find("honor") or queueMsg:find("arena") or queueMsg:find("battleground") or queueMsg:find("battle")
        if (hasWin or hasLoss) and isBattle then
            return true
        end

        return nil
    end

    function api.FormatSkillMessage(message, plainText, prefixPlus, prefixMinus)
        if not message or type(message) ~= "string" then return nil end
        plainText = (type(plainText) == "string" and plainText) or message

        local learned = message:match("You have learned a new spell: (.+)") or message:match("You have learned: (.+)") or
            message:match("You have learned how to create:? (.+)") or message:match("You have learned the recipe:? (.+)") or
            message:match("Recipe learned: (.+)") or message:match("You have learned a new ability: (.+)") or
            message:match("You have learned the ability: (.+)") or message:match("Ability learned: (.+)")
        if learned then
            local display = cleanPunctuation(stripBrackets(learned))
            display = display:gsub("^a new item: ", ""):gsub("^a new spell: ", ""):gsub("^a new ability: ", "")
            if display:match("%b()%s*$") then
                lastLearnedSkillName = api.NormalizeSkillName(display)
                lastLearnedSkillTime = GetTime and GetTime() or 0
            end
            return spaceBeforeX(prefixPlus .. colorWhite .. "Learned: " .. "|r" .. colorPurple .. display .. "|r")
        end

        local unlearned = message:match("You have unlearned: (.+)") or message:match("You have unlearned (.+)") or
            message:match("Talent unlearned: (.+)") or message:match("You have forgotten: (.+)") or
            message:match("You have forgotten (.+)") or message:match("Spell unlearned: (.+)") or
            message:match("Ability unlearned: (.+)")
        if unlearned then
            local display = cleanPunctuation(stripBrackets(unlearned))
            display = display:gsub("^a new item: ", ""):gsub("^a new spell: ", ""):gsub("^a new ability: ", "")
            return spaceBeforeX(prefixMinus .. colorWhite .. "Unlearned: " .. "|r" .. colorPurple .. display .. "|r")
        end

        local gainedSkill = plainText:match("[Yy]ou have gained the (.-) skill[%.,!]?%s*$")
        if gainedSkill then
            local display = cleanPunctuation(stripBrackets(gainedSkill))
            local now = GetTime and GetTime() or 0
            if lastLearnedSkillName and api.NormalizeSkillName(display) == lastLearnedSkillName and (now - lastLearnedSkillTime) <= learnedSkillDedupSeconds then
                return true
            end
            return spaceBeforeX(prefixPlus .. colorWhite .. "Skill: |r" .. colorPurple .. display .. "|r")
        end

        local skill, skillRank = message:match("Your skill in (.-) has increased to (%d+)")
        if skill and skillRank then
            return spaceBeforeX(prefixPlus .. colorWhite .. skillRank .. " Skill: |r" .. colorPurple .. skill .. "|r")
        end

        return nil
    end

    function api.ApplyLevelUpGlobalStringStyling()
        if originalLevelUpGlobals then return end

        originalLevelUpGlobals = {
            LEVEL_UP = _G.LEVEL_UP,
            LEVEL_UP_HEALTH = _G.LEVEL_UP_HEALTH,
            LEVEL_UP_HEALTH_MANA = _G.LEVEL_UP_HEALTH_MANA,
            LEVEL_UP_CHAR_POINTS = _G.LEVEL_UP_CHAR_POINTS,
            LEVEL_UP_STAT = _G.LEVEL_UP_STAT,
        }

        local levelColor = getClassColorForName(UnitName("player") or "")
        _G.LEVEL_UP = levelColor .. "Reached Level %d|r"
        _G.LEVEL_UP_HEALTH = colorPlus .. "+|r " .. levelColor .. "%d Hit Points|r"
        _G.LEVEL_UP_HEALTH_MANA = colorPlus .. "+|r " .. levelColor .. "%d Hit Points|r, " .. colorPlus .. "+|r " .. levelColor .. "%d Mana|r"
        _G.LEVEL_UP_CHAR_POINTS = colorPlus .. "+|r " .. levelColor .. "%d Talent Points|r"
        _G.LEVEL_UP_STAT = "Your %s increases by %d"
    end

    return api
end
