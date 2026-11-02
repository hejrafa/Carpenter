#!/usr/bin/env lua
-- Offline checks for the hidden Edit Mode layout page and installer.

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
Carpenter = { Client = { isRetail = true } }

local chunk = assert(loadfile(repo .. "/Modules/EditModeLayout.lua"))
chunk("Carpenter", ns)
local layout = assert(ns.Private.EditModeLayout, "Edit Mode layout module did not load")

-- The source of truth is the author's WoW Forever export (format 5).
local forever = assert(layout.ForeverLayoutString, "Forever Edit Mode layout string is missing")
assert(#forever == 2700, "Forever Edit Mode layout string has the wrong length")
assert(forever:match("^5 0 59 "), "Forever Edit Mode layout string has the wrong header")
assert(forever:match("29 2 1 7 7 UIParent 0%.0 400%.0 %-1 #&%$U%%#&D&%%'2%(%$%)%$$"), "Forever Edit Mode layout string has the wrong ending")
assert(not forever:find("\n", 1, true), "Edit Mode layout string must be a single line")
assert(not forever:find("\\", 1, true), "Edit Mode layout string contains an escaped Markdown asterisk")
assertContains(forever, "CompactRaidFrameManager", "raid-frame placement")
-- Raid frames: border on (setting 12), separate groups laid out horizontally (13).
assertContains(forever, "3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-=.+/$0$1#", "raid-frame border and group layout")
assertContains(forever, "14 -1 0 0 0 UIParent 1582.7 -942.5", "micro-menu placement")
assertContains(forever, "13 -1 0 0 0 UIParent 1544.6 -983.0", "bag-bar placement")
assertContains(forever, "Minimap -68.0 -68.0", "Forever group-finder eye placement")
assertContains(forever, "0 12 0 0 2 StanceBar 4.0 0.0", "stance-bar placement")
assertContains(forever, "26 0 0 1 1 UIParent -729.6 -559.0", "Forever end-cap placement")
assertContains(forever, "28 -1 1 4 4 UIParent 0.0 0.0 -1 #&", "Forever loss-of-control entry")

-- Retail 12.1.5 reads format 2 with the system count repeated, keeps Loss of
-- Control at 26, and has no totem bar, end caps, group-finder eye, or swing
-- timers, so its string is derived from the Forever export.
local retail = assert(layout.RetailLayoutString, "Retail Edit Mode layout string was not built")
assert(retail:match("^2 52 52 0 0 0 7 7 UIParent "), "Retail Edit Mode layout string has the wrong header")
assert(not retail:find("\n", 1, true), "Retail Edit Mode layout string must be a single line")
local function systemsOf(text)
    local systems = {}
    for system, index in text:gmatch("(%-?%d+) (%-?%d+) [01] %d %d %S+ %-?[%d.]+ %-?[%d.]+ %-1 %S+") do
        systems[#systems + 1] = system .. " " .. index
    end
    return systems
end
local foreverSystems, retailSystems = systemsOf(forever), systemsOf(retail)
assert(#foreverSystems == 59, "Forever Edit Mode layout string should carry 59 systems")
assert(#retailSystems == 52, "Retail Edit Mode layout string should carry 52 systems")
local retailSystemSet = {}
for _, entry in ipairs(retailSystems) do retailSystemSet[entry] = true end
for _, entry in ipairs({ "25 -1", "26 0", "26 1", "27 -1", "28 -1", "29 0", "29 1", "29 2" }) do
    assert(not retailSystemSet[entry], "Retail Edit Mode layout string must not carry Forever system " .. entry)
end
assert(retailSystemSet["26 -1"], "Retail Edit Mode layout string lost Loss of Control")
assert(retail:sub(-#"26 -1 1 4 4 UIParent 0.0 0.0 -1 #&") == "26 -1 1 4 4 UIParent 0.0 0.0 -1 #&", "Retail loss-of-control entry was not remapped from 28")
for _, entry in ipairs(foreverSystems) do
    local system = tonumber(entry:match("^(%-?%d+)"))
    if system <= 24 then
        assert(retailSystemSet[entry], "Retail Edit Mode layout string lost system " .. entry)
    end
end
assertContains(retail, "3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-=.+/$0$1#", "Retail raid-frame border and group layout")
assertContains(retail, "14 -1 0 0 0 UIParent 1582.7 -942.5", "Retail micro-menu placement")
assertContains(retail, "0 12 0 0 2 StanceBar 4.0 0.0", "Retail stance-bar placement")
-- Everything after the header is the Forever string minus the dropped systems.
local stripped = forever:gsub("^5 0 59 ", "")
    :gsub(" 25 %-1 0 4 4 UIParent 350%.0 %-400%.0 %-1 #", "")
    :gsub(" 26 0 0 1 1 UIParent %-729%.6 %-559%.0 %-1 #%$", "")
    :gsub(" 26 1 0 1 1 UIParent %-605%.0 %-559%.0 %-1 #%$", "")
    :gsub(" 27 %-1 1 4 4 Minimap %-68%.0 %-68%.0 %-1 #%-", "")
    :gsub(" 28 %-1 ", " 26 -1 ")
    :gsub(" 29 %d 1 7 7 UIParent 0%.0 4%d%d%.0 %-1 #&%$U%%#&D&%%'2%(%$%)%$", "")
assert(retail == "2 52 52 " .. stripped, "Retail Edit Mode layout string differs from the remapped Forever export")

assert(layout.IsAvailable() == true, "Retail should expose the hidden layout page")
assert(layout.GetLayoutString() == retail, "Retail must install the Retail-format layout string")
Carpenter.Client.isRetail = false
Carpenter.Client.isForever = true
assert(layout.IsAvailable() == true, "Forever should expose the hidden layout page")
assert(layout.GetLayoutString() == forever, "Forever must install the Forever-format layout string")
Carpenter.Client.isForever = false
assert(layout.IsAvailable() == false, "Classic should not expose the Edit Mode layout page")
Carpenter.Client.isRetail = true

local expectedString = retail

local inCombat = false
local savedLayoutInfo = { activeLayout = 1, layouts = {} }
local layoutAdded
local layoutDeleted
InCombatLockdown = function() return inCombat end
Enum = {
    EditModeLayoutType = { Account = 1 },
    EditModePresetLayoutsMeta = { NumValues = 3 },
}
C_EditMode = {
    ConvertStringToLayoutInfo = function(text)
        assert(text == expectedString, "installer converted the wrong layout string")
        return { systems = { { system = 0, settings = {} } } }
    end,
    GetLayouts = function() return savedLayoutInfo end,
    SaveLayouts = function(layoutInfo) savedLayoutInfo = layoutInfo end,
    OnLayoutAdded = function(index, activate, imported)
        layoutAdded = { index = index, activate = activate, imported = imported }
    end,
    OnLayoutDeleted = function(index) layoutDeleted = index end,
}

local installed, result = layout.Install()
assert(installed and result == "created", "installer did not create the Carpenter layout")
assert(#savedLayoutInfo.layouts == 1, "installer did not add exactly one layout")
assert(savedLayoutInfo.layouts[1].layoutName == "Carpenter", "installer used the wrong layout name")
assert(savedLayoutInfo.layouts[1].layoutType == 1, "installer did not create an account layout")
assert(layoutAdded and layoutAdded.index == 4 and layoutAdded.activate == false and layoutAdded.imported == true, "installer sent the wrong layout-added notification")

layoutAdded = nil
installed, result = layout.Install()
assert(installed and result == "updated", "installer did not update the existing Carpenter layout")
assert(#savedLayoutInfo.layouts == 1, "updating the Carpenter layout created a duplicate")
assert(layoutAdded == nil, "updating an existing layout must not emit a layout-added notification")

inCombat = true
installed, result = layout.Install()
assert(installed == false and result == "combat", "installer must refuse combat-time layout changes")
local removed
removed, result = layout.Remove()
assert(removed == false and result == "combat", "remover must refuse combat-time layout changes")
inCombat = false

assert(layout.IsInstalled(), "the installed Carpenter layout should read as checked")
savedLayoutInfo.activeLayout = 4
removed, result = layout.Remove()
assert(removed == false and result == "active", "remover must leave the layout in use alone")
assert(#savedLayoutInfo.layouts == 1, "refusing to remove the active layout still removed it")

savedLayoutInfo.activeLayout = 1
table.insert(savedLayoutInfo.layouts, 1, { layoutName = "Mine", layoutType = 1 })
removed, result = layout.Remove()
assert(removed and result == "removed", "remover did not remove the Carpenter layout")
assert(#savedLayoutInfo.layouts == 1 and savedLayoutInfo.layouts[1].layoutName == "Mine", "remover touched another layout")
assert(layoutDeleted == 5, "remover sent the wrong layout-deleted index")
assert(not layout.IsInstalled(), "a removed layout should read as unchecked")

layoutDeleted = nil
removed, result = layout.Remove()
assert(removed and result == "removed" and layoutDeleted == nil, "removing a missing layout should be a no-op")

for _, toc in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc" }) do
    assertContains(read(toc), "Modules\\EditModeLayout.lua", toc .. " Edit Mode layout load entry")
end
for _, toc in ipairs({ "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assert(not read(toc):find("Modules\\EditModeLayout.lua", 1, true), toc .. " must not load the Retail Edit Mode layout")
end

local config = read("config.lua")
assertContains(config, "SetSettingsView(not hiddenSettingsShown)", "version-number hidden-page toggle")
assertContains(config, "EditModeLayout.Install", "one-click Carpenter layout installer")
assertContains(config, "AddToggle(L.EDIT_MODE_LAYOUT_NAME", "Carpenter layout checkbox")
assert(not config:find("CP_EditModeLayoutInstall", 1, true), "the layout is installed by checkbox, not a button")
assert(not config:find("CP_EditModeLayoutCopy", 1, true), "copy fallback must stay removed")

print("edit-mode layout fixtures: passed")
