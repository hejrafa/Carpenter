--[[ Carpenter - Smart Macro tooltip reader ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Tooltip = ns.Private.SmartMacroTooltip or {}
ns.Private.SmartMacroTooltip = Tooltip

local Data = ns.Private.SmartMacroData or {}
local TOOLTIP_KEYWORDS = Data.TooltipKeywords or {}

local GetItemSpell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell

local scanTooltip = CreateFrame("GameTooltip", "CP_SmartMacroScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsRetail()
    return Data.IsRetail and Data.IsRetail()
end

local function ContainsAny(text, hints)
    if not text or text == "" or not hints then return false end
    for _, hint in ipairs(hints) do
        if text:find(hint, 1, true) then return true end
    end
    return false
end

local function AddTooltipLine(result, line)
    if not line or line == "" then return end
    local text = line:lower()
    result.text = result.text .. " " .. text
    local hasUse = ContainsAny(text, TOOLTIP_KEYWORDS.use)
    local hasRestore = ContainsAny(text, TOOLTIP_KEYWORDS.health) or ContainsAny(text, TOOLTIP_KEYWORDS.mana)
    if hasUse then
        result.awaitingUseText = true
    end
    if not result.useText and hasRestore and (hasUse or result.awaitingUseText) then
        result.useText = text
    end
    if result.awaitingUseText and text ~= "" and not hasUse then
        result.awaitingUseText = false
    end
    if not result.isFoodAndDrink and ContainsAny(text, TOOLTIP_KEYWORDS.foodAndDrink) then
        result.isFoodAndDrink = true
    end
    if ContainsAny(text, TOOLTIP_KEYWORDS.conjured) then
        result.isConjured = true
    end
end

local function Read(bag, slot, item)
    local result = {
        text = "",
        useText = nil,
        awaitingUseText = false,
        isFoodAndDrink = false,
        isConjured = false,
    }

    if item and item.link and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local tooltipData = C_TooltipInfo.GetHyperlink(item.link, nil, nil, true)
        if tooltipData and tooltipData.lines then
            for i = 2, #tooltipData.lines do
                local line = tooltipData.lines[i]
                if IsRetail() and line then
                    AddTooltipLine(result, line.leftText)
                    AddTooltipLine(result, line.rightText)
                elseif line and line.type == 0 then
                    AddTooltipLine(result, line.leftText)
                end
            end
            if result.text ~= "" or not IsRetail() then
                return result
            end
        end
    end

    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)

    for i = 1, scanTooltip:NumLines() do
        local left = _G["CP_SmartMacroScanTooltipTextLeft" .. i]
        local right = _G["CP_SmartMacroScanTooltipTextRight" .. i]
        AddTooltipLine(result, left and left:GetText())
        AddTooltipLine(result, right and right:GetText())
    end

    return result
end

local function GetSpellText(item)
    if not GetItemSpell or not item then return "" end
    local spellName = GetItemSpell(item.link or item.itemID or "")
    return spellName and spellName:lower() or ""
end

Tooltip.ContainsAny = ContainsAny
Tooltip.Read = Read
Tooltip.GetSpellText = GetSpellText
