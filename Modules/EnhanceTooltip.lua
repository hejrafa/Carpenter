--[[ Carpenter - Enhance Tooltip ]]
-- When enabled: hides the health bar, recolors name/info lines, shows unit target.

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("enhanceTooltipEnabled")
end

local function HideStatusBar(bar)
    if not bar or bar._CarpenterHiding then return end

    bar._CarpenterHiding = true
    if bar.SetAlpha then
        bar:SetAlpha(0)
    end
    if bar.Hide then
        bar:Hide()
    end

    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if texture and texture.SetAlpha then
        texture:SetAlpha(0)
    end
    bar._CarpenterHiding = nil
end

local function HookStatusBar(bar)
    if not bar or bar._CarpenterTooltipStatusBarHooked then return end

    if bar.Show then
        hooksecurefunc(bar, "Show", function(self)
            if IsEnabled() then
                HideStatusBar(self)
            end
        end)
    end
    if bar.SetAlpha then
        hooksecurefunc(bar, "SetAlpha", function(self)
            if IsEnabled() then
                HideStatusBar(self)
            end
        end)
    end

    bar._CarpenterTooltipStatusBarHooked = true
end

local function HideTooltipHealthBar(tooltip)
    local bars = {}
    local function AddBar(bar)
        if bar then
            bars[#bars + 1] = bar
        end
    end

    AddBar(_G["GameTooltipStatusBar"])
    AddBar(tooltip and tooltip.StatusBar)
    AddBar(tooltip and tooltip.statusBar)

    for _, bar in ipairs(bars) do
        HookStatusBar(bar)
        HideStatusBar(bar)
    end

    if tooltip then
        local children = { tooltip:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
                HookStatusBar(child)
                HideStatusBar(child)
            end
        end
    end
end

local LEVEL_STR = (type(LEVEL) == "string" and LEVEL) or "Level"
local locale = GetLocale()
local isRuRU = (locale == "ruRU")

local function UsesProtectedTooltipStrings()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

local function CanAccessValue(value)
    if type(canaccessvalue) == "function" then
        return canaccessvalue(value)
    end
    return true
end

local function CanAccessTooltipText()
    if not UsesProtectedTooltipStrings() then return true end
    local ok, text = pcall(function()
        return GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    end)
    if not ok then return false end
    return text ~= nil and CanAccessValue(text)
end

local function GetClassColorHex(unit)
    if not RAID_CLASS_COLORS or not UnitIsPlayer(unit) then return nil end
    local _, classToken = UnitClass(unit)
    local c = classToken and RAID_CLASS_COLORS[classToken]
    if not c then return nil end
    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

-- Name line (line 1): players/friendly in class or PvP color; dead in grey; hostile mobs red/tap-denied blue
local function ApplyNameLine(tooltip, unit)
    local left1 = _G["GameTooltipTextLeft1"]
    if not left1 then return end

    local tipIsPlayer = UnitIsPlayer(unit)
    local playerControl = UnitPlayerControlled(unit)
    local reaction = UnitReaction(unit, "player") or 0
    local dead = UnitIsDeadOrGhost(unit)

    if dead then
        left1:SetTextColor(0.53, 0.53, 0.53)
        return
    end

    -- Player, or friendly (reaction > 4), or player-controlled
    if tipIsPlayer or playerControl or reaction > 4 then
        if tipIsPlayer then
            local _, classToken = UnitClass(unit)
            local c = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if c then
                left1:SetTextColor(c.r, c.g, c.b)
            else
                left1:SetTextColor(1, 1, 1)
            end
        else
            if UnitIsPVP(unit) then
                left1:SetTextColor(0, 1, 0)
            else
                left1:SetTextColor(0, 0.67, 1)
            end
        end
        return
    end

    -- Hostile mob (not player, reaction < 4, not player control)
    if not tipIsPlayer and reaction < 4 and not playerControl then
        if UnitIsTapDenied(unit) then
            left1:SetTextColor(0.53, 0.53, 0.73)
        else
            left1:SetTextColor(1, 0.2, 0.2)
        end
    end
end

-- Player info line (level, race, class) - find line 2/3 that looks like the info line and replace
local function ApplyPlayerInfoLine(tooltip, unit)
    local className, classToken = UnitClass(unit)  -- className = localized (e.g. "Warrior"), classToken = "WARRIOR"
    local classColor = GetClassColorHex(unit) or "|cffffffff"
    local race = UnitRace(unit)
    local unitLevel = UnitLevel(unit)
    local levelColor = GetCreatureDifficultyColor(unitLevel)
    local levelHex = levelColor and string.format("%02x%02x%02x", levelColor.r * 255, levelColor.g * 255, levelColor.b * 255) or "ffffffff"

    local levelPart
    if unitLevel == -1 then
        levelPart = "|cffff3333" .. LEVEL_STR .. " ??|r"
    else
        levelPart = "|cff" .. levelHex .. LEVEL_STR .. " " .. unitLevel .. "|r"
    end

    local infoText
    if isRuRU then
        infoText = ""
        if race then infoText = infoText .. race .. ", " end
        infoText = infoText .. classColor .. (className or "") .. "|r "
        infoText = infoText .. levelPart
    else
        infoText = levelPart
        if race then infoText = infoText .. " " .. race end
        infoText = infoText .. " " .. classColor .. (className or "") .. "|r"
    end

    -- Find which line has the level/class info (usually line 2)
    for i = 2, 4 do
        local line = _G["GameTooltipTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            if text ~= "" and (text:lower():find(LEVEL_STR:lower()) or text:find(className or "")) then
                line:SetText(infoText)
                return
            end
        end
    end
end

-- Mob level line (level + creature type + classification)
local function ApplyMobLevelLine(tooltip, unit)
    if UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return end
    local reaction = UnitReaction(unit, "player") or 0
    if reaction >= 5 then return end
    if not UnitCanAttack(unit, "player") then return end

    local unitLevel = UnitLevel(unit)
    local levelColor = GetCreatureDifficultyColor(unitLevel)
    local levelHex = levelColor and string.format("%02x%02x%02x", levelColor.r * 255, levelColor.g * 255, levelColor.b * 255) or "ffffffff"
    local creatureType = UnitCreatureType(unit)
    local classification = UnitClassification(unit)

    local levelPart
    if unitLevel == -1 then
        levelPart = "|cffff3333" .. LEVEL_STR .. " ??|r "
    else
        levelPart = "|cff" .. levelHex .. LEVEL_STR .. " " .. unitLevel .. "|r "
    end

    local typePart = ""
    if creatureType and creatureType ~= "Not specified" then
        typePart = "|cffffffff" .. creatureType .. "|r "
    end

    local specPart = ""
    if classification and classification ~= "normal" then
        if classification == "elite" then specPart = "(" .. (type(ELITE) == "string" and ELITE or "Elite") .. ") "
        elseif classification == "rare" then specPart = "|cff00e066(Rare)|r "
        elseif classification == "rareelite" then specPart = "|cff00e066(Rare Elite)|r "
        elseif classification == "worldboss" then specPart = "(" .. (type(BOSS) == "string" and BOSS or "Boss") .. ") "
        else specPart = "(" .. tostring(classification) .. ") "
        end
    end

    local infoText = levelPart .. typePart .. specPart

    for i = 2, 4 do
        local line = _G["GameTooltipTextLeft" .. i]
        if line then
            local text = (line:GetText() or ""):lower()
            if text:find(LEVEL_STR:lower()) then
                line:SetText(infoText)
                return
            end
        end
    end
end

local TARGET_PREFIX = "Target: "
local TARGET_YOU = "YOU"

local function TooltipAlreadyHasTargetLine()
    for i = 1, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            if text:find("^Target: ") then return true end
        end
    end
    return false
end

local function ShowUnitTargetInTooltip(tooltip, unit)
    if not unit then return end
    local targetUnit = unit .. "target"

    if TooltipAlreadyHasTargetLine() then return end

    local ok, line = pcall(function()
        local name = UnitName(targetUnit)
        if not CanAccessValue(name) then return nil end
        if not name or name == "" then return nil end

        local displayText
        if UnitIsUnit(targetUnit, "player") then
            displayText = "|cffff4400" .. TARGET_YOU .. "|r"
        elseif UnitIsPlayer(targetUnit) and RAID_CLASS_COLORS then
            local _, classToken = UnitClass(targetUnit)
            local color = classToken and RAID_CLASS_COLORS[classToken]
            if color then
                local hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                displayText = hex .. name .. "|r"
            else
                displayText = name
            end
        else
            displayText = name
        end

        return TARGET_PREFIX .. displayText
    end)

    if ok and line then
        tooltip:AddLine(line)
    end
end

local function EnhanceUnitTooltip(tooltip, unit)
    if not unit then return end
    HideTooltipHealthBar(tooltip)
    ApplyNameLine(tooltip, unit)
    if UnitIsPlayer(unit) then
        ApplyPlayerInfoLine(tooltip, unit)
    else
        local reaction = UnitReaction(unit, "player") or 0
        if reaction < 5 and not UnitPlayerControlled(unit) and UnitCanAttack(unit, "player") then
            ApplyMobLevelLine(tooltip, unit)
        end
    end
    ShowUnitTargetInTooltip(tooltip, unit)
end

-- Match Leatrix Plus: world hover uses "mouseover", else GetUnit.
-- WorldFrame:EnableMouseMotion(true) so world hover triggers unit tooltips.
local function ShowTip(self)
    if not IsEnabled() then return end
    -- Only enhance the main GameTooltip (avoid affecting LibDBIcon and other tooltips)
    if self ~= GameTooltip then return end
    if not CanAccessTooltipText() then return end
    -- Do not modify tooltip when it is showing an item (e.g. merchant); avoids comparison tooltip flicker
    if self.GetItem then
        local _, itemLink = self:GetItem()
        if itemLink and itemLink ~= "" then return end
    end
    local unit
    if WorldFrame and WorldFrame.IsMouseMotionFocus and WorldFrame:IsMouseMotionFocus() then
        unit = "mouseover"
    else
        -- Leatrix uses select(2, GameTooltip:GetUnit()); support both one and two return values
        unit = (self.GetUnit and select(2, self:GetUnit())) or (self.GetUnit and self:GetUnit())
    end
    if not unit then return end
    local reaction = UnitReaction(unit, "player")
    if not reaction then return end
    EnhanceUnitTooltip(self, unit)
end

local hooked = false
local function InstallHooks()
    if not GameTooltip then return end
    if WorldFrame and WorldFrame.EnableMouseMotion then
        WorldFrame:EnableMouseMotion(true)
    end
    if not hooked then
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
                ShowTip(tooltip)
            end)
        elseif GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetUnit") then
            GameTooltip:HookScript("OnTooltipSetUnit", ShowTip)
        else
            GameTooltip:HookScript("OnShow", ShowTip)
        end
        hooked = true
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Carpenter" then
            InstallHooks()
        end
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        InstallHooks()
    end
end)
