--[[ Carpenter - ActionBarRange ]]
-- Uses Blizzard's own range checks to slightly dim action buttons when
-- they are out of range (too close or too far), matching the default
-- "not usable" look and working with macros.

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("actionBarRangeEnabled")
end

local function GetButtonIcon(button)
    if not button then return nil end
    if button.icon then return button.icon end
    local name = button:GetName()
    if not name then return nil end
    return _G[name .. "Icon"]
end

local function RestoreDefaultColor(button)
    local icon = GetButtonIcon(button)
    if not icon then return end
    icon:SetVertexColor(1, 1, 1)
    button._Carpenter_RangeDimmed = false
end

local function ApplyRangeState(button, outOfRange)
    if not button or button:IsForbidden() then return end

    -- If the feature is disabled, always restore Blizzard's default.
    if not IsEnabled() then
        if button._Carpenter_RangeDimmed then
            RestoreDefaultColor(button)
        end
        return
    end

    local icon = GetButtonIcon(button)
    if not icon then return end

    if outOfRange then
        -- Slight dark tint, similar to Blizzard's "not usable".
        icon:SetVertexColor(0.4, 0.4, 0.4)
        button._Carpenter_RangeDimmed = true
    else
        -- Let Blizzard handle other states; we just clear our override.
        if button._Carpenter_RangeDimmed then
            RestoreDefaultColor(button)
        end
    end
end

local function ComputeOutOfRangeFromAction(button, checksRange, inRange)
    if not button or button:IsForbidden() then return false end
    if not button.action or button.action == 0 then return false end

    -- If checksRange is explicitly false, this action does not use range.
    if checksRange == false then
        return false
    end

    local value = inRange

    -- On some clients, ActionButton_UpdateRangeIndicator doesn't provide
    -- inRange; fall back to IsActionInRange.
    if value == nil then
        value = IsActionInRange(button.action)
    end

    if value == nil then
        return false
    end

    if type(value) == "boolean" then
        return (value == false)
    else
        -- Numeric form: 1 in range, 0 out of range.
        return (value == 0)
    end
end

local hooked = false

local function SafeHookGlobal(name, handler)
    if Carpenter and Carpenter.SafeHook then
        return Carpenter:SafeHook(name, handler)
    end
    if not hooksecurefunc or type(_G[name]) ~= "function" then return false end
    return pcall(hooksecurefunc, name, handler) == true
end

local function HookRangeUpdates()
    if hooked then return end

    -- Modern path: hook the Blizzard range updater (Dragonflight / 2.5.5 style).
    hooked = SafeHookGlobal("ActionButton_UpdateRangeIndicator", function(self, checksRange, inRange)
        if not self or self:IsForbidden() then return end

        local outOfRange = ComputeOutOfRangeFromAction(self, checksRange, inRange)

        -- Only touch buttons while the feature is enabled or if we need
        -- to clean up a previous override.
        if IsEnabled() or self._Carpenter_RangeDimmed then
            ApplyRangeState(self, outOfRange)
        end
    end)
    if hooked then return end

    -- Classic fallback: rely on ActionButton_OnUpdate + IsActionInRange.
    hooked = SafeHookGlobal("ActionButton_OnUpdate", function(self, elapsed)
        if not self or self:IsForbidden() then return end
        if not self.action or self.action == 0 then return end

        local inRange = IsActionInRange(self.action)
        local outOfRange = false

        if inRange ~= nil then
            if type(inRange) == "boolean" then
                outOfRange = (inRange == false)
            else
                outOfRange = (inRange == 0)
            end
        end

        if IsEnabled() or self._Carpenter_RangeDimmed then
            ApplyRangeState(self, outOfRange)
        end
    end)

    -- Neither global is present yet, so leave `hooked` false and try again on
    -- the next login or zone in rather than giving up for the session.
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
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("actionBarRangeEnabled", feature)
end
