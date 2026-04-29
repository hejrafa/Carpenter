--[[ Carpenter - Hide Chat Buttons ]]
-- Reduces opacity of chat buttons to 0% (hidden) and reveals them on hover
-- with a smooth transition, just like the micromenu.

local HIDDEN_OPACITY = 0
local HOVER_OPACITY = 0.65 -- 65% transparent when visible as requested
local FADE_SPEED = 0.05    -- Adjust for faster/slower fading

-- =========================
-- Config
-- =========================
local function IsEnabled()
    if not CarpenterDB then return true end
    if CarpenterDB.hideChatButtonsEnabled == nil then return true end
    return CarpenterDB.hideChatButtonsEnabled
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

-- Define the chat button groups
local chatButtons = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "VoiceChatTalkersButton",
    "ChatFrameToggleButton"
}

local socialButtons = {
    "QuickJoinToastButton", -- Social toast button
    "ChatSocialButton", -- Social button in chat frame
    "FriendsMicroButton", -- Social (O) button near chat
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
for _, group in ipairs({chatButtons, socialButtons, arrowButtons, minimizeButtons}) do
    for _, btn in ipairs(group) do
        table.insert(allChatButtons, btn)
    end
end

local function ApplyTransparency(alpha)
    if not IsEnabled() then
        SetGroupAlpha(allChatButtons, 1.0)
        return
    end

    SetGroupAlpha(allChatButtons, alpha)
    
    -- Try specific known button names to avoid dynamic search errors
    local additionalButtons = {
        "QuickJoinToastButton1",
        "ChatSocialMenuButton",
    }

    SetGroupAlpha(additionalButtons, alpha)
end

-- Create an invisible "hitbox" frame to detect mouse hover for the chat buttons area
local hoverFrame = CreateFrame("Frame", "CarpenterChatButtonHoverFrame", UIParent)
hoverFrame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 5)
hoverFrame:SetPoint("TOPRIGHT", ChatFrame1, "TOPRIGHT", 0, 35)
hoverFrame:SetFrameStrata("TOOLTIP")

-- Logic to detect mouseover and handle smooth fading
hoverFrame:SetScript("OnUpdate", function(self)
    if not IsEnabled() then return end

    -- Check if mouse is over the hover frame OR any of the buttons themselves
    local mouseOverButtons = MouseIsOver(self)
    
    -- Also check each button individually
    if not mouseOverButtons then
        for _, buttonName in ipairs(allChatButtons) do
            local button = _G[buttonName]
            if button and MouseIsOver(button) then
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
    ApplyTransparency(HIDDEN_OPACITY)

    -- Secondary enforcement after a small delay to catch lazy-loading buttons
    C_Timer.After(2, function()
        ApplyTransparency(currentAlpha)
    end)
    C_Timer.After(5, function()
        ApplyTransparency(currentAlpha)
    end)
end)