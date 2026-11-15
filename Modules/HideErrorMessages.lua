--[[ Carpenter - HideErrorMessages ]]
-- When enabled, hides only the error messages in the hide list (and their sound),
-- whether they come with the game's error event or are written straight onto
-- the error frame. Add phrases here as you find ones you want to suppress.

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
    if issecretvalue and issecretvalue(message) then return false end
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

-- Some Blizzard code writes its errors straight onto the frame, with no
-- error event: the Auction House shows "Internal auction error." that way.
-- They are added as one line under the game's system error ID, with no
-- sound, so a post-hook blanks that line right after it is added and
-- nothing of Blizzard's is replaced.
local function BlankExternalError(frame, message)
    if not ProfileShouldHideError(message) then return end
    local id = _G.LE_GAME_ERR_SYSTEM
    local line = id and frame.GetFontStringByID and frame:GetFontStringByID(id)
    if not line then return end
    local text = line:GetText()
    if issecretvalue and issecretvalue(text) then return end
    if text == message then
        line:SetText("")
    end
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
                return
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
