#!/usr/bin/env lua
-- Offline fixture checks for Quick Lockpick: a locked lockbox in the bags, or
-- in the trade window's bottom slot, gets a right-click button that casts
-- Pick Lock on it, and nothing else does.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "quick-lockpick")
local fail, assertEqual, assertTrue = H.fail, H.assertEqual, H.assertTrue

H.installCreateFrame()
H.installHooks()
H.installUIParent()

-- Frames the module creates also take the button and texture calls it uses,
-- and run their OnHide script like the game does.
local createFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent)
    frame.template = template
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:SetPassThroughButtons(...) self.passThrough = { ... } end
    function frame:SetAllPoints(target) self.allPoints = target end
    function frame:CreateTexture(_, layer)
        local texture = H.Frame({ layer = layer })
        function texture:SetAllPoints() end
        function texture:SetTexture(path) self.texture = path end
        function texture:SetBlendMode(mode) self.blendMode = mode end
        frame.texture = texture
        return texture
    end
    local hide = frame.Hide
    function frame:Hide()
        local wasShown = self.shown
        hide(self)
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    return frame
end

-- =========================
-- Game state
-- =========================
local now = 100
GetTime = function() return now end
local inCombat = false
InCombatLockdown = function() return inCombat end
local cursorItem
GetCursorInfo = function() return cursorItem end
SpellIsTargeting = function() return false end
local playerClass = "WARRIOR"
UnitClass = function() return "Class", playerClass end
local knowsPickLock = true
C_SpellBook = { IsSpellKnown = function(spellID) return spellID == 1804 and knowsPickLock end }
C_Spell = { GetSpellName = function(spellID) if spellID == 1804 then return "Pick Lock" end end }
LOCKED = "Locked"
GREEN_FONT_COLOR = { r = 0.1, g = 1, b = 0.1 }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
TRADE_ENCHANT_SLOT = 7

Enum = { PlayerInteractionType = { TradePartner = 1, Merchant = 5, Banker = 8, MailInfo = 17, Auctioneer = 21 } }
local interacting = {}
C_PlayerInteractionManager = {
    IsInteractingWithNpcOfType = function(kind) return interacting[kind] == true end,
}

-- Text the game hides from addons.
local secretMeta = { __index = function() error("attempt to use a secret value") end }
local function Secret(value) return setmetatable({ value = value }, secretMeta) end
issecretvalue = function(value) return getmetatable(value) == secretMeta end

-- Tooltip data, as C_TooltipInfo returns it.
local function Color(r, g, b) return { GetRGB = function() return r, g, b end } end
local WHITE, RED = Color(1, 1, 1), Color(1, 0.125, 0.125)
local function Lockbox(name, lockedColor)
    return { lines = { { leftText = name, leftColor = WHITE }, { leftText = "Locked", leftColor = lockedColor or WHITE } } }
