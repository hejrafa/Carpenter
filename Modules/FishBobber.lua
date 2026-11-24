--[[ Carpenter - Fish macro: press it again to hook the bobber ]]
-- While the Fish macro's line is out, every key bound to an action button
-- holding the macro does the game's Interact with Target instead. The game's
-- soft targeting picks the bobber, so the same key casts the line and then
-- hooks the fish, without clicking the bobber.
--
-- The soft-target settings are raised only while the line is out: as
-- temporary values where the client has them (WoW Forever and Retail), so
-- nothing is saved, and on Classic set and put back when the line comes in.
-- Bindings can't change in combat, so a fight hands the keys back to the
-- macro first.
local _, ns = ...
ns.Private = ns.Private or {}

local RPMacros = ns.Private.RPMacros or {}
ns.Private.RPMacros = RPMacros

local Secret = Carpenter and Carpenter.Secret or {}
local ReadableString = Secret.ReadableString or function(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

local FishBobber = {}
RPMacros.FishBobber = FishBobber

local MACRO_NAME = "Fish"
local INTERACT_BINDING = "INTERACTTARGET"

-- The interact key needs the keyboard flag (Enum.SoftTargetEnableFlags: 2 is
-- keyboard and mouse, 3 any) and enough reach for a cast, which lands up to
-- about 20 yards out. Values already that high are left alone.
local SOFT_TARGET_CVARS = {
    { name = "SoftTargetInteract", value = 3 },
    { name = "SoftTargetInteractRange", value = 30 },
}

-- The default action bars: button names and their key binding commands.
-- Retail and Forever buttons also carry the command as bindingAction.
local BARS = {
    { "ActionButton", "ACTIONBUTTON" },
    { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
    { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" },
    { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" },
    { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" },
    { "MultiBar5Button", "MULTIACTIONBAR5BUTTON" },
    { "MultiBar6Button", "MULTIACTIONBAR6BUTTON" },
    { "MultiBar7Button", "MULTIACTIONBAR7BUTTON" },
}
local BUTTONS_PER_BAR = 12

local function CallGame(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, first, second = pcall(func, ...)
    if ok then return first, second end
    return nil
end

local function ActionAPI(name)
    return (C_ActionBar and C_ActionBar[name]) or _G[name]
end

-- True when the button's current action is the Fish macro.
local function ShowsFishMacro(button)
    local action = type(button) == "table" and button.action
    if type(action) ~= "number" or action <= 0 then return false end
    -- Global first: Forever's own action buttons call the global.
    local actionType = ReadableString(CallGame(_G.GetActionInfo or ActionAPI("GetActionInfo"), action))
    if actionType ~= "macro" then return false end
    return ReadableString(CallGame(ActionAPI("GetActionText"), action)) == MACRO_NAME
end

-- Every key bound to an action button that holds the Fish macro.
function FishBobber.FindKeys()
    local keys, seen = {}, {}
    local function Add(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            if type(key) == "string" and key ~= "" and not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
    end
    if type(GetBindingKey) ~= "function" then return keys end
    for _, bar in ipairs(BARS) do
        for i = 1, BUTTONS_PER_BAR do
            local name = bar[1] .. i
            local button = _G[name]
            if ShowsFishMacro(button) then
                local command = type(button.bindingAction) == "string" and button.bindingAction or (bar[2] .. i)
                Add(GetBindingKey(command))
                Add(GetBindingKey("CLICK " .. name .. ":LeftButton"))
            end
        end
    end
    return keys
end

function FishBobber.IsFishing()
    local fishing = RPMacros.GetFishingName and RPMacros.GetFishingName()
    local channel = ReadableString(CallGame(UnitChannelInfo, "player"))
    return channel ~= nil and channel == fishing
end

-- =========================
-- Soft-target settings
-- =========================
local tempCVars = {}   -- names set as temporary values
local savedCVars = {}  -- name -> value to put back (clients without temporary values)

local function GetCVarValue(name)
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    return CallGame(getCVar, name)
end

local function RaiseSoftTarget()
    local setTemp = C_CVar and C_CVar.SetTempCVar
    local removeTemp = C_CVar and C_CVar.RemoveTempCVar
    local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar
    for _, cvar in ipairs(SOFT_TARGET_CVARS) do
        local current = GetCVarValue(cvar.name)
        local number = tonumber(current)
        if number and number < cvar.value then
            if setTemp and removeTemp then
                if pcall(setTemp, cvar.name, tostring(cvar.value)) then
                    tempCVars[cvar.name] = true
                end
            elseif setCVar and savedCVars[cvar.name] == nil then
                if pcall(setCVar, cvar.name, tostring(cvar.value)) then
                    savedCVars[cvar.name] = current
                end
            end
        end
    end
end

local function RestoreSoftTarget()
    local removeTemp = C_CVar and C_CVar.RemoveTempCVar
    local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar
    for _, cvar in ipairs(SOFT_TARGET_CVARS) do
        local name = cvar.name
        if tempCVars[name] then
            if removeTemp then pcall(removeTemp, name) end
            tempCVars[name] = nil
        end
        if savedCVars[name] ~= nil then
            if setCVar then pcall(setCVar, name, savedCVars[name]) end
            savedCVars[name] = nil
        end
    end
end

-- =========================
-- Key overrides
-- =========================
local owner = CreateFrame and CreateFrame("Frame")
local hooked = false

function FishBobber.IsHooked()
    return hooked
end

function FishBobber.Hook()
    if hooked or not owner or (InCombatLockdown and InCombatLockdown()) then return false end
    if type(SetOverrideBinding) ~= "function" then return false end
    local keys = FishBobber.FindKeys()
    if #keys == 0 then return false end
    for _, key in ipairs(keys) do
        SetOverrideBinding(owner, true, key, INTERACT_BINDING)
    end
    hooked = true
    RaiseSoftTarget()
    return true
end

function FishBobber.Unhook()
    if hooked then
        if InCombatLockdown and InCombatLockdown() then
            -- Combat started before the regen event got here: the keys stay
            -- on the bobber until the fight ends.
            if Carpenter and Carpenter.AfterCombat then
                Carpenter:AfterCombat("FishBobber", FishBobber.Unhook)
            end
            return
        end
        if type(ClearOverrideBindings) == "function" then
            ClearOverrideBindings(owner)
        end
        hooked = false
    end
    RestoreSoftTarget()
end

if owner then
    owner:SetScript("OnEvent", function(_, event)
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            if FishBobber.IsFishing() then FishBobber.Hook() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "PLAYER_REGEN_DISABLED" then
            -- PLAYER_REGEN_DISABLED comes before combat locks bindings.
            FishBobber.Unhook()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if FishBobber.IsFishing() then FishBobber.Hook() end
        elseif event == "PLAYER_LEAVING_WORLD" then
            RestoreSoftTarget()
        end
    end)
    if owner.RegisterUnitEvent then
        owner:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        owner:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    end
    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:RegisterEvent("PLAYER_LEAVING_WORLD")
end
