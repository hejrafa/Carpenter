--[[ Carpenter - Sleek Options UI Configuration ]]
local addonName = ...
local ADDON_IMAGE_PATH = "Interface\\AddOns\\" .. (addonName or "Carpenter") .. "\\Images\\"
local frame = CreateFrame("Frame", "CarpenterOptionsPanel", UIParent)
frame.name = "Carpenter"

-- Version check: TBC uses interface 20505, Vanilla uses 11508
local _, _, _, interfaceVersion = GetBuildInfo()
local isTBC = interfaceVersion >= 20000

-- Feature availability map: maps config key to whether it's available in current version
-- TBC-only features: menuTransparencyEnabled, smallerExpBarEnabled
-- All other features are available in both Vanilla and TBC
local function IsFeatureAvailable(configKey)
    if configKey == "menuTransparencyEnabled" or configKey == "smallerExpBarEnabled" then
        return isTBC
    end
    return true -- All other features available in both versions
end

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(frame, "Carpenter")
    Settings.RegisterAddOnCategory(category)
else
    InterfaceOptions_AddCategory(frame)
end

function Carpenter_OpenConfig()
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
title:SetText("Carpenter")

local reloadBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reloadBtn:SetSize(90, 22)
reloadBtn:SetPoint("TOPRIGHT", -30, -15)
reloadBtn:SetText("Reload UI")
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

-- Sidebar: only the default (nothing hovered) text is centered; hovered options are top-to-bottom, left-aligned.
local SIDE_PLACEHOLDER = LightGrey .. "Hover over an option to the left to see its description and settings."
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
sideReloadHint:SetText(LightGrey .. "Requires UI reload|r")
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
        for _, n in ipairs({ "Food", "Water", "Pot", "Mana", "Band" }) do _G["CP_Preview_" .. n]:Hide() end
    end
    local filters = { "CP_Filter_GuildRecruit", "CP_Filter_TradeBots", "CP_Filter_Gambling", "CP_Filter_Duplicates", "CP_Filter_RestedXP" }
    for _, name in ipairs(filters) do
        if _G[name] then _G[name]:Hide() end
    end
    
end

