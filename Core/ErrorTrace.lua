--[[ Carpenter - blank Lua error tracer ]]
local MAX_LOG_ENTRIES = 8
local installed = false
local previousHandler
local handling = false
local lastNoticeAt = 0
local MAX_BLOCKED_ACTION_ENTRIES = 8

local function IsEnabled()
    return CarpenterDB and CarpenterDB.blankLuaErrorTraceEnabled == true
end

local function IsBlankMessage(message)
    if message == nil then return true end
    return type(message) == "string" and message:gsub("%s+", "") == ""
end

local function AddLogEntry(message, stack)
    CarpenterDB.blankLuaErrorTraceLog = CarpenterDB.blankLuaErrorTraceLog or {}
    local log = CarpenterDB.blankLuaErrorTraceLog

    log[#log + 1] = {
        time = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime and GetTime() or ""),
        message = tostring(message or ""),
        stack = stack or "",
    }

    while #log > MAX_LOG_ENTRIES do
        table.remove(log, 1)
    end
end

local function PrintNotice()
    local now = GetTime and GetTime() or 0
    if now > 0 and (now - lastNoticeAt) < 5 then return end
    lastNoticeAt = now

    print("|cffffd200Carpenter:|r captured a blank Lua error. Run |cff80d0ff/cpblank|r to print the latest trace.")
end

local function BuildAnnotatedMessage(stack)
    return "Carpenter captured a blank Lua error.\n\n" ..
        "Run /cpblank to print the latest captured stack in chat.\n\n" ..
        (stack or "No debug stack was available.")
end

local function ErrorTraceHandler(message)
    if handling then
        if previousHandler then
            return previousHandler(message)
        end
        return
    end

    if not IsEnabled() or not IsBlankMessage(message) then
        if previousHandler then
            return previousHandler(message)
        end
        return
    end

    handling = true
    local stack = debugstack and debugstack(3, 18, 18) or "debugstack unavailable"
    AddLogEntry(message, stack)
    PrintNotice()

    local annotatedMessage = BuildAnnotatedMessage(stack)
    if previousHandler then
        local ok = pcall(previousHandler, annotatedMessage)
        handling = false
        if ok then return end
    end

    handling = false
    print(annotatedMessage)
end

local function Install()
    if installed or type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then
        return false
    end

    previousHandler = geterrorhandler()
    if previousHandler == ErrorTraceHandler then
        installed = true
        return true
    end

    seterrorhandler(ErrorTraceHandler)
    installed = true
    return true
end

local function SetEnabled(enabled)
    CarpenterDB.blankLuaErrorTraceEnabled = enabled == true
    if CarpenterDB.blankLuaErrorTraceEnabled then
        Install()
        print("|cffffd200Carpenter:|r blank Lua error tracing enabled.")
    else
        print("|cffffd200Carpenter:|r blank Lua error tracing disabled.")
    end
end

