--[[ Carpenter - ActionBarFader ]]
-- Makes specific side/extra action bars visible on hover if enabled.
-- Targeted at modern Extra Action Bars (6-8) using internal frame names

local ALPHA_HIDDEN = 0
local ALPHA_VISIBLE = 1.0
local FADE_DURATION = 0.3

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("actionBarFaderEnabled")
end

-- List of bars to apply the effect to (only 7 and 8)
local bars = {
    "MultiBar6", -- Bar 7
    "MultiBar7", -- Bar 8
}

local function FadeFrame(frame, targetAlpha)
    if not frame then return end
    UIFrameFadeIn(frame, FADE_DURATION, frame:GetAlpha(), targetAlpha)
end

local function SetupFader(barName)
    local bar = _G[barName]
    if not bar then return end

    if not bar._Carpenter_FaderHooked then
        -- Handle the parent bar frame
        bar:HookScript("OnEnter", function(self)
            if not IsEnabled() then return end
            FadeFrame(self, ALPHA_VISIBLE)
        end)

        bar:HookScript("OnLeave", function(self)
            if not IsEnabled() then return end
            if not self.IsMouseOver or not self:IsMouseOver() then
                FadeFrame(self, ALPHA_HIDDEN)
            end
        end)

        bar._Carpenter_FaderHooked = true
    end

    -- Initial state on load or toggle
    if IsEnabled() then
        bar:SetAlpha(ALPHA_HIDDEN)
    else
        bar:SetAlpha(1.0)
    end
end

local frame = CreateFrame("Frame")

local function ApplyActionBarFader()
    -- Apply fader only to specified extra bars
    for _, barName in ipairs(bars) do
        SetupFader(barName)

        -- Hook children (buttons) for the targeted frames
        -- Buttons are named: MultiBar5Button1..12, etc.
        for i = 1, 12 do
            local btn = _G[barName .. "Button" .. i]
            if btn and not btn._Carpenter_FaderHooked then
                btn:HookScript("OnEnter", function()
                    if IsEnabled() then FadeFrame(_G[barName], ALPHA_VISIBLE) end
                end)
                btn:HookScript("OnLeave", function()
                    local parentBar = _G[barName]
                    if IsEnabled() and parentBar and
                        (not parentBar.IsMouseOver or not parentBar:IsMouseOver())
                    then
                        FadeFrame(parentBar, ALPHA_HIDDEN)
                    end
                end)
                btn._Carpenter_FaderHooked = true
            end
        end
    end

    -- FORCE VISIBILITY logic
    -- Standard bars (1-5) are always visible
    local alwaysVisible = {
        "MainMenuBar",
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarRight",
        "MultiBarLeft"
    }

    for _, barName in ipairs(alwaysVisible) do
        local b = _G[barName]
        if b then b:SetAlpha(1.0) end
    end

    -- If the option is OFF, also force the extra bars (7-8) to be visible
    if not IsEnabled() then
        for _, barName in ipairs(bars) do
            local b = _G[barName]
            if b then b:SetAlpha(1.0) end
        end
    end
end

frame:SetScript("OnEvent", ApplyActionBarFader)

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ApplyActionBarFader()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    ApplyActionBarFader()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("actionBarFaderEnabled", feature)
end
