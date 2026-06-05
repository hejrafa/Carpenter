--[[ Carpenter - Sleek Options UI Configuration ]]
local addonName, ns = ...
local L = Carpenter and Carpenter.L or {}
local ADDON_ART_PATH = "Interface\\AddOns\\" .. (addonName or "Carpenter") .. "\\Art\\"
local COVER_FADE_MASK_PATH = ADDON_ART_PATH .. "Masks\\CoverFadeMask"
local SETTINGS_IMAGE_PATH = ADDON_ART_PATH .. "Settings\\"

local RETAIL_SETTINGS_IMAGES = {
    ["actioncam.png"] = true,
    ["classhealthbar.png"] = true,
    ["macro.png"] = true,
    ["macrotext.png"] = true,
    ["micromenu.png"] = true,
    ["nameplatecombo.png"] = "combo.png",
    ["stance.png"] = true,
    ["tooltip.png"] = true,
    ["unitnumbers.png"] = "cleanunit.png",
}

local function GetSettingsImage(filename)
    if Carpenter and Carpenter.Client and Carpenter.Client.isRetail then
        local retailImage = RETAIL_SETTINGS_IMAGES[filename]
        if retailImage then
            return SETTINGS_IMAGE_PATH .. "Retail\\" .. (type(retailImage) == "string" and retailImage or filename)
        end
    end
    return SETTINGS_IMAGE_PATH .. "Classic\\" .. filename
end

local frame = CreateFrame("Frame", "CarpenterOptionsPanel", UIParent)
frame.name = L.ADDON_NAME or "Carpenter"

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(frame, L.ADDON_NAME or "Carpenter")
    Settings.RegisterAddOnCategory(category)
else
    InterfaceOptions_AddCategory(frame)
end

function Carpenter_OpenConfig()
    if InCombatLockdown and InCombatLockdown() then
        local combatMessage = L.CONFIG_COMBAT_LOCKDOWN or "Carpenter settings cannot be opened while in combat."
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(combatMessage, 1, 0.1, 0.1, 1)
        else
            print("|cffff0000Carpenter:|r " .. combatMessage)
        end
        return
    end

    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        InterfaceOptionsFrame_OpenToCategory(frame)
    end
end

-- =========================
-- Header & Layout
-- =========================
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", 16, -15)
title:SetText(L.ADDON_NAME or "Carpenter")

local reloadBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reloadBtn:SetSize(90, 22)
reloadBtn:SetPoint("TOPRIGHT", -30, -15)
reloadBtn:SetText(L.RELOAD_UI or "Reload UI")
reloadBtn:SetScript("OnClick", function() ReloadUI() end)
reloadBtn:Disable()

local configBaseline = {}

local function SnapshotBaseline()
    configBaseline = {}
    if CarpenterDB then
        for k, v in pairs(CarpenterDB) do
            configBaseline[k] = v
        end
    end
end

local function SettingsDifferFromBaseline()
    if not CarpenterDB then return false end
    for k, v in pairs(CarpenterDB) do
        if configBaseline[k] ~= v then return true end
    end
    for k, v in pairs(configBaseline) do
        if CarpenterDB[k] ~= v then return true end
    end
    return false
end

local function UpdateReloadButton()
    if SettingsDifferFromBaseline() then
        reloadBtn:Enable()
    else
        reloadBtn:Disable()
    end
end

frame:SetScript("OnShow", function()
    SnapshotBaseline()
    UpdateReloadButton()
end)

-- Header Divider
local hrLeft = frame:CreateTexture(nil, "ARTWORK")
hrLeft:SetHeight(1)
hrLeft:SetPoint("LEFT", frame, "LEFT", 10, 0)
hrLeft:SetPoint("RIGHT", frame, "CENTER", 0, 0)
hrLeft:SetPoint("TOP", frame, "TOP", 0, -50)
hrLeft:SetTexture("Interface\\BUTTONS\\WHITE8X8")
hrLeft:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.1))

local hrRight = frame:CreateTexture(nil, "ARTWORK")
hrRight:SetHeight(1)
hrRight:SetPoint("LEFT", frame, "CENTER", 0, 0)
hrRight:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
hrRight:SetPoint("TOP", frame, "TOP", 0, -50)
hrRight:SetTexture("Interface\\BUTTONS\\WHITE8X8")
hrRight:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.1), CreateColor(1, 1, 1, 0))

-- Colors
local LighterCream = "|cffffff99"
local LightGrey = "|cffaaaaaa"

