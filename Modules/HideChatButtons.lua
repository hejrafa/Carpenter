--[[ Carpenter - Hide Chat Buttons ]]
-- Reduces opacity of chat buttons to 0% (hidden) and reveals them on hover
-- with a smooth transition, just like the micromenu.

local HoverFade = Carpenter.HoverFade
local IsMouseOverFrame = HoverFade.IsMouseOverFrame

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("hideChatButtonsEnabled")
end

-- Frames whose regions and children run their own alpha animations (the
-- Retail and Forever QuickJoinToastButton keeps its queue icon, flash and
-- toasts at 0 until a toast plays), so only the frame itself is faded.
local frameAlphaOnly = {
    QuickJoinToastButton = true,
}

-- =========================
-- Core Logic: Hover Fading
-- =========================

local fader

local function SetFrameAlpha(frame, alpha, depth)
    if not frame then return end
    depth = depth or 0

    if frame.SetAlpha then
        frame._CarpenterChatButtonsSettingAlpha = true
        frame:SetAlpha(alpha)
        frame._CarpenterChatButtonsSettingAlpha = nil
    end

    if depth == 0 and frame.GetName and frameAlphaOnly[frame:GetName() or ""] then return end

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
                SetFrameAlpha(self, fader.alpha)
            end
        end)
    end

    if frame.SetAlpha then
        hooksecurefunc(frame, "SetAlpha", function(self)
            if IsEnabled() and not self._CarpenterChatButtonsSettingAlpha then
                SetFrameAlpha(self, fader.alpha)
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

-- The social button beside the chat: the quick-join toast on Retail and
-- Forever, the friends button on Classic.
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
for _, group in ipairs({chatButtons, arrowButtons, minimizeButtons, socialButtons}) do
    for _, btn in ipairs(group) do
        table.insert(allChatButtons, btn)
    end
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
    if not IsEnabled() then
        SetGroupAlpha(allChatButtons, 1.0)
        SetFramesAlpha(chatTabs, 1.0)
        return
    end

    SetGroupAlpha(allChatButtons, alpha)
    SetFramesAlpha(chatTabs, alpha)
    
end

-- Create an invisible "hitbox" frame to detect mouse hover for the chat buttons area
local hoverFrame = CreateFrame("Frame", "CarpenterChatButtonHoverFrame", UIParent)
hoverFrame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 5)
hoverFrame:SetPoint("TOPRIGHT", ChatFrame1, "TOPRIGHT", 0, 35)
hoverFrame:SetFrameStrata("TOOLTIP")

-- The hitbox, any of the buttons, a chat window or a tab under the mouse
-- keeps the buttons up.
local function ShouldShow()
    if IsMouseOverFrame(hoverFrame) then return true end

    RefreshChatFrames()
    for _, buttonName in ipairs(allChatButtons) do
        if IsMouseOverFrame(_G[buttonName]) then return true end
    end
    for _, chatFrame in ipairs(chatFrames) do
        if IsMouseOverFrame(chatFrame) then return true end
    end
    for _, tab in ipairs(chatTabs) do
        if IsMouseOverFrame(tab) then return true end
    end
    return false
end

fader = HoverFade.Create({
    isEnabled = IsEnabled,
    shouldShow = ShouldShow,
    apply = ApplyTransparency,
})

-- =========================
-- Events
-- =========================
local frame = CreateFrame("Frame")

local function SetRunning(running)
    if running then
        hoverFrame:Show()
        fader:Start()
    else
        hoverFrame:Hide()
        fader:Stop()
    end
end

-- Buttons that load late get their hooks and alpha on the later passes.
local function RefreshStartupState()
    RefreshChatFrames()
    fader:Apply()
    SetRunning(IsEnabled())
end

local function ApplyStartupState()
    RefreshChatFrames()
    fader.alpha = 0
    RefreshStartupState()

    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("HideChatButtons:startup", { 2, 5 }, RefreshStartupState)
    else
        C_Timer.After(2, RefreshStartupState)
        C_Timer.After(5, RefreshStartupState)
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
    SetRunning(false)
    fader:Stop(1)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("hideChatButtonsEnabled", feature)
end
