--[[ Carpenter - ActionBarRange ]]
-- Uses Blizzard's own range checks to slightly dim action buttons when
-- they are out of range (too close or too far), matching the default
-- "not usable" look and working with macros.

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("actionBarRangeEnabled")
end

local RANGE_TINT = 0.4
local buttonStates = setmetatable({}, { __mode = "k" })
local tintedButtons = setmetatable({}, { __mode = "k" })

local function IsForbiddenButton(button)
    if not button then return true end
    if not button.IsForbidden then return false end
    local ok, forbidden = pcall(button.IsForbidden, button)
    return not ok or forbidden == true
end

local function GetButtonIcon(button)
    if not button then return nil end
    if button.icon then return button.icon end
    if not button.GetName then return nil end
    local ok, name = pcall(button.GetName, button)
    if not ok then return nil end
    if not name then return nil end
    return _G[name .. "Icon"]
end

local function GetButtonState(button)
    local state = buttonStates[button]
    if not state then
        state = {}
        buttonStates[button] = state
    end
    return state
end

local function CaptureBlizzardColor(icon, state)
    if not icon or not state or not icon.GetVertexColor then return end
    local ok, r, g, b, a = pcall(icon.GetVertexColor, icon)
    if ok and r ~= nil and g ~= nil and b ~= nil then
        state.blizzardColor = { r, g, b, a }
    end
end

local function ClearDimmedState(button, state)
    if not button then return end
    state = state or buttonStates[button]
    if state then state.dimmed = false end
    tintedButtons[button] = nil
    button._Carpenter_RangeDimmed = false
end

local function RestoreBlizzardColor(button)
    local icon = GetButtonIcon(button)
    local state = buttonStates[button]
    local color = state and state.blizzardColor

    if icon and icon.SetVertexColor then
        if color then
            if color[4] ~= nil then
                pcall(icon.SetVertexColor, icon, color[1], color[2], color[3], color[4])
            else
                pcall(icon.SetVertexColor, icon, color[1], color[2], color[3])
            end
        else
            pcall(icon.SetVertexColor, icon, 1, 1, 1)
        end
    end

    ClearDimmedState(button, state)
end

local function ApplyRangeState(button, outOfRange, blizzardJustUpdated)
    if IsForbiddenButton(button) then return end

    local state = buttonStates[button]

    if not IsEnabled() then
        if state and state.dimmed then
            if blizzardJustUpdated then
                ClearDimmedState(button, state)
            else
                RestoreBlizzardColor(button)
            end
        end
        return
    end

    local icon = GetButtonIcon(button)
    if not icon then return end

    if outOfRange then
        state = state or GetButtonState(button)
        if blizzardJustUpdated or not state.dimmed then
            CaptureBlizzardColor(icon, state)
        end
        pcall(icon.SetVertexColor, icon, RANGE_TINT, RANGE_TINT, RANGE_TINT)
        state.dimmed = true
        tintedButtons[button] = true
        button._Carpenter_RangeDimmed = true
    elseif state and state.dimmed then
        if blizzardJustUpdated then
            ClearDimmedState(button, state)
        else
            RestoreBlizzardColor(button)
        end
    end
end

