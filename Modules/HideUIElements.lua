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

local function IsStanceBarEnabled()
    return Carpenter and Carpenter:IsEnabled("hideStanceBarEnabled")
end

local function IsKeybindsEnabled()
    return Carpenter and Carpenter:IsEnabled("hideKeybindsEnabled")
end

local function IsMacroNamesEnabled()
    return Carpenter and Carpenter:IsEnabled("hideMacroNamesEnabled")
end

local function ApplyStanceBarHide()
    if not IsStanceBarEnabled() then return end
    if InCombatLockdown() then return end

    if not CP_HiddenParent then
        CP_HiddenParent = CreateFrame("Frame")
        CP_HiddenParent:Hide()
    end

    for _, name in ipairs(STANCE_BAR_FRAMES) do
        local frame = _G[name]
        if frame then
            if hiddenStanceFrames[frame] == nil then
                hiddenStanceFrames[frame] = frame:GetParent() or UIParent
            end
            frame:UnregisterAllEvents()
            frame:Hide()
            frame:SetParent(CP_HiddenParent)

            if not frame.IsCPHooked then
                hooksecurefunc(frame, "SetShown", function(self, shown)
                    if shown and IsStanceBarEnabled() and not InCombatLockdown() then
                        self:Hide()
                    end
                end)
                hooksecurefunc(frame, "Show", function(self)
                    if IsStanceBarEnabled() and not InCombatLockdown() then
                        self:Hide()
                    end
                end)
                frame.IsCPHooked = true
            end
        end
    end
end

local function RestoreStanceBar()
    if IsStanceBarEnabled() then return end
    if InCombatLockdown() then return end

    for frame, originalParent in pairs(hiddenStanceFrames) do
        if frame then
            frame:SetParent(originalParent or UIParent)
            frame:Show()
        end
        hiddenStanceFrames[frame] = nil
    end
end

local function UpdateActionBars()
    -- Ensure database is initialized
    if not CarpenterDB then return end

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
                        hotkey:SetAlpha(0)
                        hiddenHotkeys[hotkey] = true
                        if not hotkey.IsCPHooked then
                            hooksecurefunc(hotkey, "Show", function(self)
                                if IsKeybindsEnabled() then self:SetAlpha(0) end
                            end)
                            hotkey.IsCPHooked = true
                        end
                    elseif hiddenHotkeys[hotkey] then
                        hotkey:SetAlpha(1)
                        hiddenHotkeys[hotkey] = nil
                    end
                end

                -- Handle Macro Names (Name)
                if name then
                    if hideMacroNames then
                        name:SetAlpha(0)
                        hiddenMacroNames[name] = true
                        if not name.IsCPHooked then
                            hooksecurefunc(name, "Show", function(self)
                                if IsMacroNamesEnabled() then self:SetAlpha(0) end
                            end)
                            name.IsCPHooked = true
                        end
                    elseif hiddenMacroNames[name] then
                        name:SetAlpha(1)
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
