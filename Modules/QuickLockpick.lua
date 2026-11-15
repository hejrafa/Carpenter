--[[ Carpenter - QuickLockpick ]]
-- Right-click a locked lockbox in your bags, or the one another player puts
-- in the trade window's "will not be traded" slot, to cast Pick Lock on it.
--
-- Addon code can't cast a spell when a bag slot is clicked. So while you
-- hover a locked lockbox out of combat, an invisible action button covers
-- that slot. Its right-click runs "/cast Pick Lock" and then "/use <bag>
-- <slot>", or "/click" on the trade slot. Left-clicks pass through to the
-- slot, so the box can still be picked up and moved. The button uses
-- InsecureActionButtonTemplate, which acts only out of combat, and it hides
-- when combat starts. Over the box, the cursor turns into the glowing hand
-- the game shows while Pick Lock waits for its target.
--
-- Nothing of Blizzard's is changed. Post-hooks on GameTooltip's SetBagItem
-- and SetTradeTargetItem notice the hovered slot, and the game's tooltip
-- data for that slot says whether it is locked.

local _, ns = ...
local L = (Carpenter and Carpenter.L) or (ns and ns.L) or {}

local FEATURE_KEY = "quickLockpickEnabled"
local PICK_LOCK_SPELL_ID = 1804
-- The trade window's "will not be traded" slot (TRADE_ENCHANT_SLOT).
local TRADE_TARGET_SLOT = 7
-- A hovered slot's lock is read again after this many seconds; the game
-- refreshes a bag tooltip five times a second.
local RECHECK_SECONDS = 1
-- A box that was just picked still reads as locked for a moment.
local PICKED_PAUSE_SECONDS = 1.5

-- While one of these is open, right-clicking a bag item sells, banks, mails,
-- posts or trades it, so the bag slots are left to the game.
local BAG_CLICK_TAKEN_BY = {
    "Merchant",
    "TradePartner",
    "Banker",
    "GuildBanker",
    "MailInfo",
    "Auctioneer",
    "VoidStorageBanker",
    "CharacterBanker",
    "AccountBanker",
}

local QuickLockpick = {}

local eventFrame = CreateFrame("Frame")
local cover
-- What the cover sits on: owner, key, bag, slot, trade, points.
local covered
local lastKey, lastCheckedAt = nil, -math.huge
-- The slot the last right-click cast on, and the one just picked open.
local castKey
local pickedKey, pickedAt = nil, -math.huge
local hooked = false

local function Now()
    return GetTime and GetTime() or 0
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsRogue()
    local _, class = UnitClass("player")
    return class == "ROGUE"
end

local function KnowsPickLock()
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(PICK_LOCK_SPELL_ID) == true
    end
    if IsPlayerSpell then return IsPlayerSpell(PICK_LOCK_SPELL_ID) == true end
    if IsSpellKnown then return IsSpellKnown(PICK_LOCK_SPELL_ID) == true end
    return false
end

local function PickLockName()
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(PICK_LOCK_SPELL_ID)
    if name == nil and GetSpellInfo then name = GetSpellInfo(PICK_LOCK_SPELL_ID) end
    if IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

local function LastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function BagClicksTaken()
    local manager = C_PlayerInteractionManager
    local types = Enum and Enum.PlayerInteractionType
    if not (manager and manager.IsInteractingWithNpcOfType and types) then return false end
    for _, name in ipairs(BAG_CLICK_TAKEN_BY) do
        local kind = types[name]
        if kind and manager.IsInteractingWithNpcOfType(kind) then return true end
    end
    return false
end

local function CanCover()
    if not Carpenter:IsEnabled(FEATURE_KEY) then return false end
    if InCombatLockdown() then return false end
    if GetCursorInfo() then return false end
    if SpellIsTargeting and SpellIsTargeting() then return false end
    return KnowsPickLock()
end

local function IsWarningRed(color)
    if not color or not color.GetRGB then return false end
    local r, g, b = color:GetRGB()
    if IsSecret(r) or IsSecret(g) or IsSecret(b) then return false end
    return r > 0.9 and g < 0.3 and b < 0.3
end

