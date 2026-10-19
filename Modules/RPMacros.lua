--[[ Carpenter - Personal macros ]]
-- The author's favorite profession and roleplay macros, kept on the hidden
-- settings page so they can be rebuilt on any client or account in one click.
-- Each one is an account-wide (General) macro: checking it on the page
-- installs (or updates) it, unchecking removes it. A macro with build() writes
-- its body from your bags and is rewritten whenever they change.
local _, ns = ...
ns.Private = ns.Private or {}

local RPMacros = ns.Private.RPMacros or {}
ns.Private.RPMacros = RPMacros

-- Icons are file IDs, so they don't depend on the client's icon-name lookup.
RPMacros.Macros = {
    {
        name = "Bow",
        icon = 237573,
        body = "/bow",
    },
    -- Whistle at your opponent, tell your faction "1v1", then drop the target
    -- for a moment so /wait reaches everyone around, the other faction too
    -- (chat text doesn't cross factions, built-in emotes do).
    {
        name = "1v1",
        icon = 132269,
        body = "/whistle\n/s 1v1\n/cleartarget\n/wait\n/targetlasttarget",
    },
    -- The leveling ritual: whoever rolls higher gets the next enemy.
    {
        name = "Roll",
        icon = 237284,
        body = "/crack\n/roll",
    },
    {
        name = "Coin",
        icon = 133784,
        body = "/e flips a gold coin without looking.\n/roll 2",
    },
    {
        name = "Camp",
        icon = 135805,
        body = "/sit\n/e settles in by the fire and gives everyone around it a quiet nod.",
    },
}

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetBagItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetBagItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local MAIN_HAND_SLOT = 16
local FISHING_SPELL_ID = 7620
local WEAPON_CLASS_ID, FISHING_POLE_SUBCLASS_ID = 2, 20

-- Fishing skill each pole adds (Classic and TBC). Poles not listed count as
-- +0 and are compared by item level.
local FISHING_POLE_BONUS = {
    [6256] = 0,    -- Fishing Pole
    [12225] = 3,   -- Blump Family Fishing Pole
    [6365] = 5,    -- Strong Fishing Pole
    [6366] = 15,   -- Darkwood Fishing Pole
    [6367] = 20,   -- Big Iron Fishing Pole
    [25978] = 20,  -- Seth's Graphite Fishing Pole
    [19022] = 25,  -- Nat Pagle's Extreme Angler FC-5000
    [19970] = 35,  -- Arcanite Fishing Pole
}
RPMacros.FishingPoleBonus = FISHING_POLE_BONUS

local function GetFishingName()
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(FISHING_SPELL_ID)
    elseif GetSpellInfo then
        name = GetSpellInfo(FISHING_SPELL_ID)
    end
    return name or "Fishing"
end

local function IsFishingPole(itemID)
    if not itemID or not GetItemInfoInstant then return false end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    return classID == WEAPON_CLASS_ID and subClassID == FISHING_POLE_SUBCLASS_ID
end

-- The best fishing pole you're carrying or wielding: highest fishing bonus,
-- then highest item level, and the one in your hand on a tie.
function RPMacros.FindBestFishingPole()
    local best
    local function Consider(itemID, link, equipped)
        if not IsFishingPole(itemID) then return end
        local name, itemLevel
        if GetItemInfo then
            local _
            name, _, _, itemLevel = GetItemInfo(itemID)
        end
        name = name or (link and link:match("%[(.-)%]"))
        if not name then return end
        local pole = { name = name, bonus = FISHING_POLE_BONUS[itemID] or 0, level = itemLevel or 0, equipped = equipped }
        if not best or pole.bonus > best.bonus
            or (pole.bonus == best.bonus and pole.level > best.level)
            or (pole.bonus == best.bonus and pole.level == best.level and pole.equipped and not best.equipped)
        then
            best = pole
        end
    end

    if GetInventoryItemID then
        Consider(GetInventoryItemID("player", MAIN_HAND_SLOT), GetInventoryItemLink and GetInventoryItemLink("player", MAIN_HAND_SLOT), true)
    end
    if GetNumSlots and GetBagItemID then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, GetNumSlots(bag) or 0 do
                local itemID = GetBagItemID(bag, slot)
                if itemID then
                    Consider(itemID, GetBagItemLink and GetBagItemLink(bag, slot), false)
                end
            end
        end
    end
    return best and best.name
end

local function BuildFishingMacro()
    local fishing = GetFishingName()
    local lines = { "#showtooltip " .. fishing }
    local pole = RPMacros.FindBestFishingPole()
    if pole then
        lines[#lines + 1] = "/equipslot " .. MAIN_HAND_SLOT .. " " .. pole
    end
    lines[#lines + 1] = "/cast " .. fishing
    return table.concat(lines, "\n")
end

RPMacros.ProfessionMacros = {
    {
        name = "Fish",
        icon = 136245,
        build = BuildFishingMacro,
    },
}

function RPMacros.GetBody(macro)
    if macro.build then return macro.build() end
    return macro.body
end

function RPMacros.Install(macro)
    if type(macro) ~= "table" then
        return false, "invalid"
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" then
        return false, "unsupported"
    end

    local index = GetMacroIndexByName(macro.name)
    if index and index > 0 then
        local ok = pcall(EditMacro, index, macro.name, macro.icon, RPMacros.GetBody(macro))
        return ok, ok and "updated" or "failed"
    end

    local numAccount = type(GetNumMacros) == "function" and GetNumMacros()
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    if numAccount and numAccount >= maxAccount then
        return false, "full"
    end

    local ok, created = pcall(CreateMacro, macro.name, macro.icon, RPMacros.GetBody(macro), nil)
    if not ok or not created or created == 0 then
        return false, "failed"
    end
    return true, "created"
end

function RPMacros.IsInstalled(macro)
    if type(macro) ~= "table" or type(GetMacroIndexByName) ~= "function" then
        return false
    end
    local index = GetMacroIndexByName(macro.name)
    return index ~= nil and index > 0
end

function RPMacros.Remove(macro)
    if type(macro) ~= "table" then
        return false, "invalid"
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if type(GetMacroIndexByName) ~= "function" or type(DeleteMacro) ~= "function" then
        return false, "unsupported"
    end

    local index = GetMacroIndexByName(macro.name)
    if index and index > 0 then
        local ok = pcall(DeleteMacro, index)
        if not ok then
            return false, "failed"
        end
    end
    return true, "removed"
end

-- Keep built macros in step with your bags. Only macros you've installed are
-- rewritten, and never in combat, where macros can't be edited.
local refreshFrame = CreateFrame and CreateFrame("Frame")

function RPMacros.RefreshBuiltMacros()
    if InCombatLockdown and InCombatLockdown() then
        if refreshFrame then refreshFrame:RegisterEvent("PLAYER_REGEN_ENABLED") end
        return
    end
    if type(GetMacroIndexByName) ~= "function" or type(GetMacroInfo) ~= "function" then return end
    for _, macro in ipairs(RPMacros.ProfessionMacros) do
        local index = macro.build and GetMacroIndexByName(macro.name)
        if index and index > 0 then
            local body = macro.build()
            local _, _, currentBody = GetMacroInfo(index)
            if currentBody ~= body then
                pcall(EditMacro, index, macro.name, macro.icon, body)
            end
        end
    end
end

if refreshFrame then
    refreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    refreshFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    refreshFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    refreshFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            self:UnregisterEvent(event)
        end
        RPMacros.RefreshBuiltMacros()
    end)
end
