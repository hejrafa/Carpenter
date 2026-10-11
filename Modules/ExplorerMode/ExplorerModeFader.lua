--[[ Carpenter - Explorer Mode fader ]]
-- Fade and hover drivers that animate managed frames.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Internal = ns.Private.ExplorerModeInternal
local S = Internal.State
local ACTION_BAR_CLUSTER_KEY = Internal.ACTION_BAR_CLUSTER_KEY
local ACTION_BUTTON_FADE_KEY = Internal.ACTION_BUTTON_FADE_KEY
local EXPLORING_ALPHA = Internal.EXPLORING_ALPHA
local HOVER_FADE_IN_SECONDS = Internal.HOVER_FADE_IN_SECONDS
local HOVER_FADE_OUT_DELAY_SECONDS = Internal.HOVER_FADE_OUT_DELAY_SECONDS
local HOVER_FADE_OUT_SECONDS = Internal.HOVER_FADE_OUT_SECONDS
local HOVER_UPDATE_INTERVAL = Internal.HOVER_UPDATE_INTERVAL
local VISIBLE_ALPHA = Internal.VISIBLE_ALPHA
local IsEnabled = Internal.IsEnabled
local IsForbiddenFrame = Internal.IsForbiddenFrame
local IsGameEditModeActive = Internal.IsGameEditModeActive
local IsInCombat = Internal.IsInCombat
local IsManagedAncestorHovered = Internal.IsManagedAncestorHovered
local IsMouseOverFrame = Internal.IsMouseOverFrame
local ReadFrameAlpha = Internal.ReadFrameAlpha
local RefreshManagedFrames = Internal.RefreshManagedFrames
local RememberAlpha = Internal.RememberAlpha
local SafeSetAlpha = Internal.SafeSetAlpha
local TargetAlphaForObject = Internal.TargetAlphaForObject
local ApplyActionButtonCooldownDrawStates = Internal.ApplyActionButtonCooldownDrawStates
local ApplyActionButtonCooldownDrawStatesForManagedFrame = Internal.ApplyActionButtonCooldownDrawStatesForManagedFrame
local ApplyActionButtonVisualAlphasForManagedFrame = Internal.ApplyActionButtonVisualAlphasForManagedFrame
local CollectAlphaTargets = Internal.CollectAlphaTargets
local ForEachActionButton = Internal.ForEachActionButton
local IsActionBarClusterFrame = Internal.IsActionBarClusterFrame
local IsActionBarManagedFrame = Internal.IsActionBarManagedFrame
local IsTrackingBarHovered = Internal.IsTrackingBarHovered
local RestoreActionButtonCooldownDrawStates = Internal.RestoreActionButtonCooldownDrawStates

local function EaseFadeProgress(progress)
    return progress * progress * progress * (progress * ((progress * 6) - 15) + 10)
end

local function EaseFadeOutProgress(progress)
    return EaseFadeProgress(progress)
end

local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
fadeDriver:SetScript("OnUpdate", function(self, elapsed)
    local hasActiveFade = false

    for root, fade in pairs(S.activeFades) do
        fade.elapsed = fade.elapsed + elapsed
        local progress = fade.duration > 0 and math.min(fade.elapsed / fade.duration, 1) or 1

        for object, startAlpha in pairs(fade.starts) do
            local targetAlpha = fade.targets[object] or VISIBLE_ALPHA
            local easedProgress = EaseFadeProgress(progress)
            if targetAlpha < startAlpha then
                easedProgress = EaseFadeOutProgress(progress)
            end
            SafeSetAlpha(object, startAlpha + ((targetAlpha - startAlpha) * easedProgress))
        end

        if progress >= 1 then
            S.activeFades[root] = nil
        else
            hasActiveFade = true
        end
    end

    if not hasActiveFade then
        self:Hide()
    end
end)

