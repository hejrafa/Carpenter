#!/usr/bin/env lua
-- Offline fixture checks for the Damage Meter Tab.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "damage-meter-tab")
local fail, assertEqual, assertTrue = H.fail, H.assertEqual, H.assertTrue
local unpack = unpack or table.unpack

-- =========================
-- Values the game hides in combat
-- =========================
-- Any math, comparison or joining on one raises an error, as in the game.
local secretMeta = {}
local function Refuse() error("attempt to use a secret value") end
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__concat", "__lt", "__le", "__len" }) do
    secretMeta[event] = Refuse
end
local function Secret(value) return setmetatable({ secret = value }, secretMeta) end
local function IsSecret(value) return getmetatable(value) == secretMeta end
local function Reveal(value) if IsSecret(value) then return value.secret end return value end
issecretvalue = function(value) return IsSecret(value) end
-- A hidden value still reports its own type.
local rawType = type
type = function(value)
    if IsSecret(value) then return rawType(value.secret) end
    return rawType(value)
end

-- The game formats hidden numbers into hidden text.
AbbreviateLargeNumbers = function(number)
    local text = tostring(Reveal(number))
    if IsSecret(number) then return Secret(text) end
    return text
end
SecondsToClock = function(seconds) return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) end

-- =========================
-- Frames with text
-- =========================
local function NewFontString(parent)
    local fontString = H.Frame({ parent = parent, text = nil })
    function fontString:SetFont(file, size, flags) self.font = { file, size, flags } end
    function fontString:SetFontObject(object) self.fontObject = object end
    function fontString:SetShadowOffset() end
    function fontString:SetShadowColor() end
    function fontString:SetJustifyH(justify) self.justifyH = justify end
    function fontString:SetWordWrap() end
    function fontString:SetText(text) self.text = Reveal(text) end
    function fontString:SetFormattedText(format, ...)
        local args = { ... }
        for index = 1, select("#", ...) do args[index] = Reveal(args[index]) end
        self.text = string.format(format, unpack(args, 1, select("#", ...)))
    end
    function fontString:SetTextColor(r, g, b) self.color = { r, g, b } end
    return fontString
end

local function AddFrameMethods(frame)
    function frame:CreateFontString() return NewFontString(self) end
    function frame:SetAllPoints(target) self.allPoints = target end
    function frame:GetHeight()
        if self.allPoints then return self.allPoints:GetHeight() end
        return self.height
    end
    function frame:GetWidth()
        if self.allPoints then return self.allPoints:GetWidth() end
        return self.width
    end
    function frame:GetFont() return "Fonts\\ARIALN.TTF", 14, "" end
    function frame:GetSpacing() return 3 end
    function frame:EnableMouseWheel(enabled) self.wheelEnabled = enabled end
    function frame:GetEffectiveAlpha()
        local parent = self.parent
        if self.ignoreParentAlpha or not (parent and parent.GetEffectiveAlpha) then return self.alpha end
        return self.alpha * parent:GetEffectiveAlpha()
    end
    local show, hide = frame.Show, frame.Hide
    function frame:Show()
        local wasVisible = self:IsVisible()
        show(self)
        if not wasVisible and self:IsVisible() and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide()
        local wasVisible = self:IsVisible()
        hide(self)
        if wasVisible and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    return frame
end