end
local function Item(name, ...)
    local lines = { { leftText = name, leftColor = WHITE } }
    for _, text in ipairs({ ... }) do lines[#lines + 1] = { leftText = text, leftColor = WHITE } end
    return { lines = lines }
end
local bagItems, tradeItems, fetches = {}, {}, 0
C_TooltipInfo = {
    GetBagItem = function(bag, slot)
        fetches = fetches + 1
        return bagItems[bag .. ":" .. slot]
    end,
    GetTradeTargetItem = function(index)
        fetches = fetches + 1
        return tradeItems[index]
    end,
}

-- GameTooltip, as far as the module and the slots use it.
GameTooltip = H.NamedFrame("GameTooltip", { shown = false })
function GameTooltip:SetOwner(owner, anchor)
    self.owner, self.anchor, self.lines, self.item = owner, anchor, {}, nil
    self.points = {}
end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:IsOwned(frame) return self.owner == frame end
function GameTooltip:SetBagItem(bag, slot) self.item = { bag = bag, slot = slot } end
function GameTooltip:SetTradeTargetItem(index) self.item = { trade = index } end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end

-- A bag slot: ContainerFrameItemButtonMixin:OnUpdate sets the tooltip's
-- owner and anchor, then the item. The game calls it again while hovered.
local bags = H.Frame({ name = "ContainerFrameCombinedBags" })
local slots = {}
local function BagSlot(bag, slot)
    local button = H.Frame({ parent = bags, mouseOver = false })
    function button:GetBagID() return bag end
    function button:GetID() return slot end
    function button:UpdateTooltip()
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT")
        GameTooltip:SetBagItem(bag, slot)
        GameTooltip:Show()
    end
    slots[#slots + 1] = button
    return button
end

-- The other player's side of the trade window: OnEnter and OnUpdate.
local trade = H.NamedFrame("TradeFrame")
local function TradeSlot(index)
    local button = H.NamedFrame("TradeRecipientItem" .. index .. "ItemButton", { parent = trade, mouseOver = false })
    function button:UpdateTooltip()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetTradeTargetItem(index)
        GameTooltip:Show()
    end
    slots[#slots + 1] = button
    return button
end

local function Hover(button)
    for _, other in ipairs(slots) do other.mouseOver = false end
    button.mouseOver = true
    button:UpdateTooltip()
end

local box = BagSlot(0, 3)
local potion = BagSlot(0, 4)
local redBox = BagSlot(1, 1)
local openBox = BagSlot(1, 2)
local hiddenBox = BagSlot(2, 1)
local bankBox = BagSlot(6, 1)
bagItems["0:3"] = Lockbox("Iron Lockbox")
bagItems["0:4"] = Item("Healing Potion", "Use: Restores 455 health.")
bagItems["1:1"] = Lockbox("Thorium Lockbox", RED)
bagItems["1:2"] = Item("Iron Lockbox", "<Right Click to Open>")
bagItems["2:1"] = { lines = { { leftText = "Steel Lockbox" }, { leftText = Secret("Common") }, { leftText = "Locked", leftColor = WHITE } } }
bagItems["6:1"] = Lockbox("Iron Lockbox")
local tradeBox = TradeSlot(7)
local tradeGift = TradeSlot(1)
tradeItems[7] = Lockbox("Heavy Bronze Lockbox")
tradeItems[1] = Lockbox("Iron Lockbox")

-- =========================
-- Load
-- =========================
CarpenterDB = { quickLockpickEnabled = true }
H.carpenter({
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    RegisterFeature = H.captureFeature("quickLockpickEnabled"),
})
H.load("Modules/QuickLockpick.lua")
local feature = H.features.quickLockpickEnabled
if not feature then fail("Quick Lockpick did not register its feature") end
local QuickLockpick = Carpenter.QuickLockpick
local events = QuickLockpick.eventFrame

local function Cover() return QuickLockpick.GetCover() end
local function Covered()
    local cover = Cover()
    return cover ~= nil and cover:IsShown()
end
local function Fire(event, ...) events.scripts.OnEvent(events, event, ...) end
local function Leave()
    local cover = Cover()
    if cover and cover:IsShown() then cover.scripts.OnLeave(cover) end
    for _, other in ipairs(slots) do other.mouseOver = false end
end

-- Only rogues get the hooks.
feature:Enable()
Hover(box)
assertTrue(Cover() == nil, "a non-rogue should get no button")
assertEqual(next(events.events), nil, "a non-rogue should register no events")
feature:Disable()

playerClass = "ROGUE"
feature:Enable()

-- =========================
-- A locked lockbox in the bags
-- =========================
Hover(box)
local cover = Cover()
assertTrue(Covered(), "hovering a locked lockbox should show the button")
assertEqual(cover.template, "InsecureActionButtonTemplate", "the button should act only out of combat")
assertEqual(cover.allPoints, box, "the button should cover the hovered slot")
assertEqual(cover:GetAttribute("type2"), "macro", "right-click should run the macro")
assertEqual(cover:GetAttribute("macrotext"), "/cast Pick Lock\n/use 0 3", "the macro should pick the hovered slot")
assertEqual(cover:GetAttribute("useOnKeyDown"), false, "the macro should run on release")
assertEqual(cover.clicks[1], "RightButtonUp", "only right-clicks should cast")
assertEqual(cover.passThrough[1], "LeftButton", "left-clicks should reach the slot")
assertEqual(cover.texture.layer, "HIGHLIGHT", "the slot should still light up under the mouse")

-- The button takes the mouse, so it shows the slot's tooltip itself, where
-- the game had put it.
cover.scripts.OnEnter(cover)
assertTrue(GameTooltip:IsOwned(cover), "the button should own the tooltip")
assertEqual(GameTooltip.item and GameTooltip.item.bag, 0, "the tooltip should show the box's bag")
assertEqual(GameTooltip.item and GameTooltip.item.slot, 3, "the tooltip should show the box's slot")
assertEqual(GameTooltip.lines[#GameTooltip.lines], "<Right Click to Pick Lock>", "the tooltip should end with the hint")
local point, relativeTo = GameTooltip:GetPoint(1)
assertEqual(point, "BOTTOMRIGHT", "the tooltip should keep the game's anchor")
assertEqual(relativeTo, box, "the tooltip should stay next to the slot")
assertTrue(Covered(), "the button's own tooltip should not move it")

Leave()
assertTrue(not Covered(), "leaving the slot should hide the button")
assertTrue(not GameTooltip.shown, "leaving the slot should hide the button's tooltip")

-- =========================
-- Slots that stay the game's
-- =========================
Hover(potion)
assertTrue(not Covered(), "an item that is not locked should get no button")
Hover(openBox)
assertTrue(not Covered(), "a lockbox already picked should get no button")
Hover(redBox)
assertTrue(not Covered(), "a lock beyond your skill should get no button")
Hover(hiddenBox)
assertTrue(not Covered(), "a tooltip the game hides from addons should get no button")
Hover(bankBox)
assertTrue(not Covered(), "a lockbox in the bank should get no button")

-- A tooltip some other code fills for a slot nobody is hovering.
Leave()
GameTooltip:SetOwner(box, "ANCHOR_NONE")
GameTooltip:SetBagItem(0, 3)
assertTrue(not Covered(), "a slot that isn't hovered should get no button")

-- While a vendor, bank, mailbox, auction house or trade is open, right-click
-- already does something there.
for _, kind in ipairs({ 5, 8, 17, 21, 1 }) do
    interacting[kind] = true
    Hover(box)
    assertTrue(not Covered(), "a bag slot should stay the game's while interaction " .. kind .. " is open")
    interacting[kind] = nil
    Leave()
end

knowsPickLock = false
Hover(box)
assertTrue(not Covered(), "without Pick Lock there should be no button")
knowsPickLock = true
Leave()

cursorItem = "item"
Hover(box)
assertTrue(not Covered(), "with an item on the cursor there should be no button")
cursorItem = nil
Leave()

inCombat = true
Hover(box)
assertTrue(not Covered(), "in combat there should be no button")
inCombat = false
Leave()

-- =========================
-- What hides the button
-- =========================
Hover(box)
assertTrue(Covered(), "the box should be covered again")
Fire("PLAYER_REGEN_DISABLED")
assertTrue(not Covered(), "entering combat should hide the button")

Hover(box)
Fire("CURSOR_CHANGED")
assertTrue(Covered(), "a cursor change alone should keep the button")
cursorItem = "item"
Fire("CURSOR_CHANGED")
assertTrue(not Covered(), "picking the box up should hide the button")
cursorItem = nil

-- A bag change hides it, and the slot is read again right away.
Hover(box)
Fire("BAG_UPDATE_DELAYED")
assertTrue(not Covered(), "a bag change should hide the button")
Hover(box)
assertTrue(Covered(), "the slot should be read again right after a bag change")

-- Closing the bags.
bags.shown = false
cover.scripts.OnUpdate(cover)
assertTrue(not Covered(), "closing the bags should hide the button")
bags.shown = true
Leave()

-- =========================
-- Reading a slot
-- =========================
-- The game refreshes a hovered tooltip five times a second; the slot's data
-- is read once a second.
fetches = 0
Hover(potion)
for _ = 1, 4 do potion:UpdateTooltip() end
assertEqual(fetches, 1, "a hovered slot should be read once")
now = now + 1.1
potion:UpdateTooltip()
assertEqual(fetches, 2, "a hovered slot should be read again after a second")
Leave()

-- =========================
-- After Pick Lock
-- =========================
now = now + 5
Hover(box)
cover.scripts.PostClick(cover, "RightButton")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2098)
assertTrue(Covered(), "another spell should keep the button")
-- The mouse may leave before the cast finishes.
Leave()
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1804)
now = now + 0.5
Hover(box)
assertTrue(not Covered(), "a box just picked should get no button while it still reads as locked")
now = now + 1.5
box:UpdateTooltip()
assertTrue(Covered(), "a box still locked after the pause should get the button again")
cover.scripts.PostClick(cover, "RightButton")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1804)
assertTrue(not Covered(), "a finished Pick Lock should hide the button")
Leave()

-- =========================
-- The trade window
-- =========================
now = now + 5
interacting[1] = true
Hover(tradeBox)
assertTrue(Covered(), "a locked lockbox in the trade window's bottom slot should get the button")
assertEqual(cover.allPoints, tradeBox, "the button should cover the trade slot")
assertEqual(cover:GetAttribute("macrotext"), "/cast Pick Lock\n/click TradeRecipientItem7ItemButton", "the macro should pick the trade slot")
cover.scripts.OnEnter(cover)
assertEqual(GameTooltip.item and GameTooltip.item.trade, 7, "the tooltip should show the trade slot")
assertEqual(GameTooltip.anchor, "ANCHOR_RIGHT", "the trade tooltip should open where the game opens it")
assertEqual(GameTooltip.lines[#GameTooltip.lines], "<Right Click to Pick Lock>", "the trade tooltip should end with the hint")
Fire("TRADE_TARGET_ITEM_CHANGED", 7)
assertTrue(not Covered(), "a new item in the trade slot should hide the button")
Leave()
Hover(tradeGift)
assertTrue(not Covered(), "a lockbox being traded should get no button")
interacting[1] = nil
Leave()

-- =========================
-- Turning it off
-- =========================
Hover(box)
assertTrue(Covered(), "the box should be covered before turning it off")
CarpenterDB.quickLockpickEnabled = false
feature:Disable()
assertTrue(not Covered(), "turning the option off should hide the button")
assertEqual(next(events.events), nil, "turning the option off should drop the events")
Hover(box)
assertTrue(not Covered(), "with the option off there should be no button")

print("quick-lockpick fixtures: passed")
