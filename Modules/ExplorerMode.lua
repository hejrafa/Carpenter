--[[ Carpenter - Explorer Mode ]]
-- Slowly fades the main HUD while out of combat, leaving the minimap alone.

local FEATURE_KEY = "explorerModeEnabled"
local EXPLORING_ALPHA = 0.18
local VISIBLE_ALPHA = 1
local FADE_OUT_SECONDS = 2.8
local FADE_IN_SECONDS = 0.35
local CHAT_REPAIR_VERSION = 1

local frame = CreateFrame("Frame")
local managedFrames = {}
local IsShownFrame
local registeredEvents = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "QUEST_WATCH_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
}

local frameNames = {
    -- Unit frames
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "FocusFrame",
    "FocusFrameToT",
    "PartyFrame",
    "CompactPartyFrame",
    "CompactRaidFrameContainer",
    -- Action bars and buttons
    "MainMenuBar",
    "MainMenuBarArtFrame",
    "MainMenuBarVehicleLeaveButton",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "StanceBar",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PetActionBarFrame",
    "PossessBarFrame",
    "OverrideActionBar",
    "ExtraActionBarFrame",
    "ZoneAbilityFrame",
    -- Bottom utility clusters
    "MicroButtonAndBagsBar",
    "MicroMenuContainer",
    "BagsBar",
    "BagBarExpandToggle",
    "MainMenuBarBackpackButton",
    "KeyRingButton",
    "KeyringButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
    "MainMenuExpBar",
    "ReputationWatchBar",
    "ArtifactWatchBar",
    "HonorWatchBar",
    -- Quest and watch frames
    "QuestWatchFrame",
    "WatchFrame",
    "ObjectiveTrackerFrame",
    -- Player buffs, casting, and status HUD
    "BuffFrame",
    "TemporaryEnchantFrame",
    "DebuffFrame",
    "PlayerBuffFrame",
    "CastingBarFrame",
    "DurabilityFrame",
    "VehicleSeatIndicator",
}

local repeatedFramePrefixes = {
    { prefix = "PartyMemberFrame", suffix = "", count = 4 },
    { prefix = "PartyMemberFrame", suffix = "PetFrame", count = 4 },
    { prefix = "Boss", suffix = "TargetFrame", count = 8 },
    { prefix = "ArenaEnemyFrame", suffix = "", count = 5 },
}

local microButtons = {
    "MainMenuBarPerformanceBar",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "ProfessionMicroButton",
    "QuestLogMicroButton",
    "AchievementMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "PVPMicroButton",
    "LFGMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
}

local function NormalizeChatWindowName(name)
    return tostring(name or ""):lower():gsub("%s+", "")
end

