#!/usr/bin/env lua
-- Checks Bindings.xml against what the game needs: a section and a translated
-- name for every binding, and the function each key calls on every client.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local TOCS = { "Carpenter.toc", "Carpenter_Camelot.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }

local function read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

-- Just enough of the game to load the file that sets the names.
SlashCmdList = {}
floor = math.floor
CarpenterDB = {}
Carpenter = { Client = { isMainline = true } }
function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript() end
    return frame
end

local L = { ADDON_NAME = "Carpenter", OPTION_EXPLORER_MODE = "Entdeckermodus" }
assert(loadfile(repo .. "/Core/Carpenter.lua"))("Carpenter", { Private = {}, L = L })

assert(BINDING_HEADER_CARPENTER == "Carpenter", "the Keybindings section should be called Carpenter")
assert(BINDING_NAME_CARPENTER_EXPLORER_MODE == "Entdeckermodus", "the Explorer Mode key should use the translated option name")

local function IsDefinedOnClient(toc, functionName)
    for line in read(toc):gmatch("[^\r\n]+") do
        local path = line:gsub("\\", "/")
        if path:match("%.lua$") and read(path):find("function " .. functionName .. "(", 1, true) then
            return true
        end
    end
    return false
end

local source = read("Bindings.xml")
local count = 0
for name, category, body in source:gmatch('<Binding name="([%w_]+)" category="([%w_]+)">(.-)</Binding>') do
    count = count + 1
    assert(category == "BINDING_HEADER_CARPENTER", name .. " should be in the Carpenter section")
    assert(type(_G["BINDING_NAME_" .. name]) == "string", name .. " has no name in the Keybindings list")

    local functionName = body:match("([%a_][%w_]*)%(%)")
    assert(functionName, name .. " should call a global function")
    for _, toc in ipairs(TOCS) do
        assert(IsDefinedOnClient(toc, functionName), toc .. " doesn't load " .. functionName)
    end
end

local _, declared = source:gsub("<Binding ", "")
assert(count > 0 and count == declared, "every binding in Bindings.xml should be checked, got " .. count .. " of " .. declared)

print("keybindings fixtures: passed")
