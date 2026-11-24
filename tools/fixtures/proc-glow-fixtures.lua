#!/usr/bin/env lua
-- Offline fixture checks for Proc Glow.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "proc-glow")
local fail, assertEqual, assertTrue = H.fail, H.assertEqual, H.assertTrue
local unpack = unpack or table.unpack

-- =========================
-- Clock and timers
-- =========================
local now = 100
GetTime = function() return now end

local timers = {}
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { due = now + (delay or 0), callback = callback }
    end,
}

-- Moves the clock on, running each timer that comes due on the way.
local function advance(seconds)
    local target = now + (seconds or 0)
    while true do
        local index, earliest
        for i, timer in ipairs(timers) do
            if timer.due <= target and (not earliest or timer.due < earliest.due) then
                index, earliest = i, timer
            end
        end
        if not index then break end
        table.remove(timers, index)
        if earliest.due > now then now = earliest.due end
        earliest.callback()
    end
    now = target
end

-- =========================
-- Frames, textures and animations
-- =========================
local function Descendants(frame, list)
    list = list or {}
    for _, child in ipairs(frame.children or {}) do
        list[#list + 1] = child
        Descendants(child, list)
    end
    return list
end

-- Shows or hides a frame and fires OnShow/OnHide on every frame whose
-- visibility changes, as the game does for a parent's children.
local function SetShown(frame, shown)
    local frames = Descendants(frame)
    frames[#frames + 1] = frame
    local before = {}
    for i, each in ipairs(frames) do before[i] = each:IsVisible() end
    frame.shown = shown and true or false
    for i, each in ipairs(frames) do
        local after = each:IsVisible()
        if before[i] ~= after then
            local script = each.scripts[after and "OnShow" or "OnHide"]
            if script then script(each) end
        end
    end
end

local function Texture(owner, layer)
    local texture = { layer = layer, alpha = 1, points = {} }
    function texture:SetAtlas(atlas) self.atlas = atlas end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function texture:SetAllPoints(target) self.allPoints = target end
    function texture:SetAlpha(alpha) self.alpha = alpha end
    owner.regions[#owner.regions + 1] = texture
    return texture
end

local ANIMATION_SETTERS = {
    "SetTarget", "SetOrder", "SetDuration", "SetFromAlpha", "SetToAlpha",
    "SetFlipBookRows", "SetFlipBookColumns", "SetFlipBookFrames",
    "SetFlipBookFrameWidth", "SetFlipBookFrameHeight",
}

local function AnimationGroup()
    local group = { animations = {}, playing = false, plays = 0, scripts = {} }
    function group:SetLooping(looping) self.looping = looping end
    function group:SetToFinalAlpha(value) self.toFinalAlpha = value end
    function group:CreateAnimation(kind)
        local animation = { kind = kind }
        for _, setter in ipairs(ANIMATION_SETTERS) do
            animation[setter] = function(anim, value) anim[setter] = value end
        end
        self.animations[#self.animations + 1] = animation
        return animation
    end
    function group:Play() self.playing = true; self.plays = self.plays + 1 end
    function group:Stop() self.playing = false end
    function group:IsPlaying() return self.playing end
    function group:SetScript(name, handler) self.scripts[name] = handler end
    function group:Finish()
        self.playing = false
        if self.scripts.OnFinished then self.scripts.OnFinished(self) end
    end
    return group
end

local createdFrames = H.installCreateFrame()
local baseCreateFrame = CreateFrame
CreateFrame = function(...)
    local frame = baseCreateFrame(...)
    function frame:CreateTexture(_, layer) return Texture(self, layer) end
    function frame:CreateAnimationGroup() return AnimationGroup() end
    function frame:Show() SetShown(self, true) end
    function frame:Hide() SetShown(self, false) end
    return frame
end

-- =========================
-- Game API
-- =========================
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
issecretvalue = function(value) return value == SECRET end

local inCombat = false
InCombatLockdown = function() return inCombat end

local names = {
    [14251] = "Riposte",
    [1752] = "Sinister Strike",
    [8676] = "Ambush",
    [703] = "Garrote",
    [2098] = "Eviscerate",
    [6760] = "Eviscerate", -- rank 2
    [7384] = "Overpower",
    [1784] = "Stealth",
    [185438] = "Shadowstrike",
}
for spellID = 90001, 90006 do names[spellID] = "Spell " .. spellID end
C_Spell = { GetSpellName = function(spellID) return names[spellID] end }

-- [slot] = { type, id, subType }
local actions = {
    [1] = { "spell", 14251 },
    [2] = { "spell", 1752 },
    [3] = { "spell", 8676 },
    [4] = { "macro", 703, "spell" },
    [5] = { "spell", 2098 },
    [6] = { "spell", 7384 },
    [13] = { "item", 5512 },
    [14] = { "spell", 1784 },
    [16] = { "spell", 6760 },
    [17] = { "spell", 185438 },
}
for slot = 7, 12 do actions[slot] = { "spell", 90000 + slot - 6 } end

GetActionInfo = function(slot)
    local action = actions[slot]
    if action then return action[1], action[2], action[3] end
end

-- [slot] = { usable, noMana }. Blocked unless set otherwise.
local usability = {
    [2] = { false, true }, -- Sinister Strike waits on energy
    [13] = { true, false },
    [14] = { true, false },
}
C_ActionBar = {
    IsUsableAction = function(slot)
        local state = usability[slot]
        if state then return state[1], state[2] end
        return false, false
    end,
}

local overlayed = {}
C_SpellActivationOverlay = { IsSpellOverlayed = function(spellID) return overlayed[spellID] == true end }

local player = { stealthed = false, mounted = false, form = 0 }
local target = { exists = true, dead = false }
IsStealthed = function() return player.stealthed end
IsMounted = function() return player.mounted end
IsFlying = function() return false end
IsSwimming = function() return false end
IsIndoors = function() return false end
HasFullControl = function() return true end
UnitInVehicle = function() return false end
GetShapeshiftForm = function() return player.form end
GetNumShapeshiftForms = function() return 1 end
GetShapeshiftFormInfo = function(index)
    if index == 1 then return 132320, player.form == 1, true, 1784 end
end
UnitExists = function(unit)
    if unit == "target" then return target.exists end
    return unit == "player"
end
UnitIsDead = function() return false end
UnitIsDeadOrGhost = function(unit)
    if unit == "target" then return target.dead end
    return false
end

-- Blizzard's alert taints the action buttons; the module must never call it.
ActionButtonSpellAlertManager = {
    ShowAlert = function() fail("ActionButtonSpellAlertManager:ShowAlert was called") end,
    HideAlert = function() fail("ActionButtonSpellAlertManager:HideAlert was called") end,
}
ActionButton_ShowOverlayGlow = function() fail("ActionButton_ShowOverlayGlow was called") end
ActionButton_HideOverlayGlow = function() fail("ActionButton_HideOverlayGlow was called") end

-- Action buttons, each showing the slot of the same number.
local buttons = {}
for slot = 1, 17 do
    buttons[slot] = H.Frame({ name = "ActionButton" .. slot, width = 45, height = 45, action = slot })
end
ActionBarButtonEventsFrame = { frames = {} }
for _, button in ipairs(buttons) do
    table.insert(ActionBarButtonEventsFrame.frames, button)
end

-- =========================
-- Module
-- =========================
CarpenterDB = { procGlowEnabled = true }
H.carpenter({
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = H.captureFeature("procGlowEnabled"),
})

H.load("Modules/ProcGlow.lua")
local feature = H.features.procGlowEnabled
if not feature then fail("Proc Glow did not register its feature") end
local events = createdFrames[#createdFrames]

local function fire(event, ...)
    local handler = events.scripts.OnEvent
    if not handler then fail("the module did not set an OnEvent script") end
    if events.events[event] then handler(events, event, ...) end
end

local function state(slot, isUsable, noMana)
    usability[slot] = { isUsable, noMana }
    return { slot = slot, usable = isUsable, noMana = noMana }
end

local function change(...)
    fire("ACTION_USABLE_CHANGED", { ... })
end

local function glowOf(slot)
    return buttons[slot].children[1]
end

local function isGlowing(slot)
    local glow = glowOf(slot)
    return glow ~= nil and glow.active == true and glow:IsVisible() == true
end

local function expectGlow(slot, expected, message)
    assertEqual(isGlowing(slot), expected, message)
end

-- Lets every explanation window close before the next case.
local function pause()
    advance(2)
end

-- =========================
-- Glow frames are built out of combat
-- =========================
inCombat = true
feature:Enable()
assertEqual(#buttons[1].children, 0, "no glow frame should be built in combat")
inCombat = false
Carpenter:RunAfterCombatQueue()
for slot, button in ipairs(buttons) do
    assertEqual(#button.children, 1, "button " .. slot .. " should get one glow frame after combat")
end

local glow = glowOf(1)
assertEqual(glow.width, 45 * 1.4, "the glow should be 1.4 times the button, like the game's")
assertEqual(glow.regions[1].atlas, "UI-HUD-ActionBar-Proc-Start-Flipbook", "the burst should use the game's start flipbook")
assertEqual(glow.regions[1].width, 150, "the burst should be the game's 150 pixels")
assertEqual(glow.regions[2].atlas, "UI-HUD-ActionBar-Proc-Loop-Flipbook", "the loop should use the game's loop flipbook")
assertEqual(glow.regions[2].allPoints, glow, "the loop should fill the glow frame")
assertEqual(glow.LoopAnim.looping, "REPEAT", "the loop should repeat")
assertEqual(glow.StartAnim.toFinalAlpha, true, "the burst should keep its final alpha")
local flipBook
for _, animation in ipairs(glow.LoopAnim.animations) do
    if animation.kind == "FlipBook" then flipBook = animation end
end
assertTrue(flipBook and flipBook.SetFlipBookFrames == 30 and flipBook.SetFlipBookRows == 6
    and flipBook.SetFlipBookColumns == 5, "the loop should flip through the game's 6 by 5 sheet")
expectGlow(1, false, "nothing should glow right after turning on")

-- =========================
-- Riposte after a parry
-- =========================
change(state(1, true, false))
expectGlow(1, false, "a freed spell should wait for its events to settle")
advance(0.2)
expectGlow(1, true, "Riposte should glow after a parry frees it")
assertTrue(glow.StartAnim.playing, "the glow should open with the burst")
assertTrue(not glow.LoopAnim.playing, "the loop should wait for the burst")
glow.StartAnim:Finish()
assertTrue(glow.LoopAnim.playing, "the loop should follow the burst")

change(state(1, false, false))
expectGlow(1, false, "Riposte should stop glowing once it is blocked again")
assertTrue(not glow.LoopAnim.playing and glow.shown == false, "a stopped glow should hide and stop animating")
pause()

-- =========================
-- Power coming back
-- =========================
change(state(2, true, false))
advance(0.2)
expectGlow(2, false, "energy coming back should not light up Sinister Strike")
change(state(2, false, true))
pause()

-- A parry while low on energy frees Riposte, but it glows once it's usable.
change(state(1, false, true))
advance(0.2)
expectGlow(1, false, "a proc spell waiting on energy should not glow yet")
change(state(1, true, false))
expectGlow(1, true, "the proc spell should glow once the energy is there")
change(state(1, false, true))
expectGlow(1, false, "the glow should stop while the energy is short again")
change(state(1, true, false))
expectGlow(1, true, "the glow should come back while the proc lasts")
change(state(1, false, false))
pause()

-- =========================
-- Changes that aren't procs
-- =========================
player.form = 1
fire("UPDATE_SHAPESHIFT_FORM")
change(state(6, true, false))
advance(0.2)
expectGlow(6, false, "a stance change should not light up what it frees")
player.form = 0
fire("UPDATE_SHAPESHIFT_FORM")
change(state(6, false, false))
pause()

-- The game also fires form events when the form stays the same.
fire("UPDATE_SHAPESHIFT_FORM")
change(state(6, true, false))
advance(0.2)
expectGlow(6, true, "a form event without a form change should not hide a proc")
change(state(6, false, false))
pause()

-- Buying a missing reagent frees its spells; arrows shot in combat don't
-- explain anything.
fire("BAG_UPDATE", 0)
change(state(1, true, false))
advance(0.2)
expectGlow(1, false, "a bag change out of combat should explain what it frees")
change(state(1, false, false))
pause()
inCombat = true
fire("BAG_UPDATE", 0)
change(state(1, true, false))
advance(0.2)
expectGlow(1, true, "a bag change in combat should not hide a proc")
inCombat = false
change(state(1, false, false))
pause()

-- A macro's slot changing starts that slot over and leaves the rest alone.
fire("ACTIONBAR_SLOT_CHANGED", 4)
change(state(1, true, false))
advance(0.2)
expectGlow(1, true, "another slot changing should not hide a proc")
change(state(1, false, false))
pause()
usability[6] = { true, false }
fire("ACTIONBAR_SLOT_CHANGED", 6)
advance(0.2)
expectGlow(6, false, "a slot read again after it changed should not glow for being usable")
change(state(6, false, false))
pause()
actions[13] = { "spell", 14251 }
fire("ACTIONBAR_SLOT_CHANGED", 13)
advance(0.2)
expectGlow(13, false, "a spell dragged onto a bar should not glow for being usable")
actions[13] = { "item", 5512 }
fire("ACTIONBAR_SLOT_CHANGED", 13)
pause()

-- The explanation may arrive just after the slot frees up.
change(state(1, true, false))
advance(0.05)
fire("PLAYER_TARGET_CHANGED")
advance(0.2)
expectGlow(1, false, "a target change right after should explain the change")
change(state(1, false, false))
pause()

-- Mounting has no event of its own here; the player's state shows it.
player.mounted = true
change(state(1, true, false))
advance(0.2)
expectGlow(1, false, "mounting should explain what it frees")
player.mounted = false
change(state(1, false, false))
pause()

fire("PLAYER_REGEN_ENABLED")
change(state(1, true, false))
advance(0.2)
expectGlow(1, false, "leaving combat should explain what it frees")
change(state(1, false, false))
pause()

-- Finishing moves free up on combo points, every rank of them.
change(state(5, true, false), state(16, true, false))
advance(0.2)
expectGlow(5, false, "Eviscerate should never glow")
expectGlow(16, false, "a higher rank of Eviscerate should never glow either")
change(state(5, false, false), state(16, false, false))
pause()

-- Many spells freeing at once is a state change, not a proc.
local freed, blocked = {}, {}
for slot = 7, 12 do
    freed[#freed + 1] = state(slot, true, false)
end
change(unpack(freed))
advance(0.2)
for slot = 7, 12 do
    expectGlow(slot, false, "spell " .. slot .. " should not glow when six spells free up at once")
    blocked[#blocked + 1] = state(slot, false, false)
end
change(unpack(blocked))
pause()

-- =========================
-- The game's own glow
-- =========================
change(state(6, true, false))
advance(0.2)
expectGlow(6, true, "Overpower should glow after a dodge")
fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)
expectGlow(6, false, "a spell the game glows itself should keep only the game's glow")
fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 7384)
expectGlow(6, true, "the glow should come back when the game's stops")

overlayed[7384] = true
fire("PLAYER_TARGET_CHANGED")
advance(0)
expectGlow(6, false, "a spell the game reports as overlayed should not glow")
overlayed[7384] = nil
buttons[6].SpellActivationAlert = H.Frame({ shown = true })
fire("PLAYER_TARGET_CHANGED")
advance(0)
expectGlow(6, false, "a button showing the game's alert should not glow")
buttons[6].SpellActivationAlert.shown = false
fire("PLAYER_TARGET_CHANGED")
advance(0)
expectGlow(6, true, "a button whose game alert is gone should glow")
change(state(6, false, false))
pause()

-- =========================
-- Stealth
-- =========================
-- Ghostly Strike out of stealth frees Ambush and Garrote.
change(state(3, true, false), state(4, true, false))
advance(0.2)
expectGlow(3, true, "Ambush should glow out of stealth after Ghostly Strike")
expectGlow(4, true, "Garrote from a macro should glow out of stealth after Ghostly Strike")

player.stealthed = true
fire("UPDATE_STEALTH")
expectGlow(3, false, "nothing should glow while stealthed")
player.stealthed = false
fire("UPDATE_STEALTH")
expectGlow(3, true, "the proc should glow again after stealth")
change(state(3, false, false), state(4, false, false))
advance(0.5)
expectGlow(3, false, "Ambush should stop glowing when Ghostly Strike wears off")
pause()

-- Stealth itself frees the openers, which stay quiet.
player.stealthed = true
fire("UPDATE_STEALTH")
change(state(3, true, false), state(4, true, false), state(17, true, false))
advance(0.2)
expectGlow(3, false, "Ambush should not glow in normal stealth")
player.stealthed = false
fire("UPDATE_STEALTH")
change(state(3, false, false), state(4, false, false), state(17, false, false))
advance(0.5)
expectGlow(3, false, "Ambush should stay quiet when stealth ends")
expectGlow(17, false, "Shadowstrike should stay quiet when stealth ends")
pause()

-- Opening with Ghostly Strike from stealth: the openers never stop being
-- usable, so no change arrives for them.
player.stealthed = true
fire("UPDATE_STEALTH")
change(state(3, true, false), state(4, true, false), state(17, true, false))
advance(0.2)
player.stealthed = false
fire("UPDATE_STEALTH")
advance(0.1)
expectGlow(3, false, "the openers should wait a moment after stealth ends")
advance(0.3)
expectGlow(3, true, "Ambush still usable after stealth should glow")
expectGlow(4, true, "Garrote still usable after stealth should glow")
expectGlow(17, true, "a spell learned as a stealth opener should glow the same way")
change(state(3, false, false), state(4, false, false), state(17, false, false))
expectGlow(17, false, "the learned opener should stop when it's blocked")
pause()

-- =========================
-- Target, page swaps and hidden buttons
-- =========================
change(state(1, true, false))
advance(0.2)
expectGlow(1, true, "Riposte should glow again")
target.dead = true
fire("UNIT_HEALTH", "target")
expectGlow(1, false, "a dead target should hide the glow")
target.dead = false
fire("UNIT_HEALTH", "target")
expectGlow(1, true, "a living target should bring it back")
target.exists = false
fire("PLAYER_TARGET_CHANGED")
advance(0)
expectGlow(1, false, "no target should hide the glow")
target.exists = true
fire("PLAYER_TARGET_CHANGED")
advance(0)
expectGlow(1, true, "a new target should show the glow again")

local plays = glow.StartAnim.plays
buttons[1].action = 13
fire("ACTIONBAR_PAGE_CHANGED")
advance(0)
expectGlow(1, false, "a button showing an item should not glow")
buttons[1].action = 1
fire("ACTIONBAR_PAGE_CHANGED")
advance(0)
expectGlow(1, true, "the glow should follow Riposte back to its button")
assertEqual(glow.StartAnim.plays, plays + 1, "a glow that comes back should burst again")

glow.StartAnim:Finish()
SetShown(buttons[1], false)
assertTrue(not glow.LoopAnim.playing, "a hidden button's glow should stop animating")
SetShown(buttons[1], true)
assertTrue(glow.LoopAnim.playing, "a button shown again should loop at once")
assertTrue(not glow.StartAnim.playing, "a button shown again should skip the burst")

-- Values the game hides are left alone.
change({ slot = 1, usable = SECRET, noMana = SECRET })
expectGlow(1, true, "a hidden usability should change nothing")

-- =========================
-- Turning it off
-- =========================
CarpenterDB.procGlowEnabled = false
feature:Disable()
expectGlow(1, false, "turning off should hide every glow")
assertEqual(next(events.events), nil, "turning off should drop every event")

CarpenterDB.procGlowEnabled = true
feature:Enable()
advance(0.5)
expectGlow(1, false, "turning on again should start from the slots as they are")

print("proc-glow fixtures passed")
