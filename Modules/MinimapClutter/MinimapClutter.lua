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

local function IsMainlineClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isMainline
end

local frameHelpers = FrameHelpers.Create and FrameHelpers.Create({
    IsEnabled = IsEnabled,
    IsMainlineClient = IsMainlineClient,
}) or {}

local faderHelpers = FaderHelpers.Create and FaderHelpers.Create({
    IsEnabled = IsEnabled,
    IsMainlineClient = IsMainlineClient,
}) or {}

local function ApplyMinimapClutter()
    local enabled = IsEnabled()

    if frameHelpers.Apply then
        frameHelpers.Apply(enabled)
    end
    if faderHelpers.Apply then
        faderHelpers.Apply(enabled)
    end
    if IsClassicClient() then
        if enabled and frameHelpers.EnableMouseWheelZoom then
            frameHelpers.EnableMouseWheelZoom()
        elseif not enabled and frameHelpers.DisableMouseWheelZoom then
            frameHelpers.DisableMouseWheelZoom()
        end
    end
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function()
    ApplyMinimapClutter()
end)

local feature = {}

function feature:Enable()
    Carpenter:SafeRegisterEvent(frame, "PLAYER_LOGIN")
    Carpenter:SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")
    Carpenter:SafeRegisterEvent(frame, "LFG_UPDATE")
    Carpenter:SafeRegisterEvent(frame, "LFG_QUEUE_STATUS_UPDATE")
    ApplyMinimapClutter()
    -- Re-enforce shortly after login/zone to catch any late layout changes.
    Carpenter:DeferMany("MinimapClutter:startup", { 1, 5 }, ApplyMinimapClutter)
end

function feature:Disable()
    frame:UnregisterAllEvents()
    ApplyMinimapClutter()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("minimapClutterEnabled", feature)
end
