--[[ Carpenter - Raid Target Icon Aligned ]]
-- When nameplates are enabled, the default raid target icons float too high.
-- This module re-anchors them: vertically centered on the nameplate bar, to the left of it.

local _, ns = ...
local Nameplates = ns and ns.Private and ns.Private.Nameplates or {}

local function isEnabled()
    return Carpenter and Carpenter:IsEnabled("raidTargetIconAlignedEnabled")
end

-- Find the raid target frame/texture on a nameplate (structure can vary by client)
local function findRaidTargetFrame(plate)
    if not plate then return nil end
    local uf = plate.UnitFrame
    if not uf then return nil end
    -- Common Blizzard names
    if uf.RaidTargetFrame then return uf.RaidTargetFrame end
    if uf.RaidTargetIcon then return uf.RaidTargetIcon end
    if plate.RaidTargetFrame then return plate.RaidTargetFrame end
    if plate.RaidTargetIcon then return plate.RaidTargetIcon end
    -- Scan children for a frame that looks like the raid target (often has RaidTargetIcon as texture child)
    for i = 1, select("#", uf:GetChildren()) do
        local child = select(i, uf:GetChildren())
        local name = child and child.GetName and child:GetName()
        if name and (name:find("RaidTarget") or name:find("Raid target")) then
            return child
        end
    end
    return nil
end

local GAP = 4 -- pixels between icon and nameplate bar

local function alignRaidTargetIcon(plate)
    if not isEnabled() then return end

    local rtFrame = findRaidTargetFrame(plate)
    if not rtFrame then return end

    local healthBar = (plate.UnitFrame and (plate.UnitFrame.healthBar or plate.UnitFrame.HealthBar)) or plate.healthBar or plate.HealthBar
    local rel = healthBar or (plate.UnitFrame or plate)
    -- Icon to the left of the nameplate bar, vertically centered on the bar
    rtFrame:ClearAllPoints()
    rtFrame:SetPoint("RIGHT", rel, "LEFT", -GAP, 2)
end

local function setupPlate(plate, unit)
    if not plate or not unit then return end
    -- Run after Blizzard has laid out the nameplate (next frame)
    C_Timer.After(0, function()
        if not plate:IsShown() then return end
        alignRaidTargetIcon(plate)
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("RAID_TARGET_UPDATE")

frame:SetScript("OnEvent", function(self, event, unit)
    if not isEnabled() then return end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            for _, plate in pairs((Nameplates.GetAll and Nameplates.GetAll()) or {}) do
                local plateUnit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if plateUnit then
                    setupPlate(plate, plateUnit)
                end
            end
        end)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local plate = Nameplates.GetForUnit and Nameplates.GetForUnit(unit)
        if plate then
            setupPlate(plate, unit)
        end
    elseif event == "RAID_TARGET_UPDATE" then
        -- Blizzard may reposition when marks change; re-apply alignment
        C_Timer.After(0, function()
            for _, plate in pairs((Nameplates.GetAll and Nameplates.GetAll()) or {}) do
                if plate:IsShown() then
                    alignRaidTargetIcon(plate)
                end
            end
        end)
    end
end)
