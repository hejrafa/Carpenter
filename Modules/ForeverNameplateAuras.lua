--[[ Carpenter - Forever Nameplate Auras ]]
-- WoW Forever hides enemy auras from addons in combat, so this uses the game's
-- own AuraContainer: the game fills each icon securely and Carpenter only sets
-- filters, layout, and style. Crowd control and your debuffs share one row
-- above enemy nameplates, centered and outlined by debuff type like the target
-- frame. Blizzard's own debuff, crowd control, and loss of control lists are
-- hidden on those plates so nothing shows twice.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Nameplates = ns.Private.Nameplates or {}

local FEATURE_KEY = "debuffTrackerEnabled"

local ICON_SIZE = 22
local ICON_SPACING = 2
local ICONS_PER_LINE = 6
local CROWD_CONTROL_MAX = 2
local DEBUFF_MAX = 8
local FALLBACK_GAP = 4

-- Same outline the target frame uses for its debuffs; the game tints it by
-- debuff type.
local BORDER_TEXTURE = "Interface\\Buttons\\UI-Debuff-Overlays"
local BORDER_TEX_COORDS = { 0.296875, 0.5703125, 0, 0.515625 }

local CROWD_CONTROL_FILTER = "HARMFUL|CROWD_CONTROL"
local DEBUFF_FILTER = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL"

local containersByUnitFrame = {}
local managedUnitFrames = {}
local hookedUnitFrames = {}
local hookedLists = {}
local blizzardWantsShown = {}
local suppressingList = false

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

local function IsSupported()
    return C_NamePlate and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle ~= nil
end

local function IsHostile(unit)
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    if not ok or (issecretvalue and issecretvalue(canAttack)) then return false end
    return canAttack == true
end

-- =========================
-- Aura buttons
-- =========================
local function InitializeAuraButton(button)
    button:SetSize(ICON_SIZE, ICON_SIZE)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetIcon(icon)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetReverse(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    cooldown:SetHideCountdownNumbers(true)
    button:SetDurationCooldown(cooldown)

    -- Stack count and outline sit above the cooldown swipe.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)

    local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    button:SetApplicationCount(count)

    local border = overlay:CreateTexture(nil, "OVERLAY")
    border:SetTexture(BORDER_TEXTURE)
    border:SetTexCoord(unpack(BORDER_TEX_COORDS))
    border:SetAllPoints(button)
    button:AddDispelTypeTexture(border, {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
    })
end

-- =========================
-- Containers
-- =========================
local function GetAurasFrame(unitFrame)
    return unitFrame and unitFrame.AurasFrame
end

-- Reuse the vertical anchor Blizzard gives its own debuff row (above the name
-- or the health bar, depending on the nameplate style), but center on it.
local function AnchorContainer(unitFrame, container)
    local relativeTo, relativePoint, offsetY
    local aurasFrame = GetAurasFrame(unitFrame)
    local debuffList = aurasFrame and aurasFrame.DebuffListFrame
    if debuffList then
        for index = 1, debuffList:GetNumPoints() do
            local point, pointRelativeTo, pointRelativePoint, _, pointOffsetY = debuffList:GetPoint(index)
            if point == "BOTTOM" then
                relativeTo, relativePoint, offsetY = pointRelativeTo, pointRelativePoint, pointOffsetY
                break
            end
        end
    end

    if not relativeTo then
        relativeTo = unitFrame.HealthBarsContainer or Nameplates.GetHealthBar(unitFrame) or unitFrame
        relativePoint, offsetY = "TOP", FALLBACK_GAP
    end

    container:ClearAllPoints()
    container:SetPoint("BOTTOM", relativeTo, relativePoint or "TOP", 0, offsetY or FALLBACK_GAP)
end

local function CreateContainer(unitFrame)
    local container = CreateFrame("AuraContainer", nil, unitFrame, "CustomAuraContainerTemplate")
    container:SetFrameLevel(unitFrame:GetFrameLevel() + 20)

    -- Elements fill from the bottom-left of a container that resizes to fit
    -- them; anchoring the container by its bottom center keeps the row centered.
    container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    container:SetFlowLayoutMaximumLineSize(ICONS_PER_LINE * (ICON_SIZE + ICON_SPACING))

    container:AddAuraGroup("crowdControl", CROWD_CONTROL_FILTER, {
        maxFrameCount = CROWD_CONTROL_MAX,
        initializeFrame = InitializeAuraButton,
        layout = { elementSpacing = ICON_SPACING, lineSpacing = ICON_SPACING, groupSpacing = ICON_SPACING, layoutIndex = 1 },
    })
    container:AddAuraGroup("debuffs", DEBUFF_FILTER, {
        maxFrameCount = DEBUFF_MAX,
        initializeFrame = InitializeAuraButton,
        layout = { elementSpacing = ICON_SPACING, lineSpacing = ICON_SPACING, groupSpacing = ICON_SPACING, layoutIndex = 2 },
    })

    return container
