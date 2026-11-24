--[[ Carpenter - Proc Glow ]]
-- Plays the game's proc glow on an action button while a reactive ability is
-- usable: Riposte after a parry, Overpower after a dodge, Execute on a low
-- target, or Ambush and Garrote out of stealth after Ghostly Strike.
--
-- The abilities are the ones ClassicSpellActivations and
-- SpellActivationOverlay glow for being usable on Classic and WoW Forever.
-- Each of them is unusable until its proc, so the glow follows the game's
-- own answer for the slot: usable, not just short on energy, rage or mana,
-- and not on a cooldown of its own. The global cooldown doesn't count.
-- Buff procs such as Nightfall and Clearcasting light up their spells the
-- same way while the buff is up.
--
-- The game's own alert (ActionButtonSpellAlertManager) taints the action
-- buttons when addon code calls it. The glow here is Carpenter's own frame,
-- built out of combat from the same atlases and flipbooks.

local FEATURE_KEY = "procGlowEnabled"

local Secret = Carpenter and Carpenter.Secret

-- Matched by name too, so every rank counts.
local REACTIVE_SPELL_IDS = {
    -- Warrior
    7384, -- Overpower: the target dodged
    6572, -- Revenge: you blocked, dodged or parried
    5308, -- Execute: the target is below 20% health
    34428, -- Victory Rush: you killed an enemy (TBC)
    402927, -- Victory Rush (WoW Forever)
    29801, -- Rampage: you scored a critical hit (TBC)
    -- Rogue
    14251, -- Riposte: you parried
    -- Hunter
    19306, -- Counterattack: you parried
    1495, -- Mongoose Bite: the target dodged
    34026, -- Kill Command: your pet scored a critical hit (TBC)
    -- Paladin
    24275, -- Hammer of Wrath: the target is below 20% health
}

-- Usable in stealth anyway, so they only glow out of it, as Ghostly Strike
-- allows on WoW Forever.
local STEALTH_OPENER_IDS = {
    8676, -- Ambush
    703, -- Garrote
}

-- Buffs that make spells free or instant, and the spells they light up.
-- WoW Forever hides the player's buffs in combat, but the game announces
-- these with SPELL_ACTIVATION_OVERLAY_SHOW and _HIDE, which
-- SpellActivationOverlay also follows there. Where buffs can be read, they
-- are read as well. Heals light up without an enemy target.
local BUFF_PROCS = {
    { buff = 17941, spells = { 686 } }, -- Shadow Trance from Nightfall: Shadow Bolt
    { buff = 34754, spells = { 2061, 32546, 2060 }, heal = true }, -- Priest's Clearcasting (TBC): Flash Heal, Binding Heal, Greater Heal
}

local MAX_ACTION_SLOT = 180
-- The global cooldown runs at most this long, so a longer one is the spell's
-- own. A glow waiting out a cooldown checks again this often.
local GLOBAL_COOLDOWN_MAX = 1.5
local COOLDOWN_CHECK_DELAY = 0.25

-- ActionButtonSpellAlertTemplate's art and timing.
local START_ATLAS = "UI-HUD-ActionBar-Proc-Start-Flipbook"
local LOOP_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local START_SIZE = 150
local ALERT_SCALE = 1.4
local START_DURATION = 0.7
local LOOP_DURATION = 1
local FLIPBOOK_ROWS = 6
local FLIPBOOK_COLUMNS = 5
local FLIPBOOK_FRAMES = 30

-- These move spells between buttons.
local REMAP_EVENTS = {
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORM",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_POSSESS_BAR",
}

-- These change whether a tracked spell glows.
local REFRESH_EVENTS = {
    "ACTION_USABLE_CHANGED",
    "SPELL_UPDATE_USABLE",
    "SPELL_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_COOLDOWN",
    "UPDATE_STEALTH",
    "PLAYER_TARGET_CHANGED",
}

local active = false

-- [slot] = { spellID, reactive, opener, buffs, heal, ready, onCooldown } for
-- slots holding a tracked spell.
local slots = {}
local reactiveNames = {}
local openerNames = {}
-- [spell ID or name] = { buff = true, ... } and the heal flag, from BUFF_PROCS.
local buffsBySpellID = {}
local buffsByName = {}
local healSpellIDs = {}
local healNames = {}
-- [buff ID] = true while the buff is up.
local activeBuffs = {}
local trackedBuffs = {}
for _, proc in ipairs(BUFF_PROCS) do trackedBuffs[proc.buff] = true end
-- Spells the game is glowing itself, from its overlay events.
local blizzardGlowSpells = {}
local glowFrames = setmetatable({}, { __mode = "k" })

