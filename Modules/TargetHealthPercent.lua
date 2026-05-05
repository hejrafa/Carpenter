--[[ Carpenter - Target Health Percent ]]
-- Shows compact health and resource percentages on player and hostile target unit frames in Classic clients.

local healthText
local powerText

local function IsEnabled()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic and Carpenter:IsEnabled("targetHealthPercentEnabled")
end

local function GetTargetHealthBar()
    return TargetFrameHealthBar
        or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar)
        or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar)
end

local function GetTargetPowerBar()
    return TargetFrameManaBar
        or TargetFramePowerBar
        or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.ManaBar)
        or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.PowerBar)
        or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.ManaBar)
        or (TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
            and TargetFrame.TargetFrameContent.TargetFrameContentMain.PowerBar)
end

local function CreatePercentText(bar)
    if not bar or not bar.CreateFontString then return nil end

    local parent = TargetFrameTextureFrame or TargetFrame or bar
    local text = parent:CreateFontString(nil, "OVERLAY")
    if TextStatusBarText then
        text:SetFontObject(TextStatusBarText)
    else
        text:SetFontObject("GameFontHighlightSmall")
        text:SetShadowColor(0, 0, 0, 0.7)
        text:SetShadowOffset(1, -1)
    end
    if text.SetDrawLayer then
        text:SetDrawLayer("OVERLAY", 7)
    end
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1)
    text:Hide()
    return text
end

local function EnsureHealthText()
    if healthText then return healthText end

    healthText = CreatePercentText(GetTargetHealthBar())
    return healthText
end

local function EnsurePowerText()
    if powerText then return powerText end

    powerText = CreatePercentText(GetTargetPowerBar())
    return powerText
end

local function ShouldShowTargetPercent()
    return IsEnabled()
        and UnitExists("target")
        and (UnitIsPlayer("target") or UnitCanAttack("player", "target"))
        and not UnitIsDeadOrGhost("target")
end

local function UpdateText(text, currentValue, maxValue)
    if not text then return end

    maxValue = maxValue or 0
    if maxValue <= 0 then
        text:Hide()
        return
    end

    currentValue = currentValue or 0
    local percent = math.max(0, math.min(100, math.floor((currentValue / maxValue) * 100 + 0.5)))
    text:SetText(percent .. "%")
    text:Show()
end

local function Update()
    local health = EnsureHealthText()
    local power = EnsurePowerText()
    if not health and not power then return end

    if not ShouldShowTargetPercent() then
        if health then health:Hide() end
        if power then power:Hide() end
        return
    end

    UpdateText(health, UnitHealth("target"), UnitHealthMax("target"))
    UpdateText(power, UnitPower("target"), UnitPowerMax("target"))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_HEALTH", "target")
frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
frame:RegisterUnitEvent("UNIT_MAXPOWER", "target")
frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
frame:RegisterUnitEvent("UNIT_FLAGS", "target")
frame:RegisterUnitEvent("UNIT_FACTION", "target")
frame:SetScript("OnEvent", function()
    Update()
end)

function Carpenter_UpdateTargetHealthPercent()
    Update()
end
