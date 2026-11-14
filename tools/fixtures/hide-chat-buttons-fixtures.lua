#!/usr/bin/env lua
-- Offline fixture checks for Hide Chat Buttons hover API compatibility.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "hide-chat-buttons")
local fail, assertEqual = H.fail, H.assertEqual

H.installCreateFrame()
H.installHooks()
H.installTimers("ignore")
MouseIsOver = nil

CarpenterDB = { hideChatButtonsEnabled = true }
H.carpenter({
    Client = { isClassic = false },
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = H.captureFeature("hideChatButtonsEnabled"),
    DeferMany = function() end,
})

H.NamedFrame("UIParent")
H.NamedFrame("ChatFrame1")
H.NamedFrame("ChatFrame1Tab")
H.NamedFrame("ChatFrameMenuButton")
-- Retail's social button beside the chat fades with the rest.
H.NamedFrame("QuickJoinToastButton")
-- The Damage Meter Tab's buttons in the column copy the fade themselves.
H.NamedFrame("CarpenterDamageMeterTabMenuButton")
H.NamedFrame("CarpenterDamageMeterTabSegmentButton")
NUM_CHAT_WINDOWS = 1

local function runUpdate()
    local update = H.scripts.OnUpdate
    if not update then fail("Hide Chat Buttons did not start a hover fader") end
    local ok, err = pcall(update.handler, update.frame, 0.05)
    if not ok then fail("hover update errored: " .. tostring(err)) end
end

H.load("Core/HoverFade.lua")
H.load("Modules/HideChatButtons.lua")

local registeredFeature = H.features.hideChatButtonsEnabled
if not registeredFeature then fail("Hide Chat Buttons did not register its feature") end
-- The hitbox above the chat is the module's first frame; the shared fader's
-- frame carries the OnUpdate.
local hoverFrame = H.createdFrames[1]
if not hoverFrame then fail("Hide Chat Buttons did not create its hover frame") end

registeredFeature:Enable()
assertEqual(QuickJoinToastButton.alpha, 0, "the social button should start hidden with the chat buttons")
assertEqual(CarpenterDamageMeterTabSegmentButton.alpha, 1, "the Damage Meter Tab's buttons should not be faded here")

-- Retail no longer guarantees the legacy MouseIsOver global. The frame method
-- must drive hover fading without it.
hoverFrame.mouseOver = true
runUpdate()
assertEqual(ChatFrame1Tab.alpha, 0.25, "frame-method hover did not start the fade")
assertEqual(QuickJoinToastButton.alpha, 0.25, "the social button should fade in with the chat buttons")

-- Older clients can still fall back to the legacy global if a region does not
-- expose IsMouseOver as a method.
hoverFrame.IsMouseOver = nil
hoverFrame.legacyMouseOver = true
MouseIsOver = function(frame) return frame.legacyMouseOver == true end
runUpdate()
assertEqual(ChatFrame1Tab.alpha, 0.5, "legacy hover fallback did not continue the fade")

-- The mouse on one of the Damage Meter Tab's buttons keeps the chat
-- buttons up, as on any chat button, while the button shows.
hoverFrame.legacyMouseOver = false
for _ = 1, 20 do runUpdate() end
assertEqual(ChatFrame1Tab.alpha, 0, "leaving the chat should fade the buttons out")
CarpenterDamageMeterTabSegmentButton.mouseOver = true
runUpdate()
assertEqual(ChatFrame1Tab.alpha, 0.25, "the mouse on the tab's segment button should bring the chat buttons up")
assertEqual(QuickJoinToastButton.alpha, 0.25, "the mouse on the tab's segment button should bring the social button up")
assertEqual(CarpenterDamageMeterTabSegmentButton.alpha, 1, "the tab's buttons should keep their own fade")
CarpenterDamageMeterTabSegmentButton.mouseOver = false
CarpenterDamageMeterTabMenuButton.mouseOver = true
runUpdate()
assertEqual(ChatFrame1Tab.alpha, 0.5, "the mouse on the tab's arrow should keep the chat buttons coming up")
-- Hidden with another tab, a button no longer counts.
CarpenterDamageMeterTabMenuButton.shown = false
for _ = 1, 20 do runUpdate() end
assertEqual(ChatFrame1Tab.alpha, 0, "a hidden tab button should not keep the chat buttons up")
CarpenterDamageMeterTabMenuButton.shown, CarpenterDamageMeterTabMenuButton.mouseOver = true, false

print("hide-chat-buttons fixtures: passed")
