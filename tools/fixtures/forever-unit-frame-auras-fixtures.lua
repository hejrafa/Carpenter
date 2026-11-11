#!/usr/bin/env lua
-- Verifies the Forever crowd control portrait icon: one aura slot per unit
-- frame, centered on the portrait, limited to stuns and roots, refreshed when
-- the unit behind a token changes, and released when the feature is turned off.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local eventHandler
local registeredEvents = {}

local function NewRegion()
    local region = { points = {}, shown = true, level = 1 }
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:GetWidth() return self.width or 0 end
    function region:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    function region:ClearAllPoints() self.points = {} end
    function region:SetAllPoints() end
    function region:SetTexCoord() end
    function region:SetTexture(texture) self.texture = texture end
    function region:AddMaskTexture(mask) self.mask = mask end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:CreateTexture() return NewRegion() end
    function region:CreateMaskTexture() return NewRegion() end
    function region:CreateFontString()
        local text = NewRegion()
        text.owner = self
        return text
    end
    function region:SetReverse() end
    function region:SetDrawEdge() end
    function region:SetSwipeTexture(texture) self.swipeTexture = texture end
    function region:SetSwipeColor() end
    function region:SetHideCountdownNumbers() end
    function region:SetFont(_, size) self.fontSize = size end
    function region:SetTextColor() end
    function region:SetShadowColor() end
    function region:SetShadowOffset() end
    function region:RegisterEvent(event) registeredEvents[event] = true end
    function region:UnregisterAllEvents() registeredEvents = {} end
    function region:SetScript(_, handler) eventHandler = handler end
    return region
end

