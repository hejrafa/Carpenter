--[[ Carpenter - ChatCleaner social/group message helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Social = ns.Private.ChatCleanerSocial or {}
ns.Private.ChatCleanerSocial = Social

local Utils = ns.Private.ChatCleanerUtils
local Palette = Utils.Palette
local T, Trim, GameText = Utils.T, Utils.Trim, Utils.GameText
local CleanPunctuation = Utils.CleanPunctuation
local IsSecret = Carpenter.Secret.IsSecret
local ReadableBool = Carpenter.Secret.ReadableBool

local function Line(color, text)
    return color .. text .. "|r"
end

-- A player named in a system line, without the realm.
local function NoRealm(name)
    return (Trim(name):gsub("%-.*$", ""))
end

local LOOT_METHOD_NAMES = {
    ["free for all"] = GameText("FREE_FOR_ALL", "Free for all"),
    ["round robin"] = GameText("ROUND_ROBIN", "Round robin"),
    ["master looter"] = GameText("MASTER_LOOTER", "Master looter"),
    ["group loot"] = GameText("GROUP_LOOT", "Group Loot"),
    ["need before greed"] = GameText("NEED_BEFORE_GREED", "Need Before Greed"),
    ["personal loot"] = GameText("PERSONAL_LOOT", "Personal Loot"),
}

-- The loot method as the game names it in its menus.
local function LootMethodDisplay(method)
    method = Trim(method):gsub("%.?%s*$", "")
    local key = Trim(method:lower():gsub("[_%-%s]+", " "))
    return LOOT_METHOD_NAMES[key] or method
end

-- "Loot threshold set to Uncommon." (ERR_SET_LOOT_THRESHOLD_S), as a
-- pattern that takes the quality's name.
local LOOT_THRESHOLD_PATTERN = "^" .. Utils.EscapePattern(GameText("ERR_SET_LOOT_THRESHOLD_S", "Loot threshold set to %s."))
    :gsub("%%%%s", "(.-)") .. "$"

-- The color of the item quality with that name, as on its items.
local function QualityColor(name)
    for quality = 0, 8 do
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color and _G["ITEM_QUALITY" .. quality .. "_DESC"] == name then
            return Utils.ColorCode(color.r, color.g, color.b)
        end
    end
end

local ROLE_KEYS = { tank = "CHAT_ROLE_TANK", healer = "CHAT_ROLE_HEALER", damage = "CHAT_ROLE_DAMAGE" }

local BG_SYSTEM_EVENTS = {
    CHAT_MSG_BG_SYSTEM_ALLIANCE = true, CHAT_MSG_BG_SYSTEM_HORDE = true, CHAT_MSG_BG_SYSTEM_NEUTRAL = true,
}

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
-- The same, from battlegrounds whose announcer doesn't name them.
local UNNAMED_COUNTDOWN_PATTERN = "^[Tt]he [Bb]attle begins in (%d+ %a+)"
local ROUND_COUNTDOWN_PATTERNS = {
    "^[Rr]ound (%d+) of the [Bb]attle for .- begins in (%d+ %a+)",
    "^[Rr]ound (%d+) begins in (%d+ %a+)",
}
local UNNAMED_START_PATTERNS = {
    "^[Ll]et the [Bb]attle begin",
    "^[Tt]he [Bb]attle has begun",
}

-- The announcer's lines about flags, bases, gates and the score, in each
-- battleground's words: Warsong Gulch, Arathi Basin, Eye of the Storm,
-- Alterac Valley, Isle of Conquest, Strand of the Ancients and WoW Forever's
-- own. Most take who did it, then what; "passive" takes the side, then
-- who ("The Horde Flag was picked up by X"); "bare" takes nothing, "side"
-- only the side, "score" the side and its resources, "place" what was
-- destroyed. The first that matches wins.
local BATTLE_EVENT_PATTERNS = {
    { "^The flag has been dropped$", "CHAT_BG_FLAG_DROPPED", "bare" },
    { "^The flags are now placed at their bases$", "CHAT_BG_FLAGS_PLACED", "bare" },
    { "^The (.-) [Ff]lag was picked up by (.+)$", "CHAT_BG_TOOK", "passive" },
    { "^The (.-) [Ff]lag was dropped by (.+)$", "CHAT_BG_DROPPED", "passive" },
    { "^The (.-) [Ff]lag was returned to its base by (.+)$", "CHAT_BG_RETURNED", "passive" },
    { "^(.-) has taken control of the (.+)$", "CHAT_BG_TOOK" },
    { "^(.-) has lost control of the (.+)$", "CHAT_BG_LOST" },
    { "^(.-) has taken the (.+)$", "CHAT_BG_TOOK" },
    { "^(.-) has dropped the (.+)$", "CHAT_BG_DROPPED" },
    { "^(.-) ha[sv]e? captured the (.+)$", "CHAT_BG_CAPTURED" },
    { "^(.-) captured the (.+)$", "CHAT_BG_CAPTURED" },
    { "^(.-) has assaulted the (.+)$", "CHAT_BG_ASSAULTED" },
    { "^(.-) has defended the (.+)$", "CHAT_BG_DEFENDED" },
    -- "X claims the mine!  If left unchallenged, the Horde will control it
    -- in 1 minute!"
    { "^(.-) claims the (.-)!", "CHAT_BG_CLAIMED" },
    { "^The (%a+) has gathered (%d+) resources, and is near victory$", "CHAT_BG_NEAR_VICTORY", "score" },
    { "^The (%a+) team is running out of reinforcements$", "CHAT_BG_LOW_REINFORCEMENTS", "side" },
    { "^The (%a+) wins$", "CHAT_BG_WINS", "side" },
    { "^The (.-) has been destroyed$", "CHAT_BG_DESTROYED", "place" },
}

-- Who an announcer line names: a side without its "The", or a player
-- without the brackets of a link or a realm.
local function BattleActor(text)
    text = Trim(text):gsub("^%[(.-)%]$", "%1")
    local side = text:match("^[Tt]he (%a+)$")
    if side then return side end
    return NoRealm(text)
end

-- What it names: a place as written, a flag lowercased ("the Horde flag").
local function BattleTarget(text)
    return (Trim(text):gsub("[Ff]lag$", "flag"))
end

-- Without a color of its own, the line keeps the announcer's: the side's
-- color for what a side does.
local function FormatBattleEvent(plainSys)
    local text = Trim(plainSys):gsub("[%s!%.]+$", "")
    for _, entry in ipairs(BATTLE_EVENT_PATTERNS) do
        local key, kind = entry[2], entry[3]
        local first, second = text:match(entry[1])
        if first then
            if kind == "bare" then return T(key) end
            if kind == "passive" then return T(key, BattleActor(second), BattleTarget(first .. " flag")) end
            if kind == "side" then return T(key, first) end
            if kind == "score" then return T(key, first, second) end
            if kind == "place" then return T(key, (first:gsub("^%l", string.upper))) end
            return T(key, BattleActor(first), BattleTarget(second))
        end
    end
end

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
        local battle = Line(Palette.queue, name) .. Palette.white
        return Line(Palette.white, T("CHAT_BATTLE_BEGINS_IN", battle, wait))
    end
    wait = plainSys:match(UNNAMED_COUNTDOWN_PATTERN)
    if wait then return Line(Palette.white, T("CHAT_BATTLE_STARTS_IN", wait)) end
    for _, pattern in ipairs(ROUND_COUNTDOWN_PATTERNS) do
        local round
        round, wait = plainSys:match(pattern)
        if round then return Line(Palette.white, T("CHAT_BATTLE_ROUND_BEGINS_IN", round, wait)) end
    end

    for _, pattern in ipairs(BATTLE_START_PATTERNS) do
        name = plainSys:match(pattern)
        if name and name ~= "" then
            return Line(Palette.white, T("CHAT_BATTLE_BEGUN", Line(Palette.queue, name) .. Palette.white))
        end
    end
    for _, pattern in ipairs(UNNAMED_START_PATTERNS) do
        if plainSys:find(pattern) then return Line(Palette.white, T("CHAT_BATTLE_HAS_BEGUN")) end
    end
    return FormatBattleEvent(plainSys)
end

-- The game's own words for each loot method, by its Classic name, its
-- Enum.LootMethod key, and the global that says it.
local LOOT_METHOD_STRINGS = {
    freeforall = { "Freeforall", "ERR_SET_LOOT_FREEFORALL", "Looting set to Free for All." },
    roundrobin = { "Roundrobin", "ERR_SET_LOOT_ROUNDROBIN", "Looting set to Round Robin." },
    master = { "Masterlooter", "ERR_SET_LOOT_MASTER", "Looting set to Master Looter." },
    group = { "Group", "ERR_SET_LOOT_GROUP", "Looting set to Group Loot." },
    needbeforegreed = { "Needbeforegreed", "ERR_SET_LOOT_NBG", "Looting set to Need Before Greed." },
    personalloot = { "Personal", "ERR_SET_LOOT_PERSONAL", "Looting set to Personal." },
}

-- The game's "Looting set to ..." line for the group's loot method, which
-- Retail-based clients give as an Enum.LootMethod value and Classic as a name.
local function LootMethodLine()
    local getter = C_PartyInfo and C_PartyInfo.GetLootMethod or _G.GetLootMethod
    if type(getter) ~= "function" then return nil end
    local ok, method = pcall(getter)
    if not ok or IsSecret(method) then return nil end
    for name, strings in pairs(LOOT_METHOD_STRINGS) do
        local enumValue = Enum and Enum.LootMethod and Enum.LootMethod[strings[1]]
        if method == name or (enumValue ~= nil and method == enumValue) then
            return GameText(strings[2], strings[3])
        end
    end
end

local function LootThresholdLine()
    if type(GetLootThreshold) ~= "function" then return nil end
    local ok, quality = pcall(GetLootThreshold)
    if not ok or IsSecret(quality) or type(quality) ~= "number" then return nil end
    local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if type(name) ~= "string" then return nil end
    return GameText("ERR_SET_LOOT_THRESHOLD_S", "Loot threshold set to %s."):format(name)
end

function Social.Create()
    local api = {}

    local function ShortPlayerName(name)
        if type(name) ~= "string" then return "" end
        name = Trim(Utils.StripColorsAndLinks(name)):gsub("^%[(.-)%]$", "%1")
        local ok, short = pcall(Ambiguate, name, "short")
        if ok and type(short) == "string" and short ~= "" then
            name = short
        end
        return NoRealm(name)
    end

    local function PlayerKey(name)
        name = ShortPlayerName(name)
        if name == "" then return nil end
        return name:lower()
    end

    -- The death line uses the first name; join and leave lines use the full
    -- name, which on WoW Forever includes the surname: UnitName gives it as
    -- a second value, but system lines write "First Surname".
    local function GetMemberNames(unit)
        if not UnitName then return nil end
        local ok, name, surname = pcall(UnitName, unit)
        if not ok or IsSecret(name) or IsSecret(surname) then return nil end
        if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
        local fullName = name
        if Carpenter.Client.isForever and type(surname) == "string" and surname ~= "" then
            local consts = Constants and Constants.CharacterNameSeparatorConsts
            fullName = name .. (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname
        end
        return fullName, name
    end

    -- System lines like /roll results only carry a name, so Blizzard never
    -- class-colors it the way it does chat senders. Look the class up on the
    -- units we can see, then on players who spoke in chat this session.
    local senderClasses = {}

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
        if ReadableBool(UnitIsPlayer, unit) == false then return nil end
        local fullName, name = GetMemberNames(unit)
        if not fullName or (PlayerKey(fullName) ~= key and PlayerKey(name) ~= key) then return nil end
        local ok, _, token = pcall(UnitClass, unit)
        if ok and type(token) == "string" and not IsSecret(token) then
            return token
        end
    end

    function api.GetPlayerClassColor(name)
        local key = PlayerKey(name)
        if not key or not UnitClass then return nil end

        local units = { "player", "target", "focus", "mouseover" }
        local groupPrefix = IsInRaid() and "raid" or "party"
        for i = 1, GetNumGroupMembers() do
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
    local MAX_JOINS_AT_ONCE = 3
    -- A player can join before the game has their name: UnitName says
    -- "Unknown" until UNIT_NAME_UPDATE. Their join then counts from when they
    -- came. A name that takes longer than this has no hidden line left
    -- waiting, and would only take the lines of whatever changed as it came.
    local NAME_WAIT_MAX = 3
    -- Members already there at a fresh snapshot never count as joining.
    local AT_SNAPSHOT = -math.huge
    local groupChanges = {}
    local deadMembers = {}
    local rosterNames = {}
    local rosterInRaid = false
    -- When each member still without a name came, oldest first.
    local unnamedSince = {}
    -- Who led the group at the last snapshot: true for you, else a full name.
    local rosterLeader

    -- Your own death has its own line, so you are never a tracked member.
    -- Unit comparisons can be hidden too, so the name decides as well.
    local function IsSelf(unit, fullName)
        if ReadableBool(UnitIsUnit, unit, "player") then return true end
        return fullName ~= nil and fullName == GetMemberNames("player")
    end

    -- Calls back for every other member with a name; returns how many have
    -- none yet.
    local function ForEachGroupMember(callback)
        local inRaid = IsInRaid()
        local prefix = inRaid and "raid" or "party"
        local count = GetNumGroupMembers()
        if not inRaid then count = count - 1 end
        local unnamed = 0
        for i = 1, count do
            local unit = prefix .. i
            local fullName, firstName = GetMemberNames(unit)
            if not fullName then
                unnamed = unnamed + 1
            elseif not IsSelf(unit, fullName) then
                callback(unit, fullName, firstName)
            end
        end
        return unnamed
    end

    local function PruneChanges(now)
        while groupChanges[1] and now - groupChanges[1].time > CHANGE_WINDOW do
            table.remove(groupChanges, 1)
        end
    end

    -- Who leads the group: true for you, a member's full name, or nil when
    -- that can't be read.
    local function GroupLeader()
        if ReadableBool(UnitIsGroupLeader, "player") then return true end
        local leader
        ForEachGroupMember(function(unit, fullName)
            if not leader and ReadableBool(UnitIsGroupLeader, unit) then leader = fullName end
        end)
        return leader
    end

    -- since: when a member who joined without a name came.
    local function AddChange(kind, name, now, since)
        PruneChanges(now)
        groupChanges[#groupChanges + 1] = { kind = kind, name = name, time = now, since = since }
    end

    -- True when a new death was noted for a hidden line to take. announce
    -- says whether lines are hidden; when it's left out, that's checked only
    -- for a new death, since health events come for every unit.
    local function NoteMemberDeath(unit, fullName, firstName, now, announce)
        local dead = ReadableBool(UnitIsDeadOrGhost, unit)
        if dead == nil then return false end
        local noted = dead and not deadMembers[fullName]
        if noted and announce == nil then announce = Utils.InChatLockdown() end
        noted = noted and announce == true
        if noted then
            AddChange("died", firstName, now)
        end
        deadMembers[fullName] = dead or nil
        return noted
    end

    local BYTE_R, BYTE_P = ("r"):byte(), ("p"):byte()

    -- Unit events fire for every nameplate too, so only group tokens get
    -- past the first byte.
    local function IsGroupUnit(unit)
        if type(unit) ~= "string" then return false end
        local first = unit:byte(1)
        if first ~= BYTE_R and first ~= BYTE_P then return false end
        return unit:match("^raid%d+$") ~= nil or unit:match("^party%d$") ~= nil
    end

    function api.NoteGroupMemberHealth(unit)
        if not IsGroupUnit(unit) then return false end
        local fullName, firstName = GetMemberNames(unit)
        if fullName and not IsSelf(unit, fullName) then
            return NoteMemberDeath(unit, fullName, firstName, GetTime())
        end
        return false
    end

    -- Pass reset to take a fresh snapshot without noting any change, such as
    -- after a loading screen. A group that forms or turns into another, like a
    -- battleground raid filling in at once from your party, is a snapshot too.
    function api.NoteGroupRoster(reset)
        local now = GetTime()
        local inRaid = IsInRaid() and true or false
        local current, added = {}, {}
        local unnamed = ForEachGroupMember(function(_, fullName)
            current[fullName] = true
            if not rosterNames[fullName] then
                added[#added + 1] = fullName
            end
        end)
        local fresh = reset or next(rosterNames) == nil or inRaid ~= rosterInRaid
        -- Members whose names came (or who left before they had one) give up
        -- the oldest waiting times; new ones wait from now.
        if fresh then unnamedSince = {} end
        local cameAt = {}
        while #unnamedSince > unnamed do
            cameAt[#cameAt + 1] = table.remove(unnamedSince, 1)
        end
        while #unnamedSince < unnamed do
            unnamedSince[#unnamedSince + 1] = fresh and AT_SNAPSHOT or now
        end
        local announce = not fresh and #added <= MAX_JOINS_AT_ONCE and Utils.InChatLockdown()
        if announce then
            for index, fullName in ipairs(added) do
                local since = cameAt[index]
                if not since or now - since <= NAME_WAIT_MAX then
                    AddChange("joined", fullName, now, since)
                end
            end
            for fullName in pairs(rosterNames) do
                if not current[fullName] then
                    AddChange("left", fullName, now)
                end
            end
        end
        -- A new leader ("You are now the group leader."); name is nil for you.
        local leader = GroupLeader()
        if fresh then
            rosterLeader = leader
        elseif leader ~= nil then
            if rosterLeader ~= nil and leader ~= rosterLeader and Utils.InChatLockdown() then
                AddChange("leader", leader ~= true and leader or nil, now)
            end
            rosterLeader = leader
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
        local deathsHidden = not reset and Utils.InChatLockdown()
        ForEachGroupMember(function(unit, fullName, firstName)
            NoteMemberDeath(unit, fullName, firstName, now, deathsHidden)
        end)
    end

    -- A name that came after its player joined. True when the roster was
    -- taken again for it.
    function api.NoteMemberName(unit)
        if not unnamedSince[1] or not IsGroupUnit(unit) then return false end
        api.NoteGroupRoster()
        return true
    end

    -- Recent joins, departures and deaths, oldest first.
    function api.GetGroupChanges()
        PruneChanges(GetTime())
        return groupChanges
    end

    function api.FormatGroupChange(change)
        if change.kind == "died" then
            return Line(Palette.red, T("CHAT_PLAYER_DIED", change.name))
        elseif change.kind == "left" then
            return Line(Palette.red, T("CHAT_PLAYER_LEFT", change.name))
        elseif change.kind == "leader" then
            if not change.name then return Line(Utils.GroupColor(), T("CHAT_YOU_ARE_GROUP_LEADER")) end
            return Line(Utils.GroupColor(), T("CHAT_PLAYER_NOW_GROUP_LEADER", change.name))
        end
        return Line(Palette.green, T("CHAT_PLAYER_JOINED", change.name))
    end

    local function IsGuildMember(key)
        if not (GetNumGuildMembers and GetGuildRosterInfo) then return false end
        local ok, count = pcall(GetNumGuildMembers)
        for i = 1, ok and tonumber(count) or 0 do
            local found, name = pcall(GetGuildRosterInfo, i)
            if found and PlayerKey(name) == key then return true end
        end
        return false
    end

    -- "X has come online": guild members in the guild chat's color, friends
    -- in yellow.
    local function FormatOnlineNotice(name, actionKey)
        local shortName = ShortPlayerName(name)
        if shortName == "" then return nil end
        local color = IsGuildMember(shortName:lower()) and Utils.GuildColor() or Palette.yellow
        return Line(color, shortName .. " " .. T(actionKey))
    end

    function api.IsBattleStartAnnouncement(text)
        if IsSecret(text) or type(text) ~= "string" then return false end
        for _, pattern in ipairs(BATTLE_START_PATTERNS) do
            if text:match(pattern) then return true end
        end
        for _, pattern in ipairs(UNNAMED_START_PATTERNS) do
            if text:find(pattern) then return true end
        end
        return false
    end

    function api.FormatBattlegroundAndGroupNotice(event, plainSys)
        if type(plainSys) ~= "string" then return nil end

        if BG_SYSTEM_EVENTS[event] then
            local count = plainSys:match("^(%d+)%s+players have joined the battle%.?%s*$")
            if count then
                return Line(Palette.green, T("CHAT_PLAYERS_JOINED", count))
            end
            local joined = plainSys:match("^%s*(.-)%s+has joined the battle%.?%s*$")
            if joined and joined ~= "" then
                return Line(Palette.green, T("CHAT_PLAYER_JOINED", joined))
            end
            local left = plainSys:match("^%s*(.-)%s+has left the battle%.?%s*$")
            if left and left ~= "" then
                return Line(Palette.red, T("CHAT_PLAYER_LEFT", left))
            end
            local announcement = FormatBattleAnnouncement(plainSys)
            if announcement then return announcement end
        end

        local lower = plainSys:lower()
        if lower:find("flag", 1, true) and lower:find("has been reset", 1, true) then
            return Line(Palette.orange, T("CHAT_FLAG_RESET"))
        end

        local groupColor = Utils.GroupColor()
        if plainSys:find("Party converted to Raid", 1, true) then
            return Line(groupColor, T("CHAT_PARTY_CONVERTED_TO_RAID"))
        end
        if plainSys:find("Raid converted to Party", 1, true) then
            return Line(groupColor, T("CHAT_RAID_CONVERTED_TO_PARTY"))
        end
        local raidJoin = plainSys:match("^%s*(.-)%s+has joined the raid group%.?%s*$")
        if raidJoin and raidJoin ~= "" then
            return Line(groupColor, T("CHAT_JOINED_RAID", raidJoin))
        end
        local raidLeave = plainSys:match("^%s*(.-)%s+has left the raid group%.?%s*$")
        if raidLeave and raidLeave ~= "" then
            return Line(groupColor, T("CHAT_LEFT_RAID", raidLeave))
        end
        if plainSys:find("You are in both a party and a battleground group", 1, true) then
            return Line(groupColor, T("CHAT_PARTY_AND_BG_GROUP"))
        end
        if plainSys:find("You may communicate with your party", 1, true) and plainSys:find("/p", 1, true)
            and plainSys:find("/bg", 1, true) then
            return Line(groupColor, T("CHAT_PARTY_BG_COMMANDS"))
        end
        if plainSys:find("The battle has ended", 1, true)
            and (plainSys:find("battleground will close", 1, true) or plainSys:find("close in", 1, true)) then
            return Line(Palette.white, T("CHAT_BATTLE_ENDED"))
        end
        return nil
    end

    -- The game's system lines about you, your friends and your group, in
    -- the order they are tried. true hides the line.
    function api.FormatSystemSocialMessage(plainMsg)
        if type(plainMsg) ~= "string" then return nil end
        local text = Trim(plainMsg)
        local lower = text:lower()

        if text == _G.CLEARED_AFK then return Line(Palette.green, T("CHAT_BACK")) end
        if text == _G.CLEARED_DND then return Line(Palette.green, T("CHAT_AVAILABLE")) end
        local online = text:match("^(.-)%s+has come online%.?$")
        if online and online ~= "" then return FormatOnlineNotice(online, "CHAT_CAME_ONLINE") end
        local offline = text:match("^(.-)%s+has gone offline%.?$")
        if offline and offline ~= "" then return FormatOnlineNotice(offline, "CHAT_WENT_OFFLINE") end
        if text == _G.MARKED_AFK then return Line(Palette.orange, T("CHAT_AFK")) end
        local away = text:match("^You are now Away: (.+)$") or text:match("^You are now AFK: (.+)$")
        if away then
            away = Trim(away)
            if away == "" or away:lower() == "afk" then return Line(Palette.orange, T("CHAT_AFK")) end
            return Line(Palette.orange, T("CHAT_AFK_WITH_MESSAGE", away))
        end
        if text:find("^You are now Busy") then return Line(Palette.darkorange, T("CHAT_BUSY")) end
        if text:find("^You are now flagged for PvP combat") then return Line(Palette.red, T("CHAT_FLAGGED_PVP")) end
        if lower:find("feel rested", 1, true) and lower:find("you", 1, true) then
            return Line(Palette.restedBar, T("CHAT_RESTED"))
        end
        -- WoW Forever says "You are no longer rested." where the other clients
        -- say "You feel normal."
        if (lower:find("feel normal", 1, true) and lower:find("you", 1, true)) or text:find("^You are no longer rested%.?$") then
            return Line(Palette.normalBar, T("CHAT_NORMAL"))
        end
        local home = text:match("^(.+) is now your home%.?$")
        if home then
            return Palette.white .. T("CHAT_HOME_LABEL") .. " |r" .. Line(Palette.queue, CleanPunctuation(home))
        end

        if text:find("Ready Check", 1, true) and text:find("failed", 1, true) then
            return Line(Palette.red, T("CHAT_READY_CHECK_FAILED"))
        end
        local notReady = text:match("^(.-)%s+is not ready%.?$")
        if notReady and notReady ~= "" then return Line(Palette.red, T("CHAT_NOT_READY", NoRealm(notReady))) end
        local inGroup = text:match("^(.-)%s+is already in a group%.?$")
        if inGroup and inGroup ~= "" then return Line(Palette.red, T("CHAT_ALREADY_IN_GROUP", NoRealm(inGroup))) end
        if text:find("^[Yy]ou aren't in a party%.?$") or text:find("^[Yy]ou are not in a party%.?$") then
            return Line(Palette.red, T("CHAT_NOT_IN_PARTY"))
        end
        local lootMaster = text:match("^(.-)%s+is now the loot master%.?$")
        if lootMaster and lootMaster ~= "" then return Line(Palette.orange, T("CHAT_LOOT_MASTER", NoRealm(lootMaster))) end
        if text:find("ready check", 1, true) and text:find("initiated", 1, true) and text:find("queued", 1, true) then
            return Line(Palette.orange, T("CHAT_READY_CHECK"))
        end
        local readyChecker = text:match("^(.-)%s+has initiated a ready check%.?$")
        if readyChecker and readyChecker ~= "" then
            return Line(Palette.orange, NoRealm(readyChecker) .. " " .. T("CHAT_INITIATED_READY_CHECK"))
        end
        local roleName, role = text:match("^(.-)%s+is now%s+(%a+)%.?$")
        local roleKey = role and ROLE_KEYS[role:lower()]
        if roleKey then return Line(Palette.orange, NoRealm(roleName) .. " " .. T(roleKey)) end

        local remaining = text:match("^You can only complete%s+(%d+)%s+more daily quests today%.?$")
        local done = text:match("^You have already completed%s+(%d+)%s+daily quests today%.?$")
        if remaining or done then
            local total = 25
            done = done and tonumber(done) or total - tonumber(remaining)
            done = math.max(0, math.min(total, done))
            return Line(Palette.restedBar, done .. "/" .. total) .. " " .. Line(Palette.white, T("CHAT_DAILY_QUESTS_TODAY"))
        end

        local tradeTarget = text:match("^You have requested to trade with%s+(.-)%.?$")
        if tradeTarget and tradeTarget ~= "" then
            return Line(Palette.green, T("CHAT_REQUESTED_TRADE", NoRealm(tradeTarget)))
        end

        local instanceJoin = text:match("^(.-)%s+has joined the instance group%.?$")
        if instanceJoin and instanceJoin ~= "" then return Line(Palette.green, T("CHAT_PLAYER_JOINED", instanceJoin)) end
        local instanceLeave = text:match("^(.-)%s+has left the instance group%.?$")
        if instanceLeave and instanceLeave ~= "" then return Line(Palette.red, T("CHAT_PLAYER_LEFT", instanceLeave)) end
        local guildJoiner = text:match("^(.-)%s+has joined the guild%.?$")
        if guildJoiner and NoRealm(guildJoiner) ~= "" then
            return Line(Palette.green, NoRealm(guildJoiner) .. " " .. T("CHAT_JOINED_GUILD"))
        end
        local guildLeaver = text:match("^(.-)%s+has left the guild%.?$")
        if guildLeaver and NoRealm(guildLeaver) ~= "" then
            return Line(Palette.red, NoRealm(guildLeaver) .. " " .. T("CHAT_LEFT_GUILD"))
        end
        local players = text:match("^(%d+)%s+players have joined the battle%.?$")
        if players then return Line(Palette.green, T("CHAT_PLAYERS_JOINED", players)) end
        if text:find("^Notify system has been enabled%.?$") or text:find("^Notify system has been disabled%.?$") then
            return true
        end

        local groupColor = Utils.GroupColor()
        local inviter = text:match("^(.-)%s+has invited you to join a group%.?$")
            or text:match("^(.-)%s+invites you to a group%.?$")
            or text:match("^(.-)%s+invites you to group%.?$")
            or text:match("^(.-)%s+invites you to join a group%.?$")
            or text:match("%[([^%]]+)%]%s*invited you")
        if inviter then
            inviter = Trim(inviter):gsub("^%[(.-)%]$", "%1")
            if inviter ~= "" then return Line(Palette.green, T("CHAT_PLAYER_INVITED_YOU", inviter)) end
        end
        local invited = text:match("^You have invited%s+(.-)%s+to join your group%.?$")
        if invited and invited ~= "" then return Line(Palette.green, T("CHAT_INVITED_PLAYER", invited)) end
        -- A group member who isn't the leader suggests an invite instead.
        local suggested = text:match("^You have suggested that%s+(.-)%s+join your group%.?$")
        if suggested and suggested ~= "" then return Line(Palette.green, T("CHAT_SUGGESTED_PLAYER", suggested)) end
        local decliner = text:match("^(.-)%s+declines your group invitation%.?$") or text:match("^(.-)%s+declines%.?$")
        if decliner and decliner ~= "" then return Line(Palette.red, T("CHAT_PLAYER_DECLINES", decliner)) end
        if text:find("^Your group has been disbanded%.?$") then return Line(Palette.red, T("CHAT_GROUP_DISBANDED")) end
        local leftGroup = text:match("^You leave the (%a+)%.?$") or text:match("^You left the (%a+)%.?$")
            or text:match("^You have left the (%a+)%.?$")
        if leftGroup == "group" or leftGroup == "raid" then
            return Line(Palette.red, T(leftGroup == "raid" and "CHAT_LEFT_RAID_SELF" or "CHAT_LEFT_PARTY_SELF"))
        end

        local difficultyLabel = GameText("DUNGEON_DIFFICULTY", "Dungeon Difficulty")
        if text:find(difficultyLabel, 1, true) then
            local difficulty = text:match("set to (%w+)") or text:match(Utils.EscapePattern(difficultyLabel) .. ":%s*(%w+)")
            if difficulty then
                local color = difficulty:lower() == "heroic" and Palette.orange or Palette.white
                return groupColor .. difficultyLabel .. ": |r" .. Line(color, difficulty)
            end
        end
        if text:find("^You have been removed from the group%.?$") or text:find("^You have been removed from the raid%.?$") then
            return Line(Palette.red, T("CHAT_REMOVED_FROM_GROUP"))
        end

        local joiner = text:match("^(.-)%s+joins the party%.?$") or text:match("^(.-)%s+joins the raid%.?$")
        if joiner and joiner ~= "" then return Line(Palette.green, T("CHAT_PLAYER_JOINS", joiner)) end
        local leader = text:match("^(.-)%s+is now the group leader%.?$") or text:match("^(.-)%s+is now the raid leader%.?$")
        if leader and leader ~= "" then return Line(groupColor, T("CHAT_PLAYER_NOW_GROUP_LEADER", leader)) end
        if text:find("^You are now the group leader%.?$") or text:find("^You are now the raid leader%.?$") then
            return Line(groupColor, T("CHAT_YOU_ARE_GROUP_LEADER"))
        end
        local lootMethod = text:match("^[Ll]ooting set to%s+(.+)$")
            or text:match("[Ll]ooting changed to%s+(.+)$")
            or text:match("[Ll]oot method set to%s+(.+)$")
            or text:match("[Ll]oot method changed to%s+(.+)$")
            or text:match("[Ll]oot%s+changed to%s+(.+)$")
        if lootMethod then
            return Palette.white .. T("CHAT_LOOT_LABEL") .. " |r" .. Line(groupColor, LootMethodDisplay(lootMethod))
        end
        local threshold = text:match(LOOT_THRESHOLD_PATTERN)
        if threshold and threshold ~= "" then
            return Palette.white .. T("CHAT_LOOT_THRESHOLD_LABEL") .. " |r" .. Line(QualityColor(threshold) or groupColor, threshold)
        end
        local died = text:match("^(.-)%s+has died%.?$")
        if died and died ~= "" then return Line(Palette.red, T("CHAT_PLAYER_DIED", died)) end
        local leaver, from = text:match("^(.-)%s+leaves the (%a+)%.?$")
        if leaver and leaver ~= "" and (from == "party" or from == "raid") then
            return Line(Palette.red, T(from == "raid" and "CHAT_PLAYER_LEAVES_RAID" or "CHAT_PLAYER_LEAVES_PARTY", leaver))
        end

        return nil
    end

    -- The lines the game sends as it forms a battleground's group, in its
    -- order (a probe's log): "Party converted to Raid" for a raid, then the
    -- loot method and the loot threshold, styled as the chat filter styles
    -- them. Nil when the loot settings can't be read.
    function api.GroupSetupLines()
        local method, threshold = LootMethodLine(), LootThresholdLine()
        if not (method and threshold) then return nil end
        local texts = {}
        if IsInRaid() then
            texts[1] = api.FormatBattlegroundAndGroupNotice("CHAT_MSG_SYSTEM",
                GameText("ERR_PARTY_CONVERTED_TO_RAID", "Party converted to Raid"))
        end
        texts[#texts + 1] = api.FormatSystemSocialMessage(method)
        texts[#texts + 1] = api.FormatSystemSocialMessage(threshold)
        for index = 1, (IsInRaid() and 3 or 2) do
            if type(texts[index]) ~= "string" then return nil end
        end
        return texts
    end

    return api
end
