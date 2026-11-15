--[[ Carpenter - HideErrorMessages ]]
-- When enabled, hides only the error messages in the hide list (and their sound),
-- whether they come with the game's error event or are written straight onto
-- the error frame. Add phrases here as you find ones you want to suppress.

local IsSecret = Carpenter.Secret.IsSecret

-- These belong to Action Cam and must not affect Blizzard warnings from other
-- addons when Carpenter's camera feature is disabled.
local ACTION_CAM_HIDE_PHRASES = {
    "experimental camera features",
    "visual discomfort",
}

local NEVER_HIDE = {
    "invalid target",
    "target is in combat",
}

local HIDE_PHRASES = {
    "not enough energy",
    "not ready yet",
    "out of range",
    "needs combo points",
    "requires combo points",
    "in front of you",
    "cannot attack that target",
    "too far away",
    "facing the wrong way",
    "required combo points",
    "must have a fishing pole equipped",
    "can't do that while moving",
    "there is nothing to attack",
    "too full",
    "you are in combat",
    "you have no target",
    "can't carry anymore of these items",
    "can't carry any more of those items",
    "the object is busy",
    "need to be closer to interact",
    "can't attack while stunned",
    "can't attack while horrified",
    "can't attack while disoriented",
    "can't attack while fleeing",
    "can't attack while polymorphed",
    "can't do that while stunned",
    "can't do that while fleeing",
    "you can't do that right now",
    "item is still being rolled",
    "must have a dagger equipped",
    "must have a melee weapon equipped",
    "must be in stealth",
    "target is dead",
    "the item was not found",
    "you don't have permission",
    "internal mail database error",
    "internal bag error",
    "internal auction error",
    "cannot drink any more yet",
    "interrupted",
    "someone is already looting that corpse",
}

