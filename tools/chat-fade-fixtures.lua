#!/usr/bin/env lua
-- Verifies Fade Chat fades the chat windows and every tab until the chat is
-- hovered or typed in, multiplies Blizzard's own tab alpha for undocked tabs
-- instead of replacing it, and puts everything back when turned off.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local scripts = {}
local cursorX, cursorY = 0, 0
local feature

local function NewFrame(name, parent, left, bottom, width, height)
    local frame = { alpha = 1, shown = true, parent = parent, name = name }
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    function frame:GetLeft() return left end
    function frame:GetRight() return left + width end
    function frame:GetBottom() return bottom end
    function frame:GetTop() return bottom + height end
    function frame:GetEffectiveScale() return 1 end
    function frame:IsVisible() return self.shown end
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(alpha)
        self.alpha = alpha
        for _, hook in ipairs(self.alphaHooks or {}) do hook(self, alpha) end
    end
    if name then _G[name] = frame end
    return frame
end

function hooksecurefunc(frame, method, hook)
    assert(method == "SetAlpha", "unexpected hook " .. tostring(method))
    frame.alphaHooks = frame.alphaHooks or {}
    table.insert(frame.alphaHooks, hook)
end

function CreateFrame()
    local frame = { shown = true }
    function frame:SetScript(script, handler) scripts[script] = { frame = self, handler = handler } end
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    return frame
end

function GetCursorPosition() return cursorX, cursorY end
UIParent = NewFrame("UIParent", nil, 0, 0, 1920, 1080)
Carpenter = {
    IsEnabled = function(_, key) return key == "chatFadeEnabled" and Carpenter.enabled end,
    RegisterFeature = function(_, key, registered)
        assert(key == "chatFadeEnabled", "unexpected feature key " .. tostring(key))
        feature = registered
    end,
    enabled = true,
}

-- ChatFrame1 and its tab sit in the dock in the bottom left; ChatFrame3 is a
-- separate window in the top right with its tab on UIParent, where Blizzard
-- shows it at 0.4 while the chat isn't hovered.
GeneralDockManager = NewFrame("GeneralDockManager", UIParent, 30, 300, 400, 25)
NewFrame("ChatFrame1", UIParent, 30, 100, 400, 190)
NewFrame("ChatFrame1Tab", GeneralDockManager, 30, 300, 80, 25)
ChatFrame1.editBox = NewFrame("ChatFrame1EditBox", ChatFrame1, 30, 70, 400, 25)
ChatFrame1.editBox.shown = false
function ChatFrame1.editBox:HasFocus() return self.focused end
NewFrame("ChatFrame3", UIParent, 1400, 700, 400, 190)
NewFrame("ChatFrame3Tab", UIParent, 1400, 900, 80, 25)
ChatFrame3Tab.alpha = 0.4
CHAT_FRAMES = { "ChatFrame1", "ChatFrame3" }

assert(loadfile(repo .. "/Modules/ChatFade.lua"))("Carpenter", {})
assert(feature, "the fade should register as a feature")
feature:Enable()

local function Settle()
    for _ = 1, 30 do
        scripts.OnUpdate.handler(scripts.OnUpdate.frame, 0.1)
    end
    return ChatFrame1.alpha
end

assert(ChatFrame1.alpha == 0 and ChatFrame3.alpha == 0 and GeneralDockManager.alpha == 0, "the chat should start faded")
assert(ChatFrame1Tab.alpha == 1, "docked tabs fade with the dock, not on their own")
assert(ChatFrame3Tab.alpha == 0, "an undocked tab should fade too")

cursorX, cursorY = 900, 500
assert(Settle() == 0, "the chat should stay faded away from it")

cursorX, cursorY = 200, 200
assert(Settle() == 1 and GeneralDockManager.alpha == 1 and ChatFrame3.alpha == 1, "hovering the chat should bring all of it back")
assert(ChatFrame3Tab.alpha == 0.4, "an undocked tab should get back Blizzard's own alpha")

cursorX, cursorY = 900, 500
assert(Settle() == 0, "leaving the chat should fade it again")

cursorX, cursorY = 100, 310
assert(Settle() == 1, "hovering the tab bar should bring the chat back")

cursorX, cursorY = 900, 500
Settle()
cursorX, cursorY = 1440, 910
assert(Settle() == 1, "hovering an undocked tab should bring the chat back")

-- Blizzard fades the undocked tab while the chat is faded: the fade keeps
-- its value and multiplies it.
cursorX, cursorY = 900, 500
Settle()
ChatFrame3Tab:SetAlpha(1)
assert(ChatFrame3Tab.alpha == 0, "Blizzard's tab alpha should stay multiplied by the fade")
cursorX, cursorY = 1600, 800
assert(Settle() == 1 and ChatFrame3Tab.alpha == 1, "the tab should show Blizzard's latest alpha once revealed")

cursorX, cursorY = 900, 500
ChatFrame1.editBox.shown = true
ChatFrame1.editBox.focused = true
assert(Settle() == 1, "typing should keep the chat up")
ChatFrame1.editBox.focused = nil
ChatFrame1.editBox.shown = false
assert(Settle() == 0, "the chat should fade once typing ends")

EditModeManagerFrame = { IsEditModeActive = function() return true end }
assert(Settle() == 1, "Edit Mode should always show the chat")
EditModeManagerFrame = nil
Settle()

-- Docking the separate window moves its tab into the dock: it gets its own
-- alpha back, and the dock fades it from then on.
ChatFrame3Tab.parent = GeneralDockManager
ChatFrame3Tab:SetAlpha(0.4)
assert(ChatFrame3Tab.alpha == 0.4, "a docked tab should not be faded twice")

-- A whisper window opened while the chat is faded joins the fade.
NewFrame("ChatFrame11", UIParent, 30, 100, 400, 190)
CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame11"
Settle()
assert(ChatFrame11.alpha == 0, "a new whisper window should fade with the rest")

Carpenter.enabled = false
feature:Disable()
assert(ChatFrame1.alpha == 1 and ChatFrame11.alpha == 1 and GeneralDockManager.alpha == 1, "turning the fade off should restore the chat")

ChatFrame3Tab.parent = UIParent
ChatFrame3Tab:SetAlpha(0.6)
assert(ChatFrame3Tab.alpha == 0.6, "once off, Blizzard's tab alpha should pass straight through")

print("chat fade fixtures: passed")