local function RestoreTintedButtons()
    local buttons = {}
    for button in pairs(tintedButtons) do
        buttons[#buttons + 1] = button
    end
    for _, button in ipairs(buttons) do
        RestoreBlizzardColor(button)
    end
end

local function NormalizeRangeValue(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value ~= 0 end
    return nil
end

local function CacheEventRangeState(button, checksRange, inRange)
    local state = GetButtonState(button)
    local action = button.action
    local checks = NormalizeRangeValue(checksRange)
    local range = NormalizeRangeValue(inRange)

    state.rangeAction = action
    state.checksRange = action ~= nil and action ~= 0 and checks == true and range ~= nil
    state.outOfRange = state.checksRange and range == false
    return state.outOfRange
end

local function CacheLegacyRangeState(button)
    local state = GetButtonState(button)
    local action = button.action
    local range

    if action and action ~= 0 and IsActionInRange then
        local ok, value = pcall(IsActionInRange, action)
        if ok then range = NormalizeRangeValue(value) end
    end

    state.rangeAction = action
    state.checksRange = action ~= nil and action ~= 0 and range ~= nil
    state.outOfRange = state.checksRange and range == false
    return state.outOfRange
end

local function GetCachedOutOfRange(button)
    local state = buttonStates[button]
    if not state or state.rangeAction ~= button.action then return false end
    return state.checksRange == true and state.outOfRange == true
end

local rangeIndicatorHooked = false
local onUpdateHooked = false
local buttonRegistryHooked = false
local usableMixinHooked = false
local usableGlobalHooked = false
local hookedButtons = setmetatable({}, { __mode = "k" })

local function SafeHookGlobal(name, handler)
    if Carpenter and Carpenter.SafeHook then
        return Carpenter:SafeHook(name, handler)
    end
    if not hooksecurefunc or type(_G[name]) ~= "function" then return false end
    return pcall(hooksecurefunc, name, handler) == true
end

local function SafeHookMethod(target, method, handler)
    if Carpenter and Carpenter.SafeHook then
        return Carpenter:SafeHook(target, method, handler)
    end
    if not hooksecurefunc or type(target) ~= "table" or type(target[method]) ~= "function" then return false end
    return pcall(hooksecurefunc, target, method, handler) == true
end

local function HandleRangeUpdate(button, checksRange, inRange)
    if IsForbiddenButton(button) then return end
    if IsEnabled() or tintedButtons[button] then
        ApplyRangeState(button, CacheEventRangeState(button, checksRange, inRange), false)
    end
end

local function HandleLegacyRangeUpdate(button)
    if IsForbiddenButton(button) then return end
    if IsEnabled() or tintedButtons[button] then
        ApplyRangeState(button, CacheLegacyRangeState(button), false)
    end
end

local function HandleUsabilityUpdate(button)
    if IsForbiddenButton(button) then return end
    if IsEnabled() or tintedButtons[button] then
        -- Blizzard has just repainted the icon. Reapply only the authoritative
        -- range state cached by its range event; querying IsActionInRange here
        -- can return stale or unavailable data on current clients.
        ApplyRangeState(button, GetCachedOutOfRange(button), true)
    end
end

local function HookButtonUsability(button)
    if IsForbiddenButton(button) or hookedButtons[button] then return false end
    if not SafeHookMethod(button, "UpdateUsable", HandleUsabilityUpdate) then return false end
    hookedButtons[button] = true
    return true
end

local function HookActionButtonUsability()
    local registry = _G.ActionBarButtonEventsFrame
    if type(registry) == "table" then
        if type(registry.ForEachFrame) == "function" then
            pcall(registry.ForEachFrame, registry, HookButtonUsability)
        elseif type(registry.frames) == "table" then
            for _, button in pairs(registry.frames) do
                HookButtonUsability(button)
            end
        end

        if not buttonRegistryHooked then
            buttonRegistryHooked = SafeHookMethod(registry, "RegisterFrame", function(_, button)
                HookButtonUsability(button)
            end)
        end
    end

    -- Older clients without the button registry use a shared updater.
    if not buttonRegistryHooked and not usableMixinHooked and not usableGlobalHooked and _G.ActionBarActionButtonMixin then
        usableMixinHooked = SafeHookMethod(_G.ActionBarActionButtonMixin, "UpdateUsable", HandleUsabilityUpdate)
    end

    if not buttonRegistryHooked and not usableMixinHooked and not usableGlobalHooked then
        usableGlobalHooked = SafeHookGlobal("ActionButton_UpdateUsable", HandleUsabilityUpdate)
    end
end

local function HookRangeUpdates()
    if not rangeIndicatorHooked then
        rangeIndicatorHooked = SafeHookGlobal("ActionButton_UpdateRangeIndicator", HandleRangeUpdate)
    end

    if not rangeIndicatorHooked and not onUpdateHooked then
        onUpdateHooked = SafeHookGlobal("ActionButton_OnUpdate", function(button)
            -- This hook cannot be removed if the modern function loads later,
            -- so make it inert once the event-driven path is available.
            if not rangeIndicatorHooked then
                HandleLegacyRangeUpdate(button)
            end
        end)
    end

    HookActionButtonUsability()
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        HookRangeUpdates()
    end
end)

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    HookRangeUpdates()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    RestoreTintedButtons()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("actionBarRangeEnabled", feature)
end
