--[[ Carpenter - Classic Ready Check Compatibility ]]
-- Blizzard's Classic ready check can ask GetDifficultyInfo(nil) during outdoor raids.

local function IsClassicClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic
end

local function FallbackDifficultyInfo()
    return "", "none", false, false, false, false, nil, false, 0, 0, false
end

local installed = false

local function InstallDifficultyInfoGuard()
    if installed or not IsClassicClient() or type(_G.GetDifficultyInfo) ~= "function" then
        return
    end

    local originalGetDifficultyInfo = _G.GetDifficultyInfo
    _G.GetDifficultyInfo = function(difficultyID, ...)
        if difficultyID == nil then
            return FallbackDifficultyInfo()
        end
        return originalGetDifficultyInfo(difficultyID, ...)
    end

    installed = true
end

InstallDifficultyInfoGuard()

if not installed then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self)
        InstallDifficultyInfoGuard()
        if installed then
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end
