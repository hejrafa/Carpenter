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
local value = assert(layout.LayoutString, "Edit Mode layout string is missing")
assert(#value > 2000, "Edit Mode layout string looks truncated")
assert(value:match("^3 59 "), "Edit Mode layout string has the wrong header")
assert(value:match("29 2 1 7 7 UIParent 0%.0 400%.0 %-1 #&%$U%%#&D&%%'2%(%$%)%$$"), "Edit Mode layout string has the wrong ending")
assert(not value:find("\n", 1, true), "Edit Mode layout string must be a single line")
assert(not value:find("\\", 1, true), "Edit Mode layout string contains an escaped Markdown asterisk")
assertContains(value, "CompactRaidFrameManager", "raid-frame placement")
assertContains(value, "MicroMenuContainer", "micro-menu placement")
assertContains(value, "Minimap -68.0 -68.0", "minimap placement")

assert(layout.IsAvailable() == true, "Retail should expose the hidden layout page")
Carpenter.Client.isRetail = false
assert(layout.IsAvailable() == false, "Classic should not expose the Retail Edit Mode layout page")

local inCombat = false
local savedLayoutInfo = { activeLayout = 1, layouts = {} }
local layoutAdded
InCombatLockdown = function() return inCombat end
Enum = {
    EditModeLayoutType = { Account = 1 },
    EditModePresetLayoutsMeta = { NumValues = 3 },
}
C_EditMode = {
    ConvertStringToLayoutInfo = function(text)
        assert(text == value, "installer converted the wrong layout string")
        return { systems = { { system = 0, settings = {} } } }
    end,
    GetLayouts = function() return savedLayoutInfo end,
    SaveLayouts = function(layoutInfo) savedLayoutInfo = layoutInfo end,
    OnLayoutAdded = function(index, activate, imported)
        layoutAdded = { index = index, activate = activate, imported = imported }
    end,
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
inCombat = false

for _, toc in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc" }) do
    assertContains(read(toc), "Modules\\EditModeLayout.lua", toc .. " Edit Mode layout load entry")
end
for _, toc in ipairs({ "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    assert(not read(toc):find("Modules\\EditModeLayout.lua", 1, true), toc .. " must not load the Retail Edit Mode layout")
end

local config = read("config.lua")
assertContains(config, "SetSettingsView(not hiddenSettingsShown)", "version-number hidden-page toggle")
assertContains(config, "EditModeLayout.Install", "one-click Carpenter layout installer")
assertContains(config, "CreateListItem(L.EDIT_MODE_LAYOUT_NAME", "Carpenter layout list item")
assert(not config:find("CP_EditModeLayoutCopy", 1, true), "copy fallback must stay removed")

print("edit-mode layout fixtures: passed")