local eventFrame = CreateFrame("Frame")

local function ReadBool(func, ...)
    return Secret.ReadableBool(func, ...)
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() == true
end

local function IDSet(spellIDs)
    local set = {}
    for _, spellID in ipairs(spellIDs) do set[spellID] = true end
    return set
end

local reactiveIDs = IDSet(REACTIVE_SPELL_IDS)
local openerIDs = IDSet(STEALTH_OPENER_IDS)

-- =========================
-- Spells and slots
-- =========================
local function SpellName(spellID)
    local getName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(getName) ~= "function" then return nil end
    local ok, name = pcall(getName, spellID)
    if not ok then return nil end
    return Secret.ReadableString(name)
end

local function NameSet(spellIDs)
    local names = {}
    for _, spellID in ipairs(spellIDs) do
        local name = SpellName(spellID)
        if name then names[name] = true end
    end
    return names
end

local function AddBuff(map, key, buffID)
    map[key] = map[key] or {}
    map[key][buffID] = true
end

local function ReadSpellNames()
    reactiveNames = NameSet(REACTIVE_SPELL_IDS)
    openerNames = NameSet(STEALTH_OPENER_IDS)
    buffsBySpellID, buffsByName, healSpellIDs, healNames = {}, {}, {}, {}
    for _, proc in ipairs(BUFF_PROCS) do
        for _, spellID in ipairs(proc.spells) do
            AddBuff(buffsBySpellID, spellID, proc.buff)
            if proc.heal then healSpellIDs[spellID] = true end
            local name = SpellName(spellID)
            if name then
                AddBuff(buffsByName, name, proc.buff)
                if proc.heal then healNames[name] = true end
            end
        end
    end
end

-- The spell a slot casts: a spell, or a macro that shows one.
local function ActionSpellID(slot)
    if type(GetActionInfo) ~= "function" then return nil end
    local ok, actionType, id, subType = pcall(GetActionInfo, slot)
    if not ok or Secret.IsSecret(actionType) or Secret.IsSecret(subType) then return nil end
    if actionType == "spell" or (actionType == "macro" and subType == "spell") then
        return Secret.ReadableNumber(id)
    end
    return nil
end

local function ReadSlot(slot)
    local spellID = ActionSpellID(slot)
    if not spellID then
        slots[slot] = nil
        return
    end
    local name = SpellName(spellID)
    local opener = openerIDs[spellID] or (name ~= nil and openerNames[name] == true)
    local reactive = reactiveIDs[spellID] or (name ~= nil and reactiveNames[name] == true)
    local buffs = buffsBySpellID[spellID] or (name ~= nil and buffsByName[name]) or nil
    if not reactive and not opener and not buffs then
        slots[slot] = nil
        return
    end
    local state = slots[slot]
    if not state or state.spellID ~= spellID then
        slots[slot] = {
            spellID = spellID,
            reactive = reactive == true,
            opener = opener == true,
            buffs = buffs,
            heal = healSpellIDs[spellID] or (name ~= nil and healNames[name] == true),
        }
    end
end

local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Where the game lets addons see the player's buffs: always on Classic, and
-- out of combat on WoW Forever. In combat there the overlay events decide.
local function ReadBuffs()
    if type(GetPlayerAuraBySpellID) ~= "function" then return end
    if Secret.ClientHidesValues() and InCombat() then return end
    for buffID in pairs(trackedBuffs) do
        local ok, aura = pcall(GetPlayerAuraBySpellID, buffID)
        if ok and not Secret.IsSecret(aura) then
            activeBuffs[buffID] = aura ~= nil or nil
        end
    end
end

local function HasActiveBuff(buffs)
    if not buffs then return false end
    for buffID in pairs(buffs) do
        if activeBuffs[buffID] then return true end
    end
    return false
end

local function ReadAllSlots()
    for slot = 1, MAX_ACTION_SLOT do
        ReadSlot(slot)
    end
end

local IsUsableAction = (C_ActionBar and C_ActionBar.IsUsableAction) or _G.IsUsableAction

