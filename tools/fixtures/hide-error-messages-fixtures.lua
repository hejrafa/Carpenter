#!/usr/bin/env lua
-- Offline fixture checks for Hide Error Messages: errors from the game's
-- error event, and errors Blizzard code writes straight onto the error frame
-- (the Auction House's "Internal auction error.").

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "hide-error-messages")
local fail, assertEqual = H.fail, H.assertEqual

H.installHooks()
LE_GAME_ERR_SYSTEM = 999

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
-- error ID without the error event.
local passed = {}
UIErrorsFrame = H.NamedFrame("UIErrorsFrame")
UIErrorsFrame.byID = {}
function UIErrorsFrame:AddMessage(text, _, _, _, _, id)
    local line = { text = text }
    function line:GetText() return self.text end
    function line:SetText(value) self.text = value end
    if id then self.byID[id] = line end
    return line
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

-- Errors written straight onto the frame.
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
assertEqual(ShownExternal(), "", "the Auction House's internal error should be blanked")
UIErrorsFrame:AddExternalErrorMessage("You don't have enough money.")
assertEqual(ShownExternal(), "You don't have enough money.", "an unlisted error on the frame should stay")
UIErrorsFrame:AddExternalErrorMessage("Internal mail database error.")
assertEqual(ShownExternal(), "", "every listed error on the frame should be blanked")
-- A suppressed listed error adds no line, so an older one keeps its text.
UIErrorsFrame:AddExternalErrorMessage("You don't have enough money.")
UIErrorsFrame.suppressed = true
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
assertEqual(ShownExternal(), "You don't have enough money.", "an older, different error should never be blanked")
UIErrorsFrame.suppressed = false
local hiddenOlder = Secret("Not here.")
UIErrorsFrame:AddExternalErrorMessage(hiddenOlder)
UIErrorsFrame.suppressed = true
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
assertEqual(ShownExternal(), hiddenOlder, "an older error the game hides should be left alone")
UIErrorsFrame.suppressed = false
local hidden = Secret("Internal auction error.")
UIErrorsFrame:AddExternalErrorMessage(hidden)
assertEqual(ShownExternal(), hidden, "a hidden error on the frame should stay untouched")

-- The option is read on every message.
CarpenterDB.hideErrorMessagesEnabled = false
UIErrorsFrame:AddExternalErrorMessage("Internal auction error.")
assertEqual(ShownExternal(), "Internal auction error.", "with the option off the error should stay")
onEvent(UIErrorsFrame, "UI_ERROR_MESSAGE", 1, "Not enough energy")
assertEqual(passed[#passed], "Not enough energy", "with the option off event errors should pass")

print("hide-error-messages fixtures: passed")
