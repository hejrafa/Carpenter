#!/usr/bin/env lua
-- Offline fixture checks for Hide Error Messages: errors from the game's
-- error event, and errors Blizzard code writes straight onto the error frame
-- (the Auction House's "Internal auction error.").

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "hide-error-messages")
local fail, assertEqual, assertTrue = H.fail, H.assertEqual, H.assertTrue

H.installCreateFrame()
H.installHooks()
H.installTimers("ignore")
LE_GAME_ERR_SYSTEM = 999
local now = 100
GetTime = function() return now end

-- Text the game hides from addons: searching it raises an error, as in the
-- game.
local secretMeta = { __index = function() error("attempt to use a secret value") end }
local function Secret(value) return setmetatable({ value = value }, secretMeta) end
issecretvalue = function(value) return getmetatable(value) == secretMeta end
-- A hidden value still reports its own type.
local rawType = type
type = function(value)
    if issecretvalue(value) then return rawType(rawget(value, "value")) end
    return rawType(value)
end

-- The game's error frame: a message frame that finds a line by its ID, and
-- the mixin's AddExternalErrorMessage, which adds one line under the system
-- error ID without the error event. The frame queues a new message and only
-- draws its line on its next update (Draw), unless drawsAtOnce is set.
local passed = {}
UIErrorsFrame = H.NamedFrame("UIErrorsFrame")
UIErrorsFrame.byID = {}
UIErrorsFrame.queue = {}
function UIErrorsFrame:Draw()
    for _, message in ipairs(self.queue) do
        local line = { text = message.text }
        function line:GetText() return self.text end
        function line:SetText(value) self.text = value end
        if message.id then self.byID[message.id] = line end
    end
    self.queue = {}
end
function UIErrorsFrame:AddMessage(text, _, _, _, _, id)
    self.queue[#self.queue + 1] = { text = text, id = id }
    if self.drawsAtOnce then self:Draw() end
end
function UIErrorsFrame:GetFontStringByID(id) return self.byID[id] end
-- While the game suppresses messages, nothing is added.
function UIErrorsFrame:AddExternalErrorMessage(message)
    if self.suppressed then return end
    self:AddMessage(message, 1, 0.1, 0.1, 1, LE_GAME_ERR_SYSTEM)
end
UIErrorsFrame:SetScript("OnEvent", function(_, event, _, message)
    if event == "UI_ERROR_MESSAGE" then passed[#passed + 1] = message end
end)

CarpenterDB = { hideErrorMessagesEnabled = true }
H.carpenter({
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = function(_, key, feature) H.features[key] = feature end,
})
H.load("Modules/HideErrorMessages.lua")
local feature = H.features.hideErrorMessagesEnabled
if not feature then fail("Hide Error Messages did not register its feature") end
feature.Enable()

-- The module's only frame looks for queued lines once a frame.
local watcher = H.createdFrames[1]
if not (watcher and watcher.scripts.OnUpdate) then fail("Hide Error Messages has no frame watching for lines") end
local function NextFrame(seconds)
    now = now + (seconds or 0.02)
    UIErrorsFrame:Draw()
    if watcher.shown then watcher.scripts.OnUpdate(watcher, seconds or 0.02) end
end

local function ShownExternal()
    local line = UIErrorsFrame:GetFontStringByID(LE_GAME_ERR_SYSTEM)
    return line and line:GetText()
end

-- Errors from the game's error event.
local onEvent = UIErrorsFrame:GetScript("OnEvent")
onEvent(UIErrorsFrame, "UI_ERROR_MESSAGE", 1, "Not enough energy")
assertEqual(#passed, 0, "a listed error from the error event should be hidden")
onEvent(UIErrorsFrame, "UI_ERROR_MESSAGE", 1, "Invalid target")
assertEqual(passed[1], "Invalid target", "an error that is never hidden should pass")
onEvent(UIErrorsFrame, "UI_ERROR_MESSAGE", 1, Secret("Not enough energy"))
assertEqual(#passed, 2, "an error the game hides from addons should pass untouched")

-- Errors written straight onto the frame. Its line is drawn a frame later.
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
assertEqual(ShownExternal(), nil, "the frame should not have drawn the line yet")
assertTrue(watcher.shown, "a listed error should be watched for until its line is drawn")
NextFrame()
assertEqual(ShownExternal(), "", "the Auction House's internal error should be blanked once drawn")
assertTrue(not watcher.shown, "the watch should end once the line is blanked")

UIErrorsFrame:AddExternalErrorMessage("You don't have enough money.")
assertTrue(not watcher.shown, "an unlisted error should not be watched for")
NextFrame()
assertEqual(ShownExternal(), "You don't have enough money.", "an unlisted error on the frame should stay")

UIErrorsFrame:AddExternalErrorMessage("Internal mail database error.")
NextFrame()
assertEqual(ShownExternal(), "", "every listed error on the frame should be blanked")

-- A client that draws the line at once gets it blanked right away.
UIErrorsFrame.drawsAtOnce = true
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
assertEqual(ShownExternal(), "", "a line drawn at once should be blanked at once")
assertTrue(not watcher.shown, "a line blanked at once needs no watch")
UIErrorsFrame.drawsAtOnce = false

-- A suppressed listed error adds no line: an older, different one keeps its
-- text, and the watch gives up after a second.
UIErrorsFrame:AddExternalErrorMessage("You don't have enough money.")
NextFrame()
UIErrorsFrame.suppressed = true
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
NextFrame()
assertEqual(ShownExternal(), "You don't have enough money.", "an older, different error should never be blanked")
assertTrue(watcher.shown, "the watch should wait for a line that may still come")
NextFrame(1.1)
assertTrue(not watcher.shown, "the watch should give up after a second")
assertEqual(ShownExternal(), "You don't have enough money.", "giving up should leave the older error alone")
UIErrorsFrame.suppressed = false

local hiddenOlder = Secret("Not here.")
UIErrorsFrame:AddExternalErrorMessage(hiddenOlder)
NextFrame()
UIErrorsFrame.suppressed = true
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
NextFrame()
assertEqual(ShownExternal(), hiddenOlder, "an older error the game hides should be left alone")
NextFrame(1.1)
UIErrorsFrame.suppressed = false

local hidden = Secret("Internal auction error.")
UIErrorsFrame:AddExternalErrorMessage(hidden)
NextFrame()
assertEqual(ShownExternal(), hidden, "a hidden error on the frame should stay untouched")

-- The option is read on every message.
CarpenterDB.hideErrorMessagesEnabled = false
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
NextFrame()
assertEqual(ShownExternal(), "Internal auction error.", "with the option off the error should stay")
onEvent(UIErrorsFrame, "UI_ERROR_MESSAGE", 1, "Not enough energy")
assertEqual(passed[#passed], "Not enough energy", "with the option off event errors should pass")

print("hide-error-messages fixtures: passed")
