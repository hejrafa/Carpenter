--[[ Carpenter - MenuTransparency ]]
-- Reduces opacity of the Game Menu and Bag interface buttons to 0% (hidden)
-- and reveals them on hover with a smooth transition.

local HOVER_PADDING = 14
local HoverFade = Carpenter.HoverFade

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("menuTransparencyEnabled")
end

-- =========================
-- Core Logic: Hover Fading
-- =========================

local function SetFrameAlpha(frame, alpha, depth)
    if not frame then return end
    depth = depth or 0

    if frame.SetAlpha then
        frame:SetAlpha(alpha)
    end

    if frame.GetRegions then
        for i = 1, select("#", frame:GetRegions()) do
            local region = select(i, frame:GetRegions())
            if region and region.SetAlpha then
                region:SetAlpha(alpha)
            end
        end
    end

    if depth >= 3 or not frame.GetChildren then return end
    for i = 1, frame:GetNumChildren() do
        SetFrameAlpha(select(i, frame:GetChildren()), alpha, depth + 1)
    end
end

local function SetGroupAlpha(group, alpha)
    for _, name in ipairs(group) do
        local btn = _G[name]
        if btn then
            SetFrameAlpha(btn, alpha)
        end
    end
end

-- Define the button groups
local containerFrames = {
    "MicroButtonAndBagsBar",
    "MicroMenuContainer",
    "BagsBar",
    "BagBarExpandToggle",
}

local bagButtons = {
    "MainMenuBarBackpackButton",
    "KeyRingButton",
    "KeyringButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
}

local microButtons = {
    "MainMenuBarPerformanceBar",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "ProfessionMicroButton",
    "QuestLogMicroButton",
    "AchievementMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "PVPMicroButton",
    "LFGMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
}

-- On Retail and WoW Forever, MicroButtonAndBagsBar is an empty anchor fixed in
-- the bottom-right corner. Edit Mode moves the real micro menu and bag bar
-- away from it, so hovering that corner must not count as hovering them.
local function IsHoverArea(name)
    local client = Carpenter and Carpenter.Client
    return not (name == "MicroButtonAndBagsBar" and client and client.isMainline)
end

local function IsMouseOverGroup(group, padding)
    for _, name in ipairs(group) do
        if IsHoverArea(name) and HoverFade.IsMouseOverPaddedFrame(_G[name], padding, "shown") then
            return true
        end
    end
    return false
end

-- Track hover state across the whole micro/menu bag cluster.
local hoverCount = 0

-- Function to handle hover enter/exit for individual buttons
local function SetupButtonHover(button, group)
    if not button then return end
    if button._Carpenter_MenuTransparencyHooked then return end
    button._Carpenter_MenuTransparencyHooked = true
    
    button:HookScript("OnEnter", function()
        hoverCount = hoverCount + 1
    end)
    
    button:HookScript("OnLeave", function()
        hoverCount = math.max(0, hoverCount - 1)
    end)
end

-- Function to setup hover scripts on all buttons
local function SetupButtonHoverScripts()
    for _, name in ipairs(containerFrames) do
        if IsHoverArea(name) then
            SetupButtonHover(_G[name], "micro")
        end
    end

    for _, name in ipairs(bagButtons) do
        SetupButtonHover(_G[name], "bag")
    end
    
    for _, name in ipairs(microButtons) do
        SetupButtonHover(_G[name], "micro")
    end
end

local function ApplyTransparency(alpha)
    if not IsEnabled() then
        SetGroupAlpha(containerFrames, 1.0)
        SetGroupAlpha(bagButtons, 1.0)
        SetGroupAlpha(microButtons, 1.0)
        return
    end

    SetGroupAlpha(containerFrames, alpha)
    SetGroupAlpha(bagButtons, alpha)
    SetGroupAlpha(microButtons, alpha)
end

local function ShouldShow()
    -- An open bag keeps the bars up.
    for i = 0, 4 do
        if IsBagOpen and IsBagOpen(i) then return true end
    end

    -- Treat the micro menu and bags as one cluster.
    return hoverCount > 0
        or IsMouseOverGroup(containerFrames, HOVER_PADDING)
        or IsMouseOverGroup(bagButtons, HOVER_PADDING)
        or IsMouseOverGroup(microButtons, HOVER_PADDING)
end

local fader = HoverFade.Create({
    isEnabled = IsEnabled,
    shouldShow = ShouldShow,
    apply = ApplyTransparency,
})

-- =========================
-- Events
-- =========================
local frame = CreateFrame("Frame")

-- Buttons that load late (the Guild button) get their hooks and alpha on
-- the later passes.
local function RefreshStartupState()
    SetupButtonHoverScripts()
    if IsEnabled() then fader:Start() else fader:Stop() end
    fader:Apply()
end

local function ApplyStartupState()
    SetupButtonHoverScripts()
    if IsEnabled() then fader:Start(0) else fader:Stop(0) end

    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("MenuTransparency:startup", { 2, 5 }, RefreshStartupState)
    else
        C_Timer.After(2, RefreshStartupState)
        C_Timer.After(5, RefreshStartupState)
    end
end

frame:SetScript("OnEvent", ApplyStartupState)

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ApplyStartupState()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    fader:Stop(1)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("menuTransparencyEnabled", feature)
end
