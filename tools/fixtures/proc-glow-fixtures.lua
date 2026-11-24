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
    [7384] = "Overpower",
    [14183] = "Premeditation",
    [5308] = "Execute",
    [20658] = "Execute", -- rank 2
    [1784] = "Stealth",
    [686] = "Shadow Bolt",
    [1106] = "Shadow Bolt", -- rank 5
    [5143] = "Arcane Missiles",
    [2061] = "Flash Heal",
    [133] = "Fireball",
}
C_Spell = { GetSpellName = function(spellID) return names[spellID] end }

-- [buff ID] = aura data, or an error while the game hides auras.
local auras = {}
local aurasHidden = false
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        if aurasHidden then error("Auras cannot be accessed when secret while tainted") end
        return auras[spellID]
    end,
}

-- [slot] = { type, id, subType }
local actions = {
    [1] = { "spell", 14251 },
    [2] = { "spell", 1752 },
    [3] = { "spell", 8676 },
    [4] = { "macro", 703, "spell" },
    [5] = { "spell", 2098 },
    [6] = { "spell", 7384 },
    [7] = { "spell", 14183 },
    [8] = { "spell", 20658 },
    [9] = { "spell", 1106 },
    [10] = { "spell", 5143 },
    [11] = { "spell", 2061 },
    [12] = { "spell", 133 },
    [13] = { "item", 5512 },
    [14] = { "spell", 1784 },
}

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
-- [slot] = SpellCooldownInfo. Off cooldown unless set otherwise.
local cooldowns = {}
C_ActionBar = {
    IsUsableAction = function(slot)
        local state = usability[slot]
        if state then return state[1], state[2] end
        return false, false
    end,
    GetActionCooldown = function(slot)
        return cooldowns[slot] or { startTime = 0, duration = 0, isEnabled = true, isActive = false }
    end,
}

local overlayed = {}
C_SpellActivationOverlay = { IsSpellOverlayed = function(spellID) return overlayed[spellID] == true end }

local player = { stealthed = false }
local target = { exists = true, dead = false }
IsStealthed = function() return player.stealthed end
UnitExists = function(unit)
    if unit == "target" then return target.exists end
    return unit == "player"
end
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
for slot = 1, 14 do
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

local function startCooldown(slot, duration, fields)
    cooldowns[slot] = { startTime = now, duration = duration, isEnabled = true, isActive = true, isOnGCD = false }
    for key, value in pairs(fields or {}) do cooldowns[slot][key] = value end
    fire("SPELL_UPDATE_COOLDOWN")
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
expectGlow(1, false, "nothing should glow while nothing is usable")

-- =========================
-- Reactive abilities
-- =========================
change(state(1, true, false))
expectGlow(1, true, "Riposte should glow once a parry makes it usable")
assertTrue(glow.StartAnim.playing, "the glow should open with the burst")
assertTrue(not glow.LoopAnim.playing, "the loop should wait for the burst")
glow.StartAnim:Finish()
assertTrue(glow.LoopAnim.playing, "the loop should follow the burst")

change(state(1, false, false))
expectGlow(1, false, "Riposte should stop glowing once it's unusable again")
assertTrue(not glow.LoopAnim.playing and glow.shown == false, "a stopped glow should hide and stop animating")

-- Short on energy is not usable; the glow waits for the energy.
change(state(1, false, true))
expectGlow(1, false, "Riposte short on energy should not glow")
change(state(1, true, false))
expectGlow(1, true, "Riposte should glow once the energy is there")
change(state(1, false, false))

change(state(6, true, false))
expectGlow(6, true, "Overpower should glow after a dodge")
change(state(6, false, false))

change(state(8, true, false))
expectGlow(8, true, "a higher rank of Execute should glow by its name")
change(state(8, false, false))

-- Everything else stays dark, however it becomes usable.
change(state(2, true, false), state(5, true, false), state(7, true, false), state(14, true, false))
expectGlow(2, false, "energy coming back should not light up Sinister Strike")
expectGlow(5, false, "Eviscerate should never glow")
expectGlow(7, false, "Premeditation should never glow")
expectGlow(14, false, "Stealth should never glow")
change(state(2, false, true), state(5, false, false), state(7, false, false))

-- =========================
-- Cooldowns
-- =========================
change(state(1, true, false))
expectGlow(1, true, "Riposte should glow before it's used")
startCooldown(1, 6)
expectGlow(1, false, "Riposte on its own cooldown should not glow")
cooldowns[1] = nil
advance(0.3)
expectGlow(1, true, "the glow should come back once the cooldown is over, even without an event")

