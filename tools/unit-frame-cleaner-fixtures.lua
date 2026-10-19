#!/usr/bin/env lua
-- Verifies Clean Unit Frame softens the red threat glow around the player,
-- target, focus, and party portraits: dimmed rather than hidden, never touched
-- in combat, and restored when the option is turned off.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local inCombat = false
local cleanEnabled = true
local features = {}

local function NewTexture()
    local texture = { alpha = 1 }
    function texture:SetAlpha(alpha) self.alpha = alpha end
    function texture:GetAlpha() return self.alpha end
    return texture
end

function CreateFrame()
    local frame = {}
    function frame:SetScript(_, handler) self.handler = handler end
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents() end
    return frame
end

function InCombatLockdown() return inCombat end
function GetNumGroupMembers() return 0 end
function IsInRaid() return false end
Carpenter = {
    Client = { isRetail = true, isForever = true },
    IsEnabled = function(_, key) return key == "cleanUpUnitFramesEnabled" and cleanEnabled end,
    RegisterFeature = function(_, key, feature) features[key] = feature end,
}

local playerGlow, targetGlow, focusGlow, partyGlow = NewTexture(), NewTexture(), NewTexture(), NewTexture()
PlayerFrame = { PlayerFrameContainer = { FrameFlash = playerGlow } }
TargetFrame = { TargetFrameContainer = { Flash = targetGlow } }
FocusFrame = { TargetFrameContainer = { Flash = focusGlow } }
PartyFrame = { MemberFrame1 = { Flash = partyGlow } }
CompactPartyFrameTitle = NewTexture()

local ns = { Private = {} }
for _, path in ipairs({
    "Modules/RetailUnitFrameCleanerVisuals.lua",
    "Modules/RetailUnitFrameCleanerTargets.lua",
    "Modules/RetailUnitFrameCleanerRealm.lua",
    "Modules/RetailUnitFrameCleaner.lua",
}) do
    assert(loadfile(repo .. "/" .. path))("Carpenter", ns)
end

local feature = assert(features.cleanUpUnitFramesEnabled, "Clean Unit Frame should register")

-- In combat the glow belongs to secure unit frames, so nothing changes yet.
inCombat = true
feature:Enable()
assert(playerGlow.alpha == 1, "the threat glow must not be touched in combat")

inCombat = false
feature:Enable()
for name, glow in pairs({ player = playerGlow, target = targetGlow, focus = focusGlow, party = partyGlow }) do
    assert(glow.alpha > 0 and glow.alpha < 1, name .. " threat glow should be dimmed, not hidden")
end

-- Forever keeps its party frame title (and corner icon, reputation color, and
-- realm indicators); Retail still cleans them.
assert(CompactPartyFrameTitle.alpha == 1, "Forever should leave the party frame title alone")

cleanEnabled = false
feature:Disable()
assert(playerGlow.alpha == 1 and targetGlow.alpha == 1, "turning the option off should restore the threat glow")

Carpenter.Client.isForever = false
cleanEnabled = true
feature:Enable()
assert(CompactPartyFrameTitle.alpha == 0, "Retail should still hide the party frame title")

print("unit frame cleaner fixtures: passed")
