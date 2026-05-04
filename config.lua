--[[ Carpenter - Sleek Options UI Configuration ]]
local addonName = ...
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
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage("Carpenter settings cannot be opened while in combat.", 1, 0.1, 0.1, 1)
        else
            print("|cffff0000Carpenter:|r Settings cannot be opened while in combat.")
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

-- =========================
-- Persistent Sidebar
-- =========================
local sidebar = CreateFrame("Frame", nil, frame)
sidebar:SetSize(240, 0)
sidebar:SetPoint("TOPRIGHT", -10, -60)
sidebar:SetPoint("BOTTOMRIGHT", -10, 10)

-- Colors
local LighterCream = "|cffffff99"
local LightGrey = "|cffaaaaaa"

-- Sidebar spacing: same gap between image, description, "Requires UI reload", and extra content
local SIDE_GAP = 16

-- Image Container
local sideImage = sidebar:CreateTexture(nil, "ARTWORK")
sideImage:SetSize(200, 200)
sideImage:SetPoint("TOP", sidebar, "TOP", 0, -SIDE_GAP)
sideImage:Hide()

if sidebar.CreateMaskTexture and sideImage.AddMaskTexture then
    local sideImageMask = sidebar:CreateMaskTexture()
    sideImageMask:SetTexture(COVER_FADE_MASK_PATH)
    sideImageMask:SetAllPoints(sideImage)
    sideImage:AddMaskTexture(sideImageMask)
end

-- Sidebar: only the default (nothing hovered) text is centered; hovered options are top-to-bottom, left-aligned.
local SIDE_PLACEHOLDER = LightGrey .. (L.SIDEBAR_PLACEHOLDER or "Hover over an option to the left to see its description and settings.")
local sideDesc = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sideDesc:SetSize(200, 0)
sideDesc:SetPoint("CENTER", sidebar, "CENTER", 0, 0)
sideDesc:SetJustifyH("CENTER")
sideDesc:SetJustifyV("MIDDLE")
sideDesc:SetSpacing(4)
sideDesc:SetTextColor(0.67, 0.67, 0.67, 1)
sideDesc:SetWordWrap(true)
sideDesc:SetText(SIDE_PLACEHOLDER)

local sideReloadHint = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
sideReloadHint:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -20, SIDE_GAP)
sideReloadHint:SetJustifyH("RIGHT")
sideReloadHint:SetText(LightGrey .. (L.REQUIRES_RELOAD or "Requires UI reload") .. "|r")
sideReloadHint:SetWordWrap(true)
sideReloadHint:SetWidth(200)
sideReloadHint:Hide()

local sideContent = CreateFrame("Frame", "CP_SidebarContent", sidebar)
sideContent:SetSize(210, 120)
sideContent:Hide()

local function SetSidebarDefault()
    sideImage:Hide()
    sideDesc:ClearAllPoints()
    sideDesc:SetSize(200, 0)
    sideDesc:SetPoint("CENTER", sidebar, "CENTER", 0, 0)
    sideDesc:SetJustifyH("CENTER")
    sideDesc:SetJustifyV("MIDDLE")
    sideDesc:SetText(SIDE_PLACEHOLDER)
    sideReloadHint:Hide()
    sideContent:Hide()
end

local function ToggleSideImage(path)
    sideDesc:ClearAllPoints()
    sideDesc:SetJustifyH("LEFT")
    sideDesc:SetJustifyV("TOP")
    sideDesc:SetSize(200, 0)

    if path then
        sideImage:SetTexture(path)
        sideImage:Show()
        sideDesc:SetPoint("TOPLEFT", sideImage, "BOTTOMLEFT", 0, -SIDE_GAP)
    else
        sideImage:Hide()
        sideDesc:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 20, -SIDE_GAP)
    end
end

-- =========================
-- Main Scroll Area
-- =========================
local SCROLL_TOP_PADDING = 10
local scrollFrame = CreateFrame("ScrollFrame", "CP_MainScroll", frame)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -50 - SCROLL_TOP_PADDING)
scrollFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
scrollFrame:SetPoint("RIGHT", sidebar, "LEFT", -10, 0)
scrollFrame:EnableMouseWheel(true)

scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = self:GetVerticalScrollRange()
    local new = cur - (delta * 25)
    if new < 0 then new = 0 end
    if new > max then new = max end
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
-- Side Content Logic (Trinkets/Macros/Filters/Junk)
-- =========================