end

local function GetContainer(unitFrame)
    local container = containersByUnitFrame[unitFrame]
    if container == nil then
        local ok, created = pcall(CreateContainer, unitFrame)
        container = ok and created or false
        containersByUnitFrame[unitFrame] = container
    end
    return container or nil
end

-- =========================
-- Blizzard's own lists
-- =========================
local function ShouldSuppressList(list)
    return IsEnabled() and managedUnitFrames[hookedLists[list]] == true
end

local function SuppressList(list)
    suppressingList = true
    list:Hide()
    suppressingList = false
end

local function HookList(unitFrame, list)
    if not list or hookedLists[list] then return end
    hookedLists[list] = unitFrame
    blizzardWantsShown[list] = list:IsShown()

    hooksecurefunc(list, "SetShown", function(self, shown)
        blizzardWantsShown[self] = shown and true or false
        if shown and ShouldSuppressList(self) then SuppressList(self) end
    end)
    hooksecurefunc(list, "Show", function(self)
        blizzardWantsShown[self] = true
        if ShouldSuppressList(self) then SuppressList(self) end
    end)
    hooksecurefunc(list, "Hide", function(self)
        if not suppressingList then blizzardWantsShown[self] = false end
    end)
end

local function GetManagedLists(unitFrame)
    local aurasFrame = GetAurasFrame(unitFrame)
    if not aurasFrame then return {} end
    return { aurasFrame.DebuffListFrame, aurasFrame.CrowdControlListFrame, aurasFrame.LossOfControlFrame }
end

local function SetBlizzardListsSuppressed(unitFrame, suppressed)
    for _, list in ipairs(GetManagedLists(unitFrame)) do
        HookList(unitFrame, list)
        if suppressed then
            if list:IsShown() then SuppressList(list) end
        elseif blizzardWantsShown[list] and not list:IsShown() then
            list:Show()
        end
    end
end

-- =========================
-- Nameplate lifecycle
-- =========================
local function Detach(unitFrame)
    if not unitFrame then return end
    managedUnitFrames[unitFrame] = nil
    local container = containersByUnitFrame[unitFrame]
    if container then
        container:SetUnit("none")
        container:Hide()
    end
    SetBlizzardListsSuppressed(unitFrame, false)
end

local function Attach(unit)
    local plate = Nameplates.GetForUnit and Nameplates.GetForUnit(unit)
    local unitFrame = plate and plate.UnitFrame
    if not unitFrame then return end

    if not IsHostile(unit) then
        Detach(unitFrame)
        return
    end

    local container = GetContainer(unitFrame)
    if not container then return end

    if not hookedUnitFrames[unitFrame] and unitFrame.UpdateAnchors then
        hookedUnitFrames[unitFrame] = true
        hooksecurefunc(unitFrame, "UpdateAnchors", function(self)
            local ownContainer = containersByUnitFrame[self]
            if ownContainer and managedUnitFrames[self] then
                AnchorContainer(self, ownContainer)
            end
        end)
    end

    managedUnitFrames[unitFrame] = true
    AnchorContainer(unitFrame, container)
    container:SetUnit(unit)
    container:Show()
    SetBlizzardListsSuppressed(unitFrame, true)
end

local function DetachUnit(unit)
    local plate = Nameplates.GetForUnit and Nameplates.GetForUnit(unit)
    Detach(plate and plate.UnitFrame)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Attach(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        DetachUnit(unit)
    elseif event == "UNIT_FACTION" and type(unit) == "string" and unit:match("^nameplate%d+$") then
        Attach(unit)
    end
end)

local function AttachAll()
    for _, plate in ipairs(Nameplates.GetAll and Nameplates.GetAll() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then Attach(unit) end
    end
end

local feature = {}

function feature:Enable()
    if not IsSupported() then return end
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("UNIT_FACTION")
    AttachAll()
end

function feature:Disable()
    eventFrame:UnregisterAllEvents()
    for unitFrame in pairs(containersByUnitFrame) do
        Detach(unitFrame)
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
