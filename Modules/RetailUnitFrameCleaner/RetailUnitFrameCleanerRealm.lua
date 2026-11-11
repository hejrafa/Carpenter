--[[ Carpenter - Retail Unit Frame Cleaner realm indicator text ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Realm = ns.Private.RetailUnitFrameCleanerRealm or {}
ns.Private.RetailUnitFrameCleanerRealm = Realm

local Targets = ns.Private.RetailUnitFrameCleanerTargets or {}
local Nameplates = ns.Private.Nameplates or {}

local function StripRealmIndicator(text)
    if type(text) ~= "string" then return text, false end
    local stripped = text:gsub(" %(%*%)$", "")
    return stripped, stripped ~= text
end

local function CleanRealmFontString(fontString)
    if not fontString or not fontString.GetText or not fontString.SetText then return end

    local ok, stripped, changed = pcall(function()
        local text = fontString:GetText()
        return StripRealmIndicator(text)
    end)
    if not ok or not changed then return end

    fontString:SetText(stripped)
end

function Realm.Apply(predicate)
    for _, fontString in ipairs(Targets.GetRealmIndicatorNameStrings()) do
        if predicate() then
            CleanRealmFontString(fontString)
        end
    end
end

function Realm.ApplyForUnit(unit, predicate)
    if not predicate() then return end

    local strings = {}
    if unit == "player" then
        Targets.AddUnitFrameNameStrings(strings, PlayerFrame)
        Targets.AddNameString(strings, PlayerName)
    elseif unit == "target" then
        Targets.AddUnitFrameNameStrings(strings, TargetFrame)
        Targets.AddUnitFrameNameStrings(strings, TargetFrameToT)
        Targets.AddNameString(strings, TargetFrameTextureFrameName)
    elseif unit == "focus" then
        Targets.AddUnitFrameNameStrings(strings, FocusFrame)
        Targets.AddUnitFrameNameStrings(strings, FocusFrameToT)
        Targets.AddNameString(strings, FocusFrameTextureFrameName)
    end

    do
        local plate = Nameplates.GetForUnit and Nameplates.GetForUnit(unit)
        if plate and plate.UnitFrame then
            Targets.AddNameString(strings, plate.UnitFrame.name)
            Targets.AddNameString(strings, plate.UnitFrame.Name)
            Targets.AddNameString(strings, plate.UnitFrame.NameText)
        end
    end

    for _, fontString in ipairs(strings) do
        CleanRealmFontString(fontString)
    end
end
