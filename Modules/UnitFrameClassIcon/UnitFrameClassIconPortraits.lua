--[[ Carpenter - Unit Frame Class Icon portrait lookup ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Unit = ns.Private.Unit or {}
local ClassIcon = ns.Private.UnitFrameClassIcon or {}
ns.Private.UnitFrameClassIcon = ClassIcon

local CLASS_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"

local FALLBACK_TCOORDS = {
    WARRIOR = { 0, 1/3, 0, 1/3 },
    PALADIN = { 1/3, 2/3, 0, 1/3 },
    HUNTER = { 2/3, 1, 0, 1/3 },
    ROGUE = { 0, 1/3, 1/3, 2/3 },
    PRIEST = { 1/3, 2/3, 1/3, 2/3 },
    SHAMAN = { 2/3, 1, 1/3, 2/3 },
    MAGE = { 0, 1/3, 2/3, 1 },
    WARLOCK = { 1/3, 2/3, 2/3, 1 },
    DRUID = { 2/3, 1, 2/3, 1 },
}

function ClassIcon.IsEnabled()
    return Carpenter and Carpenter:IsEnabled("unitFrameClassIconEnabled")
end

function ClassIcon.GetClassTexCoords(class)
    if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
        local coords = CLASS_ICON_TCOORDS[class]
        return coords[1], coords[2], coords[3], coords[4]
    end

    local coords = FALLBACK_TCOORDS[class]
    if coords then
        return coords[1], coords[2], coords[3], coords[4]
    end

    return nil
end

function ClassIcon.SetClassIconOnTexture(texture, class)
    if not texture or not class or not texture.SetTexture then return false end

    local left, right, top, bottom = ClassIcon.GetClassTexCoords(class)
    if not left then return false end

    texture:SetTexture(CLASS_ICON_TEXTURE)
    texture:SetTexCoord(left, right, top, bottom)
    return true
end

function ClassIcon.ShouldShow(unit)
    if not ClassIcon.IsEnabled() then return false end
    if unit == "player" then return true end

    if (unit == "target" or unit == "focus" or unit == "targettarget") and Unit.IsPlayer and Unit.IsPlayer(unit) then
        return true
    end

    return false
end

function ClassIcon.FindPortraitRegion(frame)
    if not frame or not frame.GetRegions then return nil end

    for index = 1, frame:GetNumRegions() do
        local region = select(index, frame:GetRegions())
        local name = region and region.GetName and region:GetName()
        if name and name:find("Portrait") and region.SetTexture then
            return region
        end
    end

    return nil
end

function ClassIcon.GetPortraitAndParent(unit)
    local portrait
    if unit == "player" then
        portrait = PlayerPortrait
            or (PlayerFrame and (PlayerFrame.portrait or PlayerFrame.Portrait))
            or ClassIcon.FindPortraitRegion(PlayerFrame)
    elseif unit == "target" then
        portrait = TargetFramePortrait
            or (TargetFrame and (TargetFrame.portrait or TargetFrame.Portrait))
            or ClassIcon.FindPortraitRegion(TargetFrame)
    elseif unit == "focus" then
        portrait = _G.FocusFramePortrait
            or (_G.FocusFrame and (_G.FocusFrame.portrait or _G.FocusFrame.Portrait))
            or ClassIcon.FindPortraitRegion(_G.FocusFrame)
    elseif unit == "targettarget" then
        portrait = _G.TargetFrameToTPortrait
            or _G.TargetofTargetPortrait
            or _G.TargetOfTargetPortrait
            or (_G.TargetFrameToT and (_G.TargetFrameToT.portrait or _G.TargetFrameToT.Portrait))
            or ClassIcon.FindPortraitRegion(_G.TargetFrameToT)
    end

    if not portrait then return nil, nil end

    local unitFrame = (unit == "player" and PlayerFrame)
        or (unit == "target" and TargetFrame)
        or (unit == "focus" and _G.FocusFrame)
        or (unit == "targettarget" and (_G.TargetFrameToT or _G.TargetofTargetFrame or _G.TargetOfTargetFrame))
    local parent = portrait.GetParent and portrait:GetParent() or unitFrame or UIParent
    if not parent or not parent.CreateFrame then
        parent = unitFrame or UIParent
    end

    return portrait, parent
end

function ClassIcon.IsTargetTargetPortrait(texture)
    if not texture then return false end

    local targetTargetFrame = _G.TargetFrameToT
    return texture == _G.TargetFrameToTPortrait
        or texture == _G.TargetofTargetPortrait
        or texture == _G.TargetOfTargetPortrait
        or (targetTargetFrame and (
            texture == targetTargetFrame.portrait
            or texture == targetTargetFrame.Portrait
            or texture == ClassIcon.FindPortraitRegion(targetTargetFrame)
        ))
end
