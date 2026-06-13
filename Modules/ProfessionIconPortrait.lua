--[[ Carpenter - Profession Icon Portrait ]]
-- Classic/TBC profession windows reuse the player portrait. This swaps it for
-- the active profession/craft spell icon when enabled.
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local FEATURE_KEY = "professionIconPortraitEnabled"
local BOOKTYPE = _G.BOOKTYPE_SPELL or "spell"

local globalHooks = {}
local overlays = {}
local fallbackIcons

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

local function Trim(value)
    if type(value) ~= "string" then return nil end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Normalize(value)
    value = Trim(value)
    if not value or value == "" then return nil end
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return value:lower()
end

local function IsUsefulName(value)
    value = Trim(value)
    return value and value ~= "" and value ~= (_G.UNKNOWN or "Unknown")
end

local function SameName(left, right)
    if left == right then return true end
    left = Normalize(left)
    right = Normalize(right)
    return left and right and left == right
end

local function AddFallbackIcon(map, texture, ...)
    if not texture then return end
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if IsUsefulName(name) then
            map[name] = texture
            local normalized = Normalize(name)
            if normalized then
                map[normalized] = texture
            end
        end
    end
end

local function GetFallbackIcons()
    if fallbackIcons then return fallbackIcons end

    fallbackIcons = {}
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Alchemy", "Alchemy", _G.ALCHEMY)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_BlackSmithing", "Blacksmithing", _G.BLACKSMITHING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\INV_Misc_Food_15", "Cooking", _G.COOKING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Engraving", "Enchanting", _G.ENCHANTING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Engineering", "Engineering", _G.ENGINEERING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Spell_Holy_SealOfSacrifice", "First Aid", _G.FIRST_AID)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Fishing", "Fishing", _G.FISHING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Herbalism", "Herbalism", _G.HERBALISM)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\INV_Misc_ArmorKit_17", "Leatherworking", _G.LEATHERWORKING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\INV_Misc_Gem_01", "Jewelcrafting", _G.JEWELCRAFTING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Mining", "Mining", _G.MINING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Ability_Poisons", "Poisons", _G.POISONS)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Skinning", _G.SKINNING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Spell_Fire_FlameBlades", "Smelting", _G.SMELTING)
    AddFallbackIcon(fallbackIcons, "Interface\\Icons\\Trade_Tailoring", "Tailoring", _G.TAILORING)

    return fallbackIcons
end

local function GetFallbackIcon(name)
    if not IsUsefulName(name) then return nil end
    local icons = GetFallbackIcons()
    return icons[name] or icons[Normalize(name)]
end

local function GetTextFromRegion(region)
    if region and region.GetText then
        return SafeCall(region.GetText, region)
    end
end

local function GetTradeSkillTitle()
    local title = SafeCall(_G.GetTradeSkillLine)
    if IsUsefulName(title) then return title end
    return GetTextFromRegion(_G.TradeSkillFrameTitleText)
        or (_G.TradeSkillFrame and GetTextFromRegion(_G.TradeSkillFrame.TitleText))
end

local function GetCraftTitle()
    local title = SafeCall(_G.GetCraftDisplaySkillLine)
    if IsUsefulName(title) then return title end

    title = SafeCall(_G.GetCraftSkillLine)
    if IsUsefulName(title) then return title end

    return GetTextFromRegion(_G.CraftFrameTitleText)
        or (_G.CraftFrame and GetTextFromRegion(_G.CraftFrame.TitleText))
end

local function GetSelectedTradeSkillIcon()
    if type(_G.GetTradeSkillSelectionIndex) ~= "function" or type(_G.GetTradeSkillIcon) ~= "function" then return nil end
    local index = SafeCall(_G.GetTradeSkillSelectionIndex)
    if type(index) == "number" and index > 0 then
        return SafeCall(_G.GetTradeSkillIcon, index)
    end
end

local function GetSelectedCraftIcon()
    if type(_G.GetCraftSelectionIndex) ~= "function" or type(_G.GetCraftIcon) ~= "function" then return nil end
    local index = SafeCall(_G.GetCraftSelectionIndex)
    if type(index) == "number" and index > 0 then
        return SafeCall(_G.GetCraftIcon, index)
    end
end

