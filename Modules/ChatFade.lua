--[[ Carpenter - ChatFade ]]
-- Fades the chat windows and all of their tabs and reveals them on hover or
-- while typing, with a smooth transition.

local HOVER_PADDING = 10
local HoverFade = Carpenter.HoverFade

-- =========================
-- Config
-- =========================
local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("chatFadeEnabled")
end

-- =========================
-- Core Logic: Hover Fading
-- =========================

local currentAlpha = 1

local function IsInside(frame, ancestor)
    if not ancestor then return false end
    local parent = frame.GetParent and frame:GetParent()
    while parent do
        if parent == ancestor then return true end
        parent = parent.GetParent and parent:GetParent()
    end
    return false
end

-- CHAT_FRAMES also lists temporary whisper windows.
local function ForEachChatFrame(callback)
    if type(CHAT_FRAMES) == "table" then
        for _, name in ipairs(CHAT_FRAMES) do
            local chatFrame = _G[name]
            if chatFrame then callback(chatFrame, _G[name .. "Tab"]) end
        end
        return
    end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then callback(chatFrame, _G["ChatFrame" .. i .. "Tab"]) end
    end
end

-- Blizzard animates tab alpha itself, so a tab outside the dock keeps the
-- alpha Blizzard last gave it and shows that times the fade.
local function ApplyTabAlpha(tab)
    if IsInside(tab, _G.GeneralDockManager) or not IsEnabled() then
        if tab._Carpenter_ChatFadeApplied then
            tab._Carpenter_ChatFadeApplied = nil
            tab._Carpenter_ChatFadeSetting = true
            tab:SetAlpha(tab._Carpenter_ChatFadeBaseAlpha or 1)
            tab._Carpenter_ChatFadeSetting = nil
        end
        return
    end

    tab._Carpenter_ChatFadeApplied = true
    tab._Carpenter_ChatFadeSetting = true
    tab:SetAlpha((tab._Carpenter_ChatFadeBaseAlpha or 1) * currentAlpha)
    tab._Carpenter_ChatFadeSetting = nil
end

local function HookTab(tab)
    if not tab or tab._Carpenter_ChatFadeHooked or not tab.SetAlpha then return end
    tab._Carpenter_ChatFadeHooked = true
    tab._Carpenter_ChatFadeBaseAlpha = tab.GetAlpha and tab:GetAlpha() or 1

    Carpenter:SafeHook(tab, "SetAlpha", function(self, alpha)
        if self._Carpenter_ChatFadeSetting then return end
        self._Carpenter_ChatFadeBaseAlpha = alpha
        ApplyTabAlpha(self)
    end)
end

-- Nothing in Blizzard's chat code sets the chat windows' or the dock's own
-- alpha, so fading them never fights its background and tab animations. The
-- dock holds every docked tab.
local function ApplyFade()
    local alpha = IsEnabled() and currentAlpha or 1
    ForEachChatFrame(function(chatFrame, tab)
        chatFrame:SetAlpha(alpha)
        HookTab(tab)
        if tab then ApplyTabAlpha(tab) end
    end)
    if _G.GeneralDockManager then
        _G.GeneralDockManager:SetAlpha(alpha)
    end
end

local function ShouldShow()
    -- Edit Mode needs to see the chat to move it.
    local editMode = _G.EditModeManagerFrame
    if editMode and editMode.IsEditModeActive and editMode:IsEditModeActive() then
        return true
    end

    local IsHovered = HoverFade.IsMouseOverPaddedFrame
    local shown = IsHovered(_G.GeneralDockManager, HOVER_PADDING, "visible")
    ForEachChatFrame(function(chatFrame, tab)
        if shown then return end
        local editBox = chatFrame.editBox or _G[chatFrame:GetName() .. "EditBox"]
        shown = (editBox and editBox.HasFocus and editBox:HasFocus())
            or IsHovered(chatFrame, HOVER_PADDING, "visible")
            or IsHovered(editBox, HOVER_PADDING, "visible")
            or IsHovered(tab, HOVER_PADDING, "visible")
    end)
    return shown and true or false
end

local chatFrameCount
local fader = HoverFade.Create({
    isEnabled = IsEnabled,
    shouldShow = ShouldShow,
    apply = function(alpha)
        currentAlpha = alpha
        ApplyFade()
    end,
    -- A whisper window opened since the last pass joins the fade too.
    onTick = function()
        local count = type(CHAT_FRAMES) == "table" and #CHAT_FRAMES or 0
        if count ~= chatFrameCount then
            chatFrameCount = count
            return true
        end
    end,
})

-- =========================
-- Events
-- =========================
local frame = CreateFrame("Frame")

-- Docking and undocking moves tabs in and out of the dock.
frame:SetScript("OnEvent", ApplyFade)

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UPDATE_CHAT_WINDOWS")
    frame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    fader:Start(0)
end

function feature:Disable()
    frame:UnregisterAllEvents()
    fader:Stop(1)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("chatFadeEnabled", feature)
end
