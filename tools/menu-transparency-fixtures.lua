#!/usr/bin/env lua
-- Verifies Fade Micro Menu & Bags reveals the bars only when the cursor is
-- over them: not over Retail's empty bottom-right anchor once Edit Mode has
-- moved them, and at their real size once Edit Mode has scaled them.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local scripts = {}
local cursorX, cursorY = 0, 0
local feature

local function NewFrame(left, bottom, width, height, scale)
    local frame = { alpha = 1, shown = true }
    function frame:GetLeft() return left end
    function frame:GetRight() return left + width end
    function frame:GetBottom() return bottom end
    function frame:GetTop() return bottom + height end
    function frame:GetEffectiveScale() return scale or 1 end
    function frame:IsShown() return self.shown end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:GetRegions() end
    function frame:GetNumChildren() return 0 end
    function frame:HookScript() end
    return frame
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
function IsBagOpen() return false end
UIParent = { GetEffectiveScale = function() return 1 end }
C_Timer = { After = function() end }
Carpenter = {
    Client = { isRetail = true },
    IsEnabled = function(_, key) return key == "menuTransparencyEnabled" end,
    DeferMany = function() end,
    RegisterFeature = function(_, key, registered)
        assert(key == "menuTransparencyEnabled", "unexpected feature key " .. tostring(key))
        feature = registered
    end,
}

-- Retail: the empty anchor stays in the bottom-right corner, while the micro
-- menu was moved to the top left and shrunk to half size in Edit Mode. Its
-- edges are in its own scale: 200..400 wide is 100..200 on screen.
MicroButtonAndBagsBar = NewFrame(1700, 6, 232, 80)
MicroMenuContainer = NewFrame(200, 1800, 200, 80, 0.5)

assert(loadfile(repo .. "/Modules/MenuTransparency.lua"))("Carpenter", {})
assert(feature, "the fade should register as a feature")
feature:Enable()

local function Settle()
    for _ = 1, 30 do
        scripts.OnUpdate.handler(scripts.OnUpdate.frame, 0.1)
    end
    return MicroMenuContainer.alpha
end

assert(Settle() == 0, "the bars should start hidden")

cursorX, cursorY = 1800, 40
assert(Settle() == 0, "hovering Retail's empty bottom-right anchor must not reveal moved bars")

cursorX, cursorY = 150, 920
assert(Settle() == 1, "hovering the scaled micro menu where it is on screen should reveal it")

cursorX, cursorY = 300, 920
assert(Settle() == 0, "the scaled micro menu should not be hovered past its real right edge")

-- Classic keeps the bar cluster inside MicroButtonAndBagsBar, so it still counts.
Carpenter.Client.isRetail = false
cursorX, cursorY = 1800, 40
assert(Settle() == 1, "on Classic, hovering MicroButtonAndBagsBar should still reveal the bars")

print("menu transparency fixtures: passed")