local function PrintLatestTrace()
    local log = CarpenterDB and CarpenterDB.blankLuaErrorTraceLog
    local entry = log and log[#log]
    if not entry then
        print("|cffffd200Carpenter:|r no blank Lua error trace captured yet. Use |cff80d0ff/cpblank on|r before reproducing it.")
        return
    end

    print("|cffffd200Carpenter blank Lua error|r " .. (entry.time or ""))
    print(entry.stack or "No debug stack was available.")
end

SLASH_CARPENTERBLANKERROR1 = "/cpblank"
SlashCmdList["CARPENTERBLANKERROR"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "on" or msg == "start" then
        SetEnabled(true)
    elseif msg == "off" or msg == "stop" then
        SetEnabled(false)
    elseif msg == "clear" or msg == "reset" then
        CarpenterDB.blankLuaErrorTraceLog = {}
        print("|cffffd200Carpenter:|r blank Lua error trace log cleared.")
    else
        PrintLatestTrace()
    end
end

if IsEnabled() then
    Install()
end

-- The game blames a blocked action on the last addon whose writes its own
-- code read on the way there. So each entry also keeps the way there (the
-- call stack, which the event is sent from) and every variable of the game's
-- that Carpenter's code wrote last: the reason is among those writes.
local MAX_STACK_LENGTH = 3000
local MAX_TAINTED_NAMES = 60

-- The game's tables whose fields its unit frames, menus, tooltips, popups
-- and chat read.
local SCANNED_TABLES = {
    "TargetFrame", "FocusFrame", "PlayerFrame", "PartyFrame", "GameTooltip", "UIParent", "WorldFrame",
    "UnitPopupManager", "UnitPopupMenus", "UnitPopupSharedUtil", "Menu", "MenuUtil", "EventRegistry",
    "EditModeManagerFrame", "StaticPopupDialogs", "SlashCmdList", "ChatFrame1", "GeneralDockManager",
}

-- Names and keys Carpenter owns: writing them can't taint the game's code.
local function IsOwnName(name)
    if type(name) ~= "string" then return false end
    return name:find("^_?Carpenter") ~= nil or name:find("^_?CP_") ~= nil or name:find("^I?s?CP[A-Z]") ~= nil
        or name:find("CARPENTER") ~= nil
end

local function IsCarpenterTaint(taint, addonName)
    return taint == addonName or taint == "Carpenter"
end

local function FindTaintedState(addonName)
    if type(issecurevariable) ~= "function" then return nil end
    local found = {}
    local function Add(name)
        if #found < MAX_TAINTED_NAMES then found[#found + 1] = name end
    end
    for name in pairs(_G) do
        if type(name) == "string" and not IsOwnName(name) then
            local ok, secure, taint = pcall(issecurevariable, name)
            if ok and not secure and IsCarpenterTaint(taint, addonName) then Add(name) end
        end
    end
    for _, tableName in ipairs(SCANNED_TABLES) do
        local tbl = rawget(_G, tableName)
        if type(tbl) == "table" then
            for key in pairs(tbl) do
                if type(key) == "string" and not IsOwnName(key) then
                    local ok, secure, taint = pcall(issecurevariable, tbl, key)
                    if ok and not secure and IsCarpenterTaint(taint, addonName) then Add(tableName .. "." .. key) end
                end
            end
        end
    end
    return found
end

local function CaptureStack()
    if type(debugstack) ~= "function" then return nil end
    local ok, stack = pcall(debugstack, 3)
    if not ok or type(stack) ~= "string" then return nil end
    return stack:sub(1, MAX_STACK_LENGTH)
end

local function AddBlockedAction(event, action, addonName)
    if not CarpenterDB then return end
    CarpenterDB.blockedActionLog = CarpenterDB.blockedActionLog or {}
    local log = CarpenterDB.blockedActionLog
    local okTainted, tainted = pcall(FindTaintedState, addonName)
    log[#log + 1] = {
        time = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime and GetTime() or ""),
        event = event,
        action = tostring(action or "unknown"),
        stack = CaptureStack(),
        tainted = okTainted and tainted or nil,
    }
    while #log > MAX_BLOCKED_ACTION_ENTRIES do
        table.remove(log, 1)
    end
end

local blockedActionFrame = CreateFrame("Frame")
blockedActionFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
blockedActionFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockedActionFrame:SetScript("OnEvent", function(_, event, addon, action)
    local addonName = Carpenter and Carpenter.AddonName or "Carpenter"
    if addon ~= addonName and addon ~= "Carpenter" then return end
    AddBlockedAction(event, action, addonName)
end)

SLASH_CARPENTERBLOCKEDACTION1 = "/cpblocked"
SlashCmdList["CARPENTERBLOCKEDACTION"] = function()
    local log = CarpenterDB and CarpenterDB.blockedActionLog
    local entry = log and log[#log]
    if not entry then
        print("|cffffd200Carpenter:|r no blocked action has been captured this session.")
        return
    end
    print(string.format("|cffffd200Carpenter blocked action|r %s: %s (%s)",
        entry.time or "", entry.action or "unknown", entry.event or "unknown"))
end
