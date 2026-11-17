--[[ Carpenter - ChatCleaner hidden lines ]]
-- Retail and WoW Forever hide system, skill-up and player chat lines from
-- addons during chat messaging lockdown, which covers whole battlegrounds
-- and fights in instances. Chat filters are only called for lines an addon
-- can read, so these can't be styled before they are added. They still land
-- in each chat window's history with their chat type and the time they were
-- added, so they are found there and rewritten once their cause is known.
-- The rules, in the order they claim lines:
--   1. Guild, officer, party, raid and instance chat. The window keeps each
--      line's event and its values, so ChatCleaner rebuilds the line from
--      them, styled, as it's added.
--   2. A skill-up, from the skill rank that rose within a moment of it
--      (skill ranks stay readable). Two skills rising together each take
--      a line.
--   3. Your own death, the game's "[You died.]" Death Recap link, which it
--      adds with no chat event: the one hidden line that comes with or after
--      PLAYER_DEAD, a combat info line before a system line.
--   4. A battleground's group forming as you enter: "Party converted to
--      Raid" (in a raid), the loot method and the loot threshold, in a row
--      just before GROUP_JOINED (a probe's log). They are told by their
--      place, as the loot settings may not change.
--   5. Joining or leaving a battleground queue, from the queue that starts
--      or ends right after its line. The queues the game drops and adds back
--      as you enter a battleground: the drop has no line, and each one added
--      back has its own "You have joined the queue for ..." just before it.
--   6. A join or departure, from the roster change it comes with (at most a
--      quarter second before it in three battleground logs). Each change
--      names its nearest line; battlegrounds send two lines per change, so
--      there each then empties its next nearest.
--   7. A group member's death, when exactly one death and one line meet.
--   8. On Forever, in a battleground: "Notify system has been
--      disabled/enabled", the first hidden line right after entering (it
--      doesn't always come) and right after the battle begins; and
--      Blizzard's batched "has joined the battle" lines in the first minute,
--      which repeat joins already shown. Those come from its battleground
--      chat filter, whose call stack stays readable (the window's own hidden
--      lines have a hidden stack), so they are emptied as they are added;
--      failing that, they print every 5 s from 30 s after entering and are
--      checked after each tick.
-- Anything else stays as the game wrote it. Lines are edited with
-- TransformMessages only: removing them would taint the chat history.
local _, ns = ...
ns.Private = ns.Private or {}

local HiddenLines = {}
ns.Private.ChatCleanerHiddenLines = HiddenLines

HiddenLines.START_NOTICE_GRACE = 0.35
HiddenLines.BATCH_GRACE = 0.6
HiddenLines.BATCH_TIMES = { 30, 35, 40, 45, 50, 55, 60 }

local LINE_MAX_AGE = 3
local LINE_BEFORE_CHANGE = 0.5
local LINE_AFTER_CHANGE = 0.3
local DEATH_WINDOW = 1.0
local SKILL_WINDOW = 1.5
local ENTER_NOTICE_WINDOW = 1.5
local START_NOTICE_WINDOW = 5
local START_NOTICE_GRACE = HiddenLines.START_NOTICE_GRACE
local SAME_MOMENT = 0.2
local GROUP_SETUP_WINDOW = 10
local BATCH_SLACK = 0.5
local BATCH_GRACE = HiddenLines.BATCH_GRACE
-- When to look again after each batch tick: a line can come up to
-- BATCH_SLACK after the tick and is claimed BATCH_GRACE after it came.
HiddenLines.BATCH_CHECK_DELAY = BATCH_SLACK + BATCH_GRACE + 0.05
-- Blizzard's batches stop a minute after entering.
local BATCH_PERIOD = HiddenLines.BATCH_TIMES[#HiddenLines.BATCH_TIMES] + BATCH_SLACK

local IsSecret = Carpenter.Secret.IsSecret

-- config:
--   GetFrames()         chat windows whose lines may be edited
--   GetChanges()        recent group changes { kind, name, time }, oldest first
--   FormatChange(change)
--   GetSkillRises()     recent skill rank rises { name, rank, time }, oldest first
--   FormatSkillRise(rise)
--   GetQueueChanges()   recent battleground queue changes { kind, name, time }, oldest first
--   FormatQueueChange(change)
--   IsHiddenChatEvent(event)  true for the chat events rebuilt here
--   FormatHiddenChat(event, args)  the styled line, or nil
--   FormatOwnDeath()    the styled "You died" line, or nil
--   IsActive()          true while lines can be hidden
--   IsForever()         rule 8 only applies on WoW Forever
function HiddenLines.Create(config)
    config = config or {}
    local api = {}
    local seen = setmetatable({}, { __mode = "k" })
    local pendingByFrame = setmetatable({}, { __mode = "k" })
    local doneByFrame = setmetatable({}, { __mode = "k" })
    local battle = {}
    local ownDeath
    local order = 0

    local function Now()
        return GetTime and GetTime() or 0
    end

    -- Chat type ids of the lines looked at, by kind, read once per set of
    -- chat type tables.
    local typeIDs, typeInfos = nil, {}
    local function TypeIDs()
        local system = ChatTypeInfo and ChatTypeInfo.SYSTEM
        local skill = ChatTypeInfo and ChatTypeInfo.SKILL
        local misc = ChatTypeInfo and ChatTypeInfo.COMBAT_MISC_INFO
        if not typeIDs or typeInfos[1] ~= system or typeInfos[2] ~= skill or typeInfos[3] ~= misc then
            typeInfos = { system, skill, misc }
            typeIDs = { system = system and system.id, skill = skill and skill.id, misc = misc and misc.id }
        end
        return typeIDs
    end

    local function GetElements(frame)
        local buffer = frame and frame.historyBuffer
        local elements = buffer and buffer.elements
        if type(elements) == "table" then return elements end
    end

    -- "system", "skill", "misc" (combat info) or "chat" for a recent hidden
    -- line. A chat line is told by the event the window keeps with it.
    local function HiddenLineKind(entry, typeIDs, now)
        local time, extra = entry.timestamp, entry.extraData
        if type(time) ~= "number" or IsSecret(time) or now - time > LINE_MAX_AGE then return nil end
        if not IsSecret(entry.message) or type(extra) ~= "table" then return nil end
        local event = extra[4]
        if config.IsHiddenChatEvent and type(event) == "string" and not IsSecret(event)
            and config.IsHiddenChatEvent(event) then
            return "chat"
        end
        local typeID = extra[1]
        if typeID == nil or IsSecret(typeID) then return nil end
        for kind, id in pairs(typeIDs) do
            if typeID == id then return kind end
        end
    end

    -- Hidden lines added since the last look, in every chat window or in one.
    local function Collect(now, onlyFrame)
        local ids = TypeIDs()
        if not ids.system or not config.GetFrames then return end
        for _, frame in ipairs(onlyFrame and { onlyFrame } or config.GetFrames()) do
            local elements = GetElements(frame)
            if elements then
                for _, entry in ipairs(elements) do
                    if type(entry) == "table" and not seen[entry] then
                        seen[entry] = true
                        local kind = HiddenLineKind(entry, ids, now)
                        if kind then
                            order = order + 1
                            local lines = pendingByFrame[frame] or {}
                            pendingByFrame[frame] = lines
                            lines[#lines + 1] = {
                                frame = frame, entry = entry, kind = kind, time = entry.timestamp, order = order,
                            }
                            if kind == "chat" then
                                lines[#lines].event, lines[#lines].args = entry.extraData[4], entry.extraData[5]
                            end
                        end
                    end
                end
            end
        end
    end

    -- The history keeps lines in its own order; TransformMessages walks that
    -- same array, so the line is found by its place there. A hidden line is
    -- rewritten while it's still hidden; a shown one while it still reads
    -- `expected`.
    local function RewriteEntry(frame, target, text, expected)
        local elements = GetElements(frame)
        if not elements or type(frame.TransformMessages) ~= "function" then return false end
        local position
        for index, entry in ipairs(elements) do
            if entry == target then
                position = index
                break
            end
        end
        if not position then return false end

        local call, rewritten = 0, false
        frame:TransformMessages(function(message)
            call = call + 1
            if call ~= position then return false end
            if expected == nil then return IsSecret(message) end
            return not IsSecret(message) and message == expected
        end, function(_, ...)
            rewritten = true
            return text, ...
        end)
        -- The history may hold a new entry there now. A rebuilt chat line is
        -- still hidden text with its event, so it would be rebuilt again.
        if rewritten and elements[position] then seen[elements[position]] = true end
        return rewritten
    end

    local function Rewrite(line, text)
        return RewriteEntry(line.frame, line.entry, text)
    end

    -- Hidden chat lines rebuilt from the event and values their window keeps.
    local function ResolveChatLines(lines)
        if not config.FormatHiddenChat then return end
        for _, line in ipairs(lines) do
            if line.kind == "chat" and not line.resolved then
                local text = config.FormatHiddenChat(line.event, line.args)
                if text then
                    line.resolved = true
                    pcall(Rewrite, line, text)
                end
            end
        end
    end

    -- How many of a window's lines a cause (a change, rise, death or group
    -- setup) has taken.
    local function Claims(cause, frame)
        cause.claims = cause.claims or setmetatable({}, { __mode = "k" })
        return cause.claims[frame] or 0
    end

    -- Each hidden skill-up takes the oldest rise near it that this window's
    -- lines haven't taken yet.
    local function ResolveSkillLines(frame, lines, Apply)
        if not lines[1] or not (config.GetSkillRises and config.FormatSkillRise) then return end
        local rises = config.GetSkillRises() or {}
        for _, line in ipairs(lines) do
            for _, rise in ipairs(rises) do
                if Claims(rise, frame) == 0 and math.abs(rise.time - line.time) <= SKILL_WINDOW then
                    rise.claims[frame] = 1
                    Apply(line, config.FormatSkillRise(rise))
                    break
                end
            end
        end
    end

    -- The group's lines are the newest ones in the history when GROUP_JOINED
    -- came, in the same moment, as many as there are texts; with fewer, none
    -- are touched.
    local function ResolveGroupSetup(frame, lines, Apply)
        local setup = battle.groupSetup
        if not setup or not setup.seenOrder or Claims(setup, frame) > 0 then return end
        local candidates = {}
        for _, line in ipairs(lines) do
            if not line.resolved and line.order <= setup.seenOrder
                and math.abs(setup.time - line.time) <= SAME_MOMENT then
                candidates[#candidates + 1] = line
            end
        end
        local count = #setup.texts
        if #candidates < count then return end
        setup.claims[frame] = 1
        for index = 1, count do
            Apply(candidates[#candidates - count + index], setup.texts[index])
        end
    end

    -- Each queue that starts or ends takes a line that was already in the
    -- history when the change was first seen, and came within the change's
    -- window before it; a line added after the change belongs to something
    -- else. A join takes the newest: entering a battleground brings the raid
    -- and loot lines in the same moment, just before the queue's. A leave
    -- takes the oldest, since its line comes a moment before the queue goes:
    -- leaving two queues, the first line is the first queue's. These go
    -- before roster changes, so a player joining at that moment can't take
    -- the queue's line.
    local function ResolveQueueChanges(frame, lines, queueChanges, Apply)
        if not (lines[1] and config.FormatQueueChange) then return end
        local entered = battle.enteredAt
        for _, change in ipairs(queueChanges) do
            -- The game drops your queues on its own as you enter, with no line.
            local dropped = change.kind == "left" and entered
                and change.time >= entered and change.time - entered <= ENTER_NOTICE_WINDOW
            if not dropped and Claims(change, frame) == 0 then
                local oldestFirst = change.kind == "left"
                local pick
                for _, line in ipairs(lines) do
                    if not line.resolved and line.order <= change.seenOrder
                        and math.abs(change.time - line.time) <= (change.window or 0)
                        and (not pick or (oldestFirst and line.order < pick.order)
                            or (not oldestFirst and line.order > pick.order)) then
                        pick = line
                    end
                end
                if pick then
                    change.claims[frame] = 1
                    Apply(pick, config.FormatQueueChange(change))
                end
            end
        end
    end

    -- The unclaimed line nearest to a roster change, in its window.
    local function NearestRosterLine(lines, change)
        local best, bestDistance
        for _, line in ipairs(lines) do
            local delta = change.time - line.time
            if not line.resolved and delta >= -LINE_AFTER_CHANGE and delta <= LINE_BEFORE_CHANGE then
                local distance = math.abs(delta)
                if not best or distance < bestDistance or (distance == bestDistance and line.order < best.order) then
                    best, bestDistance = line, distance
                end
            end
        end
        return best
    end

    -- Every change first names the line nearest to it; then, in a
    -- battleground, which sends two lines per change, each empties the next
    -- nearest. Naming all of them first keeps two joins at once from both
    -- going to the first.
    local function ResolveRosterChanges(frame, lines, changes, Apply)
        if not config.FormatChange then return end
        local lineCount = battle.enteredAt and 2 or 1
        for claim = 1, lineCount do
            for _, change in ipairs(changes) do
                if (change.kind == "joined" or change.kind == "left") and Claims(change, frame) == claim - 1 then
                    local line = NearestRosterLine(lines, change)
                    if line then
                        change.claims[frame] = claim
                        Apply(line, claim == 1 and config.FormatChange(change) or "")
                    end
                end
            end
        end
    end

    -- Your death takes the one hidden line that came with or after it, a
    -- combat info line if there are any, else a system line; with two or
    -- more, none. A line from before the death belongs to something else.
    local function ResolveOwnDeath(frame, systemLines, miscLines, Apply, now)
        local death = ownDeath
        if not death or not config.FormatOwnDeath or Claims(death, frame) > 0 then return end
        if now - death.time > LINE_MAX_AGE then return end
        local function Single(lines)
            local found, count = nil, 0
            for _, line in ipairs(lines) do
                local since = line.time - death.time
                if not line.resolved and since >= -SAME_MOMENT and since <= DEATH_WINDOW then
                    found, count = line, count + 1
                end
            end
            return found, count
        end
        local line, count = Single(miscLines)
        if count == 0 then line, count = Single(systemLines) end
        if count ~= 1 then return end
        local text = config.FormatOwnDeath()
        if not text then return end
        death.claims[frame] = 1
        Apply(line, text)
    end

    local function ClaimDeath(line, lines, changes)
        local match
        for _, change in ipairs(changes) do
            if change.kind == "died" and math.abs(change.time - line.time) <= DEATH_WINDOW
                and Claims(change, line.frame) == 0 then
                if match then return nil end
                match = change
            end
        end
        if not match then return nil end
        -- Another unexplained line as close to the death could be its line.
        for _, other in ipairs(lines) do
            if other ~= line and not other.resolved and math.abs(match.time - other.time) <= DEATH_WINDOW then
                return nil
            end
        end
        match.claims[line.frame] = 1
        return config.FormatChange(match)
    end

    local function IsBatchTime(line)
        local entered = battle.enteredAt
        if not entered then return false end
        local since = line.time - entered
        for _, batchTime in ipairs(HiddenLines.BATCH_TIMES) do
            if math.abs(since - batchTime) <= BATCH_SLACK then return true end
        end
        return false
    end

    local function ClaimBattleNotice(line, done, now)
        if not (config.IsForever and config.IsForever()) then return nil end
        local entered, started = battle.enteredAt, battle.startedAt
        if entered and not done.enter and now - line.time >= START_NOTICE_GRACE then
            local since = line.time - entered
            if since >= -SAME_MOMENT and since <= ENTER_NOTICE_WINDOW then
                done.enter = true
                return ""
            end
        end
        -- A join landing on a batch tick gets the moment to claim its line first.
        if now - line.time >= BATCH_GRACE and IsBatchTime(line) then
            return ""
        end
        if started and not done.start and now - line.time >= START_NOTICE_GRACE then
            local since = line.time - started
            if since >= 0 and since <= START_NOTICE_WINDOW then
                done.start = true
                return ""
            end
        end
    end

    local function Resolve(frame, lines, changes, queueChanges, now)
        table.sort(lines, function(a, b)
            if a.time ~= b.time then return a.time < b.time end
            return a.order < b.order
        end)
        local done = doneByFrame[frame] or {}
        doneByFrame[frame] = done

        local function Apply(line, text)
            if text == nil then return end
            line.resolved = true
            pcall(Rewrite, line, text)
        end

        local systemLines, skillLines, miscLines = {}, {}, {}
        for _, line in ipairs(lines) do
            local kindLines = (line.kind == "skill" and skillLines) or (line.kind == "misc" and miscLines)
                or (line.kind ~= "chat" and systemLines)
            if kindLines then kindLines[#kindLines + 1] = line end
        end

        -- The rules in order of precedence: the most certain claims first.
        ResolveChatLines(lines)
        ResolveSkillLines(frame, skillLines, Apply)
        ResolveOwnDeath(frame, systemLines, miscLines, Apply, now)
        ResolveGroupSetup(frame, systemLines, Apply)
        ResolveQueueChanges(frame, systemLines, queueChanges, Apply)
        ResolveRosterChanges(frame, systemLines, changes, Apply)
        for _, line in ipairs(systemLines) do
            if not line.resolved then Apply(line, ClaimDeath(line, systemLines, changes)) end
        end
        for _, line in ipairs(systemLines) do
            if not line.resolved then Apply(line, ClaimBattleNotice(line, done, now)) end
        end

        local kept = {}
        for _, line in ipairs(lines) do
            if not line.resolved and now - line.time <= LINE_MAX_AGE then
                kept[#kept + 1] = line
            end
        end
        pendingByFrame[frame] = kept
    end

    function api.Update()
        if not (config.IsActive and config.IsActive()) then
            pendingByFrame = setmetatable({}, { __mode = "k" })
            return
        end
        local now = Now()
        Collect(now)
        local changes = config.GetChanges and config.GetChanges() or {}
        -- A queue change can only take a line the history held when it was
        -- first seen.
        local queueChanges = config.GetQueueChanges and config.GetQueueChanges() or {}
        for _, change in ipairs(queueChanges) do
            change.seenOrder = change.seenOrder or order
        end
        if battle.groupSetup then
            battle.groupSetup.seenOrder = battle.groupSetup.seenOrder or order
        end
        for frame, lines in pairs(pendingByFrame) do
            if lines[1] then Resolve(frame, lines, changes, queueChanges, now) end
        end
    end

    local function IsFromBattlegroundChatFilter()
        if type(debugstack) ~= "function" then return false end
        local ok, stack = pcall(debugstack, 1, 30, 0)
        if not ok or IsSecret(stack) or type(stack) ~= "string" then return false end
        return stack:find("BattlegroundChatFilters", 1, true) ~= nil
    end

    -- Called from the chat window's AddMessage hook with a hidden line just added.
    function api.OnHiddenLineAdded(frame)
        if not (config.IsActive and config.IsActive()) then return end
        local before = order
        local now = Now()
        Collect(now, frame)
        -- A hidden chat line is rebuilt before the window redraws.
        ResolveChatLines(pendingByFrame[frame] or {})

        -- In a battleground's first minute, Blizzard's batched join lines.
        local entered = battle.enteredAt
        if not entered or now - entered > BATCH_PERIOD then return end
        if not (config.IsForever and config.IsForever()) then return end
        local added
        for _, line in ipairs(pendingByFrame[frame] or {}) do
            if line.order > before and line.kind == "system" then
                -- More than one new line: leave them to the timing rules.
                if added then return end
                added = line
            end
        end
        if added and IsFromBattlegroundChatFilter() then
            added.resolved = true
            pcall(Rewrite, added, "")
        end
    end

    -- Rewrites, in each chat window, the oldest shown line that reads
    -- `expected` and was added at or after `since`: a line the chat filter
    -- styled before its cause was known. True when a window had one.
    function api.RenameShownLine(expected, text, since)
        if not config.GetFrames then return false end
        local renamed = false
        for _, frame in ipairs(config.GetFrames()) do
            local oldest, oldestTime
            for _, entry in ipairs(GetElements(frame) or {}) do
                local time = type(entry) == "table" and entry.timestamp
                if type(time) == "number" and not IsSecret(time) and time >= since
                    and not IsSecret(entry.message) and entry.message == expected
                    and (not oldestTime or time < oldestTime) then
                    oldest, oldestTime = entry, time
                end
            end
            if oldest then
                local ok, rewritten = pcall(RewriteEntry, frame, oldest, text, expected)
                renamed = renamed or (ok and rewritten)
            end
        end
        return renamed
    end

    -- Whether a hidden line still waits for its cause.
    function api.HasPending()
        for _, lines in pairs(pendingByFrame) do
            for _, line in ipairs(lines) do
                if not line.resolved then return true end
            end
        end
        return false
    end

    function api.EnteredBattleground()
        battle = { enteredAt = Now() }
        doneByFrame = setmetatable({}, { __mode = "k" })
    end

    -- Called on GROUP_JOINED with the lines the game sent as it formed the
    -- group, styled, in its order; nil when one of them can't be told.
    function api.GroupJoined(texts)
        if type(texts) ~= "table" or not texts[1] then return end
        if not (config.IsForever and config.IsForever()) then return end
        local entered, now = battle.enteredAt, Now()
        if not entered or now - entered > GROUP_SETUP_WINDOW then return end
        battle.groupSetup = { time = now, texts = texts }
    end

    function api.PlayerDied()
        ownDeath = { time = Now() }
    end

    function api.BattleBegan()
        battle.startedAt = Now()
    end

    function api.LeftBattleground()
        battle = {}
    end

    return api
end
