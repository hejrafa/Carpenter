--[[ Carpenter - Damage Meter Tab ]]
-- Shows the game's damage meter as plain text in a chat tab of its own, on
-- Retail and WoW Forever: a yellow title line with the meter type on the
-- left and the segment and its time on the right, then one line per player,
-- the name in class color on the left and "total (per second)" on the right,
-- in the chat window's own font. The order shows the ranking, so a name only
-- carries its rank when it is pinned out of order. The mouse wheel scrolls
-- the lines (Shift jumps to the top or bottom).
--
-- Clicking a name shows that player's breakdown in the tab, as the game's
-- own meter does in a window beside it: their spells, best first, each with
-- its total, under a title naming them. Clicking the breakdown goes back to
-- the list. The game finds a player's spells by their ID, which it hides
-- from addons in combat for everyone but you, so in combat only your own
-- name opens a breakdown; after combat every name does again.
--
-- While the tab is open, a chat button with an arrow sits where the chat
-- channels button is. That button belongs to the General window's button
-- column and hides with it on other tabs, so the arrow takes its place there
-- and fades like the chat buttons still showing beside it. With the tab
-- pulled out into a window of its own, the arrow tops that window's button
-- column instead, with its collapse button moved down under it, and fades
-- with that column. It picks the meter type and segment and resets the data.
--
-- The game's own floating meter window stays hidden while the option is on,
-- except in Edit Mode, where it can still be placed and set up.
--
-- The tab is a real chat window named after the game's "Damage Meter" label
-- and set to receive no chat, so docking, resizing, fading and the
-- background behave like any other tab. Carpenter opens it when the option
-- is turned on and closes it when the option is turned off, never at login.
-- Opening or closing a chat window from an addon taints the chat dock until
-- the next reload, which can block slash commands typed in chat during
-- combat, so both offer a reload. After it, the game restores the window
-- itself and Carpenter only draws on top of it.
--
-- In combat the game hides names and amounts from addons. They still show:
-- they go straight into the text through the game's own formatting, with no
-- math or comparisons on them, which is also why there are no bars.

local FEATURE_KEY = "damageMeterTabEnabled"
local RELOAD_POPUP = "CARPENTER_DAMAGE_METER_TAB_RELOAD"
local REFRESH_SECONDS = 0.5
local LOGIN_SETTLE_SECONDS = { 1, 3, 6 }
local VALUE_GAP = 8
local FALLBACK_FONT_SIZE = 14
-- A faint band behind a line that takes a click, while the mouse is on it.
local CLICK_HIGHLIGHT_ALPHA = 0.1
-- The title line's yellow, as on the quest tracker's quest titles.
local TITLE_R, TITLE_G, TITLE_B = 1, 0.82, 0
-- The chat button column's art, as on the channels button.
local MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT, MENU_ICON_SIZE = 27, 26, 15
-- The arrow sits high and left in its art; this centers it on the button's
-- face. Pressed, it moves with the face as the chat buttons' icons do.
local MENU_ICON_OFFSET_X, MENU_ICON_OFFSET_Y = 1.5, -3
local MENU_ICON_PUSHED_X, MENU_ICON_PUSHED_Y = -1, -2
local MENU_ARROW_ATLAS = "friendslist-categorybutton-arrow-down"
local MENU_ARROW_FALLBACK_ATLAS = "common-dropdown-a-button-shadowless"

local L = (Carpenter and Carpenter.L) or {}
local unpack = unpack or table.unpack

local DamageMeterTab = {}
local state = {
    active = false,
    -- The game has restored its chat windows, so a missing tab is really
    -- missing.
    chatReady = false,
    dirty = true,
    -- Whether the menu button was last placed for a pulled-out window.
    pulledOut = false,
    -- Scrolling: the first line's place in the list, and what the last
    -- refresh found, which the mouse wheel stays within.
    offset = 0,
    total = 0,
    capacity = 0,
    -- The player whose breakdown shows, or nil for the list, and where the
    -- list was scrolled to when it opened.
    breakdown = nil,
    listOffset = 0,
}

local function Text(key, fallback)
    return L[key] or fallback
end

-- Runs one step of the tab's upkeep, so a failure in one doesn't stop the
-- others.
local function Try(callback, ...)
    return (pcall(callback, ...))
end

-- The game's "Damage Meter" label; the docked tab is widened to fit it. A
-- tab an earlier build named "Damage" is found and renamed.
local function TabName()
    return _G.DAMAGE_METER_LABEL or "Damage Meter"
end

local function LegacyTabName()
    return _G.DAMAGE_METER_CATEGORY_DAMAGE or "Damage"
end

-- =========================
-- Meter types and segments
-- =========================
local function MeterTypes()
    return Enum and Enum.DamageMeterType or {}
end

local function SessionTypes()
    return Enum and Enum.DamageMeterSessionType or {}
end

