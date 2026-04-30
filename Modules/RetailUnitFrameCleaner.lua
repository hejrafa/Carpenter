--[[ Carpenter - Retail Unit Frame Cleaner ]]
-- Retail-only unit frame cleanup for PvP badges and class resource widgets.

local function IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function ShouldHidePvPIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHidePowerBar()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideUnitFramePowerBarEnabled")
end

local function ShouldHideBossFrames()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideBossFramesEnabled")
end

local function ShouldHideRestAnimation()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideCombatIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideCombatIconEnabled")
end

local function ShouldHideHealthLossFx()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideGroupIndicator()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideGroupIndicatorEnabled")
end

local function ShouldHideRoleIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hideRoleIconEnabled")
end

local function ShouldHidePvPTimer()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("hidePvPTimerEnabled")
end

local function ShouldHideRealmIndicator()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHidePlayerCornerIcon()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHidePartyFrameTitle()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local function ShouldHideTargetReputationColor()
    return IsRetail() and Carpenter and Carpenter:IsEnabled("cleanUpUnitFramesEnabled")
end

local lastFeatureState = {}

local function ShouldRunCleaner()
    if not IsRetail() then return false end
    if ShouldHidePvPIcon()
        or ShouldHidePowerBar()
        or ShouldHideBossFrames()
        or ShouldHideRestAnimation()
        or ShouldHideCombatIcon()
        or ShouldHideHealthLossFx()
        or ShouldHideGroupIndicator()
        or ShouldHideRoleIcon()
        or ShouldHidePvPTimer()
        or ShouldHideRealmIndicator()
        or ShouldHidePlayerCornerIcon()
        or ShouldHidePartyFrameTitle()
        or ShouldHideTargetReputationColor()
    then
        return true
    end

    for _, wasEnabled in pairs(lastFeatureState) do
        if wasEnabled then return true end
    end

    return false
end

local hiddenParent
local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", "CarpenterRetailHiddenParent", UIParent)
        hiddenParent:Hide()
    end
    return hiddenParent
end

local function HideFrameVisuals(frame)
    if not frame then return end
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.SetAlpha then
                region:SetAlpha(0)
            end
            if region and region.Hide then
                region:Hide()
            end
        end
    end
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            HideFrameVisuals(child)
            if child.Hide then
                child:Hide()
            end
        end
    end
end

local function RestoreFrameVisuals(frame)
    if not frame then return end
    if frame.SetAlpha then
        frame:SetAlpha(1)
    end
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.SetAlpha then
                region:SetAlpha(1)
            end
        end
    end
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            RestoreFrameVisuals(child)
        end
    end
end

local function HideFrame(frame)
    if not frame or frame._CarpenterHiding then return end
    if frame._CarpenterHiddenByCleaner then return end
    local isProtected = frame.IsProtected and frame:IsProtected()
    if isProtected and InCombatLockdown and InCombatLockdown() then return end

    frame._CarpenterHiding = true
    if frame._CarpenterWasShown == nil then
        frame._CarpenterWasShown = frame.IsShown and frame:IsShown()
    end
    frame._CarpenterHiddenByCleaner = true
    HideFrameVisuals(frame)
    if frame.Hide then
        frame:Hide()
    end
    if frame.SetParent and frame.GetParent and not frame._CarpenterOriginalParent then
        frame._CarpenterOriginalParent = frame:GetParent()
        frame:SetParent(GetHiddenParent())
    end
    frame._CarpenterHiding = nil
end

local function RestoreFrame(frame)
    if not frame then return end
    if not frame._CarpenterHiddenByCleaner and not frame._CarpenterOriginalParent then return end
    local isProtected = frame.IsProtected and frame:IsProtected()
    if isProtected and InCombatLockdown and InCombatLockdown() then return end

    if frame._CarpenterOriginalParent then
        frame:SetParent(frame._CarpenterOriginalParent)
        frame._CarpenterOriginalParent = nil
    end
    RestoreFrameVisuals(frame)
    if frame._CarpenterHiddenByCleaner and frame._CarpenterWasShown and frame.Show then
        frame:Show()
    end
    frame._CarpenterHiddenByCleaner = nil
    frame._CarpenterWasShown = nil
