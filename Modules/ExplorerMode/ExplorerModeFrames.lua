--[[ Carpenter - Explorer Mode frames ]]
-- Client and health checks, hover detection, and the managed frame registry.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Internal = ns.Private.ExplorerModeInternal
local S = Internal.State
local ExplorerMode = ns.Private.ExplorerMode or {}
ns.Private.ExplorerMode = ExplorerMode
local TrackingBars = ns.Private.StatusTrackingBars or {}
local EXPLORING_ALPHA = Internal.EXPLORING_ALPHA
local FEATURE_KEY = Internal.FEATURE_KEY
local VISIBLE_ALPHA = Internal.VISIBLE_ALPHA
local classicOrTBCBottomBarFrameNames = Internal.classicOrTBCBottomBarFrameNames
local frameNames = Internal.frameNames
local minimapClutterFrameNames = Internal.minimapClutterFrameNames
local repeatedFramePrefixes = Internal.repeatedFramePrefixes
local unitFramePieces = Internal.unitFramePieces

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

function ExplorerMode.IsFaded()
    return IsEnabled() and S.explorerFaded == true
end

local function IsClassicOrTBCClient()
    local client = Carpenter and Carpenter.Client
    return client and (client.isVanilla or client.isTBC or client.isClassic)
end

local function IsEditModeSupportedClient()
    local client = Carpenter and Carpenter.Client
    return client and (client.isRetail or client.isTBC)
end

local function IsForbiddenFrame(frameObject)
    if not frameObject or not frameObject.IsForbidden then
        return false
    end
    local ok, forbidden = pcall(frameObject.IsForbidden, frameObject)
    return ok and forbidden
end

local function SafeGetFrameName(frameObject)
    if not frameObject or not frameObject.GetName then
        return nil
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    return ok and name or nil
end

local function IsMinimapClutterFrame(frameObject)
    local current = frameObject
    local depth = 0

    while current and depth <= 8 do
        local name = SafeGetFrameName(current)
        if name and minimapClutterFrameNames[name] then
            return true
        end

        if current == Minimap or current == _G.MinimapCluster then
            return true
        end

        if not current.GetParent then
            return false
        end

        local ok, parent = pcall(current.GetParent, current)
        if not ok then
            return false
        end

        current = parent
        depth = depth + 1
    end

    return false
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsGameEditModeActive()
    if not IsEditModeSupportedClient() then
        return false
    end

    local editMode = _G.EditModeManagerFrame
    if not editMode then
        return false
    end

    if editMode.IsEditModeActive then
        local ok, active = pcall(editMode.IsEditModeActive, editMode)
        if ok then
            return active == true
        end
    end

    if editMode.editModeActive ~= nil then
        return editMode.editModeActive == true
    end

    return false
end

local function GetPlayerHealthBar()
    local Unit = ns and ns.Private and ns.Private.Unit
    return Unit and Unit.FrameHealthBar and Unit.FrameHealthBar("player") or nil
end

local function IsPlayerHealthBarFull()
    local healthBar = GetPlayerHealthBar()
    if not (healthBar and healthBar.GetValue and healthBar.GetMinMaxValues) then
        return nil
    end

    local ok, fullHealth = pcall(function()
        local value = healthBar:GetValue() or 0
        local _, maxValue = healthBar:GetMinMaxValues()
        maxValue = maxValue or 0
        if maxValue <= 0 then
            return true
        end

        return value >= maxValue
    end)

    if ok then
        return fullHealth == true
    end
    return nil
end

-- Returns true or false when health can be read, or nil when the client hides
-- it behind secret values (retail and Forever).
local function GetPlayerHealthState()
    if not UnitHealth or not UnitHealthMax then
        return true
    end

    local ok, fullHealth = pcall(function()
        local maxHealth = UnitHealthMax("player") or 0
        if maxHealth <= 0 then
            return true
        end

        return (UnitHealth("player") or 0) >= maxHealth
    end)

    if ok then
        return fullHealth == true
    end

    return IsPlayerHealthBarFull()
