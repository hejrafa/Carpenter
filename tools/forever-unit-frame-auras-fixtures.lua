#!/usr/bin/env lua
-- Verifies the Forever crowd control portrait icon: one aura slot per unit
-- frame, centered on the portrait, refreshed when the unit behind a token
-- changes, and released when the feature is turned off.

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
    function region:CreateFontString() return NewRegion() end
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
    if frameType == "AuraContainer" then
        assert(template == "CustomAuraContainerTemplate", "expected the custom aura container template")
        frame.parent = parent
        frame.slots = {}
        frame.refreshes = 0
        function frame:AddAuraSlot(key, filter, options)
            -- The game creates the slot button and runs the initializer.
            local button = NewRegion()
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
assert(loadfile(repo .. "/Core/Nameplates.lua"))("Carpenter", ns)
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
assert(player.level == 4, "the icon should share the portrait frame's level so the level badge above it stays visible")
assert(player.points[1][1] == "CENTER" and player.points[1][2] == portrait, "the container should be centered on the portrait")
assert(#player.slots == 1, "the player frame should have one slot")
local slot = player.slots[1]
assert(slot.filter == "HARMFUL|CROWD_CONTROL", "the slot should only take crowd control")
assert(slot.options.sortMethod == AuraContainerSortMethod.ExpirationOnly
    and slot.options.sortDirection == AuraContainerSortDirection.Reverse, "the longest crowd control should win")

local button = slot.button
assert(button.width == 56 and button.height == 56, "the icon should be inset inside the portrait ring")
assert(button.icon and button.icon.mask, "the icon should be masked round")
assert(button.cooldown and button.cooldown.swipeTexture, "the swipe should be round")
assert(button.durationText and button.durationText.fontSize == 24, "the timer should use the Classic portrait size")
assert(button.durationOptions and button.durationOptions.textFormatter, "the timer should use the shared formatter")
assert(byUnit.party1.slots[1].button.durationText.fontSize == 14, "party portraits should use a smaller timer")

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

feature:Enable()
assert(#containers == 7, "enabling again should reuse the containers")
assert(byUnit.target.unit == "target" and byUnit.target.shown, "enabling again should restore the units")

print("forever unit frame auras fixtures: passed")
