--[[ Carpenter - Talent Icon Portrait ]]
-- Classic/TBC talent window reuses the player portrait. This swaps it for the
-- icon of the currently selected talent tree (e.g. Rogue Assassination / Combat
-- / Subtlety) while the window is open.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local FEATURE_KEY = "talentIconPortraitEnabled"
local TALENT_ADDON = "Blizzard_TalentUI"

local hookedTabs = {}
local hookedFrame = false
local hookedPortrait = false
local hookedGlobals = {}

local RefreshWindow

local function IsEnabled()
    return Carpenter
        and Carpenter.Client
        and Carpenter.Client.isClassic
        and Carpenter:IsEnabled(FEATURE_KEY)
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then return nil end
    local results = { pcall(callback, ...) }
    if results[1] then
        return unpack(results, 2)
    end
    return nil
end

local function GetTalentFrame()
    return _G.PlayerTalentFrame or _G.TalentFrame
end

local function GetTalentPortrait()
    local frame = GetTalentFrame()
    if not frame then return nil end
    local name = frame.GetName and frame:GetName()
    if name then
        local portrait = _G[name .. "Portrait"]
        if portrait then return portrait end
    end
    return frame.portrait or frame.Portrait
end

local function GetSelectedTabIndex()
    local frame = GetTalentFrame()
    if not frame then return nil end
    if type(_G.PanelTemplates_GetSelectedTab) == "function" then
        local index = SafeCall(_G.PanelTemplates_GetSelectedTab, frame)
        if type(index) == "number" and index > 0 then return index end
    end
    if type(frame.selectedTab) == "number" and frame.selectedTab > 0 then
        return frame.selectedTab
    end
    return 1
end

local function IsIconValue(value)
    if type(value) == "number" then return value > 0 end
    return type(value) == "string" and value ~= ""
end

local function GetTabIcon(tabIndex)
    if type(tabIndex) ~= "number" then return nil end
    if type(_G.GetTalentTabInfo) ~= "function" then return nil end

    local results = { SafeCall(_G.GetTalentTabInfo, tabIndex) }
    if not results[1] then return nil end

    -- Original vanilla/TBC API: name, iconTexture, pointsSpent.
    -- Modern Classic clients: id, name, description, iconTexture, pointsSpent, ...
    local icon
    if type(results[1]) == "string" then
        icon = results[2]
    else
        icon = results[4]
    end
    if IsIconValue(icon) then return icon end
end

local function ApplyIcon(portrait, texture)
    if not portrait or not texture then return false end

    portrait.CP_TalentIconApplying = true
    local ok = false
    if type(_G.SetPortraitToTexture) == "function" then
        ok = pcall(_G.SetPortraitToTexture, portrait, texture)
    end
    if not ok and portrait.SetTexture then
        ok = pcall(portrait.SetTexture, portrait, texture)
        if ok and portrait.SetTexCoord then
            pcall(portrait.SetTexCoord, portrait, 0.08, 0.92, 0.08, 0.92)
        end
    end
    if portrait.SetAlpha then
        pcall(portrait.SetAlpha, portrait, 1)
    end
    portrait.CP_TalentIconApplying = nil

    if ok then
        portrait.CP_TalentIconApplied = true
        portrait.CP_TalentIconTexture = texture
    end
    return ok
end

local function RestorePortrait()
    local portrait = GetTalentPortrait()
    if not portrait or not portrait.CP_TalentIconApplied then return end

    portrait.CP_TalentIconApplying = true
    if type(_G.SetPortraitTexture) == "function" then
        pcall(_G.SetPortraitTexture, portrait, "player")
    end
    if portrait.SetAlpha then
        pcall(portrait.SetAlpha, portrait, 1)
    end
    portrait.CP_TalentIconApplying = nil

    portrait.CP_TalentIconApplied = nil
    portrait.CP_TalentIconTexture = nil
end

local function HookPortrait()
    local portrait = GetTalentPortrait()
    if not portrait or hookedPortrait then return end

    local function OnPortraitChanged(self)
        if self.CP_TalentIconApplying or not IsEnabled() then return end
        RefreshWindow()
    end

    if Carpenter and Carpenter.SafeHook then
        Carpenter:SafeHook(portrait, "SetTexture", OnPortraitChanged)
        Carpenter:SafeHook(portrait, "SetTexCoord", OnPortraitChanged)
    elseif hooksecurefunc then
        pcall(hooksecurefunc, portrait, "SetTexture", OnPortraitChanged)
        pcall(hooksecurefunc, portrait, "SetTexCoord", OnPortraitChanged)
    end

    hookedPortrait = true
end

local function HookTabs()
    local frame = GetTalentFrame()
    if not frame then return end
    local name = frame.GetName and frame:GetName()
    if not name then return end
    for i = 1, 5 do
        local tab = _G[name .. "Tab" .. i]
        if tab and not hookedTabs[tab] and tab.HookScript then
            pcall(tab.HookScript, tab, "OnClick", function()
                if IsEnabled() then RefreshWindow() end
            end)
            hookedTabs[tab] = true
        end
    end
end

local function HookFrame()
    local frame = GetTalentFrame()
    if not frame or hookedFrame then return end
    if frame.HookScript then
        pcall(frame.HookScript, frame, "OnShow", function()
            if IsEnabled() then RefreshWindow() end
        end)
        hookedFrame = true
    end
end

local function HookGlobal(name)
    if hookedGlobals[name] or not hooksecurefunc or type(_G[name]) ~= "function" then return end
    local ok = pcall(hooksecurefunc, name, function(...)
        if not IsEnabled() then return end
        if name == "PanelTemplates_SetTab" then
            local frame = select(1, ...)
            if frame ~= GetTalentFrame() then return end
        end
        RefreshWindow()
    end)
    if ok then hookedGlobals[name] = true end
end

local function InstallHooks()
    HookGlobal("PanelTemplates_SetTab")
    HookGlobal("TalentFrame_Update")
    HookGlobal("TalentFrame_SetTab")
    HookGlobal("PlayerTalentFrame_Refresh")
    HookFrame()
    HookTabs()
    HookPortrait()
end

function RefreshWindow()
    InstallHooks()

    local frame = GetTalentFrame()
    local portrait = GetTalentPortrait()
    if not portrait then return end

    if not IsEnabled() then
        RestorePortrait()
        return
    end

    if frame and frame.IsShown and not frame:IsShown() then return end

    local tabIndex = GetSelectedTabIndex()
    local texture = GetTabIcon(tabIndex)
    if texture then
        ApplyIcon(portrait, texture)
    else
        RestorePortrait()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= TALENT_ADDON then return end
    InstallHooks()
    RefreshWindow()
end)

local function RegisterEvent(event)
    if Carpenter and Carpenter.SafeRegisterEvent then
        Carpenter:SafeRegisterEvent(eventFrame, event)
    else
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end

local feature = {}

function feature:Enable()
    RegisterEvent("ADDON_LOADED")
    RegisterEvent("PLAYER_ENTERING_WORLD")
    RegisterEvent("PLAYER_TALENT_UPDATE")
    RegisterEvent("CHARACTER_POINTS_CHANGED")

    if _G.IsAddOnLoaded and IsAddOnLoaded(TALENT_ADDON) then
        InstallHooks()
        RefreshWindow()
    end

    if Carpenter and Carpenter.RunStartupPasses then
        Carpenter:RunStartupPasses("TalentIconPortrait:startup", { 0, 0.2, 1 }, function()
            InstallHooks()
            RefreshWindow()
        end)
    end
end

function feature:Disable()
    eventFrame:UnregisterAllEvents()
    RestorePortrait()
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
