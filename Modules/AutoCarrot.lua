--[[ Carpenter - Mount Speed Trinket ]]
-- Automatically equips a mount speed trinket (Riding Crop 10% or Carrot on a Stick 3%) when mounting; prefers Crop if both in bags.

-- Item IDs, ordered by priority (best first): Riding Crop 10%, Carrot on a Stick 3%
local RIDING_CROP_ID = 25653
local CARROT_ID = 11122
local MOUNT_SPEED_TRINKET_IDS = { [RIDING_CROP_ID] = true, [CARROT_ID] = true }
local MOUNT_SPEED_PRIORITY = { RIDING_CROP_ID, CARROT_ID }

local previousTrinketID = nil
local lastSwapTime = 0
local pendingSwapBack = false

local function IsEnabled()
    return CarpenterDB and CarpenterDB.autoCarrotEnabled
end

local function GetTargetSlot()
    return (CarpenterDB and CarpenterDB.autoCarrotSlot) or 13
end

local function IsMountSpeedTrinket(itemID)
    return itemID and MOUNT_SPEED_TRINKET_IDS[itemID]
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

-- Returns bag, slot for the best mount speed trinket in bags (Crop preferred over Carrot). Only returns trinkets the player can use. Riding Crop is only considered when soulbound; tradeable Crops are skipped and we fall back to Carrot.
local function GetBestMountSpeedTrinketInBags()
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID

    for _, preferredID in ipairs(MOUNT_SPEED_PRIORITY) do
        if not CanUseTrinket(preferredID) then
            -- e.g. Riding Crop req 69 and we're not there yet - skip to next
        else
            for bag = 0, 4 do
                local numSlots = getNumSlots(bag)
                if numSlots then
                    for slot = 1, numSlots do
                        if getItemID(bag, slot) == preferredID then
                            if preferredID == RIDING_CROP_ID then
                                if IsContainerItemSoulbound(bag, slot) then
                                    return bag, slot, preferredID
                                end
                                -- skip this Crop (not soulbound), try other bags or fall back to Carrot
                            else
                                return bag, slot, preferredID
                            end
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
    if now - lastSwapTime < 0.5 then return end

    local isMounted = IsMounted()
    local isFlying = (IsFlyableArea() and IsFlying()) or UnitOnTaxi("player")
    local currentTrinketAtTarget = GetInventoryItemID("player", targetSlot)

    -- Logic for equipping best mount speed trinket (Crop preferred, then Carrot)
    if isMounted and not isFlying then
        if not IsMountSpeedTrinket(GetInventoryItemID("player", 13)) and not IsMountSpeedTrinket(GetInventoryItemID("player", 14)) then
            local bag, slot = GetBestMountSpeedTrinketInBags()
            if bag and slot then
                previousTrinketID = currentTrinketAtTarget

                if C_Container and C_Container.PickupContainerItem then
                    C_Container.PickupContainerItem(bag, slot)
                else
                    PickupContainerItem(bag, slot)
                end

                EquipCursorItem(targetSlot)
                lastSwapTime = now
                pendingSwapBack = false
            end
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")

frame:SetScript("OnEvent", function(self, event, unit)
    if (event == "UNIT_AURA" or event == "UNIT_MODEL_CHANGED") and unit ~= "player" then return end
    SwapTrinket()
end)

-- Polling ticker as a safety net for cases where events might be missed (e.g., forced dismounts)
C_Timer.NewTicker(1.0, SwapTrinket)
