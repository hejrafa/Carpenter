--[[ Carpenter - ChatCleaner system/level helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local System = ns.Private.ChatCleanerSystem or {}
ns.Private.ChatCleanerSystem = System

local ReadableNumber = Carpenter.Secret.ReadableNumber
local ReadableString = Carpenter.Secret.ReadableString

function System.Create(config)
    config = config or {}
    local cleanPunctuation = config.CleanPunctuation or function(text) return text end
    local stripBrackets = config.StripBrackets or function(text) return text end
    local spaceBeforeX = config.SpaceBeforeX or function(text) return text end
    local colorPlus = config.ColorPlus or "|cffc8c8c8"
    local colorMinus = config.ColorMinus or "|cffc8c8c8"
    local colorWhite = config.ColorWhite or "|cffffffff"
    local colorBluePurple = config.ColorBluePurple or "|cff9d8cff"
    local colorQueue = config.ColorQueue or "|cff80b0ff"
    local colorPurple = config.ColorPurple or "|cffb794f4"
    local colorTransmog = config.ColorTransmog or "|cffff80ff"
    local colorTeal = config.ColorTeal or "|cff00ccaa"
    local colorYellow = config.ColorYellow or "|cffffd200"
    local getItemLinkFromMessage = config.GetItemLinkFromMessage or function() return nil end
    local isMainlineClient = config.IsMainlineClient or function() return false end
    local L = config.L or (Carpenter and Carpenter.L) or {}

    local function T(key, fallback, ...)
        local text = L[key] or fallback or key
        if select("#", ...) > 0 then
            return string.format(text, ...)
        end
        return text
    end

    local api = {}
    local lastLearnedSkillName, lastLearnedSkillTime = nil, 0
    local learnedSkillDedupSeconds = config.LearnedSkillDedupSeconds or 3
    -- The last "Learned" line each chat frame showed. The filter runs once per
    -- frame for the same message, so the lines are tracked per frame.
    local lastLearnedLines = setmetatable({}, { __mode = "k" })
    local sharedLearnedLineKey = {}

    -- The learned name as shown, without colors, link data, or brackets (two
    -- spells with one name have different links), split into the name and a
    -- trailing "(Journeyman)" or "(Rank 2)".
    local function PlainLearnedName(display)
        local name = display:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
        name = name:gsub("[%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
        local base, rank = name:match("^(.-)%s*(%b())$")
        if base and base ~= "" then
            return base, rank
        end
        return name, ""
    end

    -- A profession rank teaches two spells that share a name, and the game
    -- announces both ("Cooking (Journeyman)" then "Cooking", or "Fishing"
    -- twice), so the same name again within a moment is dropped. Two different
    -- ranks, like "(Rank 2)" then "(Rank 3)", are separate lessons and both show.
    local function IsRepeatedLearnedLine(frame, display)
        local key = frame or sharedLearnedLineKey
        local name, rank = PlainLearnedName(display)
        local now = GetTime and GetTime() or 0
        local last = lastLearnedLines[key]
        if last and last.name == name and (now - last.time) <= learnedSkillDedupSeconds
            and (last.rank == rank or last.rank == "" or rank == "") then
            last.time = now
            return true
        end
        lastLearnedLines[key] = { name = name, rank = rank, time = now }
        return false
    end

    local function ShouldSuppressStoryModeQuestAccepted(message)
        local storyMode = _G.StoryMode
        local suppress = storyMode and storyMode.ShouldSuppressQuestAcceptedSystemMessage
        if type(suppress) ~= "function" then return false end

        local ok, result = pcall(suppress, message)
        return ok and result == true
    end

    function api.IsLevelUpRewardEvent(event)
        return event == "CHAT_MSG_SYSTEM" or
            event == "CHAT_MSG_COMBAT_XP_GAIN" or
            event == "CHAT_MSG_COMBAT_MISC_INFO"
    end

    -- The level the game counts as the top for this client's players.
    local function MaxPlayerLevel()
        local level = type(GetMaxPlayerLevel) == "function" and ReadableNumber(GetMaxPlayerLevel())
        return level or 60
    end

    local function GainedPoints(amount, one, many)
        local word = tonumber(amount) == 1 and one or many
        return colorPlus .. "+|r " .. colorWhite .. amount .. " " .. word .. "|r"
    end

    -- Level-up lines, yours and other players': the game's LEVEL_UP,
    -- LEVEL_UP_HEALTH(_MANA), LEVEL_UP_CHAR_POINTS and LEVEL_UP_STAT, and
    -- "<name> has reached level N" lines.
    function api.FormatLevelUpRewardMessage(plainText)
        if not plainText or type(plainText) ~= "string" then return nil end

        -- Forever links the level: "you have reached [Level 12]!".
        plainText = plainText:gsub("[%[%]]", "")
        local levelColor = colorWhite

        local selfLevel = plainText:match("^%s*[Cc]ongratulations,?%s+you%s+have%s+reached%s+[Ll]evel%s+(%d+)") or
            plainText:match("^%s*[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$") or
            plainText:match("^%s*[Yy]ou%s+[Hh]ave%s+[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$") or
            plainText:match("^%s*[Yy]ou%s+[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
        if selfLevel then
            return levelColor .. T("CHAT_REACHED_LEVEL_NO_NAME", "Reached level %s", selfLevel) .. "|r"
        end

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
            local lowerName = name:lower()
            if lowerName == "you" or lowerName == "has" or lowerName == "have" or lowerName == "reached" or lowerName == "reach" or lowerName == "congratulations" then
                return nil
            end

            if tonumber(levelNum) == MaxPlayerLevel() then
                return colorYellow .. T("CHAT_REACHED_LEVEL", "%s reached level %s", name, levelNum) .. "|r"
            end

            return levelColor .. T("CHAT_REACHED_LEVEL", "%s reached level %s", name, levelNum) .. "|r"
        end

        local otherName, otherLevel = plainText:match("^%s*(.-)%s+[Hh]as%s+[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
        local styledOther = FormatOtherPlayerLevel(otherName, otherLevel)
        if styledOther then return styledOther end

        otherName, otherLevel = plainText:match("^%s*(.-)%s+[Rr]eached%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
        styledOther = FormatOtherPlayerLevel(otherName, otherLevel)
        if styledOther then return styledOther end

        -- Two patterns, one at a time: `a, b = x:match() or y:match()` would
        -- keep only the name.
        otherName, otherLevel = plainText:match("^%s*[Cc]ongratulations%s+to%s+(.+)%s+on%s+[Rr]eaching%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
        if not otherName then
            otherName, otherLevel = plainText:match("^%s*[Cc]ongratulations%s+to%s+(.+)%s+for%s+[Rr]eaching%s+[Ll]evel%s+(%d+)%s*[%!%.,]?%s*$")
        end
        styledOther = FormatOtherPlayerLevel(otherName, otherLevel)
        if styledOther then return styledOther end

        local hitPoint, hitPoints = T("CHAT_HIT_POINT", "Hit Point"), T("CHAT_HIT_POINTS", "Hit Points")
        local healthAmount, manaAmount = plainText:match("[Gg]ained%s+(%d+)%s+[Hh]it [Pp]oints?%s+and%s+(%d+)%s+[Mm]ana")
        if healthAmount then
            local mana = _G.MANA or "Mana"
            return GainedPoints(healthAmount, hitPoint, hitPoints) .. ", " .. GainedPoints(manaAmount, mana, mana)
        end

        local hitAmount = plainText:match("[Gg]ained%s*:?.-%s*(%d+)%s+[Hh]it [Pp]oint")
        if hitAmount then
            return GainedPoints(hitAmount, hitPoint, hitPoints)
        end

        local talentAmount = plainText:match("[Gg]ained%s*:?.-%s*(%d+)%s+[Tt]alent [Pp]oint")
        if talentAmount then
            return GainedPoints(talentAmount, T("CHAT_TALENT_POINT", "Talent Point"), T("CHAT_TALENT_POINTS", "Talent Points"))
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
            return spaceBeforeX(colorWhite .. T("CHAT_EXPLORING_ZONE", "Exploring a new zone: %s", exploredZone) .. "|r")
        end

        local xp = message:match("You gain (%d+) experience") or message:match("Experience gained: (%d+)")
        if xp then
            return spaceBeforeX(prefixPlus .. colorWhite .. xp .. " |r" .. colorWhite .. "EXP|r")
        end

        return nil
    end

    -- "You've completed the set %s." (ERR_COMPLETED_TRANSMOG_SET_S) as a
    -- pattern that captures the set's name, built from the client's own
    -- string so every locale matches.
    local completedSetPattern
    local function GetCompletedSetPattern()
        if completedSetPattern then return completedSetPattern end
        local template = _G.ERR_COMPLETED_TRANSMOG_SET_S
        if type(template) ~= "string" or not template:find("%s", 1, true) then
            template = "You've completed the set %s."
        end
        local pattern = template:gsub("%%s", "\1")
        pattern = pattern:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        pattern = pattern:gsub("%%%.%s*$", "%%.?")
        pattern = pattern:gsub("\1", "(.-)")
        completedSetPattern = "^%s*" .. pattern .. "%s*$"
        return completedSetPattern
    end

    -- The set's name alone, in the appearance color: its link keeps working
    -- but loses its brackets and the color the game gave it.
    local function FormatCompletedSet(setName, prefixPlus)
        local display = cleanPunctuation(setName)
        display = display:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        display = display:gsub("|h%[(.-)%]|h", "|h%1|h")
        display = stripBrackets(display):gsub("^%s+", ""):gsub("%s+$", "")
        if display == "" then return nil end
        return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_COMPLETED_LABEL", "Completed:") .. " |r" .. colorTransmog .. display .. "|r")
    end

    function api.FormatQuestProgressMessage(event, message, plainText, prefixPlus)
        if event ~= "CHAT_MSG_SYSTEM" or not message or type(message) ~= "string" then return nil end
        plainText = (type(plainText) == "string" and plainText) or message

        local function IsGenericCompletionTitle(title)
            if not title or type(title) ~= "string" then return false end
            local normalized = cleanPunctuation(stripBrackets(title)):lower():gsub("^%s+", ""):gsub("%s+$", "")
            return normalized == "that quest" or normalized == "the quest" or normalized == "quest"
        end

        local function CleanQuestTitle(title)
            title = cleanPunctuation(stripBrackets(title))
            if type(title) ~= "string" then return nil end
            title = title:gsub("^%s+", ""):gsub("%s+$", "")
            if title == "" or IsGenericCompletionTitle(title) then return nil end
            return title
        end

        local function CompletedLabel()
            return (T("CHAT_COMPLETED_LABEL", "Completed:"):gsub("%s*:%s*$", ""))
        end

        local lowerPlainText = plainText:lower()
        local questAccepted = nil
        if lowerPlainText:find("quest accepted:") then
            questAccepted = message:match("[Qq]uest [Aa]ccepted: (.+)") or message:match("[Qq]uest [Aa]ccepted (.+)")
        end

        -- A completed transmog set reads like a completed quest; show it as
        -- "Completed: <set>" without "the set".
        local completedSet = message:match(GetCompletedSetPattern())
        if completedSet then
            local formatted = FormatCompletedSet(completedSet, prefixPlus)
            if formatted then return formatted end
        end

        -- "<quest> completed." (ERR_QUEST_COMPLETE_S).
        local questCompleted = message:match("^(.+) [Cc]ompleted%.?%s*$") or
            message:match("[Qq]uest [Cc]ompleted: (.+)") or
            message:match("[Qq]uest [Cc]ompleted (.+)")

        if questAccepted then
            if ShouldSuppressStoryModeQuestAccepted(message) then
                return true
            end
            local cleanQuest = CleanQuestTitle(questAccepted)
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_ACCEPTED_LABEL", "Accepted:") .. " |r" .. colorYellow .. (cleanQuest or cleanPunctuation(stripBrackets(questAccepted))) .. "|r")
        elseif questCompleted then
            if IsGenericCompletionTitle(questCompleted) then
                return spaceBeforeX(prefixPlus .. colorWhite .. CompletedLabel() .. "|r")
            end

            local cleanQuest = CleanQuestTitle(questCompleted)
            if not cleanQuest then
                return nil
            end
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_COMPLETED_LABEL", "Completed:") .. " |r" .. colorYellow .. cleanQuest .. "|r")
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
            return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. amount .. " " .. T("CHAT_REPUTATION_LABEL", "Reputation:") .. " |r" .. colorBluePurple .. faction .. "|r")
        end

        faction, amount = repMsg:match("Your reputation with (.-) has decreased by (%d+)")
        if not faction then faction, amount = repMsg:match("Your (.-) reputation has decreased by (%d+)") end
        if not faction then faction, amount = repMsg:match("Reputation with (.-) decreased by (%d+)") end
        if not faction then amount, faction = repMsg:match("(%d+) reputation with (.-) lost") end
        if not faction then faction, amount = repMsg:match("(.-) reputation decreased by (%d+)") end
        if faction and amount then
            faction = cleanPunctuation(stripBrackets(faction))
            return spaceBeforeX(colorMinus .. Carpenter.MinusSign .. "|r " .. colorWhite .. amount .. " " .. T("CHAT_REPUTATION_LABEL", "Reputation:") .. " |r" .. colorBluePurple .. faction .. "|r")
        end

        return nil
    end

    local function IsQueueNoticeEvent(event)
        return not event or event == "CHAT_MSG_SYSTEM" or
            event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or
            event == "CHAT_MSG_BG_SYSTEM_HORDE" or
            event == "CHAT_MSG_BG_SYSTEM_NEUTRAL"
    end

    local function JoinedQueueText(name)
        return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. T("CHAT_JOINED_QUEUE_LABEL", "Joined the queue:") .. " |r" .. colorQueue .. name .. "|r")
    end

    local function LeftQueueText(name)
        if not name then
            return spaceBeforeX(colorMinus .. Carpenter.MinusSign .. "|r " .. colorWhite .. T("CHAT_LEFT_QUEUE", "Left the queue") .. "|r")
        end
        return spaceBeforeX(colorMinus .. Carpenter.MinusSign .. "|r " .. colorWhite .. T("CHAT_LEFT_QUEUE_LABEL", "Left the queue:") .. " |r" .. colorQueue .. name .. "|r")
    end

    -- How far before a queue change its line can come (a probe's log): a
    -- join's line comes in the same moment as the queue; leaving, the game
    -- answers with the line and the queue goes about a quarter second later
    -- (0.25 to 0.3 s, three times). Each change carries its window and is
    -- kept a few seconds, for a line that comes after it.
    local QUEUE_CHANGE_WINDOW_SECONDS = 3
    local SAME_MOMENT_SECONDS = 0.2
    local LEAVE_LINE_SECONDS = 1
    local queueChanges = {}

    -- "You are no longer queued." doesn't say which queue. It comes before
    -- its queue goes, so ChatCleaner names the shown line once the queue has;
    -- should the queue go first, the line is named here.
    local function LeftQueueName()
        local now = GetTime and GetTime() or 0
        for index = #queueChanges, 1, -1 do
            local change = queueChanges[index]
            if now - change.time > SAME_MOMENT_SECONDS then return nil end
            if change.kind == "left" and not change.named then return change.name end
        end
    end

    -- The unnamed leave line, as shown before its queue is known.
    function api.LeftQueueText()
        return LeftQueueText()
    end

    -- "You have joined the queue for %s." and its kin, as patterns that take
    -- the battleground's name, so one the list below doesn't know (Darkspear
    -- Islands) is still named. The English wording backs up the game's.
    local QUEUE_JOIN_STRINGS = {
        "ERR_SOLO_JOIN_BATTLEGROUND_SPEC_S", "ERR_SOLO_JOIN_BATTLEGROUND_S", "ERR_GROUP_JOIN_BATTLEGROUND_S",
        "ERR_JOIN_SINGLE_SCENARIO_S", "ERR_SOLO_JOIN_TRAINING_GROUND",
    }
    local QUEUE_JOIN_FALLBACKS = {
        "You have joined the queue for %s as %s.", "You have joined the queue for %s.",
        "Your group has joined the queue for %s.",
    }
    local queueJoinPatterns

    local function QueueJoinPatterns()
        if queueJoinPatterns then return queueJoinPatterns end
        queueJoinPatterns = {}
        local function Add(format)
            if type(format) ~= "string" or not format:find("%s", 1, true) then return end
            local pattern = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.-)")
            queueJoinPatterns[#queueJoinPatterns + 1] = "^" .. pattern .. "$"
        end
        for _, key in ipairs(QUEUE_JOIN_STRINGS) do Add(_G[key]) end
        for _, format in ipairs(QUEUE_JOIN_FALLBACKS) do Add(format) end
        return queueJoinPatterns
    end

    local function QueuedName(message)
        for _, pattern in ipairs(QueueJoinPatterns()) do
            local name = message:match(pattern)
            if name and name ~= "" then return name end
        end
    end

    function api.FormatQueueNotice(message, event)
        if not message or type(message) ~= "string" then return nil end
        if not IsQueueNoticeEvent(event) then return nil end

        local queuedName = QueuedName(message)
        if queuedName then return JoinedQueueText(queuedName) end

        if message:match("^You are no longer queued%.?$") then
            return LeftQueueText(LeftQueueName())
        end

        if message:match("^You are now saved to this instance%.?$") then
            return spaceBeforeX(colorPlus .. "+|r " .. colorWhite .. T("CHAT_SAVED_TO_INSTANCE", "Saved to instance") .. "|r")
        end

        -- A battle's result ("Your team lost the battle."): the scoreboard
        -- already shows it. Whole words only, so "Wintergrasp" or "close"
        -- don't count.
        local lower = message:lower()
        local function HasWord(word) return lower:find("%f[%a]" .. word .. "%f[%A]") ~= nil end
        local isResult = HasWord("victory") or HasWord("win") or HasWord("won") or HasWord("defeat") or
            HasWord("lose") or HasWord("lost")
        local isBattle = HasWord("honor") or HasWord("arena") or HasWord("battleground") or HasWord("battle")
        if isResult and isBattle then
            return true
        end

        return nil
    end

    function api.FormatSkillMessage(message, plainText, prefixPlus, prefixMinus, frame)
        if not message or type(message) ~= "string" then return nil end
        plainText = (type(plainText) == "string" and plainText) or message

        local learned = message:match("You have learned a new spell: (.+)") or message:match("You have learned: (.+)") or
            message:match("You have learned a new passive effect: (.+)") or
            message:match("You have learned how to create:? (.+)") or message:match("You have learned the recipe:? (.+)") or
            message:match("Recipe learned: (.+)") or message:match("You have learned a new ability: (.+)") or
            message:match("You have learned the ability: (.+)") or message:match("Ability learned: (.+)")
        if learned then
            local display = cleanPunctuation(stripBrackets(learned))
            display = display:gsub("^a new item: ", ""):gsub("^a new spell: ", ""):gsub("^a new ability: ", "")
            -- A profession rank ("Cooking (Apprentice)") is followed by "You have
            -- gained the Cooking skill.", which says the same.
            local name, rank = PlainLearnedName(display)
            if rank ~= "" then
                lastLearnedSkillName = name
                lastLearnedSkillTime = GetTime and GetTime() or 0
            end
            if IsRepeatedLearnedLine(frame, display) then
                return true
            end
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_LEARNED_LABEL", "Learned:") .. " |r" .. colorPurple .. display .. "|r")
        end

        local unlearned = message:match("You have unlearned: (.+)") or message:match("You have unlearned (.+)") or
            message:match("Talent unlearned: (.+)") or message:match("You have forgotten: (.+)") or
            message:match("You have forgotten (.+)") or message:match("Spell unlearned: (.+)") or
            message:match("Ability unlearned: (.+)")
        if unlearned then
            local display = cleanPunctuation(stripBrackets(unlearned))
            display = display:gsub("^a new item: ", ""):gsub("^a new spell: ", ""):gsub("^a new ability: ", "")
            return spaceBeforeX(prefixMinus .. colorWhite .. T("CHAT_UNLEARNED_LABEL", "Unlearned:") .. " |r" .. colorPurple .. display .. "|r")
        end

        local gainedSkill = plainText:match("[Yy]ou have gained the (.-) skill[%.,!]?%s*$")
        if gainedSkill then
            local display = cleanPunctuation(stripBrackets(gainedSkill))
            local now = GetTime and GetTime() or 0
            if lastLearnedSkillName and PlainLearnedName(display) == lastLearnedSkillName and (now - lastLearnedSkillTime) <= learnedSkillDedupSeconds then
                return true
            end
            return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_SKILL_LABEL", "Skill:") .. " |r" .. colorPurple .. display .. "|r")
        end

        local skill, skillRank = message:match("Your skill in (.-) has increased to (%d+)")
        if skill and skillRank then
            return api.FormatSkillRise({ name = skill, rank = skillRank }, prefixPlus)
        end

        return nil
    end

    function api.FormatSkillRise(rise, prefixPlus)
        return spaceBeforeX(prefixPlus .. colorWhite .. rise.rank .. " " .. T("CHAT_SKILL_LABEL", "Skill:") .. " |r" ..
            colorPurple .. rise.name .. "|r")
    end

    -- WoW Forever hides skill-up text from addons during chat messaging
    -- lockdown (combat in instances), but skill ranks stay readable. Each rank
    -- that goes up is kept a few seconds, so ChatCleanerHiddenLines can
    -- rewrite the hidden line with it; the game reports the new rank just
    -- before or just after it adds the line. One that no line claims soon is
    -- dropped, so it can't land on a later line.
    local SKILL_RISE_WINDOW_SECONDS = 3
    local skillRanks = {}
    local skillRises = {}

    local function ForEachSkillLine(callback)
        local skillInfo = C_SkillInfo
        if skillInfo and skillInfo.GetNumSkillLines and skillInfo.GetSkillLineInfo then
            for index = 1, skillInfo.GetNumSkillLines() do
                local info = skillInfo.GetSkillLineInfo(index)
                local name, rank = info and ReadableString(info.name), info and ReadableNumber(info.rank)
                if name and rank and not info.isHeader then
                    callback(info.skillID or name, name, rank)
                end
            end
        elseif GetNumSkillLines and GetSkillLineInfo then
            for index = 1, GetNumSkillLines() do
                local name, isHeader, _, rank = GetSkillLineInfo(index)
                name, rank = ReadableString(name), ReadableNumber(rank)
                if name and rank and not isHeader then
                    callback(name, name, rank)
                end
            end
        end
    end

    function api.RefreshSkillRanks()
        local now = GetTime and GetTime() or 0
        while skillRises[1] and now - skillRises[1].time > SKILL_RISE_WINDOW_SECONDS do
            table.remove(skillRises, 1)
        end

        pcall(ForEachSkillLine, function(key, name, rank)
            local previous = skillRanks[key]
            if previous and rank > previous then
                skillRises[#skillRises + 1] = { name = name, rank = rank, time = now }
            end
            skillRanks[key] = rank
        end)
    end

    -- A readable skill-up line speaks for itself, so its rise isn't left
    -- waiting for a hidden line.
    function api.ClaimVisibleSkillRise(message)
        api.RefreshSkillRanks()
        for index, rise in ipairs(skillRises) do
            if message:find(rise.name, 1, true) then
                table.remove(skillRises, index)
                return
            end
        end
    end

    -- Recent rises, oldest first: { name, rank, time }.
    function api.GetSkillRises()
        api.RefreshSkillRanks()
        return skillRises
    end

    -- WoW Forever hides system lines from addons inside battlegrounds, so
    -- "You have joined the queue for Warsong Gulch." asked for from there
    -- can't be read, and "You are no longer queued." never names its queue.
    -- The queues stay readable: each one that starts or ends is noted with
    -- its battleground, so its line can be named.
    local queueStates

    -- Each queue slot's status ("none", "queued", "confirm", "active") and
    -- battleground name; either is nil while the game hides it.
    local function ReadQueues()
        local states = {}
        if type(GetBattlefieldStatus) ~= "function" then return states end
        local count = type(GetMaxBattlefieldID) == "function" and GetMaxBattlefieldID() or MAX_BATTLEFIELD_QUEUES or 3
        count = ReadableNumber(count) or 0
        for index = 1, count do
            local ok, status, name = pcall(GetBattlefieldStatus, index)
            status = ok and ReadableString(status)
            if status then
                states[index] = { status = status, name = ReadableString(name) }
            else
                -- While the game hides it, the slot keeps its last known state.
                states[index] = queueStates and queueStates[index]
            end
        end
        return states
    end

    function api.RefreshQueues()
        local now = GetTime and GetTime() or 0
        while queueChanges[1] and now - queueChanges[1].time > QUEUE_CHANGE_WINDOW_SECONDS do
            table.remove(queueChanges, 1)
        end

        local states = ReadQueues()
        if queueStates then
            for index, state in pairs(states) do
                local was = queueStates[index] and queueStates[index].status
                if state.status == "queued" and was == "none" and state.name then
                    queueChanges[#queueChanges + 1] = {
                        kind = "joined", name = state.name, time = now, window = SAME_MOMENT_SECONDS,
                    }
                elseif state.status == "none" and (was == "queued" or was == "confirm") then
                    queueChanges[#queueChanges + 1] = {
                        kind = "left", name = queueStates[index].name, time = now, window = LEAVE_LINE_SECONDS,
                    }
                end
            end
        end
        queueStates = states
    end

    -- Recent queue changes, oldest first: { kind = "joined" or "left", name,
    -- time, window }, where window is how long before the change its line
    -- can come.
    function api.GetQueueChanges()
        api.RefreshQueues()
        return queueChanges
    end

    function api.FormatQueueChange(change)
        if change.kind == "joined" then return JoinedQueueText(change.name) end
        return LeftQueueText(change.name)
    end

    function api.FormatAppearanceCollectionMessage(event, message, plainText, prefixPlus)
        if event ~= "CHAT_MSG_SYSTEM" or not isMainlineClient() then return nil end
        if not message or type(message) ~= "string" then return nil end
        plainText = (type(plainText) == "string" and plainText) or message

        local appearance = plainText:match("^%s*(.-)%s+has been added to your appearance collection%.?%s*$")
        if not appearance or appearance == "" then return nil end

        local itemLink = getItemLinkFromMessage(message)
        local display
        if itemLink then
            itemLink = itemLink:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            display = colorTransmog .. itemLink .. "|r"
        else
            display = colorTransmog .. cleanPunctuation(stripBrackets(appearance)) .. "|r"
        end

        return spaceBeforeX(prefixPlus .. colorWhite .. T("CHAT_APPEARANCE_LABEL", "Appearance:") .. " |r" .. display)
    end

    return api
end