end

local function HookHide(frame, predicate)
    if not frame or frame._CarpenterRetailCleanerHooked then return end
    frame._CarpenterRetailCleanerHooked = true

    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            if predicate() then
                HideFrame(self)
            end
        end)
    end
    if frame.Show then
        pcall(hooksecurefunc, frame, "Show", function(self)
            if predicate() then
                HideFrame(self)
            end
        end)
    end
    if frame.SetAlpha then
        pcall(hooksecurefunc, frame, "SetAlpha", function(self)
            if predicate() then
                HideFrame(self)
            end
        end)
    end
    if frame.SetVertexColor then
        pcall(hooksecurefunc, frame, "SetVertexColor", function(self)
            if predicate() then
                HideFrame(self)
            end
        end)
    end
end

local function HideFrameAlpha(frame)
    if not frame or frame._CarpenterAlphaHiding then return end
    if frame._CarpenterAlphaHiddenByCleaner then return end
    local isProtected = frame.IsProtected and frame:IsProtected()
    if isProtected and InCombatLockdown and InCombatLockdown() then return end

    frame._CarpenterAlphaHiding = true
    if frame._CarpenterOriginalAlpha == nil and frame.GetAlpha then
        frame._CarpenterOriginalAlpha = frame:GetAlpha()
    end
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(false)
    end
    frame._CarpenterAlphaHiddenByCleaner = true
    frame._CarpenterAlphaHiding = nil
end

local function RestoreFrameAlpha(frame)
    if not frame then return end
    if not frame._CarpenterAlphaHiddenByCleaner then return end

    if frame.SetAlpha then
        frame:SetAlpha(frame._CarpenterOriginalAlpha or 1)
    end
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(true)
    end
    frame._CarpenterOriginalAlpha = nil
    frame._CarpenterAlphaHiddenByCleaner = nil
end

local function HookAlphaHide(frame, predicate)
    if not frame or frame._CarpenterRetailAlphaHooked then return end
    frame._CarpenterRetailAlphaHooked = true

    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            if predicate() then
                HideFrameAlpha(self)
            end
        end)
    end
    if frame.SetAlpha then
        pcall(hooksecurefunc, frame, "SetAlpha", function(self)
            if predicate() then
                HideFrameAlpha(self)
            end
        end)
    end
end

local function AddFrame(frames, frame)
    if frame then
        table.insert(frames, frame)
    end
end

local function GetPvPIconFrames()
    local frames = {}
    AddFrame(frames, PlayerPVPIcon)
    AddFrame(frames, TargetFrameTextureFramePVPIcon)
    AddFrame(frames, FocusFrameTextureFramePVPIcon)

    if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual then
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PrestigeBadge)
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PrestigePortrait)
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PVPIcon)
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PvpIcon)
    end
    if TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual then
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PrestigeBadge)
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PrestigePortrait)
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PVPIcon)
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PvpIcon)
    end
    if FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual then
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PrestigeBadge)
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PrestigePortrait)
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PVPIcon)
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PvpIcon)
    end

    return frames
end

local function GetContextualFrame()
    return PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual
end

local function GetPowerBarFrames()
    local frames = {}
    AddFrame(frames, ComboFrame)
    AddFrame(frames, ComboPointPlayerFrame)
    AddFrame(frames, RogueComboPointBarFrame)
    AddFrame(frames, ClassNameplateBarFrame)
    AddFrame(frames, RuneFrame)
    AddFrame(frames, PaladinPowerBarFrame)
    AddFrame(frames, WarlockPowerFrame)
    AddFrame(frames, MonkHarmonyBarFrame)
    AddFrame(frames, MageArcaneChargesFrame)
    AddFrame(frames, EssencePlayerFrame)
    AddFrame(frames, TotemFrame)
    AddFrame(frames, DruidComboPointBarFrame)
    AddFrame(frames, PlayerFrameAlternateManaBar)
    return frames
