--[[ Carpenter - Explorer Mode action buttons ]]
-- Action buttons: alpha, cooldown swipes, and Blizzard update hooks.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Internal = ns.Private.ExplorerModeInternal
local S = Internal.State
local EXPLORING_ALPHA = Internal.EXPLORING_ALPHA
local actionBarClusterFrameNames = Internal.actionBarClusterFrameNames
local actionBarManagedFrameNames = Internal.actionBarManagedFrameNames
local actionButtonCooldownKeys = Internal.actionButtonCooldownKeys
local actionButtonGroups = Internal.actionButtonGroups
local actionButtonNamePatterns = Internal.actionButtonNamePatterns
local actionButtonNames = Internal.actionButtonNames
local actionButtonOverlayFunctions = Internal.actionButtonOverlayFunctions
local actionButtonRefreshFunctions = Internal.actionButtonRefreshFunctions
local classicOrTBCActionBarVisualFrameNames = Internal.classicOrTBCActionBarVisualFrameNames
local cooldownDrawMethods = Internal.cooldownDrawMethods
local cooldownFrameFunctions = Internal.cooldownFrameFunctions
local GetManagedTargetForFrame = Internal.GetManagedTargetForFrame
local IsClassicOrTBCClient = Internal.IsClassicOrTBCClient
local IsCursorWithinFrameBounds = Internal.IsCursorWithinFrameBounds
local IsEnabled = Internal.IsEnabled
local IsForbiddenFrame = Internal.IsForbiddenFrame
local IsGameEditModeActive = Internal.IsGameEditModeActive
local IsInCombat = Internal.IsInCombat
local IsMinimapClutterFrame = Internal.IsMinimapClutterFrame
local IsMouseOverFrame = Internal.IsMouseOverFrame
local IsPlayerKnownHurt = Internal.IsPlayerKnownHurt
local ReadFrameAlpha = Internal.ReadFrameAlpha
local RememberAlpha = Internal.RememberAlpha
local SafeSetAlpha = Internal.SafeSetAlpha
local TargetAlphaForObject = Internal.TargetAlphaForObject

local actionButtonOverlayHooksInstalled = false
local actionButtonCooldownHookedFrames = {}
local actionButtonCooldownDrawStates = {}

local function IsKnownActionButtonName(name)
    if not name then
        return false
    end

    for _, pattern in ipairs(actionButtonNamePatterns) do
        if name:match(pattern) then
            return true
        end
    end

    return false
end

local function IsActionButtonFrame(frameObject)
    if not frameObject or not frameObject.GetName then
        return false
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    return ok and IsKnownActionButtonName(name)
end

local function FindActionButtonAncestor(frameObject)
    local current = frameObject
    local depth = 0
    while current and depth <= 8 do
        if IsActionButtonFrame(current) then
            return current
        end
        if not current.GetParent then
            return nil
        end
        local ok, parent = pcall(current.GetParent, current)
        if not ok then
            return nil
        end
        current = parent
        depth = depth + 1
    end

    return nil
end

local function ForEachActionButton(callback)
    for _, group in ipairs(actionButtonGroups) do
        for i = 1, group.count do
            local button = _G[group.prefix .. i]
            if button then
                callback(button)
            end
        end
    end

    for _, name in ipairs(actionButtonNames) do
        local button = _G[name]
        if button then
            callback(button)
        end
    end
end

local function GetFrameName(frameObject)
    if not frameObject or not frameObject.GetName then
        return nil
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    return ok and name or nil
end

local function IsNamedFrameInSet(frameObject, nameSet)
    local name = GetFrameName(frameObject)
    return name and nameSet[name] == true
end

local function IsActionBarManagedFrame(frameObject)
    if IsClassicOrTBCClient() and IsNamedFrameInSet(frameObject, classicOrTBCActionBarVisualFrameNames) then
        return false
    end

    return IsNamedFrameInSet(frameObject, actionBarManagedFrameNames)
end

local function IsTrackingBarHovered(frameObject)
    local sources = S.trackingBarHoverSources[frameObject]
    if not sources then return false end

    for source in pairs(sources) do
        if IsMouseOverFrame(source) or IsCursorWithinFrameBounds(source) then return true end
    end
    return false
end

local function IsActionBarClusterFrame(frameObject)
    return S.trackingBarHoverSources[frameObject] ~= nil or IsNamedFrameInSet(frameObject, actionBarClusterFrameNames)
end

local function IsCooldownFrame(frameObject)
    if not frameObject or not frameObject.SetAlpha then
        return false
    end

    return frameObject.SetCooldown or frameObject.SetDrawSwipe or frameObject.SetDrawBling
end

local function GetCooldownDrawValue(cooldown, method)
    if cooldown[method.getter] then
        local ok, value = pcall(cooldown[method.getter], cooldown)
        if ok then
            return value == true
        end
    end

    return method.fallback
end

local function SetCooldownDrawValue(cooldown, method, value)
    if cooldown[method.setter] then
        pcall(cooldown[method.setter], cooldown, value)
    end
