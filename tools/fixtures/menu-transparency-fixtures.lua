#!/usr/bin/env lua
-- Verifies Fade Micro Menu & Bags reveals the bars only when the cursor is
-- over them: not over Retail's empty bottom-right anchor once Edit Mode has
-- moved them, and at their real size once Edit Mode has scaled them.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "menu-transparency")

H.installCreateFrame()
H.installCursor()
H.installTimers("ignore")
H.installUIParent()
function IsBagOpen() return false end
H.carpenter({
    Client = { isMainline = true },
    IsEnabled = function(_, key) return key == "menuTransparencyEnabled" end,
    DeferMany = function() end,
    RegisterFeature = H.captureFeature("menuTransparencyEnabled"),
})

local function NewFrame(left, bottom, width, height, scale)
    return H.Frame({ left = left, bottom = bottom, width = width, height = height, scale = scale })
end

-- Retail: the empty anchor stays in the bottom-right corner, while the micro
-- menu was moved to the top left and shrunk to half size in Edit Mode. Its
-- edges are in its own scale: 200..400 wide is 100..200 on screen.
MicroButtonAndBagsBar = NewFrame(1700, 6, 232, 80)
MicroMenuContainer = NewFrame(200, 1800, 200, 80, 0.5)

H.load("Core/HoverFade.lua")
H.load("Modules/MenuTransparency.lua")
local feature = assert(H.features.menuTransparencyEnabled, "the fade should register as a feature")
feature:Enable()

local function Settle()
    H.settle(30, 0.1)
    return MicroMenuContainer.alpha
end

assert(Settle() == 0, "the bars should start hidden")

H.setCursor(1800, 40)
assert(Settle() == 0, "hovering Retail's empty bottom-right anchor must not reveal moved bars")

H.setCursor(150, 920)
assert(Settle() == 1, "hovering the scaled micro menu where it is on screen should reveal it")

H.setCursor(300, 920)
assert(Settle() == 0, "the scaled micro menu should not be hovered past its real right edge")

-- Classic keeps the bar cluster inside MicroButtonAndBagsBar, so it still counts.
Carpenter.Client.isMainline = false
H.setCursor(1800, 40)
assert(Settle() == 1, "on Classic, hovering MicroButtonAndBagsBar should still reveal the bars")

print("menu transparency fixtures: passed")