local function HideAllSideContent()
    if _G["CP_CarrotSlotLabel"] then
        _G["CP_CarrotSlotLabel"]:Hide()
        _G["CP_CarrotSlot_13"]:Hide()
        _G["CP_CarrotSlot_14"]:Hide()
    end
    if _G["CP_Preview_Food"] then
        for _, n in ipairs({ "Food", "Water", "Pot", "Mana", "Band" }) do
            if _G["CP_Preview_" .. n] then _G["CP_Preview_" .. n]:Hide() end
        end
    end
    local filters = { "CP_Filter_GuildRecruit", "CP_Filter_TradeBots", "CP_Filter_Gambling", "CP_Filter_Duplicates", "CP_Filter_RestedXP" }
    for _, name in ipairs(filters) do
        if _G[name] then _G[name]:Hide() end
    end
    
end

local function IsRetailClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function GetSmartMacroPreviewOrder()
    if IsRetailClient() then
        return { "Food", "Water", "Pot", "Mana" }
    end
    return { "Food", "Water", "Pot", "Mana", "Band" }
end

local function StyleMacroPreviewButton(button, iconTexture)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(iconTexture)
    button.icon = icon

    local shade = button:CreateTexture(nil, "BORDER")
    shade:SetAllPoints(icon)
    shade:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    shade:SetVertexColor(0, 0, 0, 0.18)
    button.shade = shade

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
    button.border = border

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    hover:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    hover:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    hover:SetVertexColor(1, 1, 1, 0.16)
    button:SetHighlightTexture(hover)
end

local function ShowCarrotSlots()
    HideAllSideContent()
    sideContent:ClearAllPoints()
    sideContent:SetPoint("TOPLEFT", sideDesc, "BOTTOMLEFT", 0, -SIDE_GAP)
    sideContent:Show()
    if not _G["CP_CarrotSlotLabel"] then
        local l = sideContent:CreateFontString("CP_CarrotSlotLabel", "OVERLAY", "GameFontHighlight")
        l:SetPoint("TOPLEFT", 0, 0)
        l:SetText(L.EQUIP_TO_SLOT or "Equip to Slot:")
        l:SetTextColor(0.67, 0.67, 0.67, 1)
        local function CreateSlotBtn(slot, name)
            local btn = CreateFrame("CheckButton", "CP_CarrotSlot_" .. slot, sideContent, "UIRadioButtonTemplate")
            btn:SetPoint("TOPLEFT", 0, -(22 * (slot - 12)))
            local t = _G[btn:GetName() .. "Text"]
            t:SetText(name)
            t:SetFontObject("GameFontHighlight")
            t:SetTextColor(0.67, 0.67, 0.67, 1)
            btn:SetScript("OnClick", function()
                CarpenterDB.autoCarrotSlot = slot
                _G["CP_CarrotSlot_13"]:SetChecked(slot == 13)
                _G["CP_CarrotSlot_14"]:SetChecked(slot == 14)
                UpdateReloadButton()
            end)
        end
        CreateSlotBtn(13, L.TRINKET_TOP or "Trinket 13 (Top)")
        CreateSlotBtn(14, L.TRINKET_BOTTOM or "Trinket 14 (Bottom)")
    end
    _G["CP_CarrotSlotLabel"]:Show()
    _G["CP_CarrotSlot_13"]:Show()
    _G["CP_CarrotSlot_14"]:Show()
    _G["CP_CarrotSlot_13"]:SetChecked(CarpenterDB.autoCarrotSlot == 13)
    _G["CP_CarrotSlot_14"]:SetChecked(CarpenterDB.autoCarrotSlot == 14)
end

