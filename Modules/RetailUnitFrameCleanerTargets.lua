--[[ Carpenter - Retail Unit Frame Cleaner targets ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Targets = ns.Private.RetailUnitFrameCleanerTargets or {}
ns.Private.RetailUnitFrameCleanerTargets = Targets

local function AddFrame(frames, frame)
    if frame then
        table.insert(frames, frame)
    end
end

local function GetContextualFrame()
    return PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual
end

function Targets.GetPvPIconFrames()
    local frames = {}
    AddFrame(frames, PlayerPVPIcon)
    AddFrame(frames, TargetFrameTextureFramePVPIcon)
    AddFrame(frames, FocusFrameTextureFramePVPIcon)

    if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual then
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PrestigeBadge)
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PrestigePortrait)
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PVPIcon)
        AddFrame(frames, PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PvpIcon)
    end
    if TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual then
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PrestigeBadge)
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PrestigePortrait)
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PVPIcon)
        AddFrame(frames, TargetFrame.TargetFrameContent.TargetFrameContentContextual.PvpIcon)
    end
    if FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual then
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PrestigeBadge)
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PrestigePortrait)
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PVPIcon)
        AddFrame(frames, FocusFrame.TargetFrameContent.TargetFrameContentContextual.PvpIcon)
    end

    return frames
end

function Targets.GetPowerBarFrames()
    local frames = {}
    AddFrame(frames, ComboFrame)
    AddFrame(frames, ComboPointPlayerFrame)
    AddFrame(frames, RogueComboPointBarFrame)
    AddFrame(frames, ClassNameplateBarFrame)
    AddFrame(frames, RuneFrame)
    AddFrame(frames, PaladinPowerBarFrame)
    AddFrame(frames, WarlockPowerFrame)
    AddFrame(frames, MonkHarmonyBarFrame)
    AddFrame(frames, MageArcaneChargesFrame)
    AddFrame(frames, EssencePlayerFrame)
    AddFrame(frames, TotemFrame)
    AddFrame(frames, DruidComboPointBarFrame)
    AddFrame(frames, PlayerFrameAlternateManaBar)
    return frames
end

function Targets.GetBossFrames()
    local frames = {}
    AddFrame(frames, BossTargetFrameContainer)
    for i = 1, 8 do
        AddFrame(frames, _G["Boss" .. i .. "TargetFrame"])
    end
    return frames
end

function Targets.GetRestAnimationFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.PlayerRestLoop)
        AddFrame(frames, contextual.PlayerRestIcon)
        AddFrame(frames, contextual.PlayerRestGlow)
    end
    return frames
end

function Targets.GetCombatIconFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.AttackIcon)
    end
    return frames
end

function Targets.GetHealthLossFxFrames()
    local frames = {}
    local playerBars = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer
    if playerBars then
        AddFrame(frames, playerBars.PlayerFrameHealthBarAnimatedLoss)
        AddFrame(frames, playerBars.PlayerFrameTempMaxHealthLoss)
        AddFrame(frames, playerBars.TempMaxHealthLossDivider)
    end
    local targetBars = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
        and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
    if targetBars then
        AddFrame(frames, targetBars.TempMaxHealthLoss)
    end
    local focusBars = FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain
        and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
    if focusBars then
        AddFrame(frames, focusBars.TempMaxHealthLoss)
    end
    return frames
end

function Targets.GetLegacyPartyHealthLossFxFrames()
    local frames = {}
    for i = 1, 5 do
        AddFrame(frames, _G["CompactPartyFrameMember" .. i .. "TempMaxHealthLoss"])
    end
    return frames
end

function Targets.GetGroupIndicatorFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.GroupIndicator)
    end
    AddFrame(frames, PlayerFrameGroupIndicatorLeft)
    AddFrame(frames, PlayerFrameGroupIndicatorRight)
    AddFrame(frames, PlayerFrameGroupIndicatorMiddle)
    AddFrame(frames, PlayerFrameGroupIndicatorText)
    return frames
end

function Targets.GetPlayerCornerIconFrames()
    local frames = {}
    local contextual = GetContextualFrame()
    if contextual then
        AddFrame(frames, contextual.PlayerPortraitCornerIcon)
        AddFrame(frames, contextual.PortraitCornerIcon)
        AddFrame(frames, contextual.CornerIcon)
    end
    AddFrame(frames, PlayerPortraitCornerIcon)
    return frames
end

function Targets.GetPartyFrameTitleFrames()
    local frames = {}
    AddFrame(frames, CompactPartyFrameTitle)
    return frames
end

function Targets.GetTargetReputationColorFrames()
    local frames = {}
    if TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain then
        local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
        AddFrame(frames, main.ReputationColor)
    end
    AddFrame(frames, TargetFrameTextureFrameReputationColor)
    return frames
end

Targets.AddNameString = function(strings, fontString)
    if fontString and fontString.GetText and fontString.SetText then
        table.insert(strings, fontString)
    end
end

function Targets.AddUnitFrameNameStrings(strings, frame)
    if not frame then return end
    Targets.AddNameString(strings, frame.name)
    Targets.AddNameString(strings, frame.Name)
    Targets.AddNameString(strings, frame.NameText)
    if frame.PlayerFrameContent and frame.PlayerFrameContent.PlayerFrameContentMain then
        local main = frame.PlayerFrameContent.PlayerFrameContentMain
        Targets.AddNameString(strings, main.Name)
        Targets.AddNameString(strings, main.NameText)
    end
    if frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain then
        local main = frame.TargetFrameContent.TargetFrameContentMain
        Targets.AddNameString(strings, main.Name)
        Targets.AddNameString(strings, main.NameText)
    end
end

function Targets.GetRealmIndicatorNameStrings()
    local strings = {}
    Targets.AddUnitFrameNameStrings(strings, PlayerFrame)
    Targets.AddUnitFrameNameStrings(strings, TargetFrame)
    Targets.AddUnitFrameNameStrings(strings, FocusFrame)
    Targets.AddUnitFrameNameStrings(strings, TargetFrameToT)
    Targets.AddUnitFrameNameStrings(strings, FocusFrameToT)
    Targets.AddNameString(strings, PlayerName)
    Targets.AddNameString(strings, TargetFrameTextureFrameName)
    Targets.AddNameString(strings, FocusFrameTextureFrameName)

    for i = 1, 5 do
        Targets.AddNameString(strings, _G["CompactPartyFrameMember" .. i .. "Name"])
    end
    for i = 1, 40 do
        Targets.AddNameString(strings, _G["CompactRaidFrame" .. i .. "Name"])
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        for _, plate in ipairs(plates or {}) do
            if plate.UnitFrame then
                Targets.AddNameString(strings, plate.UnitFrame.name)
                Targets.AddNameString(strings, plate.UnitFrame.Name)
                Targets.AddNameString(strings, plate.UnitFrame.NameText)
            end
        end
    end

    return strings
end

function Targets.CanQueryNamePlateForUnit(unit)
    if not unit then return false end
    if unit == "target" or unit == "focus" or unit == "mouseover" then return true end
    if unit:match("^nameplate%d+$") then return true end
    return false
end
