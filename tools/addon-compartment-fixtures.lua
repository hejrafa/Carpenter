#!/usr/bin/env lua
-- Verifies Carpenter does not advertise callbacks while disabled and instead
-- registers a callable compartment entry when its Lua is loaded.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local function ReadFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

for _, tocName in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc" }) do
    local toc = ReadFile(repo .. "/" .. tocName):gsub("\\", "/")
    assert(not toc:find("AddonCompartmentFunc", 1, true), tocName .. " must not advertise callbacks while Carpenter is disabled")
    assert(not toc:find("AddonCompartmentFuncOnEnter", 1, true), tocName .. " must not advertise an optional hover callback")
    assert(not toc:find("AddonCompartmentFuncOnLeave", 1, true), tocName .. " must not advertise an optional leave callback")

    local callbackPosition = assert(toc:find("Modules/AddonCompartment.lua", 1, true), tocName .. " must load the callback module")
    local configPosition = assert(toc:find("config.lua", 1, true), tocName .. " must load the settings UI")
    assert(callbackPosition < configPosition, tocName .. " must register the callback before loading the settings UI")
end

local openCount = 0
local registeredInfo
Carpenter_OpenConfig = function()
    openCount = openCount + 1
end
C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Title" then return "Carpenter" end
        if field == "IconTexture" then return "Interface\\AddOns\\Carpenter\\Art\\Icons\\Carpenter_Logo" end
    end,
}
AddonCompartmentFrame = {
    RegisterAddon = function(_, info)
        assert(not registeredInfo, "compartment entry must only be registered once")
        registeredInfo = info
    end,
}

local chunk = assert(loadfile(repo .. "/Modules/AddonCompartment.lua"))
chunk("Carpenter", {})

assert(type(registeredInfo) == "table", "enabled Carpenter must register a compartment entry")
assert(registeredInfo.text == "Carpenter", "compartment entry must use the addon title")
assert(registeredInfo.notCheckable == true, "compartment entry must not render a checkmark")
assert(type(registeredInfo.func) == "function", "compartment entry must include a click handler")
assert(registeredInfo.funcOnEnter == nil, "compartment entry must not include a hover callback")
assert(registeredInfo.funcOnLeave == nil, "compartment entry must not include a leave callback")

registeredInfo.func(nil, { buttonName = "LeftButton" })
assert(openCount == 1, "left click should open Carpenter settings")

registeredInfo.func(nil, { buttonName = "RightButton" })
assert(openCount == 1, "right click should not open Carpenter settings")

print("addon-compartment fixtures: passed")
