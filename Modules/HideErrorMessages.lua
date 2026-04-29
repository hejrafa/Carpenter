--[[ Carpenter - HideErrorMessages ]]
-- When enabled, hides only the error messages in the hide list (and their sound).
-- Add phrases here as you find ones you want to suppress.

-- Phrases in ALWAYS_HIDE are suppressed regardless of the option (e.g. Blizzard camera warning).
local ALWAYS_HIDE = {
    "experimental camera features",
    "visual discomfort",
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
    "invalid target",
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
    if not message or type(message) ~= "string" then return false end
    local lower = message:lower()
    for _, phrase in ipairs(ALWAYS_HIDE) do
        if lower:find(phrase:lower(), 1, true) then return true end
    end
    if not CarpenterDB or not CarpenterDB.hideErrorMessagesEnabled then return false end
    for _, phrase in ipairs(HIDE_PHRASES) do
        if lower:find(phrase:lower(), 1, true) then
            return true
        end
    end
    return false
end

-- Note: We do NOT hook PlaySound to suppress the error "bonk". Replacing the global
-- PlaySound taints the secure UI and blocks actions like Exit Game (addon gets blamed).

local hooked = false

local function HookErrors()
    if not UIErrorsFrame then return end
    if hooked then return end

    local origOnEvent = UIErrorsFrame:GetScript("OnEvent")
    UIErrorsFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UI_ERROR_MESSAGE" then
            local errorType, message = ...

            if ShouldHideError(message) then
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

local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("ADDON_LOADED")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        HookErrors()
        if event == "PLAYER_ENTERING_WORLD" then
            hookFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end
end)

HookErrors()
