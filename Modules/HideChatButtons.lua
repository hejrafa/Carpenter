--[[ Carpenter - Hide Chat Buttons ]]
-- Reduces opacity of chat buttons to 0% (hidden) and reveals them on hover
-- with a smooth transition, just like the micromenu.

local HIDDEN_OPACITY = 0
local HOVER_OPACITY = 1
local FADE_IN_SPEED = 0.25
local FADE_OUT_SPEED = 0.08
local UPDATE_INTERVAL = 0.05

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("hideChatButtonsEnabled")
end

local function ShouldManageSocialButtons()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic
end

local function IsMouseOverFrame(frame)
    if not frame then return false end

    if type(frame.IsMouseOver) == "function" then
        return frame:IsMouseOver() == true
    end

    if type(MouseIsOver) == "function" then
        return MouseIsOver(frame) == true
    end

    return false
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
        frame._CarpenterChatButtonsSettingAlpha = true
        frame:SetAlpha(alpha)
        frame._CarpenterChatButtonsSettingAlpha = nil
    end

    if frame.GetRegions then
        for i = 1, select("#", frame:GetRegions()) do
            local region = select(i, frame:GetRegions())
            if region and region.SetAlpha then
                region:SetAlpha(alpha)
            end
        end
    end

    if depth >= 2 or not frame.GetChildren then return end
    for i = 1, frame:GetNumChildren() do
        SetFrameAlpha(select(i, frame:GetChildren()), alpha, depth + 1)
    end
end

local function HookManagedFrame(frame)
    if not frame or frame._CarpenterChatButtonsHooked then return end
    frame._CarpenterChatButtonsHooked = true

    if frame.Show then
        hooksecurefunc(frame, "Show", function(self)
            if IsEnabled() then
                SetFrameAlpha(self, currentAlpha)
            end
        end)
    end

    if frame.SetAlpha then
        hooksecurefunc(frame, "SetAlpha", function(self)
            if IsEnabled() and not self._CarpenterChatButtonsSettingAlpha then
                SetFrameAlpha(self, currentAlpha)
            end
        end)
    end
end

local function SetGroupAlpha(group, alpha)
    for _, name in ipairs(group) do
        local frame = _G[name]
        HookManagedFrame(frame)
        SetFrameAlpha(frame, alpha)
    end
end

local function SetFramesAlpha(frames, alpha)
    for _, frame in ipairs(frames) do
        HookManagedFrame(frame)
        SetFrameAlpha(frame, alpha)
    end
end

-- Define the chat button groups
local chatButtons = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "VoiceChatTalkersButton",
    "ChatFrameToggleButton"
}

local socialButtons = {
    "QuickJoinToastButton",
    "ChatSocialButton",
    "FriendsMicroButton",
}

-- Chat minimize and other buttons
local minimizeButtons = {
    "ChatFrame1MinimizeButton",
    "ChatFrame2MinimizeButton", 
    "ChatFrame3MinimizeButton",
    "ChatFrame4MinimizeButton",
    "ChatFrame1MaximizeButton",
    "ChatFrame2MaximizeButton",
    "ChatFrame3MaximizeButton", 
    "ChatFrame4MaximizeButton"
}

-- Arrow buttons for chat scrolling (using correct names from Leatrix code)
local arrowButtons = {
    -- Correct button frame names from Leatrix
    "ChatFrame1ButtonFrameUpButton",
    "ChatFrame1ButtonFrameDownButton",
    "ChatFrame1ButtonFrameBottomButton",
    "ChatFrame2ButtonFrameUpButton",
    "ChatFrame2ButtonFrameDownButton", 
    "ChatFrame2ButtonFrameBottomButton",
    "ChatFrame3ButtonFrameUpButton",
    "ChatFrame3ButtonFrameDownButton",
    "ChatFrame3ButtonFrameBottomButton",
    "ChatFrame4ButtonFrameUpButton",
    "ChatFrame4ButtonFrameDownButton",
    "ChatFrame4ButtonFrameBottomButton"
}

-- All buttons that should be affected
local allChatButtons = {}
for _, group in ipairs({chatButtons, arrowButtons, minimizeButtons}) do
    for _, btn in ipairs(group) do
        table.insert(allChatButtons, btn)
    end
end

local allChatButtonsWithSocial = {}
for _, btn in ipairs(allChatButtons) do
    table.insert(allChatButtonsWithSocial, btn)