local function FadeFrame(frameObject, targetAlpha, duration, forceApply)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha then
        return
    end

    if not forceApply and S.frameTargets[frameObject] == targetAlpha then
        return
    end
    S.frameTargets[frameObject] = targetAlpha

    if UIFrameFadeRemoveFrame and not IsInCombat() then
        pcall(UIFrameFadeRemoveFrame, frameObject)
    end

    local starts = {}
    local targets = {}
    if S.trackingBarHoverSources[frameObject] then
        -- Blizzard animates the status bar containers independently. Fade only
        -- their shared root so revealing it cannot restore a child to the
        -- template's initial zero alpha.
        RememberAlpha(frameObject)
        local target = TargetAlphaForObject(frameObject, targetAlpha)
        starts[frameObject] = ReadFrameAlpha(frameObject, target)
        targets[frameObject] = target
    else
        CollectAlphaTargets(frameObject, starts, targets, targetAlpha, 0)
    end

    if duration == nil or duration <= 0 then
        ApplyActionButtonVisualAlphasForManagedFrame(frameObject, targetAlpha)
        S.activeFades[frameObject] = nil
        for object, alpha in pairs(targets) do
            SafeSetAlpha(object, alpha)
        end
        return
    end

    ApplyActionButtonCooldownDrawStatesForManagedFrame(frameObject, targetAlpha)

    S.activeFades[frameObject] = {
        elapsed = 0,
        duration = duration,
        starts = starts,
        targets = targets,
    }
    fadeDriver:Show()
end

local function FadeActionButtonVisuals(targetAlpha, duration, forceApply)
    if not forceApply and S.actionButtonTargetAlpha == targetAlpha then
        return
    end

    S.actionButtonTargetAlpha = targetAlpha
    local starts = {}
    local targets = {}

    ForEachActionButton(function(button)
        if button and not IsForbiddenFrame(button) and button.SetAlpha then
            ApplyActionButtonCooldownDrawStates(button, targetAlpha)
            local target = TargetAlphaForObject(button, targetAlpha)
            starts[button] = ReadFrameAlpha(button, target)
            targets[button] = TargetAlphaForObject(button, targetAlpha)
        end
    end)

    if duration == nil or duration <= 0 then
        S.activeFades[ACTION_BUTTON_FADE_KEY] = nil
        for object, alpha in pairs(targets) do
            SafeSetAlpha(object, alpha)
        end
        if targetAlpha == VISIBLE_ALPHA then
            RestoreActionButtonCooldownDrawStates()
        end
        return
    end

    S.activeFades[ACTION_BUTTON_FADE_KEY] = {
        elapsed = 0,
        duration = duration,
        starts = starts,
        targets = targets,
    }
    fadeDriver:Show()
end

local function ForEachActionBarClusterFrame(callback)
    for frameObject in pairs(S.managedFrames) do
        if IsActionBarClusterFrame(frameObject) then
            callback(frameObject)
        end
    end
end

local function IsActionBarClusterHovered()
    local hovered = false
    ForEachActionBarClusterFrame(function(frameObject)
        if not hovered and not IsActionBarManagedFrame(frameObject)
            and (IsMouseOverFrame(frameObject) or IsTrackingBarHovered(frameObject)) then
            hovered = true
        end
    end)

    ForEachActionButton(function(button)
        if not hovered and IsMouseOverFrame(button) then
            hovered = true
        end
    end)

    return hovered
end

local function HasVisibleActionBarClusterTarget()
    if S.actionButtonTargetAlpha == VISIBLE_ALPHA then
        return true
    end

    local visible = false
    ForEachActionBarClusterFrame(function(frameObject)
        if S.frameTargets[frameObject] == VISIBLE_ALPHA then
            visible = true
        end
    end)

    return visible
end

local function HasVisibleHoverTarget()
    if HasVisibleActionBarClusterTarget() then
        return true
    end

    for frameObject in pairs(S.managedFrames) do
        if not IsActionBarClusterFrame(frameObject) and S.frameTargets[frameObject] == VISIBLE_ALPHA then
            return true
        end
    end

    return false
end

