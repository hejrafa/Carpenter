#!/usr/bin/env lua
-- Checks that every locale defines the same L.* keys as enUS and that
-- statically referenced localization keys exist in enUS.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local locales = { "deDE", "esES", "frFR", "ptBR", "ruRU" }

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
