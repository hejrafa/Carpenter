--[[ Carpenter - Classic Ready Check Compatibility ]]
-- Blizzard's Classic ready check can ask GetDifficultyInfo(nil) during outdoor raids.

local function IsClassicClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic
end

local function FallbackDifficultyInfo()
    return "", "none", false, false, false, false, nil, false, 0, 0, false
end

local installed = false

local function WithDifficultyInfoGuard(callback, ...)
    local originalGetDifficultyInfo = _G.GetDifficultyInfo
    if type(originalGetDifficultyInfo) ~= "function" then
        return callback(...)
    end

    _G.GetDifficultyInfo = function(difficultyID, ...)
        if difficultyID == nil then
            return FallbackDifficultyInfo()
        end
        return originalGetDifficultyInfo(difficultyID, ...)
    end

    local results = { pcall(callback, ...) }
    _G.GetDifficultyInfo = originalGetDifficultyInfo

    local ok = table.remove(results, 1)
    if ok then
        return unpack(results)
    end

    local message = results[1]
    if type(message) ~= "string" or message == "" then
        message = "Blizzard ReadyCheck failed without an error message."
    end
    error(message, 0)
end

local function InstallReadyCheckGuard()
    if installed or not IsClassicClient() or type(_G.ShowReadyCheck) ~= "function" then
        return false
    end

    local originalShowReadyCheck = _G.ShowReadyCheck
    _G.ShowReadyCheck = function(...)
        return WithDifficultyInfoGuard(originalShowReadyCheck, ...)
    end

    installed = true
    return true
end

local function LoadBlizzardReadyCheck()
    if installed or not IsClassicClient() or type(_G.ShowReadyCheck) == "function" then
        return
    end

    if type(UIParentLoadAddOn) == "function" then
        pcall(UIParentLoadAddOn, "Blizzard_ReadyCheck")
    elseif C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ReadyCheck")
    elseif type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_ReadyCheck")
    end
end

local function TryInstallReadyCheckGuard()
    LoadBlizzardReadyCheck()
    return InstallReadyCheckGuard()
end

InstallReadyCheckGuard()

if not installed then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName ~= "Blizzard_ReadyCheck" then
            return
        end
        if TryInstallReadyCheckGuard() then
            self:UnregisterAllEvents()
        end
    end)
end
