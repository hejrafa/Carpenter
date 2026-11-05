#!/usr/bin/env lua
-- Verifies nameplate combo points follow the target's plate on events alone:
-- no polling ticker, and they hide when the plate goes away or the target
-- dies or turns friendly. Other units' plates coming and going must leave
-- them alone, or they blink.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local eventFrame
local registered = {}
local deferred = {}
local tickersStarted = 0

local function NewRegion()
    local region = { shown = true, points = {} }
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:SetSize() end
    function region:SetScale() end
    function region:SetTexture() end
    function region:SetTexCoord() end
    function region:SetAlpha() end
    function region:SetPoint(_, relativeTo) self.points[#self.points + 1] = relativeTo end
    function region:ClearAllPoints() self.points = {} end
    function region:SetParent(parent) self.parent = parent end
    function region:GetParent() return self.parent end
    function region:SetFrameStrata() end
    function region:SetFrameLevel() end
    function region:GetFrameLevel() return 1 end
    function region:SetIgnoreParentAlpha() end
    function region:CreateTexture() return NewRegion() end
    return region
end

function CreateFrame(_, name)
    local frame = NewRegion()
    function frame:RegisterEvent(event) registered[event] = true end
    function frame:RegisterUnitEvent(event) registered[event] = true end
    function frame:UnregisterAllEvents() registered = {} end
    function frame:SetScript(_, handler) self.handler = handler end
    if name == nil and not eventFrame then eventFrame = frame end
    if name then _G[name] = frame end
    return frame
end

C_Timer = { After = function(_, callback) deferred[#deferred + 1] = callback end }
local function RunDeferred()
    local pending = deferred
    deferred = {}
    for _, callback in ipairs(pending) do callback() end
end

local target = { exists = true, dead = false, hostile = true, combo = 2 }
local plates = {}
local function NewPlate()
    local plate = NewRegion()
    plate.UnitFrame = { healthBar = NewRegion() }
    return plate
end

function UnitExists() return target.exists end
function UnitIsDead() return target.dead end
function UnitCanAttack() return target.hostile end
function GetComboPoints() return target.combo end

CarpenterDB = { nameplateComboEnabled = true }
Carpenter = {
    Client = { isVanilla = true },
    Features = {},
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(self, key, feature) self.Features[key] = feature end,
    SafeRegisterEvent = function(_, frame, event) frame:RegisterEvent(event) end,
    StartTicker = function() tickersStarted = tickersStarted + 1 end,
}

local ns = {
    Private = {
        Nameplates = {
            GetForUnit = function(unit) return plates[unit] end,
            GetHealthBar = function(plate) return plate.UnitFrame.healthBar end,
        },
    },
}
Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/NameplateComboPoints.lua"))("Carpenter", ns)

local function Fire(event, unit)
    eventFrame.handler(eventFrame, event, unit)
end

-- The target's plate is also reachable by its nameplate unit, as in game.
local function SetTargetPlate(plate)
    plates.target = plate
    plates.nameplate1 = plate
end

local resourceFrame
Carpenter.Features.nameplateComboEnabled:Enable()
assert(registered.UNIT_HEALTH and registered.UNIT_FLAGS and registered.UNIT_FACTION, "target state events should be registered")

-- Target with a plate: points attach to that plate's health bar.
SetTargetPlate(NewPlate())
Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
resourceFrame = _G.CarpenterComboFrame
assert(resourceFrame, "combo frame should exist")
assert(resourceFrame.parent == plates.target and resourceFrame:IsShown(), "points should sit on the target's plate")
assert(resourceFrame.points[1] == plates.target.UnitFrame.healthBar, "points should anchor to the health bar")
assert(tickersStarted == 0, "points must not poll with a ticker")

-- Another unit's plate appears and goes: the points stay put, with no hide
-- and re-show a frame later.
local hides, anchors = 0, 0
local originalHide, originalClearAllPoints = resourceFrame.Hide, resourceFrame.ClearAllPoints
function resourceFrame:Hide() hides = hides + 1; originalHide(self) end
function resourceFrame:ClearAllPoints() anchors = anchors + 1; originalClearAllPoints(self) end
plates.nameplate2 = NewPlate()
Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
plates.nameplate2 = nil
assert(hides == 0 and resourceFrame:IsShown(), "another unit's plate going away must not hide the points")
assert(anchors == 0, "another unit's plate must not re-anchor the points")
assert(#deferred == 0, "another unit's plate going away must not schedule a re-show")
resourceFrame.Hide, resourceFrame.ClearAllPoints = originalHide, originalClearAllPoints

-- A removal that can no longer be matched to a plate still hides them.
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate9")
assert(not resourceFrame:IsShown(), "an unmatched plate removal should hide the points")
RunDeferred()
assert(resourceFrame:IsShown(), "points should return while the target still has its plate")

-- The plate is released: hide now, and stay hidden once it's gone.
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not resourceFrame:IsShown(), "points should hide when the plate is removed")
SetTargetPlate(nil)
RunDeferred()
assert(not resourceFrame:IsShown(), "points should stay hidden without a plate")

-- The plate comes back, then the target dies.
SetTargetPlate(NewPlate())
Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(resourceFrame:IsShown() and resourceFrame.parent == plates.target, "points should return to the new plate")
target.dead = true
Fire("UNIT_HEALTH")
assert(not resourceFrame:IsShown(), "points should hide when the target dies")

-- A friendly target hides them too.
target.dead = false
Fire("PLAYER_TARGET_CHANGED")
assert(resourceFrame:IsShown(), "points should show for a new hostile target")
target.hostile = false
Fire("UNIT_FACTION")
assert(not resourceFrame:IsShown(), "points should hide when the target turns friendly")

-- Disabling hides and stops listening.
target.hostile = true
Fire("PLAYER_TARGET_CHANGED")
CarpenterDB.nameplateComboEnabled = false
Carpenter.Features.nameplateComboEnabled:Disable()
assert(not resourceFrame:IsShown() and next(registered) == nil, "disabling should hide and unregister")

print("nameplate combo fixtures passed")