-- The game's own menu, without Deaths: its value is a time that would need
-- math to show.
local function Categories()
    local types = MeterTypes()
    local function List(...)
        local list = {}
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if value ~= nil then list[#list + 1] = value end
        end
        return list
    end
    return {
        { name = _G.DAMAGE_METER_CATEGORY_DAMAGE or "Damage",
            types = List(types.DamageDone, types.Dps, types.DamageTaken, types.AvoidableDamageTaken, types.EnemyDamageTaken) },
        { name = _G.DAMAGE_METER_CATEGORY_HEALING or "Healing", types = List(types.HealingDone, types.Hps) },
        { name = _G.DAMAGE_METER_CATEGORY_ACTIONS or "Actions", types = List(types.Interrupts, types.Dispels) },
    }
end

local function TypeName(meterType)
    local types = MeterTypes()
    local names = {
        [types.DamageDone or false] = _G.DAMAGE_METER_TYPE_DAMAGE_DONE or "Damage Done",
        [types.Dps or false] = _G.DAMAGE_METER_TYPE_DPS or "DPS",
        [types.HealingDone or false] = _G.DAMAGE_METER_TYPE_HEALING_DONE or "Healing Done",
        [types.Hps or false] = _G.DAMAGE_METER_TYPE_HPS or "HPS",
        [types.Absorbs or false] = _G.DAMAGE_METER_TYPE_ABSORBS or "Absorbs",
        [types.Interrupts or false] = _G.DAMAGE_METER_TYPE_INTERRUPTS or "Interrupts",
        [types.Dispels or false] = _G.DAMAGE_METER_TYPE_DISPELS or "Dispels",
        [types.DamageTaken or false] = _G.DAMAGE_METER_TYPE_DAMAGE_TAKEN or "Damage Taken",
        [types.AvoidableDamageTaken or false] = _G.DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN or "Avoidable Damage Taken",
        [types.EnemyDamageTaken or false] = _G.DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN or "Enemy Damage Taken",
    }
    return names[meterType] or _G.DAMAGE_METER_LABEL or "Damage Meter"
end

-- Per second first, total in parentheses.
local function ShowsPerSecondFirst(meterType)
    local types = MeterTypes()
    return meterType ~= nil and (meterType == types.Dps or meterType == types.Hps)
end

-- Counts, with nothing per second.
local function HasNoPerSecond(meterType)
    local types = MeterTypes()
    return meterType ~= nil and (meterType == types.Interrupts or meterType == types.Dispels)
end

local function IsOfferedType(meterType)
    for _, category in ipairs(Categories()) do
        for _, offered in ipairs(category.types) do
            if offered == meterType then return true end
        end
    end
    return false
end

local function SelectedType()
    local saved = CarpenterDB and CarpenterDB.damageMeterTabType
    if saved ~= nil and IsOfferedType(saved) then return saved end
    return MeterTypes().DamageDone
end

local function SelectedSession()
    local sessions = SessionTypes()
    local saved = CarpenterDB and CarpenterDB.damageMeterTabSession
    if saved ~= nil and (saved == sessions.Current or saved == sessions.Overall) then return saved end
    return sessions.Current
end

local function SessionName(sessionType)
    if sessionType == SessionTypes().Overall then
        return _G.DAMAGE_METER_OVERALL_SESSION or "Overall"
    end
    return _G.DAMAGE_METER_CURRENT_SESSION or "Current Segment"
end

local function MarkDirty()
    state.dirty = true
end

-- A new list starts at its top.
local function StartOver()
    state.offset = 0
    MarkDirty()
end

-- Back from a breakdown to the list, where it was scrolled to.
local function LeaveBreakdown()
    if not state.breakdown then return false end
    state.breakdown = nil
    state.offset = state.listOffset or 0
    MarkDirty()
    return true
end

-- A new type has other players and spells, so it opens on its list, as the
-- game's meter closes its breakdown then. A new segment keeps the breakdown.
local function SelectType(meterType)
    if CarpenterDB then CarpenterDB.damageMeterTabType = meterType end
    LeaveBreakdown()
    StartOver()
end

local function SelectSession(sessionType)
    if CarpenterDB then CarpenterDB.damageMeterTabSession = sessionType end
    StartOver()
end

-- =========================
-- The chat window
-- =========================
local function ChatWindowCount()
    return _G.NUM_CHAT_WINDOWS or 10
end

-- The open chat window carrying the tab's name, or its old one. Open means
-- shown or docked: while the game loads, a docked tab can be hidden for a
-- moment. The General and Combat Log windows are never taken, whatever they
-- are called.
function DamageMeterTab.FindWindow()
    if type(GetChatWindowInfo) ~= "function" then return nil end
    local name, legacyName = TabName(), LegacyTabName()
    for index = 3, ChatWindowCount() do
        local ok, windowName, _, _, _, _, _, shown, _, docked = pcall(GetChatWindowInfo, index)
        local frame = _G["ChatFrame" .. index]
        local open = shown == true or shown == 1 or (type(docked) == "number" and docked > 0) or docked == true
        if ok and frame and open and (windowName == name or windowName == legacyName) then
            return frame, index, windowName
        end
    end
    return nil
end

-- Renames a tab from an earlier build. The game's own call saves the name
-- without touching the chat code's state, and the tab's label follows at
-- once.
local function RenameLegacyWindow(frame, index, windowName)
    if not frame or windowName == TabName() or type(SetChatWindowName) ~= "function" then return end
    if not pcall(SetChatWindowName, index, TabName()) then return end
    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab and tab.SetText then tab:SetText(TabName()) end
    pcall(DamageMeterTab.FitTabToName, frame)
end

local function FindAndRenameWindow()
    local frame, index, windowName = DamageMeterTab.FindWindow()
    RenameLegacyWindow(frame, index, windowName)
    return frame
end

local function ShowReloadPopup()
    if type(StaticPopup_Show) ~= "function" then return end
    StaticPopupDialogs = StaticPopupDialogs or {}
    if not StaticPopupDialogs[RELOAD_POPUP] then
        StaticPopupDialogs[RELOAD_POPUP] = {
            text = Text("DAMAGE_METER_TAB_RELOAD",
                "Carpenter changed your chat tabs. Reload now so chat commands keep working in combat?"),
            button1 = _G.RELOADUI or "Reload UI",
            button2 = _G.LATER or "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
    end
    StaticPopup_Show(RELOAD_POPUP)
end

-- A tab that receives no chat.
local function OpenWindow()
    if type(FCF_OpenNewWindow) ~= "function" then return nil end
    local ok, frame = pcall(FCF_OpenNewWindow, TabName(), true)
    if not ok or not frame then return nil end
    ShowReloadPopup()
    return frame
end

local function CloseWindow(frame)
    if not frame or frame == _G.DEFAULT_CHAT_FRAME or frame == _G.ChatFrame1 or frame == _G.ChatFrame2 then return end
    if type(FCF_Close) ~= "function" then return end
    pcall(FCF_Close, frame)
    ShowReloadPopup()
end

-- =========================
-- The text
-- =========================
local display, header, headerRight, headerClick, menuButton
local rows = {}
local OnMouseWheel, OnClickArea

-- Docked, the game gives every tab but General and Combat Log one width of
-- 60 to 90, which cuts "Damage Meter" off. After each dock layout the tab is
-- widened to fit its name, as those two are, and the tabs after it follow.
-- Only the tab's and its label's widths change, as the game's own fixed-width
-- tabs do; a pulled-out tab is already sized to its name.
local CHAT_TAB_SIDES_PADDING = 20

local function TabOf(window)
    local name = window and window.GetName and window:GetName()
    return name and _G[name .. "Tab"]
end

function DamageMeterTab.FitTabToName(window)
    if not state.active or not window or window == UIParent or not window.isDocked then return end
    local tab = TabOf(window)
    local label = tab and tab.Text
    if not label then return end
    local measure = label.GetUnboundedStringWidth or label.GetStringWidth
    local textWidth = math.ceil(measure(label) or 0)
    if textWidth <= 0 then return end
    local width = textWidth + CHAT_TAB_SIDES_PADDING + (tab.sizePadding or 0)
    if math.abs((tab:GetWidth() or 0) - width) < 0.5 then return end
    label:SetWidth(textWidth)
    tab:SetWidth(width)
end

local function FitAttachedTab()
    if display and display:GetParent() ~= UIParent then
        pcall(DamageMeterTab.FitTabToName, display:GetParent())
    end
end

local tabLayoutHooked = false
local function HookTabLayout()
    if tabLayoutHooked then return end
    tabLayoutHooked = Carpenter:SafeHook("FCFDock_UpdateTabs", FitAttachedTab)
end

local function ChatFont(window)
    local file, size, flags
    if window and window.GetFont then
        file, size, flags = window:GetFont()
    end
    return file, size or FALLBACK_FONT_SIZE, flags
end

local function StyleFontString(fontString, window)
    local file, size, flags = ChatFont(window)
    if file then
        fontString:SetFont(file, size, flags or "")
    elseif _G.ChatFontNormal then
        fontString:SetFontObject(_G.ChatFontNormal)
    end
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function LineHeight(window)
    local _, size = ChatFont(window)
    local spacing = window and window.GetSpacing and window:GetSpacing() or 0
    return math.floor(size + math.max(spacing, 3) + 0.5)
end

-- =========================
-- Lines that take a click
-- =========================
-- A button over a line's left side, from its start to just before its
-- value, so the value column, and the chat window's resize corner under it,
-- keep the mouse. It takes clicks only while its line does something; the
-- wheel always scrolls through it.
local function CreateClickArea()
    local area = CreateFrame("Button", nil, display)
    area:EnableMouse(false)
    area:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    area:SetScript("OnClick", function(self, mouseButton) OnClickArea(self, mouseButton) end)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, delta) OnMouseWheel(display, delta) end)

    local highlight = display:CreateTexture(nil, "BACKGROUND")
    highlight:SetColorTexture(1, 1, 1, CLICK_HIGHLIGHT_ALPHA)
    highlight:Hide()
    area.highlight = highlight
    area:SetScript("OnEnter", function(self) self.highlight:Show() end)
    area:SetScript("OnLeave", function(self) self.highlight:Hide() end)
    return area
