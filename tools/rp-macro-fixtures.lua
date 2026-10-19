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

-- Bags and gear for the fishing macro. The module looks these APIs up when it
-- loads, so they exist first.
local POLES = {
    [6256] = "Fishing Pole",
    [6365] = "Strong Fishing Pole",
    [19022] = "Nat Pagle's Extreme Angler FC-5000",
    [99001] = "Shiny New Pole",
    [99002] = "Shinier New Pole",
}
local SWORD = 2132
local bags, mainHand = {}, SWORD
NUM_BAG_SLOTS = 4
GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end
GetContainerItemID = function(bag, slot) return bags[bag] and bags[bag][slot] end
GetContainerItemLink = function() return nil end
GetInventoryItemID = function(_, slot) return slot == 16 and mainHand or nil end
GetItemInfoInstant = function(itemID)
    if POLES[itemID] then return itemID, "Weapon", "Fishing Poles", "INVTYPE_2HWEAPON", 0, 2, 20 end
    if itemID == SWORD then return itemID, "Weapon", "One-Handed Swords", "INVTYPE_WEAPON", 0, 2, 7 end
end
GetItemInfo = function(itemID)
    local levels = { [99001] = 40, [99002] = 50 }
    return POLES[itemID], nil, 1, levels[itemID] or 10
end
GetSpellInfo = function(spellID) return spellID == 7620 and "Fishing" or nil end

-- /cpemote: emotes performed later through the timer.
SlashCmdList = {}
local timers, performed = {}, {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
C_ChatInfo = { PerformEmote = function(emote, target) performed[#performed + 1] = { emote = emote, target = target } end }

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
assert(byName["1v1"] and byName["1v1"].body == "/whistle\n/s 1v1\n/cpemote wait none" and byName["1v1"].icon == 132269, "1v1 macro changed")

-- A second emote waits out the server's emote cooldown.
local slash = assert(SlashCmdList.CARPENTEREMOTE, "/cpemote should be registered")
assert(SLASH_CARPENTEREMOTE1 == "/cpemote", "/cpemote should be the command")
slash("whistle")
assert(#timers == 1 and timers[1].delay == 1.5, "/cpemote should wait 1.5 seconds by default")
assert(#performed == 0, "/cpemote must not emote right away")
timers[1].callback()
assert(performed[1].emote == "WHISTLE" and performed[1].target == nil, "/cpemote should whistle at the current target")
slash(" wave 3 ")
assert(timers[2].delay == 3, "/cpemote should take a custom delay")
slash("wait none")
timers[3].callback()
assert(performed[2].emote == "WAIT" and performed[2].target == "none", "/cpemote none should aim at nobody")
assert(rp.PerformDelayedEmote("") == false and rp.PerformDelayedEmote("/run x") == false
    and rp.PerformDelayedEmote("wait Bob") == false, "/cpemote should ignore anything but an emote, a delay, and none")
assert(#timers == 3, "bad input must not schedule an emote")
assert(byName.Roll and byName.Roll.body == "/crack\n/roll" and byName.Roll.icon == 237284, "Roll ritual macro changed")
assert(#rp.Macros == 5, "expected 5 RP macros")

-- The fishing macro reaches for the best pole by fishing bonus, then item level.
local fish = assert(rp.ProfessionMacros and rp.ProfessionMacros[1], "fishing macro is missing")
assert(fish.name == "Fish" and fish.icon == 136245, "fishing macro changed")
assert(rp.GetBody(fish) == "#showtooltip Fishing\n/cast Fishing", "no pole should just cast Fishing")
bags[0] = { 6256, 6365 }
assert(rp.GetBody(fish) == "#showtooltip Fishing\n/equipslot 16 Strong Fishing Pole\n/cast Fishing", "should pick the Strong Fishing Pole over the plain one")
mainHand = 19022
assert(rp.FindBestFishingPole() == "Nat Pagle's Extreme Angler FC-5000", "should keep a better pole already in hand")
mainHand = SWORD
bags[1] = { 99001, 99002 }
assert(rp.FindBestFishingPole() == "Strong Fishing Pole", "a known +5 pole beats unknown poles")
bags[0] = {}
assert(rp.FindBestFishingPole() == "Shinier New Pole", "unknown poles compare by item level")
bags[1] = {}

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

-- Installed built macros follow the bags; uninstalled ones are left alone.
GetMacroInfo = function(index)
    local macro = macros[index]
    if macro then return macro.name, macro.icon, macro.body end
end
bags[0] = { 6365 }
ok, result = rp.Install(fish)
assert(ok and result == "created", "installer did not create the fishing macro")
local fishIndex = GetMacroIndexByName("Fish")
assert(macros[fishIndex].body:find("Strong Fishing Pole", 1, true), "fishing macro should use the pole in the bags")
bags[0] = { 6365, 19022 }
inCombat = true
rp.RefreshBuiltMacros()
assert(macros[fishIndex].body:find("Strong Fishing Pole", 1, true), "built macros must not be rewritten in combat")
inCombat = false
rp.RefreshBuiltMacros()
assert(macros[fishIndex].body:find("Nat Pagle", 1, true), "fishing macro should switch to a better pole")
rp.Remove(fish)
bags[0] = {}
rp.RefreshBuiltMacros()
assert(not rp.IsInstalled(fish), "refreshing must not recreate a removed macro")

for _, toc in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assertContains(read(toc), "Modules\\RPMacros.lua", toc .. " RP macros load entry")
end

local config = read("config.lua")
assertContains(config, "if installed then install = RPMacros.Install end", "RP macro checkbox install/remove")
assertContains(config, "AddToggle(macro.name", "RP macro checkbox rows")
assert(config:find("SECTION_PROFESSION_MACROS", 1, true) < config:find("SECTION_RP_MACROS", 1, true), "Profession Macros should come before RP Macros")
assert(not config:find("CP_RPMacroInstall", 1, true), "RP macros are installed by checkbox, not a button")

print("rp macro fixtures: passed")
