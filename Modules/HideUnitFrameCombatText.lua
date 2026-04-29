--[[ Carpenter - Hide Unit Frame Combat Text ]]
-- When enabled, hides only the numbers on the player and pet portrait (damage, healing, dodge,
-- miss, parry, etc.). Floating combat text on the world/target is unchanged.
-- Uses the same approach as Leatrix Plus: hook Blizzard's HitIndicator frames.

local function shouldHide()
    return CarpenterDB and CarpenterDB.hideUnitFrameCombatTextEnabled
end

-- Hook Blizzard's portrait hit indicators (player/pet frame only; no global FCT change)
local function hookHitIndicators()
    if PlayerHitIndicator and not PlayerHitIndicator._classicPlusHooked then
        hooksecurefunc(PlayerHitIndicator, "Show", function()
            if shouldHide() then
                PlayerHitIndicator:Hide()
            end
        end)
        PlayerHitIndicator._classicPlusHooked = true
    end
    if PetHitIndicator and not PetHitIndicator._classicPlusHooked then
        hooksecurefunc(PetHitIndicator, "Show", function()
            if shouldHide() then
                PetHitIndicator:Hide()
            end
        end)
        PetHitIndicator._classicPlusHooked = true
    end
end

-- Hide portrait numbers immediately if already shown (e.g. when toggling option on)
local function hideNow()
    if not shouldHide() then return end
    if PlayerHitIndicator and PlayerHitIndicator:IsShown() then
        PlayerHitIndicator:Hide()
    end
    if PetHitIndicator and PetHitIndicator:IsShown() then
        PetHitIndicator:Hide()
    end
end

local function Apply()
    if not shouldHide() then return end
    hookHitIndicators()
    hideNow()
end

-- No CVars to restore; config still calls this for symmetry
local function Restore() end

-- Run when UI is ready (HitIndicator frames exist after Blizzard_UnitFrames loads)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == "Blizzard_UnitFrames" then
        Apply()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Apply()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, Apply)
        end
    end
end)

-- Expose for config live toggle (no reload)
Carpenter_ApplyUnitFrameCombatText = Apply
Carpenter_RestoreUnitFrameCombatText = Restore
