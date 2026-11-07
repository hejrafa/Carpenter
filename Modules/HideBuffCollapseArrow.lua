--[[ Carpenter - Hide Buff Collapse Arrow ]]
-- Hides the small arrow beside the buff frame that collapses and expands
-- long-lasting buffs. Blizzard shows it again on every aura update, so
-- post-hooks hide it right after. Only the arrow's own visibility changes:
-- running Blizzard's buff code from here would taint the buff buttons. While
-- the buffs are collapsed the arrow stays, so none get stuck out of view; it
-- goes away once they are expanded.

local FEATURE_KEY = "hideBuffCollapseArrowEnabled"

local arrow
local blizzardShown = false
local hiddenByCarpenter = false
local settingShown = false

local eventFrame = CreateFrame("Frame")

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

-- The arrow is checked while the buffs are expanded.
local function BuffsExpanded()
    if type(arrow.GetChecked) ~= "function" then return true end
    return arrow:GetChecked() and true or false
end

local function CanChangeArrow()
    if not (InCombatLockdown and InCombatLockdown()) then return true end
    return not (arrow.IsProtected and arrow:IsProtected())
end

local function SetArrowShown(shown)
    settingShown = true
    if shown then
        arrow:Show()
    else
        arrow:Hide()
    end
    settingShown = false
end

local function Apply()
    if not arrow then return end
    if not CanChangeArrow() then
        Carpenter:AfterCombat(FEATURE_KEY, Apply)
        return
    end

    if IsEnabled() and BuffsExpanded() then
        if arrow:IsShown() then
            SetArrowShown(false)
            hiddenByCarpenter = true
        end
    elseif hiddenByCarpenter then
        hiddenByCarpenter = false
        if blizzardShown then SetArrowShown(true) end
    end
end

-- Records what Blizzard (or anyone else) asked for, so turning the option off
-- shows the arrow only when Blizzard wants it shown.
local function OnShownRequested(shown)
    if settingShown then return end
    blizzardShown = shown and true or false
    if not blizzardShown then hiddenByCarpenter = false end
    Apply()
end

local function InstallHooks()
    if arrow then return true end
    local buffFrame = _G.BuffFrame
    local button = buffFrame and buffFrame.CollapseAndExpandButton
    if not button or type(button.Hide) ~= "function" then return false end

    arrow = button
    blizzardShown = arrow:IsShown() and true or false

    Carpenter:SafeHook(arrow, "Show", function() OnShownRequested(true) end)
    Carpenter:SafeHook(arrow, "Hide", function() OnShownRequested(false) end)
    Carpenter:SafeHook(arrow, "SetShown", function(_, shown) OnShownRequested(shown) end)
    -- Blizzard sets the checked state after showing the arrow, and clicking
    -- it to expand the buffs reshows it through SetShown.
    Carpenter:SafeHook(arrow, "SetChecked", Apply)
    return true
end

eventFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName == "Blizzard_BuffFrame" and IsEnabled() and InstallHooks() then
        self:UnregisterEvent("ADDON_LOADED")
        Apply()
    end
end)

local feature = {}

function feature:Enable()
    if InstallHooks() then
        Apply()
    else
        Carpenter:SafeRegisterEvent(eventFrame, "ADDON_LOADED")
    end
end

function feature:Disable()
    eventFrame:UnregisterEvent("ADDON_LOADED")
    Apply()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