end

-- Over the line at y, up to the region on its right (the value). The band
-- spans the whole line.
local function PlaceClickArea(area, y, lineHeight, rightRegion)
    local top, bottom = y + 1, y - lineHeight + 1
    area.highlight:ClearAllPoints()
    area.highlight:SetPoint("TOPLEFT", display, "TOPLEFT", 0, top)
    area.highlight:SetPoint("BOTTOMRIGHT", display, "TOPRIGHT", 0, bottom)
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", display, "TOPLEFT", 0, top)
    area:SetPoint("BOTTOMRIGHT", rightRegion, "TOPLEFT", -VALUE_GAP, bottom - y)
end

local function SetClickable(area, clickable)
    area:Show()
    area:EnableMouse(clickable and true or false)
    if not clickable then area.highlight:Hide() end
end

local function HideClickArea(area)
    area:EnableMouse(false)
    area:Hide()
    area.highlight:Hide()
end

local function GetRow(slot)
    local row = rows[slot]
    if row then return row end
    row = {
        name = display:CreateFontString(nil, "OVERLAY"),
        value = display:CreateFontString(nil, "OVERLAY"),
        click = CreateClickArea(),
        -- Who the line is, for a click on it.
        target = {},
        hasTarget = false,
    }
    row.click.row = row
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value:SetJustifyH("RIGHT")
    rows[slot] = row
    return row
end

local function HideRows(fromSlot)
    for slot = fromSlot, #rows do
        rows[slot].name:Hide()
        rows[slot].value:Hide()
        rows[slot].hasTarget = false
        HideClickArea(rows[slot].click)
    end
end

