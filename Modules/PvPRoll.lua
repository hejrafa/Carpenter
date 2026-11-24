--[[ Carpenter - PvP Roll ]]
-- The PvP Roll macro on the hidden settings page: /crack your knuckles, then
-- /cproll rolls 1-100 for who takes on your enemy. The roll shows at the top
-- of the screen the way the game shows a group loot roll: a loot toast for
-- each party member, whose dice tumble and land on their number. Above them,
-- the enemy's name over how the roll stands look like StoryMode's quest
-- complete banner.
--
-- Party members who run Carpenter see the same toasts and have to roll too,
-- with the dice on their toast or their own macro. Once everyone has rolled
-- (or the time is up), the highest roll takes the fight; a tie rolls again.
--
-- The rolls themselves are the game's /roll lines, so a party member without
-- Carpenter counts when they type /roll. Carpenter only tells the party that
-- a roll started and at whom, since the game's roll line doesn't say.
--
-- /cproll test tries it alone, against a made-up sparring partner.
--
-- The dice are Blizzard's own need-roll animation (GroupLootFrame's
-- NeedRollAnim), rebuilt here from the same atlases and timings. Clients
-- without those atlases get a spinning die instead.
local _, ns = ...
ns.Private = ns.Private or {}
local L = (Carpenter and Carpenter.L) or (ns and ns.L) or {}
local Secret = Carpenter.Secret
local Unit = ns.Private.Unit or {}

local PvPRoll = ns.Private.PvPRoll or {}
ns.Private.PvPRoll = PvPRoll

local PREFIX = "CarpenterRoll"
-- "S<enemy name>": a roll started, at that enemy (or at nobody).
local START = "S"
local ROLL_MIN, ROLL_MAX = 1, 100
local MAX_PLAYERS = 5
local ROLL_SECONDS = 20
local RESULT_SECONDS = 6
local FADE_SECONDS = 0.5
-- A roll line can arrive before the message saying the roll started.
local EARLY_ROLL_SECONDS = 5
-- A roll that got no line back from the game may be tried again after this.
local RETRY_ROLL_SECONDS = 3
-- /cproll test: the sparring partner rolls this long after the roll starts.
local TEST_ROLL_SECONDS, TEST_ROLL_SPREAD = 1.5, 1.5
-- No name the game writes turns into this key.
local TEST_KEY = "\001test"

-- Icons are file IDs, so they don't depend on the client's icon-name lookup.
PvPRoll.Macros = {
    {
        name = "PvP Roll",
        label = L.PVP_ROLL_NAME or "Roll",
        icon = 237285, -- INV_Misc_Dice_02
        body = "/crack\n/cproll",
    },
}

