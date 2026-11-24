--[[ Carpenter - Proc Glow ]]
-- Plays the game's proc glow on an action button while a proc makes its
-- spell usable: Riposte after a parry, Overpower after a dodge, Execute on a
-- low target, or Ambush and Garrote out of stealth after Ghostly Strike.
--
-- The game reports each slot's usability in ACTION_USABLE_CHANGED: usable,
-- or not, and whether only power (mana, rage, energy) is missing. A spell
-- that isn't usable for any other reason is blocked. A blocked spell that
-- frees up has had a proc, unless something else explains it: a stance or
-- form, entering stealth, a new target, leaving combat, gear, bags, a pet, a
-- mount or crowd control. A spell that only waits on power is never blocked,
-- so power coming back never lights it up.
--
-- The game's own alert (ActionButtonSpellAlertManager) taints the action
-- buttons when addon code calls it. The glow here is Carpenter's own frame,
-- built out of combat from the same atlases and flipbooks.

local FEATURE_KEY = "procGlowEnabled"

local Secret = Carpenter and Carpenter.Secret

-- How long the events behind one change take to arrive. The slot's change and
-- the stance, stealth or target change that caused it come in either order.
local SETTLE_DELAY = 0.15
-- A state change this soon before a spell frees up explains it.
local EXPLAIN_WINDOW = 0.4
-- More spells than this freeing up at once is a state change the events
-- didn't name (crowd control ending, landing from a taxi), not a proc.
local MAX_PROCS_AT_ONCE = 4
-- A stealth opener still usable this long after stealth ends has a proc
-- behind it.
local STEALTH_EXIT_DELAY = 0.3
local MAX_ACTION_SLOT = 180

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

-- Stealth openers, matched by name so every rank counts. Entering stealth
-- frees them, so that never glows. Out of stealth only a proc frees them.
-- Spells seen freeing up as stealth starts are added while playing.
local STEALTH_OPENER_IDS = {
    8676, -- Ambush
    703, -- Garrote
    1833, -- Cheap Shot
    6770, -- Sap
    921, -- Pick Pocket
    14183, -- Premeditation
    9005, -- Pounce
    6785, -- Ravage
}

-- Spells that wait on something other than a proc, in a way the events can't
-- tell apart: finishing moves on combo points (Classic doesn't count those as
-- power), Judgement on the paladin's own Seal, and the spells Forbearance
-- locks until it wears off.
local NEVER_GLOW_IDS = {
    2098, -- Eviscerate
    5171, -- Slice and Dice
    1943, -- Rupture
    408, -- Kidney Shot
    8647, -- Expose Armor
    32645, -- Envenom
    26679, -- Deadly Throw
    22568, -- Ferocious Bite
    1079, -- Rip
    22570, -- Maim
    52610, -- Savage Roar
    20271, -- Judgement
    642, -- Divine Shield
    498, -- Divine Protection
    1022, -- Blessing of Protection
    633, -- Lay on Hands
    31884, -- Avenging Wrath
}

local function IDSet(spellIDs)
    local set = {}
    for _, spellID in ipairs(spellIDs) do set[spellID] = true end
    return set
end

local stealthOpenerIDs = IDSet(STEALTH_OPENER_IDS)
local neverGlowIDs = IDSet(NEVER_GLOW_IDS)

-- A change in any of these explains what frees up around it. Events that
-- also fire when nothing changed (forms, the pet bar) are left out; the
-- player's state shows those changes instead.
local EXPLAINING_EVENTS = {
    "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
    "LOSS_OF_CONTROL_ADDED",
    "LOSS_OF_CONTROL_UPDATE",
    "PLAYER_CONTROL_LOST",
    "PLAYER_CONTROL_GAINED",
    "CHARACTER_POINTS_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "TRAIT_CONFIG_UPDATED",
}

local EXPLAINING_PLAYER_EVENTS = {
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
}

-- These move spells between buttons. A real form change behind them shows
-- in the player's state.
local REMAP_EVENTS = {
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORM",
    "UPDATE_SHAPESHIFT_FORMS",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_POSSESS_BAR",
}

local active = false
local stealthed = false
local stealthEnteredAt
local lastExplainedAt
local lastEnvironment
local settleScheduled = false
local targetAlive = true

