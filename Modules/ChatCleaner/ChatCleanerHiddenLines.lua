--[[ Carpenter - ChatCleaner hidden lines ]]
-- WoW Forever hides system lines from addons during chat messaging lockdown,
-- which covers whole battlegrounds and fights in instances. Its chat filters
-- only call an addon that can read the line, so these can't be styled before
-- they are added. They still land in each chat window's history with the time
-- they were added, so they are found there and rewritten when their cause is
-- known:
--   * a join or departure, from the roster change it comes with (at most a
--     quarter second before it in three battleground logs). The nearest line
--     gets the name; battlegrounds send two lines per change, and the other,
--     or Blizzard's batched line landing beside it, is emptied.
--   * a group member's death, when exactly one death and one line meet.
--   * "Notify system has been disabled/enabled": the first hidden line right
--     after entering a battleground, and right after it begins.
--   * Blizzard's batched "has joined the battle" lines in a battleground's
--     first minute, which repeat joins already shown. They print every 5 s
--     from 30 s after entering, and are checked just after each tick.
-- Anything else stays as the game wrote it. Lines are edited with
-- TransformMessages only: removing them would taint the chat history.
local _, ns = ...
ns.Private = ns.Private or {}

local HiddenLines = {}
ns.Private.ChatCleanerHiddenLines = HiddenLines

HiddenLines.LINE_MAX_AGE = 3
HiddenLines.START_NOTICE_GRACE = 0.6
HiddenLines.BATCH_GRACE = 0.6
HiddenLines.BATCH_TIMES = { 30, 35, 40, 45, 50, 55, 60 }

local LINE_MAX_AGE = HiddenLines.LINE_MAX_AGE
local LINE_BEFORE_CHANGE = 0.5
local LINE_AFTER_CHANGE = 0.3
local DEATH_WINDOW = 1.0
local ENTER_NOTICE_WINDOW = 1.5
local START_NOTICE_WINDOW = 5
local START_NOTICE_GRACE = HiddenLines.START_NOTICE_GRACE
local BATCH_SLACK = 0.5
local BATCH_GRACE = HiddenLines.BATCH_GRACE

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- config:
--   GetFrames()         chat windows whose lines may be edited
--   GetChanges()        recent group changes { kind, name, time }, oldest first
--   FormatChange(change)
--   IsActive()          true while lines can be hidden
--   IsForever()         battleground rules only apply on WoW Forever
function HiddenLines.Create(config)
    config = config or {}
    local api = {}
    local seen = setmetatable({}, { __mode = "k" })
    local pendingByFrame = setmetatable({}, { __mode = "k" })
    local doneByFrame = setmetatable({}, { __mode = "k" })
    local battle = {}
    local order = 0

    local function Now()
        return GetTime and GetTime() or 0
    end

    local function SystemTypeID()
        local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
        return info and info.id
    end

    local function GetElements(frame)
        local buffer = frame and frame.historyBuffer
        local elements = buffer and buffer.elements
        if type(elements) == "table" then return elements end
    end

    local function IsHiddenSystemLine(entry, systemID, now)
        local time, extra = entry.timestamp, entry.extraData
        if type(time) ~= "number" or IsSecret(time) or now - time > LINE_MAX_AGE then return false end
        if not IsSecret(entry.message) or type(extra) ~= "table" then return false end
        local typeID = extra[1]
        return not IsSecret(typeID) and typeID == systemID
    end

    -- Hidden system lines added since the last look.
    local function Collect(now)
        local systemID = SystemTypeID()
        if not systemID or not config.GetFrames then return end
        for _, frame in ipairs(config.GetFrames()) do
            local elements = GetElements(frame)
            if elements then
                for _, entry in ipairs(elements) do
                    if type(entry) == "table" and not seen[entry] then
                        seen[entry] = true
                        if IsHiddenSystemLine(entry, systemID, now) then
                            order = order + 1
                            local lines = pendingByFrame[frame] or {}
                            pendingByFrame[frame] = lines
                            lines[#lines + 1] = { frame = frame, entry = entry, time = entry.timestamp, order = order }
                        end
                    end
                end
            end
        end
    end

    -- The history keeps lines in its own order; TransformMessages walks that
    -- same array, so the line is found by its place there.
    local function Rewrite(line, text)
        local frame, target = line.frame, line.entry
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
            return call == position and IsSecret(message)
        end, function(_, ...)
            rewritten = true
            return text, ...
        end)
        return rewritten
    end

    local function Claims(change, frame)
        change.claims = change.claims or setmetatable({}, { __mode = "k" })
        return change.claims[frame] or 0
    end

    -- Each change takes the lines nearest to it: the first gets the name, a
    -- second is emptied.
    local function ResolveRosterChanges(frame, lines, changes, Apply)
        for _, change in ipairs(changes) do
            if change.kind == "joined" or change.kind == "left" then
                local claimed = Claims(change, frame)
                local candidates = {}
                for _, line in ipairs(lines) do
                    local delta = change.time - line.time
                    if not line.resolved and delta >= -LINE_AFTER_CHANGE and delta <= LINE_BEFORE_CHANGE then
                        candidates[#candidates + 1] = { line = line, distance = math.abs(delta) }
                    end
                end
                table.sort(candidates, function(a, b)
                    if a.distance ~= b.distance then return a.distance < b.distance end
                    return a.line.order < b.line.order
                end)
                for _, candidate in ipairs(candidates) do
                    if claimed >= 2 then break end
                    Apply(candidate.line, claimed == 0 and config.FormatChange(change) or "")
                    claimed = claimed + 1
                    change.claims[frame] = claimed
                end
            end
        end
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
        if entered and not done.enter then
            local since = line.time - entered
            if since >= -0.2 and since <= ENTER_NOTICE_WINDOW then
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

    local function Resolve(frame, lines, changes, now)
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

        ResolveRosterChanges(frame, lines, changes, Apply)
        for _, line in ipairs(lines) do
            if not line.resolved then Apply(line, ClaimBattleNotice(line, done, now)) end
        end
        for _, line in ipairs(lines) do
            if not line.resolved then Apply(line, ClaimDeath(line, lines, changes)) end
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
        for frame, lines in pairs(pendingByFrame) do
            if lines[1] then Resolve(frame, lines, changes, now) end
        end
    end

    function api.HasPending()
        for _, lines in pairs(pendingByFrame) do
            if lines[1] then return true end
        end
        return false
    end

    function api.EnteredBattleground()
        battle = { enteredAt = Now() }
        doneByFrame = setmetatable({}, { __mode = "k" })
    end

    function api.BattleBegan()
        battle.startedAt = Now()
    end

    function api.LeftBattleground()
        battle = {}
    end

    return api
end