startCooldown(1, 1)
expectGlow(1, true, "the global cooldown should not hide the glow")
cooldowns[1] = nil

-- In combat the times are hidden, but isActive and isOnGCD aren't.
startCooldown(1, SECRET, { startTime = SECRET })
expectGlow(1, false, "a hidden cooldown that isn't the global one should hide the glow")
cooldowns[1].isOnGCD = nil
advance(0.3)
expectGlow(1, false, "a cooldown with nothing readable should keep the last answer")
startCooldown(1, SECRET, { startTime = SECRET, isOnGCD = true })
expectGlow(1, true, "a hidden global cooldown should not hide the glow")
cooldowns[1] = nil
change(state(1, false, false))
advance(1)

-- =========================
-- The game's own glow
-- =========================
change(state(6, true, false))
expectGlow(6, true, "Overpower should glow")
fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)
expectGlow(6, false, "a spell the game glows itself should keep only the game's glow")
fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 7384)
expectGlow(6, true, "the glow should come back when the game's stops")

overlayed[7384] = true
fire("PLAYER_TARGET_CHANGED")
expectGlow(6, false, "a spell the game reports as overlayed should not glow")
overlayed[7384] = nil
buttons[6].SpellActivationAlert = H.Frame({ shown = true })
fire("PLAYER_TARGET_CHANGED")
expectGlow(6, false, "a button showing the game's alert should not glow")
buttons[6].SpellActivationAlert.shown = false
fire("PLAYER_TARGET_CHANGED")
expectGlow(6, true, "a button whose game alert is gone should glow")
change(state(6, false, false))

-- =========================
-- Stealth openers
-- =========================
player.stealthed = true
fire("UPDATE_STEALTH")
change(state(3, true, false), state(4, true, false), state(7, true, false))
expectGlow(3, false, "Ambush should not glow in stealth")
expectGlow(4, false, "Garrote should not glow in stealth")

-- Ghostly Strike from stealth keeps them usable after stealth ends.
player.stealthed = false
fire("UPDATE_STEALTH")
expectGlow(3, true, "Ambush still usable out of stealth should glow")
expectGlow(4, true, "Garrote from a macro still usable out of stealth should glow")
expectGlow(7, false, "Premeditation still usable out of stealth should not glow")

player.stealthed = true
fire("UPDATE_STEALTH")
expectGlow(3, false, "the openers should go quiet when stealth starts again")
player.stealthed = false
fire("UPDATE_STEALTH")
expectGlow(3, true, "the openers should glow again after stealth")
change(state(3, false, false), state(4, false, false), state(7, false, false))
expectGlow(3, false, "Ambush should stop glowing when Ghostly Strike wears off")

-- Riposte isn't an opener, so stealth doesn't hide it.
player.stealthed = true
fire("UPDATE_STEALTH")
change(state(1, true, false))
expectGlow(1, true, "Riposte should still glow in stealth")
player.stealthed = false
fire("UPDATE_STEALTH")

-- =========================
-- Target, slots, page swaps and hidden buttons
-- =========================
target.dead = true
fire("UNIT_HEALTH", "target")
expectGlow(1, false, "a dead target should hide the glow")
target.dead = false
fire("UNIT_HEALTH", "target")
expectGlow(1, true, "a living target should bring it back")
target.exists = false
fire("PLAYER_TARGET_CHANGED")
expectGlow(1, false, "no target should hide the glow")
target.exists = true
fire("PLAYER_TARGET_CHANGED")
expectGlow(1, true, "a new target should show the glow again")

-- Riposte dragged onto the item's slot glows there too.
actions[13] = { "spell", 14251 }
fire("ACTIONBAR_SLOT_CHANGED", 13)
advance(0)
expectGlow(13, true, "a slot that now holds Riposte should glow")
actions[13] = { "item", 5512 }
fire("ACTIONBAR_SLOT_CHANGED", 13)
advance(0)
expectGlow(13, false, "a slot holding an item again should stop glowing")

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

-- An answer the game hides counts as unusable, without an error.
usability[1] = { SECRET, SECRET }
change({ slot = 1, usable = SECRET, noMana = SECRET })
expectGlow(1, false, "a hidden usability should not glow")
change(state(1, true, false))
expectGlow(1, true, "a readable usability should glow again")

