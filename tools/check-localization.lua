#!/usr/bin/env lua
-- Checks that every locale defines the same L.* keys as enUS, keeps each
-- string's format specifiers, {tags}, and line breaks, and that statically
-- referenced localization keys exist in enUS.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local locales = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function readFile(path)
    local file, err = io.open(path, "rb")
    if not file then error(err) end
    local text = file:read("*a")
    file:close()
    return text
end

local function collectKeys(path)
    local keys = {}
    local text = readFile(path)
    for key in text:gmatch("L%.([A-Z0-9_]+)%s*=") do
        keys[key] = true
    end
    return keys
end

local function collectValues(path)
    local values = {}
    for line in readFile(path):gmatch("[^\n]+") do
        local key, value = line:match('^L%.([A-Z0-9_]+)%s*=%s*"(.*)"%s*$')
        if key then
            values[key] = value
        end
    end
    return values
end

-- What a translation must carry over unchanged: format specifiers in order,
-- plus the count of each {tag} and line break.
local function placeholderSignature(value)
    local parts = {}
    for spec in value:gmatch("%%[%d%.%-]*[sdfi]") do
        parts[#parts + 1] = spec
    end
    for _, token in ipairs({ "{hl}", "{/hl}", "{body}", "{name}", "\\n", "|n" }) do
        local count, start = 0, 1
        while true do
            local first, last = value:find(token, start, true)
            if not first then break end
            count, start = count + 1, last + 1
        end
        parts[#parts + 1] = token .. "x" .. count
    end
    return table.concat(parts, " ")
end

local function collectLuaFiles()
    local files = {}
    local command = table.concat({
        "find",
        shellQuote(repo),
        "-path",
        shellQuote(repo .. "/.git"),
        "-prune",
        "-o",
        "-path",
        shellQuote(repo .. "/Localization"),
        "-prune",
        "-o",
        "-path",
        shellQuote(repo .. "/tools"),
        "-prune",
        "-o",
        "-name '*.lua'",
        "-print",
    }, " ")
    local pipe = assert(io.popen(command, "r"))
    for path in pipe:lines() do
        files[#files + 1] = path
    end
    pipe:close()
    return files
end

local function collectStaticCodeKeys()
    local keys = {}
    local function addKey(key)
        if key and not key:match("_$") then
            keys[key] = true
        end
    end

    for _, path in ipairs(collectLuaFiles()) do
        local text = readFile(path)
        for key in text:gmatch("L%.([A-Z0-9_]+)") do
            addKey(key)
        end
        for key in text:gmatch("L%[%s*[\"']([A-Z0-9_]+)[\"']%s*%]") do
            addKey(key)
        end
        for key in text:gmatch("T%(%s*[\"']([A-Z0-9_]+)[\"']") do
            addKey(key)
        end
        for key in text:gmatch("Description%(%s*[\"']([A-Z0-9_]+)[\"']") do
            addKey(key)
        end
    end
    return keys
end

local function sortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local base = collectKeys(repo .. "/Localization/enUS.lua")
local baseValues = collectValues(repo .. "/Localization/enUS.lua")
local failures = {}

for _, locale in ipairs(locales) do
    local path = repo .. "/Localization/" .. locale .. ".lua"
    local keys = collectKeys(path)
    local missing = {}
    local extra = {}

    for key in pairs(base) do
        if not keys[key] then
            missing[#missing + 1] = key
        end
    end
    for key in pairs(keys) do
        if not base[key] then
            extra[#extra + 1] = key
        end
    end

    table.sort(missing)
    table.sort(extra)

    if #missing > 0 then
        failures[#failures + 1] = locale .. " missing: " .. table.concat(missing, ", ")
    end
    if #extra > 0 then
        failures[#failures + 1] = locale .. " extra: " .. table.concat(extra, ", ")
    end

    local values = collectValues(path)
    for _, key in ipairs(sortedKeys(baseValues)) do
        local value = values[key]
        if value and placeholderSignature(value) ~= placeholderSignature(baseValues[key]) then
            failures[#failures + 1] = locale .. " " .. key .. " placeholders differ from enUS: ["
                .. placeholderSignature(value) .. "] vs [" .. placeholderSignature(baseValues[key]) .. "]"
        end
    end

    -- Chat Cleaner swaps the leading name in these for a colored one.
    local you, youRoll, playerRoll = values.CHAT_YOU, values.CHAT_YOU_ROLL, values.CHAT_PLAYER_ROLLS_RANGE
    if you and youRoll and youRoll:sub(1, #you) ~= you then
        failures[#failures + 1] = locale .. " CHAT_YOU_ROLL must start with CHAT_YOU (\"" .. you .. "\")"
    end
    if playerRoll and playerRoll:sub(1, 2) ~= "%s" then
        failures[#failures + 1] = locale .. " CHAT_PLAYER_ROLLS_RANGE must start with the player name (%s)"
    end
end

local used = collectStaticCodeKeys()
local missingFromBase = {}
for key in pairs(used) do
    if not base[key] then
        missingFromBase[#missingFromBase + 1] = key
    end
end
table.sort(missingFromBase)
if #missingFromBase > 0 then
    failures[#failures + 1] = "enUS missing statically referenced keys: " .. table.concat(missingFromBase, ", ")
end

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("localization parity: " .. tostring(#sortedKeys(base)) .. " keys across " .. tostring(#locales + 1) .. " locales; static key usage covered")
