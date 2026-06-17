--[[ Carpenter - Explorer Mode ]]
-- Slowly fades the main HUD while out of combat, leaving the minimap alone.

local FEATURE_KEY = "explorerModeEnabled"
local EXPLORING_ALPHA = 0
local VISIBLE_ALPHA = 1
local FADE_OUT_SECONDS = 2.8
local HOVER_FADE_IN_SECONDS = 0.18
local HOVER_FADE_OUT_SECONDS = 0.45
local HOVER_UPDATE_INTERVAL = 0.15
local CHAT_REPAIR_VERSION = 1

local frame = CreateFrame("Frame")
local managedFrames = {}
local managedAlphas = {}
local frameTargets = {}
local activeFades = {}
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

local unitFramePieces = {
    "PlayerFrameHealthBar",
    "PlayerFrameManaBar",
    "PlayerFrameAlternateManaBar",
    "PlayerFrameTexture",
    "PlayerName",
    "PlayerLevelText",
    "PlayerPVPIcon",
    "PlayerLeaderIcon",
    "PlayerMasterIcon",
    "TargetFrameHealthBar",
    "TargetFrameManaBar",
    "TargetFrameTextureFrame",
    "TargetFrameNameBackground",
    "TargetFrameTextureFrameName",
    "TargetFrameTextureFrameLevelText",
    "TargetFrameTextureFramePVPIcon",
    "FocusFrameHealthBar",
    "FocusFrameManaBar",
    "FocusFrameTextureFrame",
    "FocusFrameNameBackground",
    "FocusFrameTextureFrameName",
    "FocusFrameTextureFrameLevelText",
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

local function IsManagedAncestorHovered(frameObject)
    if not frameObject or not frameObject.GetParent then
        return false
    end

    local ok, parent = pcall(frameObject.GetParent, frameObject)
    while ok and parent do
        if managedFrames[parent] and IsMouseOverFrame(parent) then
            return true
        end
        if not parent.GetParent then
            return false
        end
        ok, parent = pcall(parent.GetParent, parent)
    end

    return false
end

local function AddManagedFrame(frameObject)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha then
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
        managedFrames[frameObject] = true
        managedAlphas[frameObject] = alpha or VISIBLE_ALPHA
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
    if not object or managedAlphas[object] or not object.GetAlpha then
        return
    end

    local ok, alpha = pcall(object.GetAlpha, object)
    managedAlphas[object] = ok and alpha or VISIBLE_ALPHA
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
    if targetAlpha == VISIBLE_ALPHA then
        return managedAlphas[object] or VISIBLE_ALPHA
    end
    return math.min(managedAlphas[object] or VISIBLE_ALPHA, targetAlpha)
end

local function CollectAlphaTargets(root, starts, targets, targetAlpha, depth)
    if not root or depth > 4 then
        return
    end
    if IsForbiddenFrame(root) then
        return
    end

    if root.SetAlpha then
        RememberAlpha(root)
        local ok, alpha = true, targetAlpha
        if root.GetAlpha then
            ok, alpha = pcall(root.GetAlpha, root)
        end
        starts[root] = ok and alpha or TargetAlphaForObject(root, targetAlpha)
        targets[root] = TargetAlphaForObject(root, targetAlpha)
    end

    if root.GetRegions then
        for i = 1, select("#", root:GetRegions()) do
            local region = select(i, root:GetRegions())
            if region and region.SetAlpha then
                RememberAlpha(region)
                local ok, alpha = true, targetAlpha
                if region.GetAlpha then
                    ok, alpha = pcall(region.GetAlpha, region)
                end
                starts[region] = ok and alpha or TargetAlphaForObject(region, targetAlpha)
                targets[region] = TargetAlphaForObject(region, targetAlpha)
            end
        end
    end

    if root.GetChildren then
        for i = 1, root:GetNumChildren() do
            CollectAlphaTargets(select(i, root:GetChildren()), starts, targets, targetAlpha, depth + 1)
        end
    end
end

local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
fadeDriver:SetScript("OnUpdate", function(self, elapsed)
    local hasActiveFade = false

    for root, fade in pairs(activeFades) do
        fade.elapsed = fade.elapsed + elapsed
        local progress = fade.duration > 0 and math.min(fade.elapsed / fade.duration, 1) or 1

        for object, startAlpha in pairs(fade.starts) do
            local targetAlpha = fade.targets[object] or VISIBLE_ALPHA
            SafeSetAlpha(object, startAlpha + ((targetAlpha - startAlpha) * progress))
        end

        if progress >= 1 then
            activeFades[root] = nil
        else
            hasActiveFade = true
        end
    end

    if not hasActiveFade then
        self:Hide()
    end
end)

local function FadeFrame(frameObject, targetAlpha, duration)
    if not frameObject or IsForbiddenFrame(frameObject) or not frameObject.SetAlpha then
        return
    end

    if frameTargets[frameObject] == targetAlpha then
        return
    end
    frameTargets[frameObject] = targetAlpha

    if UIFrameFadeRemoveFrame and not IsInCombat() then
        pcall(UIFrameFadeRemoveFrame, frameObject)
    end

    local starts = {}
    local targets = {}
    CollectAlphaTargets(frameObject, starts, targets, targetAlpha, 0)

    if duration == nil or duration <= 0 then
        activeFades[frameObject] = nil
        for object, alpha in pairs(targets) do
            SafeSetAlpha(object, alpha)
        end
        return
    end

    activeFades[frameObject] = {
        elapsed = 0,
        duration = duration,
        starts = starts,
        targets = targets,
    }
    fadeDriver:Show()
end

local hoverDriver = CreateFrame("Frame")
hoverDriver:Hide()
hoverDriver:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled() or IsInCombat() then
        self:Hide()
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < HOVER_UPDATE_INTERVAL then
        return
    end
    self.elapsed = 0

    for frameObject in pairs(managedFrames) do
        if IsMouseOverFrame(frameObject) or IsManagedAncestorHovered(frameObject) then
            FadeFrame(frameObject, VISIBLE_ALPHA, HOVER_FADE_IN_SECONDS)
        else
            FadeFrame(frameObject, EXPLORING_ALPHA, HOVER_FADE_OUT_SECONDS)
        end
    end
end)

