#!/usr/bin/env lua
-- Verifies the shared hover fader: padded hit tests in the frame's own scale
-- with optional visibility, a fade that steps over fixed times toward what
-- shouldShow says, and Start/Stop/Apply driving the apply callback.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixture-harness.lua")(repo, "hover-fade")

H.installCreateFrame()
H.installCursor()
H.installUIParent()
H.carpenter({})

H.load("Core/HoverFade.lua")
local HoverFade = assert(Carpenter.HoverFade, "the hover fader did not register on Carpenter")

-- A 100x100 frame at 200,200, drawn at half scale so it covers 100..150.
local frame = H.Frame({ left = 200, bottom = 200, width = 100, height = 100, scale = 0.5, visible = true })

H.setCursor(125, 125)
assert(HoverFade.IsMouseOverPaddedFrame(frame, 0), "the cursor inside the scaled frame should count")
H.setCursor(155, 125)
assert(not HoverFade.IsMouseOverPaddedFrame(frame, 0), "the cursor past the scaled edge should not count")
assert(HoverFade.IsMouseOverPaddedFrame(frame, 14), "padding should widen the frame in its own scale")
assert(not HoverFade.IsMouseOverPaddedFrame(nil, 14), "a missing frame is never hovered")

H.setCursor(125, 125)
frame.shown = false
assert(HoverFade.IsMouseOverPaddedFrame(frame, 0), "without a visibility check a hidden frame keeps its edges")
assert(not HoverFade.IsMouseOverPaddedFrame(frame, 0, "shown"), "a hidden frame should fail the shown check")
frame.shown = true
frame.visible = false
assert(HoverFade.IsMouseOverPaddedFrame(frame, 0, "shown"), "a shown frame should pass the shown check")
assert(not HoverFade.IsMouseOverPaddedFrame(frame, 0, "visible"), "an invisible frame should fail the visible check")

-- Hit tests by the frame's own method, or the legacy global without it.
local hit = { IsMouseOver = function() return true end }
assert(HoverFade.IsMouseOverFrame(hit), "a frame's own hit test should count")
MouseIsOver = function(target) return target.legacy == true end
assert(HoverFade.IsMouseOverFrame({ legacy = true }), "the legacy global should stand in for a missing method")
assert(not HoverFade.IsMouseOverFrame(nil), "a missing frame is never hovered")

-- The fade itself.
local enabled, show = true, false
local applied = {}
local ticks = 0
local fader = HoverFade.Create({
    isEnabled = function() return enabled end,
    shouldShow = function() return show end,
    apply = function(alpha) applied[#applied + 1] = alpha end,
    onTick = function() ticks = ticks + 1 end,
    fadeIn = 0.2,
    fadeOut = 0.4,
    interval = 0.05,
})
local update = assert(H.scripts.OnUpdate, "the fader should drive an OnUpdate")
local function Tick(elapsed) update.handler(update.frame, elapsed or 0.1) end

assert(not fader:IsRunning() and fader.alpha == 1, "a new fader should be idle at full alpha")
fader:Start(0)
assert(fader:IsRunning() and fader.alpha == 0 and applied[#applied] == 0, "Start should apply the starting alpha and run")

Tick(0.02)
assert(ticks == 0, "passes shorter than the interval should wait")
Tick(0.03)
assert(ticks == 1 and fader.alpha == 0 and #applied == 1, "a faded frame with nothing to show should not apply again")

show = true
Tick(0.1)
assert(fader.alpha == 0.5 and applied[#applied] == 0.5, "a 0.1s pass should fade in halfway over 0.2s")
Tick(0.1)
Tick(0.1)
assert(fader.alpha == 1 and applied[#applied] == 1, "the fade in should stop at 1")

show = false
Tick(0.1)
assert(fader.alpha == 0.75, "a 0.1s pass should fade out a quarter over 0.4s")
for _ = 1, 10 do Tick(0.1) end
assert(fader.alpha == 0, "the fade out should stop at 0")

-- onTick can force an apply when nothing moved.
local force = false
local forced = HoverFade.Create({
    shouldShow = function() return false end,
    apply = function() applied[#applied + 1] = "forced" end,
    onTick = function() return force end,
})
local forcedUpdate = H.scripts.OnUpdate
forced:Start(0)
local before = #applied
forcedUpdate.handler(forcedUpdate.frame, 0.1)
assert(#applied == before, "an idle fader should not apply")
force = true
forcedUpdate.handler(forcedUpdate.frame, 0.1)
assert(applied[#applied] == "forced", "onTick returning true should apply")

-- A disabled feature stops the loop; Stop with an alpha restores the frames.
enabled = false
Tick(0.1)
assert(not fader:IsRunning(), "a disabled fader should stop itself")
fader:Stop(1)
assert(fader.alpha == 1 and applied[#applied] == 1, "Stop with an alpha should apply it")
fader:Apply()
assert(#applied >= 2 and applied[#applied] == 1, "Apply should write the current alpha")

print("hover fade fixtures: passed")
