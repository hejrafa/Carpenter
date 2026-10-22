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

-- WoW Forever's own previews, named like the option's Classic image, or by
-- the Forever-only name an option passes to GetSettingsImage. Forever falls
-- back to the Retail preview, then the Classic one, for anything not listed
-- here. Make these with tools/settings-image.swift.
local FOREVER_SETTINGS_IMAGES = {
    ["actioncam.png"] = true,
    ["chatbuttons.png"] = true,
    ["chatcleaner.png"] = true,
    ["classhealthbar.png"] = true,
    ["error.png"] = true,
    ["explorer.png"] = true,
    ["hidequesttrack.png"] = true,
    ["keybind.png"] = true,
    ["layout.png"] = true,
    ["macro.png"] = true,
    ["macrotext.png"] = true,
    ["map.png"] = true,
    ["micromenu.png"] = true,
    ["minimapclutter.png"] = true,
    ["nameplatecombo.png"] = true,
    ["nameplatedebuff.png"] = true,
    ["repair.png"] = true,
    ["selljunk.png"] = true,
    ["sortquesttrack.png"] = true,
    ["stance.png"] = true,
    ["tooltip.png"] = true,
    ["unitdebuff.png"] = true,
    ["unitnumbers.png"] = true,
    ["warning.png"] = true,
}

-- foreverFilename gives Forever its own preview where options share a Classic
-- image, or where only Forever has one (filename nil: no image elsewhere).
local function GetSettingsImage(filename, foreverFilename)
    local client = Carpenter and Carpenter.Client
    if client and client.isForever then
        local foreverImage = foreverFilename or filename
        if foreverImage and FOREVER_SETTINGS_IMAGES[foreverImage] then
            return SETTINGS_IMAGE_PATH .. "Forever\\" .. foreverImage
        end
    end
    if not filename then return nil end
    if client and client.isRetail then
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
local SyncCheckboxesFromDatabase

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
    if SyncCheckboxesFromDatabase then
        SyncCheckboxesFromDatabase()
    end
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
local EditModeLayout = ns and ns.Private and ns.Private.EditModeLayout or {}
local RPMacros = ns and ns.Private and ns.Private.RPMacros or {}
local SettingsPreset = ns and ns.Private and ns.Private.SettingsPreset or {}
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
local ShowSidebarContent = sidebarApi.ShowContent or function() end
local SIDE_GAP = sidebarApi.SideGap or 16
local hiddenSettingsShown = false
local ShowHiddenPageSidebar

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

scrollFrame:SetScript("OnLeave", function()
    if hiddenSettingsShown and ShowHiddenPageSidebar then
        ShowHiddenPageSidebar()
    else
        SetSidebarDefault()
    end
end)

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
    return label
end

