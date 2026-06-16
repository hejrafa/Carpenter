--[[ Carpenter - ChatCleaner social/group message helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Social = ns.Private.ChatCleanerSocial or {}
ns.Private.ChatCleanerSocial = Social

function Social.Create(config)
    config = config or {}
    local getPartyOrRaidMessageColor = config.GetPartyOrRaidMessageColor or function() return "|cfff0f0f0" end
    local colorGreen = config.ColorGreen or "|cff00ff00"
    local colorRed = config.ColorRed or "|cffff4040"
    local colorOrange = config.ColorOrange or "|cffff8000"
    local colorDarkorange = config.ColorDarkorange or "|cffff6600"
    local colorWhite = config.ColorWhite or "|cffffffff"
    local colorQueue = config.ColorQueue or "|cff80b0ff"
    local colorRestedBar = config.ColorRestedBar or "|cff3399ff"
    local colorNormalBar = config.ColorNormalBar or "|cff9940ff"
    local colorFriendTag = config.ColorFriendTag or "|cff7dd3fc"
    local colorGuildTag = config.ColorGuildTag or "|cff86efac"
    local colorSocialAction = config.ColorSocialAction or "|cffb8b8b8"
    local cleanPunctuation = config.CleanPunctuation or function(text) return text end
    local L = config.L or (Carpenter and Carpenter.L) or {}

    local function T(key, fallback, ...)
        local text = L[key] or fallback or key
        if select("#", ...) > 0 then
            return string.format(text, ...)
        end
        return text
    end

    local api = {}

    local function Trim(text)
        return (text and text:gsub("^%s+", ""):gsub("%s+$", "") or "")
    end

    local function ShortPlayerName(name)
        if not name or type(name) ~= "string" then return "" end
        name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        name = name:gsub("|Hplayer:[^|]+|h%[(.-)%]|h", "%1")
        name = name:gsub("|Hplayer:[^|]+|h(.-)|h", "%1")
        name = Trim(name):gsub("^%[(.-)%]$", "%1")

        if Ambiguate then
            local ok, short = pcall(Ambiguate, name, "short")
            if ok and short and short ~= "" then
                name = short
            end
        end

        return Trim(name):gsub("%-.*$", "")
    end

    local function PlayerKey(name)
        name = ShortPlayerName(name)
        if name == "" then return nil end
        return name:lower()
    end

    local function ClassTokenFromName(className)
        if not className or className == "" then return nil end
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[className] then return className end

        local maleNames = _G.LOCALIZED_CLASS_NAMES_MALE
        if type(maleNames) == "table" then
            for token, localized in pairs(maleNames) do
                if localized == className then return token end
            end
        end

        local femaleNames = _G.LOCALIZED_CLASS_NAMES_FEMALE
        if type(femaleNames) == "table" then
            for token, localized in pairs(femaleNames) do
                if localized == className then return token end
            end
        end

        return nil
    end

    local function ClassColorCode(classToken)
        local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
        if not color then return colorWhite end
        if color.colorStr and type(color.colorStr) == "string" then
            return "|c" .. color.colorStr
        end

        local r = math.floor((color.r or 1) * 255)
        local g = math.floor((color.g or 1) * 255)
        local b = math.floor((color.b or 1) * 255)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end

    local function GetFriendCount()
        if C_FriendList and C_FriendList.GetNumFriends then
            local ok, count = pcall(C_FriendList.GetNumFriends)
            if ok and count then return count end
        end
        if GetNumFriends then
            local ok, count = pcall(GetNumFriends)
            if ok and count then return count end
        end
        return 0
    end

    local function GetFriendRecord(targetKey)
        if not targetKey then return nil end

        for i = 1, GetFriendCount() do
            if C_FriendList and C_FriendList.GetFriendInfoByIndex then
                local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
                if ok and type(info) == "table" and PlayerKey(info.name) == targetKey then
                    return {
                        source = "friend",
                        classToken = ClassTokenFromName(info.classFileName or info.className),
                    }
                end
            elseif GetFriendInfo then
                local ok, name, _, className = pcall(GetFriendInfo, i)
                if ok and PlayerKey(name) == targetKey then
                    return {
                        source = "friend",
                        classToken = ClassTokenFromName(className),
                    }
                end
            end
        end

        return nil
    end

    local function GetGuildCount()
        if not GetNumGuildMembers then return 0 end

        local ok, count = pcall(GetNumGuildMembers, true)
        if ok and count then return count end

        ok, count = pcall(GetNumGuildMembers)
        if ok and count then return count end

        return 0
    end

    local function GetGuildRecord(targetKey)
        if not targetKey or not GetGuildRosterInfo then return nil end

        for i = 1, GetGuildCount() do
            local ok, name, _, _, _, className, _, _, _, _, _, classFileName = pcall(GetGuildRosterInfo, i)
            if ok and PlayerKey(name) == targetKey then
                return {
                    source = "guild",
                    classToken = ClassTokenFromName(classFileName or className),
                }
            end
        end

        return nil
    end

    local function GetSocialNoticeRecord(name)
        local targetKey = PlayerKey(name)
        if not targetKey then return nil end

        return GetGuildRecord(targetKey) or GetFriendRecord(targetKey) or { source = "friend" }
    end

    local function FormatSocialNotice(name, actionKey, actionFallback)
        local shortName = ShortPlayerName(name)
        if shortName == "" then return nil end

        local record = GetSocialNoticeRecord(shortName) or { source = "friend" }
        local isGuild = record.source == "guild"
        local labelKey = isGuild and "CHAT_GUILD_LABEL" or "CHAT_FRIEND_LABEL"
        local labelFallback = isGuild and "Guild" or "Friend"
        local tagColor = isGuild and colorGuildTag or colorFriendTag
        local nameColor = ClassColorCode(record.classToken)

        return tagColor .. "[" .. T(labelKey, labelFallback) .. "]|r " ..
            nameColor .. shortName .. "|r " ..
            colorSocialAction .. T(actionKey, actionFallback) .. "|r"
    end

    function api.FormatBattlegroundAndGroupNotice(event, plainSys)
        if not plainSys or type(plainSys) ~= "string" then return nil end

        if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
            local numPlayersJoin = plainSys:match("^(%d+)%s+players have joined the battle%.?%s*$")
            if numPlayersJoin then
                return colorGreen .. T("CHAT_PLAYERS_JOINED", "%s players joined", numPlayersJoin) .. "|r"
            end

            local bgJoin = plainSys:match("^%s*(.-)%s+has joined the battle%.?%s*$")
            if bgJoin and bgJoin ~= "" then
                bgJoin = bgJoin:gsub("^%s+", ""):gsub("%s+$", "")
                if bgJoin ~= "" then
                    return colorGreen .. T("CHAT_PLAYER_JOINED", "%s joined", bgJoin) .. "|r"
                end
            end

            local bgLeave = plainSys:match("^%s*(.-)%s+has left the battle%.?%s*$")
            if bgLeave and bgLeave ~= "" then
                bgLeave = bgLeave:gsub("^%s+", ""):gsub("%s+$", "")
                if bgLeave ~= "" then
                    return colorRed .. T("CHAT_PLAYER_LEFT", "%s left", bgLeave) .. "|r"
                end
            end
        end

        local plainLower = plainSys:lower()
        if plainLower:find("flag") and plainLower:find("has been reset") then
            return colorOrange .. T("CHAT_FLAG_RESET", "Flag reset") .. "|r"
        end

        local groupColor = getPartyOrRaidMessageColor()
        if plainSys:find("Party converted to Raid") then
            return groupColor .. T("CHAT_PARTY_CONVERTED_TO_RAID", "Party converted to Raid") .. "|r"
        end
        if plainSys:find("Raid converted to Party") then
            return groupColor .. T("CHAT_RAID_CONVERTED_TO_PARTY", "Raid converted to Party") .. "|r"
        end

        local raidJoin = plainSys:match("^%s*(.-)%s+has joined the raid group%.?%s*$")
        if raidJoin and raidJoin ~= "" then
            raidJoin = raidJoin:gsub("^%s+", ""):gsub("%s+$", "")
            return groupColor .. T("CHAT_JOINED_RAID", "%s joined the raid", raidJoin) .. "|r"
        end

        local raidLeave = plainSys:match("^%s*(.-)%s+has left the raid group%.?%s*$")
        if raidLeave and raidLeave ~= "" then
            raidLeave = raidLeave:gsub("^%s+", ""):gsub("%s+$", "")
            return groupColor .. T("CHAT_LEFT_RAID", "%s left the raid", raidLeave) .. "|r"
        end

        if plainSys:find("You are in both a party and a battleground group") then
            return groupColor .. T("CHAT_PARTY_AND_BG_GROUP", "You are in a party and a battleground group") .. "|r"
        end
        if plainSys:find("You may communicate with your party") and plainSys:find("/p") and plainSys:find("/bg") then
            return groupColor .. T("CHAT_PARTY_BG_COMMANDS", "Communicate with your party with \"/p\" and with your battleground group with \"/bg\"") .. "|r"
        end
        if plainSys:find("The battle has ended") and (plainSys:find("battleground will close") or plainSys:find("close in")) then
            return colorWhite .. T("CHAT_BATTLE_ENDED", "The battle has ended") .. "|r"
        end

        return nil
    end

    function api.FormatSystemSocialMessage(plainMsg)
        if not plainMsg or type(plainMsg) ~= "string" then return nil end

        if _G.CLEARED_AFK and plainMsg == _G.CLEARED_AFK then
            return colorGreen .. T("CHAT_BACK", "Back") .. "|r"
        end
        if _G.CLEARED_DND and plainMsg == _G.CLEARED_DND then
            return colorGreen .. T("CHAT_AVAILABLE", "Available") .. "|r"
        end
        local onlineName = plainMsg:match("^%s*(.-)%s+has come online%.?%s*$")
        if onlineName and onlineName ~= "" then
            return FormatSocialNotice(onlineName, "CHAT_CAME_ONLINE", "came online")
        end
        local offlineName = plainMsg:match("^%s*(.-)%s+has gone offline%.?%s*$")
        if offlineName and offlineName ~= "" then
            return FormatSocialNotice(offlineName, "CHAT_WENT_OFFLINE", "went offline")
        end
        if _G.MARKED_AFK and plainMsg == _G.MARKED_AFK then
            return colorOrange .. T("CHAT_AFK", "AFK") .. "|r"
        end
        local afkCustom = plainMsg:match("^You are now Away: (.+)$") or plainMsg:match("^You are now AFK: (.+)$")
        if afkCustom and afkCustom ~= "" then
            afkCustom = afkCustom:gsub("^%s+", ""):gsub("%s+$", "")
            if afkCustom == "" or afkCustom:lower() == "afk" then
                return colorOrange .. T("CHAT_AFK", "AFK") .. "|r"
            end
            return colorOrange .. T("CHAT_AFK_WITH_MESSAGE", "AFK: %s", afkCustom) .. "|r"
        end
        if _G.MARKED_DND and plainMsg:match("^You are now Busy") then
            return colorDarkorange .. T("CHAT_BUSY", "Busy") .. "|r"
        end
        if plainMsg:match("^You are now flagged for PvP combat") then
            return colorRed .. T("CHAT_FLAGGED_PVP", "Flagged for PvP") .. "|r"
        end
        if plainMsg:match("^You feel rested%.?%s*$") or (plainMsg:lower():find("feel rested") and plainMsg:lower():find("you")) then
            return colorRestedBar .. T("CHAT_RESTED", "Rested") .. "|r"
        end
        if plainMsg:match("^You feel normal%.?%s*$") or (plainMsg:lower():find("feel normal") and plainMsg:lower():find("you")) then
            return colorNormalBar .. T("CHAT_NORMAL", "Normal") .. "|r"
        end
        local homeLocation = plainMsg:match("^(.+) is now your home%.?%s*$")
        if homeLocation and homeLocation ~= "" then
            return colorWhite .. T("CHAT_HOME_LABEL", "Hearthstone:") .. " |r" .. colorQueue .. cleanPunctuation(homeLocation) .. "|r"
        end

        if plainMsg:find("Ready Check") and plainMsg:find("failed") then
            return colorRed .. T("CHAT_READY_CHECK_FAILED", "Ready Check failed") .. "|r"
        end
        local notReadyName = plainMsg:match("^%s*(.-)%s+is not ready%.?%s*$")
        if notReadyName and notReadyName ~= "" then
            local short = notReadyName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorRed .. T("CHAT_NOT_READY", "%s not ready", short) .. "|r"
        end
        local alreadyInGroup = plainMsg:match("^%s*(.-)%s+is already in a group%.?%s*$")
        if alreadyInGroup and alreadyInGroup ~= "" then
            local short = alreadyInGroup:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorRed .. T("CHAT_ALREADY_IN_GROUP", "%s already in a group", short) .. "|r"
        end
        if plainMsg:match("^%s*[Yy]ou aren't in a party%.?%s*$") or plainMsg:match("^%s*[Yy]ou are not in a party%.?%s*$") then
            return colorRed .. T("CHAT_NOT_IN_PARTY", "Not in a party") .. "|r"
        end
        local lootMaster = plainMsg:match("^%s*(.-)%s+is now the loot master%.?%s*$")
        if lootMaster and lootMaster ~= "" then
            local short = lootMaster:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorOrange .. T("CHAT_LOOT_MASTER", "%s is loot master", short) .. "|r"
        end
        if plainMsg:find("ready check") and plainMsg:find("initiated") and plainMsg:find("queued") then
            return colorOrange .. T("CHAT_READY_CHECK", "Ready check") .. "|r"
        end
        local rcName = plainMsg:match("^%s*(.-)%s+has initiated a ready check%.?%s*$")
        if rcName and rcName ~= "" then
            local short = rcName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorOrange .. short .. " " .. T("CHAT_INITIATED_READY_CHECK", "initiated ready check") .. "|r"
        end
        local roleName, roleWord = plainMsg:match("^%s*(.-)%s+is now%s+([%a]+)%.?%s*$")
        if roleName and roleWord then
            local short = roleName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            local lowerRole = roleWord:lower()
            if lowerRole == "tank" or lowerRole == "healer" or lowerRole == "damage" then
                local prettyRole = (lowerRole == "tank" and T("CHAT_ROLE_TANK", "Tank")) or (lowerRole == "healer" and T("CHAT_ROLE_HEALER", "Healer")) or T("CHAT_ROLE_DAMAGE", "Damage")
                return colorOrange .. short .. " " .. prettyRole .. "|r"
            end
        end

        local remainingDaily = plainMsg:match("^%s*You can only complete%s+(%d+)%s+more daily quests today%.?%s*$")
        local doneDaily = plainMsg:match("^%s*You have already completed%s+(%d+)%s+daily quests today%.?%s*$")
        if remainingDaily or doneDaily then
            local total = 25
            local done = doneDaily and (tonumber(doneDaily) or 0) or (total - (tonumber(remainingDaily) or 0))
            if done < 0 then done = 0 end
            if done > total then done = total end
            return colorRestedBar .. done .. "/" .. total .. "|r " .. colorWhite .. T("CHAT_DAILY_QUESTS_TODAY", "daily quests today") .. "|r"
        end

        local tradeTarget = plainMsg:match("^You have requested to trade with%s+(.+)%.$") or plainMsg:match("^You have requested to trade with%s+(.+)$")
        if tradeTarget and tradeTarget ~= "" then
            local short = tradeTarget:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorGreen .. T("CHAT_REQUESTED_TRADE", "Requested to trade with %s", short) .. "|r"
        end

        local instJoin = plainMsg:match("^%s*(.-)%s+has joined the instance group%.?%s*$")
        if instJoin and instJoin ~= "" then
            return colorGreen .. T("CHAT_PLAYER_JOINED", "%s joined", instJoin:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local instLeave = plainMsg:match("^%s*(.-)%s+has left the instance group%.?%s*$")
        if instLeave and instLeave ~= "" then
            return colorRed .. T("CHAT_PLAYER_LEFT", "%s left", instLeave:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local guildJoiner = plainMsg:match("^%s*(.-)%s+has joined the guild%.?%s*$")
        if guildJoiner and guildJoiner ~= "" then
            local short = guildJoiner:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            if short ~= "" then
                return colorGreen .. short .. " " .. T("CHAT_JOINED_GUILD", "joined the guild") .. "|r"
            end
        end
        local guildLeaver = plainMsg:match("^%s*(.-)%s+has left the guild%.?%s*$")
        if guildLeaver and guildLeaver ~= "" then
            local short = guildLeaver:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            if short ~= "" then
                return colorRed .. short .. " " .. T("CHAT_LEFT_GUILD", "left the guild") .. "|r"
            end
        end
        local numPlayers = plainMsg:match("^(%d+)%s+players have joined the battle%.?%s*$")
        if numPlayers then
            return colorGreen .. T("CHAT_PLAYERS_JOINED", "%s players joined", numPlayers) .. "|r"
        end
        if plainMsg:match("^Notify system has been enabled%.?%s*$") or plainMsg:match("^Notify system has been disabled%.?%s*$") then
            return true
        end

        local groupColor = getPartyOrRaidMessageColor()
        local inviter = plainMsg:match("^%s*(.-)%s+has invited you to join a group%.?%s*$") or
            plainMsg:match("^%s*(.-)%s+invites you to a group%.?%s*$") or
            plainMsg:match("^%s*(.-)%s+invites you to group%.?%s*$") or
            plainMsg:match("^%s*(.-)%s+invites you to join a group%.?%s*$")
        local bracketInviter = plainMsg:match("%[([^%]]+)%]%s*invited you") or plainMsg:match("^%s*%[([^%]]+)%]%s*invited you")
        local inviteName = inviter or bracketInviter
        if inviteName and inviteName ~= "" then
            inviteName = inviteName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^%[(.-)%]$", "%1")
            if inviteName ~= "" then
                return colorGreen .. T("CHAT_PLAYER_INVITED_YOU", "%s invited you", inviteName) .. "|r"
            end
        end

        local youInvited = plainMsg:match("^%s*You have invited%s+(.-)%s+to join your group%.?%s*$")
        if youInvited and youInvited ~= "" then
            return colorGreen .. T("CHAT_INVITED_PLAYER", "Invited %s", youInvited:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local decliner = plainMsg:match("^%s*(.-)%s+declines your group invitation%.?%s*$") or plainMsg:match("^%s*(.-)%s+declines%.?%s*$")
        if decliner and decliner ~= "" then
            return colorRed .. T("CHAT_PLAYER_DECLINES", "%s declines", decliner:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        if plainMsg:match("^%s*Your group has been disbanded%.?%s*$") then
            return colorRed .. T("CHAT_GROUP_DISBANDED", "Group disbanded") .. "|r"
        end
        if plainMsg:match("^%s*You leave the group%.?%s*$") or plainMsg:match("^%s*You left the group%.?%s*$") or
           plainMsg:match("^%s*You have left the group%.?%s*$") or plainMsg:match("^%s*You leave the raid%.?%s*$") or
           plainMsg:match("^%s*You left the raid%.?%s*$") or plainMsg:match("^%s*You have left the raid%.?%s*$") then
            return colorRed .. (plainMsg:lower():find("raid") and T("CHAT_LEFT_RAID_SELF", "Left raid") or T("CHAT_LEFT_PARTY_SELF", "Left party")) .. "|r"
        end

        local dungeonDifficultyLabel = _G.DUNGEON_DIFFICULTY or "Dungeon Difficulty"
        if plainMsg:find(dungeonDifficultyLabel, 1, true) then
            local difficulty = plainMsg:match("set to (%w+)") or plainMsg:match(dungeonDifficultyLabel:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. ":%s*(%w+)")
            if difficulty then
                difficulty = difficulty:gsub("^%s+", ""):gsub("%s+$", "")
                local diffColor = (difficulty:lower() == "heroic") and colorOrange or colorWhite
                return groupColor .. dungeonDifficultyLabel .. ": |r" .. diffColor .. difficulty .. "|r"
            end
        end
        if plainMsg:match("^%s*You have been removed from the group%.?%s*$") or plainMsg:match("^%s*You have been removed from the raid%.?%s*$") then
            return groupColor .. T("CHAT_REMOVED_FROM_GROUP", "Removed from the group") .. "|r"
        end

        local joiner = plainMsg:match("^%s*(.-)%s+joins the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+joins the raid%.?%s*$")
        if joiner and joiner ~= "" then
            joiner = joiner:gsub("^%s+", ""):gsub("%s+$", "")
            return colorGreen .. T("CHAT_PLAYER_JOINS", "%s joins", joiner) .. "|r"
        end
        local newLeader = plainMsg:match("^%s*(.-)%s+is now the group leader%.?%s*$") or plainMsg:match("^%s*(.-)%s+is now the raid leader%.?%s*$")
        if newLeader and newLeader ~= "" then
            return groupColor .. T("CHAT_PLAYER_NOW_GROUP_LEADER", "%s is now group leader", newLeader:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        if plainMsg:match("^%s*You are now the group leader%.?%s*$") or plainMsg:match("^%s*You are now the raid leader%.?%s*$") then
            return groupColor .. T("CHAT_YOU_ARE_GROUP_LEADER", "You are now group leader") .. "|r"
        end
        local lootMethod = plainMsg:match("[Ll]ooting changed to%s+(.+)$") or plainMsg:match("[Ll]oot method set to%s+(.+)$") or
            plainMsg:match("[Ll]oot method changed to%s+(.+)$") or plainMsg:match("[Ll]oot%s+changed to%s+(.+)$")
        if lootMethod and lootMethod ~= "" then
            lootMethod = lootMethod:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.?%s*$", "")
            return colorWhite .. T("CHAT_LOOT_LABEL", "Loot:") .. " |r" .. groupColor .. lootMethod .. "|r"
        end
        local died = plainMsg:match("^%s*(.-)%s+has died%.?%s*$")
        if died and died ~= "" then
            return colorRed .. T("CHAT_PLAYER_DIED", "%s died", died:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local leaver = plainMsg:match("^%s*(.-)%s+leaves the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+leaves the raid%.?%s*$")
        if leaver and leaver ~= "" then
            leaver = leaver:gsub("^%s+", ""):gsub("%s+$", "")
            local text = plainMsg:lower():find("leaves the raid") and T("CHAT_PLAYER_LEAVES_RAID", "%s leaves raid", leaver) or T("CHAT_PLAYER_LEAVES_PARTY", "%s leaves party", leaver)
            return colorRed .. text .. "|r"
        end

        return nil
    end

    return api
end