-- [slot] = { spellID, name, usable, noMana, blocked, armed, freedAt }
local slots = {}
local stealthOpenerNames = {}
local neverGlowNames = {}
local learnedStealthSpells = {}
local formSpells = {}
-- Spells the game is glowing itself, from its overlay events.
local blizzardGlowSpells = {}
local glowFrames = setmetatable({}, { __mode = "k" })

local eventFrame = CreateFrame("Frame")

local function Now()
    return GetTime and GetTime() or 0
end

local function ReadBool(func, ...)
    return Secret.ReadableBool(func, ...)
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() == true
end

local function Explain()
    lastExplainedAt = Now()
end

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

local function ReadSpellLists()
    stealthOpenerNames = NameSet(STEALTH_OPENER_IDS)
    neverGlowNames = NameSet(NEVER_GLOW_IDS)
end

local function ReadForms()
    formSpells = {}
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then return end
    local ok, count = pcall(GetNumShapeshiftForms)
    count = ok and Secret.ReadableNumber(count) or 0
    for index = 1, count do
        local okInfo, _, _, _, spellID = pcall(GetShapeshiftFormInfo, index)
        spellID = okInfo and Secret.ReadableNumber(spellID)
        if spellID then formSpells[spellID] = true end
    end
end

local function IsMountSpell(spellID)
    local getMount = C_MountJournal and C_MountJournal.GetMountFromSpell
    if type(getMount) ~= "function" then return false end
    local ok, mountID = pcall(getMount, spellID)
    return ok and not Secret.IsSecret(mountID) and mountID ~= nil
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

local IsUsableAction = (C_ActionBar and C_ActionBar.IsUsableAction) or _G.IsUsableAction

local function ReadUsable(slot)
    if type(IsUsableAction) ~= "function" then return nil end
    local ok, usable, noMana = pcall(IsUsableAction, slot)
    if not ok or Secret.IsSecret(usable) or Secret.IsSecret(noMana) then return nil end
    return usable == true, noMana == true
end

local function NewSlotState(spellID)
    return {
        spellID = spellID,
        name = SpellName(spellID),
        mount = IsMountSpell(spellID),
    }
end

-- Forms, mounts, finishers and Judgement free up for reasons that aren't
-- procs, such as walking outdoors or into water.
local function MayGlow(state)
    if formSpells[state.spellID] or state.mount or neverGlowIDs[state.spellID] then return false end
    return not (state.name and neverGlowNames[state.name])
end

local function IsStealthOpener(state)
    if learnedStealthSpells[state.spellID] or stealthOpenerIDs[state.spellID] then return true end
    return state.name ~= nil and stealthOpenerNames[state.name] == true
end

-- What the game says about a slot now. A spell that frees up waits for
-- Settle to decide whether a proc did it, unless quiet says the change is
-- already explained.
local function ApplyUsability(slot, usable, noMana, now, quiet)
    local state = slots[slot]
    if not state then return end
    local wasBlocked = state.blocked
    state.usable = usable
    state.noMana = noMana
    state.blocked = not usable and not noMana
    if state.blocked then
        state.armed = false
        state.freedAt = nil
    elseif wasBlocked and not quiet then
        state.freedAt = now
    end
end

local function ReadSlot(slot, now, quiet)
    local spellID = ActionSpellID(slot)
    if not spellID then
        slots[slot] = nil
        return
    end
    local usable, noMana = ReadUsable(slot)
    if usable == nil then return end

    local state = slots[slot]
    if not state or state.spellID ~= spellID then
        -- A spell new to the slot starts from what it is now.
        state = NewSlotState(spellID)
        state.usable = usable
        state.noMana = noMana
        state.blocked = not usable and not noMana
        slots[slot] = state
        return
    end
    ApplyUsability(slot, usable, noMana, now, quiet)
end

local function ReadAllSlots(quiet)
    local now = Now()
    for slot = 1, MAX_ACTION_SLOT do
        ReadSlot(slot, now, quiet)
    end
end

-- =========================
-- What explains a change
-- =========================
local function ReadNumber(func, ...)
    if type(func) ~= "function" then return 0 end
    local ok, value = pcall(func, ...)
    return ok and Secret.ReadableNumber(value) or 0
