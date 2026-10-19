--[[ Carpenter - Forever Unit Frame Auras ]]
-- WoW Forever hides auras from addons in combat, so Classic's big crowd
-- control portrait icon is rebuilt on the game's AuraContainer: each unit
-- frame gets one aura slot that the game fills securely with the longest
-- crowd control on that unit. Carpenter only sets the filter, position, and
-- style. The round icon sits over the portrait, inside the portrait ring, and
-- the game hides it again when the crowd control ends.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Nameplates = ns.Private.Nameplates or {}

local FEATURE_KEY = "unitFrameDebuffsEnabled"

local CROWD_CONTROL_FILTER = "HARMFUL|CROWD_CONTROL"
local PARTY_MEMBER_COUNT = 4
local FALLBACK_PORTRAIT_SIZE = 60
-- Keeps the icon inside the portrait ring, which overlaps the portrait edge.
local PORTRAIT_INSET = 2
local DURATION_TEXT_SIZE = 24
local DURATION_TEXT_SIZE_PARTY = 14

local ICON_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SWIPE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

local containersByUnit = {}

local function IsSupported()
    return Enum and Enum.CustomAuraButtonDispelTypeTextureStyle ~= nil
        and AuraContainerSortMethod ~= nil and AuraContainerSortDirection ~= nil
end

-- =========================
-- Unit frames
-- =========================
local function GetPartyMember(index)
    return PartyFrame and PartyFrame["MemberFrame" .. index]
end

-- Unit -> the frame that owns the portrait, and the portrait texture.
local function GetPortrait(unit)
    if unit == "player" then
        local container = PlayerFrame and PlayerFrame.PlayerFrameContainer
        return container, container and container.PlayerPortrait
    elseif unit == "target" or unit == "focus" then
        local frame = unit == "target" and TargetFrame or FocusFrame
        local container = frame and frame.TargetFrameContainer
        return container, container and container.Portrait
    end

    local index = tonumber(unit:match("^party(%d)$"))
    local member = index and GetPartyMember(index)
    return member, member and member.Portrait
end

local function GetUnits()
    local units = { "player", "target", "focus" }
    for i = 1, PARTY_MEMBER_COUNT do
        units[#units + 1] = "party" .. i
    end
    return units
end

local function GetPortraitSize(portrait)
    local ok, width = pcall(portrait.GetWidth, portrait)
    if ok and type(width) == "number" and width > 0 then return width end
    return FALLBACK_PORTRAIT_SIZE
end

-- =========================
-- Aura slot
-- =========================
local function CreateIconInitializer(size, textSize)
    return function(button)
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("CENTER")

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local mask = button:CreateMaskTexture()
        mask:SetTexture(ICON_MASK)
        mask:SetAllPoints(button)
        icon:AddMaskTexture(mask)
        button:SetIcon(icon)

        -- Round swipe, like the Classic portrait icon.
        local cooldown = CreateFrame("Cooldown", nil, button)
        cooldown:SetAllPoints(button)
        cooldown:SetReverse(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetSwipeTexture(SWIPE_TEXTURE)
        cooldown:SetSwipeColor(0, 0, 0, 0.6)
        cooldown:SetHideCountdownNumbers(true)
        button:SetDurationCooldown(cooldown)

        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints(button)
        overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)

        local durationText = overlay:CreateFontString(nil, "OVERLAY")
        durationText:SetPoint("CENTER", button, "CENTER", 0, 0)
        Nameplates.StyleAuraText(durationText, textSize)
        local formatter = Nameplates.GetAuraDurationFormatter and Nameplates.GetAuraDurationFormatter()
        button:SetDurationText(durationText, formatter and { textFormatter = formatter } or nil)
    end
end

local function CreateContainer(unit)
    local parent, portrait = GetPortrait(unit)
    if not parent or not portrait then return nil end

    -- Same level as the portrait's frame, so the icon draws over the portrait
    -- like the frame's own children do, while the level badge one level up
    -- (TargetFrameContentMain on the target and focus frames) stays on top.
    -- The inset keeps the portrait ring visible.
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetFrameLevel(parent:GetFrameLevel())
    container:SetPoint("CENTER", portrait, "CENTER")

    local size = GetPortraitSize(portrait) - PORTRAIT_INSET * 2
    local textSize = unit:match("^party") and DURATION_TEXT_SIZE_PARTY or DURATION_TEXT_SIZE
    -- Longest remaining crowd control wins, as on Classic.
    container:AddAuraSlot("crowdControl", CROWD_CONTROL_FILTER, {
        initializeFrame = CreateIconInitializer(size, textSize),
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
    })
    return container
end

local function GetContainer(unit)
    local container = containersByUnit[unit]
    if container == nil then
        local ok, created = pcall(CreateContainer, unit)
        container = ok and created or false
        containersByUnit[unit] = container
    end
    return container or nil
end

-- The container follows its unit token's auras, but not a new unit behind the
-- same token (a new target, focus, or party member), so refresh it then.
local function RefreshUnit(unit)
    local container = containersByUnit[unit]
    if container then
        container:UpdateAllAuras()
    end
end

local function RefreshParty()
    for i = 1, PARTY_MEMBER_COUNT do
        RefreshUnit("party" .. i)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        RefreshUnit("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        RefreshUnit("focus")
    elseif event == "GROUP_ROSTER_UPDATE" then
        RefreshParty()
    end
end)

local feature = {}

function feature:Enable()
    if not IsSupported() then return end
    for _, unit in ipairs(GetUnits()) do
        local container = GetContainer(unit)
        if container then
            container:SetUnit(unit)
            container:Show()
        end
    end
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function feature:Disable()
    eventFrame:UnregisterAllEvents()
    for _, container in pairs(containersByUnit) do
        if container then
            container:SetUnit("none")
            container:Hide()
        end
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
