--[[ Carpenter - Enhance UI ]]
-- Classic-only expansions for quest log, professions, trainers, and flight map.

local function IsEnabled()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic and Carpenter:IsEnabled("enhanceUIEnabled")
end

local function OnAddonLoaded(addonName, callback)
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName) then
        callback()
        return
    end
    if IsAddOnLoaded and IsAddOnLoaded(addonName) then
        callback()
        return
    end
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded(addonName, callback)
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, _, loaded)
        if loaded == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            callback()
        end
    end)
end

local function AddInset(parent, point, width, height, texture)
    if not parent or parent._CarpenterEnhanceInsets then return end
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(width, height)
    tex:SetPoint(unpack(point))
    tex:SetTexture(texture)
    return tex
end

local function AddFrameShell(parent)
    if not parent or parent._CarpenterEnhanceShell then return end
    local shell = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    shell:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
    shell:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -14)
    shell:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -34, 48)
    shell:SetVertexColor(0.18, 0.16, 0.13, 1)
    parent._CarpenterEnhanceShell = shell
end

local function Move(frame, ...)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint(...)
end

local function HideRegions(frame, ...)
    if not frame or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    for _, index in ipairs({ ... }) do
        if regions[index] and regions[index].Hide then
            regions[index]:Hide()
        end
    end
end

local addonName = ...
local CLASSIC_WIDE_FRAME_TEXTURE = "Interface\\AddOns\\" .. (addonName or "Carpenter") .. "\\Art\\Frames\\ClassicWideFrame"

local function ApplyLeatrixWideFrameArt(frame, leftRegionIndex, rightRegionIndex, hideRegionIndexes)
    if not frame or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    local left = regions[leftRegionIndex]
    local right = regions[rightRegionIndex]

    if left and left.SetTexture and left.SetTexCoord then
        left:SetSize(512, 512)
        left:SetTexture(CLASSIC_WIDE_FRAME_TEXTURE)
        left:SetTexCoord(0.25, 0.75, 0, 0.5)
    end

    if right and right.SetTexture and right.SetTexCoord then
        right:ClearAllPoints()
        right:SetPoint("TOPLEFT", left or frame, left and "TOPRIGHT" or "TOPLEFT", 0, 0)
        right:SetSize(256, 512)
        right:SetTexture(CLASSIC_WIDE_FRAME_TEXTURE)
        right:SetTexCoord(0.75, 1, 0, 0.5)
    end

    for _, index in ipairs(hideRegionIndexes or {}) do
        if regions[index] and regions[index].Hide then
            regions[index]:Hide()
        end
    end
end

local function AddRows(parent, prefix, displayedGlobal, template, extraRows)
    if not parent or parent._CarpenterEnhancedRows then return end
    local current = _G[displayedGlobal]
    if not current then return end

    for i = 2, current do
        if _G[prefix .. i] and _G[prefix .. (i - 1)] then
            Move(_G[prefix .. i], "TOPLEFT", _G[prefix .. (i - 1)], "BOTTOMLEFT", 0, 1)
        end
    end

    local old = current
    _G[displayedGlobal] = current + extraRows
    for i = old + 1, _G[displayedGlobal] do
        local previous = _G[prefix .. (i - 1)]
        if previous and not _G[prefix .. i] then
            local button = CreateFrame("Button", prefix .. i, parent, template)
            button:SetID(i)
            button:Hide()
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 1)
        end
    end
    parent._CarpenterEnhancedRows = true
end

local function QuestSuffix(suggestedGroup)
    if suggestedGroup == LFG_TYPE_DUNGEON then return "D" end
    if suggestedGroup == RAID then return "R" end
    if suggestedGroup == PVP then return "P" end
    if suggestedGroup == ELITE or suggestedGroup == GROUP then return "+" end
    return ""
end

local function ApplyQuestLevels()
    if not IsEnabled() or not QuestLogListScrollFrame then return end
    local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    if numEntries == 0 then return end
    for i = 1, (_G.QUESTS_DISPLAYED or 0) do
        local button = _G["QuestLogTitle" .. i]
        if button then
            local questIndex = i + (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0)
            if questIndex <= numEntries then
                local title, level, suggestedGroup, isHeader = GetQuestLogTitle(questIndex)
                if title and level and not isHeader then
                    button:SetText(string.format("  [%d%s] %s", level, QuestSuffix(suggestedGroup), title))
                    local check = _G["QuestLogTitle" .. i .. "Check"]
                    local text = _G["QuestLogTitle" .. i .. "NormalText"]
                    if check and text then
                        check:SetPoint("LEFT", button, "LEFT", math.min(text:GetStringWidth() + 24, 210), 0)
                    end
                end
            end
        end
    end
