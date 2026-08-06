--[[ Carpenter - SmallerExpBar ]]
-- Sets the visible XP/Rep tracking bars to 60% opacity. Sizing and placement
-- are left alone because Edit Mode now owns those bars.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local TrackingBars = ns.Private.StatusTrackingBars or {}
local OPACITY = 0.6 -- Set bars to 60% opacity

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("smallerExpBarEnabled")
end

local function GetExplorerTargetAlpha(frame)
    local explorerMode = ns.Private and ns.Private.ExplorerMode
    if not (explorerMode and explorerMode.GetStatusTrackingTargetAlpha) then return nil end
    return explorerMode.GetStatusTrackingTargetAlpha(frame)
end

-- =========================
-- Core
-- =========================
local function FadeFrame(frame, alpha)
    if frame and frame.SetAlpha then
        pcall(frame.SetAlpha, frame, alpha)
    end
end

local managedFrames = {}

local function ApplyAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
    if not managedFrames[frame] then
        local originalAlpha = 1
        if frame.GetAlpha then
            local ok, alphaValue = pcall(frame.GetAlpha, frame)
            if ok and type(alphaValue) == "number" then originalAlpha = alphaValue end
        end
        managedFrames[frame] = originalAlpha
    end
    FadeFrame(frame, alpha)
end

local function Apply()
    local seen = {}
    local forEachRoot = TrackingBars.ForEachRoot or TrackingBars.ForEach

    if forEachRoot then
        forEachRoot(function(frame)
            seen[frame] = true
            local targetAlpha = GetExplorerTargetAlpha(frame)
            if targetAlpha == nil and IsEnabled() then
                targetAlpha = OPACITY
            end

            if targetAlpha ~= nil then
                ApplyAlpha(frame, targetAlpha)
            elseif managedFrames[frame] ~= nil then
                FadeFrame(frame, managedFrames[frame])
                managedFrames[frame] = nil
            end
        end)
    end

    local staleFrames = {}
    for managedFrame in pairs(managedFrames) do
        if not seen[managedFrame] then
            staleFrames[#staleFrames + 1] = managedFrame
        end
    end
    for _, staleFrame in ipairs(staleFrames) do
        FadeFrame(staleFrame, managedFrames[staleFrame])
        managedFrames[staleFrame] = nil
    end
end

-- =========================
-- Events & Hooks
-- =========================
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("UI_SCALE_CHANGED")

frame:SetScript("OnEvent", function()
    Apply()
end)

-- Re-apply opacity whenever Blizzard redraws the bars. Which of these exist
-- depends on the client, so install whichever are present.
local hookedUpdates = {}

local function HookBarUpdates()
    for _, name in ipairs({ "MainMenuExpBar_Update", "ReputationWatchBar_Update", "StatusTrackingBarManager_Update" }) do
        if not hookedUpdates[name] and type(_G[name]) == "function" then
            if pcall(hooksecurefunc, name, Apply) then
                hookedUpdates[name] = true
            end
        end
    end

    local manager = _G.StatusTrackingBarManager
    if manager and not hookedUpdates.managerUpdate and type(manager.UpdateBarsShown) == "function" then
        if pcall(hooksecurefunc, manager, "UpdateBarsShown", Apply) then
            hookedUpdates.managerUpdate = true
        end
    end
end

HookBarUpdates()

-- Blizzard UI loves to reset these on zone in/reload, and the status bar
-- manager may not exist yet at load, so retry the hooks with the passes.
if Carpenter and Carpenter.RunStartupPasses then
    Carpenter:RunStartupPasses("SmallerExpBar:startup", { 0, 1, 5 }, function()
        HookBarUpdates()
        Apply()
    end)
else
    C_Timer.After(1, Apply)
    C_Timer.After(5, Apply)
end
