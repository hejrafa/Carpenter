--[[ Carpenter - MenuTransparency ]]
-- Reduces opacity of the Game Menu and Bag interface buttons to 0% (hidden)
-- and reveals them on hover with a smooth transition.

local HIDDEN_OPACITY = 0
local HOVER_OPACITY = 0.65 -- 65% transparent when visible as requested
local FADE_SPEED = 0.05    -- Adjust for faster/slower fading

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("menuTransparencyEnabled")
end

-- =========================
-- Core Logic: Hover Fading
-- =========================

local currentAlpha = 0
local targetAlpha = 0

local function SetGroupAlpha(group, alpha)
    for _, name in ipairs(group) do
        local btn = _G[name]
        if btn then
            btn:SetAlpha(alpha)
            -- Handle specific icon textures or flash textures if they exist
            local icon = _G[name .. "IconTexture"]
            if icon then icon:SetAlpha(alpha) end
            local flash = _G[name .. "Flash"]
            if flash then flash:SetAlpha(alpha) end
        end
    end
end

-- Define the button groups
local bagButtons = {
    "MainMenuBarBackpackButton",
    "KeyRingButton",
    "KeyringButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
}

local microButtons = {
    "MainMenuBarPerformanceBar",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "PVPMicroButton",
    "LFGMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
}

-- Track hover state for each button group
local bagHoverCount = 0
local microHoverCount = 0

-- Function to handle hover enter/exit for individual buttons
local function SetupButtonHover(button, group)
    if not button then return end
    if button._Carpenter_MenuTransparencyHooked then return end
    button._Carpenter_MenuTransparencyHooked = true
    
    button:HookScript("OnEnter", function()
        if group == "bag" then
            bagHoverCount = bagHoverCount + 1
        else
            microHoverCount = microHoverCount + 1
        end
    end)
    
    button:HookScript("OnLeave", function()
        if group == "bag" then
            bagHoverCount = math.max(0, bagHoverCount - 1)
        else
            microHoverCount = math.max(0, microHoverCount - 1)
        end
    end)
end

-- Function to setup hover scripts on all buttons
local function SetupButtonHoverScripts()
    for _, name in ipairs(bagButtons) do
        SetupButtonHover(_G[name], "bag")
    end
    
    for _, name in ipairs(microButtons) do
        SetupButtonHover(_G[name], "micro")
    end
end

local function ApplyTransparency(alpha)
    if not IsEnabled() then
        SetGroupAlpha(bagButtons, 1.0)
        SetGroupAlpha(microButtons, 1.0)
        return
    end

    SetGroupAlpha(bagButtons, alpha)
    SetGroupAlpha(microButtons, alpha)
end

-- Logic to detect mouseover and handle smooth fading
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self)
    if not IsEnabled() then return end

    -- Check if any bag/menu is actually open
    local bagsOpen = false
    for i = 0, 4 do
        if IsBagOpen(i) then
            bagsOpen = true
            break
        end
    end

    -- Determine the goal alpha based on button hover or bags open (not character pane)
    if bagHoverCount > 0 or microHoverCount > 0 or bagsOpen then
        targetAlpha = HOVER_OPACITY
    else
        targetAlpha = HIDDEN_OPACITY
    end

    -- Smooth transition logic
    if currentAlpha ~= targetAlpha then
        if currentAlpha < targetAlpha then
            currentAlpha = math.min(targetAlpha, currentAlpha + FADE_SPEED)
        else
            currentAlpha = math.max(targetAlpha, currentAlpha - FADE_SPEED)
        end
        ApplyTransparency(currentAlpha)
    end
end)

-- =========================
-- Events
-- =========================
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function()
    currentAlpha = HIDDEN_OPACITY
    SetupButtonHoverScripts()
    ApplyTransparency(HIDDEN_OPACITY)

    -- Secondary enforcement after a small delay to catch lazy-loading buttons (like Guild button)
    C_Timer.After(2, function()
        SetupButtonHoverScripts()
        ApplyTransparency(currentAlpha)
    end)
    C_Timer.After(5, function()
        SetupButtonHoverScripts()
        ApplyTransparency(currentAlpha)
    end)
end)