local function FadeActionBarCluster(targetAlpha, duration)
    ForEachActionBarClusterFrame(function(frameObject)
        if not IsActionBarManagedFrame(frameObject) then
            FadeFrame(frameObject, targetAlpha, duration)
        end
    end)
    FadeActionButtonVisuals(targetAlpha, duration)
end

local hoverDriver = CreateFrame("Frame")
hoverDriver:Hide()
hoverDriver:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() or IsInCombat() then
        self:Hide()
        return
    end
    if IsGameEditModeActive() then
        Internal.RestoreVisible(0, true)
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < HOVER_UPDATE_INTERVAL then
        return
    end
    self.elapsed = 0

    if GetCursorPosition then
        local cursorX, cursorY = GetCursorPosition()
        local cursorMoved = cursorX ~= self.lastCursorX or cursorY ~= self.lastCursorY
        self.lastCursorX = cursorX
        self.lastCursorY = cursorY

        if not cursorMoved and not HasVisibleHoverTarget() and not next(S.activeFades) then
            return
        end
    end

    local now = GetTime and GetTime() or 0
    if IsActionBarClusterHovered() then
        S.hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = nil
        FadeActionBarCluster(VISIBLE_ALPHA, HOVER_FADE_IN_SECONDS)
    elseif HasVisibleActionBarClusterTarget() then
        S.hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = S.hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] or (now + HOVER_FADE_OUT_DELAY_SECONDS)
        if now >= S.hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] then
            S.hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = nil
            FadeActionBarCluster(EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
        end
    else
        S.hoverFadeOutAt[ACTION_BAR_CLUSTER_KEY] = nil
        FadeActionBarCluster(EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
    end

    for frameObject in pairs(S.managedFrames) do
        if IsActionBarClusterFrame(frameObject) then
            S.hoverFadeOutAt[frameObject] = nil
        elseif IsMouseOverFrame(frameObject) or IsTrackingBarHovered(frameObject) or IsManagedAncestorHovered(frameObject) then
            S.hoverFadeOutAt[frameObject] = nil
            FadeFrame(frameObject, VISIBLE_ALPHA, HOVER_FADE_IN_SECONDS)
        elseif S.frameTargets[frameObject] == VISIBLE_ALPHA then
            S.hoverFadeOutAt[frameObject] = S.hoverFadeOutAt[frameObject] or (now + HOVER_FADE_OUT_DELAY_SECONDS)
            if now >= S.hoverFadeOutAt[frameObject] then
                S.hoverFadeOutAt[frameObject] = nil
                FadeFrame(frameObject, EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
            end
        else
            S.hoverFadeOutAt[frameObject] = nil
            FadeFrame(frameObject, EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
        end
    end
end)

local function ApplyTargetAlpha(targetAlpha, duration)
    RefreshManagedFrames()
    for frameObject in pairs(S.managedFrames) do
        if not IsActionBarManagedFrame(frameObject) then
            FadeFrame(frameObject, targetAlpha, duration)
        end
    end
    FadeActionButtonVisuals(targetAlpha, duration)

    if targetAlpha == VISIBLE_ALPHA then
        RestoreActionButtonCooldownDrawStates()
    end
end

local function RefreshExplorerTargets()
    RefreshManagedFrames()
    for frameObject in pairs(S.managedFrames) do
        if not IsActionBarManagedFrame(frameObject) then
            local targetAlpha = S.frameTargets[frameObject]
            if targetAlpha == nil then targetAlpha = EXPLORING_ALPHA end
            FadeFrame(frameObject, targetAlpha, 0, true)
        end
    end

    FadeActionButtonVisuals(S.actionButtonTargetAlpha or EXPLORING_ALPHA, 0, true)
end

Internal.ApplyTargetAlpha = ApplyTargetAlpha
Internal.FadeActionButtonVisuals = FadeActionButtonVisuals
Internal.RefreshExplorerTargets = RefreshExplorerTargets
Internal.fadeDriver = fadeDriver
Internal.hoverDriver = hoverDriver