-- Options apply live through Carpenter:RefreshFeature; requiresReload marks
-- the few that still need a /reload to fully take effect.
local function CreateCheckbox(key, label, description, sideLogic, imagePath, requiresReload, unavailableMessage, badge)
    requiresReload = requiresReload == true
    local isUnavailable = unavailableMessage ~= nil
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
    check:SetHitRectInsets(0, 0, 0, 0)
    check:SetChecked(CarpenterDB and CarpenterDB[key] == true)
    _G[check:GetName() .. "Text"]:SetText(label)
    _G[check:GetName() .. "Text"]:SetFontObject("GameFontNormal")
    if isUnavailable then
        check:SetAlpha(0.55)
        _G[check:GetName() .. "Text"]:SetTextColor(0.55, 0.55, 0.55, 1)
    end

    if badge and badge.text then
        local badgeFrame
        local created
        local ok = pcall(function()
            created = CreateFrame("Frame", nil, row, "NewFeatureLabelNoAnimateTemplate")
        end)

        if ok and created then
            badgeFrame = created
            local checkLabel = _G[check:GetName() .. "Text"]
            local labelWidth = checkLabel:GetWrappedWidth()
            if labelWidth and labelWidth > 0 then
                badgeFrame:SetPoint("LEFT", checkLabel, "LEFT", labelWidth - 12, 0)
            else
                badgeFrame:SetPoint("LEFT", checkLabel, "RIGHT", -10, 0)
            end
            local textRegions = {}
            for _, region in ipairs({ badgeFrame:GetRegions() }) do
                if region.SetText then
                    textRegions[#textRegions + 1] = region
                elseif region.SetVertexColor then
                    if region.SetDesaturated then
                        region:SetDesaturated(true)
                    end
                    region:SetVertexColor(0.42, 1, 0.38, 1)
                end
            end
            local badgeText = textRegions[#textRegions]
            for _, region in ipairs(textRegions) do
                if region == badgeText then
                    region:SetText(badge.text)
                    if region.SetTextColor then
                        region:SetTextColor(0.58, 1, 0.42, 1)
                    end
                    if region.SetShadowColor then
                        region:SetShadowColor(0.34, 1, 0.28, 0.85)
                        region:SetShadowOffset(0, 0)
                    end
                else
                    region:SetText("")
                    if region.Hide then
                        region:Hide()
                    end
                end
            end
        else
            badgeFrame = CreateFrame("Frame", nil, row)
            badgeFrame:SetSize(42, 18)
            badgeFrame:SetPoint("LEFT", _G[check:GetName() .. "Text"], "RIGHT", 8, 0)

            local badgeText = badgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badgeText:SetPoint("CENTER", 0, 0)
            badgeText:SetText(badge.text)
            badgeText:SetTextColor(0.58, 1, 0.42, 1)
            badgeText:SetShadowColor(0, 0, 0, 1)
            badgeText:SetShadowOffset(1, -1)
        end

        badgeFrame:SetFrameLevel((check:GetFrameLevel() or row:GetFrameLevel() or 1) + 10)
        badgeFrame:EnableMouse(true)
        badgeFrame:Show()

        badgeFrame:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(badge.tooltipTitle or badge.text, 1.0, 0.78, 0.36, 1, true)
                if badge.tooltipText then
                    GameTooltip:AddLine(badge.tooltipText, 0.9, 0.9, 0.9, true)
                end
                GameTooltip:Show()
            end
        end)

        badgeFrame:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end

    local function ResetUnavailableOption()
        check:SetChecked(false)
        if CarpenterDB then
            CarpenterDB[key] = false
            UpdateReloadButton()
        end
    end

    local function OnEnter()
        bgLeft:Show()
        bgRight:Show()
        for _, t in pairs(textures) do t:Show() end
        ToggleSideImage(imagePath)
        sideDesc:SetText(description)
        if sideLogic then sideLogic() else sideContent:Hide() end
        if requiresReload and not isUnavailable then sideReloadHint:Show() else sideReloadHint:Hide() end
    end

    local function OnLeave()
        bgLeft:Hide()
        bgRight:Hide()
        for _, t in pairs(textures) do t:Hide() end
    end

    row:SetScript("OnEnter", OnEnter)
    row:SetScript("OnLeave", OnLeave)
    row:SetScript("OnClick", function()
        if isUnavailable then
            ResetUnavailableOption()
        else
            check:Click()
        end
    end)
    check:SetScript("OnEnter", OnEnter)
    check:SetScript("OnLeave", OnLeave)
    check:SetScript("OnClick", function(self)
        if isUnavailable then
            ResetUnavailableOption()
            return
        end
        if CarpenterDB then
            CarpenterDB[key] = self:GetChecked()
            UpdateReloadButton()
            if Carpenter and Carpenter.RefreshFeature then
                Carpenter:RefreshFeature(key)
            end
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

local function ShowWidget(widget, shown)
    if shown then
        widget:Show()
    else
        widget:Hide()
    end
end

-- A list row without a saved setting. With a toggle, the row gets a checkbox
-- whose state comes from toggle.isChecked and whose clicks go to
-- toggle.onClick instead of CarpenterDB.
local function CreateListItem(label, showDetails, toggle)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", 0, yPos)
    row:SetPoint("TOPRIGHT", 0, yPos)
    row:EnableMouse(true)

    local check
    if toggle then
        check = CreateFrame("CheckButton", toggle.name, row, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("LEFT", 15, 0)
        check:SetHitRectInsets(0, 0, 0, 0)
        _G[check:GetName() .. "Text"]:SetText(label)
        _G[check:GetName() .. "Text"]:SetFontObject("GameFontNormal")
        row.Refresh = function() check:SetChecked(toggle.isChecked()) end
        row.Refresh()
    else
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", row, "LEFT", 42, 0)
        text:SetText(label)
    end

    local textures = {}
    local function CreateLine(anchor, gStart, gEnd)
        local texture = row:CreateTexture(nil, "OVERLAY")
        texture:SetHeight(0.5)
        texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        texture:SetGradient("HORIZONTAL", gStart, gEnd)

        if anchor == "TOPLEFT" then
            texture:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            texture:SetPoint("RIGHT", row, "TOP", 0, 0)
        elseif anchor == "TOPRIGHT" then
            texture:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            texture:SetPoint("LEFT", row, "TOP", 0, 0)
        elseif anchor == "BOTTOMLEFT" then
            texture:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            texture:SetPoint("RIGHT", row, "BOTTOM", 0, 0)
        elseif anchor == "BOTTOMRIGHT" then
            texture:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            texture:SetPoint("LEFT", row, "BOTTOM", 0, 0)
        end

        texture:Hide()
        return texture
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

    local function OnEnter()
        bgLeft:Show()
        bgRight:Show()
        for _, texture in pairs(textures) do texture:Show() end
        showDetails()
    end
    local function OnLeave()
        bgLeft:Hide()
        bgRight:Hide()
        for _, texture in pairs(textures) do texture:Hide() end
    end

    row:SetScript("OnEnter", OnEnter)
    row:SetScript("OnLeave", OnLeave)
    if check then
        row:SetScript("OnClick", function() check:Click() end)
        check:SetScript("OnEnter", OnEnter)
        check:SetScript("OnLeave", OnLeave)
        check:SetScript("OnClick", function(self)
            toggle.onClick(self:GetChecked() and true or false)
            row.Refresh()
        end)
    else
        row:SetScript("OnClick", showDetails)
    end

    yPos = yPos - 32
    return row
end

local function RenderSections(sections)
    local widgets = {}
    yPos = -SCROLL_CONTENT_TOP_PADDING
    local visibleSectionCount = 0

    for _, section in ipairs(sections) do
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

            widgets[#widgets + 1] = CreateHeader(section.title)

            for _, option in ipairs(section.options) do
                if IsOptionAvailable(option) then
                    widgets[#widgets + 1] = CreateCheckbox(
                        option.key,
                        option.label,
                        option.description,
                        option.sideLogic,
                        option.image,
                        option.requiresReload,
                        option.unavailableMessage,
                        option.badge
                    )
                end
            end
        end
    end

    return widgets, yPos
end

local mainWidgets, mainYPos = RenderSections(OPTION_SECTIONS)

-- Hidden page rows are checkboxes that mirror something outside CarpenterDB
-- (the game settings and keybinds, the Edit Mode layout list, the macro
-- list); the sidebar reports how the last click went.
local hiddenToggleRows = {}
local selectedHiddenItem

local function SetHiddenPageStatus(message, success)
    local status = _G.CP_HiddenPageStatus
    if not status then return end
    status:SetText(message == "" and "" or ((success and "|cff55ff55" or "|cffff6060") .. message .. "|r"))
end

local function ShowHiddenItemSidebar(item, description, image)
    ToggleSideImage(image)
    description = description:gsub("{hl}", LighterCream):gsub("{/hl}", LightGrey)
    sideDesc:SetText(LightGrey .. description .. "|r")
    sideReloadHint:Hide()
    ShowSidebarContent()

    if not _G.CP_HiddenPageStatus then
        local status = sideContent:CreateFontString("CP_HiddenPageStatus", "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", sideContent, "TOPLEFT", 5, 0)
        status:SetPoint("RIGHT", sideContent, "RIGHT", -5, 0)
        status:SetHeight(50)
        status:SetJustifyH("LEFT")
        status:SetJustifyV("TOP")
        status:SetWordWrap(true)
    end
    if selectedHiddenItem ~= item then
        selectedHiddenItem = item
        SetHiddenPageStatus("", true)
    end
    _G.CP_HiddenPageStatus:Show()
end

local function RefreshHiddenToggles()
    for _, row in ipairs(hiddenToggleRows) do
        row.Refresh()
    end
end

local function ShowSettingsPresetSidebar()
    ShowHiddenItemSidebar(SettingsPreset, L.SETTINGS_PRESET_DESCRIPTION or "Every carpenter sets up the workshop their own way. These are the author's own {hl}WoW Forever{/hl} game settings: graphics, sound, interface, nameplates, action bars, and keybinds.\n\nCheck it to switch over to them. Uncheck it to go back to the settings you had before.")
end

local SETTINGS_PRESET_MESSAGES = {
    applied = L.SETTINGS_PRESET_APPLIED or "Workshop rearranged! Reload the UI so everything settles in.",
    partial = L.SETTINGS_PRESET_PARTIAL or "The game turned down a few settings, but the rest are in place.",
    restored = L.SETTINGS_PRESET_RESTORED or "Your own settings and keybinds are back on the workbench.",
    unchanged = L.SETTINGS_PRESET_UNCHANGED or "These already are your own settings, so there's nothing to put back.",
    combat = L.SETTINGS_PRESET_COMBAT or "You can't rearrange the workshop while in combat.",
}

local function SetSettingsPresetApplied(applied)
    local apply = SettingsPreset.Restore
    if applied then apply = SettingsPreset.Apply end
    local ok, result = false, "failed"
    if apply then
        ok, result = apply()
    end
    UpdateReloadButton()
    ShowSettingsPresetSidebar()
    SetHiddenPageStatus(SETTINGS_PRESET_MESSAGES[result] or L.SETTINGS_PRESET_FAILED or "Carpenter couldn't change the game settings.", ok)
    -- The server echoes the action bar toggles back a moment later.
    Carpenter:After(1, RefreshHiddenToggles)
end

local function ShowEditModeLayoutSidebar()
    ShowHiddenItemSidebar(EditModeLayout, L.EDIT_MODE_LAYOUT_DESCRIPTION or "Every carpenter keeps a favorite workbench. This is the author's own {hl}Edit Mode{/hl} layout.\n\nCheck it to create the account-wide {hl}Carpenter{/hl} layout, then select it in Edit Mode. Uncheck it to remove the layout.",
        GetSettingsImage(nil, "layout.png"))
end

local EDIT_MODE_LAYOUT_MESSAGES = {
    created = L.EDIT_MODE_LAYOUT_CREATED or "Carpenter layout built! Open Edit Mode to select it.",
    updated = L.EDIT_MODE_LAYOUT_UPDATED or "Carpenter layout rebuilt! Open Edit Mode to select it.",
    removed = L.EDIT_MODE_LAYOUT_REMOVED or "Carpenter layout taken down.",
    active = L.EDIT_MODE_LAYOUT_ACTIVE or "You're still using the Carpenter layout. Pick another one in Edit Mode first.",
    combat = L.EDIT_MODE_LAYOUT_COMBAT or "You can't rearrange the furniture while in combat.",
}

local function SetEditModeLayoutInstalled(installed)
    local install = EditModeLayout.Remove
    if installed then install = EditModeLayout.Install end
    local ok, result = false, "failed"
    if install then
        ok, result = install()
    end
    ShowEditModeLayoutSidebar()
    SetHiddenPageStatus(EDIT_MODE_LAYOUT_MESSAGES[result] or L.EDIT_MODE_LAYOUT_FAILED or "Carpenter couldn't build the layout.", ok)
end

-- Macro sections on the hidden page, top to bottom. {body} and {name} in the
-- description are filled in per macro.
local MACRO_SECTIONS = {
    {
        title = L.SECTION_PROFESSION_MACROS or "Profession Macros",
        macros = RPMacros.ProfessionMacros or {},
        checkPrefix = "CP_ProfessionMacro_",
        description = L.PROFESSION_MACRO_DESCRIPTION or "One of the author's own {hl}profession{/hl} macros. It keeps up with your bags, so it always reaches for the best fishing pole you're carrying:\n\n{body}\n\nCheck it to add the account-wide {hl}{name}{/hl} macro to General Macros. Uncheck it to remove the macro.",
    },
    {
        title = L.SECTION_RP_MACROS or "RP Macros",
        macros = RPMacros.Macros or {},
        checkPrefix = "CP_RPMacro_",
        description = L.RP_MACRO_DESCRIPTION or "One of the author's own {hl}roleplay{/hl} macros, ready to rebuild on any character:\n\n{body}\n\nCheck it to add the account-wide {hl}{name}{/hl} macro to General Macros. Uncheck it to remove the macro.",
    },
}

local function ShowRPMacroSidebar(macro, description)
    local lines = {}
    for line in RPMacros.GetBody(macro):gmatch("[^\n]+") do
        lines[#lines + 1] = LighterCream .. line .. LightGrey
    end
    -- Font-height icon, nudged down onto the text baseline.
    local name = "|T" .. macro.icon .. ":0:0:0:-8|t " .. macro.name
    description = description:gsub("{body}", function() return table.concat(lines, "\n") end)
    description = description:gsub("{name}", function() return name end)
    ShowHiddenItemSidebar(macro, description)
end

local RP_MACRO_MESSAGES = {
    created = L.RP_MACRO_CREATED or "Macro built! Find it under General Macros.",
    updated = L.RP_MACRO_UPDATED or "Macro rebuilt! Find it under General Macros.",
    removed = L.RP_MACRO_REMOVED or "Macro taken off the workbench.",
    combat = L.RP_MACRO_COMBAT or "You can't touch your macros while in combat.",
    full = L.RP_MACRO_FULL or "Your General Macros are full. Make some room and try again.",
}

local function SetRPMacroInstalled(macro, installed, description)
    local install = RPMacros.Remove
    if installed then install = RPMacros.Install end
    local ok, result = false, "failed"
    if install then
        ok, result = install(macro)
    end
    ShowRPMacroSidebar(macro, description)
    SetHiddenPageStatus(RP_MACRO_MESSAGES[result] or L.RP_MACRO_FAILED or "Carpenter couldn't build the macro.", ok)
end

local function CreateHiddenPage()
    local widgets = {}
    yPos = -SCROLL_CONTENT_TOP_PADDING

    local function AddToggle(label, showDetails, toggle)
        local row = CreateListItem(label, showDetails, toggle)
        widgets[#widgets + 1] = row
        hiddenToggleRows[#hiddenToggleRows + 1] = row
        ShowHiddenPageSidebar = ShowHiddenPageSidebar or showDetails
    end

    -- One Settings section: the game settings on Forever, the Edit Mode
    -- layout wherever Edit Mode exists.
    local hasSettingsPreset = SettingsPreset.IsAvailable and SettingsPreset.IsAvailable()
    local hasEditModeLayout = EditModeLayout.IsAvailable and EditModeLayout.IsAvailable()
    if hasSettingsPreset or hasEditModeLayout then
        widgets[#widgets + 1] = CreateHeader(L.SECTION_SETTINGS_PRESET or "Settings")
    end

    if hasSettingsPreset then
        AddToggle(L.SETTINGS_PRESET_NAME or "Game Settings & Keybinds", ShowSettingsPresetSidebar, {
            name = "CP_SettingsPresetCheck",
            isChecked = function() return SettingsPreset.IsApplied and SettingsPreset.IsApplied() or false end,
            onClick = SetSettingsPresetApplied,
        })
    end

    if hasEditModeLayout then
        AddToggle(L.EDIT_MODE_LAYOUT_NAME or "Edit Mode Layout", ShowEditModeLayoutSidebar, {
            name = "CP_EditModeLayoutCheck",
            isChecked = function() return EditModeLayout.IsInstalled and EditModeLayout.IsInstalled() or false end,
            onClick = SetEditModeLayoutInstalled,
        })
    end

    for _, section in ipairs(MACRO_SECTIONS) do
        if #section.macros > 0 then
            if #widgets > 0 then
                yPos = yPos - 24
            end
            widgets[#widgets + 1] = CreateHeader(section.title)
            for index, macro in ipairs(section.macros) do
                AddToggle(macro.name, function() ShowRPMacroSidebar(macro, section.description) end, {
                    name = section.checkPrefix .. index,
                    isChecked = function() return RPMacros.IsInstalled and RPMacros.IsInstalled(macro) or false end,
                    onClick = function(checked) SetRPMacroInstalled(macro, checked, section.description) end,
                })
            end
        end
    end

    return widgets, yPos
end

local hiddenWidgets, hiddenYPos = CreateHiddenPage()
local hasHiddenSettings = #hiddenWidgets > 0

-- =========================
-- Footer
-- =========================
local footerVersionButton = CreateFrame("Button", nil, content)
footerVersionButton:SetSize(120, 16)

local footerVersion = footerVersionButton:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footerVersion:SetAllPoints(footerVersionButton)
footerVersion:SetJustifyH("RIGHT")

local versionText = "v" .. ((Carpenter and Carpenter.GetVersion and Carpenter:GetVersion()) or "1.8.1")
    .. " (" .. ((Carpenter and Carpenter.GetBuild and Carpenter:GetBuild()) or "dev") .. ")"
local function UpdateFooterVersionText(isHovered)
    footerVersion:SetText((isHovered and hasHiddenSettings and "|cffdddddd" or LightGrey) .. versionText .. "|r")
end

local function SetSettingsView(showHidden)
    hiddenSettingsShown = hasHiddenSettings and showHidden == true
    for _, widget in ipairs(mainWidgets) do
        ShowWidget(widget, not hiddenSettingsShown)
    end
    for _, widget in ipairs(hiddenWidgets) do
        ShowWidget(widget, hiddenSettingsShown)
    end

    local footerYPos = (hiddenSettingsShown and hiddenYPos or mainYPos) - 48
    footerVersionButton:ClearAllPoints()
    footerVersionButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, footerYPos - 3)
    SetSidebarDefault()
    if hiddenSettingsShown then
        RefreshHiddenToggles()
        if ShowHiddenPageSidebar then ShowHiddenPageSidebar() end
    end
    scrollFrame:SetVerticalScroll(0)

-- Keep the scroll child close to the frame edges without crowding the footer.
    local FOOTER_LINE_HEIGHT = 14
    local SIDEBAR_BOTTOM_INSET = 10
    local SCROLL_CONTENT_BOTTOM_PADDING = SIDE_GAP + SIDEBAR_BOTTOM_INSET
    content:SetHeight(-footerYPos + FOOTER_LINE_HEIGHT + SCROLL_CONTENT_BOTTOM_PADDING)
end

footerVersionButton:SetScript("OnEnter", function()
    UpdateFooterVersionText(true)
end)
footerVersionButton:SetScript("OnLeave", function()
    UpdateFooterVersionText(false)
end)
footerVersionButton:SetScript("OnClick", function()
    SetSettingsView(not hiddenSettingsShown)
end)

UpdateFooterVersionText(false)
SetSettingsView(false)

SyncCheckboxesFromDatabase = function()
    RefreshHiddenToggles()
    if not CarpenterDB then return end

    for key, value in pairs(CarpenterDB) do
        local checkbox = _G["CP_Check_" .. key]
        if checkbox then
            checkbox:SetChecked(value == true)
        end
    end
end

-- Hidden page checkboxes mirror the macro and Edit Mode layout lists, which
-- can also change in Blizzard's own windows while the settings are open.
local hiddenToggleWatcher = CreateFrame("Frame")
hiddenToggleWatcher:RegisterEvent("UPDATE_MACROS")
if EditModeLayout.IsAvailable and EditModeLayout.IsAvailable() then
    pcall(hiddenToggleWatcher.RegisterEvent, hiddenToggleWatcher, "EDIT_MODE_LAYOUTS_UPDATED")
end
hiddenToggleWatcher:SetScript("OnEvent", function()
    if frame:IsVisible() then RefreshHiddenToggles() end
end)

-- Saved variables are guaranteed by ADDON_LOADED. Keep the world event as a
-- fallback for clients that defer parts of settings initialization.
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("VARIABLES_LOADED")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= addonName then
        return
    end

    SyncCheckboxesFromDatabase()
    self:UnregisterEvent(event)
end)