end

local function GetBossFrames()
    local frames = {}
    AddFrame(frames, BossTargetFrameContainer)
    for i = 1, 8 do
        AddFrame(frames, _G["Boss" .. i .. "TargetFrame"])
    end
    return frames
end

local function GetRestAnimationFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.PlayerRestLoop)
        AddFrame(frames, contextual.PlayerRestIcon)
        AddFrame(frames, contextual.PlayerRestGlow)
    end
    return frames
end

local function GetCombatIconFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.AttackIcon)
    end
    return frames
end

local function GetHealthLossFxFrames()
    local frames = {}
    local playerBars = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer
    if playerBars then
        AddFrame(frames, playerBars.PlayerFrameHealthBarAnimatedLoss)
        AddFrame(frames, playerBars.PlayerFrameTempMaxHealthLoss)
        AddFrame(frames, playerBars.TempMaxHealthLossDivider)
    end
    local targetBars = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
        and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
    if targetBars then
        AddFrame(frames, targetBars.TempMaxHealthLoss)
    end
    local focusBars = FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain
        and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
    if focusBars then
        AddFrame(frames, focusBars.TempMaxHealthLoss)
    end
    for i = 1, 5 do
        AddFrame(frames, _G["CompactPartyFrameMember" .. i .. "TempMaxHealthLoss"])
    end
    return frames
end

local function GetGroupIndicatorFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.GroupIndicator)
    end
    AddFrame(frames, PlayerFrameGroupIndicatorLeft)
    AddFrame(frames, PlayerFrameGroupIndicatorRight)
    AddFrame(frames, PlayerFrameGroupIndicatorMiddle)
    AddFrame(frames, PlayerFrameGroupIndicatorText)
    return frames
end

local function GetRoleIconFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.RoleIcon)
    end
    return frames
end

local function GetPvPTimerFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.PvpTimerText)
        AddFrame(frames, contextual.PlayerPVPTimerText)
    end
    AddFrame(frames, PlayerPVPTimerText)
    return frames
end

local function GetPlayerCornerIconFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.PlayerPortraitCornerIcon)
        AddFrame(frames, contextual.PortraitCornerIcon)
        AddFrame(frames, contextual.CornerIcon)
    end
    AddFrame(frames, PlayerPortraitCornerIcon)
    return frames
end

local function GetPartyFrameTitleFrames()
    local frames = {}
    AddFrame(frames, CompactPartyFrameTitle)
    return frames
end

local function GetTargetReputationColorFrames()
    local frames = {}
    if TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain then
        local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
        AddFrame(frames, main.ReputationColor)
        AddFrame(frames, main.ReputationColorTexture)
        AddFrame(frames, main.NameBackground)
        AddFrame(frames, main.NameBackgroundTexture)
        AddFrame(frames, main.Background)
    end
    AddFrame(frames, TargetFrameTextureFrameReputationColor)
    AddFrame(frames, TargetFrameNameBackground)
    return frames
end

local function StripRealmIndicator(text)
    if type(text) ~= "string" then return text, false end
    local stripped = text:gsub(" %(%*%)$", "")
    return stripped, stripped ~= text
end

local function CleanRealmFontString(fontString)
    if not fontString or not fontString.GetText or not fontString.SetText or fontString._CarpenterRealmCleaning then return end

    local ok, stripped, changed = pcall(function()
        local text = fontString:GetText()
        return StripRealmIndicator(text)
    end)
    if not ok or not changed then return end

    fontString._CarpenterRealmCleaning = true
    fontString:SetText(stripped)
    fontString._CarpenterRealmCleaning = nil
end

local function HookRealmFontString(fontString)
    if not fontString or fontString._CarpenterRealmIndicatorHooked then return end
    fontString._CarpenterRealmIndicatorHooked = true
    pcall(hooksecurefunc, fontString, "SetText", function(self)
        if ShouldHideRealmIndicator() then
            CleanRealmFontString(self)
        end
    end)
