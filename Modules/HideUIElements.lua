--[[ Carpenter - HideUIElements ]]
local f = CreateFrame("Frame")

-- Register events to catch the bars during login, spec changes, or stance swaps
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

local STANCE_BAR_FRAMES = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" }
local hiddenStanceFrames = setmetatable({}, { __mode = "k" })
local hiddenHotkeys = setmetatable({}, { __mode = "k" })
local hiddenMacroNames = setmetatable({}, { __mode = "k" })
local secureCallFunction = securecallfunction

local function IsStanceBarEnabled()
    return Carpenter and Carpenter:IsEnabled("hideStanceBarEnabled")
end

local function IsKeybindsEnabled()
    return Carpenter and Carpenter:IsEnabled("hideKeybindsEnabled")
end

local function IsMacroNamesEnabled()
    return Carpenter and Carpenter:IsEnabled("hideMacroNamesEnabled")
end

local function CanSecurelyStyleActionButtonText()
    local client = Carpenter and Carpenter.Client
    return client and client.isRetail and type(secureCallFunction) == "function"
end

local function SetActionButtonTextAlpha(region, alpha)
    local setAlpha = region and region.SetAlpha
    if type(setAlpha) ~= "function" then return false end

    if CanSecurelyStyleActionButtonText() then
        -- FontString widget methods are provided through the UI object's
        -- metatable. securecallmethod uses raw lookup and therefore cannot find
        -- SetAlpha here; pass the resolved native method to the secure barrier.
        secureCallFunction(setAlpha, region, alpha)
    else
        setAlpha(region, alpha)
    end
    return true
end

local function ApplyStanceBarHide()
    if not IsStanceBarEnabled() then return end
    if InCombatLockdown() then return end

    for _, name in ipairs(STANCE_BAR_FRAMES) do
        local frame = _G[name]
        if frame and frame.SetAlpha then
            if hiddenStanceFrames[frame] == nil then
                hiddenStanceFrames[frame] = frame.GetAlpha and frame:GetAlpha() or 1
            end
            -- Stance bars are protected and share Blizzard's combat visibility
            -- controller with the other action bars. Parenting or hiding one of
            -- them taints that controller; alpha is visual-only and leaves its
            -- secure ownership and visibility state intact.
            frame:SetAlpha(0)
        end
    end
end

local function RestoreStanceBar()
    if IsStanceBarEnabled() then return end
    if InCombatLockdown() then return end

    for frame, originalAlpha in pairs(hiddenStanceFrames) do
        if frame and frame.SetAlpha then
            frame:SetAlpha(originalAlpha or 1)
        end
        hiddenStanceFrames[frame] = nil
    end
end

local function UpdateActionBars()
    -- Ensure database is initialized
    if not CarpenterDB then return end

    -- Blizzard updates protected action buttons while combat state changes. Even
    -- visual writes to their child regions from that call path can taint the
    -- remaining secure update and make entire bars fail to show. The regen event
    -- below reapplies pending visual changes once combat ends.
    if InCombatLockdown and InCombatLockdown() then return end

    local hideStanceBar = IsStanceBarEnabled()
    local hideKeybinds = IsKeybindsEnabled()
    local hideMacroNames = IsMacroNamesEnabled()
    local hasModifiedFrames = next(hiddenStanceFrames) ~= nil or next(hiddenHotkeys) ~= nil or next(hiddenMacroNames) ~= nil

    -- Do not touch protected action-button descendants when every related
    -- setting is off. Forever can otherwise mark Blizzard's cooldown path as
    -- tainted even though Carpenter has no active action-bar feature.
    if not hideStanceBar and not hideKeybinds and not hideMacroNames and not hasModifiedFrames then
        return
    end

    -- 1. STANCE BAR LOGIC (combat-safe: no protected frame changes during combat)
    if hideStanceBar then
        ApplyStanceBarHide()
    else
        RestoreStanceBar()
    end

    -- Retail-style restricted clients associate action-button child regions with
    -- the protected button's execution context. Use securecallfunction as a secure
    -- barrier for the visual write; never fall back to a normal SetAlpha call on
    -- those clients because it can taint secret cooldown updates.
    if Carpenter and Carpenter.Client and Carpenter.Client.isRetail
        and not CanSecurelyStyleActionButtonText()
    then
        return
    end

    -- 2. MACRO NAMES & KEYBIND TEXT LOGIC
    for i = 1, 12 do
        local buttons = {
            _G["ActionButton" .. i],
            _G["MultiBarBottomLeftButton" .. i],
            _G["MultiBarBottomRightButton" .. i],
            _G["MultiBarLeftButton" .. i],
            _G["MultiBarRightButton" .. i],
            _G["MultiBar5Button" .. i],
            _G["MultiBar6Button" .. i],
            _G["MultiBar7Button" .. i],
        }

        for _, btn in ipairs(buttons) do
            if btn then
                local hotkey = _G[btn:GetName() .. "HotKey"]
                local name = _G[btn:GetName() .. "Name"]

                -- Handle Keybinds (HotKey)
                if hotkey then
                    if hideKeybinds then
                        SetActionButtonTextAlpha(hotkey, 0)
                        hiddenHotkeys[hotkey] = true
                    elseif hiddenHotkeys[hotkey] then
                        SetActionButtonTextAlpha(hotkey, 1)
                        hiddenHotkeys[hotkey] = nil
                    end
                end

                -- Handle Macro Names (Name)
                if name then
                    if hideMacroNames then
                        SetActionButtonTextAlpha(name, 0)
                        hiddenMacroNames[name] = true
                    elseif hiddenMacroNames[name] then
                        SetActionButtonTextAlpha(name, 1)
                        hiddenMacroNames[name] = nil
                    end
                end
            end
        end
    end
end

f:SetScript("OnEvent", function()
    UpdateActionBars()
end)