local containers = {}
function CreateFrame(frameType, _, parent, template)
    local frame = NewRegion()
    frame.parent = parent
    -- As in the game, a new child frame starts one level above its parent.
    if parent then
        frame.level = parent:GetFrameLevel() + 1
    end
    if frameType == "AuraContainer" then
        assert(template == "CustomAuraContainerTemplate", "expected the custom aura container template")
        frame.slots = {}
        frame.refreshes = 0
        function frame:AddAuraSlot(key, filter, options)
            -- The game creates the slot button as the container's child and runs the initializer.
            local button = CreateFrame("AuraButton", nil, self)
            function button:SetIcon(texture) self.icon = texture end
            function button:SetDurationCooldown(cooldown) self.cooldown = cooldown end
            function button:SetDurationText(text, textOptions) self.durationText, self.durationOptions = text, textOptions end
            options.initializeFrame(button)
            self.slots[#self.slots + 1] = { key = key, filter = filter, options = options, button = button }
            return button
        end
        function frame:SetUnit(unit) self.unit = unit end
        function frame:UpdateAllAuras() self.refreshes = self.refreshes + 1 end
        containers[#containers + 1] = frame
    end
    return frame
end

Enum = {
    CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 },
    NumericRuleFormatRounding = { Up = 1 },
}
AuraContainerSortMethod = { Default = 0, ExpirationOnly = 5 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
C_StringUtil = {
    CreateNumericRuleFormatter = function() return { SetBreakpoints = function() end } end,
}

local function NewPortraitOwner(portraitKey, size)
    local owner = NewRegion()
    owner.level = 4
    owner[portraitKey] = NewRegion()
    owner[portraitKey]:SetSize(size, size)
    return owner
end

PlayerFrame = { PlayerFrameContainer = NewPortraitOwner("PlayerPortrait", 60) }
TargetFrame = { TargetFrameContainer = NewPortraitOwner("Portrait", 58) }
FocusFrame = { TargetFrameContainer = NewPortraitOwner("Portrait", 58) }
PartyFrame = {}
for i = 1, 4 do
    PartyFrame["MemberFrame" .. i] = NewPortraitOwner("Portrait", 37)
end

CarpenterDB = { unitFrameDebuffsEnabled = true }
Carpenter = {
    Features = {},
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(self, key, feature) self.Features[key] = feature end,
}

local ns = { Private = {} }
assert(loadfile(repo .. "/Core/SpellData.lua"))("Carpenter", ns)
assert(loadfile(repo .. "/Core/Nameplates.lua"))("Carpenter", ns)
Carpenter = dofile(repo .. "/tools/fixtures/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/ForeverUnitFrameAuras.lua"))("Carpenter", ns)

local feature = Carpenter.Features.unitFrameDebuffsEnabled
assert(feature, "feature should register on the unit frame debuffs key")
feature:Enable()

local byUnit = {}
for _, container in ipairs(containers) do
    byUnit[container.unit] = container
end
for _, unit in ipairs({ "player", "target", "focus", "party1", "party2", "party3", "party4" }) do
    assert(byUnit[unit], unit .. " should get a portrait container")
end
assert(#containers == 7, "each unit frame should get exactly one container")

-- Player: one crowd control slot, longest first, centered on the portrait.
local player = byUnit.player
local portrait = PlayerFrame.PlayerFrameContainer.PlayerPortrait
assert(player.parent == PlayerFrame.PlayerFrameContainer, "the player container should sit with the portrait")
assert(player:GetFrameLevel() == PlayerFrame.PlayerFrameContainer:GetFrameLevel(), "the container should share the portrait frame's level")
assert(player.points[1][1] == "CENTER" and player.points[1][2] == portrait, "the container should be centered on the portrait")
assert(#player.slots == 1, "the player frame should have one slot")
local slot = player.slots[1]
assert(slot.filter == "HARMFUL|CROWD_CONTROL", "the slot should only take crowd control")
assert(slot.options.sortMethod == AuraContainerSortMethod.ExpirationOnly
    and slot.options.sortDirection == AuraContainerSortDirection.Reverse, "the longest crowd control should win")

-- Only stuns and roots. The game applies these filters after its crowd control
-- one; a duration of 0 means permanent, which a maximum duration never lets by.
local filters = slot.options.candidateFilters
assert(filters, "the slot should narrow down the game's crowd control filter")
local function PassesDuration(duration)
    return duration ~= 0 and duration <= filters.maxDuration
end
assert(not PassesDuration(0), "permanent debuffs like Bonus XP should stay off the portrait")
assert(not PassesDuration(60), "the shortest Resurrection Sickness should stay off the portrait")
assert(not PassesDuration(600), "the longest Resurrection Sickness should stay off the portrait")
assert(PassesDuration(27), "the longest root, Entangling Roots, should show")
assert(PassesDuration(6), "a Kidney Shot should show")

local hiddenOnEnemies = {
    { 118, "Polymorph" }, { 12826, "Polymorph rank 4" }, { 5782, "Fear" }, { 6215, "Fear rank 3" },
    { 2070, "Sap" }, { 11297, "Sap rank 3" }, { 2094, "Blind" }, { 8122, "Psychic Scream" },
    { 15487, "Silence" }, { 3355, "Freezing Trap" }, { 5246, "Intimidating Shout" },
}
for _, spell in ipairs(hiddenOnEnemies) do
    assert(filters.excludeSpellIDs[spell[1]], spell[2] .. " should stay off an enemy's portrait")
end
local shown = {
    { 853, "Hammer of Justice" }, { 408, "Kidney Shot" }, { 8643, "Kidney Shot rank 2" }, { 1833, "Cheap Shot" },
    { 5211, "Bash" }, { 20549, "War Stomp" }, { 122, "Frost Nova" }, { 339, "Entangling Roots" },
    { 1776, "Gouge" }, { 1777, "Gouge rank 2" }, { 8629, "Gouge rank 3" }, { 11285, "Gouge rank 4" },
    { 11286, "Gouge rank 5" }, { 38764, "Gouge rank 6" },
}
for _, spell in ipairs(shown) do
    assert(not filters.excludeSpellIDs[spell[1]], spell[2] .. " should show")
end

-- A wrong ID in the list would quietly leave that spell showing.
for spellId in pairs(CarpenterSpellData.OtherCrowdControl) do
    assert(CarpenterSpellData.GetSpellInfo(spellId) == "cc", "spell " .. spellId .. " should be crowd control in the spell list")
    assert(filters.excludeSpellIDs[spellId], "spell " .. spellId .. " should be excluded")
end

local button = slot.button
assert(button.width == 56 and button.height == 56, "the icon should be inset inside the portrait ring")
assert(button.icon and button.icon.mask, "the icon should be masked round")
assert(button.cooldown and button.cooldown.swipeTexture, "the swipe should be round")
assert(button.durationText and button.durationText.fontSize == 24, "the timer should use the Classic portrait size")
assert(button.durationOptions and button.durationOptions.textFormatter, "the timer should use the shared formatter")
assert(byUnit.party1.slots[1].button.durationText.fontSize == 14, "party portraits should use a smaller timer")

-- Draw order is only certain between different levels, so each piece needs its own:
-- portrait's frame, icon, swipe, level badge. The badge's frame doesn't move, and
-- starts one level above where the portrait's frame started.
local PORTRAIT_FRAME_START = 4
local BADGE_LEVEL = PORTRAIT_FRAME_START + 1
for _, unit in ipairs({ "player", "target", "focus" }) do
    local container = byUnit[unit]
    local unitButton = container.slots[1].button
    local iconLevel, swipeLevel = unitButton:GetFrameLevel(), unitButton.cooldown:GetFrameLevel()
    assert(container.parent:GetFrameLevel() < iconLevel, unit .. "'s icon should draw over the portrait")
    assert(iconLevel < swipeLevel, unit .. "'s swipe should draw over the icon")
    assert(swipeLevel < BADGE_LEVEL, unit .. "'s swipe should stay under the level badge")
    assert(unitButton.durationText.owner:GetFrameLevel() > swipeLevel, unit .. "'s timer should draw over the swipe")
end

-- Party frames have no level badge, so their frames stay where they are.
local partyButton = byUnit.party1.slots[1].button
assert(PartyFrame.MemberFrame1:GetFrameLevel() == PORTRAIT_FRAME_START, "party frames should not move")
assert(PORTRAIT_FRAME_START < partyButton:GetFrameLevel(), "the party icon should draw over the portrait")
assert(partyButton:GetFrameLevel() < partyButton.cooldown:GetFrameLevel(), "the party swipe should draw over the icon")

-- A new unit behind the same token is refreshed.
local targetRefreshes, focusRefreshes, partyRefreshes = byUnit.target.refreshes, byUnit.focus.refreshes, byUnit.party2.refreshes
eventHandler(nil, "PLAYER_TARGET_CHANGED")
eventHandler(nil, "PLAYER_FOCUS_CHANGED")
eventHandler(nil, "GROUP_ROSTER_UPDATE")
assert(byUnit.target.refreshes == targetRefreshes + 1, "a new target should refresh the target icon")
assert(byUnit.focus.refreshes == focusRefreshes + 1, "a new focus should refresh the focus icon")
assert(byUnit.party2.refreshes == partyRefreshes + 1, "a roster change should refresh party icons")

-- Turning it off releases every unit; turning it on again reuses the containers.
feature:Disable()
for _, container in ipairs(containers) do
    assert(container.unit == "none" and not container.shown, "disabling should release and hide every container")
end
assert(next(registeredEvents) == nil, "disabling should stop listening for unit changes")
assert(TargetFrame.TargetFrameContainer:GetFrameLevel() == PORTRAIT_FRAME_START, "disabling should put the portrait frames back")

feature:Enable()
assert(TargetFrame.TargetFrameContainer:GetFrameLevel() == PORTRAIT_FRAME_START - 2, "enabling again should move the portrait frames down")
assert(#containers == 7, "enabling again should reuse the containers")
assert(byUnit.target.unit == "target" and byUnit.target.shown, "enabling again should restore the units")

print("forever unit frame auras fixtures: passed")
