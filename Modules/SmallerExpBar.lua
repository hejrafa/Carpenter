--[[ Carpenter - SmallerExpBar ]]
-- Scales the visible XP/Rep tracking bars to 65% and sets opacity to 60%.

local SCALE = 0.65 -- 0.5 is often too small, 0.65 is a sweet spot, adjust as needed
local OPACITY = 0.6 -- Set bars to 60% opacity

-- =========================
-- Config
-- =========================
local function IsEnabled()
    if not CarpenterDB then return true end
    if CarpenterDB.smallerExpBarEnabled == nil then return true end
    return CarpenterDB.smallerExpBarEnabled
end

-- =========================
-- Core
-- =========================
local function ApplyScale()
    if not IsEnabled() then return end

    -- 1. Main Menu Experience Bar (Standard Classic)
    if MainMenuExpBar then
        if MainMenuExpBar:GetScale() ~= SCALE then
            MainMenuExpBar:SetScale(SCALE)
        end
        MainMenuExpBar:SetAlpha(OPACITY)
    end

    -- 2. Reputation Watch Bar (Standard Classic)
    if ReputationWatchBar then
        if ReputationWatchBar:GetScale() ~= SCALE then
            ReputationWatchBar:SetScale(SCALE)
        end
        ReputationWatchBar:SetAlpha(OPACITY)
    end

    -- 3. Modern Manager (If present in your client version)
    local m = StatusTrackingBarManager
    if m then
        if m:GetScale() ~= SCALE then
            m:SetScale(SCALE)
        end
        m:SetAlpha(OPACITY)
        -- Sometimes the container needs scaling instead of the manager
        if m.BarContainer then
            if m.BarContainer:GetScale() ~= SCALE then
                m.BarContainer:SetScale(SCALE)
            end
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
    ApplyScale()
end)

-- Hook specific update functions to re-apply scale if Blizzard resets it
if MainMenuExpBar_Update then
    hooksecurefunc("MainMenuExpBar_Update", ApplyScale)
end

if ReputationWatchBar_Update then
    hooksecurefunc("ReputationWatchBar_Update", ApplyScale)
end

-- Periodically enforce it (Blizzard UI loves to reset scales on zone in/reload)
C_Timer.After(1, ApplyScale)
C_Timer.After(5, ApplyScale)
