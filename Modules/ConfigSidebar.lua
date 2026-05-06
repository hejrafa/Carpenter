--[[ Carpenter - Config sidebar helpers ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Sidebar = ns.Private.ConfigSidebar or {}
ns.Private.ConfigSidebar = Sidebar

function Sidebar.Create(context)
    context = context or {}
    local frame = context.Frame
    local L = context.L or {}
    local LightGrey = context.LightGrey or "|cffaaaaaa"
    local LighterCream = context.LighterCream or "|cffffff99"
    local COVER_FADE_MASK_PATH = context.CoverFadeMaskPath
    local UpdateReloadButton = context.UpdateReloadButton or function() end

    -- =========================
    -- Persistent Sidebar
    -- =========================
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetSize(240, 0)
    sidebar:SetPoint("TOPRIGHT", -10, -60)
    sidebar:SetPoint("BOTTOMRIGHT", -10, 10)

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


    return {
        Frame = sidebar,
        Description = sideDesc,
        ReloadHint = sideReloadHint,
        Content = sideContent,
        SetDefault = SetSidebarDefault,
        ToggleImage = ToggleSideImage,
        ShowCarrotSlots = ShowCarrotSlots,
        ShowMacroPreviews = ShowMacroPreviews,
        ShowSellJunkOptions = ShowSellJunkOptions,
        ShowFilterOptions = ShowFilterOptions,
        SideGap = SIDE_GAP,
    }
end
