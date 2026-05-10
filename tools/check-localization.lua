#!/usr/bin/env lua
-- Checks that every locale defines the same L.* keys as enUS.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local locales = { "deDE", "esES", "frFR", "ptBR", "ruRU" }

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

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("localization parity: " .. tostring(#sortedKeys(base)) .. " keys across " .. tostring(#locales + 1) .. " locales")