local function IsDefaultChatWindowName(index, name)
    local normalizedName = NormalizeChatWindowName(name)
    if normalizedName == "" or normalizedName == tostring(index) then
        return true
    end

    local defaults = {
        "ChatFrame" .. index,
        "Chat " .. index,
        "Window " .. index,
        "Chat Window " .. index,
        _G["CHAT_WINDOW_" .. index],
    }

    local function AddFormattedDefault(template)
        if not template then return end
        local ok, formattedName = pcall(string.format, template, index)
        if ok then
            defaults[#defaults + 1] = formattedName
        end
    end

    AddFormattedDefault(CHAT_NAME_TEMPLATE)
    AddFormattedDefault(CHAT_WINDOW_NAME_TEMPLATE)

    for _, defaultName in ipairs(defaults) do
        if defaultName and normalizedName == NormalizeChatWindowName(defaultName) then
            return true
        end
    end

    return false
end

local function GetChatWindowShown(index)
    if GetChatWindowInfo then
        local ok, name, fontSize, r, g, b, alpha, shown = pcall(GetChatWindowInfo, index)
        if ok then
            return shown == true
        end
    end

    local chatFrame = _G["ChatFrame" .. index]
    return chatFrame and IsShownFrame(chatFrame)
end

local function GetChatWindowName(index)
    if GetChatWindowInfo then
        local ok, name = pcall(GetChatWindowInfo, index)
        if ok then
            return name
        end
    end
    return nil
end

local function CloseChatWindow(index)
    local chatFrame = _G["ChatFrame" .. index]

    if FCF_Close and chatFrame then
        pcall(FCF_Close, chatFrame)
    end

    if SetChatWindowShown then
        pcall(SetChatWindowShown, index, false)
    end

    if chatFrame and chatFrame.Hide then
        pcall(chatFrame.Hide, chatFrame)
    end

    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab and tab.Hide then
        pcall(tab.Hide, tab)
    end
end

local function RepairAccidentalChatWindows()
    if not CarpenterDB or CarpenterDB.explorerModeChatWindowRepairVersion == CHAT_REPAIR_VERSION then
        return
    end

    if Carpenter and Carpenter.Client and Carpenter.Client.isClassic then
        for index = 4, 10 do
            if GetChatWindowShown(index) and IsDefaultChatWindowName(index, GetChatWindowName(index)) then
                CloseChatWindow(index)
            end
        end
    end

    CarpenterDB.explorerModeChatWindowRepairVersion = CHAT_REPAIR_VERSION
end

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

local function IsForbiddenFrame(frameObject)
    if not frameObject or not frameObject.IsForbidden then
        return false
    end
    local ok, forbidden = pcall(frameObject.IsForbidden, frameObject)
    return ok and forbidden
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

function IsShownFrame(frameObject)
    if not frameObject or not frameObject.IsShown then
        return true
    end
    local ok, shown = pcall(frameObject.IsShown, frameObject)
    return ok and shown
end

local function AddManagedFrame(frameObject)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha or not IsShownFrame(frameObject) then
        return
    end

    if not managedFrames[frameObject] then
        local ok, alpha = true, VISIBLE_ALPHA
        if frameObject.GetAlpha then
            ok, alpha = pcall(frameObject.GetAlpha, frameObject)
        end
        if not ok then
            alpha = VISIBLE_ALPHA
        end
        managedFrames[frameObject] = alpha or VISIBLE_ALPHA
    end
end

local function AddFrameByName(name)
    AddManagedFrame(_G[name])
end

local function RefreshManagedFrames()
    for _, name in ipairs(frameNames) do
        AddFrameByName(name)
    end

    for _, name in ipairs(microButtons) do
        AddFrameByName(name)
    end

    for _, group in ipairs(repeatedFramePrefixes) do
        for i = 1, group.count do
            AddFrameByName(group.prefix .. i .. group.suffix)
        end
    end
end

local function SafeSetAlpha(frameObject, alpha)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha then
        return
    end
    pcall(frameObject.SetAlpha, frameObject, alpha)
end

local function FadeFrame(frameObject, targetAlpha, duration)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha then
        return
    end

    if not IsShownFrame(frameObject) then
        SafeSetAlpha(frameObject, targetAlpha)
        return
    end

    if UIFrameFadeRemoveFrame then
        pcall(UIFrameFadeRemoveFrame, frameObject)
    end

    if UIFrameFadeIn then
        local ok, currentAlpha = true, targetAlpha
        if frameObject.GetAlpha then
            ok, currentAlpha = pcall(frameObject.GetAlpha, frameObject)
        end
        if not ok then
            currentAlpha = targetAlpha
        end
        pcall(UIFrameFadeIn, frameObject, duration, currentAlpha or targetAlpha, targetAlpha)
    else
        SafeSetAlpha(frameObject, targetAlpha)
    end
end

local function ApplyTargetAlpha(targetAlpha, duration)
    RefreshManagedFrames()
    for frameObject, originalAlpha in pairs(managedFrames) do
        local alpha = targetAlpha == VISIBLE_ALPHA and originalAlpha or math.min(originalAlpha or VISIBLE_ALPHA, targetAlpha)
        FadeFrame(frameObject, alpha, duration)
    end
end

local function RestoreManagedFrames()
    for frameObject, originalAlpha in pairs(managedFrames) do
        if UIFrameFadeRemoveFrame then
            pcall(UIFrameFadeRemoveFrame, frameObject)
        end
        SafeSetAlpha(frameObject, originalAlpha or VISIBLE_ALPHA)
    end
    managedFrames = {}
end

local function ScheduleRefresh()
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("ExplorerMode:refresh", { 0.2, 1.0 }, function()
            if IsEnabled() then
                ApplyTargetAlpha(IsInCombat() and VISIBLE_ALPHA or EXPLORING_ALPHA, IsInCombat() and FADE_IN_SECONDS or FADE_OUT_SECONDS)
            end
        end)
    end
end

local function ApplyExplorerMode()
    if not IsEnabled() then
        RestoreManagedFrames()
        return
    end

    local inCombat = IsInCombat()
    ApplyTargetAlpha(inCombat and VISIBLE_ALPHA or EXPLORING_ALPHA, inCombat and FADE_IN_SECONDS or FADE_OUT_SECONDS)
    ScheduleRefresh()
end

frame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end
    ApplyExplorerMode()
end)

_G.Carpenter_ApplyExplorerMode = ApplyExplorerMode
_G.Carpenter_RepairExplorerModeChatWindows = RepairAccidentalChatWindows

local repairFrame = CreateFrame("Frame")
repairFrame:RegisterEvent("PLAYER_LOGIN")
repairFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if Carpenter and Carpenter.After then
        Carpenter:After(2, RepairAccidentalChatWindows)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(2, RepairAccidentalChatWindows)
    else
        RepairAccidentalChatWindows()
    end
end)

local feature = {}

function feature:Enable()
    for _, event in ipairs(registeredEvents) do
        if Carpenter and Carpenter.SafeRegisterEvent then
            Carpenter:SafeRegisterEvent(frame, event)
        else
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    ApplyExplorerMode()
end

function feature:Disable()
    frame:UnregisterAllEvents()
    RestoreManagedFrames()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