end

-- Unreadable health is not known to be hurt; hidden-health clients instead
-- hold the fade until health stops changing.
local function IsPlayerKnownHurt()
    return GetPlayerHealthState() == false
end

local function IsPlayerHealthSecret()
    return GetPlayerHealthState() == nil
end

local function IsShownFrame(frameObject)
    if not frameObject or not frameObject.IsShown then
        return true
    end
    local ok, shown = pcall(frameObject.IsShown, frameObject)
    return ok and shown
end

local function IsMouseOverFrame(frameObject)
    if not frameObject or not IsShownFrame(frameObject) then
        return false
    end

    if MouseIsOver then
        local ok, hovering = pcall(MouseIsOver, frameObject)
        if ok then
            return hovering == true
        end
    end

    if frameObject.IsMouseOver then
        local ok, hovering = pcall(frameObject.IsMouseOver, frameObject)
        return ok and hovering == true
    end

    return false
end

local function IsCursorWithinFrameBounds(frameObject)
    if not (frameObject and GetCursorPosition and frameObject.GetLeft and frameObject.GetRight
        and frameObject.GetTop and frameObject.GetBottom) then
        return false
    end

    local ok, hovering = pcall(function()
        local left = frameObject:GetLeft()
        local right = frameObject:GetRight()
        local top = frameObject:GetTop()
        local bottom = frameObject:GetBottom()
        if not (left and right and top and bottom) then return false end

        local scale = 1
        if UIParent and UIParent.GetEffectiveScale then
            scale = UIParent:GetEffectiveScale() or 1
        end
        if scale <= 0 then scale = 1 end

        local cursorX, cursorY = GetCursorPosition()
        cursorX, cursorY = cursorX / scale, cursorY / scale
        return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
    end)

    return ok and hovering == true
end

local function IsManagedAncestorHovered(frameObject)
    if not frameObject or not frameObject.GetParent then
        return false
    end

    local ok, parent = pcall(frameObject.GetParent, frameObject)
    while ok and parent do
        if S.managedFrames[parent] and IsMouseOverFrame(parent) then
            return true
        end
        if not parent.GetParent then
            return false
        end
        ok, parent = pcall(parent.GetParent, parent)
    end

    return false
end

local function SafeAlphaValue(value, fallback)
    fallback = fallback or VISIBLE_ALPHA

    local ok, alpha = pcall(function()
        if value == nil then
            return fallback
        end
        if value < 0 then
            return 0
        end
        if value > 1 then
            return 1
        end
        return value
    end)

    return ok and alpha or fallback
end

local function ReadFrameAlpha(frameObject, fallback)
    fallback = fallback or VISIBLE_ALPHA
    if not (frameObject and frameObject.GetAlpha) then
        return fallback
    end

    local ok, alpha = pcall(frameObject.GetAlpha, frameObject)
    if not ok then
        return fallback
    end

    return SafeAlphaValue(alpha, fallback)
end

local function AddManagedFrame(frameObject)
    if not frameObject or IsForbiddenFrame(frameObject) or IsMinimapClutterFrame(frameObject) or not frameObject.SetAlpha then
        return
    end

    if not S.managedFrames[frameObject] then
        S.managedAlphas[frameObject] = ReadFrameAlpha(frameObject, VISIBLE_ALPHA)
        S.managedFrames[frameObject] = true
    end
end

local function AddFrameByName(name)
    AddManagedFrame(_G[name])
end

local function RefreshTrackingBarFrames()
    local roots = {}
    S.trackingBarHoverSources = setmetatable({}, { __mode = "k" })

    if not TrackingBars.ForEachRoot then return end

    TrackingBars.ForEachRoot(function(root)
        AddManagedFrame(root)
        roots[root] = true
        S.trackingBarHoverSources[root] = setmetatable({ [root] = true }, { __mode = "k" })
    end, true)

    if not TrackingBars.ForEach then return end

    TrackingBars.ForEach(function(object)
        local current = object
        local depth = 0
        while current and depth < 16 do
            if roots[current] then
                S.trackingBarHoverSources[current][object] = true
                return
            end
            if not current.GetParent then return end
            local ok, parent = pcall(current.GetParent, current)
            if not ok then return end
            current = parent
            depth = depth + 1
        end
    end, true)