end

local function ApplyQuestLog()
    if not IsEnabled() or not QuestLogFrame or QuestLogFrame._CarpenterEnhancedUI then return end
    QuestLogFrame._CarpenterEnhancedUI = true

    local tall = 73
    UIPanelWindows["QuestLogFrame"] = { area = "override", pushable = 0, xoffset = -16, yoffset = 12, bottomClampOverride = 152, width = 685, height = 560, whileDead = 1 }
    QuestLogFrame:SetSize(714, 487 + tall)
    AddFrameShell(QuestLogFrame)
    Move(QuestLogTitleText, "TOP", QuestLogFrame, "TOP", 0, -18)
    Move(QuestLogDetailScrollFrame, "TOPLEFT", QuestLogListScrollFrame, "TOPRIGHT", 31, 1)
    QuestLogDetailScrollFrame:SetHeight(336 + tall)
    QuestLogListScrollFrame:SetHeight(336 + tall)
    AddRows(QuestLogFrame, "QuestLogTitle", "QUESTS_DISPLAYED", "QuestLogTitleButtonTemplate", 21)

    ApplyLeatrixWideFrameArt(QuestLogFrame, 3, 4, { 5, 6 })
    QuestLogFrameAbandonButton:SetSize(110, 21)
    QuestLogFrameAbandonButton:SetText(ABANDON_QUEST_ABBREV)
    Move(QuestLogFrameAbandonButton, "BOTTOMLEFT", QuestLogFrame, "BOTTOMLEFT", 17, 54)
    QuestFramePushQuestButton:SetSize(100, 21)
    QuestFramePushQuestButton:SetText(SHARE_QUEST_ABBREV)
    Move(QuestFramePushQuestButton, "LEFT", QuestLogFrameAbandonButton, "RIGHT", -3, 0)
    QuestFrameExitButton:SetSize(80, 22)
    QuestFrameExitButton:SetText(CLOSE)
    Move(QuestFrameExitButton, "BOTTOMRIGHT", QuestLogFrame, "BOTTOMRIGHT", -42, 54)

    if not _G.CarpenterQuestLogMapButton then
        local mapButton = CreateFrame("Button", "CarpenterQuestLogMapButton", QuestLogFrame, "UIPanelButtonTemplate")
        mapButton:SetText(WORLD_MAP or "Map")
        mapButton:SetSize(100, 21)
        mapButton:SetPoint("LEFT", QuestFramePushQuestButton, "RIGHT", -3, 0)
        mapButton:SetScript("OnClick", ToggleWorldMap)
    end

    if QuestLogNoQuestsText then
        Move(QuestLogNoQuestsText, "TOP", QuestLogListScrollFrame, 0, -50)
    end
    if EmptyQuestLogFrame then
        hooksecurefunc(EmptyQuestLogFrame, "Show", function()
            Move(EmptyQuestLogFrame, "BOTTOMLEFT", QuestLogFrame, "BOTTOMLEFT", 20, -76)
            EmptyQuestLogFrame:SetHeight(487)
        end)
    end

    hooksecurefunc("QuestLog_UpdateQuestDetails", function()
        if not IsEnabled() then return end
        local quest = GetQuestLogSelection and GetQuestLogSelection()
        if not quest then return end
        local title, level, suggestedGroup = GetQuestLogTitle(quest)
        if title and level and QuestLogQuestTitle then
            QuestLogQuestTitle:SetText(string.format("[%d%s] %s", level, QuestSuffix(suggestedGroup), title))
        end
    end)
    hooksecurefunc("QuestLog_Update", ApplyQuestLevels)
    ApplyQuestLevels()
end