local menuButtons = {}
CreateFrame = function(frameType, frameName, parent, template)
    local frame = AddFrameMethods(H.Frame({ name = frameName, parent = parent, objectType = frameType }))
    H.createdFrames[#H.createdFrames + 1] = frame
    if frameType == "DropdownButton" then
        if template ~= nil then error("unexpected template " .. tostring(template)) end
        function frame:SetupMenu(generator) self.generator = generator end
        function frame:IsMenuOpen() return self.menuOpen == true end
        function frame:SetMenuAnchor(anchor) self.menuAnchor = anchor end
        function frame:SetNormalAtlas(atlas) self.normalAtlas = atlas end
        function frame:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
        function frame:SetHighlightAtlas(atlas) self.highlightAtlas = atlas end
        function frame:CreateTexture()
            local texture = H.Frame({ parent = self })
            function texture:SetAtlas(atlas) self.atlas = atlas end
            return texture
        end
        menuButtons[#menuButtons + 1] = frame
    end
    return frame
end
H.installHooks()
H.installTimers("immediate")
UIParent = AddFrameMethods(H.Frame({ name = "UIParent" }))
AnchorUtil = { CreateAnchor = function(...) return { ... } end }
local knownAtlases = { ["friendslist-categorybutton-arrow-down"] = true }
C_Texture = { GetAtlasInfo = function(atlas) if knownAtlases[atlas] then return {} end end }
local shiftDown = false
IsShiftKeyDown = function() return shiftDown end

-- The chat button column. The channels button belongs to the General
-- window's buttons and hides with it while another tab is open; the social
-- button stays, faded by Hide Chat Buttons.
local channelColumn = AddFrameMethods(H.Frame({ name = "ChatFrame1ButtonFrame", shown = false }))
ChatFrameChannelButton = AddFrameMethods(H.Frame({ name = "ChatFrameChannelButton", parent = channelColumn, strata = "MEDIUM", level = 6 }))
QuickJoinToastButton = AddFrameMethods(H.Frame({ name = "QuickJoinToastButton", parent = UIParent }))

-- =========================
-- Chat windows
-- =========================
NUM_CHAT_WINDOWS = 10
DAMAGE_METER_LABEL = "Damage Meter"
local windows = {
    [1] = { name = "General", shown = true },
    [2] = { name = "Combat Log", shown = true },
}
-- Docked windows; each has its own button column, topped by a collapse
-- button the game hides while docked.
for index = 1, NUM_CHAT_WINDOWS do
    local frame = AddFrameMethods(H.Frame({ name = "ChatFrame" .. index, level = 3, width = 300, height = 120, shown = false }))
    frame.isDocked = true
    frame.buttonFrame = AddFrameMethods(H.Frame({ name = "ChatFrame" .. index .. "ButtonFrame", parent = frame, alpha = 1 }))
    frame.buttonFrame.minimizeButton = AddFrameMethods(H.Frame({ parent = frame.buttonFrame, shown = false, strata = "LOW", level = 8 }))
    frame.buttonFrame.minimizeButton:SetPoint("TOP", frame.buttonFrame, "TOP", 0, 4)
    _G["ChatFrame" .. index] = frame
end
DEFAULT_CHAT_FRAME = ChatFrame1
GetChatWindowInfo = function(index)
    local window = windows[index]
    if not window then return "", 14, 0, 0, 0, 0, false end
    return window.name, 14, 0, 0, 0, 0, window.shown
end

local opened, closed, popups = {}, {}, {}
FCF_OpenNewWindow = function(name, noDefaultChannels)
    for index = 3, NUM_CHAT_WINDOWS do
        if not (windows[index] and windows[index].shown) then
            windows[index] = { name = name, shown = true }
            opened[#opened + 1] = { name = name, noDefaultChannels = noDefaultChannels }
            local frame = _G["ChatFrame" .. index]
            frame:Show()
            return frame, index
        end
    end
end
FCF_Close = function(frame)
    local index = tonumber(frame:GetName():match("%d+$"))
    windows[index].shown = false
    closed[#closed + 1] = index
    frame:Hide()
end
StaticPopupDialogs = {}
StaticPopup_Show = function(name) popups[#popups + 1] = name end
ReloadUI = function() end

-- =========================
-- The damage meter
-- =========================
Enum = {
    DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5,
        Dispels = 6, DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 },
    DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 },
}
local Types, Sessions = Enum.DamageMeterType, Enum.DamageMeterSessionType
DAMAGE_METER_TYPE_DAMAGE_DONE = "Damage Done"
DAMAGE_METER_TYPE_DPS = "DPS"
DAMAGE_METER_TYPE_INTERRUPTS = "Interrupts"
DAMAGE_METER_CURRENT_SESSION = "Current Segment"
DAMAGE_METER_OVERALL_SESSION = "Overall"
DAMAGE_METER_SOURCE_NAME = "%d. %s"
DAMAGE_METER_ENTRY_FORMAT_COMPACT = "%s (%s)"
RAID_CLASS_COLORS = {
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
}

local meter = { enabled = true, available = true, inCombat = false, duration = 83, sources = {}, requests = {}, resets = 0 }
C_CVar = { GetCVarBool = function(name) if name == "damageMeterEnabled" then return meter.enabled end end }
C_DamageMeter = {
    IsDamageMeterAvailable = function() return meter.available, meter.available and "" or "Not here" end,
    GetSessionDurationSeconds = function()
        if meter.inCombat then return Secret(meter.duration) end
        return meter.duration
    end,
    GetCombatSessionFromType = function(sessionType, meterType)
        meter.requests[#meter.requests + 1] = { sessionType = sessionType, meterType = meterType }
        local sources = {}
        for index, source in ipairs(meter.sources) do
            local hide = meter.inCombat and Secret or function(value) return value end
            sources[index] = {
                name = hide(source.name),
                classFilename = source.classFilename,
                isLocalPlayer = source.isLocalPlayer == true,
                totalAmount = hide(source.total),
                amountPerSecond = hide(source.perSecond),
            }
        end
        return { combatSources = sources, maxAmount = 0, totalAmount = 0 }
    end,
    ResetAllCombatSessions = function() meter.resets = meter.resets + 1 end,
}
UnitAffectingCombat = function() return meter.inCombat end

-- The game's floating meter window; it shows itself as its settings say.
DamageMeter = AddFrameMethods(H.Frame({ name = "DamageMeter", shown = true }))

-- =========================
-- Carpenter
-- =========================
CarpenterDB = { damageMeterTabEnabled = true }
local ns = { Private = {} }
H.carpenter({
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = H.captureFeature("damageMeterTabEnabled"),
    Client = { isMainline = true, isForever = true },
    L = {},
})
H.load("Core/HoverFade.lua", ns)
H.load("Modules/DamageMeterTab.lua", ns)
local feature = H.features.damageMeterTabEnabled
if not feature then fail("the Damage Meter Tab did not register its feature") end
local Tab = ns.Private.DamageMeterTab
local eventFrame = H.createdFrames[1]

local function Fire(event, ...)
    eventFrame.scripts.OnEvent(eventFrame, event, ...)
end

local function Display()
    for _, frame in ipairs(H.createdFrames) do
        if frame.scripts.OnUpdate and frame.allPoints then return frame end
    end
end

-- The text on the display, by line: header, then "name | value". The
-- header's right side lands in headerRightText.
local headerRightText
local function Read(display)
    local header, names, values = nil, {}, {}
    for _, region in ipairs(display.children or {}) do
        if region.shown and region.points[1] then
            local point, _, _, _, y = unpack(region.points[1])
            local line = math.floor(-(y or 0) / 17 + 0.5)
            if line == 0 and point == "TOPLEFT" then
                header = region.text
            elseif line == 0 and point == "TOPRIGHT" then
                headerRightText = region.text
            elseif point == "TOPLEFT" then
                names[line] = region
            elseif point == "TOPRIGHT" and region.objectType ~= "DropdownButton" then
                values[line] = region
            end
        end
    end
    return header, names, values
end

local function StripColors(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- =========================
-- Login with the option on and no tab yet: nothing opens on its own.
-- =========================
feature.enabled = true
feature:Enable()
assertEqual(#opened, 0, "enabling before login should not open a chat window")
assertEqual(DamageMeter.shown, false, "the game's floating meter should hide")
DamageMeter:SetShown(true)
assertEqual(DamageMeter.shown, false, "the floating meter should stay hidden when the game shows it")
DamageMeter:Show()
assertEqual(DamageMeter.shown, false, "the floating meter should stay hidden after Show")
DamageMeter.isEditing = true
DamageMeter:SetShown(true)
assertEqual(DamageMeter.shown, true, "the floating meter should show in Edit Mode")
DamageMeter.isEditing = false
DamageMeter:SetShown(true)
assertEqual(DamageMeter.shown, false, "the floating meter should hide again after Edit Mode")
Fire("PLAYER_ENTERING_WORLD")
assertEqual(#opened, 0, "login should not open a chat window on its own")
assertEqual(#popups, 0, "login should not ask for a reload")

-- =========================
-- Turning the option on in the settings opens the tab.
-- =========================
feature:Disable()
assertEqual(#closed, 0, "turning off with no tab should close nothing")
assertEqual(#popups, 0, "turning off with no tab should not ask for a reload")

meter.sources = {
    { name = "Koji Hakamori", classFilename = "ROGUE", isLocalPlayer = true, total = 1491, perSecond = 124.3 },
    { name = "Suggo Battsuggovic", classFilename = "PRIEST", total = 900, perSecond = 70 },
}
feature:Enable()
assertEqual(#opened, 1, "turning the option on should open one chat window")
assertEqual(opened[1].name, "Damage Meter", "the tab should carry the game's Damage Meter label")
assertEqual(opened[1].noDefaultChannels, true, "the tab should receive no chat")
assertEqual(popups[1], "CARPENTER_DAMAGE_METER_TAB_RELOAD", "opening the tab should ask for a reload")
assertTrue(StaticPopupDialogs.CARPENTER_DAMAGE_METER_TAB_RELOAD ~= nil, "the reload popup should be defined")

local display = Display()
if not display then fail("the tab should get a display") end
assertEqual(display.parent, ChatFrame3, "the display should sit in the new chat window")
assertEqual(display.allPoints, ChatFrame3, "the display should cover the chat window")
assertTrue(display:IsVisible(), "the display should show with its tab")

local header, names, values = Read(display)
assertEqual(header, "Damage Done", "the header should name the type on the left")
assertEqual(headerRightText, "Current Segment [1:23]", "the header should show the segment and time on the right")
for _, region in ipairs(display.children) do
    if region.text == "Current Segment [1:23]" then
        assertEqual(region.color and region.color[2], 0.82, "the segment should share the title's yellow")
    end
end
assertEqual(names[1] and names[1].text, "Koji Hakamori", "the first line should be the top source, without a rank")
assertEqual(values[1] and values[1].text, "1491 (124.3)", "the first value should be total and per second")
assertEqual(names[2] and names[2].text, "Suggo Battsuggovic", "the second line should be the next source")
assertEqual(names[1].color[1], 1.00, "names should be in class color")
assertEqual(names[1].color[2], 0.96, "names should be in class color")
assertEqual(names[1].font[2], 14, "lines should use the chat window's font size")
local request = meter.requests[#meter.requests]
assertEqual(request.sessionType, Sessions.Current, "the tab should start on the current segment")
assertEqual(request.meterType, Types.DamageDone, "the tab should start on damage done")

-- =========================
-- In combat every name and amount is hidden from addons.
-- =========================
meter.inCombat = true
meter.sources[1].total = 2500
Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", Types.DamageDone, 1)
display.scripts.OnUpdate(display, 0.6)
header, names, values = Read(display)
assertEqual(values[1] and values[1].text, "2500 (124.3)", "hidden amounts should still show")
assertEqual(names[1] and names[1].text, "Koji Hakamori", "hidden names should still show")
assertEqual(headerRightText, "Current Segment", "a hidden segment time should be left out")
meter.inCombat = false

-- =========================
-- Types that read differently
-- =========================
CarpenterDB.damageMeterTabType = Types.Dps
Tab.Refresh()
header, names, values = Read(display)
assertEqual(values[1] and values[1].text, "124.3 (2500)", "DPS should show per second first")

CarpenterDB.damageMeterTabType = Types.Interrupts
meter.sources[1].total = 3
Tab.Refresh()
header, names, values = Read(display)
assertEqual(values[1] and values[1].text, "3", "interrupts should show a count alone")

CarpenterDB.damageMeterTabType = Types.Deaths
Tab.Refresh()
assertEqual(meter.requests[#meter.requests].meterType, Types.DamageDone, "a type the tab doesn't offer should fall back to damage done")
CarpenterDB.damageMeterTabType = nil
meter.sources[1].total = 2500

-- =========================
-- A short window keeps the local player on its last line.
-- =========================
meter.sources = {
    { name = "A", classFilename = "PRIEST", total = 500, perSecond = 50 },
    { name = "B", classFilename = "PRIEST", total = 400, perSecond = 40 },
    { name = "C", classFilename = "PRIEST", total = 300, perSecond = 30 },
    { name = "Koji Hakamori", classFilename = "ROGUE", isLocalPlayer = true, total = 200, perSecond = 20 },
}
ChatFrame3.height = 17 * 3 + 5
Tab.Refresh()
header, names, values = Read(display)
assertEqual(names[1] and names[1].text, "A", "the top source should keep the first line")
assertEqual(names[2] and names[2].text, "4. Koji Hakamori", "the local player should take the last line, with its rank")
assertTrue(names[3] == nil, "nothing should show past the window's height")
ChatFrame3.height = 120

-- =========================
-- The menu button covers the channels button and fades with it.
-- =========================
local button = menuButtons[1]
if not button then fail("the tab should have a menu button") end
local function Tick() display.scripts.OnUpdate(display, 0.01) end
local point = button.points[1]
assertEqual(point and point[2], ChatFrameChannelButton, "the menu button should sit on the channels button")
assertEqual(button.strata, "MEDIUM", "the menu button should share the channels button's strata")
assertEqual(button.level, 16, "the menu button should sit above the channels button")
assertEqual(button.normalAtlas, "chatframe-button-up", "the menu button should use the chat button art")
assertEqual(button.ignoreParentAlpha, true, "the menu button should fade on its own")
assertEqual(button.parent, UIParent, "the menu button should not be drawn inside the chat window")
assertEqual(button.shown, true, "the menu button should show with the tab")

QuickJoinToastButton.alpha = 0
Tick()
assertEqual(button.alpha, 0, "a faded social button should hide the menu button")
QuickJoinToastButton.alpha = 0.4
Tick()
assertEqual(button.alpha, 0.4, "the menu button should fade with the chat buttons beside it")
QuickJoinToastButton.alpha = 1
Tick()
assertEqual(button.alpha, 1, "the menu button should show with the chat buttons")
QuickJoinToastButton.alpha = 0
button.menuOpen = true
Tick()
assertEqual(button.alpha, 1, "the menu button should stay while its menu is open")
button.menuOpen = false
-- Without the social button it follows whichever chat button still shows.
QuickJoinToastButton.shown = false
channelColumn.shown, channelColumn.alpha, ChatFrameChannelButton.alpha = true, 0.5, 1
Tick()
assertEqual(button.alpha, 0.5, "the menu button should follow another visible chat button")
channelColumn.shown, channelColumn.alpha = false, 1
Tick()
assertEqual(button.alpha, 1, "with no chat button showing the menu button should stay up")
QuickJoinToastButton.shown, QuickJoinToastButton.alpha = true, 1

-- The menu picks the type and segment and resets the data.
local root = { items = {} }
local function Description(store)
    local description = { items = store }
    function description:SetTag() end
    function description:CreateButton(text, callback)
        local item = { kind = "button", text = text, callback = callback, items = {} }
        store[#store + 1] = item
        return Description(item.items)
    end
    function description:CreateRadio(text, isSelected, setSelected, data)
        store[#store + 1] = { kind = "radio", text = text, isSelected = isSelected, setSelected = setSelected, data = data }
    end
    function description:CreateDivider() store[#store + 1] = { kind = "divider" } end
    return description
end
button.generator(button, Description(root.items))
local dpsRadio, overallRadio, resetButton
local function Walk(items)
    for _, item in ipairs(items) do
        if item.kind == "radio" and item.data == Types.Dps and item.text == "DPS" then dpsRadio = item end
        if item.kind == "radio" and item.text == "Overall" then overallRadio = item end
        if item.kind == "button" and item.callback then resetButton = item end
        if item.items then Walk(item.items) end
    end
end
Walk(root.items)
if not (dpsRadio and overallRadio and resetButton) then fail("the menu should offer types, segments and a reset") end
dpsRadio.setSelected(dpsRadio.data)
overallRadio.setSelected(overallRadio.data)
assertEqual(CarpenterDB.damageMeterTabType, Types.Dps, "picking DPS should save it")
assertEqual(CarpenterDB.damageMeterTabSession, Sessions.Overall, "picking Overall should save it")
assertTrue(dpsRadio.isSelected(Types.Dps), "the menu should mark the picked type")
display.scripts.OnUpdate(display, 0.6)
request = meter.requests[#meter.requests]
assertEqual(request.meterType, Types.Dps, "the tab should follow the picked type")
assertEqual(request.sessionType, Sessions.Overall, "the tab should follow the picked segment")
resetButton.callback()
assertEqual(meter.resets, 1, "the reset should clear the meter")

-- =========================
-- The wheel scrolls the lines.
-- =========================
assertEqual(display.wheelEnabled, true, "the tab should take the mouse wheel")
assertTrue(display.mouseEnabled ~= true, "clicks should pass through to the chat window")
CarpenterDB.damageMeterTabType, CarpenterDB.damageMeterTabSession = nil, nil
meter.sources = {}
for index = 1, 9 do
    meter.sources[index] = { name = "P" .. index, classFilename = "PRIEST", total = 1000 - index, perSecond = 1,
        isLocalPlayer = index == 2 }
end
ChatFrame3.height = 17 * 4 + 5
Tab.Refresh()
local Wheel = display.scripts.OnMouseWheel
header, names = Read(display)
assertEqual(names[1] and names[1].text, "P1", "the list should start at the top")
assertEqual(names[3] and names[3].text, "P3", "three lines should fit")
Wheel(display, -1)
header, names = Read(display)
assertEqual(names[1] and names[1].text, "P2", "the wheel down should move one line")
assertEqual(names[3] and names[3].text, "P4", "the wheel down should bring the next line in")
Wheel(display, -1)
header, names = Read(display)
assertEqual(names[1] and names[1].text, "2. P2", "the local player should keep the first line once scrolled past, with its rank")
assertEqual(names[2] and names[2].text, "P4", "the lines after it should follow the scroll")
shiftDown = true
Wheel(display, -1)
header, names = Read(display)
assertEqual(names[3] and names[3].text, "P9", "Shift and the wheel down should jump to the bottom")
Wheel(display, -1)
header, names = Read(display)
assertEqual(names[3] and names[3].text, "P9", "the wheel should stop at the bottom")
Wheel(display, 1)
header, names = Read(display)
assertEqual(names[1] and names[1].text, "P1", "Shift and the wheel up should jump to the top")
shiftDown = false
Wheel(display, 1)
header, names = Read(display)
assertEqual(names[1] and names[1].text, "P1", "the wheel should stop at the top")
Wheel(display, -1)
Wheel(display, -1)
dpsRadio.setSelected(dpsRadio.data)
display.scripts.OnUpdate(display, 0.6)
header, names = Read(display)
assertEqual(names[1] and names[1].text, "P1", "a new type should start at the top")
Wheel(display, -1)
meter.sources = { meter.sources[1], meter.sources[2] }
Tab.Refresh()
header, names = Read(display)
assertEqual(names[1] and names[1].text, "P1", "a shorter list should scroll back into view")
ChatFrame3.height = 120
CarpenterDB.damageMeterTabType = nil

-- =========================
-- A segment with no fight yet says so.
-- =========================
local savedSources = meter.sources
meter.sources = {}
Tab.Refresh()
header, names, values = Read(display)
assertEqual(names[1] and names[1].text, "Nothing recorded in this segment yet.", "an empty segment should say so")
assertEqual(names[1].color[1], 0.6, "the empty segment's line should be gray")
assertTrue(names[2] == nil, "an empty segment should show nothing else")
meter.sources = savedSources
Tab.Refresh()
header, names = Read(display)
assertTrue(names[1] and names[1].text ~= "Nothing recorded in this segment yet.", "the list should come back with data")

-- =========================
-- A meter that is off says so.
-- =========================
meter.enabled = false
Tab.Refresh()
header, names = Read(display)
assertTrue(names[1] and names[1].text:find("Turn on the damage meter", 1, true) ~= nil, "a meter that is off should say how to turn it on")
meter.enabled = true

-- =========================
-- Turning the option off closes the tab.
-- =========================
popups = {}
-- Out of combat the game hides its meter (shown only in combat), then the
-- option goes off: the meter stays as the game left it.
DamageMeter:SetShown(false)
feature:Disable()
assertEqual(DamageMeter.shown, false, "turning off should leave a meter the game hid hidden")
DamageMeter:SetShown(true)
assertEqual(closed[1], 3, "turning the option off should close the tab")
assertEqual(popups[1], "CARPENTER_DAMAGE_METER_TAB_RELOAD", "closing the tab should ask for a reload")
assertTrue(not display:IsVisible(), "the display should hide")
assertEqual(button.shown, false, "the menu button should hide with the tab")
assertEqual(DamageMeter.shown, true, "with the option off the game should show its meter again")
DamageMeter:SetShown(false)
assertEqual(DamageMeter.shown, false, "with the option off the game should hide its meter as it likes")
DamageMeter:SetShown(true)
assertEqual(DamageMeter.shown, true, "with the option off the game should show its meter as it likes")

-- =========================
-- After the reload the game restores the tab, and it is only drawn on.
-- =========================
opened, popups = {}, {}
windows[4] = { name = "Damage Meter", shown = true }
ChatFrame4:Show()
-- Right after the reload the window has no size yet.
ChatFrame4.width, ChatFrame4.height = 0, 0
local requestsBefore = #meter.requests
feature:Enable()
display.scripts.OnUpdate(display, 0.6)
assertEqual(#meter.requests, requestsBefore, "a window without a size should not be filled yet")
ChatFrame4.width, ChatFrame4.height = 300, 120
display.scripts.OnSizeChanged(display)
display.scripts.OnUpdate(display, 0.6)
assertTrue(#meter.requests > requestsBefore, "the tab should fill once the window has a size")
header, names = Read(display)
assertEqual(header, "Damage Done", "the header should show once the window has a size")
assertTrue(names[1] ~= nil, "the lines should show once the window has a size")
assertEqual(#opened, 0, "an existing tab should not be opened again")
assertEqual(#popups, 0, "drawing on an existing tab should not ask for a reload")
assertEqual(display.parent, ChatFrame4, "the display should move to the existing tab")
assertTrue(display.scripts.OnSizeChanged ~= nil, "a resized chat window should lay the lines out again")
assertEqual(DamageMeter.shown, false, "turning on again should hide the floating meter")

-- Pulling the tab out of the dock moves the menu button to its window.
local collapse = ChatFrame4.buttonFrame.minimizeButton
ChatFrame4.isDocked, collapse.shown = nil, true
Tick()
local menuPoint = button.points[1]
assertEqual(menuPoint and menuPoint[2], ChatFrame4.buttonFrame, "a pulled-out tab should top its own button column with the menu button")
assertEqual(menuPoint and menuPoint[1], "TOP", "the menu button should sit at the column's top")
local collapsePoint = collapse.points[1]
assertEqual(collapsePoint and collapsePoint[2], button, "the collapse button should move under the menu button")
assertEqual(collapsePoint and collapsePoint[3], "BOTTOM", "the collapse button should hang from the menu button's bottom")
assertEqual(button.strata, "LOW", "the menu button should share the column's strata")
ChatFrame4.buttonFrame.alpha = 0.2
Tick()
assertEqual(button.alpha, 0.2, "the menu button should fade with its window's button column")
ChatFrame4.buttonFrame.alpha = 1
Tick()
assertEqual(button.alpha, 1, "the menu button should show with its window's button column")

-- Docking it again puts both back.
ChatFrame4.isDocked, collapse.shown = true, false
Tick()
menuPoint = button.points[1]
assertEqual(menuPoint and menuPoint[2], ChatFrameChannelButton, "a docked tab should put the menu button back on the channels button")
collapsePoint = collapse.points[1]
assertEqual(collapsePoint and collapsePoint[2], ChatFrame4.buttonFrame, "docking should give the collapse button its own anchor back")
assertEqual(collapsePoint and collapsePoint[5], 4, "the collapse button should keep the game's offset")
assertEqual(#collapse.points, 1, "the collapse button should have only its own anchor")

-- Turning off while pulled out also gives the collapse button back.
ChatFrame4.isDocked, collapse.shown = nil, true
Tick()
assertEqual(collapse.points[1][2], button, "the collapse button should move under the menu button again")
feature:Disable()
assertEqual(DamageMeter.shown, true, "turning off should bring back a floating meter the game wants shown")
assertEqual(collapse.points[1][2], ChatFrame4.buttonFrame, "turning off should give the collapse button its own anchor back")
ChatFrame4.isDocked = true

-- The General and Combat Log windows are never taken, whatever their names.
windows[1].name, windows[4].shown = "Damage Meter", false
ChatFrame4:Hide()
assertTrue(Tab.FindWindow() == nil, "the General window should never count as the tab")

print("damage-meter-tab fixtures passed")
