#!/usr/bin/env lua
-- Verifies Mount Speed Trinket: mounting equips the best mount speed trinket
-- for the client and zone, and dismounting brings the previous trinket back.
-- WoW Forever prefers The Desert Rose in desert zones and swaps between it
-- and Carrot on a Stick while riding across a zone border. Classic Era only
-- uses Carrot; TBC prefers a soulbound Riding Crop.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local CARROT, CROP, ROSE, BADGE, TOKEN = 11122, 25653, 274648, 1001, 1002

local function fail(message)
    io.stderr:write("auto-carrot fixture failed: " .. message .. "\n")
    os.exit(1)
end
local function expect(actual, expected, label)
    if actual ~= expected then
        fail(label .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

-- World state the game functions read.
local world

local AREA_NAMES = {
    [440] = "Tanaris", [400] = "Thousand Needles", [1377] = "Silithus", [4] = "Blasted Lands",
    [16115] = "Blasted Lands", [3] = "Badlands", [17] = "The Barrens", [405] = "Desolace",
    [16017] = "Desolace", [3428] = "Ahn'Qiraj", [3478] = "Gates of Ahn'Qiraj",
    [3429] = "Ruins of Ahn'Qiraj", [16076] = "Temple of Ahn'Qiraj", [14] = "Durotar",
    [1637] = "Orgrimmar", [1337] = "Uldaman", [1176] = "Zul'Farrak",
}

local function Load(clientFlags)
    world = {
        level = 60, mounted = false, combat = false, time = 100, zone = "Elwynn Forest",
        equipped = { [13] = BADGE, [14] = TOKEN },
        bags = {}, soulbound = {}, cursor = nil, timers = {}, events = {}, equips = 0,
    }

    local feature
    CarpenterDB = { autoCarrotSlot = 14 }
    Carpenter = {
        Client = clientFlags,
        IsEnabled = function(_, key) return key == "autoCarrotEnabled" end,
        RegisterFeature = function(_, key, registered)
            if key == "autoCarrotEnabled" then feature = registered end
        end,
    }

    function CreateFrame()
        local frame = {}
        function frame:SetScript(_, handler) self.OnEvent = handler end
        function frame:RegisterEvent(event) world.events[event] = true end
        function frame:RegisterUnitEvent(event) world.events[event] = true end
        function frame:UnregisterAllEvents() world.events = {} end
        world.frame = frame
        return frame
    end

    C_Timer = { After = function(delay, callback) world.timers[#world.timers + 1] = callback end }
    C_Map = { GetAreaInfo = function(areaID) return AREA_NAMES[areaID] end }
    C_Item = {
        GetItemInfo = function(itemID)
            local reqLevel = itemID == CROP and 69 or 0
            local equipLoc = (itemID == BADGE or itemID == TOKEN or itemID == CARROT or itemID == CROP or itemID == ROSE)
                and "INVTYPE_TRINKET" or "INVTYPE_HEAD"
            return "item", nil, nil, nil, reqLevel, nil, nil, nil, equipLoc
        end,
    }
    C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
        GetContainerItemID = function(bag, slot) return bag == 0 and world.bags[slot] or nil end,
        PickupContainerItem = function(bag, slot)
            world.cursor = { bag = bag, slot = slot }
        end,
    }
    function EquipCursorItem(invSlot)
        local from = world.cursor
        if not from then fail("EquipCursorItem without an item on the cursor") end
        local incoming = world.bags[from.slot]
        world.bags[from.slot] = world.equipped[invSlot]
        world.equipped[invSlot] = incoming
        world.cursor = nil
        world.equips = world.equips + 1
    end
    function GetInventoryItemID(_, invSlot) return world.equipped[invSlot] end
    function GetRealZoneText() return world.zone end
    function UnitLevel() return world.level end
    function UnitIsDeadOrGhost() return false end
    function InCombatLockdown() return world.combat end
    function IsMounted() return world.mounted end
    function IsFlyableArea() return false end
    function IsFlying() return false end
    function UnitOnTaxi() return false end
    function GetTime() return world.time end
    function IsLoggedIn() return true end

    -- The soulbound check reads the bag item's tooltip.
    ITEM_SOULBOUND = "Soulbound"
    local tooltipSlot
    GameTooltip = {
        GetOwner = function() return nil end,
        SetOwner = function() end,
        ClearLines = function() tooltipSlot = nil end,
        SetBagItem = function(_, _, slot) tooltipSlot = slot end,
        NumLines = function() return 1 end,
        GetRegions = function() return end,
        Hide = function() end,
    }
    GameTooltipTextLeft1 = {
        GetText = function() return tooltipSlot and world.soulbound[tooltipSlot] and "Soulbound" or "Binds when picked up" end,
    }
    GameTooltipTextRight1 = { GetText = function() return nil end }
    UIParent = {}

    assert(loadfile(repo .. "/Modules/AutoCarrot.lua"))("Carpenter", {})
    if not feature then fail("feature was not registered") end
    feature:Enable()
    -- Turned on while logged in, it looks once right away (dismounted: no swap).
    local due = world.timers
    world.timers = {}
    for _, callback in ipairs(due) do callback() end
    if world.equips ~= 0 then fail("enabling while dismounted shouldn't swap") end
    return feature
end

-- Runs every pending timer, letting time pass so throttled swaps go through.
local function Settle()
    for _ = 1, 10 do
        local due = world.timers
        if #due == 0 then return end
        world.timers = {}
        world.time = world.time + 1
        for _, callback in ipairs(due) do callback() end
    end
    fail("timers never settled")
end

local function Fire(event, unit)
    world.frame:OnEvent(event, unit)
    Settle()
end
local function Mount() world.mounted = true; Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
local function Dismount() world.mounted = false; Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
local function Travel(zone) world.zone = zone; Fire("ZONE_CHANGED_NEW_AREA") end

-- =========================
-- WoW Forever
-- =========================
Load({ isForever = true, isMainline = true })
if not world.events.ZONE_CHANGED_NEW_AREA then fail("zone changes should be watched") end

-- Outside the desert, Carrot goes into the chosen slot.
world.bags = { [1] = CARROT, [2] = ROSE }
Mount()
expect(world.equipped[14], CARROT, "Forever outside the desert equips Carrot")
expect(world.equipped[13], BADGE, "the other trinket slot stays as it was")

-- Riding into Tanaris swaps the worn Carrot for The Desert Rose.
Travel("Tanaris")
expect(world.equipped[14], ROSE, "entering a desert swaps in The Desert Rose")

-- Riding on through another desert zone changes nothing.
local equips = world.equips
Travel("Durotar")
expect(world.equips, equips, "a desert-to-desert ride doesn't swap")

-- Leaving the desert brings Carrot back.
Travel("Ashenvale")
expect(world.equipped[14], CARROT, "leaving the desert swaps Carrot back in")

-- Dismounting returns the trinket worn before mounting, not Carrot or the Rose.
Travel("Orgrimmar")
expect(world.equipped[14], ROSE, "Orgrimmar counts as desert")
Dismount()
expect(world.equipped[14], TOKEN, "dismount returns the original trinket after zone swaps")

-- Mounting inside a desert goes straight to The Desert Rose.
Mount()
expect(world.equipped[14], ROSE, "mounting in a desert equips The Desert Rose")
Dismount()
expect(world.equipped[14], TOKEN, "dismount returns the original trinket")

-- Without the Rose, Carrot works in the desert too.
world.bags = { [1] = CARROT }
Mount()
expect(world.equipped[14], CARROT, "desert without the Rose falls back to Carrot")
Dismount()

-- The Rose alone does nothing outside a desert, so it stays in the bags.
world.bags = { [1] = ROSE }
Travel("Elwynn Forest")
Mount()
expect(world.equipped[14], TOKEN, "the Rose isn't equipped outside a desert")
-- Leaving the desert with the Rose on and no Carrot keeps it until dismount.
Travel("Silithus")
expect(world.equipped[14], ROSE, "entering a desert while mounted equips the Rose")
Travel("Feralas")
expect(world.equipped[14], ROSE, "with no Carrot, the Rose stays on until dismount")
Dismount()
expect(world.equipped[14], TOKEN, "dismount returns the original trinket")

-- A swap right after another still happens once the throttle has passed.
world.bags = { [1] = CARROT, [2] = ROSE }
world.zone = "Feralas"
world.mounted = true
world.time = world.time + 5
world.frame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
local due = world.timers
world.timers = {}
for _, callback in ipairs(due) do callback() end
expect(world.equipped[14], CARROT, "mount swap without letting time pass")
world.zone = "Tanaris"
world.frame:OnEvent("ZONE_CHANGED_NEW_AREA")
due = world.timers
world.timers = {}
for _, callback in ipairs(due) do callback() end
expect(world.equipped[14], CARROT, "a swap inside the throttle waits")
Settle()
expect(world.equipped[14], ROSE, "the throttled swap runs afterwards")
Dismount()
expect(world.equipped[14], TOKEN, "dismount after a throttled swap")

-- In combat nothing moves; the swap back waits for combat to end.
Mount()
world.combat = true
world.mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
expect(world.equipped[14], ROSE, "no swap in combat")
world.combat = false
Fire("PLAYER_REGEN_ENABLED")
expect(world.equipped[14], TOKEN, "swap back after combat")

-- =========================
-- Classic Era
-- =========================
Load({ isVanilla = true, isClassic = true })
world.bags = { [1] = ROSE, [2] = CARROT }
world.zone = "Tanaris"
Mount()
expect(world.equipped[14], CARROT, "Classic Era ignores The Desert Rose")
Dismount()
expect(world.equipped[14], TOKEN, "Classic Era dismount")

-- =========================
-- TBC
-- =========================
Load({ isTBC = true, isClassic = true })
world.level = 70
world.bags = { [1] = CROP, [2] = CARROT }
Mount()
expect(world.equipped[14], CARROT, "a tradeable Riding Crop is skipped")
Dismount()
world.soulbound[1] = true
Mount()
expect(world.equipped[14], CROP, "a soulbound Riding Crop wins over Carrot")
Dismount()
expect(world.equipped[14], TOKEN, "TBC dismount")
world.level = 60
Mount()
expect(world.equipped[14], CARROT, "below the Crop's level, Carrot is used")
Dismount()

print("auto-carrot fixtures passed")
