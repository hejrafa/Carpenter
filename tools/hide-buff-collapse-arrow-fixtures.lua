#!/usr/bin/env lua
-- Offline fixture checks for Hide Buff Collapse Arrow.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixture-harness.lua")(repo, "hide-buff-collapse-arrow")
local fail, assertEqual = H.fail, H.assertEqual

H.installCreateFrame()
H.installHooks()
InCombatLockdown = function() return false end

CarpenterDB = { hideBuffCollapseArrowEnabled = true }
H.carpenter({
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = H.captureFeature("hideBuffCollapseArrowEnabled"),
})

-- Blizzard's arrow is a CheckButton that is checked while buffs are expanded.
local buffFrame = H.NamedFrame("BuffFrame")
local arrow = H.Frame({ parent = buffFrame, objectType = "CheckButton", checked = true })
function arrow:SetChecked(checked) self.checked = checked and true or false end
function arrow:GetChecked() return self.checked end
buffFrame.CollapseAndExpandButton = arrow

-- What BuffFrameMixin:RefreshConsolidationFrameVisibility does on each update.
local function BlizzardRefresh(isExpanded)
    arrow:SetShown(true)
    arrow:SetChecked(isExpanded)
end

H.load("Modules/HideBuffCollapseArrow.lua")
local feature = H.features.hideBuffCollapseArrowEnabled
if not feature then fail("Hide Buff Collapse Arrow did not register its feature") end

feature:Enable()
assertEqual(arrow.shown, false, "the arrow should hide when the option turns on")

BlizzardRefresh(true)
assertEqual(arrow.shown, false, "the arrow should stay hidden after Blizzard reshows it")

-- Collapsed buffs keep the arrow, so the player can expand them again.
BlizzardRefresh(false)
assertEqual(arrow.shown, true, "the arrow should stay while the buffs are collapsed")

-- Clicking the arrow checks it, then Blizzard's update reshows it.
arrow.checked = true
BlizzardRefresh(true)
assertEqual(arrow.shown, false, "the arrow should hide once the buffs are expanded")

-- Turning the option off brings the arrow back when Blizzard wants it shown.
CarpenterDB.hideBuffCollapseArrowEnabled = false
feature:Disable()
assertEqual(arrow.shown, true, "the arrow should come back when the option turns off")

-- With no hideable buffs Blizzard hides the arrow; turning off must not show it.
CarpenterDB.hideBuffCollapseArrowEnabled = true
feature:Enable()
arrow:SetShown(false)
CarpenterDB.hideBuffCollapseArrowEnabled = false
feature:Disable()
assertEqual(arrow.shown, false, "the arrow should stay hidden when Blizzard hid it")

-- Clients that load the buff frame later get hooked on ADDON_LOADED.
BuffFrame = nil
H.createdFrames = {}
H.features = {}
CarpenterDB.hideBuffCollapseArrowEnabled = true
H.load("Modules/HideBuffCollapseArrow.lua")
local lateFeature = H.features.hideBuffCollapseArrowEnabled
local eventFrame = H.createdFrames[1]
lateFeature:Enable()
local lateFrame = H.NamedFrame("BuffFrame")
local lateArrow = H.Frame({ parent = lateFrame, checked = true })
function lateArrow:GetChecked() return self.checked end
function lateArrow:SetChecked(checked) self.checked = checked end
lateFrame.CollapseAndExpandButton = lateArrow
local onEvent = eventFrame.scripts.OnEvent
if not onEvent then fail("the module did not set an OnEvent script") end
onEvent(eventFrame, "ADDON_LOADED", "Blizzard_BuffFrame")
assertEqual(lateArrow.shown, false, "the arrow should hide once Blizzard_BuffFrame loads")

print("hide-buff-collapse-arrow fixtures passed")