local function ShowMacroPreviews()
    HideAllSideContent()
    sideContent:ClearAllPoints()
    sideContent:SetPoint("TOPLEFT", sideDesc, "BOTTOMLEFT", 0, -SIDE_GAP)
    sideContent:Show()
    if not _G["CP_Preview_Food"] then
        local icons = { Food = "Interface\\Icons\\Inv_Misc_Food_15", Water = "Interface\\Icons\\Inv_Drink_07", Pot =
        "Interface\\Icons\\Inv_Potion_51", Mana = "Interface\\Icons\\Inv_Potion_76", Band =
        "Interface\\Icons\\Inv_Misc_Bandage_08" }
        local order = GetSmartMacroPreviewOrder()
        local labels = { Food = L.FOOD or "Food", Water = L.WATER or "Water", Pot = L.HEALTH or "Health", Mana = L.MANA or "Mana", Band = L.BANDAGE or "Bandage" }
        local iconSize, spacing = 34, 12
        local totalWidth = (#order * iconSize) + ((#order - 1) * spacing)
        local startX = -(totalWidth / 2) + (iconSize / 2)
        local function CreatePreview(name, labelText, index)
            local p = CreateFrame("Button", "CP_Preview_" .. name, sideContent)
            p:SetSize(iconSize, iconSize)
            local xOffset = startX + ((index - 1) * (iconSize + spacing))
            p:SetPoint("CENTER", sideContent, "TOP", xOffset, -iconSize / 2)
            StyleMacroPreviewButton(p, icons[name])
            local l = p:CreateFontString(nil, "OVERLAY")
            l:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            l:SetPoint("TOP", p, "BOTTOM", 0, -4)
            l:SetTextColor(0.67, 0.67, 0.67, 1)
            l:SetText(labelText)
            p:RegisterForDrag("LeftButton")
            p:SetScript("OnDragStart", function()
                local mName = (name == "Pot") and "CarpenterHP" or "Carpenter" .. name
                local idx = GetMacroIndexByName(mName)
                if idx > 0 then PickupMacro(idx) end
            end)
        end
        for i, name in ipairs(order) do CreatePreview(name, labels[name], i) end
    end
    for _, n in ipairs({ "Food", "Water", "Pot", "Mana", "Band" }) do
        if _G["CP_Preview_" .. n] then _G["CP_Preview_" .. n]:Hide() end
    end
    for _, n in ipairs(GetSmartMacroPreviewOrder()) do _G["CP_Preview_" .. n]:Show() end
end

local function ShowSellJunkOptions()
    HideAllSideContent()
    sideContent:ClearAllPoints()
    sideContent:SetPoint("TOPLEFT", sideDesc, "BOTTOMLEFT", 0, -SIDE_GAP)
    sideContent:Show()
end

local function ShowFilterOptions()
    HideAllSideContent()
    sideContent:ClearAllPoints()
    sideContent:SetPoint("TOPLEFT", sideDesc, "BOTTOMLEFT", 0, -SIDE_GAP)
    sideContent:Show()
    if not _G["CP_Filter_GuildRecruit"] then
        local opts = {
            { key = "filterGuildRecruitEnabled", name = "CP_Filter_GuildRecruit", label = L.FILTER_GUILD_RECRUITMENT or "Guild recruitment" },
            { key = "filterTradeBotsEnabled", name = "CP_Filter_TradeBots", label = L.FILTER_BOT_SPAM or "Bot spam" },
            { key = "filterGamblingEnabled", name = "CP_Filter_Gambling", label = L.FILTER_GAMBLING or "Gambling" },
            { key = "filterDuplicatesEnabled", name = "CP_Filter_Duplicates", label = L.FILTER_DUPLICATES or "Duplicates" },
            { key = "filterRestedXPEnabled", name = "CP_Filter_RestedXP", label = L.FILTER_RESTEDXP or "RestedXP level-up spam" },
        }
        for i, opt in ipairs(opts) do
            local cb = CreateFrame("CheckButton", opt.name, sideContent, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
            _G[cb:GetName() .. "Text"]:SetText(opt.label)
            _G[cb:GetName() .. "Text"]:SetFontObject("GameFontHighlight")
            _G[cb:GetName() .. "Text"]:SetTextColor(0.67, 0.67, 0.67, 1)
            cb:SetScript("OnClick", function(self)
                if CarpenterDB then
                    CarpenterDB[opt.key] = self:GetChecked()
                    UpdateReloadButton()
                end
            end)
        end
    end
    local filters = { "CP_Filter_GuildRecruit", "CP_Filter_TradeBots", "CP_Filter_Gambling", "CP_Filter_Duplicates", "CP_Filter_RestedXP" }
    for _, name in ipairs(filters) do
        local key = name:gsub("CP_Filter_", "filter") .. "Enabled"
        if _G[name] then
            _G[name]:Show()
            _G[name]:SetChecked(CarpenterDB and CarpenterDB[key])
        end
    end
end

-- =========================
-- UI Component Helpers
-- =========================
local yPos = -10

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
            if onToggle then onToggle() end
        end
    end)

    yPos = yPos - 32
    return row
end

-- =========================
-- Populate Content
-- =========================

local OPTION_SECTIONS = {
    {
        title = L.SECTION_ACTION_BARS or "Action Bars",
        options = {
            {
                key = "hideMacroNamesEnabled",
                label = L.OPTION_HIDE_MACRO_NAMES or "Hide Macro Names",
                description = LightGrey .. "Macro labels can turn clean action bars into tiny text soup.\n\n" ..
                    "Hides " .. LighterCream .. "macro names" .. LightGrey .. " on action buttons so your bars stay icon-focused and easier to scan.",
                image = GetSettingsImage("macrotext.png"),
            },
            {
                key = "hideKeybindsEnabled",
                label = L.OPTION_HIDE_KEYBINDS or "Hide Keybind Text",
                description = LightGrey .. "Once your binds are muscle memory, hotkey text mostly gets in the way.\n\n" ..
                    "Hides " .. LighterCream .. "hotkey labels" .. LightGrey .. " on action buttons for quieter, cleaner bars.",
                image = GetSettingsImage("keybind.png"),
            },
            {
                key = "actionBarFaderEnabled",
                label = L.OPTION_ACTION_BAR_FADER or "Fade Extra Action Bars",
                description = LightGrey .. "Extra bars are useful, but they do not need to sit fully visible all the time.\n\n" ..
                    "Fades bars " .. LighterCream .. "7 and 8" .. LightGrey .. " until you hover them, then brings them back when you need a click.",
                image = GetSettingsImage("actionbar.png"),
            },
            {
                key = "actionBarRangeEnabled",
                label = L.OPTION_ACTION_BAR_RANGE or "Out of Range Tint",
                description = LightGrey .. "Range should be readable at a glance, especially when your target is moving.\n\n" ..
                    "Adds a subtle dark tint to " .. LighterCream .. "range-checked abilities" .. LightGrey .. " while your current target is out of range, then restores Blizzard's normal button look when you are close enough.",
                image = GetSettingsImage("range.png"),
                requiresReload = false,
            },
            {
                key = "hideStanceBarEnabled",
                label = L.OPTION_HIDE_STANCE_BAR or "Hide Stance Bar",
                description = LightGrey .. "The stance bar can duplicate buttons you already bind elsewhere.\n\n" ..
                    "Hides the " .. LighterCream .. "Stance Bar" .. LightGrey .. " for forms, stances, and stealth buttons, keeping the bar out of sight while your binds still work.",
                image = GetSettingsImage("stance.png"),
            },
        },
    },
    {
        title = L.SECTION_INTERFACE or "Interface",
        options = {
            {
                key = "menuTransparencyEnabled",
                label = L.OPTION_MENU_TRANSPARENCY or "Fade Micro Menu & Bags",
                description = LightGrey .. "The micro menu and bag buttons are useful, but not every second of every fight.\n\n" ..
                    "Fades the " .. LighterCream .. "Micro Menu" .. LightGrey .. " and " .. LighterCream .. "Bag Bar" .. LightGrey .. " until you hover them or open your bags.",
                image = GetSettingsImage("micromenu.png"),
            },
            {
                key = "smallerExpBarEnabled",
                label = L.OPTION_SMALLER_EXP_BAR or "Resize Exp & Rep Bars",
                description = LightGrey .. "Experience and reputation bars carry useful progress, but they can be visually loud.\n\n" ..
                    "Scales the " .. LighterCream .. "Experience" .. LightGrey .. " and " .. LighterCream .. "Reputation" .. LightGrey .. " bars to 65% and lowers their opacity.",
                image = GetSettingsImage("repbar.png"),
            },
            {
                key = "minimapClutterEnabled",
                label = L.OPTION_MINIMAP_CLUTTER or "Remove Minimap Clutter",
                description = LightGrey .. "The minimap works better when the frame around it stays quiet.\n\n" ..
                    "Hides the minimap " .. LighterCream .. "zoom buttons" .. LightGrey .. ", " .. LighterCream .. "day/night icon" .. LightGrey .. ", and " .. LighterCream .. "zone text bar" .. LightGrey .. " while keeping mousewheel zoom available.",
                image = GetSettingsImage("minimapclutter.png"),
            },
            {
                key = "enhanceTooltipEnabled",
                label = L.OPTION_ENHANCE_TOOLTIP or "Enhanced Tooltip",
                description = LightGrey .. "Default unit tooltips can be bulky for how often you read them.\n\n" ..
                    "Cleans up " .. LighterCream .. "unit tooltips" .. LightGrey .. " by hiding the health bar, recoloring name and level lines, and showing the unit's current target.",
                image = GetSettingsImage("tooltip.png"),
            },
            {
                key = "enhanceUIEnabled",
                label = L.OPTION_ENHANCE_UI or "Enhance UI",
                description = LightGrey .. "Some Classic interface panels are cramped for repeated use.\n\n" ..
                    "Expands the " .. LighterCream .. "quest log" .. LightGrey .. ", " .. LighterCream .. "professions" .. LightGrey .. ", and " .. LighterCream .. "trainer" .. LightGrey .. " frames, adds quest levels and a map button, adds a trainer " .. LighterCream .. "Train All" .. LightGrey .. " button, and cleans up the " .. LighterCream .. "flight map" .. LightGrey .. " with larger controls.",
                image = GetSettingsImage("tooltip.png"),
            },
            {
                key = "scaleExtraAbilityEnabled",
                label = L.OPTION_SCALE_EXTRA_ABILITY or "Scale Extra Ability",
                description = LightGrey .. "Retail's extra ability buttons can appear oversized compared with the rest of your UI.\n\n" ..
                    "Scales the " .. LighterCream .. "Extra Action" .. LightGrey .. " and " .. LighterCream .. "Zone Ability" .. LightGrey .. " buttons to " .. LighterCream .. "80%" .. LightGrey .. ".",
                image = GetSettingsImage("actionbar.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyExtraAbilityScale then Carpenter_ApplyExtraAbilityScale() end
                end,
            },
            {
                key = "hideBossFramesEnabled",
                label = L.OPTION_HIDE_BOSS_FRAMES or "Hide Boss Frames",
                description = LightGrey .. "Boss frames can duplicate information already covered by nameplates, raid frames, or boss mods.\n\n" ..
                    "Fades Retail " .. LighterCream .. "boss unit frames" .. LightGrey .. " and disables their mouse interaction.",
                image = GetSettingsImage("unitnumbers.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                end,
            },
        },
    },
    {
        title = L.SECTION_UNIT_FRAMES or "Unit Frames",
        options = {
            {
                key = "classHealthColorsEnabled",
                label = L.OPTION_CLASS_HEALTH_COLORS or "Class Colored Health",
                description = LightGrey .. "Green health bars are readable, but class color is faster to recognize.\n\n" ..
                    "Colors " .. LighterCream .. "player, target, focus, and party health bars" .. LightGrey .. " by class where class information is available.",
                image = GetSettingsImage("classhealthbar.png"),
            },
            {
                key = "threatIndicatorEnabled",
                label = L.OPTION_THREAT_INDICATOR or "Threat Percentage",
                description = LightGrey .. "Threat is easier to manage when the number is where your eyes already are.\n\n" ..
                    "Shows your " .. LighterCream .. "threat percentage" .. LightGrey .. " on the target frame so you can ease off, hold steady, or push with confidence.",
                image = GetSettingsImage("threat.png"),
            },
            {
                key = "unitFrameDebuffsEnabled",
                label = L.OPTION_DEBUFFS or "Debuffs",
                description = LightGrey .. "Crowd control should stand out from ordinary aura noise.\n\n" ..
                    "Highlights important " .. LighterCream .. "CC effects" .. LightGrey .. " such as stuns, polymorphs, fears, and similar debuffs on player and target unit frames.",
                image = GetSettingsImage("unitdebuff.png"),
            },
            {
                key = "unitFrameBuffsEnabled",
                label = L.OPTION_UNIT_FRAME_BUFFS or "Buffs",
                description = LightGrey .. "Your own cooldown buffs should be visible where your eyes already check your health.\n\n" ..
                    "Highlights important " .. LighterCream .. "player buffs" .. LightGrey .. " such as Sprint, Slice and Dice, defensive cooldowns, offensive cooldowns, and immunities on the player unit frame.",
                image = GetSettingsImage("unitdebuff.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_UpdateUnitFrameAuras then Carpenter_UpdateUnitFrameAuras() end
                end,
            },
            {
                key = "unitFrameClassIconEnabled",
                label = L.OPTION_CLASS_ICON_PORTRAIT or "Class Icon Portrait",
                description = LightGrey .. "Unit portraits are flavorful, but class icons are faster to parse.\n\n" ..
                    "Replaces player, target, and focus " .. LighterCream .. "portraits" .. LightGrey .. " with class icons. When Debuffs is enabled, CC effects can still take over the portrait as usual.",
                image = GetSettingsImage("classicon.png"),
            },
            {
                key = "hideUnitFrameCombatTextEnabled",
                label = L.OPTION_HIDE_UNIT_FRAME_COMBAT_TEXT or "Hide Unit Frame Combat Text",
                description = LightGrey .. "Combat text on unit portraits can compete with the information around the frame.\n\n" ..
                    "Hides " .. LighterCream .. "damage" .. LightGrey .. ", " .. LighterCream .. "healing" .. LightGrey .. ", " .. LighterCream .. "avoidance" .. LightGrey .. ", periodic numbers, and combat state messages on player and pet portrait frames.",
                image = GetSettingsImage("unitnumbers.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter:IsEnabled("hideUnitFrameCombatTextEnabled") then
                        if Carpenter_ApplyUnitFrameCombatText then Carpenter_ApplyUnitFrameCombatText() end
                    else
                        if Carpenter_RestoreUnitFrameCombatText then Carpenter_RestoreUnitFrameCombatText() end
                    end
                end,
            },
            {
                key = "cleanUpUnitFramesEnabled",
                label = L.OPTION_CLEAN_UP_UNIT_FRAMES or "Clean Unit Frame",
                description = LightGrey .. "Retail unit frames carry several small decorative markers around the core health and name information.\n\n" ..
                    "Hides " .. LighterCream .. "combat text" .. LightGrey .. ", " .. LighterCream .. "PvP icons" .. LightGrey .. ", the " .. LighterCream .. "combat sword" .. LightGrey .. ", " .. LighterCream .. "Zzz rest animation" .. LightGrey .. ", " .. LighterCream .. "health loss FX" .. LightGrey .. ", player " .. LighterCream .. "corner icon" .. LightGrey .. ", target " .. LighterCream .. "reputation color" .. LightGrey .. ", " .. LighterCream .. "party frame title text" .. LightGrey .. ", and " .. LighterCream .. "realm indicators" .. LightGrey .. ".",
                image = GetSettingsImage("unitnumbers.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                    if Carpenter:IsEnabled("cleanUpUnitFramesEnabled") then
                        if Carpenter_ApplyUnitFrameCombatText then Carpenter_ApplyUnitFrameCombatText() end
                    else
                        if Carpenter_RestoreUnitFrameCombatText then Carpenter_RestoreUnitFrameCombatText() end
                    end
                end,
            },
            {
                key = "hideUnitFramePowerBarEnabled",
                label = L.OPTION_HIDE_POWER_BAR or "Hide Combo/Power Bar",
                description = LightGrey .. "Some class resources are already shown better on your bars, nameplates, or custom UI.\n\n" ..
                    "Hides Retail " .. LighterCream .. "class resource widgets" .. LightGrey .. " such as combo points, runes, holy power, soul shards, arcane charges, essence, and the personal resource bar.",
                image = GetSettingsImage("nameplatecombo.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                end,
            },
            {
                key = "hideGroupIndicatorEnabled",
                label = L.OPTION_HIDE_GROUP_INDICATOR or "Hide Group Indicator",
                description = LightGrey .. "Hides the small " .. LighterCream .. "group number indicator" .. LightGrey .. " attached to the player frame.",
                image = GetSettingsImage("unitnumbers.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyRetailUnitFrameCleaner then Carpenter_ApplyRetailUnitFrameCleaner() end
                end,
            },
        },
    },
    {
        title = L.SECTION_NAMEPLATES or "Nameplates",
        options = {
            {
                key = "debuffTrackerEnabled",
                label = L.OPTION_DEBUFFS or "Debuffs",
                description = LightGrey .. "Crowd control on enemy nameplates should be visible without searching through tiny aura icons.\n\n" ..
                    "Shows important " .. LighterCream .. "CC effects" .. LightGrey .. " above enemy nameplates so you can see what is controlled at a glance.",
                image = GetSettingsImage("nameplatedebuff.png"),
            },
            {
                key = "nameplateComboEnabled",
                label = L.OPTION_COMBO_POINTS or "Combo Points",
                description = LightGrey .. "Combo points are easier to use when they sit on the thing you are attacking.\n\n" ..
                    "Displays your " .. LighterCream .. "combo points" .. LightGrey .. " on the target's nameplate for cleaner finisher timing.",
                image = GetSettingsImage("nameplatecombo.png"),
            },
            {
                key = "nameplateCastNamesEnabled",
                label = L.OPTION_CAST_BAR or "Cast Bar",
                description = LightGrey .. "Enemy casts need enough detail to act on quickly.\n\n" ..
                    "Adds a full " .. LighterCream .. "cast bar" .. LightGrey .. " below enemy nameplates with spell icon, spell name, progress, and interrupt feedback. Casts are gold, channels are green, and interrupted casts flash red.",
                image = GetSettingsImage("spellname.png"),
            },
            {
                key = "nameplateClassHealthEnabled",
                label = L.OPTION_CLASS_HEALTH_COLORS or "Class Colored Health",
                description = LightGrey .. "Enemy player nameplates are easier to read when class is visible in the bar itself.\n\n" ..
                    "Colors enemy player " .. LighterCream .. "nameplate health bars" .. LightGrey .. " by class, making healers, melee, and priority targets quicker to spot.",
                image = GetSettingsImage("classhealthnameplate.png"),
            },
            {
                key = "raidTargetIconAlignedEnabled",
                label = L.OPTION_RAID_TARGET_ICON_ALIGNED or "Raid Target Icon Aligned",
                description = LightGrey .. "Raid target icons can float awkwardly high above nameplates.\n\n" ..
                    "Moves " .. LighterCream .. "raid target icons" .. LightGrey .. " down so they sit closer to the nameplate they belong to.",
                image = GetSettingsImage("raidtarget.png"),
            },
        },
    },
    {
        title = L.SECTION_CHAT or "Chat",
        options = {
            {
                key = "chatFilterEnabled",
                label = L.OPTION_CHAT_FILTER or "Filter",
                description = LightGrey .. "Trade and general chat can get noisy fast.\n\n" ..
                    "Filters common " .. LighterCream .. "spam patterns" .. LightGrey .. " such as guild recruitment, bot ads, gambling messages, duplicate lines, and RestedXP level-up announcements.",
                sideLogic = ShowFilterOptions,
                image = GetSettingsImage("chatfilter.png"),
            },
            {
                key = "chatCleanerEnabled",
                label = L.OPTION_CHAT_CLEANER or "Cleaner",
                description = LightGrey .. "System messages are useful, but Blizzard's default formatting can be hard to scan.\n\n" ..
                    "Restyles " .. LighterCream .. "system and loot messages" .. LightGrey .. " for experience, reputation, money, learned abilities, currency, repairs, and similar events.",
                image = GetSettingsImage("chatcleaner.png"),
            },
            {
                key = "hideChatButtonsEnabled",
                label = L.OPTION_HIDE_CHAT_BUTTONS or "Hide Chat Buttons",
                description = LightGrey .. "Chat buttons are handy, but they do not need to frame the chat box all day.\n\n" ..
                    "Fades default " .. LighterCream .. "chat buttons" .. LightGrey .. " such as Social, Chat Channels, and Voice until you hover the chat area.",
                image = GetSettingsImage("chatbuttons.png"),
            },
        },
    },
    {
        title = L.SECTION_AUTOMATIONS or "Automations",
        options = {
            {
                key = "autoCarrotEnabled",
                label = L.OPTION_MOUNT_SPEED_TRINKET or "Mount Speed Trinket",
                description = LightGrey .. "Mount speed trinkets are useful, but manual swapping gets old quickly.\n\n" ..
                    "Equips " .. LighterCream .. "Riding Crop" .. LightGrey .. " if available, otherwise " .. LighterCream .. "Carrot on a Stick" .. LightGrey .. ", when you mount. Your previous trinket is restored when you dismount.",
                sideLogic = ShowCarrotSlots,
                image = GetSettingsImage("carrot.png"),
            },
            {
                key = "smartMacrosEnabled",
                label = L.OPTION_CONSUMABLE_MACROS or "Consumable Macros",
                description = LightGrey .. "Consumable buttons are better when they follow your bags automatically.\n\n" ..
                    "Creates draggable macros for your best available " .. LighterCream .. "food" .. LightGrey .. ", " .. LighterCream .. "water" .. LightGrey .. ", " .. LighterCream .. "health potion" .. LightGrey .. ", " .. LighterCream .. "mana potion" .. LightGrey .. ", and supported bandages.",
                sideLogic = ShowMacroPreviews,
                image = GetSettingsImage("macro.png"),
            },
            {
                key = "autoTrackQuestsEnabled",
                label = L.OPTION_AUTO_TRACK_QUESTS or "Auto Track Quests",
                description = LightGrey .. "New quests should land in the tracker without an extra trip to the quest log.\n\n" ..
                    "Automatically adds " .. LighterCream .. "newly accepted quests" .. LightGrey .. " to the objective tracker.",
                image = GetSettingsImage("questtrack.png"),
                requiresReload = false,
            },
            {
                key = "autoSellGreys",
                label = L.OPTION_AUTO_SELL_JUNK or "Auto Sell Junk",
                description = LightGrey .. "Grey items are vendor trash by design.\n\n" ..
                    "Sells " .. LighterCream .. "grey-quality items" .. LightGrey .. " when you open a merchant. Hold " .. LighterCream .. "Shift" .. LightGrey .. " while opening the merchant to skip the sale.",
                sideLogic = ShowSellJunkOptions,
                image = GetSettingsImage("selljunk.png"),
            },
            {
                key = "autoRepair",
                label = L.OPTION_AUTO_REPAIR or "Auto Repair",
                description = LightGrey .. "Repairing is easy to forget until your gear makes it your problem.\n\n" ..
                    "Repairs your " .. LighterCream .. "gear" .. LightGrey .. " with your gold when you open a repair vendor. Hold " .. LighterCream .. "Shift" .. LightGrey .. " while opening the vendor to skip repair.",
                image = GetSettingsImage("repair.png"),
            },
        },
    },
    {
        title = L.SECTION_TEXT or "Text",
        options = {
            {
                key = "enchantWarningEnabled",
                label = L.OPTION_POISON_WARNING or "Poison Warning",
                description = LightGrey .. "Weapon buffs are easy to miss when they fall off mid-session.\n\n" ..
                    "Shows an alert when your " .. LighterCream .. "weapon buff" .. LightGrey .. " such as poison or sharpening stone is missing or about to expire.",
                image = GetSettingsImage("warning.png"),
            },
            {
                key = "hideErrorMessagesEnabled",
                label = L.OPTION_HIDE_ERROR_MESSAGES or "Hide Error Messages",
                description = LightGrey .. "Repeated red error text can become visual noise during combat.\n\n" ..
                    "Silences common " .. LighterCream .. "ability errors" .. LightGrey .. " such as Out of range and Not enough energy while leaving important errors visible.",
                image = GetSettingsImage("error.png"),
            },
        },
    },
    {
        title = L.SECTION_SETTINGS or "Settings",
        options = {
            {
                key = "classicSettingsPresetEnabled",
                label = L.OPTION_SETTINGS_PRESET or "Preset",
                description = LightGrey .. "A quick Classic baseline for fresh characters or clients.\n\n" ..
                    "Turns on " .. LighterCream .. "auto loot" .. LightGrey .. ", " .. LighterCream .. "enemy unit and minion nameplates" .. LightGrey .. ", and " .. LighterCream .. "action bars 2 and 3" .. LightGrey .. ". Carpenter reapplies these settings when you log in while the preset is enabled.",
                image = GetSettingsImage("actionbar.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyClassicSettingsPreset then Carpenter_ApplyClassicSettingsPreset() end
                end,
            },
        },
    },
    {
        title = L.SECTION_IMMERSION or "Immersion",
        options = {
            {
                key = "actionCamEnabled",
                label = L.OPTION_ACTION_CAM or "Action Cam",
                description = LightGrey .. "A small camera shift can make the world feel less like a spreadsheet with dragons.\n\n" ..
                    "Uses a DynamicCam-style " .. LighterCream .. "over-the-shoulder camera" .. LightGrey .. " with vertical pitch, a wider mounted zoom, and adjusted Retail spell activation overlays.",
                image = GetSettingsImage("actioncam.png"),
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyActionCam then Carpenter_ApplyActionCam() end
                end,
            },
        },
    },
}

local visibleSectionCount = 0

for _, section in ipairs(OPTION_SECTIONS) do
    local hasAvailableOptions = false
    for _, option in ipairs(section.options) do
        if Carpenter:IsFeatureAvailable(option.key) then
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
            if Carpenter:IsFeatureAvailable(option.key) then
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
footerVersion:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, yPos)
footerVersion:SetText(LightGrey .. "v1.4.2|r")

-- Match sidebar: footer ends with same bottom spacing as "Requires UI reload" (SIDE_GAP)
local FOOTER_LINE_HEIGHT = 14
content:SetHeight(-yPos + FOOTER_LINE_HEIGHT + SIDE_GAP)

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
