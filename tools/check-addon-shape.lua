#!/usr/bin/env lua
-- Checks cross-file addon metadata that is easy to drift during maintenance.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local tocs = { "Carpenter.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }

-- Saved state tables that intentionally live inside CarpenterDB but are not
-- settings toggles.
local stateKeys = {
    autoTrackQuestWatches = true,
    blankLuaErrorTraceLog = true,
    explorerModeChatWindowRepairVersion = true,
    noObjectiveQuestWatches = true,
}

-- Kept in defaults/settings definitions for history, but currently hidden by
-- feature support.
local dormantOptionKeys = {
    hideGroupIndicatorEnabled = true,
}

local failures = {}

local function fail(message)
    failures[#failures + 1] = message
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

local function fileExists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

local function relative(path)
    local prefix = repo .. "/"
    if path:sub(1, #prefix) == prefix then
        return path:sub(#prefix + 1)
    end
    return path
end

local function normalize(path)
    return (path:gsub("\\", "/"))
end

local function countKeys(map)
    local count = 0
    for _ in pairs(map) do
        count = count + 1
    end
    return count
end

local function addKey(map, key, source, duplicates)
    if map[key] and duplicates then
        duplicates[#duplicates + 1] = source .. " duplicates key: " .. key
    end
    map[key] = true
end

local function collectFiles(command)
    local files = {}
    local pipe = assert(io.popen(command, "r"))
    for path in pipe:lines() do
        files[#files + 1] = path
    end
    pipe:close()
    table.sort(files)
    return files
end

local function collectRuntimeFiles()
    local files = {}
    local function add(path)
        files[normalize(relative(path))] = true
    end

    for _, dir in ipairs({ "Core", "Modules", "Localization" }) do
        local command = "find " .. shellQuote(repo .. "/" .. dir) .. " -type f \\( -name '*.lua' -o -name '*.xml' \\) -print"
        for _, path in ipairs(collectFiles(command)) do
            add(path)
        end
    end

    for _, path in ipairs({ "config.lua", "SpellData.lua" }) do
        add(repo .. "/" .. path)
    end

    return files
end

local function collectTocReferences()
    local expectedVersion
    local references = {}

    for _, toc in ipairs(tocs) do
        local path = repo .. "/" .. toc
        local text = readFile(path)
        local versions = {}
        local interfaces = {}
        local seenInToc = {}

        for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
            local line = rawLine:gsub("\r", ""):match("^%s*(.-)%s*$")

            local version = line:match("^## Version:%s*(.-)%s*$")
            if version then
                versions[#versions + 1] = version
            end

            local interface = line:match("^## Interface:%s*(.-)%s*$")
            if interface then
                interfaces[#interfaces + 1] = interface
            end

            if line ~= "" and line:sub(1, 1) ~= "#" then
                local runtimePath = normalize(line)
                if seenInToc[runtimePath] then
                    fail(toc .. " lists " .. runtimePath .. " more than once")
                end
                seenInToc[runtimePath] = true

                if not fileExists(repo .. "/" .. runtimePath) then
                    fail(toc .. " references missing file: " .. runtimePath)
                end
                references[runtimePath] = true
            end
        end

        if #versions ~= 1 then
            fail(toc .. " must declare exactly one ## Version")
        elseif not versions[1]:match("^%d+%.%d+%.%d+$") then
            fail(toc .. " version must use MAJOR.MINOR.PATCH: " .. versions[1])
        elseif expectedVersion and versions[1] ~= expectedVersion then
            fail(toc .. " version is " .. versions[1] .. ", expected " .. expectedVersion)
        else
            expectedVersion = expectedVersion or versions[1]
        end

        if #interfaces ~= 1 then
            fail(toc .. " must declare exactly one ## Interface")
        end
    end

    return references
end

local function collectDefaults()
    local text = readFile(repo .. "/Core/Carpenter.lua")
    local block = text:match("local%s+defaults%s*=%s*(%b{})")
    local keys = {}
    local duplicates = {}

    if not block then
        fail("Core/Carpenter.lua does not expose a local defaults table")
        return keys
    end

    for key in block:gmatch("([%a_][%w_]*)%s*=") do
        addKey(keys, key, "Core/Carpenter.lua defaults", duplicates)
    end

    for _, message in ipairs(duplicates) do
        fail(message)
    end

    return keys
end

local function collectConfigOptionKeys()
    local text = readFile(repo .. "/Modules/ConfigOptions.lua")
    local keys = {}
    local duplicates = {}

    for key in text:gmatch("key%s*=%s*[\"']([%a_][%w_]*)[\"']") do
        addKey(keys, key, "Modules/ConfigOptions.lua", duplicates)
    end

    for _, message in ipairs(duplicates) do
        fail(message)
    end

    return keys
end

local function collectFeatureSupportKeys()
    local text = readFile(repo .. "/Core/Compatibility.lua")
    local keys = {}

    for key in text:gmatch("([%a_][%w_]*)%s*=%s*true") do
        keys[key] = true
    end
    for key in text:gmatch("([%a_][%w_]*)%s*=%s*false") do
        keys[key] = true
    end

    return keys
end

local function collectLuaRuntimeText()
    local chunks = {}
    for runtimePath in pairs(collectRuntimeFiles()) do
        if runtimePath:match("%.lua$") then
            chunks[#chunks + 1] = readFile(repo .. "/" .. runtimePath)
        end
    end
    return table.concat(chunks, "\n")
end

local function collectPatternKeys(text, pattern)
    local keys = {}
    for key in text:gmatch(pattern) do
        keys[key] = true
    end
    return keys
end

local function mergeKeys(target, source)
    for key in pairs(source) do
        target[key] = true
    end
end

local function requireKnownKeys(label, keys, known, allowlist)
    local unknown = {}
    allowlist = allowlist or {}
    for key in pairs(keys) do
        if not known[key] and not allowlist[key] then
            unknown[#unknown + 1] = key
        end
    end
    table.sort(unknown)
    if #unknown > 0 then
        fail(label .. " references keys without defaults: " .. table.concat(unknown, ", "))
    end
end

local tocReferences = collectTocReferences()
local runtimeFiles = collectRuntimeFiles()
local defaults = collectDefaults()
local optionKeys = collectConfigOptionKeys()
local featureSupportKeys = collectFeatureSupportKeys()
local runtimeText = collectLuaRuntimeText()

local registeredFeatureKeys = collectPatternKeys(runtimeText, "Carpenter:RegisterFeature%s*%(%s*[\"']([%a_][%w_]*)[\"']")
local isEnabledKeys = collectPatternKeys(runtimeText, ":IsEnabled%s*%(%s*[\"']([%a_][%w_]*)[\"']")
local savedVariableKeys = collectPatternKeys(runtimeText, "CarpenterDB%.([%a_][%w_]*)")
mergeKeys(savedVariableKeys, collectPatternKeys(runtimeText, "CarpenterDB%[%s*[\"']([%a_][%w_]*)[\"']%s*%]"))

for runtimePath in pairs(runtimeFiles) do
    if not tocReferences[runtimePath] then
        fail("runtime file is not referenced by any TOC: " .. runtimePath)
    end
end

requireKnownKeys("config options", optionKeys, defaults)
requireKnownKeys("feature support", featureSupportKeys, defaults)
requireKnownKeys("registered features", registeredFeatureKeys, defaults)
requireKnownKeys("IsEnabled calls", isEnabledKeys, defaults)
requireKnownKeys("saved-variable reads/writes", savedVariableKeys, defaults, stateKeys)

local unsupportedOptions = {}
for key in pairs(optionKeys) do
    if not featureSupportKeys[key] and not dormantOptionKeys[key] then
        unsupportedOptions[#unsupportedOptions + 1] = key
    end
end
table.sort(unsupportedOptions)
if #unsupportedOptions > 0 then
    fail("config options have no feature-support entry: " .. table.concat(unsupportedOptions, ", "))
end

local unsupportedRegistrations = {}
for key in pairs(registeredFeatureKeys) do
    if not featureSupportKeys[key] then
        unsupportedRegistrations[#unsupportedRegistrations + 1] = key
    end
end
table.sort(unsupportedRegistrations)
if #unsupportedRegistrations > 0 then
    fail("registered features have no feature-support entry: " .. table.concat(unsupportedRegistrations, ", "))
end

if #failures > 0 then
    table.sort(failures)
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print(
    "addon shape: " ..
    tostring(#tocs) .. " TOCs, " ..
    tostring(countKeys(runtimeFiles)) .. " runtime files, " ..
    tostring(countKeys(defaults)) .. " defaults, " ..
    tostring(countKeys(optionKeys)) .. " settings options"
)