local function FindSpellbookIcon(name)
    if not IsUsefulName(name)
        or type(_G.GetNumSpellTabs) ~= "function"
        or type(_G.GetSpellTabInfo) ~= "function"
        or type(_G.GetSpellName) ~= "function"
        or type(_G.GetSpellTexture) ~= "function" then
        return nil
    end

    local numTabs = tonumber(SafeCall(_G.GetNumSpellTabs)) or 0
    for tabIndex = 1, numTabs do
        local _, _, offset, numSpells = SafeCall(_G.GetSpellTabInfo, tabIndex)
        offset = tonumber(offset) or 0
        numSpells = tonumber(numSpells) or 0

        for spellIndex = offset + 1, offset + numSpells do
            local spellName = SafeCall(_G.GetSpellName, spellIndex, BOOKTYPE)
            if SameName(spellName, name) then
                local texture = SafeCall(_G.GetSpellTexture, spellIndex, BOOKTYPE)
                if texture then return texture end
            end
        end
    end
end

local function GetProfessionIcon(name, selectedIcon)
    if not IsUsefulName(name) then return selectedIcon end

    if type(_G.GetSpellTexture) == "function" then
        local texture = SafeCall(_G.GetSpellTexture, name)
        if texture then return texture end
    end

    return FindSpellbookIcon(name)
        or GetFallbackIcon(name)
        or selectedIcon
end

local windows = {
    tradeSkill = {
        frameName = "TradeSkillFrame",
        portraitName = "TradeSkillFramePortrait",
        title = GetTradeSkillTitle,
        selectedIcon = GetSelectedTradeSkillIcon,
    },
    craft = {
        frameName = "CraftFrame",
        portraitName = "CraftFramePortrait",
        title = GetCraftTitle,
        selectedIcon = GetSelectedCraftIcon,
    },
}

local function GetWindowFrame(window)
    return window and _G[window.frameName]
end

local function GetWindowPortrait(window)
    if not window then return nil end
    local portrait = _G[window.portraitName]
    if portrait then return portrait end

    local frame = GetWindowFrame(window)
    if frame then
        return frame.portrait or frame.Portrait
    end
end

local function SetPortraitAlpha(portrait, alpha)
    if not portrait or type(portrait.SetAlpha) ~= "function" then return end
    portrait.CP_ProfessionIconApplying = true
    pcall(portrait.SetAlpha, portrait, alpha)
    portrait.CP_ProfessionIconApplying = nil
end

local function ScheduleRefresh(window)
    if Carpenter and Carpenter.Defer then
        Carpenter:Defer("ProfessionIconPortrait:" .. (window.frameName or "all"), 0, function()
            if window then
                windows.RefreshWindow(window)
            end
        end)
        return
    end
    if window then
        windows.RefreshWindow(window)
    end
end

local function HookPortrait(window)
    local portrait = GetWindowPortrait(window)
    if not portrait or portrait.CP_ProfessionIconHooked then return end

    local function OnPortraitChanged(self)
        if self.CP_ProfessionIconApplying or not IsEnabled() then return end
        ScheduleRefresh(window)
    end

    if Carpenter and Carpenter.SafeHook then
        Carpenter:SafeHook(portrait, "SetTexture", OnPortraitChanged)
        Carpenter:SafeHook(portrait, "SetTexCoord", OnPortraitChanged)
        Carpenter:SafeHook(portrait, "Show", OnPortraitChanged)
    elseif hooksecurefunc then
        pcall(hooksecurefunc, portrait, "SetTexture", OnPortraitChanged)
        pcall(hooksecurefunc, portrait, "SetTexCoord", OnPortraitChanged)
        pcall(hooksecurefunc, portrait, "Show", OnPortraitChanged)
    end

    portrait.CP_ProfessionIconHooked = true
end

local function PositionOverlay(overlay, portrait, parent)
    if overlay.SetParent and overlay:GetParent() ~= parent then
        overlay:SetParent(parent)
    end
    overlay:ClearAllPoints()
    overlay:SetFrameLevel(math.max(0, (parent.GetFrameLevel and parent:GetFrameLevel() or 0) - 2))
    overlay:SetPoint("TOPLEFT", portrait, "TOPLEFT")
    overlay:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT")
end

local function GetOrCreateOverlay(window, portrait)
    if not window or not portrait then return nil end

    local parent = (portrait.GetParent and portrait:GetParent()) or GetWindowFrame(window) or UIParent
    if not parent then return nil end

    local overlay = overlays[window.frameName]
    if not overlay then
        overlay = CreateFrame("Frame", nil, parent)
        local texture = overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
        texture:SetAllPoints(overlay)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        if overlay.CreateMaskTexture and texture.AddMaskTexture then
            local mask = overlay:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            mask:SetAllPoints(overlay)
            texture:AddMaskTexture(mask)
            overlay.mask = mask
        end

        overlay.texture = texture
        overlays[window.frameName] = overlay
    end

    PositionOverlay(overlay, portrait, parent)
    return overlay
