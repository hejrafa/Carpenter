--[[ Carpenter - MenuTransparency ]]
-- Reduces opacity of the Game Menu and Bag interface buttons to 0% (hidden)
-- and reveals them on hover with a smooth transition.

local HIDDEN_OPACITY = 0
local HOVER_OPACITY = 1
local FADE_SPEED = 0.05    -- Adjust for faster/slower fading
local HOVER_PADDING = 14
local UPDATE_INTERVAL = 0.05

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

local function SetFrameAlpha(frame, alpha, depth)
    if not frame then return end
    depth = depth or 0

    if frame.SetAlpha then
        frame:SetAlpha(alpha)
    end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
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

local function IsMouseOverPaddedFrame(frame, padding)
    if not frame or not frame.GetLeft or not frame:IsShown() then return false end

    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end

    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    padding = padding or 0

    return x >= left - padding and x <= right + padding and y >= bottom - padding and y <= top + padding
end

local function IsMouseOverGroup(group, padding)
    for _, name in ipairs(group) do
        if IsMouseOverPaddedFrame(_G[name], padding) then
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
        SetupButtonHover(_G[name], "micro")
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

-- Logic to detect mouseover and handle smooth fading
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then
        self:Hide()
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    self.elapsed = 0

    -- Check if any bag/menu is actually open
    local bagsOpen = false
    for i = 0, 4 do
        if IsBagOpen and IsBagOpen(i) then
            bagsOpen = true
            break
        end
    end

    -- Treat the micro menu and bags as one cluster.
    local clusterHovered = hoverCount > 0
        or IsMouseOverGroup(containerFrames, HOVER_PADDING)
        or IsMouseOverGroup(bagButtons, HOVER_PADDING)
        or IsMouseOverGroup(microButtons, HOVER_PADDING)

    if clusterHovered or bagsOpen then
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
    if IsEnabled() then updateFrame:Show() else updateFrame:Hide() end

    -- Secondary enforcement after a small delay to catch lazy-loading buttons (like Guild button)
    C_Timer.After(2, function()
        SetupButtonHoverScripts()
        ApplyTransparency(currentAlpha)
        if IsEnabled() then updateFrame:Show() else updateFrame:Hide() end
    end)
    C_Timer.After(5, function()
        SetupButtonHoverScripts()
        ApplyTransparency(currentAlpha)
        if IsEnabled() then updateFrame:Show() else updateFrame:Hide() end
    end)
end)
updateFrame:Hide()