-- A lockbox's tooltip has a "Locked" line until it is picked. The game shows
-- that line in red when the lock is beyond your skill, and then the click is
-- left to the game.
local function IsPickable(data)
    local lines = type(data) == "table" and data.lines
    if type(lines) ~= "table" then return false end
    local lockedText = LOCKED or "Locked"
    for index = 2, #lines do
        local line = lines[index]
        local text = type(line) == "table" and line.leftText
        if IsSecret(text) then return false end
        if text == lockedText then
            return not IsWarningRed(line.leftColor)
        end
    end
    return false
end

local function RecentlyPicked(key)
    return key == pickedKey and Now() - pickedAt < PICKED_PAUSE_SECONDS
end

-- The game refreshes a hovered slot's tooltip over and over, so a slot is
-- read once and then again only after RECHECK_SECONDS.
local function ShouldCheck(key)
    local now = Now()
    if key == lastKey and now - lastCheckedAt < RECHECK_SECONDS then return false end
    lastKey, lastCheckedAt = key, now
    return true
end

-- Where the game put the slot's tooltip, so the tooltip stays put once the
-- cover takes the mouse.
local function TooltipPoints(tooltip)
    local points = {}
    local count = tooltip.GetNumPoints and tooltip:GetNumPoints() or 0
    for index = 1, count do
        points[index] = { tooltip:GetPoint(index) }
    end
    return points
end

-- The glowing hand the game shows while a spell waits for its target, so the
-- box looks the way it does with Pick Lock in hand. The game ignores
-- SetCursor over the world, but the button is a UI frame.
local function ShowCastCursor()
    local modes = Enum and Enum.Cursormode
    if SetCursorByMode and modes and modes.CastCursor then
        SetCursorByMode(modes.CastCursor)
    end
end

local function HideCover()
    lastKey = nil
    if cover and cover:IsShown() then cover:Hide() end
    covered = nil
end

local function Cover_OnEnter(self)
    local target = covered
    if not target then return end
    local points = target.points
    if points and #points > 0 then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        for _, point in ipairs(points) do
            GameTooltip:SetPoint(unpack(point))
        end
    else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    end
    if target.trade then
        GameTooltip:SetTradeTargetItem(target.slot)
    else
        GameTooltip:SetBagItem(target.bag, target.slot)
    end
    local color = GREEN_FONT_COLOR
    GameTooltip:AddLine(L.QUICK_LOCKPICK_HINT or "<Right Click to Pick Lock>",
        color and color.r or 0.1, color and color.g or 1, color and color.b or 0.1, true)
    GameTooltip:Show()
    ShowCastCursor()
end

local function Cover_OnLeave()
    HideCover()
end

-- Like the game's own bag slots, the cursor stays as it is while a spell
-- waits for its target.
local function Cover_OnHide(self)
    covered = nil
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    if ResetCursor and not (SpellIsTargeting and SpellIsTargeting()) then ResetCursor() end
end

-- Closing the bags or the trade window takes the slot away under the cover.
local function Cover_OnUpdate()
    local target = covered
    if not target or not target.owner:IsVisible() or InCombatLockdown() then
        HideCover()
    end
end

-- Runs after the button's own click, so the cast's slot is known even if
-- the mouse leaves before Pick Lock finishes. Targeting the box hands the
-- cursor back to the game, so the glowing hand goes back on.
local function Cover_PostClick(self, mouseButton)
    if mouseButton ~= "RightButton" or not covered then return end
    castKey = covered.key
    if self:IsMouseOver() then ShowCastCursor() end
end

local function CreateCover()
    local button = CreateFrame("Button", "CarpenterQuickLockpickButton", UIParent, "InsecureActionButtonTemplate")
    button:Hide()
    button:SetFrameStrata("FULLSCREEN_DIALOG")
    button:EnableMouse(true)
    button:RegisterForClicks("RightButtonUp")
    if button.SetPassThroughButtons then button:SetPassThroughButtons("LeftButton") end
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type2", "macro")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnEnter", Cover_OnEnter)
    button:SetScript("OnLeave", Cover_OnLeave)
    button:SetScript("OnHide", Cover_OnHide)
    button:SetScript("OnUpdate", Cover_OnUpdate)
    button:SetScript("PostClick", Cover_PostClick)
    return button