-- Usable right now. Short on power, blocked or hidden all count as no.
local function IsUsable(slot)
    if type(IsUsableAction) ~= "function" then return false end
    local ok, usable = pcall(IsUsableAction, slot)
    if not ok or Secret.IsSecret(usable) then return false end
    return usable == true
end

local GetActionCooldown = (C_ActionBar and C_ActionBar.GetActionCooldown) or _G.GetActionCooldown

local function IsOwnCooldown(startTime, duration)
    startTime = Secret.ReadableNumber(startTime)
    duration = Secret.ReadableNumber(duration)
    if not startTime or not duration then return nil end
    return startTime > 0 and duration > GLOBAL_COOLDOWN_MAX
end

-- Whether a slot's spell is on its own cooldown rather than just the global
-- one: true, false, or nil when the game hides it. In combat Retail and
-- WoW Forever hide the times, but never isActive or isOnGCD.
local function ReadCooldown(slot)
    if type(GetActionCooldown) ~= "function" then return false end
    local ok, info, duration = pcall(GetActionCooldown, slot)
    if not ok or Secret.IsSecret(info) then return nil end
    if type(info) ~= "table" then
        return IsOwnCooldown(info, duration)
    end

    local isActive = info.isActive
    if Secret.IsSecret(isActive) then return nil end
    if isActive == nil then
        return IsOwnCooldown(info.startTime, info.duration)
    end
    if isActive ~= true then return false end

    duration = Secret.ReadableNumber(info.duration)
    if duration then return duration > GLOBAL_COOLDOWN_MAX end
    local onGlobalCooldown = info.isOnGCD
    if Secret.IsSecret(onGlobalCooldown) or type(onGlobalCooldown) ~= "boolean" then return nil end
    return not onGlobalCooldown
end

-- =========================
-- Glow frames
-- =========================
local function IsForbidden(frame)
    if type(frame.IsForbidden) ~= "function" then return false end
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    return not ok or forbidden == true
end

local function AddAlpha(group, region, order, duration, fromAlpha, toAlpha)
    local animation = group:CreateAnimation("Alpha")
    animation:SetTarget(region)
    animation:SetOrder(order)
    animation:SetDuration(duration)
    animation:SetFromAlpha(fromAlpha)
    animation:SetToAlpha(toAlpha)
    return animation
end

local function AddFlipBook(group, region, order, duration)
    local animation = group:CreateAnimation("FlipBook")
    animation:SetTarget(region)
    animation:SetOrder(order)
    animation:SetDuration(duration)
    animation:SetFlipBookRows(FLIPBOOK_ROWS)
    animation:SetFlipBookColumns(FLIPBOOK_COLUMNS)
    animation:SetFlipBookFrames(FLIPBOOK_FRAMES)
    animation:SetFlipBookFrameWidth(0)
    animation:SetFlipBookFrameHeight(0)
    return animation
end

local function FitGlow(glow, button)
    local ok, width, height = pcall(button.GetSize, button)
    width = ok and Secret.ReadableNumber(width) or nil
    height = ok and Secret.ReadableNumber(height) or nil
    if width and height and width > 0 and height > 0 then
        glow:SetSize(width * ALERT_SCALE, height * ALERT_SCALE)
    end
end

-- The same layers and animations as ActionButtonSpellAlertTemplate: a burst
-- that plays once, then the marching loop.
local function CreateGlow(button)
    local glow = CreateFrame("Frame", nil, button)
    glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    FitGlow(glow, button)
    glow:Hide()

    local start = glow:CreateTexture(nil, "ARTWORK")
    start:SetAtlas(START_ATLAS)
    start:SetSize(START_SIZE, START_SIZE)
    start:SetPoint("CENTER", glow, "CENTER", 0, 0)
    start:SetAlpha(1)

    local loop = glow:CreateTexture(nil, "ARTWORK")
    loop:SetAtlas(LOOP_ATLAS)
    loop:SetAllPoints(glow)
    loop:SetAlpha(0)

    local loopAnim = glow:CreateAnimationGroup()
    loopAnim:SetLooping("REPEAT")
    AddAlpha(loopAnim, start, 0, 0.001, 0.01, 0)
    AddAlpha(loopAnim, loop, 1, 0.001, 1, 1)
    AddFlipBook(loopAnim, loop, 2, LOOP_DURATION)

    local startAnim = glow:CreateAnimationGroup()
    startAnim:SetToFinalAlpha(true)
    AddAlpha(startAnim, start, 0, 0.001, 1, 1)
    AddFlipBook(startAnim, start, 1, START_DURATION)
    AddAlpha(startAnim, start, 2, 0.001, 1, 0)

    startAnim:SetScript("OnFinished", function()
        glow.starting = false
        if glow.active then loopAnim:Play() end
    end)
    -- A button hidden and shown again, as a bar page swap does, skips the
    -- burst and goes straight back to the loop.
    glow:SetScript("OnHide", function()
        startAnim:Stop()
        loopAnim:Stop()
        glow.starting = false
    end)
    glow:SetScript("OnShow", function()
        if glow.active and not glow.starting and not loopAnim:IsPlaying() then
            loopAnim:Play()
        end
    end)

    glow.Start = start
    glow.Loop = loop
    glow.StartAnim = startAnim
    glow.LoopAnim = loopAnim
    return glow
