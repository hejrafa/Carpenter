--[[ Carpenter - ClassHealthColors unit frames ]]
-- Colors player, target, focus, and party health bars by player class.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local ClassHealth = ns.Private.ClassHealthColors or {}

local function IsRetailClient()
    return ClassHealth.IsRetail and ClassHealth.IsRetail()
end

local USE_ATLAS_SIZE = TextureKitConstants and TextureKitConstants.UseAtlasSize
local STATUS_SUFFIX = "-Status"

-- Retail-style health fills are a shaded green atlas, and desaturating it
-- leaves it gray, so a class tint on top comes out darker than Blizzard's own
-- class colors. Each fill has a white "-Status" twin (the heal prediction
-- fill), so class colors are painted on that one instead.
local function AtlasExists(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    return ok and info ~= nil
end

local function GetFillTexture(bar)
    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if texture and texture.GetAtlas and texture.SetAtlas then return texture end
end

local function UseStatusFill(bar)
    local texture = GetFillTexture(bar)
    local atlas = texture and texture:GetAtlas()
    if issecretvalue and issecretvalue(atlas) then return end
    if type(atlas) ~= "string" or atlas:sub(-#STATUS_SUFFIX) == STATUS_SUFFIX then return end

    local statusAtlas = atlas .. STATUS_SUFFIX
    if not AtlasExists(statusAtlas) then return end
    texture:SetAtlas(statusAtlas, USE_ATLAS_SIZE)
    bar._Carpenter_DefaultFillAtlas = atlas
end

local function RestoreDefaultFill(bar)
    local atlas = bar._Carpenter_DefaultFillAtlas
    if not atlas then return end
    bar._Carpenter_DefaultFillAtlas = nil

    -- Blizzard may have set its own art since; only undo the one we swapped in.
    local texture = GetFillTexture(bar)
    if texture and texture:GetAtlas() == atlas .. STATUS_SUFFIX then
        texture:SetAtlas(atlas, USE_ATLAS_SIZE)
    end
end

local function RestoreDefaultUnitColor(bar, unit, force)
    if not bar then return end
    if not force and not bar._Carpenter_IsUnitClassColored then return end

    local wasClassColored = ClassHealth.ClearBarState(bar)
    if IsRetailClient() then
        RestoreDefaultFill(bar)
        if wasClassColored or force then
            bar:SetStatusBarColor(1, 1, 1)
        end
        return
    end

    if not unit or not ClassHealth.UnitExists(unit) then return end

    if UnitFrameHealthBar_Update then
        bar._CarpenterRestoringDefault = true
        pcall(UnitFrameHealthBar_Update, bar, unit)
        bar._CarpenterRestoringDefault = false
        return
    end

    local r, g, b = ClassHealth.GetSelectionColor(unit)
    if r and g and b then
        bar:SetStatusBarColor(r, g, b)
    end
end

local function HookUnitFrameHealthBar(bar, unit)
    if not bar or bar._CarpenterUnitFrameClassColorHooked or not bar.SetStatusBarColor then return end
    if ClassHealth.IsRetail and ClassHealth.IsRetail() then return end
    bar._CarpenterUnitFrameClassColorHooked = true
    bar._CarpenterUnitFrameUnit = unit

    hooksecurefunc(bar, "SetStatusBarColor", function(self)
        local function Recolor()
            if self._CarpenterRestoringDefault or self._CarpenterRecoloring or not ClassHealth.IsUnitFrameEnabled() then return end
            self._CarpenterRecoloring = true
            if not ClassHealth.ApplyUnitFrameClassColor(self, self._CarpenterUnitFrameUnit) then
                RestoreDefaultUnitColor(self, self._CarpenterUnitFrameUnit)
            end
            self._CarpenterRecoloring = false
        end
        if Carpenter and Carpenter.Profile then
            return Carpenter:Profile("ClassHealthColors:SetStatusBarColorHook", Recolor)
        end
        return Recolor()
    end)
end

local Unit = ns.Private.Unit or {}
local PARTY_MEMBER_FRAME_COUNT = 5
local PARTY_HEALTH_ATLAS = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health"
local PARTY_HEALTH_STATUS_ATLAS = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status"
local CHARACTER_PARTY_HEALTH_ATLAS = "UI-HUD-UnitFrame-CharacterFrameOnParty-PortraitOn-Bar-Health"
local CHARACTER_PARTY_HEALTH_STATUS_ATLAS = "UI-HUD-UnitFrame-CharacterFrameOnParty-PortraitOn-Bar-Health-Status"

local function GetPartyMemberFrame(index)
    return PartyFrame and PartyFrame["MemberFrame" .. index]
end

local function GetPartyHealthTexture(member)
    local container = member and member.HealthBarContainer
    local bar = container and container.HealthBar
    return bar and bar.HealthBarTexture
end

local function GetPartyHealthAtlases(member)
    if member.frameType == "CharacterFrameOn" then
        return CHARACTER_PARTY_HEALTH_ATLAS, CHARACTER_PARTY_HEALTH_STATUS_ATLAS
    end
    return PARTY_HEALTH_ATLAS, PARTY_HEALTH_STATUS_ATLAS
end

-- Retail-style party health bars are secure StatusBars: SetStatusBarColor writes
-- restricted state that taints Blizzard's later reads. Blizzard locks their color
-- (lockColor) and only swaps the fill atlas in ToPlayerArt/ToVehicleArt, so tint
-- the fill texture region instead, on the grayscale atlas Blizzard uses for
-- heal prediction fills.
local function RestorePartyMemberColor(member)
    local texture = GetPartyHealthTexture(member)
    if not texture or not texture._Carpenter_PartyClassColored then return end
    texture._Carpenter_PartyClassColored = nil

    texture:SetVertexColor(1, 1, 1)
    -- Vehicle art already replaced the atlas; only undo the one we swapped in.
    if member.state == "player" then
        texture:SetAtlas((GetPartyHealthAtlases(member)), USE_ATLAS_SIZE)
    end
end

local function ApplyPartyMemberColor(member)
    local texture = GetPartyHealthTexture(member)
    if not texture then return end

    local unit = member.unit
    local color = member.state == "player"
        and ClassHealth.IsUnitFrameEnabled()
        and ClassHealth.IsPlayerUnit(unit)
        and ClassHealth.GetClassColor(unit)
    if not color then
        RestorePartyMemberColor(member)
        return
    end

    local _, statusAtlas = GetPartyHealthAtlases(member)
    if texture:GetAtlas() ~= statusAtlas then
        texture:SetAtlas(statusAtlas, USE_ATLAS_SIZE)
    end
    texture:SetVertexColor(color.r, color.g, color.b)
    texture._Carpenter_PartyClassColored = true
end

local function HookPartyMemberArt(member)
    if member._CarpenterPartyClassColorHooked then return end
    member._CarpenterPartyClassColorHooked = true

    local function OnArtChanged(self)
        if self.state ~= "player" then
            RestorePartyMemberColor(self)
            return
        end
        ApplyPartyMemberColor(self)
    end
    for _, method in ipairs({ "ToPlayerArt", "ToCharacterStyleArt", "ToVehicleArt" }) do
        if type(member[method]) == "function" then
            hooksecurefunc(member, method, OnArtChanged)
        end
    end
end

local function GetUnitFrameHealthBar(unit)
    return Unit.FrameHealthBar and Unit.FrameHealthBar(unit) or nil
end

-- Party frames moved around when Edit Mode reached Classic, so try the nested
-- container shapes before falling back to the old globals.
local function GetPartyHealthBar(index)
    local member = PartyFrame and PartyFrame["MemberFrame" .. index]
    if member then
        local container = member.HealthBarsContainer or member.HealthBarContainer
        local bar = (container and (container.HealthBar or container.healthBar))
            or member.HealthBar
            or member.healthBar
            or member.healthbar
        if bar then
            return bar, member.unit or member.displayedUnit
        end
    end

    local legacy = _G["PartyMemberFrame" .. index]
    local bar = _G["PartyMemberFrame" .. index .. "HealthBar"]
        or (legacy and (legacy.HealthBar or legacy.healthBar or legacy.healthbar))
    if bar then
        return bar, "party" .. index
    end
end

local function IsReadable(value)
    return not (issecretvalue and issecretvalue(value))
end

-- Forever hides the target of target's GUID and class from addons, but its
-- class still feeds C_ClassColor, and the health bar accepts the resulting
-- hidden color. That marks the bar's color and alpha as hidden values, so it
-- is only used for this one bar and only when the class can't be read.
local function ApplyHiddenClassColor(bar, unit)
    if not (C_ClassColor and C_ClassColor.GetClassColor and UnitIsPlayer and UnitClass) then return false end

    local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
    if not okPlayer or not IsReadable(isPlayer) or isPlayer ~= true then return false end

    local ok = pcall(function()
        local _, classToken = UnitClass(unit)
        local color = C_ClassColor.GetClassColor(classToken)
        local r, g, b = color:GetRGB()
        if bar.SetStatusBarDesaturated then
            bar:SetStatusBarDesaturated(true)
        end
        bar:SetStatusBarColor(r, g, b)
    end)
    if ok then
        bar._Carpenter_IsUnitClassColored = true
        UseStatusFill(bar)
    end
    return ok
end

local function UpdateHealthBarColor(bar, unit)
    if not bar then return end
    if not ClassHealth.IsUnitFrameEnabled() then return end
    if not unit or not ClassHealth.UnitExists(unit) then
        RestoreDefaultUnitColor(bar, unit, true)
        return
    end
    if not ClassHealth.IsPlayerUnit(unit) then
        if IsRetailClient() and unit == "targettarget" and ApplyHiddenClassColor(bar, unit) then
            return
        end
        RestoreDefaultUnitColor(bar, unit, true)
        return
    end

    if IsRetailClient() then
        if ClassHealth.ApplyUnitFrameClassColor(bar, unit) then
            UseStatusFill(bar)
        else
            RestoreDefaultUnitColor(bar, unit, true)
        end
        return
    end

    HookUnitFrameHealthBar(bar, unit)
    if not ClassHealth.ApplyUnitFrameClassColor(bar, unit) then
        RestoreDefaultUnitColor(bar, unit, true)
    end
end

local function UpdatePartyHealthBarColor(bar, unit)
    if IsRetailClient() then return end
    UpdateHealthBarColor(bar, unit)
end

local function RefreshPartyFrameColors(onlyUnit)
    for i = 1, PARTY_MEMBER_FRAME_COUNT do
        if IsRetailClient() then
            local member = GetPartyMemberFrame(i)
            if member and GetPartyHealthTexture(member) and (not onlyUnit or member.unit == onlyUnit) then
                HookPartyMemberArt(member)
                ApplyPartyMemberColor(member)
            end
        else
            local partyBar, partyUnit = GetPartyHealthBar(i)
            if partyBar and (not onlyUnit or partyUnit == onlyUnit) then
                UpdatePartyHealthBarColor(partyBar, partyUnit)
            end
        end
    end
end

local function RefreshUnitFrameColors()
    UpdateHealthBarColor(GetUnitFrameHealthBar("player"), "player")
    UpdateHealthBarColor(GetUnitFrameHealthBar("target"), "target")
    UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
    UpdateHealthBarColor(GetUnitFrameHealthBar("focus"), "focus")

    RefreshPartyFrameColors()
end

-- Retail-style clients repaint these bars green in UnitFrameHealthBar_Update.
-- Target of target runs that every frame from OnUpdate, so recolor right
-- after Blizzard instead of waiting for the next event. Party bars are tinted
-- through their texture and never pass through here.
local UNIT_FRAME_UNITS = { "player", "target", "targettarget", "focus" }
local healthBarUpdateHooked = false

local function HookBlizzardHealthBarUpdates()
    if healthBarUpdateHooked or not IsRetailClient() or type(UnitFrameHealthBar_Update) ~= "function" then return end
    healthBarUpdateHooked = true

    -- Target and focus reset their fill atlas after the health update whenever
    -- the unit changes, so swap it back afterwards.
    for _, entry in ipairs({ { TargetFrame, "target" }, { FocusFrame, "focus" } }) do
        local frame, unit = entry[1], entry[2]
        if frame and type(frame.UpdateHealthBarVisuals) == "function" then
            hooksecurefunc(frame, "UpdateHealthBarVisuals", function()
                local bar = GetUnitFrameHealthBar(unit)
                if bar and ClassHealth.IsUnitFrameEnabled()
                    and (bar._Carpenter_IsUnitClassColored or ClassHealth.IsPlayerUnit(unit)) then
                    UpdateHealthBarColor(bar, unit)
                end
            end)
        end
    end

    hooksecurefunc("UnitFrameHealthBar_Update", function(bar)
        if not bar or not ClassHealth.IsUnitFrameEnabled() then return end
        for _, unit in ipairs(UNIT_FRAME_UNITS) do
            if bar == GetUnitFrameHealthBar(unit) then
                -- NPC bars stay Blizzard's unless Carpenter colored them before.
                if bar._Carpenter_IsUnitClassColored or ClassHealth.IsPlayerUnit(unit) then
                    UpdateHealthBarColor(bar, unit)
                end
                return
            end
        end
    end)
end

local unitFrameDriver = CreateFrame("Frame")
unitFrameDriver:Hide()

local function HandleUnitFrameEvent(self, event, unit)
    if not ClassHealth.IsUnitFrameEnabled() then return end

    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        RefreshUnitFrameColors()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, RefreshUnitFrameColors)
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        RefreshUnitFrameColors()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, RefreshUnitFrameColors)
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
        if unit == "target" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("target"), "target")
            UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
        elseif unit == "targettarget" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
        elseif unit == "focus" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("focus"), "focus")
        elseif unit == "player" then
            UpdateHealthBarColor(GetUnitFrameHealthBar("player"), "player")
            RefreshPartyFrameColors("player")
        elseif unit and unit:find("party") then
            RefreshPartyFrameColors(unit)
        end
    elseif event == "UNIT_TARGET" and unit == "target" then
        UpdateHealthBarColor(GetUnitFrameHealthBar("targettarget"), "targettarget")
    elseif event == "GROUP_ROSTER_UPDATE" then
        RefreshUnitFrameColors()
    end
