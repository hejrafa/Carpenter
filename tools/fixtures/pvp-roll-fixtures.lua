#!/usr/bin/env lua
-- Offline checks for the PvP Roll: the game's /roll line in every language,
-- player names, and rolls between party members from start to winner.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "pvp-roll")
local assertEqual, assertTrue, assertContains = H.assertEqual, H.assertTrue, H.assertContains

local function read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

-- =========================
-- Game mocks
-- =========================
local now = 100
GetTime = function() return now end

-- Timers run in order of when they are due as the clock moves on.
local timers = {}
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { due = now + (delay or 0), callback = callback }
    end,
}
local function advance(seconds)
    local target = now + seconds
    while true do
        local nextIndex
        for index, timer in ipairs(timers) do
            if timer.due <= target and (not nextIndex or timer.due < timers[nextIndex].due) then
                nextIndex = index
            end
        end
        if not nextIndex then break end
        local timer = table.remove(timers, nextIndex)
        if timer.due > now then now = timer.due end
        timer.callback()
    end
    now = target
end

-- Hidden values: only this sentinel is secret.
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(value) return value == SECRET end

-- Widgets: every method exists; the ones the checks read keep their state.
local created = {}
local onEvent
local function noop() end
local Widget
local WIDGET_FIELDS = {
    Animation = true, RollNumber = true, Anim = true, Icon = true, Name = true, Timer = true,
    RollButton = true, Waiting = true, Pass = true, effects = true, animations = true, text = true,
    color = true, atlas = true, texture = true, alpha = true, playing = true, plays = true, kind = true,
    scale = true, point = true, value = true, template = true, shadow = true, width = true, height = true,
}
local widgetMethods = {
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    SetShown = function(self, shown) self.shown = shown and true or false end,
    IsShown = function(self) return self.shown == true end,
    SetAlpha = function(self, alpha) self.alpha = alpha end,
    GetAlpha = function(self) return self.alpha or 1 end,
    SetText = function(self, text) self.text = text end,
    GetText = function(self) return self.text end,
    SetTextColor = function(self, r, g, b) self.color = { r, g, b } end,
    SetScript = function(self, script, handler)
        self.scripts[script] = handler
        if script == "OnEvent" then onEvent = function(...) handler(self, ...) end end
    end,
    GetScript = function(self, script) return self.scripts[script] end,
    RegisterEvent = function(self, event) self.events[event] = true end,
    SetAtlas = function(self, atlas) self.atlas = atlas end,
    SetScale = function(self, scale) self.scale = scale end,
    SetValue = function(self, value) self.value = value end,
    SetPoint = function(self, ...) self.point = { ... } end,
    SetTexture = function(self, texture) self.texture = texture end,
    CreateTexture = function(self) return Widget("Texture", self) end,
    CreateFontString = function(self, _, _, template)
        local fontString = Widget("FontString", self)
        fontString.template = template
        return fontString
    end,
    SetShadowOffset = function(self, x, y) self.shadow = { x, y } end,
    SetSize = function(self, width, height) self.width, self.height = width, height end,
    CreateAnimationGroup = function(self)
        local group = Widget("AnimationGroup", self)
        group.Play = function(g) g.playing = true; g.plays = (g.plays or 0) + 1 end
        group.Stop = function(g) g.playing = false end
        group.IsPlaying = function(g) return g.playing == true end
        return group
    end,
    CreateAnimation = function(self, kind)
        local animation = Widget("Animation", self)
        animation.kind = kind
        self.animations = self.animations or {}
        self.animations[#self.animations + 1] = animation
        return animation
    end,
}
Widget = function(objectType, parent)
    -- Fields the module hangs on its widgets stay nil until it sets them.
    local widget = setmetatable({ objectType = objectType, parent = parent, scripts = {}, events = {} }, {
        __index = function(_, key)
            if widgetMethods[key] then return widgetMethods[key] end
            if WIDGET_FIELDS[key] then return nil end
            return noop
        end,
    })
    if objectType == "Frame" or objectType == "Button" or objectType == "StatusBar" then widget.shown = true end
    if objectType == "Texture" or objectType == "FontString" then widget.shown = true end
    created[#created + 1] = widget
    return widget
end
CreateFrame = function(objectType, name, parent)
    local frame = Widget(objectType, parent)
    if name then _G[name] = frame end
    return frame
end
UIParent = Widget("Frame")
GameTooltip = Widget("Frame")

-- The atlases Mainline clients have.
local ATLASES = {
    ["lootroll-animdice"] = true, ["lootroll-animdiceglow"] = true, ["lootroll-animreveal-a"] = true,
    ["lootroll-animreveal-b"] = true, ["lootroll-animrevealfade"] = true,
    ["lootroll-toast-icon-need-up"] = true, ["loottoast-itemborder-white"] = true,
}
C_Texture = { GetAtlasInfo = function(atlas) return ATLASES[atlas] and { width = 1 } or nil end }

SOUNDKIT = { UI_NEED_ROLL_POSITIVE = 1, UI_NEED_ROLL_NEGATIVE = 2, UI_NEED_ROLL_NEUTRAL = 3 }
local sounds = {}
PlaySound = function(id) sounds[#sounds + 1] = id end
RAID_CLASS_COLORS = { ROGUE = { colorStr = "fffff468" }, MAGE = { colorStr = "ff3fc7eb" } }
CLASS_ICON_TCOORDS = { ROGUE = { 0.5, 0.75, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 } }
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
-- Lines printed to your own chat window.
local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text, r, g, b) printed[#printed + 1] = { text = text, r = r, g = g, b = b } end }
QuestFont_Huge = {}
ROLL, PASS = "Roll", "Pass"

-- The party: you (Rafa, a rogue) and Bob (a mage).
local inGroup = true
local units = {
    player = { name = "Rafa", class = "ROGUE" },
    party1 = { name = "Bob", class = "MAGE" },
}
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
IsInGroup = function(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return false end
    return inGroup
end
UnitExists = function(unit) return units[unit] ~= nil end
UnitName = function(unit)
    local info = units[unit]
    if info then return info.name, info.second end
end
UnitGUID = function(unit) return units[unit] and ("Player-1-" .. unit) or nil end
UnitIsPlayer = function(unit) return units[unit] ~= nil and not units[unit].npc end
UnitClass = function(unit)
    local info = units[unit]
    if info and info.class then return info.class, info.class end
end
UnitIsConnected = function(unit) return units[unit] ~= nil and not units[unit].offline end
UnitCanAttack = function(_, unit) return units[unit] ~= nil and units[unit].hostile == true end

local sent, rolled = {}, {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) C_ChatInfo.registered = prefix end,
    SendAddonMessage = function(prefix, message, channel)
        sent[#sent + 1] = { prefix = prefix, message = message, channel = channel }
    end,
}
RandomRoll = function(low, high) rolled[#rolled + 1] = { low, high } end
SlashCmdList = {}

-- =========================
-- Load
-- =========================
local ns = { Private = {} }
H.carpenter({ Client = { isRetail = true }, IsEnabled = function() return false end })
H.load("Localization/enUS.lua", ns)
H.load("Core/Unit.lua", ns)
H.load("Modules/PvPRoll.lua", ns)
local PvPRoll = assert(ns.Private.PvPRoll, "PvP Roll did not load")
local L = Carpenter.L

assertEqual(C_ChatInfo.registered, "CarpenterRoll", "the addon message prefix should be registered")
assertEqual(SLASH_CARPENTERROLL1, "/cproll", "/cproll should be the command")
local slash = assert(SlashCmdList.CARPENTERROLL, "/cproll should be registered")

local function fire(event, ...) onEvent(event, ...) end
local function system(text) fire("CHAT_MSG_SYSTEM", text, "", "", "") end
local function addon(text, sender) fire("CHAT_MSG_ADDON", "CarpenterRoll", text, "PARTY", sender) end

-- =========================
-- The macro
-- =========================
local macro = assert(PvPRoll.Macros and PvPRoll.Macros[1], "the PvP Roll macro is missing")
assertEqual(#PvPRoll.Macros, 1, "the PvP section has one feature")
assertEqual(macro.name, "PvP Roll", "macro name")
assertEqual(macro.label, "Roll", "the row is labelled Roll")
assertEqual(macro.body, "/crack\n/cproll", "the macro cracks its knuckles, then rolls through Carpenter")
assertEqual(macro.icon, 237285, "macro icon")
assertTrue(#macro.name <= 16, "macro name is longer than a macro name allows")
for _, rp in ipairs((ns.Private.RPMacros or {}).Macros or {}) do
    assertTrue(rp.name ~= macro.name, "PvP Roll must not share a macro name with an RP macro")
end

-- =========================
-- The roll line in every language
-- =========================
-- RANDOM_ROLL_RESULT per locale (Forever's GlobalStrings) and a line in it.
local ROLL_LINES = {
    enUS = { "%s rolls %d (%d-%d)", "Bob rolls 57 (1-100)" },
    deDE = { "%1$s würfelt. Ergebnis: %2$d (%3$d-%4$d)", "Bob würfelt. Ergebnis: 57 (1-100)" },
    frFR = { "%s obtient un %d (%d-%d).", "Bob obtient un 57 (1-100)." },
    esES = { "%s tira los dados y obtiene %d (%d-%d)", "Bob tira los dados y obtiene 57 (1-100)" },
    ruRU = { "%s выбрасывает %d (%d-%d)", "Bob выбрасывает 57 (1-100)" },
    zhCN = { "%s掷出%d（%d-%d）", "Bob掷出57（1-100）" },
    zhTW = { "%s擲出%d（%d-%d）", "Bob擲出57（1-100）" },
    koKR = { "%s님이 주사위를 굴려 %d|1이;가; 나왔습니다. (%d-%d)", "Bob님이 주사위를 굴려 57이 나왔습니다. (1-100)" },
    ptBR = { "%s tira %d (%d-%d)", "Bob tira 57 (1-100)" },
}
for locale, case in pairs(ROLL_LINES) do
    local pattern, order = PvPRoll.BuildRollPattern(case[1])
    assertTrue(pattern, locale .. " roll pattern should build")
    local name, roll, low, high = PvPRoll.ParseRollLine(case[2], pattern, order)
    assertEqual(name, "Bob", locale .. " roller")
    assertEqual(roll, 57, locale .. " roll")
    assertEqual(low, 1, locale .. " low end")
    assertEqual(high, 100, locale .. " high end")
end
-- Arguments in another order still land in the right place.
local swapped, swappedOrder = PvPRoll.BuildRollPattern("(%3$d-%4$d) %2$d: %1$s")
local name, roll, low, high = PvPRoll.ParseRollLine("(1-100) 42: Bob", swapped, swappedOrder)
assertTrue(name == "Bob" and roll == 42 and low == 1 and high == 100, "positional arguments should map back to name, roll and range")
assertEqual(PvPRoll.BuildRollPattern("%s rolls"), nil, "a format without four values is no roll line")
name, roll = PvPRoll.ParseRollLine("Koji Kurosawa rolls 61 (1-100)")
assertEqual(name, "Koji Kurosawa", "Forever roll lines carry the surname")
assertEqual(PvPRoll.ParseRollLine("Bob has come online."), nil, "other system lines are no roll")
assertEqual(PvPRoll.ParseRollLine(SECRET), nil, "a hidden line is no roll")
assertEqual(PvPRoll.ParseRollLine("Bob rolls 57 (1-100) extra"), nil, "the whole line must be a roll")

-- =========================
-- Names
-- =========================
assertEqual(PvPRoll.NameKey("Bob"), "bob", "plain name")
assertEqual(PvPRoll.NameKey("Bob-Stormrage"), "bob", "another realm's player")
assertEqual(PvPRoll.NameKey("Koji Kurosawa"), "koji", "Forever first name and surname")
assertEqual(PvPRoll.NameKey("|cff3fc7ebBob|r"), "bob", "a colored name")
assertEqual(PvPRoll.NameKey(SECRET), nil, "a hidden name")
assertEqual(PvPRoll.NameKey(""), nil, "an empty name")

-- =========================
-- You start a roll at an enemy and lose it
-- =========================
units.target = { name = "Hogger", npc = true, hostile = true }
slash("")
assertEqual(#sent, 1, "starting a roll should tell the party")
assertEqual(sent[1].message, "SHogger", "the start message names the enemy")
assertEqual(sent[1].channel, "PARTY", "the start goes to the party")
assertEqual(#rolled, 1, "/cproll should roll")
assertTrue(rolled[1][1] == 1 and rolled[1][2] == 100, "/cproll rolls 1-100")
local frame = assert(_G.CarpenterPvPRollFrame, "the roll frame should exist")
assertTrue(frame:IsShown(), "the roll should show")
-- StoryMode's quest complete banner: a 400 by 60 box 24 below the top.
assertTrue(frame.point[1] == "TOP" and frame.point[2] == UIParent and frame.point[3] == "TOP", "the roll sits at the top of the screen")
assertEqual(frame.point[5], -24, "24 below the top edge, like StoryMode's banners")
assertEqual(frame.scale, nil, "the banner text keeps StoryMode's size")
assertTrue(frame.width == 400 and frame.height == 60, "the banner box is StoryMode's")
local session = PvPRoll.GetSession()
assertEqual(#session.players, 2, "everyone in the party rolls")
assertEqual(session.target, "Hogger", "the roll is at the enemy")

slash("")
assertEqual(#rolled, 1, "pressing again before the game answers must not roll twice")
assertEqual(#sent, 1, "pressing again must not start another roll")

local function findText(text)
    for _, widget in ipairs(created) do
        if widget.objectType == "FontString" and widget.text == text and widget.shown then return widget end
    end
end
local enemy = assert(findText("HOGGER"), "the enemy's name is the small line on top, in capitals")
assertEqual(enemy.template, "GameFontNormalSmall", "the enemy line is StoryMode's small font")
assertTrue(enemy.color[1] == 0.95 and enemy.color[2] == 0.85 and enemy.color[3] == 0.55, "the enemy line is StoryMode's gold")
assertTrue(enemy.shadow[1] == 1 and enemy.shadow[2] == -1, "the enemy line has StoryMode's shadow")
assertTrue(enemy.point[1] == "BOTTOM" and enemy.point[2] == frame and enemy.point[3] == "CENTER" and enemy.point[5] == 2, "the enemy line sits over the banner's middle")
local status = assert(findText(L.PVP_ROLL_PROMPT), "the prompt is the big line while rolling")
assertEqual(status.template, "QuestFont_Huge", "the big line is StoryMode's QuestFont_Huge")
assertTrue(status.color[1] == 1 and status.color[2] == 1 and status.color[3] == 1, "the big line is white, as in StoryMode")
assertTrue(status.shadow[1] == 1 and status.shadow[2] == -1, "the big line has StoryMode's shadow")
assertTrue(status.point[1] == "TOP" and status.point[2] == frame and status.point[3] == "CENTER" and status.point[5] == -2, "the big line hangs under the banner's middle")

-- Toast widgets per player, found by the name on them; the newest one, as
-- the fallback checks load the module again.
local function toastFor(playerName)
    for index = #created, 1, -1 do
        local widget = created[index]
        if widget.objectType == "Frame" and widget.Name and widget.Name.text
            and widget.Name.text:find(playerName, 1, true) and widget.shown then
            return widget
        end
    end
end
local rafaToast, bobToast = assert(toastFor("Rafa"), "your toast"), assert(toastFor("Bob"), "Bob's toast")
assertEqual(rafaToast.parent.scale, 0.75, "the toasts are drawn smaller than Blizzard's")
assertTrue(rafaToast.parent.parent == frame and rafaToast.parent.point[3] == "BOTTOM", "the toasts hang under the banner")
assertContains(bobToast.Name.text, "|cff3fc7eb", "Bob's name is in his class color")
assertEqual(bobToast.Icon.texture, "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES", "Bob's toast shows his class")
assertTrue(bobToast.Waiting.shown and not bobToast.RollButton.shown, "Bob's dice wait for him")

system("Rafa rolls 40 (1-100)")
local rafa = session.byKey.rafa
assertEqual(rafa.roll, 40, "your roll should count")
assertTrue(rafaToast.Anim.shown and rafaToast.Anim.Animation.playing, "your dice should tumble")
assertEqual(rafaToast.Anim.RollNumber.text, "40", "your dice land on your roll")
assertEqual(sounds[#sounds], SOUNDKIT.UI_NEED_ROLL_NEUTRAL, "a roll that settles nothing sounds neutral")
assertTrue(not rafaToast.RollButton.shown, "your dice button goes once you rolled")
assertTrue(rafaToast.Timer.shown and rafaToast.Timer.value == 20, "your bar keeps counting while Bob still has to roll")
advance(2)
frame.scripts.OnUpdate(frame, 0)
assertEqual(rafaToast.Timer.value, 18, "the bars count down")
assertEqual(bobToast.Timer.value, 18, "Bob's bar counts down too")

system("Bob rolls 72 (1-100)")
assertTrue(rafaToast.Timer.shown and rafaToast.Timer.value == 0, "the bars empty once everyone has rolled")
assertTrue(bobToast.Timer.shown and bobToast.Timer.value == 0, "Bob's bar empties too")
assertEqual(sounds[#sounds], SOUNDKIT.UI_NEED_ROLL_NEGATIVE, "the roll that beats you sounds like a lost need roll")
assertTrue(not session.finished, "the winner shows only once the last dice land")
advance(3.3)
assertTrue(not session.finished, "the dice are still tumbling")
advance(0.2)
assertTrue(session.finished, "the roll should finish when the dice land")
assertEqual(session.winner, session.byKey.bob, "Bob rolled higher")
assertTrue(findText("|cff3fc7ebBob|r takes the fight!"), "the winner is named in their class color")
assertEqual(#printed, 1, "the result is printed in chat once")
assertEqual(printed[1].text, "Hogger: |cff3fc7ebBob|r takes the fight!", "chat names the enemy and the winner")
assertTrue(printed[1].r == 1 and printed[1].g == 1 and printed[1].b == 1, "the chat line is white")
assertEqual(bobToast.Anim.RollNumber.color[2], 1, "the winning number is green")
assertEqual(rafaToast.Anim.RollNumber.color[1], 1, "the losing number is red")
assertEqual(rafaToast.Anim.RollNumber.color[2], 0.1, "the losing number is red")
advance(6)
H.assertTrue(frame.scripts.OnUpdate, "the frame fades on update")
advance(1)
frame.scripts.OnUpdate(frame, 1)
assertTrue(not frame:IsShown(), "the result should fade away")

-- =========================
-- Bob starts one; his roll line comes first, then a tie
-- =========================
system("Bob-Stormrage rolls 90 (1-100)")
addon("SHogger", "Bob-Stormrage")
session = PvPRoll.GetSession()
assertTrue(not session.finished and frame:IsShown(), "a party member's roll should show here too")
assertEqual(session.target, "Hogger", "their enemy is named")
assertEqual(session.byKey.bob.roll, 90, "a roll line just before the start message counts")
assertEqual(#sent, 1, "joining someone else's roll sends nothing")
rafaToast = toastFor("Rafa")
assertTrue(rafaToast.RollButton.shown, "you have to roll: your dice are a button")
rafaToast.RollButton.scripts.OnClick(rafaToast.RollButton)
assertEqual(#rolled, 2, "clicking your dice rolls")
system("Rafa rolls 90 (1-100)")
advance(3.4)
assertTrue(session.tie and not session.finished, "a tie should roll again")
assertTrue(findText(L.PVP_ROLL_TIE), "the tie is announced")
assertEqual(#printed, 1, "a tie isn't printed in chat")
assertEqual(session.byKey.rafa.roll, nil, "the tied rolls start over")
assertTrue(rafaToast.RollButton.shown and not rafaToast.Anim.shown, "your dice are back for the second roll")
slash("")
assertEqual(#rolled, 3, "you can roll again after a tie")
system("Bob rolls 10 (1-100)")
system("Rafa rolls 50 (1-100)")
assertEqual(sounds[#sounds], SOUNDKIT.UI_NEED_ROLL_POSITIVE, "the roll that wins it for you sounds like a won need roll")
advance(3.4)
assertEqual(session.winner, session.byKey.rafa, "you won the second roll")
assertTrue(findText(L.PVP_ROLL_YOU_WIN), "you take the fight")
assertEqual(printed[#printed].text, "Hogger: You take the fight!", "chat says you take the fight")
advance(8)

-- =========================
-- Nobody answers: time runs out
-- =========================
units.target = nil
slash("")
assertEqual(sent[#sent].message, "S", "a roll at nobody names no enemy")
session = PvPRoll.GetSession()
assertTrue(findText("NEXT FIGHT"), "without an enemy the small line says Next Fight")
system("Rafa rolls 33 (1-100)")
system("Bob rolls 99 (1-50)")
assertEqual(session.byKey.bob.roll, nil, "only 1-100 rolls count")
system(SECRET)
advance(19)
assertTrue(not session.finished, "Bob still has time")
advance(1.1)
assertTrue(session.finished, "the roll ends when time runs out")
assertTrue(session.byKey.bob.passed, "Bob passed")
assertTrue(toastFor("Bob").Pass.shown, "Bob's toast says Pass")
assertEqual(session.winner, session.byKey.rafa, "the only roll wins")
assertEqual(printed[#printed].text, "You take the fight!", "without an enemy chat only names the winner")
advance(8)

-- =========================
-- Messages that start nothing
-- =========================
local before = PvPRoll.GetSession()
addon("SHogger", "Stranger")
addon("SHogger", "Rafa")
addon(SECRET, "Bob")
fire("CHAT_MSG_ADDON", "OtherAddon", "SHogger", "PARTY", "Bob")
assertEqual(PvPRoll.GetSession(), before, "only party members' Carpenter rolls start one here")

-- =========================
-- A party member leaves mid-roll
-- =========================
units.target = { name = "Hogger", npc = true, hostile = true }
slash("")
session = PvPRoll.GetSession()
system("Rafa rolls 20 (1-100)")
units.party1 = nil
fire("GROUP_ROSTER_UPDATE")
assertTrue(session.byKey.bob.passed, "a member who left doesn't hold up the roll")
advance(3.4)
assertEqual(session.winner, session.byKey.rafa, "the roll ends without them")
advance(8)

-- =========================
-- Alone
-- =========================
inGroup = false
local sentBefore = #sent
slash("")
assertEqual(#sent, sentBefore, "alone there's nobody to tell")
session = PvPRoll.GetSession()
assertEqual(#session.players, 1, "alone you roll by yourself")
system("Rafa rolls 5 (1-100)")
advance(3.4)
assertEqual(session.winner, session.byKey.rafa, "alone you take the fight")
advance(8)
inGroup = true

-- =========================
-- WoW Forever names
-- =========================
Carpenter.Client = { isForever = true }
units.party1 = { name = "Koji", second = "Kurosawa", class = "MAGE" }
units.target = { name = "Ash", second = "Bloodfang", class = "ROGUE", hostile = true }
assertEqual(PvPRoll.EnemyTargetName(), "Ash Bloodfang", "Forever enemy players keep their surname")
Carpenter.IsEnabled = function(_, key) return key == "hideSurnamesEnabled" end
assertEqual(PvPRoll.EnemyTargetName(), "Ash", "Hide Surnames drops the enemy's surname")
Carpenter.IsEnabled = function() return false end
units.target.hostile = false
assertEqual(PvPRoll.EnemyTargetName(), nil, "a target you can't attack is no enemy")
units.target.hostile = true
slash("")
session = PvPRoll.GetSession()
assertTrue(session.byKey.koji, "Koji is in the roll")
system("Koji Kurosawa rolls 61 (1-100)")
assertEqual(session.byKey.koji.roll, 61, "a Forever roll line finds its party member")
system("Rafa rolls 60 (1-100)")
advance(3.4)
assertEqual(session.winner, session.byKey.koji, "Koji takes the fight")

-- =========================
-- Capitals in every language
-- =========================
assertEqual(PvPRoll.Upper("Gleichstand. Noch mal würfeln!"), "GLEICHSTAND. NOCH MAL WÜRFELN!", "German umlauts become capitals")
assertEqual(PvPRoll.Upper("Égalité. Relancez !"), "ÉGALITÉ. RELANCEZ !", "French accents become capitals")
assertEqual(PvPRoll.Upper("Ничья. Бросайте ещё раз!"), "НИЧЬЯ. БРОСАЙТЕ ЕЩЁ РАЗ!", "Cyrillic becomes capitals")
assertEqual(PvPRoll.Upper("平局，再掷一次！"), "平局，再掷一次！", "Chinese stays as it is")
assertEqual(PvPRoll.Upper("2 ÷ 2"), "2 ÷ 2", "÷ is no letter")

-- =========================
-- Wiring
-- =========================
for _, toc in ipairs({ "Carpenter.toc", "Carpenter_Camelot.toc", "Carpenter_TBC.toc", "Carpenter_Vanilla.toc" }) do
    local source = read(toc)
    local rp = source:find("Modules\\RPMacros.lua", 1, true)
    local pvp = source:find("Modules\\PvPRoll.lua", 1, true)
    local config = source:find("Settings\\Config.lua", 1, true)
    assertTrue(rp and pvp and config and rp < pvp and pvp < config, toc .. " should load PvP Roll after RP macros and before the settings")
end
local config = read("Settings/Config.lua")
assertContains(config, "title = L.SECTION_PVP", "PvP section on the hidden page")
assertContains(config, "macros = PvPRoll.Macros", "PvP section lists the Roll macro")
assertContains(config, 'image = GetSettingsImage(nil, "pvproll.png")', "the Roll sidebar shows its Forever preview")
assertContains(config, "ShowRPMacroSidebar(macro, section.description, section.image)", "macro rows pass their section's preview")
assertContains(config, "SetRPMacroInstalled(macro, checked, section.description, section.image)", "the preview stays after checking the row")
assert(config:find("SECTION_RP_MACROS", 1, true) < config:find("SECTION_PVP", 1, true), "PvP comes after RP Macros")
-- /cproll test is the author's own; the settings text doesn't mention it.
for _, path in ipairs({ "Settings/Config.lua", "Localization/enUS.lua", "Localization/deDE.lua", "Localization/esES.lua",
    "Localization/esMX.lua", "Localization/frFR.lua", "Localization/itIT.lua", "Localization/koKR.lua",
    "Localization/ptBR.lua", "Localization/ruRU.lua", "Localization/zhCN.lua", "Localization/zhTW.lua" }) do
    assertTrue(not read(path):find("/cproll test", 1, true), path .. " should not mention /cproll test")
end

-- =========================
-- /cproll test: a sparring partner instead of the party
-- =========================
advance(8)
local realRandom = math.random
local nextRolls = {}
math.random = function(low)
    if low then return table.remove(nextRolls, 1) or low end
    return 0.5
end
local sentCount, rolledCount = #sent, #rolled
nextRolls = { 30 }
slash("test")
session = PvPRoll.GetSession()
local partner = session.players[2]
assertTrue(session.test, "/cproll test starts a test roll")
assertEqual(#session.players, 2, "the test is you and a sparring partner")
assertEqual(partner.name, L.PVP_ROLL_TEST_PARTNER, "the partner has a name")
assertEqual(session.byKey.koji, nil, "the party isn't in the test")
assertEqual(#sent, sentCount, "a test tells nobody")
assertEqual(#rolled, rolledCount + 1, "your test roll is a real /roll")
assertEqual(session.target, "Ash Bloodfang", "the test rolls at your enemy too")
assertTrue(toastFor(L.PVP_ROLL_TEST_PARTNER), "the partner gets a toast")
system("Rafa rolls 60 (1-100)")
system("Koji Kurosawa rolls 99 (1-100)")
fire("GROUP_ROSTER_UPDATE")
assertTrue(not partner.passed, "the partner isn't in the party but still gets to roll")
advance(2)
assertEqual(partner.roll, nil, "the partner takes a moment")
advance(0.3)
assertEqual(partner.roll, 30, "the partner rolls")
advance(3.4)
assertEqual(session.winner, session.byKey.rafa, "you beat the partner")

-- "tie" matches your first roll, so the re-roll shows.
advance(8)
nextRolls = { 80 }
slash("test tie")
session = PvPRoll.GetSession()
partner = session.players[2]
advance(2.3)
assertEqual(partner.roll, nil, "a tying partner waits for your roll")
system("Rafa rolls 45 (1-100)")
advance(0.5)
assertEqual(partner.roll, 45, "the partner matches your roll")
advance(3.4)
assertTrue(session.tie and not session.finished, "the test tie rolls again")
slash("")
system("Rafa rolls 10 (1-100)")
advance(2.3)
assertEqual(partner.roll, 80, "the partner rolls again after the tie")
advance(3.4)
assertEqual(session.winner, partner, "the partner wins the second roll")

-- "pass" never rolls, so the time runs out.
advance(8)
slash("test pass")
session = PvPRoll.GetSession()
partner = session.players[2]
system("Rafa rolls 12 (1-100)")
advance(20.1)
assertTrue(partner.passed, "a passing partner never rolls")
assertEqual(session.winner, session.byKey.rafa, "you win when the partner passes")

-- Testing again starts over; a party member's real roll replaces a test.
advance(8)
slash("test")
local testSession = PvPRoll.GetSession()
slash("test")
assertTrue(PvPRoll.GetSession() ~= testSession, "testing again starts over")
testSession = PvPRoll.GetSession()
addon("SAsh", "Koji Kurosawa")
session = PvPRoll.GetSession()
assertTrue(session ~= testSession and not session.test, "a party member's roll replaces the test")
assertTrue(session.byKey.koji, "the real roll has the party")
advance(3.1)
local rolledBefore = #rolled
slash("test")
assertEqual(PvPRoll.GetSession(), session, "/cproll test doesn't replace a real roll")
assertEqual(#rolled, rolledBefore + 1, "it rolls into the real one instead")
advance(25)
math.random = realRandom

-- =========================
-- Classic: no need-roll atlases, so the loot die spins
-- =========================
local function loadFresh()
    local fresh = { Private = {} }
    H.load("Core/Unit.lua", fresh)
    H.load("Modules/PvPRoll.lua", fresh)
    return fresh.Private.PvPRoll
end
advance(8)
for atlas in pairs(ATLASES) do ATLASES[atlas] = nil end
SOUNDKIT = { UI_BONUS_LOOT_ROLL_START = 4 }
Carpenter.Client = { isClassic = true }
units.party1 = nil
inGroup = false
local classic = loadFresh()
classic.Roll()
session = classic.GetSession()
assertEqual(classic.View.RevealSeconds(), 1.4, "the spinning die lands sooner")
system("Rafa rolls 77 (1-100)")
local spinToast = assert(toastFor("Rafa"), "Classic still shows the toast")
local kinds = {}
for _, animation in ipairs(spinToast.Anim.Animation.animations) do kinds[animation.kind] = true end
assertTrue(kinds.Rotation and not kinds.FlipBook, "Classic spins the loot die instead of the flipbook")
assertEqual(spinToast.Icon.texture, "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES", "Classic shows the same class icons")
assertEqual(sounds[#sounds], 4, "Classic plays the bonus roll sound")
advance(1.4)
assertEqual(session.winner, session.byKey.rafa, "the Classic roll finishes when the die lands")

-- A client without an animation type the dice use: the number shows at once.
advance(8)
local createAnimation = widgetMethods.CreateAnimation
widgetMethods.CreateAnimation = function(self, kind)
    if kind == "Rotation" then error("unknown animation type") end
    return createAnimation(self, kind)
end
local bare = loadFresh()
bare.Roll()
session = bare.GetSession()
system("Rafa rolls 12 (1-100)")
assertEqual(bare.View.RevealSeconds(), 0, "without the animation the number shows right away")
local bareToast = toastFor("Rafa")
assertEqual(bareToast.Anim.RollNumber.alpha, 1, "the number is visible without the animation")
advance(0)
assertEqual(session.winner, session.byKey.rafa, "the roll still finishes")
widgetMethods.CreateAnimation = createAnimation

print("pvp roll fixtures: passed")