local function ClassColor(classFilename)
    local colors = _G.RAID_CLASS_COLORS
    local color = type(classFilename) == "string" and classFilename ~= "" and colors and colors[classFilename]
    if color then return color.r, color.g, color.b end
    return 0.8, 0.8, 0.8
end

-- The class color as a text color code, for a name inside a line of
-- another color.
local function ClassColorCode(classFilename)
    local r, g, b = ClassColor(classFilename)
    return string.format("ff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- A value the game isn't hiding right now.
local function Readable(value)
    if issecretvalue and issecretvalue(value) then return false end
    return value ~= nil
end

-- Readable text with something in it.
local function KnownText(value)
    return Readable(value) and type(value) == "string" and value ~= ""
end

-- Who a line is, as the game's breakdown looks a player up: their ID, or a
-- creature's. The game hides both in combat, so the local player's ID comes
-- from their own unit instead, which it doesn't hide.
local function SourceKey(source)
    if source.isLocalPlayer == true and UnitGUID then
        local ok, guid = pcall(UnitGUID, "player")
        if ok and Readable(guid) then return guid, nil end
    end
    local guid = Readable(source.sourceGUID) and source.sourceGUID or nil
    local creatureID = Readable(source.sourceCreatureID) and source.sourceCreatureID or nil
    return guid, creatureID
end

-- "total (per second)", per second first for DPS and HPS, a count alone for
-- interrupts and dispels. Amounts may be hidden in combat, so they go to the
-- text through the game's own formatting.
local function FillValue(row, total, perSecond, meterType)
    local main, extra = total, perSecond
    if ShowsPerSecondFirst(meterType) then main, extra = extra, main end
    if HasNoPerSecond(meterType) then
        row.value:SetText(AbbreviateLargeNumbers(main))
    else
        row.value:SetFormattedText(_G.DAMAGE_METER_ENTRY_FORMAT_COMPACT or "%s (%s)",
            AbbreviateLargeNumbers(main), AbbreviateLargeNumbers(extra))
    end
    row.value:SetTextColor(1, 1, 1)
end

-- Every field but the class and the local player flag may be hidden in
-- combat, so each goes to the text as it is. A line takes a click when the
-- game lets its player be looked up.
local function FillRow(row, index, source, meterType, showRank)
    if showRank then
        row.name:SetFormattedText(_G.DAMAGE_METER_SOURCE_NAME or "%d. %s", index, source.name)
    else
        row.name:SetText(source.name)
    end
    row.name:SetTextColor(ClassColor(source.classFilename))
    FillValue(row, source.totalAmount, source.amountPerSecond, meterType)
    row.name:Show()
    row.value:Show()

    local guid, creatureID = SourceKey(source)
    local target = row.target
    target.guid, target.creatureID = guid, creatureID
    target.name, target.classFilename = source.name, source.classFilename
    row.hasTarget = guid ~= nil or creatureID ~= nil
    SetClickable(row.click, row.hasTarget)
end

local function SpellName(spell)
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    -- The game's lookup takes an ID it hides in combat.
    local ok, name = pcall(C_Spell.GetSpellName, spell.spellID)
    if ok then return name end
    return nil
end

-- Text that may be hidden counts as there; readable text only when it
-- isn't empty.
local function MayHaveText(value)
    if issecretvalue and issecretvalue(value) then return true end
    return type(value) == "string" and value ~= ""
end

-- A breakdown line, named as the game's own breakdown names it: the spell,
-- with the pet that cast it, "Spell (Pet)", or with the unit that cast it at
-- the player for damage taken, "Spell - Unit" in that unit's class color.
-- The game hides the pet's and unit's names in combat, so until it ends a
-- line shows the spell alone. Lines are in the player's class color, as
-- their bars are in the game's breakdown.
local function FillSpellRow(row, spell, meterType, classFilename)
    local spellName = SpellName(spell)
    local details = type(spell.combatSpellDetails) == "table" and spell.combatSpellDetails or nil
    local creatureName = spell.creatureName
    local unitName = details and details.unitName
    local unitText
    if KnownText(unitName) then
        unitText = unitName
        if KnownText(details.unitClassFilename) then
            unitText = "|c" .. ClassColorCode(details.unitClassFilename) .. unitName .. "|r"
        end
    end

    if MayHaveText(spellName) and KnownText(creatureName) then
        row.name:SetFormattedText(_G.DAMAGE_METER_SPELL_ENTRY_CREATURE or "%s (%s)", spellName, creatureName)
    elseif MayHaveText(spellName) and unitText then
        row.name:SetFormattedText(_G.DAMAGE_METER_SPELL_ENTRY_UNIT or "%s - %s", spellName, unitText)
    elseif MayHaveText(spellName) then
        row.name:SetText(spellName)
    elseif unitText then
        row.name:SetText(unitText)
    elseif KnownText(creatureName) then
        row.name:SetText(creatureName)
    else
        row.name:SetText(_G.UNKNOWN or "Unknown")
    end
    row.name:SetTextColor(ClassColor(classFilename))
    FillValue(row, spell.totalAmount, spell.amountPerSecond, meterType)
    row.name:Show()
    row.value:Show()
    -- A click anywhere on the breakdown goes back to the list.
    row.hasTarget = false
    SetClickable(row.click, true)
end

local function PlaceRow(row, slot, window, lineHeight)
    StyleFontString(row.name, window)
    StyleFontString(row.value, window)
    local y = -slot * lineHeight
    row.value:ClearAllPoints()
    row.value:SetPoint("TOPRIGHT", display, "TOPRIGHT", 0, y)
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", display, "TOPLEFT", 0, y)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -VALUE_GAP, 0)
    PlaceClickArea(row.click, y, lineHeight, row.value)
end

-- Why the tab is empty, when the game says.
local function UnavailableReason()
    if C_CVar and C_CVar.GetCVarBool then
        local ok, enabled = pcall(C_CVar.GetCVarBool, "damageMeterEnabled")
        if ok and enabled == false then
            return Text("DAMAGE_METER_TAB_TURNED_OFF", "Turn on the damage meter in the game's options to fill this tab.")
        end
    end
    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable then
        local ok, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
        if ok and available == false then
            if type(reason) == "string" and reason ~= "" then return reason end
            return Text("DAMAGE_METER_TAB_UNAVAILABLE", "The damage meter isn't available here.")
        end
    end
    return nil
end

-- The segment, with its time once it has one.
local function SegmentText(sessionType)
    local text = SessionName(sessionType)
    if C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds and SecondsToClock then
        local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, sessionType)
        local hidden = issecretvalue and issecretvalue(seconds)
        if ok and not hidden and type(seconds) == "number" and seconds > 0 then
            text = text .. " [" .. SecondsToClock(seconds) .. "]"
        end
    end
    return text