end

unitFrameDriver:SetScript("OnEvent", function(...)
    if Carpenter and Carpenter.Profile then
        return Carpenter:Profile("ClassHealthColors:UnitFrames", HandleUnitFrameEvent, ...)
    end
    return HandleUnitFrameEvent(...)
end)

local unitFrameFeature = {}

function unitFrameFeature:Enable()
    unitFrameDriver:RegisterEvent("PLAYER_TARGET_CHANGED")
    unitFrameDriver:RegisterEvent("PLAYER_FOCUS_CHANGED")
    unitFrameDriver:RegisterUnitEvent("UNIT_HEALTH", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_FLAGS", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_FACTION", "player", "target", "targettarget", "focus", "party1", "party2", "party3", "party4")
    unitFrameDriver:RegisterUnitEvent("UNIT_TARGET", "target")
    unitFrameDriver:RegisterEvent("GROUP_ROSTER_UPDATE")
    unitFrameDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
    unitFrameDriver:Show()
    HookBlizzardHealthBarUpdates()
    RefreshUnitFrameColors()
end

function unitFrameFeature:Disable()
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("player"), "player", true)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("target"), "target", true)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("targettarget"), "targettarget", true)
    RestoreDefaultUnitColor(GetUnitFrameHealthBar("focus"), "focus", true)

    for i = 1, PARTY_MEMBER_FRAME_COUNT do
        if IsRetailClient() then
            RestorePartyMemberColor(GetPartyMemberFrame(i))
        else
            local partyBar, partyUnit = GetPartyHealthBar(i)
            RestoreDefaultUnitColor(partyBar, partyUnit, true)
        end
    end

    unitFrameDriver:UnregisterAllEvents()
    unitFrameDriver:Hide()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("classHealthColorsEnabled", unitFrameFeature)
end
