--[[ Carpenter - safe unit helpers ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Unit = ns.Private.Unit or {}
ns.Private.Unit = Unit

local function CanAccessValue(value)
    if canaccessvalue then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok and accessible == false then
            return false
        end
    end
    return true
end

function Unit.IsToken(value)
    local ok, isToken = pcall(function()
        return CanAccessValue(value) and type(value) == "string" and value ~= ""
    end)
    return ok and isToken == true
end

function Unit.Exists(unit)
    if not Unit.IsToken(unit) or not UnitExists then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and exists == true
end

function Unit.GUID(unit)
    if not Unit.Exists(unit) or not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok then return nil end
    local prefixOk, accessibleGuid = pcall(function()
        return CanAccessValue(guid) and type(guid) == "string" and guid or nil
    end)
    if prefixOk then return accessibleGuid end
    return nil
end

function Unit.IsPlayer(unit)
    if not Unit.Exists(unit) or not UnitIsPlayer then return false end

    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or not isPlayer then return false end
    if not UnitGUID then return true end

    local guid = Unit.GUID(unit)
    local prefixOk, isPlayerGuid = pcall(function()
        return type(guid) == "string" and guid:sub(1, 7) == "Player-"
    end)
    return prefixOk and isPlayerGuid == true
end

function Unit.IsPlayerControlled(unit)
    if not Unit.Exists(unit) or not UnitPlayerControlled then return false end
    local ok, controlled = pcall(UnitPlayerControlled, unit)
    return ok and controlled == true
end

function Unit.IsPartyUnit(unit)
    if not Unit.IsToken(unit) then return false end
    local ok, isParty = pcall(function()
        return unit:match("^party%d$") ~= nil
    end)
    return ok and isParty == true
end

function Unit.IsNPCPartyUnit(unit)
    return Unit.IsPartyUnit(unit) and Unit.Exists(unit) and not Unit.IsPlayer(unit)
end

function Unit.Class(unit)
    if not Unit.IsPlayer(unit) or not UnitClass then return nil, nil end
    local ok, className, classToken = pcall(UnitClass, unit)
    if ok then return className, classToken end
    return nil, nil
end

function Unit.ClassColor(unit)
    local _, classToken = Unit.Class(unit)
    return classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] or nil
end

function Unit.SelectionColor(unit)
    if not Unit.Exists(unit) or not UnitSelectionColor then return nil, nil, nil end
    local ok, r, g, b = pcall(UnitSelectionColor, unit)
    if ok then return r, g, b end
    return nil, nil, nil
end
