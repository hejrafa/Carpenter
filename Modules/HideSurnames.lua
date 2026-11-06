--[[ Carpenter - Hide Secondary Names ]]
-- WoW Forever gives every character a surname, and its GetUnitName always
-- adds it. This shows first names only on unit frames, party and raid frames,
-- and nameplates. Tooltips build their own name line, so they keep the full
-- name. Blizzard writes those names in UnitFrame_Update and
-- CompactUnitFrame_UpdateName; both are post-hooked, so nothing is tainted.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local FEATURE_KEY = "hideSurnamesEnabled"

local Nameplates = ns.Private.Nameplates or {}

local HideSurnames = {}
ns.Private.HideSurnames = HideSurnames

-- The name Blizzard last wrote to each font string we shortened, put back when
-- the option is turned off. Every Blizzard write passes through a hook, which
-- refreshes or clears the entry, so it never goes stale.
local blizzardNames = setmetatable({}, { __mode = "k" })

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled(FEATURE_KEY)
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsUsableFrame(frame)
    if not frame or IsSecret(frame) then return false end
    return not (frame.IsForbidden and frame:IsForbidden())
end

-- UnitName returns the first name and the surname separately on Forever. In
-- restricted content the name can be secret: SetText still accepts it, but it
-- can't be compared, so the first return says whether there is a name.
local function GetFirstName(unit)
    if type(unit) ~= "string" then return false end
    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) or not isPlayer then return false end

    local firstName = UnitName(unit)
    if IsSecret(firstName) then return true, firstName end
    if type(firstName) ~= "string" or firstName == "" then return false end
    return true, firstName
end

local function ShortenName(fontString, unit)
    local hasName, firstName = GetFirstName(unit)
    if not hasName then
        blizzardNames[fontString] = nil
        return
    end

    blizzardNames[fontString] = fontString:GetText()
    fontString:SetText(firstName)
end

-- Player, target, focus, target of target, pet, and party frames.
local function UpdateUnitFrame(frame)
    if not IsUsableFrame(frame) or not frame.name then return end
    ShortenName(frame.name, frame.overrideName or frame.unit)
end

-- Nameplates and raid-style party and raid frames. Blizzard hides the name
-- instead of writing it when it shouldn't show, and frames with a name
-- override (the nameplate settings preview) show a name of their own.
local function UpdateCompactFrame(frame)
    if not IsUsableFrame(frame) or not frame.name then return end
    if frame.UpdateNameOverride or not frame.name:IsShown() then
        blizzardNames[frame.name] = nil
        return
    end
    ShortenName(frame.name, frame.unit)
end

function HideSurnames.UpdateUnitFrame(frame)
    if not IsEnabled() then return end
    UpdateUnitFrame(frame)
end

function HideSurnames.UpdateCompactFrame(frame)
    if not IsEnabled() then return end
    UpdateCompactFrame(frame)
end

local hookedUnitFrames = false
local hookedCompactFrames = false

local function InstallHooks()
    if not hookedUnitFrames then
        hookedUnitFrames = Carpenter:SafeHook("UnitFrame_Update", HideSurnames.UpdateUnitFrame)
    end
    if not hookedCompactFrames then
        hookedCompactFrames = Carpenter:SafeHook("CompactUnitFrame_UpdateName", HideSurnames.UpdateCompactFrame)
    end
end

local function AddFrame(frames, frame)
    if frame then
        frames[#frames + 1] = frame
    end
end

local function GetUnitFrames()
    local frames = {}
    for _, frame in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT", "PetFrame" }) do
        AddFrame(frames, _G[frame])
    end
    for i = 1, 4 do
        AddFrame(frames, PartyFrame and PartyFrame["MemberFrame" .. i])
    end
    return frames
end

local function GetCompactFrames()
    local frames = {}
    for _, plate in ipairs((Nameplates.GetAll and Nameplates.GetAll()) or {}) do
        AddFrame(frames, plate.UnitFrame)
    end
    for i = 1, 5 do
        AddFrame(frames, _G["CompactPartyFrameMember" .. i])
    end
    for i = 1, 40 do
        AddFrame(frames, _G["CompactRaidFrame" .. i])
    end
    for group = 1, 8 do
        for member = 1, 5 do
            AddFrame(frames, _G["CompactRaidGroup" .. group .. "Member" .. member])
        end
    end
    return frames
end

-- Shortens the names already on screen; the hooks handle every later update.
local function ApplyAll()
    for _, frame in ipairs(GetUnitFrames()) do
        UpdateUnitFrame(frame)
    end
    for _, frame in ipairs(GetCompactFrames()) do
        UpdateCompactFrame(frame)
    end
end

local function RestoreAll()
    for fontString, text in pairs(blizzardNames) do
        fontString:SetText(text)
    end
    wipe(blizzardNames)
end

local feature = {}

function feature:Enable()
    InstallHooks()
    ApplyAll()
end

function feature:Disable()
    RestoreAll()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