local function ApplyTradeSkill()
    if not IsEnabled() or not TradeSkillFrame or TradeSkillFrame._CarpenterEnhancedUI then return end
    TradeSkillFrame._CarpenterEnhancedUI = true

    local tall = 73
    UIPanelWindows["TradeSkillFrame"] = { area = "override", pushable = 1, xoffset = -16, yoffset = 12, bottomClampOverride = 152, width = 685, height = 560, whileDead = 1 }
    TradeSkillFrame:SetSize(714, 487 + tall)
    AddFrameShell(TradeSkillFrame)
    Move(TradeSkillFrameTitleText, "TOP", TradeSkillFrame, "TOP", 0, -18)
    Move(TradeSkillListScrollFrame, "TOPLEFT", TradeSkillFrame, "TOPLEFT", 25, -75)
    TradeSkillListScrollFrame:SetSize(295, 336 + tall)
    AddRows(TradeSkillFrame, "TradeSkillSkill", "TRADE_SKILLS_DISPLAYED", "TradeSkillSkillButtonTemplate", 19)
    Move(TradeSkillDetailScrollFrame, "TOPLEFT", TradeSkillFrame, "TOPLEFT", 352, -74)
    TradeSkillDetailScrollFrame:SetSize(298, 336 + tall)
    if TradeSkillDetailScrollFrameTop then TradeSkillDetailScrollFrameTop:SetAlpha(0) end
    if TradeSkillDetailScrollFrameBottom then TradeSkillDetailScrollFrameBottom:SetAlpha(0) end
    if TradeSkillExpandTabLeft then TradeSkillExpandTabLeft:Hide() end
    ApplyLeatrixWideFrameArt(TradeSkillFrame, 2, 3, { 4, 5, 9, 10 })
    AddInset(TradeSkillFrame, { "TOPLEFT", TradeSkillFrame, "TOPLEFT", 16, -72 }, 304, 361 + tall, "Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg")
    AddInset(TradeSkillFrame, { "TOPLEFT", TradeSkillFrame, "TOPLEFT", 348, -72 }, 302, 339 + tall, "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated")
    TradeSkillFrame._CarpenterEnhanceInsets = true
    Move(TradeSkillCreateButton, "RIGHT", TradeSkillCancelButton, "LEFT", -1, 0)
    TradeSkillCancelButton:SetSize(80, 22)
    TradeSkillCancelButton:SetText(CLOSE)
    Move(TradeSkillCancelButton, "BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -42, 54)
    Move(TradeSkillFrameCloseButton, "TOPRIGHT", TradeSkillFrame, "TOPRIGHT", -30, -8)
    Move(TradeSkillInvSlotDropdown, "TOPLEFT", TradeSkillFrame, "TOPLEFT", 550, -42)
    Move(TradeSkillSubClassDropdown, "RIGHT", TradeSkillInvSlotDropdown, "LEFT", -10, 0)
    hooksecurefunc(TradeSkillHighlightFrame, "Show", function() TradeSkillHighlightFrame:SetWidth(290) end)
end

local function ApplyCraft()
    if not IsEnabled() or not CraftFrame or CraftFrame._CarpenterEnhancedUI then return end
    CraftFrame._CarpenterEnhancedUI = true

    local tall = 73
    UIPanelWindows["CraftFrame"] = { area = "override", pushable = 1, xoffset = -16, yoffset = 12, bottomClampOverride = 152, width = 685, height = 560, whileDead = 1 }
    CraftFrame:SetSize(714, 487 + tall)
    AddFrameShell(CraftFrame)
    Move(CraftFrameTitleText, "TOP", CraftFrame, "TOP", 0, -18)
    Move(CraftListScrollFrame, "TOPLEFT", CraftFrame, "TOPLEFT", 25, -75)
    CraftListScrollFrame:SetSize(295, 336 + tall)
    AddRows(CraftFrame, "Craft", "CRAFTS_DISPLAYED", "CraftButtonTemplate", 19)
    Move(CraftDetailScrollFrame, "TOPLEFT", CraftFrame, "TOPLEFT", 352, -74)
    CraftDetailScrollFrame:SetSize(298, 336 + tall)
    if CraftDetailScrollFrameTop then CraftDetailScrollFrameTop:SetAlpha(0) end
    if CraftDetailScrollFrameBottom then CraftDetailScrollFrameBottom:SetAlpha(0) end
    if CraftExpandTabLeft then CraftExpandTabLeft:Hide() end
    ApplyLeatrixWideFrameArt(CraftFrame, 2, 3, { 4, 5, 9, 10 })
    AddInset(CraftFrame, { "TOPLEFT", CraftFrame, "TOPLEFT", 16, -72 }, 304, 361 + tall, "Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg")
    AddInset(CraftFrame, { "TOPLEFT", CraftFrame, "TOPLEFT", 348, -72 }, 302, 339 + tall, "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated")
    CraftFrame._CarpenterEnhanceInsets = true
    Move(CraftCreateButton, "RIGHT", CraftCancelButton, "LEFT", -1, 0)
    CraftCancelButton:SetSize(80, 22)
    CraftCancelButton:SetText(CLOSE)
    Move(CraftCancelButton, "BOTTOMRIGHT", CraftFrame, "BOTTOMRIGHT", -42, 54)
    Move(CraftFrameCloseButton, "TOPRIGHT", CraftFrame, "TOPRIGHT", -30, -8)
    hooksecurefunc(CraftHighlightFrame, "Show", function() CraftHighlightFrame:SetWidth(290) end)
    hooksecurefunc("CraftFrame_Update", function()
        for i = 1, (_G.CRAFTS_DISPLAYED or 0) do
            local cost = _G["Craft" .. i .. "Cost"]
            if cost then cost:SetPoint("RIGHT", -30, 0) end
        end
    end)
end

local function UpdateTrainAllButton(button)
    if not button or not GetNumTrainerServices then return end
    local available = false
    for i = 1, GetNumTrainerServices() do
        local _, _, state = GetTrainerServiceInfo(i)
        if state == "available" then
            available = true
            break
        end
    end
    button:SetEnabled(available)
end

local function ApplyTrainer()
    if not IsEnabled() or not ClassTrainerFrame or ClassTrainerFrame._CarpenterEnhancedUI then return end
    ClassTrainerFrame._CarpenterEnhancedUI = true

    local tall = 73
    local extraRows = 17
    local baseRows = _G.CLASS_TRAINER_SKILLS_DISPLAYED or 0
    UIPanelWindows["ClassTrainerFrame"] = { area = "override", pushable = 0, xoffset = -16, yoffset = 12, bottomClampOverride = 152, width = 685, height = 560, whileDead = 1 }
    ClassTrainerFrame:SetSize(714, 487 + tall)
    AddFrameShell(ClassTrainerFrame)
    Move(ClassTrainerNameText, "TOP", ClassTrainerFrame, "TOP", 0, -18)
    Move(ClassTrainerListScrollFrame, "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 25, -75)
    ClassTrainerListScrollFrame:SetSize(295, 336 + tall)
    AddRows(ClassTrainerFrame, "ClassTrainerSkill", "CLASS_TRAINER_SKILLS_DISPLAYED", "ClassTrainerSkillButtonTemplate", extraRows)
    Move(ClassTrainerDetailScrollFrame, "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 352, -74)
    ClassTrainerDetailScrollFrame:SetSize(296, 336 + tall)
    if ClassTrainerDetailScrollFrameTop then ClassTrainerDetailScrollFrameTop:SetAlpha(0) end
    if ClassTrainerDetailScrollFrameBottom then ClassTrainerDetailScrollFrameBottom:SetAlpha(0) end
    if ClassTrainerExpandTabLeft then ClassTrainerExpandTabLeft:Hide() end
    if ClassTrainerHorizontalBarLeft then ClassTrainerHorizontalBarLeft:Hide() end
    ApplyLeatrixWideFrameArt(ClassTrainerFrame, 2, 3, { 4, 5, 9 })
    AddInset(ClassTrainerFrame, { "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 16, -72 }, 304, 361 + tall, "Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg")
    AddInset(ClassTrainerFrame, { "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 348, -72 }, 302, 339 + tall, "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated")
    ClassTrainerFrame._CarpenterEnhanceInsets = true
    Move(ClassTrainerTrainButton, "RIGHT", ClassTrainerCancelButton, "LEFT", -1, 0)
    ClassTrainerCancelButton:SetSize(80, 22)
    ClassTrainerCancelButton:SetText(CLOSE)
    Move(ClassTrainerCancelButton, "BOTTOMRIGHT", ClassTrainerFrame, "BOTTOMRIGHT", -42, 54)
    Move(ClassTrainerFrameCloseButton, "TOPRIGHT", ClassTrainerFrame, "TOPRIGHT", -30, -8)
    if ClassTrainerFrame.FilterDropdown then
        Move(ClassTrainerFrame.FilterDropdown, "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 576, -44)
    end
    if ClassTrainerMoneyFrame then Move(ClassTrainerMoneyFrame, "TOPLEFT", ClassTrainerFrame, "TOPLEFT", 143, -49) end
    if ClassTrainerGreetingText then ClassTrainerGreetingText:Hide() end
    hooksecurefunc(ClassTrainerSkillHighlightFrame, "Show", function() ClassTrainerSkillHighlightFrame:SetWidth(290) end)

    local function RestoreTrainerScrollArea(rowOffset)
        if not IsEnabled() then return end
        _G.CLASS_TRAINER_SKILLS_DISPLAYED = baseRows + extraRows + (rowOffset or 0)
        ClassTrainerListScrollFrame:SetHeight(336 + tall)
        ClassTrainerDetailScrollFrame:SetHeight(336 + tall)
    end

    if type(ClassTrainer_SetToTradeSkillTrainer) == "function" then
        hooksecurefunc("ClassTrainer_SetToTradeSkillTrainer", function()
            RestoreTrainerScrollArea(0)
        end)
    end
    if type(ClassTrainer_SetToClassTrainer) == "function" then
        hooksecurefunc("ClassTrainer_SetToClassTrainer", function()
            RestoreTrainerScrollArea(-1)
        end)
    end
    RestoreTrainerScrollArea(0)

    local trainAll = CreateFrame("Button", "CarpenterTrainAllButton", ClassTrainerFrame, "UIPanelButtonTemplate")
    trainAll:SetText("Train All")
    trainAll:SetSize(100, 22)
    trainAll:SetPoint("BOTTOMLEFT", ClassTrainerFrame, "BOTTOMLEFT", 344, 54)
    trainAll:SetScript("OnEnter", function(self)
        local count, cost = 0, 0
        for i = 1, GetNumTrainerServices() do
            local _, _, state = GetTrainerServiceInfo(i)
            if state == "available" then
                count = count + 1
                cost = cost + (GetTrainerServiceCost(i) or 0)
            end
        end
        if count > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
            GameTooltip:SetText("Train " .. count .. " " .. (count == 1 and "skill" or "skills") .. " for " .. GetCoinTextureString(cost))
            GameTooltip:Show()
        end
    end)
    trainAll:SetScript("OnLeave", GameTooltip_Hide)
    trainAll:SetScript("OnClick", function()
        for i = 1, GetNumTrainerServices() do
            local _, _, state = GetTrainerServiceInfo(i)
            if state == "available" then
                BuyTrainerService(i)
            end
        end
    end)
    hooksecurefunc("ClassTrainerFrame_Update", function() UpdateTrainAllButton(trainAll) end)
    UpdateTrainAllButton(trainAll)
end

local function ApplyFlightMap()
    if not IsEnabled() or not TaxiFrame or TaxiFrame._CarpenterEnhancedUI then return end
    TaxiFrame._CarpenterEnhancedUI = true

    HideRegions(TaxiFrame, 2, 3, 4, 5)
    if TaxiPortrait then TaxiPortrait:Hide() end
    if TaxiMerchant then TaxiMerchant:Hide() end
    TaxiFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    TaxiFrame:SetScale(1.9)
    TaxiFrame:SetClampedToScreen(true)
    TaxiFrame:SetClampRectInsets(200, -200, -300, 300)
    if TaxiCloseButton and TaxiRouteMap then
        TaxiCloseButton:SetIgnoreParentScale(true)
        Move(TaxiCloseButton, "TOPRIGHT", TaxiRouteMap, "TOPRIGHT", 0, 0)
    end

    local border = TaxiFrame:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
    border:SetPoint("TOPLEFT", 18, -73)
    border:SetPoint("BOTTOMRIGHT", -45, 83)

    local function ResizeTaxiButtons()
        for i = 1, (NUM_TAXI_BUTTONS or 0) do
            local button = _G["TaxiButton" .. i]
            if button and button:IsVisible() then
                button:SetSize(12, 12)
                if button:GetHighlightTexture() then button:GetHighlightTexture():SetSize(24, 24) end
                if button:GetPushedTexture() then button:GetPushedTexture():SetSize(24, 24) end
            end
        end
    end
    TaxiFrame:HookScript("OnShow", ResizeTaxiButtons)

    TaxiFrame:RegisterForDrag("LeftButton")
    TaxiFrame:SetMovable(true)
    TaxiFrame:HookScript("OnDragStart", function(self)
        if IsAltKeyDown() then self:StartMoving() end
    end)
    TaxiFrame:HookScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

local function Apply()
    if not IsEnabled() then return end
    ApplyQuestLog()
    ApplyFlightMap()
    OnAddonLoaded("Blizzard_TradeSkillUI", ApplyTradeSkill)
    OnAddonLoaded("Blizzard_CraftUI", ApplyCraft)
    OnAddonLoaded("Blizzard_TrainerUI", ApplyTrainer)
end

Carpenter_ApplyEnhanceUI = Apply

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    Apply()
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
