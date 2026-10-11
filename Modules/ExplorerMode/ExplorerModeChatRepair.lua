--[[ Carpenter - Explorer Mode chat repair ]]
-- One-time repair of chat windows an old Explorer Mode build opened by accident.

local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local Internal = ns.Private.ExplorerModeInternal
local S = Internal.State
local CHAT_REPAIR_VERSION = Internal.CHAT_REPAIR_VERSION
local IsShownFrame = Internal.IsShownFrame

local function NormalizeChatWindowName(name)
    return tostring(name or ""):lower():gsub("%s+", "")
end

local function IsDefaultChatWindowName(index, name)
    local normalizedName = NormalizeChatWindowName(name)
    if normalizedName == "" or normalizedName == tostring(index) then
        return true
    end

    local defaults = {
        "ChatFrame" .. index,
        "Chat " .. index,
        "Window " .. index,
        "Chat Window " .. index,
        _G["CHAT_WINDOW_" .. index],
    }

    local function AddFormattedDefault(template)
        if not template then return end
        local ok, formattedName = pcall(string.format, template, index)
        if ok then
            defaults[#defaults + 1] = formattedName
        end
    end

    AddFormattedDefault(CHAT_NAME_TEMPLATE)
    AddFormattedDefault(CHAT_WINDOW_NAME_TEMPLATE)

    for _, defaultName in ipairs(defaults) do
        if defaultName and normalizedName == NormalizeChatWindowName(defaultName) then
            return true
        end
    end

    return false
end

local function GetChatWindowShown(index)
    if GetChatWindowInfo then
        local ok, name, fontSize, r, g, b, alpha, shown = pcall(GetChatWindowInfo, index)
        if ok then
            return shown == true
        end
    end

    local chatFrame = _G["ChatFrame" .. index]
    return chatFrame and IsShownFrame(chatFrame)
end

local function GetChatWindowName(index)
    if GetChatWindowInfo then
        local ok, name = pcall(GetChatWindowInfo, index)
        if ok then
            return name
        end
    end
    return nil
end

local function CloseChatWindow(index)
    local chatFrame = _G["ChatFrame" .. index]

    if FCF_Close and chatFrame then
        pcall(FCF_Close, chatFrame)
    end

    if SetChatWindowShown then
        pcall(SetChatWindowShown, index, false)
    end

    if chatFrame and chatFrame.Hide then
        pcall(chatFrame.Hide, chatFrame)
    end

    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab and tab.Hide then
        pcall(tab.Hide, tab)
    end
end

local function RepairAccidentalChatWindows()
    if not CarpenterDB or CarpenterDB.explorerModeChatWindowRepairVersion == CHAT_REPAIR_VERSION then
        return
    end

    if Carpenter and Carpenter.Client and Carpenter.Client.isClassic then
        for index = 4, 10 do
            if GetChatWindowShown(index) and IsDefaultChatWindowName(index, GetChatWindowName(index)) then
                CloseChatWindow(index)
            end
        end
    end

    CarpenterDB.explorerModeChatWindowRepairVersion = CHAT_REPAIR_VERSION
end

_G.Carpenter_RepairExplorerModeChatWindows = RepairAccidentalChatWindows

local repairFrame = CreateFrame("Frame")
repairFrame:RegisterEvent("PLAYER_LOGIN")
repairFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if Carpenter and Carpenter.After then
        Carpenter:After(2, RepairAccidentalChatWindows)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(2, RepairAccidentalChatWindows)
    else
        RepairAccidentalChatWindows()
    end
end)
