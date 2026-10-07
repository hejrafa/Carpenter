local root = assert(arg[1], "usage: lua tools/minimap-clutter-fixtures.lua <addon-root>")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function newWidget(name)
    local widget = {
        name = name,
        alpha = 1,
        shown = true,
        scripts = {},
    }

    function widget:GetName() return self.name end
    function widget:SetAlpha(alpha) self.alpha = alpha end
    function widget:GetAlpha() return self.alpha end
    function widget:Show() self.shown = true end
    function widget:Hide() self.shown = false end
    function widget:IsShown() return self.shown end
    function widget:IsMouseOver() return false end
    function widget:HookScript(event, callback) self.scripts[event] = callback end
    function widget:SetScript(event, callback) self.scripts[event] = callback end
    function widget:GetScript(event) return self.scripts[event] end

    return widget
end

local addonButton = newWidget("LibDBIcon10_Test")
local trackingButton = newWidget("MiniMapTrackingButton")
local zoneButton = newWidget("MinimapZoneTextButton")
local compartmentButton = newWidget("AddonCompartmentMinimapButton")
local calendarButton = newWidget("GameTimeMinimapButton")
local clockButton = newWidget("TimeManagerClockMinimapButton")
local children = {
    addonButton,
    trackingButton,
    zoneButton,
    compartmentButton,
    calendarButton,
    clockButton,
}
local unpackValues = table.unpack or unpack

Minimap = newWidget("Minimap")
function Minimap:GetNumChildren() return #children end
function Minimap:GetChildren() return unpackValues(children) end

QueueStatusMinimapButton = newWidget("QueueStatusMinimapButton")

local faderFrame
function CreateFrame()
    faderFrame = newWidget("MinimapClutterFader")
    return faderFrame
end

local faderNamespace = { Private = {} }
assert(loadfile(root .. "/Modules/MinimapClutter/MinimapClutterFader.lua"))("Carpenter", faderNamespace)
local fader = assert(faderNamespace.Private.MinimapClutterFader.Create)({
    IsEnabled = function() return true end,
})

fader.Apply(true)
assertEqual(addonButton.CP_MinimapFadeManaged, true, "addon button is managed")
assertEqual(addonButton.alpha, 0, "addon button starts faded")
assertEqual(QueueStatusMinimapButton.CP_MinimapFadeManaged, true, "queue button is managed")
assertEqual(trackingButton.CP_MinimapFadeManaged, nil, "tracking remains unmanaged")
assertEqual(zoneButton.CP_MinimapFadeManaged, nil, "zone text remains unmanaged")
assertEqual(compartmentButton.CP_MinimapFadeManaged, nil, "addon compartment remains unmanaged")
assertEqual(calendarButton.CP_MinimapFadeManaged, nil, "calendar remains unmanaged")
assertEqual(clockButton.CP_MinimapFadeManaged, nil, "clock remains unmanaged")

fader.Apply(false)
assertEqual(addonButton.alpha, 1, "addon button restores on disable")
assertEqual(QueueStatusMinimapButton.alpha, 1, "queue button restores on disable")

MinimapZoomIn = newWidget("MinimapZoomIn")
MinimapZoomOut = newWidget("MinimapZoomOut")
MinimapCloseButton = newWidget("MinimapCloseButton")
MinimapToggleButton = newWidget("MinimapToggleButton")
GameTimeFrame = newWidget("GameTimeFrame")
MinimapZoneTextButton = newWidget("MinimapZoneTextButton")
MinimapZoneText = newWidget("MinimapZoneText")
MinimapBorderTop = newWidget("MinimapBorderTop")
MinimapCluster = {
    BorderTop = newWidget("ClusterBorderTop"),
    CloseButton = newWidget("ClusterCloseButton"),
    DielFrame = newWidget("ClusterDielFrame"),
    ToggleButton = newWidget("ClusterToggleButton"),
}

function hooksecurefunc() end

local frameNamespace = { Private = {} }
assert(loadfile(root .. "/Modules/MinimapClutter/MinimapClutterFrames.lua"))("Carpenter", frameNamespace)
local frames = assert(frameNamespace.Private.MinimapClutterFrames.Create)({
    IsEnabled = function() return true end,
    IsRetailClient = function() return false end,
})

frames.Apply(true)
assertEqual(MinimapZoomIn.shown, false, "classic zoom in is hidden")
assertEqual(MinimapZoomOut.shown, false, "classic zoom out is hidden")
assertEqual(MinimapCloseButton.shown, false, "classic close button is hidden")
assertEqual(MinimapToggleButton.shown, false, "classic toggle button is hidden")
assertEqual(GameTimeFrame.shown, true, "calendar remains shown")
assertEqual(MinimapCluster.DielFrame.shown, false, "day/night artwork is hidden")
assertEqual(MinimapZoneTextButton.shown, true, "zone text button remains shown")
assertEqual(MinimapZoneText.shown, true, "zone text remains shown")
assertEqual(MinimapBorderTop.shown, true, "zone text border remains shown")
assertEqual(MinimapCluster.BorderTop.shown, true, "cluster zone border remains shown")

frames.Apply(false)
assertEqual(MinimapCluster.DielFrame.shown, true, "day/night artwork restores on disable")

local foreverFrames = assert(frameNamespace.Private.MinimapClutterFrames.Create)({
    IsEnabled = function() return true end,
    IsRetailClient = function() return true end,
})
foreverFrames.Apply(true)
assertEqual(MinimapCluster.DielFrame.shown, false, "Forever day/night artwork is hidden")
assertEqual(GameTimeFrame.shown, true, "Forever calendar remains shown")
assertEqual(MinimapZoomIn.shown, true, "Forever zoom controls remain client-managed")

