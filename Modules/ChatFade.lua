--[[ Carpenter - ChatFade ]]
-- Fades the chat windows and all of their tabs and reveals them on hover or
-- while typing, with a smooth transition.

local FADE_IN_SECONDS = 0.2
local FADE_OUT_SECONDS = 0.6
local HOVER_PADDING = 10
local UPDATE_INTERVAL = 0.05

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

    hooksecurefunc(tab, "SetAlpha", function(self, alpha)
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

local function IsMouseOverPaddedFrame(frame, padding)
    if not frame or not frame.GetLeft or not frame:IsVisible() then return false end

    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end

    -- A frame's edges are in its own scale, which Edit Mode can change.
    local scale = (frame.GetEffectiveScale and frame:GetEffectiveScale())
        or (UIParent and UIParent:GetEffectiveScale()) or 1
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale

    return x >= left - padding and x <= right + padding and y >= bottom - padding and y <= top + padding
end

local function ShouldShow()
    -- Edit Mode needs to see the chat to move it.
    local editMode = _G.EditModeManagerFrame
    if editMode and editMode.IsEditModeActive and editMode:IsEditModeActive() then
        return true
    end

    local shown = IsMouseOverPaddedFrame(_G.GeneralDockManager, HOVER_PADDING)
    ForEachChatFrame(function(chatFrame, tab)
        if shown then return end
        local editBox = chatFrame.editBox or _G[chatFrame:GetName() .. "EditBox"]
        shown = (editBox and editBox.HasFocus and editBox:HasFocus())
            or IsMouseOverPaddedFrame(chatFrame, HOVER_PADDING)
            or IsMouseOverPaddedFrame(editBox, HOVER_PADDING)
            or IsMouseOverPaddedFrame(tab, HOVER_PADDING)
    end)
    return shown and true or false
end

local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() then
        self:Hide()
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    local step = self.elapsed
    self.elapsed = 0

    local targetAlpha = ShouldShow() and 1 or 0
    local changed = false
    if currentAlpha < targetAlpha then
        currentAlpha = math.min(targetAlpha, currentAlpha + step / FADE_IN_SECONDS)
        changed = true
    elseif currentAlpha > targetAlpha then
        currentAlpha = math.max(targetAlpha, currentAlpha - step / FADE_OUT_SECONDS)
        changed = true
    end

    -- A whisper window opened since the last pass joins the fade too.
    local chatFrameCount = type(CHAT_FRAMES) == "table" and #CHAT_FRAMES or 0
    if chatFrameCount ~= self.chatFrameCount then
        self.chatFrameCount = chatFrameCount
        changed = true
    end

    if changed then
        ApplyFade()
    end
end)

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
    currentAlpha = 0
    ApplyFade()
    updateFrame:Show()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    updateFrame:Hide()
    currentAlpha = 1
    ApplyFade()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("chatFadeEnabled", feature)
end