-- =========================
-- Buff procs
-- =========================
change(state(1, false, false))
change(state(9, true, false), state(10, true, false), state(11, true, false), state(12, true, false))
expectGlow(9, false, "Shadow Bolt should not glow without Nightfall")
expectGlow(10, false, "Arcane Missiles should not glow without Clearcasting")

-- In combat on WoW Forever the game announces Nightfall with its overlay.
inCombat = true
aurasHidden = true
fire("SPELL_ACTIVATION_OVERLAY_SHOW", 17941, 132125, "LEFT", 1, 255, 255, 255)
expectGlow(9, true, "Shadow Bolt of any rank should glow while Shadow Trance is up")
expectGlow(12, false, "Fireball should not glow for Nightfall")
fire("UNIT_AURA", "player")
expectGlow(9, true, "a hidden aura in combat should leave the overlay's answer alone")
aurasHidden = false
fire("UNIT_AURA", "player")
expectGlow(9, true, "in combat the buffs shouldn't be read where the game hides them")
aurasHidden = true
change(state(9, false, true))
expectGlow(9, false, "Shadow Bolt without the mana for it should not glow")
change(state(9, true, false))
expectGlow(9, true, "Shadow Bolt should glow again with the mana back")
fire("SPELL_ACTIVATION_OVERLAY_HIDE", 17941)
expectGlow(9, false, "Shadow Bolt should stop glowing when Shadow Trance is used")
fire("SPELL_ACTIVATION_OVERLAY_SHOW", 99999, 132125, "LEFT", 1, 255, 255, 255)
expectGlow(9, false, "an overlay for another buff should light nothing")

-- The mage's Clearcasting works on any spell, so it lights no button.
fire("SPELL_ACTIVATION_OVERLAY_SHOW", 12536, 132125, "TOP", 1, 255, 255, 255)
expectGlow(10, false, "Arcane Missiles should not glow with the mage's Clearcasting")

fire("SPELL_ACTIVATION_OVERLAY_SHOW", 17941, 132125, "LEFT", 1, 255, 255, 255)
expectGlow(9, true, "Shadow Bolt should glow with Shadow Trance again")
fire("SPELL_ACTIVATION_OVERLAY_HIDE")
expectGlow(9, false, "a hide without a spell should clear every buff")

-- Heals light up without an enemy target.
fire("SPELL_ACTIVATION_OVERLAY_SHOW", 34754, 132125, "TOP", 1, 255, 255, 255)
target.exists = false
fire("PLAYER_TARGET_CHANGED")
expectGlow(11, true, "Flash Heal should glow with Clearcasting without a target")
fire("SPELL_ACTIVATION_OVERLAY_SHOW", 17941, 132125, "LEFT", 1, 255, 255, 255)
expectGlow(9, false, "Shadow Bolt should wait for a target")
target.exists = true
fire("PLAYER_TARGET_CHANGED")
expectGlow(9, true, "Shadow Bolt should glow once there's a target")

-- Out of combat the buffs can be read, which catches a buff gone while the
-- overlay events were missed.
inCombat = false
aurasHidden = false
auras[34754] = { spellId = 34754 }
fire("PLAYER_REGEN_ENABLED")
expectGlow(9, false, "Shadow Bolt should stop once leaving combat shows Shadow Trance is gone")
expectGlow(11, true, "Flash Heal should keep glowing while its Clearcasting is up")
auras[34754] = nil
auras[17941] = { spellId = 17941 }
auras[12536] = { spellId = 12536 }
fire("UNIT_AURA", "player")
expectGlow(11, false, "Flash Heal should stop when its Clearcasting is read as gone")
expectGlow(9, true, "a Shadow Trance read out of combat should light Shadow Bolt")
expectGlow(10, false, "a mage's Clearcasting read out of combat should light nothing")
auras[17941], auras[12536] = nil, nil
fire("UNIT_AURA", "player")
expectGlow(9, false, "Shadow Bolt should stop when Shadow Trance is read as gone")
change(state(9, false, false), state(10, false, false), state(11, false, false), state(12, false, false))

-- =========================
-- Turning it off
-- =========================
change(state(1, true, false))
expectGlow(1, true, "Riposte should glow before turning off")
CarpenterDB.procGlowEnabled = false
feature:Disable()
expectGlow(1, false, "turning off should hide every glow")
assertEqual(next(events.events), nil, "turning off should drop every event")

CarpenterDB.procGlowEnabled = true
feature:Enable()
expectGlow(1, true, "turning on again should glow what is usable now")

print("proc-glow fixtures passed")