local function ApplyTargetAlpha(targetAlpha, duration)
    RefreshManagedFrames()
    for frameObject in pairs(managedFrames) do
        FadeFrame(frameObject, targetAlpha, duration)
    end
end

local function CancelScheduledRefresh()
    if Carpenter and Carpenter.Deferred then
        Carpenter.Deferred["ExplorerMode:refresh"] = nil
    end
end

local function RestoreManagedFrames()
    activeFades = {}
    fadeDriver:Hide()
    hoverDriver:Hide()

    for object, originalAlpha in pairs(managedAlphas) do
        SafeSetAlpha(object, originalAlpha or VISIBLE_ALPHA)
    end
    managedFrames = {}
    managedAlphas = {}
    frameTargets = {}
end

local function ScheduleRefresh()
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("ExplorerMode:refresh", { 0.2, 1.0 }, function()
            if IsEnabled() and not IsInCombat() then
                ApplyTargetAlpha(EXPLORING_ALPHA, FADE_OUT_SECONDS)
            end
        end)
    end
end

local function ApplyExplorerMode(forceVisible)
    if not IsEnabled() then
        RestoreManagedFrames()
        return
    end

    if forceVisible then
        CancelScheduledRefresh()
        activeFades = {}
        fadeDriver:Hide()
        hoverDriver:Hide()
        ApplyTargetAlpha(VISIBLE_ALPHA, 0)
        return
    end

    local inCombat = IsInCombat()
    if inCombat then
        CancelScheduledRefresh()
        activeFades = {}
        fadeDriver:Hide()
        hoverDriver:Hide()
        ApplyTargetAlpha(VISIBLE_ALPHA, 0)
    else
        ApplyTargetAlpha(EXPLORING_ALPHA, FADE_OUT_SECONDS)
        hoverDriver:Show()
        ScheduleRefresh()
    end
end

frame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
        return
    end
    ApplyExplorerMode(event == "PLAYER_REGEN_DISABLED")
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