end

local function ForEachActionButton(callback)
    local registry = _G.ActionBarButtonEventsFrame
    local frames = type(registry) == "table" and registry.frames
    if type(frames) ~= "table" then return end
    for _, button in pairs(frames) do
        if type(button) == "table" then callback(button) end
    end
end

local function SetGlow(button, shown)
    local glow = glowFrames[button]
    if not glow then return end

    if shown then
        if glow.active then return end
        glow.active = true
        FitGlow(glow, button)
        glow.starting = true
        glow:Show()
        if glow:IsVisible() then
            glow.LoopAnim:Stop()
            glow.StartAnim:Play()
        else
            glow.starting = false
        end
    elseif glow.active then
        glow.active = false
        glow.starting = false
        glow.StartAnim:Stop()
        glow.LoopAnim:Stop()
        glow:Hide()
    end
end

local function HideAllGlows()
    for button in pairs(glowFrames) do
        SetGlow(button, false)
    end
end

-- =========================
-- Which buttons glow
-- =========================
local IsSpellOverlayed = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or _G.IsSpellOverlayed

local function BlizzardGlows(button, spellID)
    if blizzardGlowSpells[spellID] then return true end
    if type(IsSpellOverlayed) == "function" and ReadBool(IsSpellOverlayed, spellID) then return true end
    local alert = button.SpellActivationAlert
    if type(alert) == "table" and type(alert.IsShown) == "function" then
        return ReadBool(alert.IsShown, alert) == true
    end
    return false
end

-- Every one of these is an attack, so a dead or missing target hides the
-- glow until there is someone to use it on.
local function HasLivingTarget()
    if ReadBool(UnitExists, "target") == false then return false end
    return ReadBool(UnitIsDeadOrGhost, "target") ~= true
end

local RefreshButtons

-- The game says when a cooldown starts, not always when it ends, so a glow
-- waiting on one looks again until it's over.
local cooldownCheckScheduled = false
local function CheckCooldownsSoon()
    if cooldownCheckScheduled then return end
    cooldownCheckScheduled = true
    Carpenter:After(COOLDOWN_CHECK_DELAY, function()
        cooldownCheckScheduled = false
        RefreshButtons()
    end)
end

-- Reads each tracked slot. A hidden cooldown keeps the last answer, which a
-- cooldown starting showed.
local function ReadSlotStates(stealthed)
    local waiting = false
    for slot, state in pairs(slots) do
        local lit = state.reactive or (state.opener and not stealthed) or HasActiveBuff(state.buffs)
        state.ready = lit and IsUsable(slot)
        if state.ready then
            local onCooldown = ReadCooldown(slot)
            if onCooldown ~= nil then state.onCooldown = onCooldown end
            if state.onCooldown then waiting = true end
        else
            state.onCooldown = nil
        end
    end
    if waiting then CheckCooldownsSoon() end
end

local function ShouldGlow(button, targetAlive)
    local slot = Secret.ReadableNumber(button.action)
    local state = slot and slots[slot]
    if not state or not state.ready or state.onCooldown then return false end
    if not targetAlive and not state.heal then return false end
    return not BlizzardGlows(button, state.spellID)
end

RefreshButtons = function()
    if not active then return end
    ReadSlotStates(ReadBool(IsStealthed) == true)
    local targetAlive = HasLivingTarget()
    ForEachActionButton(function(button)
        if glowFrames[button] then
            SetGlow(button, ShouldGlow(button, targetAlive))
        end
    end)