local ConfigSidebar = ns and ns.Private and ns.Private.ConfigSidebar or {}
local ConfigOptions = ns and ns.Private and ns.Private.ConfigOptions or {}
local sidebarApi = ConfigSidebar.Create and ConfigSidebar.Create({
    Frame = frame,
    L = L,
    LightGrey = LightGrey,
    LighterCream = LighterCream,
    CoverFadeMaskPath = COVER_FADE_MASK_PATH,
    UpdateReloadButton = UpdateReloadButton,
}) or {}
local sidebar = sidebarApi.Frame
local sideDesc = sidebarApi.Description
local sideReloadHint = sidebarApi.ReloadHint
local sideContent = sidebarApi.Content
local SetSidebarDefault = sidebarApi.SetDefault or function() end
local ToggleSideImage = sidebarApi.ToggleImage or function() end
local SIDE_GAP = sidebarApi.SideGap or 16

-- =========================
-- Main Scroll Area
-- =========================
local scrollFrame = CreateFrame("ScrollFrame", "CP_MainScroll", frame)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -50)
scrollFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 0)
scrollFrame:SetPoint("RIGHT", sidebar, "LEFT", -10, 0)
scrollFrame:EnableMouseWheel(true)

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    local new = Clamp(cur - (delta * 25), 0, max)
    self:SetVerticalScroll(new)
end)

scrollFrame:SetScript("OnLeave", SetSidebarDefault)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetHeight(1000)
content:SetWidth(scrollFrame:GetWidth())
scrollFrame:SetScrollChild(content)
scrollFrame:SetScript("OnSizeChanged", function(self)
    local w = self:GetWidth()
    if w and w > 0 then content:SetWidth(w) end
end)

-- =========================
-- Vertical Divider
-- =========================
local vLineTop = frame:CreateTexture(nil, "ARTWORK")
vLineTop:SetWidth(1)
vLineTop:SetPoint("TOP", scrollFrame, "TOP", 0, 0)
vLineTop:SetPoint("BOTTOM", scrollFrame, "CENTER", 0, 0)
vLineTop:SetPoint("LEFT", scrollFrame, "RIGHT", 7, 0)
vLineTop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
vLineTop:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.1), CreateColor(1, 1, 1, 0))

local vLineBot = frame:CreateTexture(nil, "ARTWORK")
vLineBot:SetWidth(1)
vLineBot:SetPoint("TOP", scrollFrame, "CENTER", 0, 0)
vLineBot:SetPoint("BOTTOM", scrollFrame, "BOTTOM", 0, 0)
vLineBot:SetPoint("LEFT", scrollFrame, "RIGHT", 7, 0)
vLineBot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
vLineBot:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.1))

-- =========================
-- UI Component Helpers
-- =========================
local SCROLL_CONTENT_TOP_PADDING = 16
local yPos = -SCROLL_CONTENT_TOP_PADDING

local function CreateHeader(text)
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", 10, yPos)
    label:SetText(text)
    label:SetTextColor(1, 1, 1)
    yPos = yPos - 25
end

