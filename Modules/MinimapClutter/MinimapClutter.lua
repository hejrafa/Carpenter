--[[ Carpenter - MinimapClutter ]]
-- Fades or hides minimap extras for a cleaner minimap, depending on client flavor.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local FrameHelpers = ns.Private.MinimapClutterFrames or {}
local FaderHelpers = ns.Private.MinimapClutterFader or {}

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("minimapClutterEnabled")
end

local function IsClassicClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic
end

local function IsRetailClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local frameHelpers = FrameHelpers.Create and FrameHelpers.Create({
    IsEnabled = IsEnabled,
    IsRetailClient = IsRetailClient,
}) or {}

local faderHelpers = FaderHelpers.Create and FaderHelpers.Create({
    IsEnabled = IsEnabled,
    IsClassicClient = IsClassicClient,
    IsRetailClient = IsRetailClient,
}) or {}

local function ApplyMinimapClutter()
    local enabled = IsEnabled()

    if frameHelpers.Apply then
        frameHelpers.Apply(enabled)
    end
    if faderHelpers.Apply then
        faderHelpers.Apply(enabled)
    end
    if enabled and IsClassicClient() and frameHelpers.EnableMouseWheelZoom then
        frameHelpers.EnableMouseWheelZoom()
    end
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function()
    ApplyMinimapClutter()
end)

local function RegisterEventSafe(event)
    pcall(frame.RegisterEvent, frame, event)
end

local feature = {}

function feature:Enable()
    RegisterEventSafe("PLAYER_LOGIN")
    RegisterEventSafe("PLAYER_ENTERING_WORLD")
    RegisterEventSafe("LFG_UPDATE")
    RegisterEventSafe("LFG_QUEUE_STATUS_UPDATE")
    RegisterEventSafe("MINIMAP_UPDATE_TRACKING")
    ApplyMinimapClutter()
    -- Re-enforce shortly after login/zone to catch any late layout changes.
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("MinimapClutter:startup", { 1, 5 }, ApplyMinimapClutter)
    else
        C_Timer.After(1, ApplyMinimapClutter)
        C_Timer.After(5, ApplyMinimapClutter)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
    ApplyMinimapClutter()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("minimapClutterEnabled", feature)
end