end

local function AddNameString(strings, fontString)
    if fontString and fontString.GetText and fontString.SetText then
        table.insert(strings, fontString)
    end
end

local function AddUnitFrameNameStrings(strings, frame)
    if not frame then return end
    AddNameString(strings, frame.name)
    AddNameString(strings, frame.Name)
    AddNameString(strings, frame.NameText)
    if frame.PlayerFrameContent and frame.PlayerFrameContent.PlayerFrameContentMain then
        local main = frame.PlayerFrameContent.PlayerFrameContentMain
        AddNameString(strings, main.Name)
        AddNameString(strings, main.NameText)
    end
    if frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain then
        local main = frame.TargetFrameContent.TargetFrameContentMain
        AddNameString(strings, main.Name)
        AddNameString(strings, main.NameText)
    end
end

local function GetRealmIndicatorNameStrings()
    local strings = {}
    AddUnitFrameNameStrings(strings, PlayerFrame)
    AddUnitFrameNameStrings(strings, TargetFrame)
    AddUnitFrameNameStrings(strings, FocusFrame)
    AddUnitFrameNameStrings(strings, TargetFrameToT)
    AddUnitFrameNameStrings(strings, FocusFrameToT)
    AddNameString(strings, PlayerName)
    AddNameString(strings, TargetFrameTextureFrameName)
    AddNameString(strings, FocusFrameTextureFrameName)

    for i = 1, 5 do
        AddNameString(strings, _G["CompactPartyFrameMember" .. i .. "Name"])
    end
    for i = 1, 40 do
        AddNameString(strings, _G["CompactRaidFrame" .. i .. "Name"])
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        for _, plate in ipairs(plates or {}) do
            if plate.UnitFrame then
                AddNameString(strings, plate.UnitFrame.name)
                AddNameString(strings, plate.UnitFrame.Name)
                AddNameString(strings, plate.UnitFrame.NameText)
            end
        end
    end

    return strings
end

local function ApplyRealmIndicator()
    for _, fontString in ipairs(GetRealmIndicatorNameStrings()) do
        HookRealmFontString(fontString)
        if ShouldHideRealmIndicator() then
            CleanRealmFontString(fontString)
        end
    end
end

local function ApplyRealmIndicatorForUnit(unit)
    if not ShouldHideRealmIndicator() then return end

    local strings = {}
    if unit == "player" then
        AddUnitFrameNameStrings(strings, PlayerFrame)
        AddNameString(strings, PlayerName)
    elseif unit == "target" then
        AddUnitFrameNameStrings(strings, TargetFrame)
        AddUnitFrameNameStrings(strings, TargetFrameToT)
        AddNameString(strings, TargetFrameTextureFrameName)
    elseif unit == "focus" then
        AddUnitFrameNameStrings(strings, FocusFrame)
        AddUnitFrameNameStrings(strings, FocusFrameToT)
        AddNameString(strings, FocusFrameTextureFrameName)
    elseif unit and unit:match("^party%d$") then
        local index = unit:match("%d+")
        AddNameString(strings, _G["CompactPartyFrameMember" .. index .. "Name"])
    elseif unit and unit:match("^raid%d+$") then
        local index = unit:match("%d+")
        AddNameString(strings, _G["CompactRaidFrame" .. index .. "Name"])
    end

    if unit and C_NamePlate and C_NamePlate.GetNamePlateForUnit and not unit:match("^boss%d+$") then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.UnitFrame then
            AddNameString(strings, plate.UnitFrame.name)
            AddNameString(strings, plate.UnitFrame.Name)
            AddNameString(strings, plate.UnitFrame.NameText)
        end
    end

    for _, fontString in ipairs(strings) do
        HookRealmFontString(fontString)
        CleanRealmFontString(fontString)
    end
end