local SURNAME_SEPARATOR = (Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "

local function Now()
    return GetTime and GetTime() or 0
end

local function After(delay, callback)
    if Carpenter and Carpenter.After then
        Carpenter:After(delay, callback)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    end
end

-- =========================
-- The game's roll line
-- =========================
local function EscapeLiteral(text)
    text = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return (text:gsub("\001", ".-"))
end

-- RANDOM_ROLL_RESULT as a pattern, plus the order its four values come in:
-- "%s rolls %d (%d-%d)" in English, "%1$s würfelt. Ergebnis: %2$d (%3$d-%4$d)"
-- in German. Korean picks a particle after the number with "|1이;가;".
function PvPRoll.BuildRollPattern(format)
    if type(format) ~= "string" or format == "" then return nil end
    format = format:gsub("|1[^;]*;[^;]*;", "\001")
    local parts, order, nextArg, position = { "^" }, {}, 1, 1
    while position <= #format do
        local first, last, argIndex, kind = format:find("%%(%d*)%$?([sd])", position)
        if not first then
            parts[#parts + 1] = EscapeLiteral(format:sub(position))
            break
        end
        parts[#parts + 1] = EscapeLiteral(format:sub(position, first - 1))
        parts[#parts + 1] = kind == "s" and "(.-)" or "(%d+)"
        local index = tonumber(argIndex)
        if not index then
            index = nextArg
            nextArg = nextArg + 1
        end
        order[#order + 1] = index
        position = last + 1
    end
    if #order ~= 4 then return nil end
    parts[#parts + 1] = "$"
    return table.concat(parts), order
end

local rollPattern, rollOrder

-- Name, roll, low and high from a /roll line, or nil for any other line.
function PvPRoll.ParseRollLine(text, pattern, order)
    text = Secret.ReadableString(text)
    if not text then return nil end
    if not pattern then
        if not rollPattern then
            rollPattern, rollOrder = PvPRoll.BuildRollPattern(_G.RANDOM_ROLL_RESULT)
            if not rollPattern then
                rollPattern, rollOrder = PvPRoll.BuildRollPattern("%s rolls %d (%d-%d)")
            end
        end
        pattern, order = rollPattern, rollOrder
    end
    local captures = { text:match(pattern) }
    if #captures ~= #order then return nil end
    local values = {}
    for capture, index in ipairs(order) do
        values[index] = captures[capture]
    end
    local roll, low, high = tonumber(values[2]), tonumber(values[3]), tonumber(values[4])
    if type(values[1]) ~= "string" or values[1] == "" or not (roll and low and high) then return nil end
    return values[1], roll, low, high
end

-- =========================
-- Who's who
-- =========================
-- One key per player, whichever way the game writes the name: "Bob",
-- "Bob-Stormrage" (another realm) or, on WoW Forever, "Koji Kurosawa".
function PvPRoll.NameKey(name)
    name = Secret.ReadableString(name)
    if not name then return nil end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local first = name:match("^%s*([^%s%-]+)")
    if first and SURNAME_SEPARATOR ~= "" and SURNAME_SEPARATOR ~= " " then
        local cut = first:find(SURNAME_SEPARATOR, 1, true)
        if cut then first = first:sub(1, cut - 1) end
    end
    if not first or first == "" then return nil end
    return first:lower()
end

local function UnitNames(unit)
    if not UnitName then return nil end
    local ok, name, second = pcall(UnitName, unit)
    if not ok then return nil end
    return Secret.ReadableString(name), Secret.ReadableString(second)
end

local function SelfKey()
    return PvPRoll.NameKey((UnitNames("player")))
end

local function InGroup()
    return IsInGroup and IsInGroup() == true
end

-- You and the rest of your party (your raid group's party in a raid), in
-- party order; members who are offline or whose name is hidden are left out.
local function GroupMembers()
    local units = { "player" }
    if InGroup() then
        for index = 1, MAX_PLAYERS - 1 do
            units[#units + 1] = "party" .. index
        end
    end
    local members, seen = {}, {}
    for _, unit in ipairs(units) do
        local isSelf = unit == "player"
        if isSelf or Unit.Exists(unit) then
            local name = UnitNames(unit)
            local key = PvPRoll.NameKey(name)
            local connected = isSelf or Secret.ReadableBool(UnitIsConnected, unit) ~= false
            if key and connected and not seen[key] then
                seen[key] = true
                local _, classToken = Unit.Class(unit)
                members[#members + 1] = { key = key, name = name, classToken = classToken, isSelf = isSelf }
            end
        end
    end
    return members
end

local function IsGroupMember(key)
    for _, member in ipairs(GroupMembers()) do
        if member.key == key then return true end
    end
    return false
end

-- The enemy you're targeting, with the surname on WoW Forever unless Hide
-- Surnames is on; nil when you target nobody you can attack.
function PvPRoll.EnemyTargetName()
    if not Unit.Exists("target") then return nil end
    if Secret.ReadableBool(UnitCanAttack, "player", "target") ~= true then return nil end
    local name, second = UnitNames("target")
    if not name then return nil end
    local client = Carpenter and Carpenter.Client or {}
    local hideSurnames = Carpenter and Carpenter.IsEnabled and Carpenter:IsEnabled("hideSurnamesEnabled")
    if second and client.isForever and not hideSurnames and Unit.IsPlayer("target") then
        return name .. SURNAME_SEPARATOR .. second
    end
    return name
end

-- =========================
-- Talking to the party
-- =========================
local function GroupChannel()
    if not InGroup() then return nil end
    if LE_PARTY_CATEGORY_HOME and IsInGroup(LE_PARTY_CATEGORY_HOME) then return "PARTY" end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    return "PARTY"
end

local function Send(message)
    local channel = GroupChannel()
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
    if not channel or type(send) ~= "function" then return false end
    return pcall(send, PREFIX, message, channel) == true
end

-- =========================
-- Toasts
-- =========================
local View = {}

local LOOT_TOAST = "Interface\\LootFrame\\LootToast"
local DICE_UP = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local DICE_HIGHLIGHT = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight"
local DICE_DOWN = "Interface\\Buttons\\UI-GroupLoot-Dice-Down"
local TIMER_BAR = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local UNKNOWN_ICON = 134400 -- INV_Misc_QuestionMark
local TOAST_WIDTH, TOAST_HEIGHT = 277, 67
-- Blizzard spaces its loot toasts 100 apart; the dice's light needs room.
local TOAST_SPACING = 84
-- The enemy and how the roll stands are StoryMode's quest banner: a 400 by 60
-- box 24 below the top of the screen. The toasts hang under it, smaller than
-- Blizzard's.
local BANNER_WIDTH, BANNER_HEIGHT, BANNER_TOP = 400, 60, -24
local TOAST_SCALE = 0.75
local TOAST_GAP = -6
-- Where the dice sit on the toast, from its top left: the need button's
-- spot, and the animation 5 to its right like Blizzard's.
local DICE_X, DICE_Y = 218, -33
local ANIM_X, ANIM_Y = 223, -23
-- The number lands down and right of the animation's middle.
local NUMBER_X, NUMBER_Y = 13, -13

local WHITE = { 1, 1, 1 }
local GREEN = { 0.1, 1, 0.1 }
local RED = { 1, 0.1, 0.1 }
-- StoryMode's banner line color.
local BANNER_GOLD = { 0.95, 0.85, 0.55 }

local container, toastArea, titleText, statusText
local toasts = {}
local fadeStartedAt
local diceAnimAvailable
-- Set when this client lacks an animation type the dice use.
local animationMissing = false

local function HasAtlas(atlas)
    local getInfo = C_Texture and C_Texture.GetAtlasInfo
    if type(getInfo) ~= "function" then return false end
    local ok, info = pcall(getInfo, atlas)
    return ok and type(info) == "table"
end

-- Blizzard's need-roll dice need Mainline's atlases (Retail, WoW Forever).
local function HasDiceAnim()
    if diceAnimAvailable == nil then
        diceAnimAvailable = HasAtlas("lootroll-animdice") and HasAtlas("lootroll-animdiceglow")
            and HasAtlas("lootroll-animreveal-a") and HasAtlas("lootroll-animreveal-b")
            and HasAtlas("lootroll-animrevealfade")
    end
    return diceAnimAvailable
end

-- Seconds from a roll until its number shows.
function View.RevealSeconds()
    if animationMissing then return 0 end
    return HasDiceAnim() and 3.4 or 1.4
end

local function PlaySoundKit(name)
    local id = SOUNDKIT and SOUNDKIT[name]
    if id and PlaySound then pcall(PlaySound, id) end
end

local function NumberFont()
    return _G.Game32Font and "Game32Font" or "GameFontNormalHuge"
end

local function AddAnimation(group, kind, target, duration, delay)
    local animation = group:CreateAnimation(kind)
    animation:SetTarget(target)
    animation:SetDuration(duration)
    animation:SetOrder(1)
    if delay and delay > 0 then animation:SetStartDelay(delay) end
    return animation
end

local function AddAlpha(group, target, duration, delay, from, to)
    local animation = AddAnimation(group, "Alpha", target, duration, delay)
    animation:SetFromAlpha(from)
    animation:SetToAlpha(to)
end

local function AddFlipBook(group, target, duration, delay, rows, columns, frames)
    local animation = AddAnimation(group, "FlipBook", target, duration, delay)
    animation:SetFlipBookRows(rows)
    animation:SetFlipBookColumns(columns)
    animation:SetFlipBookFrames(frames)
    animation:SetFlipBookFrameWidth(0)
    animation:SetFlipBookFrameHeight(0)
end

-- GroupLootFrameBaseTemplate's NeedRollAnim, piece for piece.
local function BuildDiceAnim(anim)
    local function Layer(atlas, subLevel, width, height, x, y)
        local texture = anim:CreateTexture(nil, "ARTWORK", nil, subLevel)
        texture:SetAtlas(atlas)
        texture:SetSize(width, height)
        texture:SetPoint("CENTER", x or 0, y or 0)
        texture:SetAlpha(0)
        anim.effects[#anim.effects + 1] = texture
        return texture
    end
    local dice = Layer("lootroll-animdice", 0, 58, 74)
    local revealA = Layer("lootroll-animreveal-a", 0, 128, 114, 19.5, -7)
    local revealFade = Layer("lootroll-animrevealfade", 0, 70, 220, 12.5, 30)
    local glow = Layer("lootroll-animdiceglow", 1, 70, 76, NUMBER_X, NUMBER_Y)
    local revealB1 = Layer("lootroll-animreveal-b", 2, 108, 150, 10, 15)
    local revealB2 = Layer("lootroll-animreveal-b", 2, 108, 150, 23, 15)
    local number = anim.RollNumber

    local group = anim.Animation
    AddFlipBook(group, dice, 1.47, 0, 9, 5, 44)
    AddAlpha(group, dice, 1.47, 0, 1, 1)
    AddAlpha(group, dice, 0, 1.48, 0, 0)
    AddFlipBook(group, glow, 1.67, 1.48, 10, 5, 50)
    AddAlpha(group, glow, 1.47, 0, 0, 0)
    AddAlpha(group, glow, 1.67, 1.48, 1, 1)
    local grow = AddAnimation(group, "Scale", glow, 0.27, 3.15)
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(1.3, 1.3)
    AddAlpha(group, glow, 0.27, 3.15, 1, 0)
    AddFlipBook(group, revealB1, 0.3, 3.15, 2, 5, 10)
    AddAlpha(group, revealB1, 3.14, 0, 0, 0)
    AddAlpha(group, revealB1, 0.3, 3.15, 1, 1)
    AddAlpha(group, revealB1, 0, 3.46, 0, 0)
    AddFlipBook(group, revealB2, 0.35, 3.2, 2, 5, 10)
    AddAlpha(group, revealB2, 3.19, 0, 0, 0)
    AddAlpha(group, revealB2, 0.35, 3.2, 1, 1)
    AddAlpha(group, revealB2, 0, 3.56, 0, 0)
    AddFlipBook(group, revealA, 0.4, 3.3, 2, 6, 12)
    AddAlpha(group, revealA, 3.29, 0, 0, 0)
    AddAlpha(group, revealA, 0.4, 3.3, 1, 1)
    AddFlipBook(group, revealFade, 0.7, 3.4, 3, 7, 21)
    AddAlpha(group, revealFade, 3.39, 0, 0, 0)
    AddAlpha(group, revealFade, 0.7, 3.4, 1, 1)
    AddAlpha(group, number, 3.39, 0, 0, 0)
    AddAlpha(group, number, 0.1, 3.4, 0, 1)
    AddAnimation(group, "Translation", number, 0, 0):SetOffset(0, 5)
    AddAnimation(group, "Translation", number, 0.6, 3.4):SetOffset(0, -5)
end

-- Without those atlases: the loot die spins, then the number shows.
local function BuildSpinAnim(anim)
    local dice = anim:CreateTexture(nil, "ARTWORK")
    dice:SetTexture(DICE_UP)
    dice:SetSize(32, 32)
    dice:SetPoint("CENTER", DICE_X - ANIM_X, DICE_Y - ANIM_Y)
    dice:SetAlpha(0)
    anim.effects[#anim.effects + 1] = dice

    local group = anim.Animation
    AddAlpha(group, dice, 1.2, 0, 1, 1)
    local spin = AddAnimation(group, "Rotation", dice, 1.2, 0)
    spin:SetDegrees(-720)
    AddAlpha(group, dice, 0.15, 1.2, 1, 0)
    AddAlpha(group, anim.RollNumber, 1.35, 0, 0, 0)
    AddAlpha(group, anim.RollNumber, 0.1, 1.35, 0, 1)
end

local function CreateRollAnim(toast)
    local anim = CreateFrame("Frame", nil, toast)
    anim:SetSize(128, 128)
    anim:SetPoint("CENTER", toast, "TOPLEFT", ANIM_X, ANIM_Y)
    anim:Hide()
    anim.effects = {}

    local number = anim:CreateFontString(nil, "ARTWORK", NumberFont())
    number:SetDrawLayer("ARTWORK", 1)
    number:SetPoint("CENTER", NUMBER_X, NUMBER_Y)
    number:SetAlpha(0)
    anim.RollNumber = number

    local group = anim:CreateAnimationGroup()
    group:SetToFinalAlpha(true)
    anim.Animation = group
    -- The effects' last frames would show their whole sheet once the
    -- flipbooks stop, so only the number stays.
    group:SetScript("OnFinished", function()
        for _, texture in ipairs(anim.effects) do texture:Hide() end
        number:SetAlpha(1)
    end)
    local built = pcall(HasDiceAnim() and BuildDiceAnim or BuildSpinAnim, anim)
    if not built then
        -- An animation type this client lacks: show the number at once.
        animationMissing = true
        group:Stop()
        anim.Animation = nil
    end
    return anim
end

-- The square class icons from character creation, which fit the loot
-- toast's square icon slot on every client.
local function SetClassIcon(texture, classToken)
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        texture:SetTexture(CLASS_ICONS)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return
    end
    texture:SetTexture(UNKNOWN_ICON)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function SetDiceTextures(button)
    if HasAtlas("lootroll-toast-icon-need-up") then
        button:SetNormalAtlas("lootroll-toast-icon-need-up")
        button:SetHighlightAtlas("lootroll-toast-icon-need-highlight", "ADD")
        button:SetPushedAtlas("lootroll-toast-icon-need-down")
    else
        button:SetNormalTexture(DICE_UP)
        button:SetHighlightTexture(DICE_HIGHLIGHT, "ADD")
        button:SetPushedTexture(DICE_DOWN)
    end
end

local function CreateToast()
    local toast = CreateFrame("Frame", nil, toastArea)
    toast:SetSize(TOAST_WIDTH, TOAST_HEIGHT)

    local background = toast:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(LOOT_TOAST)
    background:SetTexCoord(0.28222656, 0.55273438, 0.30859375, 0.57031250)
    background:SetAllPoints(toast)

    local border = toast:CreateTexture(nil, "BORDER")
    border:SetTexture(LOOT_TOAST)
    border:SetTexCoord(0.00097656, 0.28027344, 0.43750000, 0.73437500)
    border:SetSize(286, 76)
    border:SetPoint("CENTER", toast, "CENTER")

    toast.Icon = toast:CreateTexture(nil, "ARTWORK")
    toast.Icon:SetSize(34, 34)
    toast.Icon:SetPoint("TOPLEFT", toast, "TOPLEFT", 10, -11)
    if HasAtlas("loottoast-itemborder-white") then
        local iconBorder = toast:CreateTexture(nil, "OVERLAY")
        iconBorder:SetAtlas("loottoast-itemborder-white")
        iconBorder:SetSize(42, 42)
        iconBorder:SetPoint("CENTER", toast.Icon, "CENTER", 0, -2)
    end

    toast.Name = toast:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    toast.Name:SetSize(125, 30)
    toast.Name:SetPoint("TOPLEFT", toast, "TOPLEFT", 60, -15)
    toast.Name:SetJustifyH("LEFT")
    toast.Name:SetJustifyV("MIDDLE")

    local timer = CreateFrame("StatusBar", nil, toast)
    timer:SetSize(190, 8)
    timer:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 3, 2)
    timer:SetStatusBarTexture(TIMER_BAR)
    timer:SetStatusBarColor(1, 1, 0)
    timer:SetMinMaxValues(0, ROLL_SECONDS)
    local timerBackground = timer:CreateTexture(nil, "BACKGROUND")
    timerBackground:SetAllPoints(timer)
    timerBackground:SetColorTexture(0, 0, 0)
    toast.Timer = timer

    -- Your dice: click to roll.
    local button = CreateFrame("Button", nil, toast)
    button:SetSize(32, 32)
    button:SetPoint("CENTER", toast, "TOPLEFT", DICE_X, DICE_Y)
    SetDiceTextures(button)
    button:SetScript("OnClick", function() PvPRoll.Roll() end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(_G.ROLL or "Roll")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    toast.RollButton = button

    -- Someone else's dice while they haven't rolled.
    local waiting = toast:CreateTexture(nil, "ARTWORK")
    waiting:SetSize(32, 32)
    waiting:SetPoint("CENTER", toast, "TOPLEFT", DICE_X, DICE_Y)
    if HasAtlas("lootroll-toast-icon-need-up") then
        waiting:SetAtlas("lootroll-toast-icon-need-up")
    else
        waiting:SetTexture(DICE_UP)
    end
    waiting:SetDesaturated(true)
    waiting:SetAlpha(0.5)
    toast.Waiting = waiting

    toast.Pass = toast:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    toast.Pass:SetPoint("CENTER", toast, "TOPLEFT", ANIM_X + NUMBER_X, ANIM_Y + NUMBER_Y)
    toast.Pass:SetText(_G.PASS or "Pass")

    toast.Anim = CreateRollAnim(toast)
    return toast
end

-- Seconds left for the rolls still to come, or 0 once everyone has rolled.
local function TimeLeft(session)
    if session.finished or session.deciding then return 0 end
    return math.max(0, session.endsAt - Now())
end

local function OnUpdate()
    local session = PvPRoll.GetSession()
    if session and not session.finished and not session.deciding then
        local left = TimeLeft(session)
        for _, toast in ipairs(toasts) do
            if toast:IsShown() then toast.Timer:SetValue(left) end
        end
    end
    if fadeStartedAt then
        local progress = (Now() - fadeStartedAt) / FADE_SECONDS
        if progress >= 1 then
            fadeStartedAt = nil
            container:Hide()
        else
            container:SetAlpha(1 - progress)
        end
    end
end

local function SetColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end

local function EnsureContainer()
    if container then return container end
    container = CreateFrame("Frame", "CarpenterPvPRollFrame", UIParent)
    container:SetSize(BANNER_WIDTH, BANNER_HEIGHT)
    container:SetPoint("TOP", UIParent, "TOP", 0, BANNER_TOP)
    container:SetFrameStrata("DIALOG")
    container:Hide()

    -- StoryMode's quest complete banner, line for line: the enemy (or "Next
    -- Fight") small and uppercase in its gold, over how the roll stands in
    -- QuestFont_Huge, both shadowed.
    titleText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("BOTTOM", container, "CENTER", 0, 2)
    titleText:SetJustifyH("CENTER")
    SetColor(titleText, BANNER_GOLD)
    titleText:SetShadowOffset(1, -1)
    statusText = container:CreateFontString(nil, "OVERLAY", _G.QuestFont_Huge and "QuestFont_Huge" or "GameFontNormalHuge")
    statusText:SetPoint("TOP", container, "CENTER", 0, -2)
    statusText:SetJustifyH("CENTER")
    SetColor(statusText, WHITE)
    statusText:SetShadowOffset(1, -1)

    toastArea = CreateFrame("Frame", nil, container)
    toastArea:SetScale(TOAST_SCALE)
    toastArea:SetSize(TOAST_WIDTH, TOAST_SPACING)
    -- A scaled frame's offsets scale with it.
    toastArea:SetPoint("TOP", container, "BOTTOM", 0, TOAST_GAP / TOAST_SCALE)

    container:SetScript("OnUpdate", OnUpdate)
    return container
end

-- Uppercase like the small line of StoryMode's banner. string.upper only knows ASCII,
-- so accented Latin ("würfeln", "égalité") and Cyrillic letters are raised
-- here too.
function PvPRoll.Upper(text)
    text = text:upper()
    text = text:gsub("\195([\160-\190])", function(byte)
        if byte == "\183" then return nil end -- ÷
        return "\195" .. string.char(byte:byte() - 32)
    end)
    text = text:gsub("\208([\176-\191])", function(byte) return "\208" .. string.char(byte:byte() - 32) end)
    text = text:gsub("\209([\128-\143])", function(byte) return "\208" .. string.char(byte:byte() + 32) end)
    return (text:gsub("\209\145", "\208\129")) -- ё
end

local function PlayerName(player)
    local color = player.classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[player.classToken]
    if color and color.colorStr then
        return "|c" .. color.colorStr .. player.name .. "|r"
    end
    return player.name
end

-- How the roll stands: the prompt, a tie, or who takes the fight.
local function StatusText(session)
    if session.finished then
        local winner = session.winner
        if not winner then return L.PVP_ROLL_NOBODY or "Nobody rolled." end
        if winner.isSelf then return L.PVP_ROLL_YOU_WIN or "You take the fight!" end
        return (L.PVP_ROLL_WINNER or "%s takes the fight!"):format(PlayerName(winner))
    end
    if session.tie then return L.PVP_ROLL_TIE or "It's a tie. Roll again!" end
    return L.PVP_ROLL_PROMPT or "Highest roll takes the fight"
end

-- The result in your chat window, white like the banner's line, winner
-- first and in class color: "Bob takes the fight vs. Empowered Brute".
-- Nothing goes to the party.
function View.PrintResult(session)
    local chat = DEFAULT_CHAT_FRAME
    if not chat or not chat.AddMessage then return end
    local winner, text = session.winner, nil
    if winner and session.target and winner.isSelf then
        text = (L.PVP_ROLL_YOU_WIN_VS or "You take the fight vs. %s"):format(session.target)
    elseif winner and session.target then
        text = (L.PVP_ROLL_WINNER_VS or "%s takes the fight vs. %s"):format(PlayerName(winner), session.target)
    else
        text = StatusText(session)
    end
    chat:AddMessage(text, 1, 1, 1)
end

function View.Update(session)
    if not container or not session then return end
    titleText:SetText(PvPRoll.Upper(session.target or L.PVP_ROLL_NO_TARGET or "Next Fight"))
    statusText:SetText(StatusText(session))

    for index, toast in ipairs(toasts) do
        local player = session.players[index]
        if player then
            local waiting = not player.roll and not player.passed and not player.out
            toast.RollButton:SetShown(waiting and player.isSelf)
            toast.Waiting:SetShown(waiting and not player.isSelf)
            toast.Pass:SetShown(player.passed == true)
            -- Every toast counts down while anyone still has to roll, and
            -- empties once all rolls are in, as the game's loot roll does.
            toast.Timer:Show()
            toast.Timer:SetValue(TimeLeft(session))
            toast.Anim:SetShown(player.roll ~= nil)
            if player.roll then
                local color = WHITE
                if session.finished then
                    color = player == session.winner and GREEN or RED
                elseif player.out then
                    color = RED
                end
                SetColor(toast.Anim.RollNumber, color)
            end
        end
    end
end

function View.Show(session)
    EnsureContainer()
    for index, player in ipairs(session.players) do
        local toast = toasts[index] or CreateToast()
        toasts[index] = toast
        toast:ClearAllPoints()
        toast:SetPoint("TOP", toastArea, "TOP", 0, -(index - 1) * TOAST_SPACING)
        SetClassIcon(toast.Icon, player.classToken)
        toast.Name:SetText(PlayerName(player))
        View.ResetDice(toast)
        toast:Show()
    end
    for index = #session.players + 1, #toasts do
        toasts[index]:Hide()
    end
    toastArea:SetHeight(#session.players * TOAST_SPACING)
    fadeStartedAt = nil
    container:SetAlpha(1)
    container:Show()
    View.Update(session)
end

function View.ResetDice(toast)
    local anim = toast.Anim
    if anim.Animation then anim.Animation:Stop() end
    anim.RollNumber:SetText("")
    anim:Hide()
end

-- Back to waiting, for a player rolling again after a tie.
function View.ResetPlayer(player)
    local toast = toasts[player.index]
    if toast then View.ResetDice(toast) end
end

-- The dice for player's roll tumble; sound is the game's need-roll sound
-- for the outcome this roll settles ("POSITIVE", "NEGATIVE" or "NEUTRAL").
function View.PlayRoll(session, player, sound)
    local toast = toasts[player.index]
    if not toast or not container then return end
    local anim = toast.Anim
    anim.RollNumber:SetText(tostring(player.roll))
    for _, texture in ipairs(anim.effects) do texture:Show() end
    anim:Show()
    if anim.Animation then
        anim.RollNumber:SetAlpha(0)
        anim.Animation:Stop()
        anim.Animation:Play()
    else
        anim.RollNumber:SetAlpha(1)
    end
    if SOUNDKIT and SOUNDKIT.UI_NEED_ROLL_NEUTRAL then
        PlaySoundKit("UI_NEED_ROLL_" .. (sound or "NEUTRAL"))
    else
        PlaySoundKit("UI_BONUS_LOOT_ROLL_START")
    end
    View.Update(session)
end

function View.FadeOut()
    if container and container:IsShown() then fadeStartedAt = Now() end
end

PvPRoll.View = View

-- =========================
-- A roll for the next fight
-- =========================
local session
local recentRolls = {}
local rollSentAt = -math.huge

function PvPRoll.GetSession()
    return session
end

local function IsWaiting(player)
    return not player.roll and not player.out and not player.passed
end

local function CountWaiting(current)
    local count = 0
    for _, player in ipairs(current.players) do
        if IsWaiting(player) then count = count + 1 end
    end
    return count
end

-- The highest roll among those still in, and everyone who has it.
local function Leaders(current)
    local best, leaders = nil, {}
    for _, player in ipairs(current.players) do
        if player.roll and not player.out then
            if not best or player.roll > best then
                best, leaders = player.roll, { player }
            elseif player.roll == best then
                leaders[#leaders + 1] = player
            end
        end
    end
    return best, leaders
end

local function Finish(current, winner)
    current.finished = true
    current.winner = winner
    View.Update(current)
    View.PrintResult(current)
    After(RESULT_SECONDS, function()
        if session == current then View.FadeOut() end
    end)
end

local ScheduleTimeout, ScheduleTestRolls

local function Decide(current)
    current.deciding = nil
    local best, leaders = Leaders(current)
    if #leaders <= 1 then
        Finish(current, leaders[1])
        return
    end
    -- A tie: the tied players roll again; everyone else is out.
    for _, player in ipairs(current.players) do
        if player.roll and not player.out then
            if player.roll == best then
                player.roll, player.revealAt = nil, nil
                View.ResetPlayer(player)
            else
                player.out = true
            end
        end
    end
    current.round = current.round + 1
    current.tie = true
    current.endsAt = Now() + ROLL_SECONDS
    ScheduleTimeout(current)
    ScheduleTestRolls(current)
    View.Update(current)
end

-- Once nobody is left to roll, the result shows when the last dice land.
local function CheckRolls(current)
    if current.finished or current.deciding or CountWaiting(current) > 0 then
        View.Update(current)
        return
    end
    current.deciding = true
    local lastReveal = Now()
    for _, player in ipairs(current.players) do
        if player.revealAt and player.revealAt > lastReveal then lastReveal = player.revealAt end
    end
    local round = current.round
    After(lastReveal - Now(), function()
        if session ~= current or current.round ~= round or current.finished then return end
        Decide(current)
    end)
    View.Update(current)
end

ScheduleTimeout = function(current)
    local round = current.round
    After(ROLL_SECONDS, function()
        if session ~= current or current.round ~= round or current.finished or current.deciding then return end
        for _, player in ipairs(current.players) do
            if IsWaiting(player) then player.passed = true end
        end
        CheckRolls(current)
    end)
end

-- The sound for a roll: the last roll settles who fights, so it gets the
-- game's winning or losing sound for you.
local function RollSound(current)
    if CountWaiting(current) > 0 then return "NEUTRAL" end
    local _, leaders = Leaders(current)
    if #leaders ~= 1 then return "NEUTRAL" end
    local me = current.byKey[SelfKey() or ""]
    if not me or me.out or me.passed then return "NEUTRAL" end
    return leaders[1] == me and "POSITIVE" or "NEGATIVE"
end

local function ApplyRoll(current, player, roll)
    player.roll = roll
    player.revealAt = Now() + View.RevealSeconds()
    if player.isSelf then rollSentAt = -math.huge end
    View.PlayRoll(current, player, RollSound(current))
end

-- A /roll line: counts for a party member still waiting to roll. Before a
-- roll starts, it's kept for a moment in case the start message is late.
function PvPRoll.RecordRoll(key, roll)
    if not key or type(roll) ~= "number" then return end
    local current = session
    if not current or current.finished then
        recentRolls[key] = { roll = roll, at = Now() }
        return
    end
    local player = current.byKey[key]
    if not player or not IsWaiting(player) then return end
    ApplyRoll(current, player, roll)
    CheckRolls(current)
end

-- Starts the roll for the next fight, or names its enemy when one is
-- already running without a name. Returns the roll and whether it is new.
-- players replaces the party (the test roll); a real roll replaces a test.
function PvPRoll.Begin(target, players)
    local now = Now()
    if session and not session.finished then
        if session.test and not players then
            session.finished = true
        else
            if target and not session.target then
                session.target = target
                View.Update(session)
            end
            return session, false
        end
    end
    players = players or GroupMembers()
    if #players == 0 then return nil, false end
    local current = { target = target, players = players, byKey = {}, round = 1, endsAt = now + ROLL_SECONDS }
    for index, player in ipairs(players) do
        player.index = index
        current.byKey[player.key] = player
    end
    session = current
    View.Show(current)

    local early = recentRolls
    recentRolls = {}
    for _, player in ipairs(players) do
        local recent = early[player.key]
        if recent and now - recent.at <= EARLY_ROLL_SECONDS then
            ApplyRoll(current, player, recent.roll)
        end
    end
    ScheduleTimeout(current)
    ScheduleTestRolls(current)
    CheckRolls(current)
    return current, true
end

local function RollDice()
    if type(RandomRoll) ~= "function" then return false end
    local now = Now()
    if now - rollSentAt < RETRY_ROLL_SECONDS then return false end
    rollSentAt = now
    return pcall(RandomRoll, ROLL_MIN, ROLL_MAX) == true
end

-- /cproll and the dice on your toast: your roll for the fight that's on,
-- or a new one at the enemy you're targeting.
function PvPRoll.Roll()
    local current = session
    if current and not current.finished then
        local me = current.byKey[SelfKey() or ""]
        if me and IsWaiting(me) then RollDice() end
        return
    end
    local target = PvPRoll.EnemyTargetName()
    local _, started = PvPRoll.Begin(target)
    if started then Send(START .. (target or "")) end
    RollDice()
end

-- The sparring partner's roll, a moment after each round starts. "tie"
-- matches your first roll; "pass" never rolls.
ScheduleTestRolls = function(current)
    for _, player in ipairs(current.players) do
        if player.testMode and player.testMode ~= "pass" and IsWaiting(player) then
            local round = current.round
            local function RollForPartner()
                if session ~= current or current.round ~= round or current.finished or not IsWaiting(player) then return end
                if player.testMode == "tie" and round == 1 then
                    local me = current.byKey[SelfKey() or ""]
                    if not (me and me.roll) then
                        After(0.5, RollForPartner)
                        return
                    end
                    PvPRoll.RecordRoll(player.key, me.roll)
                    return
                end
                PvPRoll.RecordRoll(player.key, math.random(ROLL_MIN, ROLL_MAX))
            end
            After(TEST_ROLL_SECONDS + math.random() * TEST_ROLL_SPREAD, RollForPartner)
        end
    end
end

-- /cproll test [tie|pass]: a roll against a made-up sparring partner rather
-- than the party, to see it without anyone else. Your roll is a real /roll;
-- nothing goes to the party.
function PvPRoll.Test(mode)
    if mode ~= "tie" and mode ~= "pass" then mode = "roll" end
    local current = session
    if current and not current.finished and not current.test then
        PvPRoll.Roll()
        return
    end
    if current then current.finished = true end
    local me
    for _, member in ipairs(GroupMembers()) do
        if member.isSelf then me = member end
    end
    if not me then return end
    local partner = {
        key = TEST_KEY,
        name = L.PVP_ROLL_TEST_PARTNER or "Sparring Partner",
        classToken = "WARRIOR",
        testMode = mode,
    }
    current = PvPRoll.Begin(PvPRoll.EnemyTargetName(), { me, partner })
    if current then current.test = true end
    rollSentAt = -math.huge
    RollDice()
end

-- A party member who leaves stops holding up the roll.
local function OnRosterUpdate()
    local current = session
    if not current or current.finished then return end
    local present = {}
    for _, member in ipairs(GroupMembers()) do present[member.key] = true end
    for _, player in ipairs(current.players) do
        if IsWaiting(player) and not player.testMode and not present[player.key] then player.passed = true end
    end
    CheckRolls(current)
end

local function OnAddonMessage(prefix, text, _, sender)
    if Secret.ReadableString(prefix) ~= PREFIX then return end
    text, sender = Secret.ReadableString(text), Secret.ReadableString(sender)
    if not text or not sender then return end
    local senderKey = PvPRoll.NameKey(sender)
    if not senderKey or senderKey == SelfKey() or not IsGroupMember(senderKey) then return end
    if text:sub(1, 1) == START then
        local target = text:sub(2)
        PvPRoll.Begin(target ~= "" and target or nil)
    end
end

local function OnSystemMessage(text)
    local name, roll, low, high = PvPRoll.ParseRollLine(text)
    if not name or low ~= ROLL_MIN or high ~= ROLL_MAX then return end
    PvPRoll.RecordRoll(PvPRoll.NameKey(name), roll)
end

local eventFrame = CreateFrame and CreateFrame("Frame")
if eventFrame then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, PREFIX)
    end
    Carpenter:SafeRegisterEvent(eventFrame, "CHAT_MSG_SYSTEM")
    Carpenter:SafeRegisterEvent(eventFrame, "CHAT_MSG_ADDON")
    Carpenter:SafeRegisterEvent(eventFrame, "GROUP_ROSTER_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_SYSTEM" then
            OnSystemMessage(...)
        elseif event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        elseif event == "GROUP_ROSTER_UPDATE" then
            OnRosterUpdate()
        end
    end)
end

if SlashCmdList then
    SLASH_CARPENTERROLL1 = "/cproll"
    SlashCmdList["CARPENTERROLL"] = function(input)
        local command, mode = tostring(input or ""):lower():match("^%s*(%S*)%s*(%S*)")
        if command == "test" then
            PvPRoll.Test(mode)
        else
            PvPRoll.Roll()
        end
    end
end
