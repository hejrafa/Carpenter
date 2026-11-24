--[[ Carpenter - Mount Speed Trinket ]]
-- Automatically equips a mount speed trinket when mounting.
-- Classic Era supports Carrot on a Stick; TBC also supports Riding Crop and prefers it when available.
-- WoW Forever prefers The Desert Rose (+7%) in desert zones, otherwise Carrot on a Stick (+3%).

local RIDING_CROP_ID = 25653
local CARROT_ID = 11122
local DESERT_ROSE_ID = 274648
local TRINKET_SLOTS = { 13, 14 }

-- The Desert Rose's spell (1294646) only works in area group 9097: Tanaris,
-- Thousand Needles, Silithus, Blasted Lands, Badlands, the Barrens, Desolace,
-- Ahn'Qiraj, Durotar, Orgrimmar, Uldaman and Zul'Farrak (Forever DB2
-- SpellCastingRequirements and AreaGroupMember, build 1.60.1.71037).
local DESERT_AREA_IDS = {
    440, 400, 1377, 4, 16115, 3, 17, 405, 16017,
    3428, 3478, 3429, 16076, 14, 1637, 1337, 1176,
}

-- Best first. soulboundOnly skips a tradeable copy; desertOnly items only
-- count in a desert zone.
local VANILLA_PRIORITY = { { id = CARROT_ID } }
local TBC_PRIORITY = { { id = RIDING_CROP_ID, soulboundOnly = true }, { id = CARROT_ID } }
local FOREVER_PRIORITY = { { id = DESERT_ROSE_ID, desertOnly = true }, { id = CARROT_ID } }

local function BuildIDSet(priority)
    local set = {}
    for _, entry in ipairs(priority) do set[entry.id] = true end
    return set
end

local MOUNT_SPEED_TRINKET_IDS = {
    [VANILLA_PRIORITY] = BuildIDSet(VANILLA_PRIORITY),
    [TBC_PRIORITY] = BuildIDSet(TBC_PRIORITY),
    [FOREVER_PRIORITY] = BuildIDSet(FOREVER_PRIORITY),
}

local previousTrinketID = nil
local lastSwapTime = 0
local pendingSwapBack = false
local swapScheduled = false

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("autoCarrotEnabled")
end

local function GetTargetSlot()
    return (CarpenterDB and CarpenterDB.autoCarrotSlot) or 13
end

local function GetMountSpeedPriority()
    local client = Carpenter and Carpenter.Client
    if client and client.isForever then return FOREVER_PRIORITY end
    if client and client.isVanilla then return VANILLA_PRIORITY end
    return TBC_PRIORITY
end

local function IsMountSpeedTrinket(itemID)
    return itemID and MOUNT_SPEED_TRINKET_IDS[GetMountSpeedPriority()][itemID]
end

-- Zone names come from the game, so they match the player's language.
local desertZoneNames
local function IsInDesert()
    if not desertZoneNames then
        local getAreaInfo = C_Map and C_Map.GetAreaInfo
        if not getAreaInfo then return false end
        local names, found = {}, false
        for _, areaID in ipairs(DESERT_AREA_IDS) do
            local name = getAreaInfo(areaID)
            if name and name ~= "" then
                names[name] = true
                found = true
            end
        end
        if not found then return false end
        desertZoneNames = names
    end
    local zone = GetRealZoneText and GetRealZoneText()
    return zone ~= nil and desertZoneNames[zone] == true
end

-- True if the player can equip this item (level requirement).
local function CanUseTrinket(itemID)
    if not itemID then return false end
    local getItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local _, _, _, _, reqLevel = getItemInfo(itemID)
    if not reqLevel or reqLevel == 0 then return true end
    return UnitLevel("player") >= reqLevel
end

