--[[ Carpenter - Damage Meter Tab ]]
-- Shows the game's damage meter as plain text in a chat tab of its own, on
-- Retail and WoW Forever: a yellow title line with the meter type and
-- segment, then one line per player, "1. Name" in class color on the left
-- and "total (per second)" on the right, in the chat window's own font. An
-- arrow in the tab's top-right corner, shown while the mouse is over the
-- window, picks the meter type and segment and resets the data.
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
local LOGIN_SETTLE_SECONDS = 1
local VALUE_GAP = 8
local MENU_BUTTON_INSET_X, MENU_BUTTON_INSET_Y = 4, 6
local FALLBACK_FONT_SIZE = 14

local L = (Carpenter and Carpenter.L) or {}
local HoverFade = Carpenter.HoverFade

local DamageMeterTab = {}
local state = {
    active = false,
    -- The game has restored its chat windows, so a missing tab is really
    -- missing.
    chatReady = false,
    dirty = true,
}

local function Text(key, fallback)
    return L[key] or fallback
end

local function TabName()
    return _G.DAMAGE_METER_LABEL or "Damage Meter"
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

local function SelectType(meterType)
    if CarpenterDB then CarpenterDB.damageMeterTabType = meterType end
    MarkDirty()
end

local function SelectSession(sessionType)
    if CarpenterDB then CarpenterDB.damageMeterTabSession = sessionType end
    MarkDirty()
end

-- =========================
-- The chat window
-- =========================
local function ChatWindowCount()
    return _G.NUM_CHAT_WINDOWS or 10
end

-- The open chat window carrying the tab's name. The General and Combat Log
-- windows are never taken, whatever they are called.
function DamageMeterTab.FindWindow()
    if type(GetChatWindowInfo) ~= "function" then return nil end
    local name = TabName()
    for index = 3, ChatWindowCount() do
        local ok, windowName, _, _, _, _, _, shown = pcall(GetChatWindowInfo, index)
        local frame = _G["ChatFrame" .. index]
        if ok and windowName == name and shown and frame then
            return frame, index
        end
    end
    return nil
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
local display, header, menuButton, fader
local rows = {}

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

local function GetRow(slot)
    local row = rows[slot]
    if row then return row end
    row = {
        name = display:CreateFontString(nil, "OVERLAY"),
        value = display:CreateFontString(nil, "OVERLAY"),
    }
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
    end
end

local function ClassColor(classFilename)
    local colors = _G.RAID_CLASS_COLORS
    local color = type(classFilename) == "string" and classFilename ~= "" and colors and colors[classFilename]
    if color then return color.r, color.g, color.b end
    return 0.8, 0.8, 0.8
end

-- Every field but the class and the local player flag may be hidden in
-- combat, so each goes to the text as it is.
local function FillRow(row, index, source, meterType)
    row.name:SetFormattedText(_G.DAMAGE_METER_SOURCE_NAME or "%d. %s", index, source.name)
    row.name:SetTextColor(ClassColor(source.classFilename))

    local main, extra = source.totalAmount, source.amountPerSecond
    if ShowsPerSecondFirst(meterType) then main, extra = extra, main end
    if HasNoPerSecond(meterType) then
        row.value:SetText(AbbreviateLargeNumbers(main))
    else
        row.value:SetFormattedText(_G.DAMAGE_METER_ENTRY_FORMAT_COMPACT or "%s (%s)",
            AbbreviateLargeNumbers(main), AbbreviateLargeNumbers(extra))
    end
    row.value:SetTextColor(1, 1, 1)
    row.name:Show()
    row.value:Show()
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

local function HeaderText(meterType, sessionType)
    local text = "|cffffd200" .. TypeName(meterType) .. "|r  |cff999999" .. SessionName(sessionType)
    if C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds and SecondsToClock then
        local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, sessionType)
        local hidden = issecretvalue and issecretvalue(seconds)
        if ok and not hidden and type(seconds) == "number" and seconds > 0 then
            text = text .. " [" .. SecondsToClock(seconds) .. "]"
        end
    end
    return text .. "|r"
end

