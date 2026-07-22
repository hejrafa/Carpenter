--[[ Carpenter - SmallerExpBar ]]
-- Sets the visible XP/Rep tracking bars to 60% opacity. Sizing and placement
-- are left alone because Edit Mode now owns those bars.

local OPACITY = 0.6 -- Set bars to 60% opacity

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("smallerExpBarEnabled")
end

-- =========================
-- Core
-- =========================
local function ApplyOpacity()
    if not IsEnabled() then return end

    -- 1. Main Menu Experience Bar (Standard Classic)
    if MainMenuExpBar then
        MainMenuExpBar:SetAlpha(OPACITY)
    end

    -- 2. Reputation Watch Bar (Standard Classic)
    if ReputationWatchBar then
        ReputationWatchBar:SetAlpha(OPACITY)
    end

    -- 3. Modern Manager (If present in your client version)
    local m = StatusTrackingBarManager
    if m then
        m:SetAlpha(OPACITY)
        -- Sometimes the container needs the opacity instead of the manager
        if m.BarContainer then
            m.BarContainer:SetAlpha(OPACITY)
        end
    end
end

-- =========================
-- Events & Hooks
-- =========================
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("UI_SCALE_CHANGED")

frame:SetScript("OnEvent", function()
    ApplyOpacity()
end)

-- Hook specific update functions to re-apply opacity if Blizzard resets it
if MainMenuExpBar_Update then
    hooksecurefunc("MainMenuExpBar_Update", ApplyOpacity)
end

if ReputationWatchBar_Update then
    hooksecurefunc("ReputationWatchBar_Update", ApplyOpacity)
end

-- Periodically enforce it (Blizzard UI loves to reset these on zone in/reload)
C_Timer.After(1, ApplyOpacity)
C_Timer.After(5, ApplyOpacity)
