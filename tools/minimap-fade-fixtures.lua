#!/usr/bin/env lua
-- Verifies Fade Minimap fades the minimap cluster and the map's own alpha
-- together until it is hovered, hides the map itself once faded so its blips
-- go too, and never shows a minimap the player hid themselves.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixture-harness.lua")(repo, "minimap-fade")

H.installCreateFrame()
H.installCursor()
H.installUIParent()
H.carpenter({
    IsEnabled = function(_, key) return key == "minimapFadeEnabled" end,
    RegisterFeature = H.captureFeature("minimapFadeEnabled"),
})

local function NewFrame(parent, left, bottom, width, height, scale)
    return H.Frame({ parent = parent, left = left, bottom = bottom, width = width, height = height, scale = scale })
end

-- The cluster sits in the top-right corner. Edit Mode scaled its map
-- container to 150%, so the container's 1180..1280 is 1770..1920 on screen.
MinimapCluster = NewFrame(UIParent, 1700, 820, 220, 260)
MinimapCluster.MinimapContainer = NewFrame(MinimapCluster, 1180, 540, 100, 100, 1.5)
Minimap = NewFrame(MinimapCluster.MinimapContainer, 1185, 545, 90, 90, 1.5)
MinimapCluster.Tracking = { Button = { IsMenuOpen = function(self) return self.open end } }

-- Explorer Mode reports whether it has brought the HUD back.
local explorerRevealed = false
local ns = { Private = { ExplorerMode = { IsHUDRevealed = function() return explorerRevealed end } } }

H.load("Core/HoverFade.lua", ns)
H.load("Modules/MinimapFade.lua", ns)
local feature = assert(H.features.minimapFadeEnabled, "the fade should register as a feature")
feature:Enable()

local function Step()
    H.settle(1, 0.1)
end

local function Settle()
    H.settle(30, 0.1)
    return MinimapCluster.alpha
end

assert(MinimapCluster.alpha == 0 and not Minimap.shown, "the minimap should start faded and hidden")
-- The engine draws the map from the Minimap frame's own alpha, so the map
-- gets the fade directly and ignores the cluster's alpha to fade only once.
assert(Minimap.alpha == 0, "the map itself should start faded")
assert(Minimap.ignoreParentAlpha == true, "the map should ignore the cluster's alpha while fading")

H.setCursor(900, 500)
assert(Settle() == 0 and not Minimap.shown, "the minimap should stay hidden away from it")

H.setCursor(1750, 1000)
Step()
assert(Minimap.shown and MinimapCluster.alpha > 0 and MinimapCluster.alpha < 1, "the fade-in should run over several frames")
assert(Minimap.alpha == MinimapCluster.alpha, "the map should fade in step with the cluster")
assert(Settle() == 1 and Minimap.shown and Minimap.alpha == 1, "hovering the cluster should bring the minimap back")

H.setCursor(900, 500)
Step()
assert(Minimap.shown and MinimapCluster.alpha > 0 and MinimapCluster.alpha < 1, "the fade-out should run over several frames")
assert(Minimap.alpha == MinimapCluster.alpha, "the map should fade out in step with the cluster")
assert(Settle() == 0 and not Minimap.shown and Minimap.alpha == 0, "leaving should fade the minimap and hide its blips")

H.setCursor(1850, 795)
assert(Settle() == 1, "the scaled map should be hovered where it is on screen, below the cluster")

H.setCursor(900, 500)
MinimapCluster.Tracking.Button.open = true
assert(Settle() == 1, "an open tracking menu should keep the minimap up")
MinimapCluster.Tracking.Button.open = nil

EditModeManagerFrame = { IsEditModeActive = function() return true end }
assert(Settle() == 1, "Edit Mode should always show the minimap")
EditModeManagerFrame = nil

-- Explorer Mode brings the HUD back in combat and below full health.
assert(Settle() == 0, "the minimap should fade again away from it")
explorerRevealed = true
assert(Settle() == 1 and Minimap.shown, "the minimap should come back with Explorer Mode's HUD")
explorerRevealed = false
assert(Settle() == 0 and not Minimap.shown, "the minimap should fade once Explorer Mode fades the HUD")

-- The player hides the minimap while it's up; the fade must not show it again.
H.setCursor(1750, 1000)
Settle()
Minimap:Hide()
H.setCursor(900, 500)
Settle()
H.setCursor(1750, 1000)
assert(Settle() == 1 and not Minimap.shown, "a minimap the player hid should stay hidden")
Minimap:Show()

-- Another addon moved the minimap out of the cluster: it still fades.
Minimap.parent = UIParent
H.setCursor(900, 500)
Settle()
assert(Minimap.alpha == 0, "a minimap outside the cluster should still fade")

feature:Disable()
assert(MinimapCluster.alpha == 1 and Minimap.alpha == 1 and Minimap.shown, "turning the fade off should restore the minimap")
assert(Minimap.ignoreParentAlpha == false, "turning the fade off should give the map its parent's alpha back")

print("minimap fade fixtures: passed")