local function ApplyFrameFeature(featureKey, getFrames, predicate, alphaOnly)
    local enabled = predicate()
    if not enabled and not lastFeatureState[featureKey] then
        return
    end

    if enabled then
        for _, frame in ipairs(getFrames()) do
            if alphaOnly then
                HideFrameAlpha(frame)
                HookAlphaHide(frame, predicate)
            else
                HideFrame(frame)
                HookHide(frame, predicate)
            end
        end
    else
        for _, frame in ipairs(getFrames()) do
            if alphaOnly then
                RestoreFrameAlpha(frame)
            else
                RestoreFrame(frame)
            end
        end
    end

    lastFeatureState[featureKey] = enabled
end

local function ApplyPvPIcon()
    local enabled = ShouldHidePvPIcon()
    if not enabled and not lastFeatureState.pvpIcon then
        return
    end

    if enabled then
        for _, frame in ipairs(GetPvPIconFrames()) do
            HideFrame(frame)
            HookHide(frame, ShouldHidePvPIcon)
        end
    else
        for _, frame in ipairs(GetPvPIconFrames()) do
            RestoreFrame(frame)
        end
    end

    lastFeatureState.pvpIcon = enabled
end

local function ApplyPowerBar()
    local enabled = ShouldHidePowerBar()
    if not enabled and not lastFeatureState.powerBar then
        return
    end

    if enabled then
        for _, frame in ipairs(GetPowerBarFrames()) do
            HideFrame(frame)
            HookHide(frame, ShouldHidePowerBar)
        end
    else
        for _, frame in ipairs(GetPowerBarFrames()) do
            RestoreFrame(frame)
        end
    end

    lastFeatureState.powerBar = enabled
end

local function ApplyRealmIndicatorFeature()
    local enabled = ShouldHideRealmIndicator()
    if not enabled and not lastFeatureState.realmIndicator then
        return
    end

    if enabled then
        ApplyRealmIndicator()
    end

    lastFeatureState.realmIndicator = enabled
end

local function Apply()
    if not IsRetail() then return end
    if not ShouldRunCleaner() then return end

    ApplyPvPIcon()
    ApplyPowerBar()
    ApplyFrameFeature("bossFrames", GetBossFrames, ShouldHideBossFrames, true)
    ApplyFrameFeature("restAnimation", GetRestAnimationFrames, ShouldHideRestAnimation, false)
    ApplyFrameFeature("combatIcon", GetCombatIconFrames, ShouldHideCombatIcon, false)
    ApplyFrameFeature("healthLossFx", GetHealthLossFxFrames, ShouldHideHealthLossFx, false)
    ApplyFrameFeature("groupIndicator", GetGroupIndicatorFrames, ShouldHideGroupIndicator, false)
    ApplyFrameFeature("roleIcon", GetRoleIconFrames, ShouldHideRoleIcon, false)
    ApplyFrameFeature("pvpTimer", GetPvPTimerFrames, ShouldHidePvPTimer, false)
    ApplyFrameFeature("playerCornerIcon", GetPlayerCornerIconFrames, ShouldHidePlayerCornerIcon, false)
    ApplyFrameFeature("partyFrameTitle", GetPartyFrameTitleFrames, ShouldHidePartyFrameTitle, false)
    ApplyFrameFeature("targetReputationColor", GetTargetReputationColorFrames, ShouldHideTargetReputationColor, false)
    ApplyRealmIndicatorFeature()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
local applyScheduled = false
local function ScheduleApply()
    if applyScheduled then return end
    applyScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            applyScheduled = false
            Apply()
        end)
    else
        applyScheduled = false
        Apply()
    end
end

local function HandleEvent(_, event, unit)
    if event == "UNIT_NAME_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" then
        ApplyRealmIndicatorForUnit(unit)
        return
    end

    if not ShouldRunCleaner() then return end

    ScheduleApply()
end

frame:SetScript("OnEvent", function(...)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("RetailUnitFrameCleaner:OnEvent", HandleEvent, ...)
    end
    return HandleEvent(...)
end)

function Carpenter_ApplyRetailUnitFrameCleaner()
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("RetailUnitFrameCleaner:Apply", Apply)
    end
    return Apply()
end
