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

print("hide-chat-buttons fixtures: passed")
