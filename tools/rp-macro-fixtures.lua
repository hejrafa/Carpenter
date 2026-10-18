#!/usr/bin/env lua
-- Offline checks for the hidden RP macros page and installer.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local function read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function assertContains(text, needle, label)
    assert(text:find(needle, 1, true), label .. " is missing")
end

local ns = { Private = {} }
local chunk = assert(loadfile(repo .. "/Modules/RPMacros.lua"))
chunk("Carpenter", ns)

local rp = assert(ns.Private.RPMacros, "RP macros module did not load")
local byName = {}
for _, macro in ipairs(rp.Macros) do
    assert(type(macro.icon) == "number", macro.name .. " needs an icon file ID")
    assert(#macro.name <= 16, macro.name .. " is longer than a macro name allows")
    assert(#macro.body <= 255, macro.name .. " is longer than a macro body allows")
    byName[macro.name] = macro
end
assert(byName.Bow and byName.Bow.body == "/bow" and byName.Bow.icon == 237573, "Bow macro changed")
assert(byName["1v1"] and byName["1v1"].body == "/whistle\n/s 1v1" and byName["1v1"].icon == 132269, "1v1 macro changed")
assert(byName.Roll and byName.Roll.body == "/crack\n/roll" and byName.Roll.icon == 237284, "Roll ritual macro changed")
assert(#rp.Macros == 10, "expected 10 RP macros")

local inCombat = false
local macros = {}
local accountCount = 0
InCombatLockdown = function() return inCombat end
MAX_ACCOUNT_MACROS = 2
GetNumMacros = function() return accountCount, 0 end
GetMacroIndexByName = function(name)
    for index, macro in pairs(macros) do
        if macro.name == name then return index end
    end
    return 0
end
CreateMacro = function(name, icon, body, perCharacter)
    assert(perCharacter == nil, "RP macros must be account-wide")
    accountCount = accountCount + 1
    macros[accountCount] = { name = name, icon = icon, body = body }
    return accountCount
end
EditMacro = function(index, name, icon, body)
    macros[index] = { name = name, icon = icon, body = body }
    return index
end
DeleteMacro = function(index)
    macros[index] = nil
    accountCount = accountCount - 1
end

local ok, result = rp.Install(byName.Bow)
assert(ok and result == "created", "installer did not create the Bow macro")
assert(macros[1].icon == 237573 and macros[1].body == "/bow", "installer wrote the wrong Bow macro")

macros[1].body = "/wave"
ok, result = rp.Install(byName.Bow)
assert(ok and result == "updated" and macros[1].body == "/bow", "installer did not update the existing Bow macro")
assert(accountCount == 1, "updating a macro created a duplicate")

accountCount = MAX_ACCOUNT_MACROS
ok, result = rp.Install(byName["1v1"])
assert(ok == false and result == "full", "installer must stop when General Macros are full")
accountCount = 1

inCombat = true
ok, result = rp.Install(byName["1v1"])
assert(ok == false and result == "combat", "installer must refuse combat-time macro changes")
ok, result = rp.Remove(byName.Bow)
assert(ok == false and result == "combat", "remover must refuse combat-time macro changes")
inCombat = false

assert(rp.IsInstalled(byName.Bow), "Bow should read as installed")
assert(not rp.IsInstalled(byName["1v1"]), "1v1 should read as not installed")
ok, result = rp.Remove(byName.Bow)
assert(ok and result == "removed" and not rp.IsInstalled(byName.Bow), "unchecking did not remove the Bow macro")
ok, result = rp.Remove(byName.Bow)
assert(ok and result == "removed", "removing a missing macro should be a no-op")

for _, toc in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assertContains(read(toc), "Modules\\RPMacros.lua", toc .. " RP macros load entry")
end

local config = read("config.lua")
assertContains(config, "if installed then install = RPMacros.Install end", "RP macro checkbox install/remove")
assertContains(config, "AddToggle(macro.name", "RP macro checkbox rows")
assert(not config:find("CP_RPMacroInstall", 1, true), "RP macros are installed by checkbox, not a button")

print("rp macro fixtures: passed")
