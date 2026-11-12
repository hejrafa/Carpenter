--[[ Carpenter - Forever target level ]]
-- For a unit too far above you, WoW Forever's target frame hides the level
-- number and shows a skull. Its battle pet check runs right after and shows
-- the number again for every unit that isn't a battle pet, still holding the
-- last target's level, so the skull came with a stale, wrong level. Retail's
-- check leaves the number alone. After each battle pet check the number is
-- hidden again wherever the skull shows; the next normal target shows it as
-- usual. Only the number's visibility changes, so no Blizzard code runs here.

local function IsForever()
    return Carpenter and Carpenter.Client and Carpenter.Client.isForever
end

local MAX_BOSS_FRAMES_CHECKED = 8
local hooked = setmetatable({}, { __mode = "k" })

local function GetLevelRegions(frame)
    local content = frame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    local contextual = content and content.TargetFrameContentContextual
    return main and main.LevelText, contextual and contextual.HighLevelTexture
end

local function HideLevelBehindSkull(frame)
    local levelText, skull = GetLevelRegions(frame)
    if not (levelText and skull) then return end
    if skull:IsShown() and levelText:IsShown() then
        levelText:Hide()
    end
end

local function OnBattlePetChecked(frame)
    pcall(HideLevelBehindSkull, frame)
end

local function HookFrame(frame)
    if not frame or hooked[frame] then return end
    local levelText, skull = GetLevelRegions(frame)
    if not (levelText and skull) then return end
    if Carpenter:SafeHook(frame, "CheckBattlePet", OnBattlePetChecked) then
        hooked[frame] = true
        OnBattlePetChecked(frame)
    end
end

local function HookFrames()
    HookFrame(_G.TargetFrame)
    HookFrame(_G.FocusFrame)
    for index = 1, MAX_BOSS_FRAMES_CHECKED do
        HookFrame(_G["Boss" .. index .. "TargetFrame"])
    end
end

if IsForever() then
    HookFrames()
    -- Frames that don't exist yet at load get their hook at login.
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        HookFrames()
    end)
end
