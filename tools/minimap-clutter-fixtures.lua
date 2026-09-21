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

local coreFile = assert(io.open(root .. "/Core/Carpenter.lua", "r"))
local coreSource = coreFile:read("*a")
coreFile:close()
local foreverDefaultOff = assert(
    coreSource:match("local%s+foreverDefaultOff%s*=%s*(%b{})"),
    "could not find the Forever forced-off defaults"
)
assertEqual(
    foreverDefaultOff:match("minimapClutterEnabled%s*="),
    nil,
    "Remove Minimap Clutter is forced on for Forever"
)

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
