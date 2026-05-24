--[[ Carpenter - blank Lua error tracer ]]
local MAX_LOG_ENTRIES = 8
local installed = false
local previousHandler
local handling = false
local lastNoticeAt = 0

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