-- True if the item in bag/slot is soulbound (so we don't equip a tradeable Riding Crop).
local function IsContainerItemSoulbound(bag, slot)
    local soulbound = (ITEM_SOULBOUND or "Soulbound"):lower()
    local function textHasSoulbound(text)
        return text and text:lower():find(soulbound, 1, true)
    end
    local tt = GameTooltip
    local prevOwner = tt:GetOwner()
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:ClearLines()
    tt:SetBagItem(bag, slot)
    -- Scan named lines (GameTooltipTextLeft1, etc.)
    local n = tt:NumLines() or 0
    for i = 1, n do
        for _, base in ipairs({ "GameTooltipTextLeft", "GameTooltipTextRight" }) do
            local line = _G[base .. i]
            if line and line.GetText and textHasSoulbound(line:GetText()) then
                tt:ClearLines()
                tt:Hide()
                if prevOwner then tt:SetOwner(prevOwner, "ANCHOR_NONE") end
                return true
            end
        end
    end
    -- Fallback: scan all regions (some clients use different tooltip layout)
    for _, region in ipairs({ tt:GetRegions() }) do
        if region and region.GetText then
            if textHasSoulbound(region:GetText()) then
                tt:ClearLines()
                tt:Hide()
                if prevOwner then tt:SetOwner(prevOwner, "ANCHOR_NONE") end
                return true
            end
        end
    end
    tt:ClearLines()
    tt:Hide()
    if prevOwner then tt:SetOwner(prevOwner, "ANCHOR_NONE") end
    return false
end

local function GetWornMountSpeedSlot()
    for _, slot in ipairs(TRINKET_SLOTS) do
        if IsMountSpeedTrinket(GetInventoryItemID("player", slot)) then
            return slot
        end
    end
    return nil
end

-- The best mount speed trinket the player can use here. Returns its item ID,
-- then the bag and slot when it sits in the bags, or nil, nil, slot when it is
-- already equipped. Riding Crop only counts when soulbound; a tradeable Crop
-- falls through to Carrot.
local function FindBestMountSpeedTrinket()
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID

    for _, entry in ipairs(GetMountSpeedPriority()) do
        local preferredID = entry.id
        if CanUseTrinket(preferredID) and (not entry.desertOnly or IsInDesert()) then
            for _, slot in ipairs(TRINKET_SLOTS) do
                if GetInventoryItemID("player", slot) == preferredID then
                    return preferredID, nil, nil, slot
                end
            end
            for bag = 0, 4 do
                local numSlots = getNumSlots(bag)
                if numSlots then
                    for slot = 1, numSlots do
                        if getItemID(bag, slot) == preferredID
                            and (not entry.soulboundOnly or IsContainerItemSoulbound(bag, slot)) then
                            return preferredID, bag, slot
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function GetItemBagPos(targetID)
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID

    for bag = 0, 4 do
        local numSlots = getNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                if getItemID(bag, slot) == targetID then
                    return bag, slot
                end
            end
        end
    end
    return nil
end

-- Find any non-mount-speed trinket in bags to use as a fallback if previousTrinketID is lost
local function FindFallbackTrinket()
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    local getItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

    for bag = 0, 4 do
        local numSlots = (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(bag)
        if numSlots then
            for slot = 1, numSlots do
                local id = getItemID(bag, slot)
                if id and not IsMountSpeedTrinket(id) then
                    local _, _, _, _, _, _, _, _, equipLoc = getItemInfo(id)
                    if equipLoc == "INVTYPE_TRINKET" then
                        return id
                    end
                end
            end
        end
    end
    return nil
end

local function SwapTrinket()
    swapScheduled = false
    -- Check if enabled and if the player is alive/not a ghost
    if not IsEnabled() or UnitIsDeadOrGhost("player") then return end

    local targetSlot = GetTargetSlot()

    -- In combat, we can't swap gear. Mark for later.
    if InCombatLockdown() then
        if not IsMounted() and (IsMountSpeedTrinket(GetInventoryItemID("player", 13)) or IsMountSpeedTrinket(GetInventoryItemID("player", 14))) then
            pendingSwapBack = true
        end
        return
    end

    local now = GetTime()
    if now - lastSwapTime < 0.5 then
        -- Mounting and a zone change can come right after a swap: look again.
        swapScheduled = true
        C_Timer.After(0.5 - (now - lastSwapTime) + 0.05, SwapTrinket)
        return
    end

    local isMounted = IsMounted()
    local isFlying = (IsFlyableArea() and IsFlying()) or UnitOnTaxi("player")
    local currentTrinketAtTarget = GetInventoryItemID("player", targetSlot)

    -- Equip the best mount speed trinket for here. One that is already worn
    -- gets replaced in its own slot, so a better one for this zone takes over
    -- while the trinket from before mounting stays remembered.
    if isMounted and not isFlying then
        local _, bag, slot = FindBestMountSpeedTrinket()
        if bag and slot then
            local wornSlot = GetWornMountSpeedSlot()
            if not wornSlot then
                previousTrinketID = currentTrinketAtTarget
            end

            if C_Container and C_Container.PickupContainerItem then
                C_Container.PickupContainerItem(bag, slot)
            else
                PickupContainerItem(bag, slot)
            end

            EquipCursorItem(wornSlot or targetSlot)
            lastSwapTime = now
            pendingSwapBack = false
        end
    -- Logic for swapping back (dismounted, flying, or pending from combat)
    elseif not isMounted or isFlying or pendingSwapBack then
        if IsMountSpeedTrinket(GetInventoryItemID("player", targetSlot)) then
            -- Use stored ID, or look for a fallback if the ID was lost/not set
            local swapTargetID = previousTrinketID or FindFallbackTrinket()

            if swapTargetID then
                local bag, slot = GetItemBagPos(swapTargetID)
                if bag and slot then
                    if C_Container and C_Container.PickupContainerItem then
                        C_Container.PickupContainerItem(bag, slot)
                    else
                        PickupContainerItem(bag, slot)
                    end

                    EquipCursorItem(targetSlot)
                    previousTrinketID = nil
                    pendingSwapBack = false
                    lastSwapTime = now
                else
                    -- Target item not in bags anymore, clear the record to try fresh next time
                    previousTrinketID = nil
                end
            end
        end
    end
end

local function ScheduleSwap(delay)
    if swapScheduled then return end
    swapScheduled = true
    C_Timer.After(delay or 0.1, SwapTrinket)
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_MODEL_CHANGED" and unit ~= "player" then return end
    ScheduleSwap(0.1)
end)

local feature = {}

function feature:Enable()
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    -- Riding into or out of a desert changes which trinket is best.
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
    -- Turned on while playing: check right away. At startup the events cover it.
    if IsLoggedIn and IsLoggedIn() then
        ScheduleSwap(0.1)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("autoCarrotEnabled", feature)
end
