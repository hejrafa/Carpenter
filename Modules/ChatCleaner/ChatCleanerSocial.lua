--[[ Carpenter - ChatCleaner social/group message helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Social = ns.Private.ChatCleanerSocial or {}
ns.Private.ChatCleanerSocial = Social

local Utils = ns.Private.ChatCleanerUtils
local Palette = Utils.Palette
local T, Trim, GameText = Utils.T, Utils.Trim, Utils.GameText
local CleanPunctuation = Utils.CleanPunctuation

function Social.Create()

    local api = {}

    local lootMethodNames = {
        ["free for all"] = GameText("FREE_FOR_ALL", "Free for all"),
        ["round robin"] = GameText("ROUND_ROBIN", "Round robin"),
        ["master looter"] = GameText("MASTER_LOOTER", "Master looter"),
        ["group loot"] = GameText("GROUP_LOOT", "Group Loot"),
        ["need before greed"] = GameText("NEED_BEFORE_GREED", "Need Before Greed"),
        ["personal loot"] = GameText("PERSONAL_LOOT", "Personal Loot"),
    }

    local function NormalizeLootMethodDisplay(method)
        method = Trim(method):gsub("%.?%s*$", "")
        local key = method:lower():gsub("[_%-%s]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return lootMethodNames[key] or method
    end

    -- "Loot threshold set to Uncommon." (ERR_SET_LOOT_THRESHOLD_S), as a
    -- pattern that takes the quality's name.
    local function LootThresholdName(plainMsg)
        local format = GameText("ERR_SET_LOOT_THRESHOLD_S", "Loot threshold set to %s.")
        local pattern = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.-)")
        local name = Trim(plainMsg):match("^" .. pattern .. "$")
        if name and name ~= "" then return name end
    end

    -- The color of the item quality with that name, as on its items.
    local function QualityColor(name)
        for quality = 0, 8 do
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if color and _G["ITEM_QUALITY" .. quality .. "_DESC"] == name then
                return string.format("|cff%02x%02x%02x", math.floor((color.r or 1) * 255),
                    math.floor((color.g or 1) * 255), math.floor((color.b or 1) * 255))
            end
        end
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

    -- System lines like /roll results only carry a name, so Blizzard never
    -- class-colors it the way it does chat senders. Look the class up on the
    -- units we can see, then on players who spoke in chat this session.
    local senderClasses = {}

    local IsSecret = Carpenter.Secret.IsSecret

    function api.RememberSenderClass(name, guid)
        if not GetPlayerInfoByGUID or IsSecret(name) or IsSecret(guid) then return end
        if type(guid) ~= "string" or guid == "" then return end
        local key = PlayerKey(name)
        if not key then return end
        local ok, _, classToken = pcall(GetPlayerInfoByGUID, guid)
        if ok and type(classToken) == "string" and not IsSecret(classToken) then
            senderClasses[key] = classToken
        end
    end

    local function GetUnitClassToken(unit, key)
        local ok, classToken = pcall(function()
            if UnitIsPlayer and not UnitIsPlayer(unit) then return nil end
            local name, surname = UnitName(unit)
            if not name then return nil end
            -- WoW Forever returns the surname as UnitName's second value but
            -- writes system lines with the full "First Surname".
            local fullName = name
            local client = Carpenter and Carpenter.Client
            if client and client.isForever and type(surname) == "string" and surname ~= "" then
                local consts = Constants and Constants.CharacterNameSeparatorConsts
                fullName = name .. (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname
            end
            if PlayerKey(fullName) ~= key and PlayerKey(name) ~= key then return nil end
            local _, token = UnitClass(unit)
            return token
        end)
        if ok and type(classToken) == "string" and not IsSecret(classToken) then
            return classToken
        end
    end

    function api.GetPlayerClassColor(name)
        local key = PlayerKey(name)
        if not key or not UnitName or not UnitClass then return nil end

        local units = { "player", "target", "focus", "mouseover" }
        local groupPrefix = (IsInRaid and IsInRaid()) and "raid" or "party"
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            units[#units + 1] = groupPrefix .. i
        end

        local classToken
        for _, unit in ipairs(units) do
            classToken = GetUnitClassToken(unit, key)
            if classToken then break end
        end
        classToken = classToken or senderClasses[key]

        return classToken and Utils.ClassColorCode(classToken)
    end

    -- WoW Forever hides system lines from addons during chat messaging
    -- lockdown (instances and battlegrounds), group joins, departures and
    -- deaths included. The roster and deaths stay readable, so each change is
    -- noted with its time, for ChatCleanerHiddenLines to match the hidden line
    -- that came with it.
    local CHANGE_WINDOW = 10
    local groupChanges = {}
    local deadMembers = {}
    local rosterNames = {}
    local rosterInRaid = false
    local MAX_JOINS_AT_ONCE = 3

    local function Now()
        return GetTime and GetTime() or 0
    end

    -- The death line uses the first name; join and leave lines use the full
    -- name, which on WoW Forever includes the surname.
    local function GetMemberNames(unit)
        if not UnitName then return nil end
        local ok, name, surname = pcall(UnitName, unit)
        if not ok or IsSecret(name) or IsSecret(surname) then return nil end
        if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
        local fullName = name
        local client = Carpenter and Carpenter.Client
        if client and client.isForever and type(surname) == "string" and surname ~= "" then
            local consts = Constants and Constants.CharacterNameSeparatorConsts
            fullName = name .. (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname
        end
        return fullName, name
    end

    -- Your own death has its own line, so you are never a tracked member.
    -- Unit comparisons can be hidden too, so the name decides as well.
    local function IsSelf(unit, fullName)
        local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
        if okSelf and not IsSecret(isSelf) and isSelf then return true end
        return fullName ~= nil and fullName == GetMemberNames("player")
    end

    local function ForEachGroupMember(callback)
        local inRaid = IsInRaid and IsInRaid()
        local prefix = inRaid and "raid" or "party"
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        if not inRaid then count = count - 1 end
        for i = 1, count do
            local unit = prefix .. i
            local fullName, firstName = GetMemberNames(unit)
            if fullName and not IsSelf(unit, fullName) then
                callback(unit, fullName, firstName)
            end
        end
    end

    local function PruneTimes(list, window, now)
        while list[1] do
            local first = list[1]
            local time = type(first) == "table" and first.time or first
            if now - time <= window then return end
            table.remove(list, 1)
        end
    end

    local function AddNotice(kind, name, now)
        PruneTimes(groupChanges, CHANGE_WINDOW, now)
        groupChanges[#groupChanges + 1] = { kind = kind, name = name, time = now, lines = 0 }
    end

    -- True when a new death was noted for a hidden line to take. announce
    -- says whether lines are hidden; when it's left out, that's checked only
    -- for a new death, since health events come for every unit.
    local function NoteMemberDeath(unit, fullName, firstName, now, announce)
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if not ok or IsSecret(dead) then return false end
        dead = dead == true
        local noted = dead and not deadMembers[fullName] and (announce == nil and Utils.InChatLockdown() or announce)
        if noted then
            AddNotice("died", firstName, now)
        end
        deadMembers[fullName] = dead or nil
        return noted == true
    end

    local function NoteDeaths(now, announce)
        if not UnitIsDeadOrGhost then return end
        ForEachGroupMember(function(unit, fullName, firstName)
            NoteMemberDeath(unit, fullName, firstName, now, announce)
        end)
    end

    local BYTE_R, BYTE_P = ("r"):byte(), ("p"):byte()

    -- Health events fire for every nameplate too, so only group tokens get
    -- past the first byte.
    function api.NoteGroupMemberHealth(unit)
        if type(unit) ~= "string" or not UnitIsDeadOrGhost then return end
        local first = unit:byte(1)
        if first ~= BYTE_R and first ~= BYTE_P then return end
        if not (unit:match("^raid%d+$") or unit:match("^party%d$")) then return end
        local fullName, firstName = GetMemberNames(unit)
        if fullName and not IsSelf(unit, fullName) then
            return NoteMemberDeath(unit, fullName, firstName, Now())
        end
        return false
    end

    -- Pass reset to take a fresh snapshot without noting any change, such as
    -- after a loading screen. A group that forms or turns into another, like a
    -- battleground raid filling in at once from your party, is a snapshot too.
    function api.NoteGroupRoster(reset)
        local now = Now()
        local inRaid = (IsInRaid and IsInRaid()) and true or false
        local current, added = {}, {}
        ForEachGroupMember(function(_, fullName)
            current[fullName] = true
            if not rosterNames[fullName] then
                added[#added + 1] = fullName
            end
        end)
        local announce = not reset and next(rosterNames) ~= nil and inRaid == rosterInRaid
            and #added <= MAX_JOINS_AT_ONCE and Utils.InChatLockdown()
        if announce then
            for _, fullName in ipairs(added) do
                AddNotice("joined", fullName, now)
            end
            for fullName in pairs(rosterNames) do
                if not current[fullName] then
                    AddNotice("left", fullName, now)
                end
            end
        end
        rosterNames, rosterInRaid = current, inRaid
        for fullName in pairs(deadMembers) do
            if not current[fullName] then
                deadMembers[fullName] = nil
            end
        end
        if reset then
            groupChanges = {}
        end
        NoteDeaths(now, not reset and Utils.InChatLockdown())
    end

    local function FormatNotice(notice)
        if notice.kind == "died" then
            return Palette.red .. T("CHAT_PLAYER_DIED", notice.name) .. "|r"
        elseif notice.kind == "left" then
            return Palette.red .. T("CHAT_PLAYER_LEFT", notice.name) .. "|r"
        end
        return Palette.green .. T("CHAT_PLAYER_JOINED", notice.name) .. "|r"
    end

    -- Recent joins, departures and deaths, oldest first. The hidden line
    -- matcher counts the lines it gives each one in change.lines.
    function api.GetGroupChanges()
        PruneTimes(groupChanges, CHANGE_WINDOW, Now())
        return groupChanges
    end

    function api.FormatGroupChange(change)
        return FormatNotice(change)
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
                    return { source = "friend" }
                end
            elseif GetFriendInfo then
                local ok, name = pcall(GetFriendInfo, i)
                if ok and PlayerKey(name) == targetKey then
                    return { source = "friend" }
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
            local ok, name = pcall(GetGuildRosterInfo, i)
            if ok and PlayerKey(name) == targetKey then
                return { source = "guild" }
            end
        end

        return nil
    end

    local function GetSocialNoticeRecord(name)
        local targetKey = PlayerKey(name)
        if not targetKey then return nil end

        return GetGuildRecord(targetKey) or GetFriendRecord(targetKey) or { source = "friend" }
    end

    local function FormatSocialNotice(name, actionKey)
        local shortName = ShortPlayerName(name)
        if shortName == "" then return nil end

        local record = GetSocialNoticeRecord(shortName) or { source = "friend" }
        local isGuild = record.source == "guild"
        local lineColor = isGuild and Utils.GuildColor() or Palette.yellow

        return lineColor .. shortName .. " " .. T(actionKey) .. "|r"
    end

    -- The battleground announcer's countdown and start, each battleground in its
    -- own words: "The battle for Warsong Gulch begins in 30 seconds. Prepare
    -- yourselves!" becomes "Warsong Gulch begins in 30 seconds".
    local BATTLE_COUNTDOWN_PATTERNS = {
        "^[Tt]he [Bb]attle for (.-) begins in (%d+ %a+)",
        "^[Tt]he [Bb]attle for (.-) will begin in (%d+ %a+)",
    }
    local BATTLE_START_PATTERNS = {
        "^[Ll]et the [Bb]attle for (.-) begin",
        "^[Tt]he [Bb]attle for (.-) has begun",
    }

    local function FormatBattleAnnouncement(plainSys)
        local name, wait
        for _, pattern in ipairs(BATTLE_COUNTDOWN_PATTERNS) do
            name, wait = plainSys:match(pattern)
            if name then break end
        end
        if not name then
            wait, name = plainSys:match("^(%d+ %a+) until the [Bb]attle for (.-) begins")
        end
        if name and name ~= "" then
            local battle = Palette.queue .. name .. "|r" .. Palette.white
            return Palette.white .. T("CHAT_BATTLE_BEGINS_IN", battle, wait) .. "|r"
        end

        for _, pattern in ipairs(BATTLE_START_PATTERNS) do
            name = plainSys:match(pattern)
            if name and name ~= "" then
                local battle = Palette.queue .. name .. "|r" .. Palette.white
                return Palette.white .. T("CHAT_BATTLE_BEGUN", battle) .. "|r"
            end
        end
        return nil
    end

    function api.IsBattleStartAnnouncement(text)
        if IsSecret(text) or type(text) ~= "string" then return false end
        for _, pattern in ipairs(BATTLE_START_PATTERNS) do
            if text:match(pattern) then return true end
        end
        return false
    end

    function api.FormatBattlegroundAndGroupNotice(event, plainSys)
        if not plainSys or type(plainSys) ~= "string" then return nil end

        if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
            local numPlayersJoin = plainSys:match("^(%d+)%s+players have joined the battle%.?%s*$")
            if numPlayersJoin then
                return Palette.green .. T("CHAT_PLAYERS_JOINED", numPlayersJoin) .. "|r"
            end

            local bgJoin = plainSys:match("^%s*(.-)%s+has joined the battle%.?%s*$")
            if bgJoin and bgJoin ~= "" then
                bgJoin = bgJoin:gsub("^%s+", ""):gsub("%s+$", "")
                if bgJoin ~= "" then
                    return Palette.green .. T("CHAT_PLAYER_JOINED", bgJoin) .. "|r"
                end
            end

            local bgLeave = plainSys:match("^%s*(.-)%s+has left the battle%.?%s*$")
            if bgLeave and bgLeave ~= "" then
                bgLeave = bgLeave:gsub("^%s+", ""):gsub("%s+$", "")
                if bgLeave ~= "" then
                    return Palette.red .. T("CHAT_PLAYER_LEFT", bgLeave) .. "|r"
                end
            end

            local announcement = FormatBattleAnnouncement(plainSys)
            if announcement then return announcement end
        end

        local plainLower = plainSys:lower()
        if plainLower:find("flag") and plainLower:find("has been reset") then
            return Palette.orange .. T("CHAT_FLAG_RESET") .. "|r"
        end

        local groupColor = Utils.GroupColor()
        if plainSys:find("Party converted to Raid") then
            return groupColor .. T("CHAT_PARTY_CONVERTED_TO_RAID") .. "|r"
        end
        if plainSys:find("Raid converted to Party") then
            return groupColor .. T("CHAT_RAID_CONVERTED_TO_PARTY") .. "|r"
        end

        local raidJoin = plainSys:match("^%s*(.-)%s+has joined the raid group%.?%s*$")
        if raidJoin and raidJoin ~= "" then
            raidJoin = raidJoin:gsub("^%s+", ""):gsub("%s+$", "")
            return groupColor .. T("CHAT_JOINED_RAID", raidJoin) .. "|r"
        end

        local raidLeave = plainSys:match("^%s*(.-)%s+has left the raid group%.?%s*$")
        if raidLeave and raidLeave ~= "" then
            raidLeave = raidLeave:gsub("^%s+", ""):gsub("%s+$", "")
            return groupColor .. T("CHAT_LEFT_RAID", raidLeave) .. "|r"
        end

        if plainSys:find("You are in both a party and a battleground group") then
            return groupColor .. T("CHAT_PARTY_AND_BG_GROUP") .. "|r"
        end
        if plainSys:find("You may communicate with your party") and plainSys:find("/p") and plainSys:find("/bg") then
            return groupColor .. T("CHAT_PARTY_BG_COMMANDS") .. "|r"
        end
        if plainSys:find("The battle has ended") and (plainSys:find("battleground will close") or plainSys:find("close in")) then
            return Palette.white .. T("CHAT_BATTLE_ENDED") .. "|r"
        end

        return nil
    end

    function api.FormatSystemSocialMessage(plainMsg)
        if not plainMsg or type(plainMsg) ~= "string" then return nil end

        if _G.CLEARED_AFK and plainMsg == _G.CLEARED_AFK then
            return Palette.green .. T("CHAT_BACK") .. "|r"
        end
        if _G.CLEARED_DND and plainMsg == _G.CLEARED_DND then
            return Palette.green .. T("CHAT_AVAILABLE") .. "|r"
        end
        local onlineName = plainMsg:match("^%s*(.-)%s+has come online%.?%s*$")
        if onlineName and onlineName ~= "" then
            return FormatSocialNotice(onlineName, "CHAT_CAME_ONLINE")
        end
        local offlineName = plainMsg:match("^%s*(.-)%s+has gone offline%.?%s*$")
        if offlineName and offlineName ~= "" then
            return FormatSocialNotice(offlineName, "CHAT_WENT_OFFLINE")
        end
        if _G.MARKED_AFK and plainMsg == _G.MARKED_AFK then
            return Palette.orange .. T("CHAT_AFK") .. "|r"
        end
        local afkCustom = plainMsg:match("^You are now Away: (.+)$") or plainMsg:match("^You are now AFK: (.+)$")
        if afkCustom and afkCustom ~= "" then
            afkCustom = afkCustom:gsub("^%s+", ""):gsub("%s+$", "")
            if afkCustom == "" or afkCustom:lower() == "afk" then
                return Palette.orange .. T("CHAT_AFK") .. "|r"
            end
            return Palette.orange .. T("CHAT_AFK_WITH_MESSAGE", afkCustom) .. "|r"
        end
        if _G.MARKED_DND and plainMsg:match("^You are now Busy") then
            return Palette.darkorange .. T("CHAT_BUSY") .. "|r"
        end
        if plainMsg:match("^You are now flagged for PvP combat") then
            return Palette.red .. T("CHAT_FLAGGED_PVP") .. "|r"
        end
        if plainMsg:match("^You feel rested%.?%s*$") or (plainMsg:lower():find("feel rested") and plainMsg:lower():find("you")) then
            return Palette.restedBar .. T("CHAT_RESTED") .. "|r"
        end
        -- WoW Forever says "You are no longer rested." where the other clients
        -- say "You feel normal."
        if plainMsg:match("^You feel normal%.?%s*$") or (plainMsg:lower():find("feel normal") and plainMsg:lower():find("you"))
            or plainMsg:match("^You are no longer rested%.?%s*$") then
            return Palette.normalBar .. T("CHAT_NORMAL") .. "|r"
        end
        local homeLocation = plainMsg:match("^(.+) is now your home%.?%s*$")
        if homeLocation and homeLocation ~= "" then
            return Palette.white .. T("CHAT_HOME_LABEL") .. " |r" .. Palette.queue .. CleanPunctuation(homeLocation) .. "|r"
        end

        if plainMsg:find("Ready Check") and plainMsg:find("failed") then
            return Palette.red .. T("CHAT_READY_CHECK_FAILED") .. "|r"
        end
        local notReadyName = plainMsg:match("^%s*(.-)%s+is not ready%.?%s*$")
        if notReadyName and notReadyName ~= "" then
            local short = notReadyName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return Palette.red .. T("CHAT_NOT_READY", short) .. "|r"
        end
        local alreadyInGroup = plainMsg:match("^%s*(.-)%s+is already in a group%.?%s*$")
        if alreadyInGroup and alreadyInGroup ~= "" then
            local short = alreadyInGroup:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return Palette.red .. T("CHAT_ALREADY_IN_GROUP", short) .. "|r"
        end
        if plainMsg:match("^%s*[Yy]ou aren't in a party%.?%s*$") or plainMsg:match("^%s*[Yy]ou are not in a party%.?%s*$") then
            return Palette.red .. T("CHAT_NOT_IN_PARTY") .. "|r"
        end
        local lootMaster = plainMsg:match("^%s*(.-)%s+is now the loot master%.?%s*$")
        if lootMaster and lootMaster ~= "" then
            local short = lootMaster:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return Palette.orange .. T("CHAT_LOOT_MASTER", short) .. "|r"
        end
        if plainMsg:find("ready check") and plainMsg:find("initiated") and plainMsg:find("queued") then
            return Palette.orange .. T("CHAT_READY_CHECK") .. "|r"
        end
        local rcName = plainMsg:match("^%s*(.-)%s+has initiated a ready check%.?%s*$")
        if rcName and rcName ~= "" then
            local short = rcName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return Palette.orange .. short .. " " .. T("CHAT_INITIATED_READY_CHECK") .. "|r"
        end
        local roleName, roleWord = plainMsg:match("^%s*(.-)%s+is now%s+([%a]+)%.?%s*$")
        if roleName and roleWord then
            local short = roleName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            local lowerRole = roleWord:lower()
            if lowerRole == "tank" or lowerRole == "healer" or lowerRole == "damage" then
                local prettyRole = (lowerRole == "tank" and T("CHAT_ROLE_TANK")) or (lowerRole == "healer" and T("CHAT_ROLE_HEALER")) or T("CHAT_ROLE_DAMAGE")
                return Palette.orange .. short .. " " .. prettyRole .. "|r"
            end
        end

        local remainingDaily = plainMsg:match("^%s*You can only complete%s+(%d+)%s+more daily quests today%.?%s*$")
        local doneDaily = plainMsg:match("^%s*You have already completed%s+(%d+)%s+daily quests today%.?%s*$")
        if remainingDaily or doneDaily then
            local total = 25
            local done = doneDaily and (tonumber(doneDaily) or 0) or (total - (tonumber(remainingDaily) or 0))
            if done < 0 then done = 0 end
            if done > total then done = total end
            return Palette.restedBar .. done .. "/" .. total .. "|r " .. Palette.white .. T("CHAT_DAILY_QUESTS_TODAY") .. "|r"
        end

        local tradeTarget = plainMsg:match("^You have requested to trade with%s+(.+)%.$") or plainMsg:match("^You have requested to trade with%s+(.+)$")
        if tradeTarget and tradeTarget ~= "" then
            local short = tradeTarget:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            return Palette.green .. T("CHAT_REQUESTED_TRADE", short) .. "|r"
        end

        local instJoin = plainMsg:match("^%s*(.-)%s+has joined the instance group%.?%s*$")
        if instJoin and instJoin ~= "" then
            return Palette.green .. T("CHAT_PLAYER_JOINED", instJoin:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local instLeave = plainMsg:match("^%s*(.-)%s+has left the instance group%.?%s*$")
        if instLeave and instLeave ~= "" then
            return Palette.red .. T("CHAT_PLAYER_LEFT", instLeave:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local guildJoiner = plainMsg:match("^%s*(.-)%s+has joined the guild%.?%s*$")
        if guildJoiner and guildJoiner ~= "" then
            local short = guildJoiner:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            if short ~= "" then
                return Palette.green .. short .. " " .. T("CHAT_JOINED_GUILD") .. "|r"
            end
        end
        local guildLeaver = plainMsg:match("^%s*(.-)%s+has left the guild%.?%s*$")
        if guildLeaver and guildLeaver ~= "" then
            local short = guildLeaver:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
            if short ~= "" then
                return Palette.red .. short .. " " .. T("CHAT_LEFT_GUILD") .. "|r"
            end
        end
        local numPlayers = plainMsg:match("^(%d+)%s+players have joined the battle%.?%s*$")
        if numPlayers then
            return Palette.green .. T("CHAT_PLAYERS_JOINED", numPlayers) .. "|r"
        end
        if plainMsg:match("^Notify system has been enabled%.?%s*$") or plainMsg:match("^Notify system has been disabled%.?%s*$") then
            return true
        end

        local groupColor = Utils.GroupColor()
        local inviter = plainMsg:match("^%s*(.-)%s+has invited you to join a group%.?%s*$") or
            plainMsg:match("^%s*(.-)%s+invites you to a group%.?%s*$") or
            plainMsg:match("^%s*(.-)%s+invites you to group%.?%s*$") or
            plainMsg:match("^%s*(.-)%s+invites you to join a group%.?%s*$")
        local bracketInviter = plainMsg:match("%[([^%]]+)%]%s*invited you") or plainMsg:match("^%s*%[([^%]]+)%]%s*invited you")
        local inviteName = inviter or bracketInviter
        if inviteName and inviteName ~= "" then
            inviteName = inviteName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^%[(.-)%]$", "%1")
            if inviteName ~= "" then
                return Palette.green .. T("CHAT_PLAYER_INVITED_YOU", inviteName) .. "|r"
            end
        end

        local youInvited = plainMsg:match("^%s*You have invited%s+(.-)%s+to join your group%.?%s*$")
        if youInvited and youInvited ~= "" then
            return Palette.green .. T("CHAT_INVITED_PLAYER", youInvited:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        -- A group member who isn't the leader suggests an invite instead.
        local youSuggested = plainMsg:match("^%s*You have suggested that%s+(.-)%s+join your group%.?%s*$")
        if youSuggested and youSuggested ~= "" then
            return Palette.green .. T("CHAT_SUGGESTED_PLAYER", youSuggested:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local decliner = plainMsg:match("^%s*(.-)%s+declines your group invitation%.?%s*$") or plainMsg:match("^%s*(.-)%s+declines%.?%s*$")
        if decliner and decliner ~= "" then
            return Palette.red .. T("CHAT_PLAYER_DECLINES", decliner:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        if plainMsg:match("^%s*Your group has been disbanded%.?%s*$") then
            return Palette.red .. T("CHAT_GROUP_DISBANDED") .. "|r"
        end
        if plainMsg:match("^%s*You leave the group%.?%s*$") or plainMsg:match("^%s*You left the group%.?%s*$") or
           plainMsg:match("^%s*You have left the group%.?%s*$") or plainMsg:match("^%s*You leave the raid%.?%s*$") or
           plainMsg:match("^%s*You left the raid%.?%s*$") or plainMsg:match("^%s*You have left the raid%.?%s*$") then
            return Palette.red .. (plainMsg:lower():find("raid") and T("CHAT_LEFT_RAID_SELF") or T("CHAT_LEFT_PARTY_SELF")) .. "|r"
        end

        local dungeonDifficultyLabel = _G.DUNGEON_DIFFICULTY or "Dungeon Difficulty"
        if plainMsg:find(dungeonDifficultyLabel, 1, true) then
            local difficulty = plainMsg:match("set to (%w+)") or plainMsg:match(dungeonDifficultyLabel:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. ":%s*(%w+)")
            if difficulty then
                difficulty = difficulty:gsub("^%s+", ""):gsub("%s+$", "")
                local diffColor = (difficulty:lower() == "heroic") and Palette.orange or Palette.white
                return groupColor .. dungeonDifficultyLabel .. ": |r" .. diffColor .. difficulty .. "|r"
            end
        end
        if plainMsg:match("^%s*You have been removed from the group%.?%s*$") or plainMsg:match("^%s*You have been removed from the raid%.?%s*$") then
            return Palette.red .. T("CHAT_REMOVED_FROM_GROUP") .. "|r"
        end

        local joiner = plainMsg:match("^%s*(.-)%s+joins the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+joins the raid%.?%s*$")
        if joiner and joiner ~= "" then
            joiner = joiner:gsub("^%s+", ""):gsub("%s+$", "")
            return Palette.green .. T("CHAT_PLAYER_JOINS", joiner) .. "|r"
        end
        local newLeader = plainMsg:match("^%s*(.-)%s+is now the group leader%.?%s*$") or plainMsg:match("^%s*(.-)%s+is now the raid leader%.?%s*$")
        if newLeader and newLeader ~= "" then
            return groupColor .. T("CHAT_PLAYER_NOW_GROUP_LEADER", newLeader:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        if plainMsg:match("^%s*You are now the group leader%.?%s*$") or plainMsg:match("^%s*You are now the raid leader%.?%s*$") then
            return groupColor .. T("CHAT_YOU_ARE_GROUP_LEADER") .. "|r"
        end
        local lootMethod = plainMsg:match("^%s*[Ll]ooting set to%s+(.+)$") or
            plainMsg:match("[Ll]ooting changed to%s+(.+)$") or plainMsg:match("[Ll]oot method set to%s+(.+)$") or
            plainMsg:match("[Ll]oot method changed to%s+(.+)$") or plainMsg:match("[Ll]oot%s+changed to%s+(.+)$")
        if lootMethod and lootMethod ~= "" then
            lootMethod = NormalizeLootMethodDisplay(lootMethod)
            return Palette.white .. T("CHAT_LOOT_LABEL") .. " |r" .. groupColor .. lootMethod .. "|r"
        end
        local threshold = LootThresholdName(plainMsg)
        if threshold then
            return Palette.white .. T("CHAT_LOOT_THRESHOLD_LABEL") .. " |r" ..
                (QualityColor(threshold) or groupColor) .. threshold .. "|r"
        end
        local died = plainMsg:match("^%s*(.-)%s+has died%.?%s*$")
        if died and died ~= "" then
            return Palette.red .. T("CHAT_PLAYER_DIED", died:gsub("^%s+", ""):gsub("%s+$", "")) .. "|r"
        end
        local leaver = plainMsg:match("^%s*(.-)%s+leaves the party%.?%s*$") or plainMsg:match("^%s*(.-)%s+leaves the raid%.?%s*$")
        if leaver and leaver ~= "" then
            leaver = leaver:gsub("^%s+", ""):gsub("%s+$", "")
            local text = plainMsg:lower():find("leaves the raid") and T("CHAT_PLAYER_LEAVES_RAID", leaver) or T("CHAT_PLAYER_LEAVES_PARTY", leaver)
            return Palette.red .. text .. "|r"
        end

        return nil
    end

    return api
end
