--[[ Carpenter - ChatCleaner lifecycle ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Lifecycle = ns.Private.ChatCleanerLifecycle or {}
ns.Private.ChatCleanerLifecycle = Lifecycle

local chatEvents = {
    "CHAT_MSG_COMBAT_XP_GAIN",
    "CHAT_MSG_COMBAT_MISC_INFO",
    "CHAT_MSG_COMBAT_HONOR_GAIN",
    "CHAT_MSG_COMBAT_FACTION_CHANGE",
    "CHAT_MSG_MONEY",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_SKILL",
    "CHAT_MSG_BG_SYSTEM_ALLIANCE",
    "CHAT_MSG_BG_SYSTEM_HORDE",
    "CHAT_MSG_BG_SYSTEM_NEUTRAL",
    "CHAT_MSG_AUCTION_LISTED",
    "CHAT_MSG_AUCTION_REMOVED",
    "CHAT_MSG_AUCTION_WON",
    "CHAT_MSG_AUCTION_OUTBIDDED",
    "CHAT_MSG_AUCTION_EXPIRED",
    "CHAT_MSG_AUCTION_CANCELLED",
    "CHAT_MSG_CURRENCY",
    "CHAT_MSG_MONSTER_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_SAY",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_YELL",
}

local CHAT_FLAG_KEYS = { "CHAT_FLAG_AFK", "CHAT_FLAG_DND" }
local CHAT_FLAG_VALUES = { CHAT_FLAG_AFK = "AFK ", CHAT_FLAG_DND = "DND " }

local originalChatFlags
local originalEditBoxTextures = {}

local function ApplyChatFlags()
    if originalChatFlags then return end
    originalChatFlags = {}
    for _, key in ipairs(CHAT_FLAG_KEYS) do
        originalChatFlags[key] = _G[key]
        _G[key] = CHAT_FLAG_VALUES[key]
    end
end

local function RestoreChatFlags()
    if not originalChatFlags then return end
    for _, key in ipairs(CHAT_FLAG_KEYS) do
        -- Leave the flag alone if another addon replaced it after us.
        if _G[key] == CHAT_FLAG_VALUES[key] then
            _G[key] = originalChatFlags[key]
        end
    end
    originalChatFlags = nil
end

local function ForEachEditBoxTexture(callback)
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and eb.GetRegions then
            for regionIndex = 1, select("#", eb:GetRegions()) do
                local region = select(regionIndex, eb:GetRegions())
                if region and region.IsObjectType and region:IsObjectType("Texture") then
                    callback(region)
                end
            end
        end
    end
end

local function CleanEditBox()
    ForEachEditBoxTexture(function(region)
        if not originalEditBoxTextures[region] then
            originalEditBoxTextures[region] = {
                atlas = region.GetAtlas and region:GetAtlas() or nil,
                texture = region.GetTexture and region:GetTexture() or nil,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                texCoord = region.GetTexCoord and { region:GetTexCoord() } or nil,
            }
        end
        region:SetTexture(nil)
        region:SetAlpha(0)
    end)
end

local function RestoreEditBox()
    for region, original in pairs(originalEditBoxTextures) do
        if original.atlas and region.SetAtlas then
            region:SetAtlas(original.atlas)
        else
            region:SetTexture(original.texture)
            if original.texCoord and #original.texCoord > 0 and region.SetTexCoord then
                region:SetTexCoord(unpack(original.texCoord))
            end
        end
        region:SetAlpha(original.alpha)
    end
    originalEditBoxTextures = {}
end

-- The input box texture is hidden unless the player chose to keep it.
local function ApplyEditBox()
    if CarpenterDB and CarpenterDB.chatEditBoxTextureEnabled == true then
        RestoreEditBox()
    else
        CleanEditBox()
    end
end

function Lifecycle.Create(options)
    options = options or {}
    local filtersRegistered = false
    local initializedHooks = false
    local featureEnabled = false

    local function ForEachChatFrame(callback)
        if not callback then return end
        for i = 1, NUM_CHAT_WINDOWS do
            callback(_G["ChatFrame" .. i])
        end
    end

    local function HookChatFrames()
        if not featureEnabled then return end
        ForEachChatFrame(function(chatFrame)
            if options.HookChatFrameAddMessage then
                options.HookChatFrameAddMessage(chatFrame)
            end
        end)
    end

    local function RestoreChatFrames()
        ForEachChatFrame(function(chatFrame)
            if options.RestoreChatFrameAddMessage then
                options.RestoreChatFrameAddMessage(chatFrame)
            end
        end)
    end

    local function ChatFilter(self, event, msg, author, ...)
        local function RunFilter(...)
            return pcall(options.FilterImpl, ...)
        end
        local results
        if Carpenter and Carpenter.Profile then
            results = { Carpenter:Profile("ChatCleaner:Filter", RunFilter, self, event, msg, author, ...) }
        else
            results = { RunFilter(self, event, msg, author, ...) }
        end
        local ok = results[1]
        if not ok then
            return false, (msg or ""), (author or ""), ...
        end
        table.remove(results, 1)
        for i = 1, #results do
            if results[i] == nil then
                results[i] = ""
            end
        end
        return unpack(results)
    end

    local function RegisterChatFilters()
        if filtersRegistered then return end
        filtersRegistered = true
        for _, event in ipairs(chatEvents) do
            ChatFrame_AddMessageEventFilter(event, ChatFilter)
        end
    end

    local function UnregisterChatFilters()
        if not filtersRegistered or not ChatFrame_RemoveMessageEventFilter then return end
        filtersRegistered = false
        for _, event in ipairs(chatEvents) do
            ChatFrame_RemoveMessageEventFilter(event, ChatFilter)
        end
    end

    local function InitializeHooks()
        if initializedHooks then return end
        initializedHooks = true

        if C_Timer and C_Timer.After then
            C_Timer.After(0, HookChatFrames)
        else
            HookChatFrames()
        end
    end

    local function Enable()
        featureEnabled = true
        InitializeHooks()
        HookChatFrames()
        if options.ApplyLevelUpGlobalStringStyling then
            options.ApplyLevelUpGlobalStringStyling()
        end
        ApplyChatFlags()
        RegisterChatFilters()
        ApplyEditBox()
        if options.SessionTracker and options.SessionTracker.Enable then
            options.SessionTracker:Enable()
        end
    end

    local function Disable()
        featureEnabled = false
        UnregisterChatFilters()
        RestoreChatFrames()
        if options.RestoreLevelUpGlobalStringStyling then
            options.RestoreLevelUpGlobalStringStyling()
        end
        RestoreChatFlags()
        RestoreEditBox()
        if options.SessionTracker and options.SessionTracker.Disable then
            options.SessionTracker:Disable()
        end
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("VARIABLES_LOADED")
    loader:SetScript("OnEvent", function(_, event)
        InitializeHooks()
        if Carpenter and Carpenter.RefreshFeature then
            Carpenter:RefreshFeature("chatCleanerEnabled")
        elseif Carpenter and Carpenter:IsEnabled("chatCleanerEnabled") then
            Enable()
        end
    end)

    return {
        Enable = Enable,
        Disable = Disable,
        ApplyEditBox = function()
            if featureEnabled then ApplyEditBox() end
        end,
    }
end