local function ShowCarrotSlots()
    HideAllSideContent()
    sideContent:ClearAllPoints()
    sideContent:SetPoint("TOPLEFT", sideDesc, "BOTTOMLEFT", 0, -SIDE_GAP)
    sideContent:Show()
    if not _G["CP_CarrotSlotLabel"] then
        local l = sideContent:CreateFontString("CP_CarrotSlotLabel", "OVERLAY", "GameFontHighlight")
        l:SetPoint("TOPLEFT", 0, 0)
        l:SetText("Equip to Slot:")
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
        CreateSlotBtn(13, "Trinket 13 (Top)")
        CreateSlotBtn(14, "Trinket 14 (Bottom)")
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
        local order = { "Food", "Water", "Pot", "Mana", "Band" }
        local labels = { Food = "Food", Water = "Water", Pot = "Health", Mana = "Mana", Band = "Bandage" }
        local iconSize, spacing = 26, 12
        local totalWidth = (#order * iconSize) + ((#order - 1) * spacing)
        local startX = -(totalWidth / 2) + (iconSize / 2)
        local function CreatePreview(name, labelText, index)
            local p = CreateFrame("CheckButton", "CP_Preview_" .. name, sideContent, "ActionButtonTemplate")
            p:SetSize(iconSize, iconSize)
            local xOffset = startX + ((index - 1) * (iconSize + spacing))
            p:SetPoint("CENTER", sideContent, "TOP", xOffset, -iconSize / 2)
            _G[p:GetName() .. "Border"]:Hide()
            if _G[p:GetName() .. "FloatingBG"] then _G[p:GetName() .. "FloatingBG"]:Hide() end
            p:GetNormalTexture():SetAlpha(0)
            p.icon = _G[p:GetName() .. "Icon"]
            p.icon:SetTexture(icons[name])
            p.icon:SetAllPoints(p)
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
    for _, n in ipairs({ "Food", "Water", "Pot", "Mana", "Band" }) do _G["CP_Preview_" .. n]:Show() end
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
            { key = "filterGuildRecruitEnabled", name = "CP_Filter_GuildRecruit", label = "Guild recruitment" },
            { key = "filterTradeBotsEnabled", name = "CP_Filter_TradeBots", label = "Bot spam" },
            { key = "filterGamblingEnabled", name = "CP_Filter_Gambling", label = "Gambling" },
            { key = "filterDuplicatesEnabled", name = "CP_Filter_Duplicates", label = "Duplicates" },
            { key = "filterRestedXPEnabled", name = "CP_Filter_RestedXP", label = "RestedXP level-up spam" },
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
        title = "Action Bars",
        options = {
            {
                key = "hideMacroNamesEnabled",
                label = "Hide Macro Names",
                description = LightGrey .. "Your action bars don't need to be a wall of text.\n\n" ..
                    "Hides " .. LighterCream .. "macro names" .. LightGrey .. " so your bars are clean and focused. Icons speak louder than words.",
                image = ADDON_IMAGE_PATH .. "macrotext.png",
            },
            {
                key = "hideKeybindsEnabled",
                label = "Hide Keybind Text",
                description = LightGrey .. "You already know your keybinds. Why is the game still showing them?\n\n" ..
                    "Hides " .. LighterCream .. "hotkey labels" .. LightGrey .. " so you see icons, not text. Clean bars for players who know what they're doing.",
                image = ADDON_IMAGE_PATH .. "keybind.png",
            },
            {
                key = "actionBarFaderEnabled",
                label = "Fade Extra Action Bars",
                description = LightGrey .. "Bars 7 and 8 are always there, even when you don't need them.\n\n" ..
                    "Hides bars " .. LighterCream .. "7 and 8" .. LightGrey .. " until you hover. They fade back when you need them - out of sight, ready when called.",
                image = ADDON_IMAGE_PATH .. "actionbar.png",
            },
            {
                key = "actionBarRangeEnabled",
                label = "Out of Range Tint",
                description = LightGrey .. "Knowing exactly when an ability is in range shouldn't require guessing.\n\n" ..
                    "Tints all " .. LighterCream .. "range-checked abilities" .. LightGrey .. " on your action bars with a subtle dark overlay whenever your current target is out of range, then restores Blizzard's normal look when you step back into range.",
                image = ADDON_IMAGE_PATH .. "range.png",
                requiresReload = false,
            },
            {
                key = "hideStanceBarEnabled",
                label = "Hide Stance Bar",
                description = LightGrey .. "The stance bar takes up space you could use for something better.\n\n" ..
                    "Hides the " .. LighterCream .. "Stance Bar" .. LightGrey .. " (" .. LighterCream .. "Druid forms" .. LightGrey .. ", " .. LighterCream .. "Warrior stances" .. LightGrey .. ", " .. LighterCream .. "Rogue stealth" .. LightGrey .. "). Out of sight, still accessible when you need it.",
                image = ADDON_IMAGE_PATH .. "stance.png",
            },
        },
    },
    {
        title = "Interface",
        options = {
            {
                key = "menuTransparencyEnabled",
                label = "Fade Micro Menu & Bags",
                description = LightGrey .. "Why are the micro-menu and bags always visible? You know where they are.\n\n" ..
                    "Hides the " .. LighterCream .. "Micro-Menu" .. LightGrey .. " and " .. LighterCream .. "Bags" .. LightGrey .. " until you hover. Or just open your bags - they'll show up. Clean UI until you need them.",
                image = ADDON_IMAGE_PATH .. "micromenu.png",
            },
            {
                key = "smallerExpBarEnabled",
                label = "Resize Exp & Rep Bars",
                description = LightGrey .. "Those exp and rep bars are way too big. They don't need to dominate your screen.\n\n" ..
                    "Resizes the " .. LighterCream .. "Experience" .. LightGrey .. " and " .. LighterCream .. "Reputation" .. LightGrey .. " bars to 65% and makes them transparent. Less clutter, more game.",
                image = ADDON_IMAGE_PATH .. "repbar.png",
            },
            {
                key = "minimapClutterEnabled",
                label = "Remove Minimap Clutter",
                description = LightGrey .. "Your minimap is doing way too much. Zoom buttons, a glowing sun/moon, and a big zone label all fighting for your attention.\n\n" ..
                    "Hides the minimap " .. LighterCream .. "zoom buttons" .. LightGrey .. ", the " .. LighterCream .. "day/night icon" .. LightGrey .. ", and the " .. LighterCream .. "zone text bar" .. LightGrey .. ". A clean, quiet minimap that still does its job without shouting.",
                image = ADDON_IMAGE_PATH .. "minimapclutter.png",
            },
            {
                key = "enhanceTooltipEnabled",
                label = "Enhanced Tooltip",
                description = LightGrey .. "Default unit tooltips waste space and bury the information you actually care about.\n\n" ..
                    "Rebuilds the " .. LighterCream .. "unit tooltip" .. LightGrey .. ": hides the bulky " .. LighterCream .. "health bar" .. LightGrey .. ", recolors " .. LighterCream .. "name and level lines" .. LightGrey .. ", and shows who your target is focusing. Clean, readable tooltips that tell you what matters.",
                image = ADDON_IMAGE_PATH .. "tooltip.png",
            },
        },
    },
    {
        title = "Unit Frames",
        options = {
            {
                key = "classHealthColorsEnabled",
                label = "Class Colored Health",
                description = LightGrey .. "Everything is green. Your health, your party's health, everything. Boring.\n\n" ..
                    "Replaces green health bars with your " .. LighterCream .. "class color" .. LightGrey .. " on player, target, and party frames. Consistent colors throughout your UI - finally, some personality.",
                image = ADDON_IMAGE_PATH .. "classhealthbar.png",
            },
            {
                key = "threatIndicatorEnabled",
                label = "Threat Percentage",
                description = LightGrey .. "Playing threat roulette in raids is not a strategy.\n\n" ..
                    "Shows your " .. LighterCream .. "threat percentage" .. LightGrey .. " on the target frame. Know exactly when to ease off or go all out. No more guessing.",
                image = ADDON_IMAGE_PATH .. "threat.png",
            },
            {
                key = "unitFrameDebuffsEnabled",
                label = "Debuffs",
                description = LightGrey .. "Important debuffs blend into the noise. You shouldn't have to hunt for them.\n\n" ..
                    "Highlights " .. LighterCream .. "CC" .. LightGrey .. " (" .. LighterCream .. "Stuns" .. LightGrey .. ", " .. LighterCream .. "Poly" .. LightGrey .. ", etc.) on player and target unit frames. Never miss a crowd control effect again.",
                image = ADDON_IMAGE_PATH .. "unitdebuff.png",
            },
            {
                key = "unitFrameClassIconEnabled",
                label = "Class Icon Portrait",
                description = LightGrey .. "Replace the player, target, and focus frame " .. LighterCream .. "portrait" .. LightGrey .. " with the unit's " .. LighterCream .. "class icon" .. LightGrey .. " (same circular mask). When Debuffs is enabled, CC still replaces the portrait as usual.",
                image = ADDON_IMAGE_PATH .. "classicon.png",
            },
            {
                key = "hideUnitFrameCombatTextEnabled",
                label = "Hide Unit Frame Combat Text",
                description = LightGrey .. "Floating combat text near your player and pet frames can get in the way.\n\n" ..
                    "Hides " .. LighterCream .. "damage" .. LightGrey .. ", " .. LighterCream .. "healing" .. LightGrey .. ", " .. LighterCream .. "dodge" .. LightGrey .. ", " .. LighterCream .. "miss" .. LightGrey .. ", " .. LighterCream .. "parry" .. LightGrey .. ", periodic numbers, and combat state messages on the player and pet portrait frames. Cleaner unit frames, less visual noise.",
                image = ADDON_IMAGE_PATH .. "unitnumbers.png",
                requiresReload = false,
                onToggle = function()
                    if Carpenter_ApplyUnitFrameCombatText then Carpenter_ApplyUnitFrameCombatText() end
                    if Carpenter_RestoreUnitFrameCombatText then Carpenter_RestoreUnitFrameCombatText() end
                end,
            },
        },
    },
    {
        title = "Nameplates",
        options = {
            {
                key = "debuffTrackerEnabled",
                label = "Debuffs",
                description = LightGrey .. "What's affecting that enemy? Who knows. The game isn't telling you.\n\n" ..
                    "Shows " .. LighterCream .. "CC" .. LightGrey .. " (" .. LighterCream .. "Stuns" .. LightGrey .. ", " .. LighterCream .. "Poly" .. LightGrey .. ", etc.) above enemy nameplates. See what's affecting your targets at a glance.",
                image = ADDON_IMAGE_PATH .. "nameplatedebuff.png",
            },
            {
                key = "nameplateComboEnabled",
                label = "Combo Points",
                description = LightGrey .. "Your eyes darting between your combo points and your target mid-fight. There's a better way.\n\n" ..
                    "Displays your " .. LighterCream .. "Combo Points" .. LightGrey .. " on the target's nameplate. Perfect for rogues and druids tracking finishers. Keep your eyes where they matter.",
                image = ADDON_IMAGE_PATH .. "nameplatecombo.png",
            },
            {
                key = "nameplateCastNamesEnabled",
                label = "Cast Bar",
                description = LightGrey .. "That enemy is casting something. What is it? How long do you have?\n\n" ..
                    "Adds a full " .. LighterCream .. "cast bar" .. LightGrey .. " below enemy nameplates — " .. LighterCream .. "spell icon" .. LightGrey .. ", " .. LighterCream .. "spell name" .. LightGrey .. ", " .. LighterCream .. "progress bar" .. LightGrey .. ", and " .. LighterCream .. "spark glow" .. LightGrey .. ". Color-coded: " .. LighterCream .. "gold" .. LightGrey .. " for casts, " .. LighterCream .. "green" .. LightGrey .. " for channels, " .. LighterCream .. "red" .. LightGrey .. " on interrupt. Identical to the unit frame cast bar.",
                image = ADDON_IMAGE_PATH .. "spellname.png",
            },
            {
                key = "nameplateClassHealthEnabled",
                label = "Class Colored Health",
                description = LightGrey .. "Every enemy health bar is the same flat green. In chaotic fights, nothing stands out.\n\n" ..
                    "Colors enemy player nameplate health bars with their " .. LighterCream .. "class color" .. LightGrey .. ". Instantly spot healers, melee, and priority targets just by the bar color.",
                image = ADDON_IMAGE_PATH .. "classhealthnameplate.png",
            },
            {
                key = "raidTargetIconAlignedEnabled",
                label = "Raid Target Icon Aligned",
                description = LightGrey .. "With nameplates on, the raid target icons (skull, star, etc.) float too high above the bar.\n\n" ..
                    "Moves the " .. LighterCream .. "raid target icon" .. LightGrey .. " down so it sits on the same level as the nameplate. Cleaner and easier to read.",
                image = ADDON_IMAGE_PATH .. "raidtarget.png",
            },
        },
    },
    {
        title = "Chat",
        options = {
            {
                key = "chatFilterEnabled",
                label = "Filter",
                description = LightGrey .. "Your chat is a spam dumpster. Guild recruitment, bots, gambling - it never stops.",
                sideLogic = ShowFilterOptions,
                image = ADDON_IMAGE_PATH .. "chatfilter.png",
            },
            {
                key = "chatCleanerEnabled",
                label = "Cleaner",
                description = LightGrey .. "System messages look like they were designed in 2004. Because they were.\n\n" ..
                    "Restyles " .. LighterCream .. "system and loot messages" .. LightGrey .. " in chat (" .. LighterCream .. "exp" .. LightGrey .. ", " .. LighterCream .. "rep" .. LightGrey .. ", " .. LighterCream .. "money" .. LightGrey .. ", " .. LighterCream .. "learned" .. LightGrey .. ", etc.). Clean, readable notifications that don't hurt your eyes.",
                image = ADDON_IMAGE_PATH .. "chatcleaner.png",
            },
            {
                key = "hideChatButtonsEnabled",
                label = "Hide Chat Buttons",
                description = LightGrey .. "Those chat buttons? You've clicked them maybe twice. Ever.\n\n" ..
                    "Hides the default " .. LighterCream .. "chat buttons" .. LightGrey .. " like " .. LighterCream .. "Social" .. LightGrey .. ", " .. LighterCream .. "Chat Channels" .. LightGrey .. ", and " .. LighterCream .. "Voice" .. LightGrey .. ". They reappear when you hover - out of the way until you need them.",
                image = ADDON_IMAGE_PATH .. "chatbuttons.png",
            },
        },
    },
    {
        title = "Automations",
        options = {
            {
                key = "autoCarrotEnabled",
                label = "Mount Speed Trinket",
                description = LightGrey .. "Swapping trinkets every mount and dismount gets old fast.\n\n" ..
                    "Equips a mount speed trinket in your chosen slot when you mount: " .. LighterCream .. "Riding Crop" .. LightGrey .. " (10%) if you have it, otherwise " .. LighterCream .. "Carrot on a Stick" .. LightGrey .. " (3%). Swaps back automatically when you dismount.",
                sideLogic = ShowCarrotSlots,
                image = ADDON_IMAGE_PATH .. "carrot.png",
            },
            {
                key = "smartMacrosEnabled",
                label = "Consumable Macros",
                description = LightGrey .. "Digging through your bags for the right consumable mid-combat is not ideal.\n\n" ..
                    "Creates macros that use your " .. LighterCream .. "best consumable" .. LightGrey .. " (" .. LighterCream .. "food" .. LightGrey .. ", " .. LighterCream .. "water" .. LightGrey .. ", " .. LighterCream .. "pot" .. LightGrey .. ", " .. LighterCream .. "bandage" .. LightGrey .. "). Drag them onto your action bars and go. Always uses the best you have.",
                sideLogic = ShowMacroPreviews,
                image = ADDON_IMAGE_PATH .. "macro.png",
            },
            {
                key = "autoSellGreys",
                label = "Auto Sell Junk",
                description = LightGrey .. "Selling grey items one by one is busywork, not gameplay.\n\n" ..
                    "Sells " .. LighterCream .. "grey-quality items" .. LightGrey .. " to the vendor when you open a merchant. Hold " .. LighterCream .. "Shift" .. LightGrey .. " to skip - you're in control. More time playing, less time managing inventory.",
                sideLogic = ShowSellJunkOptions,
                image = ADDON_IMAGE_PATH .. "selljunk.png",
            },
            {
                key = "autoRepair",
                label = "Auto Repair",
                description = LightGrey .. "You forgot to repair again. Now your gear is broken mid-raid. Naturally.\n\n" ..
                    "Repairs your " .. LighterCream .. "gear" .. LightGrey .. " with your gold when you talk to a repair vendor. Hold " .. LighterCream .. "Shift" .. LightGrey .. " to skip - save that gold for something else. Never worry about broken gear again.",
                image = ADDON_IMAGE_PATH .. "repair.png",
            },
        },
    },
    {
        title = "Text",
        options = {
            {
                key = "enchantWarningEnabled",
                label = "Poison Warning",
                description = LightGrey .. "Your weapon buff expired five minutes ago. You had no idea.\n\n" ..
                    "Shows an alert when your " .. LighterCream .. "weapon buff" .. LightGrey .. " (" .. LighterCream .. "poison" .. LightGrey .. ", " .. LighterCream .. "stone" .. LightGrey .. ") is about to expire. Never get caught unbuffed again. Stay sharp.",
                image = ADDON_IMAGE_PATH .. "warning.png",
            },
            {
                key = "hideErrorMessagesEnabled",
                label = "Hide Error Messages",
                description = LightGrey .. "Red error text in the middle of your screen yelling \"Out of range\" or \"Not enough energy\" every few seconds isn't helping.\n\n" ..
                    "Silences common " .. LighterCream .. "ability error messages" .. LightGrey .. " like " .. LighterCream .. "Out of range" .. LightGrey .. ", " .. LighterCream .. "Not enough energy" .. LightGrey .. ", and more, while leaving important errors alone. Quieter combat, same control.",
                image = ADDON_IMAGE_PATH .. "error.png",
            },
        },
    },
    {
        title = "Immersion",
        options = {
            {
                key = "actionCamEnabled",
                label = "Action Cam",
                description = LightGrey .. "Your character deserves a proper close-up.\n\n" ..
                    "Shifts the camera over your shoulder for a " .. LighterCream .. "cinematic" .. LightGrey .. " view - like you're right there in the action instead of floating behind. The camera tilts and follows more naturally when you move and fly. Turn it on, run around, and see the world from a fresh angle.",
                image = ADDON_IMAGE_PATH .. "actioncam.png",
                requiresReload = false,
            },
        },
    },
}

for sectionIndex, section in ipairs(OPTION_SECTIONS) do
    if sectionIndex > 1 then
        yPos = yPos - 24
    end

    CreateHeader(section.title)

    for _, option in ipairs(section.options) do
        if IsFeatureAvailable(option.key) then
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

-- =========================
-- Footer
-- =========================
yPos = yPos - 48
local footerCredit = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footerCredit:SetPoint("TOPLEFT", 10, yPos)
footerCredit:SetText(LightGrey .. "Created by Rafa - " .. "|cff00aaffhejrafa.com|r")

local footerVersion = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footerVersion:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, yPos)
footerVersion:SetText(LightGrey .. "v1.4.0|r")

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