end

local function HideOverlay(window)
    local overlay = window and overlays[window.frameName]
    if overlay then
        overlay:Hide()
    end
end

local function SetPortraitIcon(window, portrait, texture)
    if not portrait or not texture then return false end

    local overlay = GetOrCreateOverlay(window, portrait)
    if not overlay or not overlay.texture then return false end

    local ok = pcall(overlay.texture.SetTexture, overlay.texture, texture)
    if not ok then return false end

    if overlay.texture.SetTexCoord then
        pcall(overlay.texture.SetTexCoord, overlay.texture, 0.08, 0.92, 0.08, 0.92)
    end

    overlay:Show()
    SetPortraitAlpha(portrait, 0)
    portrait.CP_ProfessionIconApplied = true
    portrait.CP_ProfessionIconTexture = texture
    return true
end

local function RestorePortrait(window)
    local portrait = GetWindowPortrait(window)
    if not portrait or not portrait.CP_ProfessionIconApplied then return end

    portrait.CP_ProfessionIconApplied = nil
    portrait.CP_ProfessionIconTexture = nil
    HideOverlay(window)
    SetPortraitAlpha(portrait, 1)
end

function windows.RefreshWindow(window)
    if not window then return end

    HookPortrait(window)

    local frame = GetWindowFrame(window)
    local portrait = GetWindowPortrait(window)
    if not portrait then return end

    if not IsEnabled() then
        RestorePortrait(window)
        return
    end

    if frame and frame.IsShown and not frame:IsShown() then return end

    local title = window.title and window.title()
    local selectedIcon = window.selectedIcon and window.selectedIcon()
    local texture = GetProfessionIcon(title, selectedIcon)
    if texture then
        SetPortraitIcon(window, portrait, texture)
    else
        RestorePortrait(window)
    end
end

local function RefreshAll()
    windows.RefreshWindow(windows.tradeSkill)
    windows.RefreshWindow(windows.craft)
end

local function InstallGlobalHook(name, window)
    if globalHooks[name] or type(_G[name]) ~= "function" or not hooksecurefunc then return end
    local ok = pcall(hooksecurefunc, name, function()
        if IsEnabled() then
            ScheduleRefresh(window)
        end
    end)
    if ok then
        globalHooks[name] = true
    end
end

local function HookWindowScript(window)
    local frame = GetWindowFrame(window)
    if not frame or frame.CP_ProfessionIconHooked then return end

    if frame.HookScript then
        pcall(frame.HookScript, frame, "OnShow", function()
            ScheduleRefresh(window)
        end)
    end

    frame.CP_ProfessionIconHooked = true
end

local function InstallHooks()
    InstallGlobalHook("TradeSkillFrame_Update", windows.tradeSkill)
    InstallGlobalHook("TradeSkillFrame_SetSelection", windows.tradeSkill)
    InstallGlobalHook("CraftFrame_Update", windows.craft)
    InstallGlobalHook("CraftFrame_SetSelection", windows.craft)
    HookWindowScript(windows.tradeSkill)
    HookWindowScript(windows.craft)
    HookPortrait(windows.tradeSkill)
    HookPortrait(windows.craft)
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function()
    InstallHooks()
    RefreshAll()
end)

local function RegisterEvent(event)
    if Carpenter and Carpenter.SafeRegisterEvent then
        Carpenter:SafeRegisterEvent(frame, event)
    else
        pcall(frame.RegisterEvent, frame, event)
    end
end

local feature = {}

function feature:Enable()
    RegisterEvent("ADDON_LOADED")
    RegisterEvent("PLAYER_ENTERING_WORLD")
    RegisterEvent("TRADE_SKILL_SHOW")
    RegisterEvent("TRADE_SKILL_UPDATE")
    RegisterEvent("CRAFT_SHOW")
    RegisterEvent("CRAFT_UPDATE")

    InstallHooks()
    RefreshAll()

    if Carpenter and Carpenter.RunStartupPasses then
        Carpenter:RunStartupPasses("ProfessionIconPortrait:startup", { 0, 0.2, 1 }, RefreshAll)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
    RestorePortrait(windows.tradeSkill)
    RestorePortrait(windows.craft)
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature(FEATURE_KEY, feature)
end