end

-- The player's situation in one string. Most of it has no event of its own,
-- so a change shows up as a different string.
local function ReadEnvironment()
    return table.concat({
        ReadNumber(GetShapeshiftForm),
        tostring(ReadBool(IsMounted)),
        tostring(ReadBool(IsFlying)),
        tostring(ReadBool(IsSwimming)),
        tostring(ReadBool(IsIndoors)),
        tostring(ReadBool(UnitInVehicle, "player")),
        tostring(ReadBool(UnitExists, "pet")),
        tostring(ReadBool(UnitIsDead, "pet")),
        tostring(ReadBool(UnitIsDeadOrGhost, "player")),
        tostring(ReadBool(HasFullControl)),
    }, ":")
end

local function NoteEnvironment()
    local environment = ReadEnvironment()
    if lastEnvironment and environment ~= lastEnvironment then
        Explain()
    end
    lastEnvironment = environment
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

-- Every proc spell is an attack, so a dead or missing target hides the glow
-- until there is someone to use it on.
local function HasLivingTarget()
    if ReadBool(UnitExists, "target") == false then return false end
    return ReadBool(UnitIsDeadOrGhost, "target") ~= true
end

local function ShouldGlow(button)
    local slot = Secret.ReadableNumber(button.action)
    local state = slot and slots[slot]
    if not state or not state.armed or not state.usable then return false end
    return not BlizzardGlows(button, state.spellID)
end