local function ShouldHideError(message)
    -- Text the game hides from addons can't be searched.
    if IsSecret(message) then return false end
    if not message or type(message) ~= "string" then return false end
    local lower = message:lower()
    for _, phrase in ipairs(NEVER_HIDE) do
        if lower:find(phrase:lower(), 1, true) then return false end
    end
    if Carpenter and Carpenter:IsEnabled("actionCamEnabled") then
        for _, phrase in ipairs(ACTION_CAM_HIDE_PHRASES) do
            if lower:find(phrase:lower(), 1, true) then return true end
        end
    end
    if not (Carpenter and Carpenter:IsEnabled("hideErrorMessagesEnabled")) then return false end
    for _, phrase in ipairs(HIDE_PHRASES) do
        if lower:find(phrase:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function ProfileShouldHideError(message)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("HideErrorMessages:ShouldHideError", ShouldHideError, message)
    end
    return ShouldHideError(message)
end

-- Note: We do NOT hook PlaySound to suppress the error "bonk". Replacing the global
-- PlaySound taints the secure UI and blocks actions like Exit Game (addon gets blamed).

local hooked = false

-- =========================
-- TEMPORARY probe: listed errors written straight onto the error frame
-- =========================
-- Logs what the frame holds when a listed error is written onto it, when its
-- line turns up, and whether a blanked line stays blank, to
-- CarpenterDB.hideErrorProbeLog. Remove once the auction error stays hidden.
local probeLog = {}
local function Probe(text)
    if #probeLog >= 100 then return end
    local now = GetTime and GetTime() or 0
    probeLog[#probeLog + 1] = string.format("%.2f %s", now, (text:gsub("|", "||")))
    if CarpenterDB then CarpenterDB.hideErrorProbeLog = probeLog end
end

local function ProbeText(value)
    if IsSecret(value) then return "secret" end
    if value == nil then return "nil" end
    return string.format("%q", tostring(value))
end

local function ProbeSystemLine()
    local id = _G.LE_GAME_ERR_SYSTEM
    local frame = UIErrorsFrame
    local line = frame and id and frame.GetFontStringByID and frame:GetFontStringByID(id)
    if not line then return "none" end
    return ProbeText(line:GetText())
end

-- Some Blizzard code writes its errors straight onto the frame, with no
-- error event: the Auction House shows "Internal auction error." that way.
-- They are added as one line under the game's system error ID, with no
-- sound. The frame only draws a new line on its next update, so the line is
-- looked for each frame, for up to a second, and blanked once it shows the
-- error. Nothing of Blizzard's is replaced.
local BLANK_WAIT_SECONDS = 1
local pendingBlanks = {}
local blankWatcher = CreateFrame("Frame")
blankWatcher:Hide()

-- Blanks the newest system line if it shows message.
local function BlankSystemLine(message)
    local id = _G.LE_GAME_ERR_SYSTEM
    local frame = UIErrorsFrame
    local line = frame and id and frame.GetFontStringByID and frame:GetFontStringByID(id)
    if not line then return false end
    local text = line:GetText()
    if IsSecret(text) then return false end
    if text ~= message then return false end
    line:SetText("")
    return true
end

local function ProbeBlanked(pending)
    Probe(string.format("blanked %s after %d checks", ProbeText(pending.text), pending.checks))
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() Probe("line +0.5s: " .. ProbeSystemLine()) end)
    end
end

blankWatcher:SetScript("OnUpdate", function(self)
    local now = GetTime()
    for index = #pendingBlanks, 1, -1 do
        local pending = pendingBlanks[index]
        pending.checks = pending.checks + 1
        if BlankSystemLine(pending.text) then
            ProbeBlanked(pending)
            table.remove(pendingBlanks, index)
        elseif now > pending.untilTime then
            Probe("gave up on " .. ProbeText(pending.text) .. ", line " .. ProbeSystemLine())
            table.remove(pendingBlanks, index)
        end
    end
    if #pendingBlanks == 0 then self:Hide() end
end)

local function BlankExternalError(_, message)
    local hide = ProfileShouldHideError(message)
    Probe("external " .. ProbeText(message) .. " hide=" .. tostring(hide) .. " line " .. ProbeSystemLine())
    if not hide then return end
    local pending = { text = message, untilTime = GetTime() + BLANK_WAIT_SECONDS, checks = 0 }
    -- A client that draws the line right away needs no wait.
    if BlankSystemLine(message) then
        ProbeBlanked(pending)
        return
    end
    pendingBlanks[#pendingBlanks + 1] = pending
    blankWatcher:Show()
end

local function HookErrors()
    if not UIErrorsFrame then return end
    if hooked then return end

    if Carpenter and Carpenter.SafeHook then
        Carpenter:SafeHook(UIErrorsFrame, "AddExternalErrorMessage", BlankExternalError)
    end

    local origOnEvent = UIErrorsFrame:GetScript("OnEvent")
    UIErrorsFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UI_ERROR_MESSAGE" then
            local errorType, message = ...

            if ProfileShouldHideError(message) then
                if type(message) == "string" and not IsSecret(message)
                    and message:lower():find("auction", 1, true) then
                    Probe("event hid " .. ProbeText(message))
                end
                return
            end
            if type(message) == "string" and not IsSecret(message)
                and message:lower():find("auction", 1, true) then
                Probe("event passed " .. ProbeText(message))
            end

            -- Customize "Player is already in a group." → red & clearer wording
            if message == ERR_ALREADY_IN_GROUP_S or message == "Player is already in a group." then
                local newMessage = "|cffff0000Player is in a group|r"
                if origOnEvent then
                    return origOnEvent(self, event, errorType, newMessage)
                else
                    return
                end
            end
        end

        if origOnEvent then
            return origOnEvent(self, event, ...)
        end
    end)
    hooked = true
end

-- The hook is installed the first time an option needs it (this one, or
-- Action Cam hiding its camera warnings). It can't be removed again, but it
-- checks both options on every message, so turning them off takes effect
-- right away.
if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("hideErrorMessagesEnabled", { Enable = HookErrors })
    Carpenter:RegisterFeature("actionCamEnabled", { Enable = HookErrors })
end
