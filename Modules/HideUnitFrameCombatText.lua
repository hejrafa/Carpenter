--[[ Carpenter - Hide Unit Frame Combat Text ]]
-- When enabled, hides only the numbers on the player and pet portrait (damage, healing, dodge,
-- miss, parry, etc.). Floating combat text on the world/target is unchanged.
-- Uses the same approach as Leatrix Plus: hook Blizzard's HitIndicator frames.

local function shouldHide()
    if Carpenter and Carpenter.Client and Carpenter.Client.isRetail then
        return Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
    end
    return Carpenter and Carpenter:IsEnabled("hideUnitFrameCombatTextEnabled")
end

local hiddenParent
local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", "CarpenterHitIndicatorHiddenParent", UIParent)
        hiddenParent:Hide()
    end
    return hiddenParent
end

local function GetPlayerHitIndicator()
    return PlayerHitIndicator
        or (PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
            and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator)
end

local function HideIndicator(frame)
    if not frame then return end

    if frame._CarpenterHiding then return end
    frame._CarpenterHiding = true

    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
    if frame.Hide then
        frame:Hide()
    end

    local hitText = frame.HitText
    if hitText then
        if hitText.SetAlpha then
            hitText:SetAlpha(0)
        end
        if hitText.Hide then
            hitText:Hide()
        end
    end

    frame._CarpenterHiding = nil
end

local function HideHitText(hitText)
    if not hitText or hitText._CarpenterHiding then return end

    hitText._CarpenterHiding = true
    if hitText.SetAlpha then
        hitText:SetAlpha(0)
    end
    if hitText.Hide then
        hitText:Hide()
    end
    hitText._CarpenterHiding = nil
end

local function HidePetIndicator()
    if not PetHitIndicator then return end
    if PetHitIndicator.SetParent and not PetHitIndicator._CarpenterOriginalParent then
        PetHitIndicator._CarpenterOriginalParent = PetHitIndicator:GetParent()
        PetHitIndicator:SetParent(GetHiddenParent())
    end
    HideIndicator(PetHitIndicator)
end

-- Hook Blizzard's portrait hit indicators (player/pet frame only; no global FCT change)
local function hookHitIndicators()
    local playerHitIndicator = GetPlayerHitIndicator()
    if playerHitIndicator and not playerHitIndicator._CarpenterCombatTextHooked then
        hooksecurefunc(playerHitIndicator, "Show", function(self)
            if shouldHide() then
                HideIndicator(self)
            end
        end)
        hooksecurefunc(playerHitIndicator, "SetAlpha", function(self)
            if shouldHide() then
                HideIndicator(self)
            end
        end)
        if playerHitIndicator.HitText then
            hooksecurefunc(playerHitIndicator.HitText, "Show", function(self)
                if shouldHide() then
                    HideHitText(self)
                end
            end)
            hooksecurefunc(playerHitIndicator.HitText, "SetAlpha", function(self)
                if shouldHide() then
                    HideHitText(self)
                end
            end)
        end
        playerHitIndicator._CarpenterCombatTextHooked = true
    end
    if PetHitIndicator and not PetHitIndicator._CarpenterCombatTextHooked then
        hooksecurefunc(PetHitIndicator, "Show", function()
            if shouldHide() then
                HidePetIndicator()
            end
        end)
        hooksecurefunc(PetHitIndicator, "SetAlpha", function()
            if shouldHide() then
                HidePetIndicator()
            end
        end)
        PetHitIndicator._CarpenterCombatTextHooked = true
    end
end

-- Hide portrait numbers immediately if already shown (e.g. when toggling option on)
local function hideNow()
    if not shouldHide() then return end
    HideIndicator(GetPlayerHitIndicator())
    HidePetIndicator()
end

local function Apply()
    if not shouldHide() then return end
    hookHitIndicators()
    hideNow()
end

local function Restore()
    local playerHitIndicator = GetPlayerHitIndicator()
    if playerHitIndicator then
        if playerHitIndicator.SetAlpha then
            playerHitIndicator:SetAlpha(1)
        end
        if playerHitIndicator.HitText and playerHitIndicator.HitText.SetAlpha then
            playerHitIndicator.HitText:SetAlpha(1)
        end
    end
    if PetHitIndicator and PetHitIndicator._CarpenterOriginalParent then
        PetHitIndicator:SetParent(PetHitIndicator._CarpenterOriginalParent)
        PetHitIndicator._CarpenterOriginalParent = nil
        if PetHitIndicator.SetAlpha then
            PetHitIndicator:SetAlpha(1)
        end
    end
end

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
            C_Timer.After(2, Apply)
        end
    end
end)

-- Expose for config live toggle (no reload)
Carpenter_ApplyUnitFrameCombatText = Apply
Carpenter_RestoreUnitFrameCombatText = Restore