end

local function ShowCover(target, macroText)
    cover = cover or CreateCover()
    covered = target
    cover:SetAttribute("macrotext", macroText)
    cover:ClearAllPoints()
    cover:SetAllPoints(target.owner)
    cover:Show()
end

local function IsHovered(owner)
    if not owner or (owner.IsForbidden and owner:IsForbidden()) then return false end
    return owner:IsVisible() and owner:IsMouseOver()
end

local function OnSetBagItem(tooltip, bag, slot)
    if type(bag) ~= "number" or type(slot) ~= "number" then return end
    if bag < 0 or bag > LastBag() then return end
    local owner = tooltip:GetOwner()
    if not IsHovered(owner) or not owner.GetBagID or not owner.GetID then return end
    if owner:GetBagID() ~= bag or owner:GetID() ~= slot then return end
    if not CanCover() or BagClicksTaken() then return end

    local key = bag .. ":" .. slot
    if RecentlyPicked(key) or not ShouldCheck(key) then return end
    local data = C_TooltipInfo and C_TooltipInfo.GetBagItem and C_TooltipInfo.GetBagItem(bag, slot)
    if not IsPickable(data) then return end
    local spellName = PickLockName()
    if not spellName then return end

    ShowCover({ owner = owner, key = key, bag = bag, slot = slot, points = TooltipPoints(tooltip) },
        string.format("/cast %s\n/use %d %d", spellName, bag, slot))
end

local function OnSetTradeTargetItem(tooltip, index)
    local tradeSlot = TRADE_ENCHANT_SLOT or TRADE_TARGET_SLOT
    if index ~= tradeSlot then return end
    local buttonName = "TradeRecipientItem" .. tradeSlot .. "ItemButton"
    local owner = tooltip:GetOwner()
    if owner == nil or owner ~= _G[buttonName] or not IsHovered(owner) then return end
    if not CanCover() then return end

    local key = "trade"
    if RecentlyPicked(key) or not ShouldCheck(key) then return end
    local data = C_TooltipInfo and C_TooltipInfo.GetTradeTargetItem and C_TooltipInfo.GetTradeTargetItem(tradeSlot)
    if not IsPickable(data) then return end
    local spellName = PickLockName()
    if not spellName then return end

    ShowCover({ owner = owner, key = key, slot = tradeSlot, trade = true, points = TooltipPoints(tooltip) },
        string.format("/cast %s\n/click %s", spellName, buttonName))
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        HideCover()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if castKey and not IsSecret(spellID) and spellID == PICK_LOCK_SPELL_ID then
            pickedKey, pickedAt, castKey = castKey, Now(), nil
            HideCover()
        end
    elseif event == "CURSOR_CHANGED" then
        -- A left-click passed through and picked the box up.
        if covered and GetCursorInfo() then HideCover() end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- The slot may hold something else now; hovering reads it again.
        if covered and not covered.trade then HideCover() end
    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        if covered and covered.trade then HideCover() end
    end
end)

local feature = {}

function feature:Enable()
    if not IsRogue() then return end
    if not hooked and GameTooltip then
        hooked = true
        Carpenter:SafeHook(GameTooltip, "SetBagItem", OnSetBagItem)
        Carpenter:SafeHook(GameTooltip, "SetTradeTargetItem", OnSetTradeTargetItem)
    end
    Carpenter:SafeRegisterEvent(eventFrame, "PLAYER_REGEN_DISABLED")
    Carpenter:SafeRegisterUnitEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")
    Carpenter:SafeRegisterEvent(eventFrame, "CURSOR_CHANGED")
    Carpenter:SafeRegisterEvent(eventFrame, "BAG_UPDATE_DELAYED")
    Carpenter:SafeRegisterEvent(eventFrame, "TRADE_TARGET_ITEM_CHANGED")
end

function feature:Disable()
    eventFrame:UnregisterAllEvents()
    HideCover()
end

QuickLockpick.feature = feature
QuickLockpick.eventFrame = eventFrame
QuickLockpick.GetCover = function() return cover end
Carpenter.QuickLockpick = QuickLockpick

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
