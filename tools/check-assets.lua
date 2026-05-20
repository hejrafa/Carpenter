#!/usr/bin/env lua
-- Checks settings preview artwork and direct addon artwork for missing or unused files.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

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

local function basename(path)
    return path:match("([^/]+)$") or path
end

local function stripExtension(path)
    return (basename(path):gsub("%.[^.]+$", ""))
end

local function relative(path)
    local prefix = repo .. "/"
    if path:sub(1, #prefix) == prefix then
        return path:sub(#prefix + 1)
    end
    return path
end

local function listFiles(command)
    local files = {}
    local pipe = assert(io.popen(command, "r"))
    for path in pipe:lines() do
        files[#files + 1] = path
    end
    pipe:close()
    table.sort(files)
    return files
end

local function collectFiles(path, expression)
    return listFiles("find " .. shellQuote(path) .. " " .. expression .. " -print")
end

local function collectRuntimeText()
    local files = collectFiles(
        repo,
        [[-path ]] .. shellQuote(repo .. "/.git") ..
        [[ -prune -o -path ]] .. shellQuote(repo .. "/tools") ..
        [[ -prune -o \( -name '*.lua' -o -name '*.toc' -o -name '*.xml' \)]]
    )
    local chunks = {}
    for _, path in ipairs(files) do
        chunks[#chunks + 1] = readFile(path)
    end
    return table.concat(chunks, "\n")
end

local function collectSettingsImageCalls()
    local used = {}
    local text = readFile(repo .. "/Modules/ConfigOptions.lua")
    for filename in text:gmatch("GetSettingsImage%(%s*\"([^\"]+)\"%s*%)") do
        used[filename] = true
    end
    return used
end

local function collectRetailImageTargets()
    local targets = {}
    local text = readFile(repo .. "/config.lua")
    local block = text:match("local RETAIL_SETTINGS_IMAGES = %b{}") or ""
    for _, target in block:gmatch("%[\"([^\"]+)\"%]%s*=%s*\"([^\"]+)\"") do
        targets[target] = true
    end
    for filename in block:gmatch("%[\"([^\"]+)\"%]%s*=%s*true") do
        targets[filename] = true
    end
    return targets
end

local function sortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local imageFiles = collectFiles(repo .. "/Art", [[-type f \( -iname '*.png' -o -iname '*.tga' -o -iname '*.blp' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \)]])
local classicFiles = {}
local retailFiles = {}
local directFiles = {}

for _, path in ipairs(imageFiles) do
    local rel = relative(path)
    if rel:match("^Art/Settings/Classic/") then
        classicFiles[basename(path)] = rel
    elseif rel:match("^Art/Settings/Retail/") then
        retailFiles[basename(path)] = rel
    else
        directFiles[#directFiles + 1] = rel
    end
end

local usedClassic = collectSettingsImageCalls()
local usedRetail = collectRetailImageTargets()
local runtimeText = collectRuntimeText()
local failures = {}

for filename in pairs(usedClassic) do
    if not classicFiles[filename] then
        failures[#failures + 1] = "missing Classic settings image: Art/Settings/Classic/" .. filename
    end
end

for filename, path in pairs(classicFiles) do
    if not usedClassic[filename] then
        failures[#failures + 1] = "unused Classic settings image: " .. path
    end
end

for filename in pairs(usedRetail) do
    if not retailFiles[filename] then
        failures[#failures + 1] = "missing Retail settings image: Art/Settings/Retail/" .. filename
    end
end

for filename, path in pairs(retailFiles) do
    if not usedRetail[filename] then
        failures[#failures + 1] = "unused Retail settings image: " .. path
    end
end

for _, path in ipairs(directFiles) do
    local filename = basename(path)
    local stem = stripExtension(path)
    if not runtimeText:find(filename, 1, true) and not runtimeText:find(stem, 1, true) then
        failures[#failures + 1] = "unused addon artwork: " .. path
    end
end

table.sort(failures)
if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print(
    "asset references: " ..
    tostring(#sortedKeys(usedClassic)) .. " Classic previews, " ..
    tostring(#sortedKeys(usedRetail)) .. " Retail overrides, " ..
    tostring(#directFiles) .. " direct artwork files"
)
