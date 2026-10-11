#!/usr/bin/env lua
-- Verifies the Forever nameplate aura row: container setup, anchoring, and
-- hiding/restoring Blizzard's own aura lists.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local hooks = {}
local eventHandler
local hostile = { nameplate1 = true, nameplate2 = false }

function hooksecurefunc(target, name, hook)
    local original = target[name]
    target[name] = function(...)
        local result = original(...)
        hook(...)
        return result
    end
    hooks[#hooks + 1] = name
end

local function NewRegion()
    local region = { points = {}, shown = true }
    function region:SetSize() end
    function region:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    function region:ClearAllPoints() self.points = {} end
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(index)
        if self.restricted then error("Can't measure restricted regions") end
        return unpack(self.points[index])
    end
    function region:GetOwnPoint(index) return unpack(self.points[index]) end
    function region:SetAllPoints() end
    function region:SetTexCoord() end
    function region:SetTexture() end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level or 1 end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:SetShown(shown) self.shown = shown and true or false end
    function region:IsShown() return self.shown end
    function region:CreateTexture() return NewRegion() end
    function region:CreateFontString() return NewRegion() end
    function region:SetReverse() end
    function region:SetDrawEdge() end
    function region:SetSwipeColor() end
    function region:SetHideCountdownNumbers() end
    function region:SetFont() end
    function region:SetTextColor() end
    function region:SetShadowColor() end
    function region:SetShadowOffset() end
    function region:RegisterEvent() end
    function region:UnregisterAllEvents() end
    function region:SetScript(_, handler) eventHandler = handler end
    return region
end

local containers = {}
function CreateFrame(frameType, _, parent, template)
    local frame = NewRegion()
    if frameType == "AuraContainer" then
        assert(template == "CustomAuraContainerTemplate", "expected the custom aura container template")
        frame.groups = {}
        function frame:SetFlowLayoutAnchorPoint(point) self.anchorPoint = point end
        function frame:SetFlowLayoutGrowthDirection(h, v) self.growth = { h, v } end
        function frame:SetFlowLayoutMaximumLineSize(size) self.lineSize = size end
        function frame:AddAuraGroup(key, filter, options)
            self.groups[#self.groups + 1] = { key = key, filter = filter, options = options }
            -- The game creates buttons and runs the initializer.
            local button = NewRegion()
            function button:SetIcon(texture) self.icon = texture end
            function button:SetDurationCooldown(cooldown) self.cooldown = cooldown end
            function button:SetApplicationCount(text) self.count = text end
            function button:SetDurationText(text, textOptions) self.durationText, self.durationOptions = text, textOptions end
            function button:AddDispelTypeTexture(texture, dispelOptions) self.border, self.borderOptions = texture, dispelOptions end
            options.initializeFrame(button)
            self.button = button
        end
        function frame:SetUnit(unit) self.unit = unit end
        frame.parent = parent
        containers[#containers + 1] = frame
    end
    return frame
end

Enum = {
    CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 },
    LuaCurveType = { Step = 1 },
    SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2 },
    SecondsFormatterAbbreviation = { OneLetter = 2 },
    SecondsFormatterIntervalWhitespace = { StripIgnoreLocale = 2 },
    SecondsFormatterRounding = { RoundUp = 0 },
    NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
}
local curvePoints = {}
C_CurveUtil = { CreateCurve = function()
    return { SetType = function() end, AddPoint = function(_, x, y) curvePoints[#curvePoints + 1] = { x, y } end }
end }
local formatterSettings = {}
local ruleBreakpoints
C_StringUtil = {
    CreateNumericRuleFormatter = function()
        return { SetBreakpoints = function(_, breakpoints) ruleBreakpoints = breakpoints end }
    end,
    CreateSecondsFormatter = function()
    return setmetatable({}, { __index = function(_, method)
        return function(_, value) formatterSettings[method] = value end
    end })
    end,
}
AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
C_NamePlate = {}
NamePlateConstants = { NAME_ANCHOR_STYLES = { AboveHealthBar = 0, InsideHealthBar = 1 } }
NamePlateSetupOptions = { unitNameAnchorStyle = 0 }
local debuffPadding = "5"
C_CVar = { GetCVar = function(name) if name == "nameplateDebuffPadding" then return debuffPadding end end }
function UnitCanAttack(_, unit) return hostile[unit] end
unpack = unpack or table.unpack

local function NewPlate(unit)
    local unitFrame = NewRegion()
    unitFrame.HealthBarsContainer = NewRegion()
    unitFrame.HealthBarsContainer.healthBar = NewRegion()
    unitFrame.name = NewRegion()
    unitFrame.AurasFrame = {
        DebuffListFrame = NewRegion(),
        CrowdControlListFrame = NewRegion(),
        LossOfControlFrame = NewRegion(),
        BuffListFrame = NewRegion(),
    }
    -- Forever refuses to measure Blizzard's nameplate regions.
    unitFrame.AurasFrame.DebuffListFrame.restricted = true
    function unitFrame:UpdateAnchors() end
    return { UnitFrame = unitFrame, namePlateUnitToken = unit }
end

local plates = { nameplate1 = NewPlate("nameplate1"), nameplate2 = NewPlate("nameplate2") }

CarpenterDB = { debuffTrackerEnabled = true }
Carpenter = {
    Features = {},
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(self, key, feature) self.Features[key] = feature end,
}

local ns = {
    Private = {
        Nameplates = {
            GetForUnit = function(unit) return plates[unit] end,
            GetAll = function() return {} end,
            GetHealthBar = function() return nil end,
        },
    },
}
assert(loadfile(repo .. "/Modules/ForeverNameplateAuras.lua"))("Carpenter", ns)

local feature = Carpenter.Features.debuffTrackerEnabled
assert(feature, "feature should register on the debuff tracker key")
feature:Enable()

-- Enemy plate: one centered container with crowd control first, then debuffs.
eventHandler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
local enemy = plates.nameplate1.UnitFrame
assert(#containers == 1, "expected one container for the enemy plate")
local container = containers[1]
assert(container.unit == "nameplate1", "container should follow the plate's unit")
assert(container.groups[1].filter == "HARMFUL|CROWD_CONTROL", "crowd control group should come first")
assert(container.groups[2].filter:find("!CROWD_CONTROL", 1, true), "debuffs should exclude crowd control to avoid duplicates")
assert(container.anchorPoint == "BOTTOMLEFT", "elements should fill from the container's bottom left")

local point, relativeTo, relativePoint, x, y = container:GetOwnPoint(1)
assert(point == "BOTTOM" and relativeTo == enemy.name and relativePoint == "TOP" and x == 0 and y == 5,
    "container should center above the name, spaced by the debuff padding")

local button = container.button
assert(button.icon and button.cooldown and button.count and button.border, "buttons should get icon, cooldown, count, and border")
assert(button.durationText and button.durationOptions and button.durationOptions.textFormatter, "buttons should get a timer with Carpenter's formatter")
assert(ruleBreakpoints, "timer should use the Classic-style rule formatter")
assert(ruleBreakpoints[1].threshold == 0 and ruleBreakpoints[1].format == "%d" and ruleBreakpoints[1].rounding == Enum.NumericRuleFormatRounding.Up,
    "timer should show plain whole seconds, rounded up")
assert(ruleBreakpoints[2].threshold == 60 and ruleBreakpoints[2].format == "%dm" and ruleBreakpoints[2].components[1].div == 60,
    "timer should switch to minutes at 60 seconds")
assert(ruleBreakpoints[3].threshold == 3600 and ruleBreakpoints[3].format == "%dh", "timer should switch to hours at an hour")
assert(button.borderOptions.style == Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, "border should keep the target-frame art")
assert(button.borderOptions.showWithoutDispelType == true, "physical debuffs should still get an outline")

-- Blizzard's own lists are hidden, and stay hidden when Blizzard shows them again.
assert(not enemy.AurasFrame.DebuffListFrame:IsShown(), "Blizzard's debuff list should be hidden")
assert(not enemy.AurasFrame.CrowdControlListFrame:IsShown(), "Blizzard's crowd control list should be hidden")
assert(enemy.AurasFrame.BuffListFrame:IsShown(), "Blizzard's buff list should stay")
enemy.AurasFrame.CrowdControlListFrame:SetShown(true)
assert(not enemy.AurasFrame.CrowdControlListFrame:IsShown(), "re-shown Blizzard lists should be hidden again")

-- Blizzard re-anchoring after a style or padding change moves our row with it.
NamePlateSetupOptions.unitNameAnchorStyle = 1
debuffPadding = "7"
enemy:UpdateAnchors()
point, relativeTo, relativePoint, x, y = container:GetOwnPoint(1)
assert(relativeTo == enemy.HealthBarsContainer.healthBar and y == 7, "names inside the bar should put the row above the health bar")

-- Friendly plates are left to Blizzard.
eventHandler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(#containers == 1, "friendly plates should not get a container")
assert(plates.nameplate2.UnitFrame.AurasFrame.DebuffListFrame:IsShown(), "friendly plates keep Blizzard's lists")

-- Removing the plate restores Blizzard's lists.
eventHandler(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(container.unit == "none", "removed plates should clear the container unit")
assert(enemy.AurasFrame.DebuffListFrame:IsShown(), "Blizzard's lists should come back when the plate is released")

-- Disabling restores everything.
eventHandler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
CarpenterDB.debuffTrackerEnabled = false
feature:Disable()
assert(container.unit == "none" and not container:IsShown(), "disabling should clear and hide the container")
assert(enemy.AurasFrame.CrowdControlListFrame:IsShown(), "disabling should bring Blizzard's lists back")

print("forever nameplate auras fixtures passed")