-- Forever and Retail fade the strip above the minimap and keep it up on hover.
local mouseOverCluster = false
local menuOpen = false
MinimapCluster.ZoneTextButton = newWidget("ClusterZoneTextButton")
MinimapCluster.Tracking = newWidget("ClusterTracking")
MinimapCluster.Tracking.Button = newWidget("ClusterTrackingButton")
function MinimapCluster.Tracking.Button:IsMenuOpen() return menuOpen end
MinimapCluster.IndicatorFrame = newWidget("ClusterIndicatorFrame")
function MinimapCluster:IsMouseOver() return mouseOverCluster end
function MinimapCluster:HookScript(event, callback) self[event] = callback end
AddonCompartmentFrame = newWidget("AddonCompartmentFrame")
TimeManagerClockButton = newWidget("TimeManagerClockButton")
GameTimeCalendarInvitesTexture = newWidget("GameTimeCalendarInvitesTexture")
GameTimeCalendarInvitesTexture.shown = false
TimeManagerAlarmFiredTexture = newWidget("TimeManagerAlarmFiredTexture")
TimeManagerAlarmFiredTexture.shown = false
GameTimeFrame.alpha = 1

function hooksecurefunc(target, method, hook)
    local original = target[method]
    target[method] = function(...)
        original(...)
        hook(...)
    end
end

local retailFader = assert(faderNamespace.Private.MinimapClutterFader.Create)({
    IsEnabled = function() return true end,
    IsRetailClient = function() return true end,
})
retailFader.Apply(true)
local headerFrames = {
    MinimapCluster.BorderTop,
    MinimapCluster.ZoneTextButton,
    MinimapCluster.Tracking,
    GameTimeFrame,
    TimeManagerClockButton,
    AddonCompartmentFrame,
}
for _, frame in ipairs(headerFrames) do
    assertEqual(frame.CP_MinimapFadeManaged, true, frame.name .. " is managed")
    assertEqual(frame.alpha, 0, frame.name .. " starts faded")
end
assertEqual(MinimapCluster.IndicatorFrame.CP_MinimapFadeManaged, nil, "mail and crafting indicators stay visible")
assert(MinimapCluster.OnEnter and MinimapCluster.OnLeave, "cluster hover is hooked")

-- Like the client, only tick while the fader frame is shown.
local function RunFader()
    for _ = 1, 20 do
        if faderFrame.shown and faderFrame.scripts.OnUpdate then
            faderFrame.scripts.OnUpdate(faderFrame, 0.05)
        end
    end
end

mouseOverCluster = true
MinimapCluster.OnEnter(MinimapCluster)
RunFader()
assertEqual(GameTimeFrame.alpha, 1, "hovering the minimap reveals the calendar")
assertEqual(MinimapCluster.ZoneTextButton.alpha, 1, "hovering the minimap reveals the zone name")

-- Leaving through a frame the fader never hooked (mail icon, another addon)
-- fires no leave event, so the fader has to notice on its own.
mouseOverCluster = false
RunFader()
assertEqual(GameTimeFrame.alpha, 0, "strip fades after leaving through an unhooked frame")
assertEqual(faderFrame.shown, false, "fader stops polling once the strip has faded")

mouseOverCluster = true
MinimapCluster.OnEnter(MinimapCluster)
RunFader()
mouseOverCluster = false
menuOpen = true
MinimapCluster.OnLeave(MinimapCluster)
RunFader()
assertEqual(MinimapCluster.Tracking.alpha, 1, "open tracking menu keeps the strip visible")

menuOpen = false
RunFader()
assertEqual(MinimapCluster.Tracking.alpha, 0, "strip fades once the menu closes")

faderFrame.shown = false
GameTimeCalendarInvitesTexture:Show()
assertEqual(faderFrame.shown, true, "a new calendar invite wakes the fader")
RunFader()
assertEqual(GameTimeFrame.alpha, 1, "pending invites keep the calendar visible")
assertEqual(TimeManagerClockButton.alpha, 0, "the clock still fades without an alarm")
assertEqual(MinimapCluster.ZoneTextButton.alpha, 0, "the zone name still fades with pending invites")

GameTimeCalendarInvitesTexture:Hide()
RunFader()
assertEqual(GameTimeFrame.alpha, 0, "the calendar fades once invites are seen")

TimeManagerAlarmFiredTexture:Show()
RunFader()
assertEqual(TimeManagerClockButton.alpha, 1, "a ringing alarm keeps the clock visible")
TimeManagerAlarmFiredTexture:Hide()
RunFader()
assertEqual(TimeManagerClockButton.alpha, 0, "the clock fades once the alarm stops")

retailFader.Apply(false)
for _, frame in ipairs(headerFrames) do
    assertEqual(frame.alpha, 1, frame.name .. " restores on disable")
end

local localizationFiles = {
    "deDE.lua",
    "enUS.lua",
    "esES.lua",
    "frFR.lua",
    "ptBR.lua",
    "ruRU.lua",
}

for _, fileName in ipairs(localizationFiles) do
    local file = assert(io.open(root .. "/Localization/" .. fileName, "r"))
    local source = file:read("*a")
    file:close()

    local description = assert(source:match('L%.DESC_MINIMAP_CLUTTER%s*=%s*"(.-)"'), fileName .. " minimap description")
    local _, highlights = description:gsub("{hl}", "")
    assertEqual(highlights, 1, fileName .. " minimap description only names addon buttons")
end

print("minimap clutter fixtures: passed")