end

local function RememberCooldownDrawState(cooldown)
    local state = actionButtonCooldownDrawStates[cooldown]
    if state then
        return state
    end

    state = {}
    actionButtonCooldownDrawStates[cooldown] = state

    for _, method in ipairs(cooldownDrawMethods) do
        if cooldown[method.setter] then
            state[method.setter] = GetCooldownDrawValue(cooldown, method)
        end
    end

    return state
end

local function RestoreCooldownDrawState(cooldown, state)
    if not cooldown or IsForbiddenFrame(cooldown) then
        return
    end

    state = state or actionButtonCooldownDrawStates[cooldown]
    if not state then
        return
    end

    for _, method in ipairs(cooldownDrawMethods) do
        if state[method.setter] ~= nil then
            SetCooldownDrawValue(cooldown, method, state[method.setter])
        end
    end
end

local function RestoreActionButtonCooldownDrawStates()
    for cooldown, state in pairs(actionButtonCooldownDrawStates) do
        RestoreCooldownDrawState(cooldown, state)
        actionButtonCooldownDrawStates[cooldown] = nil
    end
end

local function IsForeverClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isForever == true
end

local function ApplyCooldownDrawState(cooldown, targetAlpha)
    if IsForeverClient() or not IsCooldownFrame(cooldown) or IsForbiddenFrame(cooldown) then
        return
    end

    if targetAlpha == EXPLORING_ALPHA then
        RememberCooldownDrawState(cooldown)
        for _, method in ipairs(cooldownDrawMethods) do
            SetCooldownDrawValue(cooldown, method, false)
        end
    elseif actionButtonCooldownDrawStates[cooldown] then
        RestoreCooldownDrawState(cooldown)
        actionButtonCooldownDrawStates[cooldown] = nil
    end
end

local function AddCooldownFrame(cooldowns, frameObject)
    if IsCooldownFrame(frameObject) then
        cooldowns[frameObject] = true
    end
end

local function CollectCooldownChildren(root, cooldowns, depth)
    if not root or depth > 3 or IsForbiddenFrame(root) then
        return
    end

    AddCooldownFrame(cooldowns, root)

    if root.GetChildren then
        for i = 1, root:GetNumChildren() do
            CollectCooldownChildren(select(i, root:GetChildren()), cooldowns, depth + 1)
        end
    end
end

local function CollectActionButtonCooldownFrames(button, cooldowns)
    if not button then
        return
    end

    for _, key in ipairs(actionButtonCooldownKeys) do
        AddCooldownFrame(cooldowns, button[key])
    end

    if button.GetName then
        local ok, name = pcall(button.GetName, button)
        if ok and name then
            AddCooldownFrame(cooldowns, _G[name .. "Cooldown"])
        end
    end

    CollectCooldownChildren(button, cooldowns, 0)
end

local function CollectAlphaTargets(root, starts, targets, targetAlpha, depth)
    if not root or depth > 4 then
        return
    end
    if IsForbiddenFrame(root) or IsMinimapClutterFrame(root) then
        return
    end

    if root.SetAlpha then
        RememberAlpha(root)
        local target = TargetAlphaForObject(root, targetAlpha)
        starts[root] = ReadFrameAlpha(root, target)
        targets[root] = TargetAlphaForObject(root, targetAlpha)
    end

    if root.GetRegions then
        for i = 1, select("#", root:GetRegions()) do
            local region = select(i, root:GetRegions())
            if region and region.SetAlpha and not IsMinimapClutterFrame(region) then
                RememberAlpha(region)
                local target = TargetAlphaForObject(region, targetAlpha)
                starts[region] = ReadFrameAlpha(region, target)
                targets[region] = TargetAlphaForObject(region, targetAlpha)
            end
        end
    end

    if root.GetChildren then
        for i = 1, root:GetNumChildren() do
            CollectAlphaTargets(select(i, root:GetChildren()), starts, targets, targetAlpha, depth + 1)
        end
    end
end

local function ApplyActionButtonCooldownDrawStates(button, targetAlpha)
    if IsForeverClient() then
        return
    end

    local cooldowns = {}
    CollectActionButtonCooldownFrames(button, cooldowns)

    for cooldown in pairs(cooldowns) do
        ApplyCooldownDrawState(cooldown, targetAlpha)
    end
end

local function ApplyActionButtonFrameAlpha(button, targetAlpha)
    if not button or IsForbiddenFrame(button) or not button.SetAlpha then
        return
    end

    RememberAlpha(button)
    SafeSetAlpha(button, TargetAlphaForObject(button, targetAlpha))
end

