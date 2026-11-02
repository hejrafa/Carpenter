#!/usr/bin/env lua
-- Verifies Fade Minimap fades the minimap cluster and the map's own alpha
-- together until it is hovered, hides the map itself once faded so its blips
-- go too, and never shows a minimap the player hid themselves.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local scripts = {}
local cursorX, cursorY = 0, 0
local feature

local function NewFrame(parent, left, bottom, width, height, scale)
    local frame = { alpha = 1, shown = true, parent = parent }
    function frame:GetParent() return self.parent end
    function frame:GetLeft() return left end
    function frame:GetRight() return left + width end
    function frame:GetBottom() return bottom end
    function frame:GetTop() return bottom + height end
    function frame:GetEffectiveScale() return scale or 1 end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetIgnoreParentAlpha(ignore) self.ignoreParentAlpha = ignore end
    function frame:IsIgnoringParentAlpha() return self.ignoreParentAlpha == true end
    return frame
end

function CreateFrame()
    local frame = { shown = true }
    function frame:SetScript(script, handler) scripts[script] = { frame = self, handler = handler } end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    return frame
end

function GetCursorPosition() return cursorX, cursorY end
UIParent = NewFrame(nil, 0, 0, 1920, 1080)
Carpenter = {
    IsEnabled = function(_, key) return key == "minimapFadeEnabled" end,
    RegisterFeature = function(_, key, registered)
        assert(key == "minimapFadeEnabled", "unexpected feature key " .. tostring(key))
        feature = registered
    end,
}

-- The cluster sits in the top-right corner. Edit Mode scaled its map
-- container to 150%, so the container's 1180..1280 is 1770..1920 on screen.
MinimapCluster = NewFrame(UIParent, 1700, 820, 220, 260)
MinimapCluster.MinimapContainer = NewFrame(MinimapCluster, 1180, 540, 100, 100, 1.5)
Minimap = NewFrame(MinimapCluster.MinimapContainer, 1185, 545, 90, 90, 1.5)
MinimapCluster.Tracking = { Button = { IsMenuOpen = function(self) return self.open end } }

assert(loadfile(repo .. "/Core/HoverFade.lua"))("Carpenter", {})
Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/MinimapFade.lua"))("Carpenter", {})
assert(feature, "the fade should register as a feature")
feature:Enable()

local function Settle()
    for _ = 1, 30 do
        scripts.OnUpdate.handler(scripts.OnUpdate.frame, 0.1)
    end
    return MinimapCluster.alpha
end

assert(MinimapCluster.alpha == 0 and not Minimap.shown, "the minimap should start faded and hidden")
-- The engine draws the map from the Minimap frame's own alpha, so the map
-- gets the fade directly and ignores the cluster's alpha to fade only once.
assert(Minimap.alpha == 0, "the map itself should start faded")
assert(Minimap.ignoreParentAlpha == true, "the map should ignore the cluster's alpha while fading")

cursorX, cursorY = 900, 500
assert(Settle() == 0 and not Minimap.shown, "the minimap should stay hidden away from it")

cursorX, cursorY = 1750, 1000
scripts.OnUpdate.handler(scripts.OnUpdate.frame, 0.1)
assert(Minimap.shown and MinimapCluster.alpha > 0 and MinimapCluster.alpha < 1, "the fade-in should run over several frames")
assert(Minimap.alpha == MinimapCluster.alpha, "the map should fade in step with the cluster")
assert(Settle() == 1 and Minimap.shown and Minimap.alpha == 1, "hovering the cluster should bring the minimap back")

cursorX, cursorY = 900, 500
scripts.OnUpdate.handler(scripts.OnUpdate.frame, 0.1)
assert(Minimap.shown and MinimapCluster.alpha > 0 and MinimapCluster.alpha < 1, "the fade-out should run over several frames")
assert(Minimap.alpha == MinimapCluster.alpha, "the map should fade out in step with the cluster")
assert(Settle() == 0 and not Minimap.shown and Minimap.alpha == 0, "leaving should fade the minimap and hide its blips")

cursorX, cursorY = 1850, 795
assert(Settle() == 1, "the scaled map should be hovered where it is on screen, below the cluster")

cursorX, cursorY = 900, 500
MinimapCluster.Tracking.Button.open = true
assert(Settle() == 1, "an open tracking menu should keep the minimap up")
MinimapCluster.Tracking.Button.open = nil

EditModeManagerFrame = { IsEditModeActive = function() return true end }
assert(Settle() == 1, "Edit Mode should always show the minimap")
EditModeManagerFrame = nil

-- The player hides the minimap while it's up; the fade must not show it again.
cursorX, cursorY = 1750, 1000
Settle()
Minimap:Hide()
cursorX, cursorY = 900, 500
Settle()
cursorX, cursorY = 1750, 1000
assert(Settle() == 1 and not Minimap.shown, "a minimap the player hid should stay hidden")
Minimap:Show()

-- Another addon moved the minimap out of the cluster: it still fades.
Minimap.parent = UIParent
cursorX, cursorY = 900, 500
Settle()
assert(Minimap.alpha == 0, "a minimap outside the cluster should still fade")

feature:Disable()
assert(MinimapCluster.alpha == 1 and Minimap.alpha == 1 and Minimap.shown, "turning the fade off should restore the minimap")
assert(Minimap.ignoreParentAlpha == false, "turning the fade off should give the map its parent's alpha back")

print("minimap fade fixtures: passed")
