--[[ Carpenter - Enhance Tooltip ]]
-- When enabled: hides the health bar, recolors name/info lines, shows unit target.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local L = (Carpenter and Carpenter.L) or (ns and ns.L) or {}
local Unit = ns.Private.Unit or {}

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
        Carpenter:SafeHook(bar, "Show", function(self)
            if IsEnabled() then
                HideStatusBar(self)
            end
        end)
    end
    if bar.SetShown then
        Carpenter:SafeHook(bar, "SetShown", function(self)
            if IsEnabled() then
                HideStatusBar(self)
            end
        end)
    end
    if bar.SetAlpha then
        Carpenter:SafeHook(bar, "SetAlpha", function(self)
            if IsEnabled() then
                HideStatusBar(self)
            end
        end)
    end
    if bar.SetValue then
        Carpenter:SafeHook(bar, "SetValue", function(self)
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

local function ShowStatusBar(bar)
    if not bar then return end
    if bar.SetAlpha then
        bar:SetAlpha(1)
    end
    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if texture and texture.SetAlpha then
        texture:SetAlpha(1)
    end
end

local function RestoreTooltipHealthBar(tooltip)
    ShowStatusBar(_G["GameTooltipStatusBar"])
    ShowStatusBar(tooltip and tooltip.StatusBar)
    ShowStatusBar(tooltip and tooltip.statusBar)

    if tooltip then
        local children = { tooltip:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
                ShowStatusBar(child)
            end
        end
    end
end

local function ScheduleHideTooltipHealthBar(tooltip)
    HideTooltipHealthBar(tooltip)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            HideTooltipHealthBar(tooltip)
        end)
        C_Timer.After(0.05, function()
            HideTooltipHealthBar(tooltip)
        end)
    end
end

local LEVEL_STR = (type(LEVEL) == "string" and LEVEL) or "Level"
local locale = GetLocale()
local isRuRU = (locale == "ruRU")

local function UsesProtectedTooltipStrings()
    return Carpenter and Carpenter.Client and Carpenter.Client.isMainline
end

local function CanAccessValue(value)
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        return ok and accessible
    end
    return true
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- A string this addon may read and compare, or nil.
local function ReadableString(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

-- A yes/no answer from the game, or nil when it failed or is hidden.
local function ReadableBool(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return nil end
    return value == true
end

local function IsAccessibleString(value)
    if Unit.IsToken then return Unit.IsToken(value) end
    local ok, accessible = pcall(function()
        return CanAccessValue(value) and type(value) == "string" and value ~= ""
    end)
    return ok and accessible == true
end

local function CanAccessTooltipText()
    if not UsesProtectedTooltipStrings() then return true end
    local ok, text = pcall(function()
        return GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    end)
    if not ok then return false end
    return text ~= nil and CanAccessValue(text)
end

local function CanUseUnit(unit)
    if Unit.Exists then return Unit.Exists(unit) end
    if not IsAccessibleString(unit) then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and exists == true
end

local function SafeUnitReaction(unit, target)
    if not CanUseUnit(unit) or not CanUseUnit(target) then return nil end
    local ok, reaction = pcall(UnitReaction, unit, target)
    if ok then return reaction end
    return nil
end

local function SafeUnitCanAttack(unit, target)
    if not CanUseUnit(unit) or not CanUseUnit(target) then return false end
    local ok, canAttack = pcall(UnitCanAttack, unit, target)
    return ok and canAttack or false
end

local function IsTapDenied(unit)
    if not CanUseUnit(unit) then return false end
    if UnitIsTapDenied then
        local ok, denied = pcall(UnitIsTapDenied, unit)
        if ok then return denied end
    end
    if UnitIsTapped and UnitIsTappedByPlayer then
        local ok, tapped = pcall(UnitIsTapped, unit)
        if ok and tapped then
            local okByPlayer, tappedByPlayer = pcall(UnitIsTappedByPlayer, unit)
            return okByPlayer and not tappedByPlayer
        end
    end
    return false
end

local function ColorHex(c)
    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

local function GetClassColorHex(unit)
    if not RAID_CLASS_COLORS then return nil end
    local c = Unit.ClassColor and Unit.ClassColor(unit)
    if not c then return nil end
    return ColorHex(c)
end

-- Any player, including one whose GUID Forever hides; Unit.IsPlayer needs the GUID.
local function IsPlayerToken(unit)
    return CanUseUnit(unit) and ReadableBool(UnitIsPlayer, unit) == true
end

local function IsHiddenPlayer(unit)
    return UnitGUID ~= nil and IsPlayerToken(unit) and Unit.GUID(unit) == nil
end

local SURNAME_SEPARATOR = (Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "

-- The name to show and the first name. Forever's UnitName returns the first
-- name and the surname, and only the two together are unique; elsewhere the
-- second return is the realm of a player from another realm.
local function GetUnitNames(unit)
    if not CanUseUnit(unit) then return nil end
    local ok, name, second = pcall(UnitName, unit)
    if not ok then return nil end
    name = ReadableString(name)
    if not name then return nil end
    second = ReadableString(second)
    if not second then return name, name end
    if Carpenter and Carpenter.Client and Carpenter.Client.isForever then
        return name .. SURNAME_SEPARATOR .. second, name
    end
    return name .. "-" .. second, name
end

-- Forever hides an enemy player's class and race from addons in battlegrounds,
-- but the scoreboard keeps every player's name, race and class readable.
local SCORE_REQUEST_INTERVAL = 5
local scoreboard = { byName = nil, dirty = true, requestedAt = nil }

local function InBattleground()
    if C_PvP and C_PvP.IsBattleground and ReadableBool(C_PvP.IsBattleground) then
        return true
    end
    if not IsInInstance then return false end
    local ok, _, instanceType = pcall(IsInInstance)
    return ok and ReadableString(instanceType) == "pvp"
end

local function RequestScores()
    if not RequestBattlefieldScoreData or not InBattleground() then return end
    local now = GetTime and GetTime() or 0
    if scoreboard.requestedAt and now - scoreboard.requestedAt < SCORE_REQUEST_INTERVAL then return end
    scoreboard.requestedAt = now
    pcall(RequestBattlefieldScoreData)
end

-- Two players behind one name (first names repeat on Forever) leave it unusable.
local function AddScoreEntry(byName, key, entry)
    if not key or key == "" then return end
    local known = byName[key]
    if known == nil then
        byName[key] = entry
    elseif known and (known.classToken ~= entry.classToken or known.raceName ~= entry.raceName) then
        byName[key] = false
    end
end

local function ReadScoreboard()
    if not scoreboard.dirty then return scoreboard.byName end
    scoreboard.dirty = false
    local byName = {}
    scoreboard.byName = byName
    if not (C_PvP and C_PvP.GetScoreInfo and GetNumBattlefieldScores) then return byName end

    local okCount, count = pcall(GetNumBattlefieldScores)
    if not okCount or IsSecret(count) or type(count) ~= "number" then return byName end
    for index = 1, count do
        local ok, info = pcall(C_PvP.GetScoreInfo, index)
        if ok and not IsSecret(info) and type(info) == "table" then
            local name = ReadableString(info.name)
            local classToken = ReadableString(info.classToken)
            if name and classToken then
                local entry = {
                    classToken = classToken,
                    className = ReadableString(info.className),
                    raceName = ReadableString(info.raceName),
                }
                local fullName = name:match("^([^%-]+)") or name
                AddScoreEntry(byName, fullName, entry)
                local cut = fullName:find(SURNAME_SEPARATOR, 1, true)
                if cut and cut > 1 then
                    AddScoreEntry(byName, fullName:sub(1, cut - 1), entry)
                end
            end
        end
    end
    return byName
end

local function FindScore(displayName, firstName)
    local byName = ReadScoreboard()
    local entry = byName and (byName[(displayName:match("^([^%-]+)"))] or byName[firstName])
    if entry then return entry end
    RequestScores()
    return nil
end

-- Class and race of a player: from the unit when the game shows them, from the
-- battleground scoreboard when Forever hides them.
local function GetPlayerIdentity(unit, displayName, firstName)
    local className, classToken = Unit.Class(unit)
    if classToken then
        local ok, race = pcall(UnitRace, unit)
        return { classToken = classToken, className = className, raceName = ok and ReadableString(race) or nil }
    end
    if not displayName or not IsPlayerToken(unit) then return nil end
    return FindScore(displayName, firstName)
end

local function IdentityClassColor(identity)
    return identity and RAID_CLASS_COLORS and RAID_CLASS_COLORS[identity.classToken] or nil
end

-- Name line (line 1): players/friendly in class or PvP color; dead in grey; hostile mobs red/tap-denied blue
local function ApplyNameLine(tooltip, unit)
    local left1 = _G["GameTooltipTextLeft1"]
    if not left1 then return end

    local tipIsPlayer = Unit.IsPlayer and Unit.IsPlayer(unit)
    local playerControl = Unit.IsPlayerControlled and Unit.IsPlayerControlled(unit)
    local reaction = SafeUnitReaction(unit, "player") or 0
    local dead = UnitIsDeadOrGhost(unit)

    if dead then
        left1:SetTextColor(0.53, 0.53, 0.53)
        return
    end

    -- Player, or friendly (reaction > 4), or player-controlled
    if tipIsPlayer or playerControl or reaction > 4 then
        if tipIsPlayer then
            -- Unit.ClassColor skips class tokens Forever hides from addons.
            local c = Unit.ClassColor and Unit.ClassColor(unit)
            if c then
                left1:SetTextColor(c.r, c.g, c.b)
            else
                left1:SetTextColor(1, 1, 1)
            end
        else
            -- Forever hides PvP flags in combat; a hidden one reads as not flagged.
            local okPvP, isPvP = pcall(UnitIsPVP, unit)
            if okPvP and not (issecretvalue and issecretvalue(isPvP)) and isPvP then
                left1:SetTextColor(0, 1, 0)
            else
                left1:SetTextColor(0, 0.67, 1)
            end
        end
        return
    end

    -- Hostile mob (not player, reaction < 4, not player control)
    if not tipIsPlayer and reaction < 4 and not playerControl then
        if IsTapDenied(unit) then
            left1:SetTextColor(0.53, 0.53, 0.73)
        else
            left1:SetTextColor(1, 0.2, 0.2)
        end
    end
end

-- The level text for the line about to be replaced. The game writes "??" there
-- for a unit too far above the player, even where UnitLevel still returns the
-- real level, so its line decides what stays hidden. Our own text keeps the "??"
-- for the next pass over the same line.
local function FormatLevel(unit, levelLine)
    local unitLevel = UnitLevel(unit)
    local lineText = levelLine and ReadableString(levelLine:GetText())
    if IsSecret(unitLevel) or type(unitLevel) ~= "number" or unitLevel == -1
        or (lineText and lineText:find("??", 1, true)) then
        return "|cffff3333" .. LEVEL_STR .. " ??|r"
    end

    local levelColor = GetCreatureDifficultyColor(unitLevel)
    local levelHex = levelColor and string.format("%02x%02x%02x", levelColor.r * 255, levelColor.g * 255, levelColor.b * 255) or "ffffffff"
    return "|cff" .. levelHex .. LEVEL_STR .. " " .. unitLevel .. "|r"
end

-- "Level 60 Orc Priest"; Russian puts the level last.
local function JoinPlayerInfo(levelPart, race, classPart)
    local infoText
    if isRuRU then
        infoText = ""
        if race then infoText = infoText .. race end
        if classPart ~= "" then infoText = infoText .. (race and ", " or "") .. classPart end
        if infoText ~= "" then infoText = infoText .. " " end
        return infoText .. levelPart
    end
    infoText = levelPart
    if race then infoText = infoText .. " " .. race end
    if classPart ~= "" then infoText = infoText .. " " .. classPart end
    return infoText
end

-- Player info line (level, race, class) - find line 2/3 that looks like the info line and replace
local function ApplyPlayerInfoLine(tooltip, unit)
    local className, classToken = UnitClass(unit)  -- className = localized (e.g. "Warrior"), classToken = "WARRIOR"
    local classColor = GetClassColorHex(unit) or "|cffffffff"
    local race = UnitRace(unit)

    -- Locate the level line and check whether the game already shows the class on its
    -- own line (e.g. "Shadow Priest" under "Level 60 Orc"), so we don't repeat it.
    local levelLine, classOnlyLine
    local numLines = tooltip and tooltip.NumLines and tooltip:NumLines() or 4
    for i = 2, numLines do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText() or ""
        if text ~= "" then
            local hasLevel = text:lower():find(LEVEL_STR:lower(), 1, true) ~= nil
            local hasClass = className and className ~= "" and text:find(className, 1, true) ~= nil
            if hasLevel then
                levelLine = levelLine or line
            elseif hasClass and text:sub(-#className) == className then
                -- A line ending in the class name is the game's own class/spec line.
                classOnlyLine = classOnlyLine or line
            end
        end
    end
    local classShownElsewhere = levelLine ~= nil and classOnlyLine ~= nil
    levelLine = levelLine or classOnlyLine
    if not levelLine then return end

    local levelPart = FormatLevel(unit, levelLine)

    local classPart = ""
    if not classShownElsewhere then
        classPart = classColor .. (className or "") .. "|r"
    end

    levelLine:SetText(JoinPlayerInfo(levelPart, race, classPart))
end

-- Mob level line (level + creature type + classification)
local function ApplyMobLevelLine(tooltip, unit)
    if (Unit.IsPlayer and Unit.IsPlayer(unit)) or (Unit.IsPlayerControlled and Unit.IsPlayerControlled(unit)) then return end
    local reaction = SafeUnitReaction(unit, "player") or 0
    if reaction >= 5 then return end
    if not SafeUnitCanAttack("player", unit) then return end

    local levelLine
    for i = 2, 4 do
        local line = _G["GameTooltipTextLeft" .. i]
        if line and (line:GetText() or ""):lower():find(LEVEL_STR:lower()) then
            levelLine = line
            break
        end
    end
    if not levelLine then return end

    local creatureType = UnitCreatureType(unit)
    local classification = UnitClassification(unit)

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

    levelLine:SetText(FormatLevel(unit, levelLine) .. " " .. typePart .. specPart)
end

local TARGET_PREFIX = (L.TOOLTIP_TARGET_PREFIX or "Target:") .. " "
local TARGET_YOU = L.TOOLTIP_YOU or "YOU"

local function RefreshTooltipLayout(tooltip)
    if tooltip and tooltip.Show then
        tooltip:Show()
    end
end

local function TooltipAlreadyHasTargetLine()
    for i = 1, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and ReadableString(line:GetText())
        if text and text:find("^" .. TARGET_PREFIX:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) then
            return true
        end
    end
    return false
end

local function GetTooltipUnit(tooltip)
    if WorldFrame and WorldFrame.IsMouseMotionFocus and WorldFrame:IsMouseMotionFocus() and CanUseUnit("mouseover") then
        return "mouseover"
    end

    if tooltip and tooltip.GetUnit then
        local ok, name, unit = pcall(tooltip.GetUnit, tooltip)
        if ok then
            if IsAccessibleString(unit) then
                return unit
            end
            if IsAccessibleString(name) then
                local nameOk, nameExists = pcall(UnitExists, name)
                if nameOk and nameExists then
                    return name
                end
            end
        end
    end

    if CanUseUnit("mouseover") then
        return "mouseover"
    end
    return nil
end

local function BuildTargetLine(unit)
    local targetUnit = unit .. "target"
    local displayName, name = GetUnitNames(targetUnit)
    if not name then return nil end

    -- Forever hides comparisons of chained units like "mouseovertarget" in
    -- battlegrounds, but player names stay readable there.
    local isYou = ReadableBool(UnitIsUnit, targetUnit, "player")
    if isYou == nil then
        isYou = displayName == GetUnitNames("player")
    end
    if isYou then
        return TARGET_PREFIX .. "|cffff4400" .. TARGET_YOU .. "|r"
    end

    local color = Unit.IsPlayer and Unit.IsPlayer(targetUnit) and Unit.ClassColor and Unit.ClassColor(targetUnit)
    if not color and IsHiddenPlayer(targetUnit) then
        color = IdentityClassColor(GetPlayerIdentity(targetUnit, displayName, name))
    end
    if color then
        return TARGET_PREFIX .. ColorHex(color) .. name .. "|r"
    end
    return TARGET_PREFIX .. name
end

local function ShowUnitTargetInTooltip(tooltip, unit)
    if not unit then return end
    if TooltipAlreadyHasTargetLine() then return end

    local ok, line = pcall(BuildTargetLine, unit)
    if ok and line then
        tooltip:AddLine(line)
        RefreshTooltipLayout(tooltip)
    end
end

-- Forever hides an enemy player's class, race and GUID in battlegrounds, and
-- the tooltip text with them, so Blizzard's lines can't be read or restyled.
-- The tooltip is rebuilt instead from what stays readable: name, level, guild
-- and faction from the unit, class and race from the scoreboard.
local DEAD_COLOR = { r = 0.53, g = 0.53, b = 0.53 }
local WHITE = { r = 1, g = 1, b = 1 }

local function BuildHiddenEnemyLines(unit)
    if not IsPlayerToken(unit) or ReadableBool(UnitCanAttack, "player", unit) ~= true then return nil end
    local _, classToken = Unit.Class(unit)
    if classToken and CanAccessTooltipText() then return nil end

    local displayName, firstName = GetUnitNames(unit)
    if not displayName then return nil end
    local identity = GetPlayerIdentity(unit, displayName, firstName)
    local classColor = IdentityClassColor(identity)
    if not classColor then return nil end

    local nameColor = ReadableBool(UnitIsDeadOrGhost, unit) and DEAD_COLOR or classColor
    local lines = { { text = displayName, color = nameColor } }

    if GetGuildInfo then
        local ok, guild = pcall(GetGuildInfo, unit)
        guild = ok and ReadableString(guild)
        if guild then lines[#lines + 1] = { text = guild, color = WHITE } end
    end

    local className = identity.className
        or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[identity.classToken]) or ""
    local classPart = className ~= "" and (ColorHex(classColor) .. className .. "|r") or ""
    lines[#lines + 1] = { text = JoinPlayerInfo(FormatLevel(unit), identity.raceName, classPart), color = WHITE }

    if UnitFactionGroup then
        local ok, _, factionName = pcall(UnitFactionGroup, unit)
        factionName = ok and ReadableString(factionName)
        if factionName then lines[#lines + 1] = { text = factionName, color = WHITE } end
    end

    local okTarget, targetLine = pcall(BuildTargetLine, unit)
    -- No color, like the target line Carpenter adds to other tooltips.
    if okTarget and targetLine then lines[#lines + 1] = { text = targetLine } end
    return lines
end

local function RebuildHiddenEnemyTooltip(tooltip, unit)
    local lines = BuildHiddenEnemyLines(unit)
    if not lines then return false end

    local parts = {}
    for i, line in ipairs(lines) do
        local color = line.color
        parts[i] = color and string.format("%s:%.2f:%.2f:%.2f", line.text, color.r, color.g, color.b) or line.text
    end
    local signature = table.concat(parts, "\n")
    if tooltip._CP_HiddenEnemySignature == signature then return true end

    tooltip:ClearLines()
    for _, line in ipairs(lines) do
        local color = line.color
        if color then
            tooltip:AddLine(line.text, color.r, color.g, color.b)
        else
            tooltip:AddLine(line.text)
        end
    end
    tooltip._CP_HiddenEnemySignature = signature
    RefreshTooltipLayout(tooltip)
    return true
end

local function EnhanceUnitTooltip(tooltip, unit)
    if not CanUseUnit(unit) then return end
    ScheduleHideTooltipHealthBar(tooltip)
    if RebuildHiddenEnemyTooltip(tooltip, unit) then return end
    if not CanAccessTooltipText() then return end
    if IsHiddenPlayer(unit) then
        -- Without the class its lines can't be told apart, so Blizzard's stay.
        ShowUnitTargetInTooltip(tooltip, unit)
        return
    end
    ApplyNameLine(tooltip, unit)
    if Unit.IsPlayer and Unit.IsPlayer(unit) then
        ApplyPlayerInfoLine(tooltip, unit)
    else
        local reaction = SafeUnitReaction(unit, "player") or 0
        if reaction < 5 and not (Unit.IsPlayerControlled and Unit.IsPlayerControlled(unit)) and SafeUnitCanAttack("player", unit) then
            ApplyMobLevelLine(tooltip, unit)
        end
    end
    ShowUnitTargetInTooltip(tooltip, unit)
end

local function ScheduleEnhanceUnitTooltip(tooltip, unit)
    EnhanceUnitTooltip(tooltip, unit)
    if not (C_Timer and C_Timer.After) then return end

    local function Reapply()
        if IsEnabled() and tooltip and tooltip:IsShown() and GetTooltipUnit(tooltip) == unit then
            EnhanceUnitTooltip(tooltip, unit)
        end
    end

    C_Timer.After(0, Reapply)
    C_Timer.After(0.03, Reapply)
end

local tooltipUpdateElapsed = 0

local function MaintainEnhancedTooltip(self, elapsed)
    if self ~= GameTooltip or not IsEnabled() or not self:IsShown() then return end

    tooltipUpdateElapsed = tooltipUpdateElapsed + (elapsed or 0)
    if tooltipUpdateElapsed < 0.02 then return end
    tooltipUpdateElapsed = 0

    if self.GetItem then
        local _, itemLink = self:GetItem()
        if itemLink and itemLink ~= "" then return end
    end

    local unit = GetTooltipUnit(self)
    if CanUseUnit(unit) then
        EnhanceUnitTooltip(self, unit)
    end
end

-- Match Leatrix Plus: world hover uses "mouseover", else GetUnit.
-- WorldFrame:EnableMouseMotion(true) so world hover triggers unit tooltips.
local function ShowTip(self)
    -- Only enhance the main GameTooltip (avoid affecting LibDBIcon and other tooltips)
    if self ~= GameTooltip then return end
    -- Blizzard just wrote its own lines, so a rebuilt enemy tooltip is gone.
    self._CP_HiddenEnemySignature = nil
    if not IsEnabled() then return end
    -- Do not modify tooltip when it is showing an item (e.g. merchant); avoids comparison tooltip flicker
    if self.GetItem then
        local _, itemLink = self:GetItem()
        if itemLink and itemLink ~= "" then return end
    end
    local unit = GetTooltipUnit(self)
    if not CanUseUnit(unit) then return end
    local reaction = SafeUnitReaction(unit, "player")
    if not reaction then return end

    -- Hide the bar before touching protected tooltip strings. Retail can block
    -- text access for some world-hover enemy tooltips, but the status bar still
    -- needs to be suppressed. EnhanceUnitTooltip checks the text itself.
    ScheduleHideTooltipHealthBar(self)
    ScheduleEnhanceUnitTooltip(self, unit)
end

local hooked = false
local function InstallHooks()
    if not GameTooltip then return end
    if WorldFrame and WorldFrame.EnableMouseMotion then
        WorldFrame:EnableMouseMotion(true)
    end
    if not hooked then
        if IsEnabled() then
            HideTooltipHealthBar(GameTooltip)
        end
        local hookedOnShow = false
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
                ShowTip(tooltip)
            end)
        elseif GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetUnit") then
            GameTooltip:HookScript("OnTooltipSetUnit", ShowTip)
        else
            GameTooltip:HookScript("OnShow", ShowTip)
            hookedOnShow = true
        end
        if not hookedOnShow and GameTooltip.HasScript and GameTooltip:HasScript("OnShow") then
            GameTooltip:HookScript("OnShow", ShowTip)
        end
        if GameTooltip.HasScript and GameTooltip:HasScript("OnUpdate") then
            GameTooltip:HookScript("OnUpdate", MaintainEnhancedTooltip)
        end
        hooked = true
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
if Carpenter and Carpenter.SafeRegisterEvent then
    Carpenter:SafeRegisterEvent(frame, "UPDATE_BATTLEFIELD_SCORE")
end
-- Blizzard re-shows the bar on the next unit tooltip; only its alpha needs restoring.
if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("enhanceTooltipEnabled", {
        Enable = function() end,
        Disable = function()
            RestoreTooltipHealthBar(GameTooltip)
        end,
    })
end

frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "UPDATE_BATTLEFIELD_SCORE" then
        scoreboard.dirty = true
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        scoreboard.dirty = true
        scoreboard.requestedAt = nil
    end
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