local function RefreshButtons()
    if not active then return end
    targetAlive = HasLivingTarget()
    local quiet = stealthed or not targetAlive
    ForEachActionButton(function(button)
        if glowFrames[button] then
            SetGlow(button, not quiet and ShouldGlow(button))
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
-- Deciding on procs
-- =========================
local Settle

local function ScheduleSettle()
    if settleScheduled then return end
    settleScheduled = true
    Carpenter:After(SETTLE_DELAY, function()
        settleScheduled = false
        Settle()
    end)
end

Settle = function()
    if not active then return end
    NoteEnvironment()

    local now = Now()
    local procs, procSpells, procCount = {}, {}, 0
    local waiting = false

    for _, state in pairs(slots) do
        local freedAt = state.freedAt
        if freedAt then
            if now - freedAt < SETTLE_DELAY - 0.01 then
                waiting = true
            else
                state.freedAt = nil
                local explained = lastExplainedAt ~= nil and lastExplainedAt >= freedAt - EXPLAIN_WINDOW
                if explained then
                    if stealthed and stealthEnteredAt and stealthEnteredAt >= freedAt - EXPLAIN_WINDOW then
                        learnedStealthSpells[state.spellID] = true
                    end
                elseif not state.blocked and MayGlow(state) then
                    procs[#procs + 1] = state
                    if not procSpells[state.spellID] then
                        procSpells[state.spellID] = true
                        procCount = procCount + 1
                    end
                end
            end
        end
    end

    if procCount <= MAX_PROCS_AT_ONCE then
        for _, state in ipairs(procs) do
            state.armed = true
        end
    end

    if waiting then ScheduleSettle() end
    RefreshButtons()
end

-- Leaving stealth blocks the openers again. One that stays usable has a proc
-- keeping it open, even if it never left the usable state to show it.
local function CheckStealthOpeners()
    if not active or stealthed then return end
    for slot, state in pairs(slots) do
        if not state.armed and IsStealthOpener(state) and MayGlow(state) then
            local usable, noMana = ReadUsable(slot)
            if usable ~= nil then
                state.usable = usable
                state.noMana = noMana
                state.blocked = not usable and not noMana
                if not state.blocked then
                    state.armed = true
                    state.freedAt = nil
                end
            end
        end
    end
    RefreshButtons()
end

local function ReadStealth()
    local now = ReadBool(IsStealthed) == true
    if now == stealthed then return end
    stealthed = now
    if now then
        stealthEnteredAt = Now()
        Explain()
    else
        Carpenter:After(STEALTH_EXIT_DELAY, CheckStealthOpeners)
    end
    RefreshButtons()
end

-- =========================
-- Events
-- =========================
local function OnUsableChanged(changes)
    if type(changes) ~= "table" then return end
    NoteEnvironment()
    local now = Now()
    for _, change in ipairs(changes) do
        local slot = type(change) == "table" and Secret.ReadableNumber(change.slot)
        if slot then
            local usable, noMana = change.usable, change.noMana
            if not slots[slot] then
                ReadSlot(slot, now)
            elseif not Secret.IsSecret(usable) and not Secret.IsSecret(noMana) then
                ApplyUsability(slot, usable == true, noMana == true, now)
            end
        end
    end
    ScheduleSettle()
    RefreshButtons()
end

-- A slot that changed starts over from what it holds now. The other slots
-- carry on: macros fire this as their shown spell changes.
local function OnSlotChanged(slot)
    slot = Secret.ReadableNumber(slot)
    if slot and slot > 0 then
        ReadSlot(slot, Now(), true)
    else
        ReadAllSlots(true)
    end
    RefreshSoon()
end

local function SetGameGlow(spellID, shown)
    spellID = Secret.ReadableNumber(spellID)
    if not spellID then return end
    blizzardGlowSpells[spellID] = shown or nil
    RefreshButtons()
end

local explainingEvents = {}
for _, event in ipairs(EXPLAINING_EVENTS) do explainingEvents[event] = true end
for _, event in ipairs(EXPLAINING_PLAYER_EVENTS) do explainingEvents[event] = true end
local remapEvents = {}
for _, event in ipairs(REMAP_EVENTS) do remapEvents[event] = true end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not active then return end

    if event == "ACTION_USABLE_CHANGED" then
        OnUsableChanged(...)
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        OnSlotChanged(...)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        SetGameGlow(..., true)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        SetGameGlow(..., false)
    elseif event == "UPDATE_STEALTH" then
        ReadStealth()
    elseif event == "UNIT_HEALTH" then
        -- Only a target dying or coming back changes what glows.
        if HasLivingTarget() ~= targetAlive then RefreshButtons() end
    elseif event == "SPELLS_CHANGED" then
        if next(neverGlowNames) == nil then ReadSpellLists() end
        ReadAllSlots()
        ScheduleSettle()
        RefreshSoon()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Explain()
        ReadStealth()
        ReadForms()
        ReadAllSlots(true)
        lastEnvironment = ReadEnvironment()
        BuildGlowFrames()
        RefreshSoon()
    elseif remapEvents[event] then
        if event == "UPDATE_SHAPESHIFT_FORMS" then ReadForms() end
        NoteEnvironment()
        ReadStealth()
        RefreshSoon()
    elseif event == "BAG_UPDATE" then
        -- Buying a missing reagent frees its spells. In combat the bags
        -- change with every arrow shot, so only outside of it.
        if not InCombat() then Explain() end
    elseif explainingEvents[event] then
        Explain()
        RefreshSoon()
    end
end)

local function RegisterEvents()
    local register = function(event) Carpenter:SafeRegisterEvent(eventFrame, event) end
    register("ACTION_USABLE_CHANGED")
    register("ACTIONBAR_SLOT_CHANGED")
    register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    register("UPDATE_STEALTH")
    register("SPELLS_CHANGED")
    register("PLAYER_ENTERING_WORLD")
    register("BAG_UPDATE")
    for _, event in ipairs(REMAP_EVENTS) do register(event) end
    for _, event in ipairs(EXPLAINING_EVENTS) do register(event) end
    for _, event in ipairs(EXPLAINING_PLAYER_EVENTS) do
        Carpenter:SafeRegisterUnitEvent(eventFrame, event, "player")
    end
    Carpenter:SafeRegisterUnitEvent(eventFrame, "UNIT_HEALTH", "target")
end

-- =========================
-- Feature
-- =========================
local feature = {}

function feature:Enable()
    active = true
    stealthed = ReadBool(IsStealthed) == true
    lastEnvironment = ReadEnvironment()
    RegisterEvents()
    ReadSpellLists()
    ReadForms()
    ReadAllSlots()
    BuildGlowFrames()
    RefreshButtons()
end

function feature:Disable()
    active = false
    eventFrame:UnregisterAllEvents()
    Carpenter:CancelAfterCombat("procGlowFrames")
    -- Turning it on again starts from what the slots are then.
    slots = {}
    HideAllGlows()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