end

-- Which sources fill the lines: those from the scroll position on, with the
-- local player kept on the first or last line when they are scrolled out of
-- view, as the game's meter does.
local function PickSources(sources, capacity, offset)
    local picked = {}
    local first = offset + 1
    local last = math.min(#sources, offset + capacity)
    for index = first, last do picked[#picked + 1] = index end
    if picked[1] == nil then return picked end
    for index = 1, #sources do
        if sources[index].isLocalPlayer == true then
            if index < first then
                picked[1] = index
            elseif index > last then
                picked[#picked] = index
            end
            break
        end
    end
    return picked
end

-- A gray line in place of the list, saying why it is empty. On a breakdown
-- it still goes back to the list when clicked.
local function ShowNotice(window, lineHeight, text)
    local row = GetRow(1)
    PlaceRow(row, 1, window, lineHeight)
    row.name:SetText(text)
    row.name:SetTextColor(0.6, 0.6, 0.6)
    row.value:SetText("")
    row.name:Show()
    row.value:Show()
    row.hasTarget = false
    SetClickable(row.click, state.breakdown ~= nil)
    HideRows(2)
end

local function FillRows(window, lineHeight, capacity)
    local meterType, sessionType = SelectedType(), SelectedSession()
    local reason = UnavailableReason()
    if reason then
        ShowNotice(window, lineHeight, reason)
        return
    end

    local session = C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)
    local sources = type(session) == "table" and session.combatSources or {}
    state.total = #sources
    -- A segment with no fight yet, as the current one after a reload.
    if state.total == 0 then
        state.offset = 0
        ShowNotice(window, lineHeight, Text("DAMAGE_METER_TAB_NO_DATA", "Nothing recorded in this segment yet."))
        return
    end
    state.offset = math.max(0, math.min(state.offset, state.total - capacity))
    local picked = PickSources(sources, capacity, state.offset)
    for slot, index in ipairs(picked) do
        local row = GetRow(slot)
        PlaceRow(row, slot, window, lineHeight)
        -- A line shows its rank only when it is out of order: the local
        -- player pinned to the first or last line.
        FillRow(row, index, sources[index], meterType, index ~= state.offset + slot)
    end
    HideRows(#picked + 1)
end

-- One player's spells, best first, as the game lists them.
local function FillBreakdown(window, lineHeight, capacity)
    local meterType, sessionType = SelectedType(), SelectedSession()
    local reason = UnavailableReason()
    if reason then
        ShowNotice(window, lineHeight, reason)
        return
    end

    local target = state.breakdown
    local source = C_DamageMeter.GetCombatSessionSourceFromType(sessionType, meterType, target.guid, target.creatureID)
    local spells = type(source) == "table" and type(source.combatSpells) == "table" and source.combatSpells or {}
    state.total = #spells
    if state.total == 0 then
        state.offset = 0
        ShowNotice(window, lineHeight, Text("DAMAGE_METER_TAB_NO_DATA", "Nothing recorded in this segment yet."))
        return
    end
    state.offset = math.max(0, math.min(state.offset, state.total - capacity))
    local slot = 0
    for index = state.offset + 1, math.min(state.total, state.offset + capacity) do
        slot = slot + 1
        local row = GetRow(slot)
        PlaceRow(row, slot, window, lineHeight)
        FillSpellRow(row, spells[index], meterType, target.classFilename)
    end
    HideRows(slot + 1)
end

-- The title: the type, or on a breakdown the type and whose it is, the name
-- in class color. A name hidden in combat still goes into the text whole.
local function FillHeader(window, lineHeight, meterType)
    StyleFontString(header, window)
    StyleFontString(headerRight, window)
    local target = state.breakdown
    if target then
        header:SetFormattedText("%s: |c%s%s|r", TypeName(meterType), ClassColorCode(target.classFilename), target.name)
    else
        header:SetText(TypeName(meterType))
    end
    header:SetTextColor(TITLE_R, TITLE_G, TITLE_B)
    if headerClick then
        PlaceClickArea(headerClick, 0, lineHeight, headerRight)
        SetClickable(headerClick, target ~= nil)
    end
end

function DamageMeterTab.Refresh()
    if not display or not display:IsVisible() then return end
    local window = display:GetParent()
    -- Right after a reload the chat window can still be without a size;
    -- stay dirty and try again on the next pass.
    if (display:GetWidth() or 0) <= 0 or (display:GetHeight() or 0) <= 0 then
        state.dirty = true
        return
    end
    state.dirty = false

    local lineHeight = LineHeight(window)
    local capacity = math.max(0, math.floor((display:GetHeight() or 0) / lineHeight) - 1)
    state.capacity = capacity
    local meterType, sessionType = SelectedType(), SelectedSession()

    headerRight:SetText(SegmentText(sessionType))
    headerRight:SetTextColor(TITLE_R, TITLE_G, TITLE_B)
    pcall(FillHeader, window, lineHeight, meterType)

    -- A failure keeps the lines already shown rather than blanking the tab.
    pcall(state.breakdown and FillBreakdown or FillRows, window, lineHeight, capacity)
end

-- A click on a name opens its breakdown; a click on a breakdown, its title
-- included, goes back to the list.
function OnClickArea(area, mouseButton)
    if state.breakdown then
        LeaveBreakdown()
    elseif mouseButton == "LeftButton" and area.row and area.row.hasTarget then
        local target = area.row.target
        state.breakdown = {
            guid = target.guid,
            creatureID = target.creatureID,
            name = target.name,
            classFilename = target.classFilename,
        }
        state.listOffset = state.offset
        state.offset = 0
        MarkDirty()
    else
        return
    end
    Try(DamageMeterTab.Refresh)
end

local function InCombat()
    return (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false
end

local MirrorChannelButton, PlaceMenuButton, IsPulledOut

local function OnDisplayUpdate(self, elapsed)
    -- The tab was pulled out of the dock or put back.
    if IsPulledOut(self:GetParent()) ~= state.pulledOut then
        Try(PlaceMenuButton)
    end
    Try(MirrorChannelButton)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < REFRESH_SECONDS then return end
    self.elapsed = 0
    -- The segment timer runs in combat.
    if state.dirty or InCombat() then
        Try(DamageMeterTab.Refresh)
    end
end

-- =========================
-- The menu button
-- =========================
local function SetupMenu(_, rootDescription)
    if rootDescription.SetTag then rootDescription:SetTag("MENU_CARPENTER_DAMAGE_METER_TAB") end

    local function IsTypeSelected(meterType) return SelectedType() == meterType end
    local function IsSessionSelected(sessionType) return SelectedSession() == sessionType end

    for _, category in ipairs(Categories()) do
        if category.types[1] ~= nil then
            local submenu = rootDescription:CreateButton(category.name)
            for _, meterType in ipairs(category.types) do
                submenu:CreateRadio(TypeName(meterType), IsTypeSelected, SelectType, meterType)
            end
        end
    end

    rootDescription:CreateDivider()
    local sessions = SessionTypes()
    rootDescription:CreateRadio(SessionName(sessions.Current), IsSessionSelected, SelectSession, sessions.Current)
    rootDescription:CreateRadio(SessionName(sessions.Overall), IsSessionSelected, SelectSession, sessions.Overall)

    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
        rootDescription:CreateDivider()
        rootDescription:CreateButton(_G.DAMAGE_METER_RESET_ALL_SESSIONS or "Reset Data", function()
            C_DamageMeter.ResetAllCombatSessions()
            LeaveBreakdown()
            StartOver()
        end)
    end
end

local function IsMenuOpen()
    return menuButton and menuButton.IsMenuOpen and menuButton:IsMenuOpen() == true
end

local function ChannelButton()
    return _G.ChatFrameChannelButton
end

-- Chat buttons that stay in the column whichever tab is open, first to last.
-- On this tab the channels and chat menu buttons are hidden with the General
-- window, so it is usually the social button.
local COLUMN_BUTTONS = { "QuickJoinToastButton", "ChatFrameMenuButton", "ChatFrameChannelButton" }

-- A pulled-out window has its own button column, topped by its collapse
-- button; a docked one hides that button.
function IsPulledOut(window)
    return window ~= nil and window ~= UIParent and not window.isDocked
end

local function CollapseButtonOf(window)
    local buttonFrame = window and window.buttonFrame
    return buttonFrame and buttonFrame.minimizeButton
end

-- Collapse buttons moved under the menu button, with their own anchors.
local movedCollapseButtons = {}

local function RestoreCollapseButtons()
    for button, points in pairs(movedCollapseButtons) do
        button:ClearAllPoints()
        for _, point in ipairs(points) do
            button:SetPoint(unpack(point))
        end
        movedCollapseButtons[button] = nil
    end
end

local function MoveCollapseButtonUnder(button)
    if not movedCollapseButtons[button] then
        local points = {}
        for index = 1, button:GetNumPoints() do
            points[index] = { button:GetPoint(index) }
        end
        movedCollapseButtons[button] = points
    end
    button:ClearAllPoints()
    -- Its art has room around the button; the game sets it 4 higher than
    -- the column's top for the same reason.
    button:SetPoint("TOP", menuButton, "BOTTOM", 0, 4)
end

-- The button shows as much as the chat buttons beside it, so it fades with
-- Hide Chat Buttons and the chat window, and stays up while its menu is open.
-- In a pulled-out window those are its own column's.
function MirrorChannelButton()
    if not menuButton then return end
    local alpha = 1
    if not IsMenuOpen() then
        local collapse = state.pulledOut and CollapseButtonOf(display:GetParent())
        if collapse and collapse:IsVisible() then
            alpha = collapse:GetEffectiveAlpha() or 1
        else
            for _, name in ipairs(COLUMN_BUTTONS) do
                local button = _G[name]
                if button and button.IsVisible and button:IsVisible() then
                    alpha = button:GetEffectiveAlpha() or 1
                    break
                end
            end
        end
    end
    -- A fade the game hides from addons can't be copied; stay up instead.
    if issecretvalue and issecretvalue(alpha) then alpha = 1 end
    if menuButton:GetAlpha() ~= alpha then
        menuButton:SetAlpha(alpha)
    end
end

-- Docked: over the channels button, a level above it. Pulled out: at the top
-- of the window's own button column, its collapse button moved under it. At
-- the tab's top-right corner on a client without either.
function PlaceMenuButton()
    if not menuButton then return end
    local window = display:GetParent()
    local collapse = IsPulledOut(window) and CollapseButtonOf(window)
    local channel = ChannelButton()
    state.pulledOut = IsPulledOut(window)
    menuButton:ClearAllPoints()
    if collapse then
        local column = window.buttonFrame
        menuButton:SetPoint("TOP", column, "TOP", 0, 0)
        menuButton:SetFrameStrata(collapse:GetFrameStrata() or "MEDIUM")
        menuButton:SetFrameLevel((collapse:GetFrameLevel() or 0) + 1)
        MoveCollapseButtonUnder(collapse)
        return
    end
    RestoreCollapseButtons()
    if channel then
        menuButton:SetPoint("CENTER", channel, "CENTER", 0, 0)
        menuButton:SetFrameStrata(channel:GetFrameStrata() or "MEDIUM")
        menuButton:SetFrameLevel((channel:GetFrameLevel() or 0) + 10)
    else
        menuButton:SetPoint("TOPRIGHT", display, "TOPRIGHT", 0, MENU_BUTTON_HEIGHT)
    end
end

local function HasAtlas(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return true end
    return C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function CreateMenuButton()
    -- Not a child of the chat window, which wouldn't draw it out in the
    -- button column; it shows and hides with the tab instead.
    local ok, button = pcall(CreateFrame, "DropdownButton", nil, UIParent)
    if not ok or not button or not button.SetupMenu then return nil end
    button:SetSize(MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT)
    button:SetNormalAtlas("chatframe-button-up")
    button:SetPushedAtlas("chatframe-button-down")
    button:SetHighlightAtlas("chatframe-button-highlight", "ADD")
    -- Its own fade, not the chat window's on top of it.
    button:SetIgnoreParentAlpha(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", MENU_ICON_OFFSET_X, MENU_ICON_OFFSET_Y)
    if HasAtlas(MENU_ARROW_ATLAS) then
        icon:SetAtlas(MENU_ARROW_ATLAS)
        icon:SetSize(MENU_ICON_SIZE, MENU_ICON_SIZE)
        -- The friends list's arrow is a pale tan; drawn in the game's gold,
        -- it matches the chat buttons' icons.
        icon:SetDesaturated(true)
        local gold = _G.NORMAL_FONT_COLOR
        if gold and gold.GetRGB then
            icon:SetVertexColor(gold:GetRGB())
        else
            icon:SetVertexColor(1, 0.82, 0)
        end
    else
        icon:SetAtlas(MENU_ARROW_FALLBACK_ATLAS)
        icon:SetSize(MENU_BUTTON_WIDTH - 4, MENU_BUTTON_HEIGHT - 4)
    end
    button.Icon = icon

    if AnchorUtil and AnchorUtil.CreateAnchor and button.SetMenuAnchor then
        button:SetMenuAnchor(AnchorUtil.CreateAnchor("BOTTOMLEFT", button, "TOPRIGHT", 0, 0))
    end
    button:SetupMenu(SetupMenu)
    button:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TabName())
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:HookScript("OnMouseDown", function()
        icon:SetPoint("CENTER", button, "CENTER",
            MENU_ICON_OFFSET_X + MENU_ICON_PUSHED_X, MENU_ICON_OFFSET_Y + MENU_ICON_PUSHED_Y)
    end)
    button:HookScript("OnMouseUp", function()
        icon:SetPoint("CENTER", button, "CENTER", MENU_ICON_OFFSET_X, MENU_ICON_OFFSET_Y)
    end)
    button:SetAlpha(0)
    button:Hide()
    return button
end

-- The wheel moves a line at a time; with Shift it jumps to an end.
function OnMouseWheel(_, delta)
    local maxOffset = math.max(0, state.total - state.capacity)
    if IsShiftKeyDown and IsShiftKeyDown() then
        state.offset = delta > 0 and 0 or maxOffset
    else
        state.offset = math.max(0, math.min(maxOffset, state.offset - delta))
    end
    DamageMeterTab.Refresh()
end

-- =========================
-- Display
-- =========================
local function CreateDisplay()
    if display then return end
    display = CreateFrame("Frame", nil, UIParent)
    display:Hide()
    -- Clicks pass through to the chat window; the wheel scrolls the lines.
    display:EnableMouse(false)
    display:EnableMouseWheel(true)
    display:SetScript("OnMouseWheel", OnMouseWheel)

    headerRight = display:CreateFontString(nil, "OVERLAY")
    headerRight:SetJustifyH("RIGHT")
    headerRight:SetWordWrap(false)
    headerRight:SetPoint("TOPRIGHT", display, "TOPRIGHT", 0, 0)

    header = display:CreateFontString(nil, "OVERLAY")
    header:SetJustifyH("LEFT")
    header:SetWordWrap(false)
    header:SetPoint("TOPLEFT", display, "TOPLEFT", 0, 0)
    header:SetPoint("RIGHT", headerRight, "LEFT", -VALUE_GAP, 0)
    headerClick = CreateClickArea()

    menuButton = CreateMenuButton()

    display:SetScript("OnShow", function(self)
        self.elapsed = 0
        state.dirty = true
        Try(PlaceMenuButton)
        if menuButton then menuButton:Show() end
        Try(DamageMeterTab.Refresh)
        Try(MirrorChannelButton)
    end)
    display:SetScript("OnHide", function()
        if menuButton then menuButton:Hide() end
    end)
    -- The chat window got its size, or was resized: lay the lines out again.
    display:SetScript("OnSizeChanged", MarkDirty)
    display:SetScript("OnUpdate", OnDisplayUpdate)
end

local function Attach(window)
    if not window then return false end
    CreateDisplay()
    if display:GetParent() ~= window then
        display:SetParent(window)
        display:ClearAllPoints()
        display:SetAllPoints(window)
        display:SetFrameLevel((window:GetFrameLevel() or 0) + 5)
    end
    display:Show()
    MarkDirty()
    Try(DamageMeterTab.Refresh)
    FitAttachedTab()
    return true
end

local function Detach()
    if not display then return end
    RestoreCollapseButtons()
    state.pulledOut = false
    display:Hide()
    display:SetParent(UIParent)
    display:ClearAllPoints()
end

-- =========================
-- The game's own meter window
-- =========================
-- What the game last asked for, so turning the option off shows the window
-- only when the game wants it shown.
local floatingMeter = { hooked = false, wanted = false, hiding = false }

local function FloatingMeterFrame()
    return _G.DamageMeter
end

-- The meter sets this before it shows or hides itself for Edit Mode.
local function IsEditingFloatingMeter(frame)
    return frame.isEditing == true
end

function DamageMeterTab.ApplyFloatingMeter()
    local frame = FloatingMeterFrame()
    if not frame or not floatingMeter.hooked then return end
    floatingMeter.hiding = true
    if state.active and not IsEditingFloatingMeter(frame) then
        if frame:IsShown() then frame:Hide() end
    elseif floatingMeter.wanted and not frame:IsShown() then
        frame:Show()
    end
    floatingMeter.hiding = false
end

local function OnFloatingMeterShownRequested(shown)
    if floatingMeter.hiding then return end
    floatingMeter.wanted = shown and true or false
    DamageMeterTab.ApplyFloatingMeter()
end

-- Post-hooks on the window's own Show, Hide and SetShown: the game decides
-- when it shows (combat, group, Edit Mode), and it is hidden again right
-- after, without running the meter's code.
local function HookFloatingMeter()
    if floatingMeter.hooked then return true end
    local frame = FloatingMeterFrame()
    if not frame or type(frame.SetShown) ~= "function" then return false end
    floatingMeter.hooked = true
    floatingMeter.wanted = frame:IsShown() and true or false
    Carpenter:SafeHook(frame, "Show", function() OnFloatingMeterShownRequested(true) end)
    Carpenter:SafeHook(frame, "Hide", function() OnFloatingMeterShownRequested(false) end)
    Carpenter:SafeHook(frame, "SetShown", function(_, shown) OnFloatingMeterShownRequested(shown) end)
    return true
end

-- =========================
-- Events
-- =========================
local eventFrame = CreateFrame("Frame")

local function TryAttach()
    if not state.active then return end
    Attach(FindAndRenameWindow())
end

eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_DamageMeter" and HookFloatingMeter() then
            eventFrame:UnregisterEvent("ADDON_LOADED")
            DamageMeterTab.ApplyFloatingMeter()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The game restores its chat windows around now and can hide the tab
        -- for a moment, so it is looked for a few times.
        Carpenter:DeferMany("DamageMeterTab:login", LOGIN_SETTLE_SECONDS, function()
            state.chatReady = true
            TryAttach()
        end)
    elseif event == "UPDATE_CHAT_WINDOWS" then
        TryAttach()
    elseif event == "DAMAGE_METER_RESET" then
        -- The breakdown's player is gone with the data.
        LeaveBreakdown()
        StartOver()
    else
        MarkDirty()
    end
end)

local METER_EVENTS = {
    "DAMAGE_METER_COMBAT_SESSION_UPDATED",
    "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_RESET",
    "PLAYER_REGEN_ENABLED",
}

Carpenter:SafeRegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")

-- =========================
-- Feature
-- =========================
local feature = {}

function feature:Enable()
    state.active = true
    HookTabLayout()
    if HookFloatingMeter() then
        DamageMeterTab.ApplyFloatingMeter()
    else
        Carpenter:SafeRegisterEvent(eventFrame, "ADDON_LOADED")
    end
    Carpenter:SafeRegisterEvent(eventFrame, "UPDATE_CHAT_WINDOWS")
    for _, event in ipairs(METER_EVENTS) do
        Carpenter:SafeRegisterEvent(eventFrame, event)
    end
    local window = FindAndRenameWindow()
    -- Turned on in the settings: open the tab. At login the game restores it.
    if not window and state.chatReady then
        window = OpenWindow()
    end
    Attach(window)
end

function feature:Disable()
    state.active = false
    state.breakdown = nil
    eventFrame:UnregisterEvent("ADDON_LOADED")
    DamageMeterTab.ApplyFloatingMeter()
    eventFrame:UnregisterEvent("UPDATE_CHAT_WINDOWS")
    for _, event in ipairs(METER_EVENTS) do
        eventFrame:UnregisterEvent(event)
    end
    Detach()
    if state.chatReady then
        CloseWindow(DamageMeterTab.FindWindow())
    end
end

DamageMeterTab.feature = feature
DamageMeterTab.state = state

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end

local _, ns = ...
if ns then
    ns.Private = ns.Private or {}
    ns.Private.DamageMeterTab = DamageMeterTab
end