end

-- After the game's own handlers have moved spells between buttons.
local refreshScheduled = false
local function RefreshSoon()
    if refreshScheduled then return end
    refreshScheduled = true
    Carpenter:After(0, function()
        refreshScheduled = false
        RefreshButtons()
    end)
end

local function BuildGlowFrames()
    if not active then return end
    if InCombat() then
        Carpenter:AfterCombat("procGlowFrames", BuildGlowFrames)
        return
    end
    ForEachActionButton(function(button)
        if not glowFrames[button] and not IsForbidden(button) then
            glowFrames[button] = CreateGlow(button)
        end
    end)
    RefreshButtons()
end

-- =========================
-- Events
-- =========================
local function SetGameGlow(spellID, shown)
    spellID = Secret.ReadableNumber(spellID)
    if not spellID then return end
    blizzardGlowSpells[spellID] = shown or nil
    RefreshButtons()
end

-- The game's own overlay for a proc buff, the way WoW Forever announces them.
-- A hide without a spell clears them all.
local function SetOverlayBuff(spellID, shown)
    if spellID == nil and not shown then
        activeBuffs = {}
        ReadBuffs()
        RefreshButtons()
        return
    end
    spellID = Secret.ReadableNumber(spellID)
    if not spellID or not trackedBuffs[spellID] then return end
    activeBuffs[spellID] = shown or nil
    RefreshButtons()
end

local function OnSlotChanged(slot)
    slot = Secret.ReadableNumber(slot)
    if slot and slot > 0 then
        ReadSlot(slot)
    else
        ReadAllSlots()
    end
    RefreshSoon()
end

-- Only a target dying or coming back changes what glows.
local lastTargetAlive
local function OnTargetHealth()
    local alive = HasLivingTarget()
    if alive ~= lastTargetAlive then
        lastTargetAlive = alive
        RefreshButtons()
    end
end

local refreshEvents = {}
for _, event in ipairs(REFRESH_EVENTS) do refreshEvents[event] = true end
local remapEvents = {}
for _, event in ipairs(REMAP_EVENTS) do remapEvents[event] = true end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not active then return end

    if event == "ACTIONBAR_SLOT_CHANGED" then
        OnSlotChanged(...)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        SetGameGlow(..., true)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        SetGameGlow(..., false)
    elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        SetOverlayBuff(..., true)
    elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        SetOverlayBuff(..., false)
    elseif event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" then
        ReadBuffs()
        RefreshButtons()
    elseif event == "UNIT_HEALTH" then
        OnTargetHealth()
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        if next(reactiveNames) == nil then ReadSpellNames() end
        ReadAllSlots()
        if event == "PLAYER_ENTERING_WORLD" then BuildGlowFrames() end
        RefreshSoon()
    elseif remapEvents[event] then
        RefreshSoon()
    elseif refreshEvents[event] then
        RefreshButtons()
    end
end)

local function RegisterEvents()
    local register = function(event) Carpenter:SafeRegisterEvent(eventFrame, event) end
    register("ACTIONBAR_SLOT_CHANGED")
    register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    register("SPELL_ACTIVATION_OVERLAY_SHOW")
    register("SPELL_ACTIVATION_OVERLAY_HIDE")
    register("PLAYER_REGEN_ENABLED")
    register("SPELLS_CHANGED")
    register("PLAYER_ENTERING_WORLD")
    for _, event in ipairs(REFRESH_EVENTS) do register(event) end
    for _, event in ipairs(REMAP_EVENTS) do register(event) end
    Carpenter:SafeRegisterUnitEvent(eventFrame, "UNIT_HEALTH", "target")
    Carpenter:SafeRegisterUnitEvent(eventFrame, "UNIT_AURA", "player")
end

-- =========================
-- Feature
-- =========================
local feature = {}

function feature:Enable()
    active = true
    RegisterEvents()
    ReadSpellNames()
    ReadAllSlots()
    ReadBuffs()
    lastTargetAlive = HasLivingTarget()
    BuildGlowFrames()
    RefreshButtons()
end

function feature:Disable()
    active = false
    eventFrame:UnregisterAllEvents()
    Carpenter:CancelAfterCombat("procGlowFrames")
    slots = {}
    activeBuffs = {}
    HideAllGlows()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