local function ApplyActionButtonOverlayAlpha(button, targetAlphaOverride)
    if not button then
        return
    end

    local targetAlpha = targetAlphaOverride or GetManagedTargetForFrame(button) or S.actionButtonTargetAlpha
    if targetAlpha == nil then
        return
    end

    if targetAlpha == EXPLORING_ALPHA and (IsInCombat() or not S.explorerFaded or IsPlayerKnownHurt()) then
        return
    end

    if IsInCombat() then
        ApplyActionButtonCooldownDrawStates(button, targetAlpha)
        return
    end

    ApplyActionButtonCooldownDrawStates(button, targetAlpha)
    ApplyActionButtonFrameAlpha(button, targetAlpha)
end

local function ClampUpdatedActionButtonAlpha(button)
    if S.actionButtonTargetAlpha == nil then
        return
    end
    if not (IsEnabled() and S.explorerFaded and not IsInCombat() and not IsPlayerKnownHurt() and not IsGameEditModeActive()) then
        return
    end

    ApplyActionButtonFrameAlpha(button, S.actionButtonTargetAlpha)
end

local function ApplyActionButtonVisualAlphasForManagedFrame(frameObject, targetAlpha)
    if not IsActionBarManagedFrame(frameObject) then
        return
    end

    ForEachActionButton(function(button)
        local currentTargetAlpha, managedRoot = GetManagedTargetForFrame(button)
        if managedRoot == frameObject or button == frameObject then
            ApplyActionButtonOverlayAlpha(button, targetAlpha or currentTargetAlpha)
        end
    end)
end

local function ApplyActionButtonCooldownDrawStatesForManagedFrame(frameObject, targetAlpha)
    if not IsActionBarManagedFrame(frameObject) then
        return
    end

    ForEachActionButton(function(button)
        local currentTargetAlpha, managedRoot = GetManagedTargetForFrame(button)
        if managedRoot == frameObject or button == frameObject then
            ApplyActionButtonCooldownDrawStates(button, targetAlpha or currentTargetAlpha)
        end
    end)
end

local function ApplyCooldownFrameAlpha(cooldown)
    if IsForeverClient() then
        return
    end

    local button = FindActionButtonAncestor(cooldown)
    if button then
        ApplyActionButtonOverlayAlpha(button)
    end
end

local function HookActionButtonCooldownFrame(cooldown)
    if IsForeverClient() or not cooldown or actionButtonCooldownHookedFrames[cooldown] or not cooldown.HookScript then
        return
    end

    actionButtonCooldownHookedFrames[cooldown] = true
    pcall(cooldown.HookScript, cooldown, "OnShow", ApplyCooldownFrameAlpha)
end

local function RefreshActionButtonCooldownHooks()
    if IsForeverClient() then
        return
    end

    ForEachActionButton(function(button)
        local cooldowns = {}
        CollectActionButtonCooldownFrames(button, cooldowns)
        for cooldown in pairs(cooldowns) do
            HookActionButtonCooldownFrame(cooldown)
        end
    end)
end

local function HookActionButtonOverlayFunctions()
    if IsForeverClient() then
        return
    end

    if actionButtonOverlayHooksInstalled or not hooksecurefunc then
        if RefreshActionButtonCooldownHooks then
            RefreshActionButtonCooldownHooks()
        end
        return
    end

    local hookedAny = false
    for _, functionName in ipairs(actionButtonOverlayFunctions) do
        if type(_G[functionName]) == "function" then
            local ok = pcall(hooksecurefunc, functionName, function(button)
                ApplyActionButtonOverlayAlpha(button)
            end)
            hookedAny = hookedAny or ok
        end
    end

    for _, functionName in ipairs(actionButtonRefreshFunctions) do
        if type(_G[functionName]) == "function" then
            local ok = pcall(hooksecurefunc, functionName, function(button)
                ClampUpdatedActionButtonAlpha(button)
            end)
            hookedAny = hookedAny or ok
        end
    end

    for _, functionName in ipairs(cooldownFrameFunctions) do
        if type(_G[functionName]) == "function" then
            local ok = pcall(hooksecurefunc, functionName, function(cooldown)
                ApplyCooldownFrameAlpha(cooldown)
            end)
            hookedAny = hookedAny or ok
        end
    end

    RefreshActionButtonCooldownHooks()
    actionButtonOverlayHooksInstalled = hookedAny
end

Internal.ApplyActionButtonCooldownDrawStates = ApplyActionButtonCooldownDrawStates
Internal.ApplyActionButtonCooldownDrawStatesForManagedFrame = ApplyActionButtonCooldownDrawStatesForManagedFrame
Internal.ApplyActionButtonVisualAlphasForManagedFrame = ApplyActionButtonVisualAlphasForManagedFrame
Internal.CollectAlphaTargets = CollectAlphaTargets
Internal.ForEachActionButton = ForEachActionButton
Internal.HookActionButtonOverlayFunctions = HookActionButtonOverlayFunctions
Internal.IsActionBarClusterFrame = IsActionBarClusterFrame
Internal.IsActionBarManagedFrame = IsActionBarManagedFrame
Internal.IsTrackingBarHovered = IsTrackingBarHovered
Internal.RestoreActionButtonCooldownDrawStates = RestoreActionButtonCooldownDrawStates
