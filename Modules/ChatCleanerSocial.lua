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
    local colorOffwhite = config.ColorOffwhite or "|cfff0f0f0"
    local colorQueue = config.ColorQueue or "|cff80b0ff"
    local colorRestedBar = config.ColorRestedBar or "|cff3399ff"
    local colorNormalBar = config.ColorNormalBar or "|cff9940ff"
    local cleanPunctuation = config.CleanPunctuation or function(text) return text end
    local getClassColorForName = config.GetClassColorForName or function() return colorOffwhite end
    local getFirstPlayerLink = config.GetFirstPlayerLink or function() return nil end
    local playerNameToClassColor = config.PlayerNameToClassColor or {}

    local api = {}

    function api.FormatBattlegroundAndGroupNotice(event, plainSys)
        if not plainSys or type(plainSys) ~= "string" then return nil end

        if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
            local numPlayersJoin = plainSys:match("^(%d+)%s+players have joined the battle%.?%s*$")
            if numPlayersJoin then
                return colorGreen .. numPlayersJoin .. " players joined|r"
            end

            local bgJoin = plainSys:match("^%s*(.-)%s+has joined the battle%.?%s*$")
            if bgJoin and bgJoin ~= "" then
                bgJoin = bgJoin:gsub("^%s+", ""):gsub("%s+$", "")
                if bgJoin ~= "" then
                    return colorGreen .. bgJoin .. " joined|r"
                end
            end

            local bgLeave = plainSys:match("^%s*(.-)%s+has left the battle%.?%s*$")
            if bgLeave and bgLeave ~= "" then
                bgLeave = bgLeave:gsub("^%s+", ""):gsub("%s+$", "")
                if bgLeave ~= "" then
                    return colorRed .. bgLeave .. " left|r"
                end
            end
        end

        local plainLower = plainSys:lower()
        if plainLower:find("flag") and plainLower:find("has been reset") then
            return colorOrange .. "Flag reset|r"
        end

        local groupColor = getPartyOrRaidMessageColor()
        if plainSys:find("Party converted to Raid") then
            return groupColor .. "Party converted to Raid|r"
        end
        if plainSys:find("Raid converted to Party") then
            return groupColor .. "Raid converted to Party|r"
        end

        local raidJoin = plainSys:match("^%s*(.-)%s+has joined the raid group%.?%s*$")
        if raidJoin and raidJoin ~= "" then
            raidJoin = raidJoin:gsub("^%s+", ""):gsub("%s+$", "")
            return groupColor .. raidJoin .. " joined the raid|r"
        end

        local raidLeave = plainSys:match("^%s*(.-)%s+has left the raid group%.?%s*$")
        if raidLeave and raidLeave ~= "" then
            raidLeave = raidLeave:gsub("^%s+", ""):gsub("%s+$", "")
            return groupColor .. raidLeave .. " left the raid|r"
        end

        if plainSys:find("You are in both a party and a battleground group") then
            return groupColor .. "You are in a party and a battleground group|r"
        end
        if plainSys:find("You may communicate with your party") and plainSys:find("/p") and plainSys:find("/bg") then
            return groupColor .. "Communicate with your party with \"/p\" and with your battleground group with \"/bg\"|r"
        end
        if plainSys:find("The battle has ended") and (plainSys:find("battleground will close") or plainSys:find("close in")) then
            return colorWhite .. "The battle has ended|r"
        end

        return nil
    end

    function api.FormatSystemSocialMessage(plainMsg, rawMsg)
        if not plainMsg or type(plainMsg) ~= "string" then return nil end

        if _G.CLEARED_AFK and plainMsg == _G.CLEARED_AFK then
            return colorGreen .. "Back|r"
        end
        if _G.CLEARED_DND and plainMsg == _G.CLEARED_DND then
            return colorGreen .. "Available|r"
        end
        if _G.MARKED_AFK and plainMsg == _G.MARKED_AFK then
            return colorOrange .. "AFK|r"
        end
        local afkCustom = plainMsg:match("^You are now Away: (.+)$") or plainMsg:match("^You are now AFK: (.+)$")
        if afkCustom and afkCustom ~= "" then
            return colorOrange .. "AFK: " .. afkCustom .. "|r"
        end
        if _G.MARKED_DND and plainMsg:match("^You are now Busy") then
            return colorDarkorange .. "Busy|r"
        end
        if plainMsg:match("^You are now flagged for PvP combat") then
            return colorRed .. "Flagged for PvP|r"
        end
        if plainMsg:match("^You feel rested%.?%s*$") or (plainMsg:lower():find("feel rested") and plainMsg:lower():find("you")) then
            return colorRestedBar .. "Rested|r"
        end
        if plainMsg:match("^You feel normal%.?%s*$") or (plainMsg:lower():find("feel normal") and plainMsg:lower():find("you")) then
            return colorNormalBar .. "Normal|r"
        end
        local homeLocation = plainMsg:match("^(.+) is now your home%.?%s*$")
        if homeLocation and homeLocation ~= "" then
            return colorWhite .. "Home: |r" .. colorQueue .. cleanPunctuation(homeLocation) .. "|r"
        end

        if plainMsg:find("Ready Check") and plainMsg:find("failed") then
            return colorRed .. "Ready Check failed|r"
        end
        local notReadyName = plainMsg:match("^%s*(.-)%s+is not ready%.?%s*$")
        if notReadyName and notReadyName ~= "" then
            local short = notReadyName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorRed .. short .. " not ready|r"
        end
        local alreadyInGroup = plainMsg:match("^%s*(.-)%s+is already in a group%.?%s*$")
        if alreadyInGroup and alreadyInGroup ~= "" then
            local short = alreadyInGroup:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorRed .. short .. " already in a group|r"
        end
        if plainMsg:match("^%s*[Yy]ou aren't in a party%.?%s*$") or plainMsg:match("^%s*[Yy]ou are not in a party%.?%s*$") then
            return colorRed .. "Not in a party|r"
        end
        local lootMaster = plainMsg:match("^%s*(.-)%s+is now the loot master%.?%s*$")
        if lootMaster and lootMaster ~= "" then
            local short = lootMaster:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorOrange .. short .. " is loot master|r"
        end
        if plainMsg:find("ready check") and plainMsg:find("initiated") and plainMsg:find("queued") then
            return colorOrange .. "Ready check|r"
        end
        local rcName = plainMsg:match("^%s*(.-)%s+has initiated a ready check%.?%s*$")
        if rcName and rcName ~= "" then
            local short = rcName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return getClassColorForName(short) .. short .. "|r " .. colorOrange .. "initiated ready check|r"
        end
        local roleName, roleWord = plainMsg:match("^%s*(.-)%s+is now%s+([%a]+)%.?%s*$")
        if roleName and roleWord then
            local short = roleName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            local lowerRole = roleWord:lower()
            if lowerRole == "tank" or lowerRole == "healer" or lowerRole == "damage" then
                local prettyRole = (lowerRole == "tank" and "Tank") or (lowerRole == "healer" and "Healer") or "Damage"
                return getClassColorForName(short) .. short .. "|r " .. colorOrange .. prettyRole .. "|r"
            end
        end

        local remainingDaily = plainMsg:match("^%s*You can only complete%s+(%d+)%s+more daily quests today%.?%s*$")
        local doneDaily = plainMsg:match("^%s*You have already completed%s+(%d+)%s+daily quests today%.?%s*$")
        if remainingDaily or doneDaily then
            local total = 25
            local done = doneDaily and (tonumber(doneDaily) or 0) or (total - (tonumber(remainingDaily) or 0))
            if done < 0 then done = 0 end
            if done > total then done = total end
            return colorRestedBar .. done .. "/" .. total .. "|r " .. colorWhite .. "daily quests today|r"
        end

        local tradeTarget = plainMsg:match("^You have requested to trade with%s+(.+)%.$") or plainMsg:match("^You have requested to trade with%s+(.+)$")
        if tradeTarget and tradeTarget ~= "" then
            local short = tradeTarget:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return colorGreen .. "Requested to trade with " .. short .. "|r"
        end

        local instJoin = plainMsg:match("^%s*(.-)%s+has joined the instance group%.?%s*$")
        if instJoin and instJoin ~= "" then
            return colorGreen .. instJoin:gsub("^%s+", ""):gsub("%s+$", "") .. " joined|r"
        end
        local instLeave = plainMsg:match("^%s*(.-)%s+has left the instance group%.?%s*$")
        if instLeave and instLeave ~= "" then
            return colorRed .. instLeave:gsub("^%s+", ""):gsub("%s+$", "") .. " left|r"
        end
        local numPlayers = plainMsg:match("^(%d+)%s+players have joined the battle%.?%s*$")
        if numPlayers then
            return colorGreen .. numPlayers .. " players joined|r"
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
                local shortName = inviteName:gsub("%-[^%-]+$", "")
                local playerLink = getFirstPlayerLink(rawMsg)
                local nameColor = playerNameToClassColor[shortName] or playerNameToClassColor[inviteName] or getClassColorForName(inviteName)
                if nameColor ~= colorOffwhite then
                    return (playerLink or (nameColor .. inviteName .. "|r")) .. groupColor .. " invited you|r"
                end
                return colorGreen .. inviteName .. " invited you|r"
            end
        end

        local youInvited = plainMsg:match("^%s*You have invited%s+(.-)%s+to join your group%.?%s*$")
        if youInvited and youInvited ~= "" then
            return colorGreen .. "Invited " .. youInvited:gsub("^%s+", ""):gsub("%s+$", "") .. "|r"
        end
        local decliner = plainMsg:match("^%s*(.-)%s+declines your group invitation%.?%s*$") or plainMsg:match("^%s*(.-)%s+declines%.?%s*$")
        if decliner and decliner ~= "" then
            return colorRed .. decliner:gsub("^%s+", ""):gsub("%s+$", "") .. " declines|r"
        end
        if plainMsg:match("^%s*Your group has been disbanded%.?%s*$") then
            return colorRed .. "Group disbanded|r"
        end
        if plainMsg:match("^%s*You leave the group%.?%s*$") or plainMsg:match("^%s*You left the group%.?%s*$") or
           plainMsg:match("^%s*You have left the group%.?%s*$") or plainMsg:match("^%s*You leave the raid%.?%s*$") or
           plainMsg:match("^%s*You left the raid%.?%s*$") or plainMsg:match("^%s*You have left the raid%.?%s*$") then
            return colorRed .. (plainMsg:lower():find("raid") and "Left raid|r" or "Left party|r")
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
            return groupColor .. "Removed from the group|r"
        end

        local joiner = plainMsg:match("^%s*(.-)%s+joins the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+joins the raid%.?%s*$")
        if joiner and joiner ~= "" then
            joiner = joiner:gsub("^%s+", ""):gsub("%s+$", "")
            local joinerShort = joiner:gsub("%-[^%-]+$", "")
            local classColor = getClassColorForName(joiner)
            playerNameToClassColor[joinerShort] = classColor
            playerNameToClassColor[joiner] = classColor
            return colorGreen .. joiner .. " joins|r"
        end
        local newLeader = plainMsg:match("^%s*(.-)%s+is now the group leader%.?%s*$") or plainMsg:match("^%s*(.-)%s+is now the raid leader%.?%s*$")
        if newLeader and newLeader ~= "" then
            return groupColor .. newLeader:gsub("^%s+", ""):gsub("%s+$", "") .. " is now group leader|r"
        end
        if plainMsg:match("^%s*You are now the group leader%.?%s*$") or plainMsg:match("^%s*You are now the raid leader%.?%s*$") then
            return groupColor .. "You are now group leader|r"
        end
        local lootMethod = plainMsg:match("[Ll]ooting changed to%s+(.+)$") or plainMsg:match("[Ll]oot method set to%s+(.+)$") or
            plainMsg:match("[Ll]oot method changed to%s+(.+)$") or plainMsg:match("[Ll]oot%s+changed to%s+(.+)$")
        if lootMethod and lootMethod ~= "" then
            lootMethod = lootMethod:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.?%s*$", "")
            return colorWhite .. "Loot: |r" .. groupColor .. lootMethod .. "|r"
        end
        local died = plainMsg:match("^%s*(.-)%s+has died%.?%s*$")
        if died and died ~= "" then
            return colorRed .. died:gsub("^%s+", ""):gsub("%s+$", "") .. " died|r"
        end
        local leaver = plainMsg:match("^%s*(.-)%s+leaves the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+leaves the raid%.?%s*$")
        if leaver and leaver ~= "" then
            leaver = leaver:gsub("^%s+", ""):gsub("%s+$", "")
            local suffix = plainMsg:lower():find("leaves the raid") and " leaves raid" or " leaves party"
            return colorRed .. leaver .. suffix .. "|r"
        end

        return nil
    end

    return api
end
