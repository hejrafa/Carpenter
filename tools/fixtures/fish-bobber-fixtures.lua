#!/usr/bin/env lua
-- Verifies the Fish macro's second press: while Fishing channels, the keys
-- bound to buttons holding the Fish macro turn into Interact with Target, and
-- the soft-target settings are raised for the bobber. Everything goes back
-- when the line comes in, before combat locks bindings, and on logout. WoW
-- Forever uses temporary CVars; Classic sets them and puts the old values back.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local function fail(message)
    io.stderr:write("fish-bobber fixture failed: " .. message .. "\n")
    os.exit(1)
end
local function expect(actual, expected, label)
    if actual ~= expected then
        fail(label .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

local state
local FishBobber, eventFrame

local function Load(client)
    state = {
        overrides = {}, cleared = 0, channel = nil, combat = false,
        cvars = { SoftTargetInteract = "1", SoftTargetInteractRange = "10" },
        temp = {}, setCalls = {},
        actions = {}, bindings = {},
    }

    function CreateFrame()
        local frame = { events = {} }
        function frame:SetScript(_, handler) self.OnEvent = handler end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:RegisterUnitEvent(event, unit) self.events[event] = unit end
        return frame
    end
    local frames = {}
    local create = CreateFrame
    CreateFrame = function(...)
        local frame = create(...)
        frames[#frames + 1] = frame
        return frame
    end

    issecretvalue = client.forever and function(value) return value == SECRET end or nil
    Carpenter = { AfterCombat = function(_, _, callback) state.afterCombat = callback end }
    assert(loadfile(repo .. "/Core/Secret.lua"))()

    SlashCmdList = {}
    C_Spell = { GetSpellName = function(spellID) return spellID == 7620 and "Fishing" or nil end }
    C_Container = nil
    C_Item = nil
    GetInventoryItemID = nil

    function UnitChannelInfo(unit)
        if unit == "player" then return state.channel end
    end
    function InCombatLockdown() return state.combat end
    function GetActionInfo(slot)
        local action = state.actions[slot]
        if action then return action.type, 1 end
    end
    C_ActionBar = {
        GetActionText = function(slot)
            local action = state.actions[slot]
            return action and action.text
        end,
    }
    function GetBindingKey(command)
        local keys = state.bindings[command]
        if keys then return unpack(keys) end
    end
    unpack = unpack or table.unpack
    function SetOverrideBinding(owner, priority, key, command)
        if not priority then fail("override should take priority over the game's bindings") end
        state.overrides[key] = command
        state.owner = owner
    end
    function ClearOverrideBindings(owner)
        if owner ~= state.owner then fail("cleared another owner's bindings") end
        state.overrides = {}
        state.cleared = state.cleared + 1
    end

    if client.forever then
        C_CVar = {
            GetCVar = function(name) return state.temp[name] or state.cvars[name] end,
            SetCVar = function(name, value) state.cvars[name] = value end,
            SetTempCVar = function(name, value) state.temp[name] = value end,
            RemoveTempCVar = function(name) state.temp[name] = nil end,
        }
        GetCVar, SetCVar = nil, nil
    else
        C_CVar = nil
        function GetCVar(name) return state.cvars[name] end
        function SetCVar(name, value)
            state.setCalls[#state.setCalls + 1] = name .. "=" .. tostring(value)
            state.cvars[name] = tostring(value)
        end
    end

    -- Action bars: the Fish macro on main bar button 3 and bottom-left
    -- button 5, another macro on main bar button 4, a spell on button 6.
    for _, name in ipairs({ "ActionButton3", "ActionButton4", "ActionButton6", "MultiBarBottomLeftButton5" }) do
        _G[name] = nil
    end
    ActionButton3 = { action = 3 }
    ActionButton4 = { action = 4 }
    ActionButton6 = { action = 6 }
    MultiBarBottomLeftButton5 = { action = 65, bindingAction = client.forever and "MULTIACTIONBAR1BUTTON5" or nil }
    state.actions[3] = { type = "macro", text = "Fish" }
    state.actions[4] = { type = "macro", text = "Bow" }
    state.actions[6] = { type = "spell" }
    state.actions[65] = { type = "macro", text = "Fish" }
    state.bindings.ACTIONBUTTON3 = { "3" }
    state.bindings.ACTIONBUTTON4 = { "4" }
    state.bindings.ACTIONBUTTON6 = { "6" }
    state.bindings.MULTIACTIONBAR1BUTTON5 = { "F", "SHIFT-F" }
    state.bindings["CLICK ActionButton3:LeftButton"] = { "BUTTON4" }

    local ns = { Private = {} }
    assert(loadfile(repo .. "/Modules/RPMacros.lua"))("Carpenter", ns)
    assert(loadfile(repo .. "/Modules/FishBobber.lua"))("Carpenter", ns)
    FishBobber = ns.Private.RPMacros.FishBobber
    if not FishBobber then fail("FishBobber was not exposed") end
    for _, frame in ipairs(frames) do
        if frame.events.UNIT_SPELLCAST_CHANNEL_START then eventFrame = frame end
    end
    if not eventFrame then fail("no frame listens for the fishing channel") end
    expect(eventFrame.events.UNIT_SPELLCAST_CHANNEL_START, "player", "channel start is watched for the player only")
    expect(eventFrame.events.UNIT_SPELLCAST_CHANNEL_STOP, "player", "channel stop is watched for the player only")
end

local function Fire(event) eventFrame:OnEvent(event) end
local function StartChannel(name) state.channel = name; Fire("UNIT_SPELLCAST_CHANNEL_START") end
local function StopChannel() state.channel = nil; Fire("UNIT_SPELLCAST_CHANNEL_STOP") end
local function OverrideList()
    local keys = {}
    for key, command in pairs(state.overrides) do keys[#keys + 1] = key .. ">" .. command end
    table.sort(keys)
    return table.concat(keys, ",")
end

local FISH_KEYS = "3>INTERACTTARGET,BUTTON4>INTERACTTARGET,F>INTERACTTARGET,SHIFT-F>INTERACTTARGET"

-- =========================
-- WoW Forever: temporary CVars
-- =========================
Load({ forever = true })

StartChannel("Fishing")
expect(OverrideList(), FISH_KEYS, "the Fish macro's keys turn into Interact with Target")
expect(state.temp.SoftTargetInteract, "3", "the interact key is turned on for the keyboard")
expect(state.temp.SoftTargetInteractRange, "30", "the interact reach covers the bobber")
expect(state.cvars.SoftTargetInteract, "1", "the saved setting is untouched")

StopChannel()
expect(OverrideList(), "", "the keys go back when the line comes in")
expect(state.temp.SoftTargetInteract, nil, "the temporary interact value is removed")
expect(state.temp.SoftTargetInteractRange, nil, "the temporary reach is removed")
expect(FishBobber.IsHooked(), false, "nothing stays hooked")

-- Another channel doesn't touch the keys.
StartChannel("Drink")
expect(OverrideList(), "", "a non-fishing channel leaves the keys alone")
StopChannel()

-- A hidden channel name counts as not fishing.
StartChannel(SECRET)
expect(OverrideList(), "", "a hidden channel name leaves the keys alone")
StopChannel()

-- Settings already high enough stay as they are.
state.cvars.SoftTargetInteract, state.cvars.SoftTargetInteractRange = "3", "40"
StartChannel("Fishing")
expect(OverrideList(), FISH_KEYS, "keys hooked with high settings")
expect(state.temp.SoftTargetInteract, nil, "an interact key already on is left alone")
expect(state.temp.SoftTargetInteractRange, nil, "a longer reach is left alone")
StopChannel()
state.cvars.SoftTargetInteract, state.cvars.SoftTargetInteractRange = "1", "10"

-- Combat hands the keys back first, and they return if the line is still out.
StartChannel("Fishing")
Fire("PLAYER_REGEN_DISABLED")
expect(OverrideList(), "", "combat hands the keys back to the macro")
expect(state.temp.SoftTargetInteract, nil, "combat restores the settings")
state.combat = true
Fire("PLAYER_REGEN_ENABLED")
state.combat = false
Fire("PLAYER_REGEN_ENABLED")
expect(OverrideList(), FISH_KEYS, "the keys come back after combat while still fishing")
StopChannel()

-- No hooking while combat locks bindings.
state.combat = true
StartChannel("Fishing")
expect(OverrideList(), "", "no hook in combat")
state.combat = false
StopChannel()

-- A line that comes in during combat unhooks once the fight ends.
StartChannel("Fishing")
state.combat = true
StopChannel()
expect(OverrideList(), FISH_KEYS, "bindings can't change in combat")
if not state.afterCombat then fail("the unhook should wait for combat to end") end
state.combat = false
state.afterCombat()
expect(OverrideList(), "", "unhooked after combat")

-- Without the Fish macro on a bar nothing changes.
state.actions[3], state.actions[65] = nil, nil
StartChannel("Fishing")
expect(OverrideList(), "", "no Fish macro on a bar, no hook")
expect(state.temp.SoftTargetInteract, nil, "no Fish macro on a bar, settings untouched")
StopChannel()

-- Logging out mid-cast puts the settings back.
state.actions[3] = { type = "macro", text = "Fish" }
StartChannel("Fishing")
Fire("PLAYER_LEAVING_WORLD")
expect(state.temp.SoftTargetInteract, nil, "leaving the world removes the temporary values")

-- =========================
-- Classic: set and put back
-- =========================
Load({ forever = false })
StartChannel("Fishing")
expect(OverrideList(), FISH_KEYS, "Classic hooks the same keys")
expect(state.cvars.SoftTargetInteract, "3", "Classic turns the interact key on")
expect(state.cvars.SoftTargetInteractRange, "30", "Classic raises the reach")
StopChannel()
expect(state.cvars.SoftTargetInteract, "1", "Classic puts the interact setting back")
expect(state.cvars.SoftTargetInteractRange, "10", "Classic puts the reach back")
expect(table.concat(state.setCalls, ","), "SoftTargetInteract=3,SoftTargetInteractRange=30,SoftTargetInteract=1,SoftTargetInteractRange=10",
    "Classic sets each value once and restores it once")

print("fish-bobber fixtures passed")