-- Which sources fill the lines: the top ones, with the local player kept on
-- the last line when they rank lower, as the game's meter does.
local function PickSources(sources, capacity)
    local picked = {}
    local count = math.min(#sources, capacity)
    for index = 1, count do picked[index] = index end
    if count > 0 and count < #sources then
        for index = count + 1, #sources do
            if sources[index].isLocalPlayer == true then
                picked[count] = index
                break
            end
        end
    end
    return picked
end

local function FillRows(window, lineHeight, capacity)
    local meterType, sessionType = SelectedType(), SelectedSession()
    local reason = UnavailableReason()
    if reason then
        local row = GetRow(1)
        PlaceRow(row, 1, window, lineHeight)
        row.name:SetText(reason)
        row.name:SetTextColor(0.6, 0.6, 0.6)
        row.value:SetText("")
        row.name:Show()
        row.value:Show()
        HideRows(2)
        return
    end

    local session = C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)
    local sources = type(session) == "table" and session.combatSources or {}
    local picked = PickSources(sources, capacity)
    for slot, index in ipairs(picked) do
        local row = GetRow(slot)
        PlaceRow(row, slot, window, lineHeight)
        FillRow(row, index, sources[index], meterType)
    end
    HideRows(#picked + 1)
end

function DamageMeterTab.Refresh()
    if not display or not display:IsVisible() then return end
    local window = display:GetParent()
    state.dirty = false

    local lineHeight = LineHeight(window)
    local capacity = math.max(0, math.floor((display:GetHeight() or 0) / lineHeight) - 1)
    local meterType, sessionType = SelectedType(), SelectedSession()

    StyleFontString(header, window)
    header:SetText(HeaderText(meterType, sessionType))

    -- A failure keeps the lines already shown rather than blanking the tab.
    pcall(FillRows, window, lineHeight, capacity)
end

local function InCombat()
    return (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false
end

local function OnDisplayUpdate(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < REFRESH_SECONDS then return end
    self.elapsed = 0
    -- The segment timer runs in combat.
    if state.dirty or InCombat() then
        DamageMeterTab.Refresh()
    end
end

-- =========================
-- The menu arrow
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
            MarkDirty()
        end)
    end
end

local function IsMenuOpen()
    return menuButton and menuButton.IsMenuOpen and menuButton:IsMenuOpen() == true
end

local function ShouldShowMenuButton()
    if not display or not display:IsVisible() then return false end
    if IsMenuOpen() then return true end
    local window = display:GetParent()
    return HoverFade.IsMouseOverFrame(window) or HoverFade.IsMouseOverFrame(menuButton)
end

-- =========================
-- Display
-- =========================
local function CreateDisplay()
    if display then return end
    display = CreateFrame("Frame", nil, UIParent)
    display:Hide()
    display:EnableMouse(false)

    header = display:CreateFontString(nil, "OVERLAY")
    header:SetJustifyH("LEFT")
    header:SetWordWrap(false)
    header:SetPoint("TOPLEFT", display, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", display, "TOPRIGHT", -24, 0)

    local ok, button = pcall(CreateFrame, "DropdownButton", nil, display, "WowStyle1ArrowDropdownTemplate")
    if ok and button and button.SetupMenu then
        menuButton = button
        menuButton:SetPoint("TOPRIGHT", display, "TOPRIGHT", MENU_BUTTON_INSET_X, MENU_BUTTON_INSET_Y)
        menuButton:SetupMenu(SetupMenu)
        menuButton:SetAlpha(0)
        fader = HoverFade.Create({
            isEnabled = function() return state.active end,
            shouldShow = ShouldShowMenuButton,
            apply = function(alpha) menuButton:SetAlpha(alpha) end,
        })
    end

    display:SetScript("OnShow", function(self)
        self.elapsed = 0
        state.dirty = true
        DamageMeterTab.Refresh()
        if fader then fader:Start(0) end
    end)
    display:SetScript("OnHide", function()
        if fader then fader:Stop(0) end
    end)
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
    DamageMeterTab.Refresh()
    return true
end

local function Detach()
    if not display then return end
    display:Hide()
    display:SetParent(UIParent)
    display:ClearAllPoints()
end

-- =========================
-- Events
-- =========================
local eventFrame = CreateFrame("Frame")

local function TryAttach()
    if not state.active then return end
    Attach(DamageMeterTab.FindWindow())
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Carpenter:After(LOGIN_SETTLE_SECONDS, function()
            state.chatReady = true
            TryAttach()
        end)
    elseif event == "UPDATE_CHAT_WINDOWS" then
        TryAttach()
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
    Carpenter:SafeRegisterEvent(eventFrame, "UPDATE_CHAT_WINDOWS")
    for _, event in ipairs(METER_EVENTS) do
        Carpenter:SafeRegisterEvent(eventFrame, event)
    end
    local window = DamageMeterTab.FindWindow()
    -- Turned on in the settings: open the tab. At login the game restores it.
    if not window and state.chatReady then
        window = OpenWindow()
    end
    Attach(window)
end

function feature:Disable()
    state.active = false
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