end
for _, btn in ipairs(socialButtons) do
    table.insert(allChatButtonsWithSocial, btn)
end

local function GetManagedChatButtons()
    return ShouldManageSocialButtons() and allChatButtonsWithSocial or allChatButtons
end

local chatTabs = {}
local chatFrames = {}

local function RefreshChatFrames()
    chatTabs = {}
    chatFrames = {}
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if chatFrame then
            table.insert(chatFrames, chatFrame)
        end
        if tab then
            HookManagedFrame(tab)
            table.insert(chatTabs, tab)
        end
    end
end

local function ApplyTransparency(alpha)
    local managedChatButtons = GetManagedChatButtons()

    if not IsEnabled() then
        SetGroupAlpha(managedChatButtons, 1.0)
        SetFramesAlpha(chatTabs, 1.0)
        return
    end

    SetGroupAlpha(managedChatButtons, alpha)
    SetFramesAlpha(chatTabs, alpha)
    
end

-- Create an invisible "hitbox" frame to detect mouse hover for the chat buttons area
local hoverFrame = CreateFrame("Frame", "CarpenterChatButtonHoverFrame", UIParent)
hoverFrame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 5)
hoverFrame:SetPoint("TOPRIGHT", ChatFrame1, "TOPRIGHT", 0, 35)
hoverFrame:SetFrameStrata("TOOLTIP")

-- Logic to detect mouseover and handle smooth fading
hoverFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then
        self:Hide()
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    self.elapsed = 0

    -- Check if mouse is over the hover frame OR any of the buttons themselves
    local mouseOverButtons = IsMouseOverFrame(self)
    
    -- Also check each button individually
    if not mouseOverButtons then
        RefreshChatFrames()
        for _, buttonName in ipairs(GetManagedChatButtons()) do
            local button = _G[buttonName]
            if IsMouseOverFrame(button) then
                mouseOverButtons = true
                break
            end
        end
    end

    if not mouseOverButtons then
        for _, chatFrame in ipairs(chatFrames) do
            if IsMouseOverFrame(chatFrame) then
                mouseOverButtons = true
                break
            end
        end
    end

    if not mouseOverButtons then
        for _, tab in ipairs(chatTabs) do
            if IsMouseOverFrame(tab) then
                mouseOverButtons = true
                break
            end
        end
    end

    -- Determine the goal alpha
    if mouseOverButtons then
        targetAlpha = HOVER_OPACITY
    else
        targetAlpha = HIDDEN_OPACITY
    end

    -- Smooth transition logic
    if currentAlpha ~= targetAlpha then
        if currentAlpha < targetAlpha then
            currentAlpha = math.min(targetAlpha, currentAlpha + FADE_IN_SPEED)
        else
            currentAlpha = math.max(targetAlpha, currentAlpha - FADE_OUT_SPEED)
        end
        ApplyTransparency(currentAlpha)
    end
end)

-- =========================
-- Events
-- =========================
local frame = CreateFrame("Frame")

local function ApplyStartupState()
    currentAlpha = HIDDEN_OPACITY
    RefreshChatFrames()
    ApplyTransparency(HIDDEN_OPACITY)
    if IsEnabled() then hoverFrame:Show() else hoverFrame:Hide() end

    -- Secondary enforcement after a small delay to catch lazy-loading buttons
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("HideChatButtons:startup", { 2, 5 }, function()
            RefreshChatFrames()
            ApplyTransparency(currentAlpha)
            if IsEnabled() then hoverFrame:Show() else hoverFrame:Hide() end
        end)
    else
        C_Timer.After(2, function()
            RefreshChatFrames()
            ApplyTransparency(currentAlpha)
            if IsEnabled() then hoverFrame:Show() else hoverFrame:Hide() end
        end)
        C_Timer.After(5, function()
            RefreshChatFrames()
            ApplyTransparency(currentAlpha)
            if IsEnabled() then hoverFrame:Show() else hoverFrame:Hide() end
        end)
    end
end

frame:SetScript("OnEvent", ApplyStartupState)
hoverFrame:Hide()

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UPDATE_CHAT_WINDOWS")
    ApplyStartupState()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    hoverFrame:Hide()
    currentAlpha = 1
    targetAlpha = 1
    ApplyTransparency(1)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("hideChatButtonsEnabled", feature)
end