local function CreateCheckbox(key, label, description, sideLogic, imagePath, requiresReload, onToggle)
    if requiresReload == nil then requiresReload = true end
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", 0, yPos)
    row:SetPoint("TOPRIGHT", 0, yPos)
    row:EnableMouse(true)

    local textures = {}
    local function CreateLine(anchor, gStart, gEnd)
        local t = row:CreateTexture(nil, "OVERLAY")
        t:SetHeight(0.5)
        t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        t:SetGradient("HORIZONTAL", gStart, gEnd)

        if anchor == "TOPLEFT" then
            t:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            t:SetPoint("RIGHT", row, "TOP", 0, 0)
        elseif anchor == "TOPRIGHT" then
            t:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            t:SetPoint("LEFT", row, "TOP", 0, 0)
        elseif anchor == "BOTTOMLEFT" then
            t:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            t:SetPoint("RIGHT", row, "BOTTOM", 0, 0)
        elseif anchor == "BOTTOMRIGHT" then
            t:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            t:SetPoint("LEFT", row, "BOTTOM", 0, 0)
        end

        t:Hide()
        return t
    end

    textures.lineTopL = CreateLine("TOPLEFT", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.8))
    textures.lineTopR = CreateLine("TOPRIGHT", CreateColor(1, 1, 1, 0.8), CreateColor(1, 1, 1, 0))
    textures.lineBotL = CreateLine("BOTTOMLEFT", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.8))
    textures.lineBotR = CreateLine("BOTTOMRIGHT", CreateColor(1, 1, 1, 0.8), CreateColor(1, 1, 1, 0))

    local bgLeft = row:CreateTexture(nil, "BACKGROUND")
    bgLeft:SetPoint("TOPLEFT")
    bgLeft:SetPoint("BOTTOMLEFT")
    bgLeft:SetPoint("RIGHT", row, "CENTER")
    bgLeft:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    bgLeft:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.06))
    bgLeft:Hide()

    local bgRight = row:CreateTexture(nil, "BACKGROUND")
    bgRight:SetPoint("TOPRIGHT")
    bgRight:SetPoint("BOTTOMRIGHT")
    bgRight:SetPoint("LEFT", row, "CENTER")
    bgRight:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    bgRight:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.06), CreateColor(1, 1, 1, 0))
    bgRight:Hide()

    local check = CreateFrame("CheckButton", "CP_Check_" .. key, row, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("LEFT", 15, 0)
    check:SetHitRectInsets(0, -320, 0, 0)
    _G[check:GetName() .. "Text"]:SetText(label)
    _G[check:GetName() .. "Text"]:SetFontObject("GameFontNormal")

    local function OnEnter()
        bgLeft:Show()
        bgRight:Show()
        for _, t in pairs(textures) do t:Show() end
        ToggleSideImage(imagePath)
        sideDesc:SetText(description)
        if sideLogic then sideLogic() else sideContent:Hide() end
        if requiresReload then sideReloadHint:Show() else sideReloadHint:Hide() end
    end

    local function OnLeave()
        bgLeft:Hide()
        bgRight:Hide()
        for _, t in pairs(textures) do t:Hide() end
    end

    row:SetScript("OnEnter", OnEnter)
    row:SetScript("OnLeave", OnLeave)
    row:SetScript("OnClick", function() check:Click() end)
    check:SetScript("OnEnter", OnEnter)
    check:SetScript("OnLeave", OnLeave)
    check:SetScript("OnClick", function(self)
        if CarpenterDB then
            CarpenterDB[key] = self:GetChecked()
            UpdateReloadButton()
            if Carpenter and Carpenter.RefreshFeature then
                Carpenter:RefreshFeature(key)
            end
            if onToggle then onToggle() end
        end
    end)

    yPos = yPos - 32
    return row
end

-- =========================
-- Populate Content
-- =========================

local OPTION_SECTIONS = ConfigOptions.Create and ConfigOptions.Create({
    L = L,
    LightGrey = LightGrey,
    LighterCream = LighterCream,
    GetSettingsImage = GetSettingsImage,
    SideLogic = sidebarApi.SideLogic,
}) or {}

local function IsOptionAvailable(option)
    if not Carpenter:IsFeatureAvailable(option.key) then return false end
    if option.class then
        local _, class = UnitClass("player")
        if class ~= option.class then return false end
    end
    return true
end

local visibleSectionCount = 0

for _, section in ipairs(OPTION_SECTIONS) do
    local hasAvailableOptions = false
    for _, option in ipairs(section.options) do
        if IsOptionAvailable(option) then
            hasAvailableOptions = true
            break
        end
    end

    if hasAvailableOptions then
        visibleSectionCount = visibleSectionCount + 1
        if visibleSectionCount > 1 then
            yPos = yPos - 24
        end

        CreateHeader(section.title)

        for _, option in ipairs(section.options) do
            if IsOptionAvailable(option) then
                CreateCheckbox(
                    option.key,
                    option.label,
                    option.description,
                    option.sideLogic,
                    option.image,
                    option.requiresReload,
                    option.onToggle
                )
            end
        end
    end
end

-- =========================
-- Footer
-- =========================
yPos = yPos - 48
local footerVersion = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footerVersion:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, yPos - 3)
footerVersion:SetText(LightGrey .. "v" .. ((Carpenter and Carpenter.GetVersion and Carpenter:GetVersion()) or "1.6.0") .. "|r")

-- Keep the scroll child close to the frame edges without crowding the footer.
local FOOTER_LINE_HEIGHT = 14
local SIDEBAR_BOTTOM_INSET = 10
local SCROLL_CONTENT_BOTTOM_PADDING = SIDE_GAP + SIDEBAR_BOTTOM_INSET
content:SetHeight(-yPos + FOOTER_LINE_HEIGHT + SCROLL_CONTENT_BOTTOM_PADDING)

-- Sync on Login
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function(self)
    if CarpenterDB then
        for key, _ in pairs(CarpenterDB) do
            local cb = _G["CP_Check_" .. key]
            if cb then cb:SetChecked(CarpenterDB[key]) end
        end
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
