--[[ Carpenter - Target Health Percent ]]
-- Shows a compact health percentage on hostile target unit frames in Classic clients.

local percentText

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

local function EnsureText()
    if percentText then return percentText end

    local bar = GetTargetHealthBar()
    if not bar or not bar.CreateFontString then return nil end

    local parent = TargetFrameTextureFrame or TargetFrame or bar
    percentText = parent:CreateFontString(nil, "OVERLAY")
    if TextStatusBarText then
        percentText:SetFontObject(TextStatusBarText)
    else
        percentText:SetFontObject("GameFontHighlightSmall")
        percentText:SetShadowColor(0, 0, 0, 0.7)
        percentText:SetShadowOffset(1, -1)
    end
    if percentText.SetDrawLayer then
        percentText:SetDrawLayer("OVERLAY", 7)
    end
    percentText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    percentText:SetTextColor(1, 1, 1)
    percentText:Hide()
    return percentText
end

local function ShouldShowTargetPercent()
    return IsEnabled()
        and UnitExists("target")
        and UnitCanAttack("player", "target")
        and not UnitIsDeadOrGhost("target")
end

local function Update()
    local text = EnsureText()
    if not text then return end

    if not ShouldShowTargetPercent() then
        text:Hide()
        return
    end

    local maxHealth = UnitHealthMax("target") or 0
    if maxHealth <= 0 then
        text:Hide()
        return
    end

    local health = UnitHealth("target") or 0
    local percent = math.max(0, math.min(100, math.floor((health / maxHealth) * 100 + 0.5)))
    text:SetText(percent .. "%")
    text:Show()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_HEALTH", "target")
frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
frame:RegisterUnitEvent("UNIT_FLAGS", "target")
frame:RegisterUnitEvent("UNIT_FACTION", "target")
frame:SetScript("OnEvent", function()
    Update()
end)

function Carpenter_UpdateTargetHealthPercent()
    Update()
end