end

local function RefreshManagedFrames()
    for _, name in ipairs(frameNames) do
        AddFrameByName(name)
    end

    RefreshTrackingBarFrames()

    if IsClassicOrTBCClient() then
        for _, name in ipairs(classicOrTBCBottomBarFrameNames) do
            AddFrameByName(name)
        end
    end

    for _, name in ipairs(unitFramePieces) do
        AddFrameByName(name)
    end

    for _, group in ipairs(repeatedFramePrefixes) do
        for i = 1, group.count do
            AddFrameByName(group.prefix .. i .. group.suffix)
        end
    end
end

local function RememberAlpha(object)
    if not object or S.managedAlphas[object] or not object.GetAlpha then
        return
    end

    S.managedAlphas[object] = ReadFrameAlpha(object, VISIBLE_ALPHA)
end

local function SafeSetAlpha(object, alpha)
    if not object or not object.SetAlpha then
        return
    end
    if IsForbiddenFrame(object) then
        return
    end
    RememberAlpha(object)
    pcall(object.SetAlpha, object, alpha)
end

local function TargetAlphaForObject(object, targetAlpha)
    local originalAlpha = SafeAlphaValue(S.managedAlphas[object], VISIBLE_ALPHA)
    if targetAlpha == VISIBLE_ALPHA then
        return originalAlpha
    end
    return math.min(originalAlpha, SafeAlphaValue(targetAlpha, EXPLORING_ALPHA))
end

local function GetManagedTargetForFrame(frameObject)
    local current = frameObject
    while current do
        if S.managedFrames[current] then
            return S.frameTargets[current], current
        end
        if not current.GetParent then
            return nil, nil
        end
        local ok, parent = pcall(current.GetParent, current)
        if not ok then
            return nil, nil
        end
        current = parent
    end

    return nil, nil
end

function ExplorerMode.GetStatusTrackingTargetAlpha(frameObject)
    if not (IsEnabled() and S.explorerFaded) then return nil end

    local targetAlpha, managedRoot = GetManagedTargetForFrame(frameObject)
    if managedRoot ~= frameObject or not S.trackingBarHoverSources[managedRoot] then
        return nil
    end

    if targetAlpha == nil then targetAlpha = EXPLORING_ALPHA end
    return TargetAlphaForObject(managedRoot, targetAlpha)
end

Internal.GetManagedTargetForFrame = GetManagedTargetForFrame
Internal.IsClassicOrTBCClient = IsClassicOrTBCClient
Internal.IsCursorWithinFrameBounds = IsCursorWithinFrameBounds
Internal.IsEditModeSupportedClient = IsEditModeSupportedClient
Internal.IsEnabled = IsEnabled
Internal.IsForbiddenFrame = IsForbiddenFrame
Internal.IsGameEditModeActive = IsGameEditModeActive
Internal.IsInCombat = IsInCombat
Internal.IsManagedAncestorHovered = IsManagedAncestorHovered
Internal.IsMinimapClutterFrame = IsMinimapClutterFrame
Internal.IsMouseOverFrame = IsMouseOverFrame
Internal.IsPlayerHealthSecret = IsPlayerHealthSecret
Internal.IsPlayerKnownHurt = IsPlayerKnownHurt
Internal.IsShownFrame = IsShownFrame
Internal.ReadFrameAlpha = ReadFrameAlpha
Internal.RefreshManagedFrames = RefreshManagedFrames
Internal.RememberAlpha = RememberAlpha
Internal.SafeSetAlpha = SafeSetAlpha
Internal.TargetAlphaForObject = TargetAlphaForObject
