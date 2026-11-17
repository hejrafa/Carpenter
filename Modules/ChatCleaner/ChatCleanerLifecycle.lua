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

local originalEditBoxTextures = {}

local function ForEachEditBoxTexture(callback)
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox and editBox.GetRegions then
            for _, region in ipairs({ editBox:GetRegions() }) do
                if region.IsObjectType and region:IsObjectType("Texture") then
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

-- config: FilterImpl, ShouldDropBeforeAdd, ShouldDropChannelNotice,
-- HookChatFrameAddMessage, RestoreChatFrameAddMessage, SessionTracker.
function Lifecycle.Create(config)
    config = config or {}
    local filtersRegistered = false
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
            if config.HookChatFrameAddMessage then
                config.HookChatFrameAddMessage(chatFrame)
            end
        end)
    end

    local function RestoreChatFrames()
        ForEachChatFrame(function(chatFrame)
            if config.RestoreChatFrameAddMessage then
                config.RestoreChatFrameAddMessage(chatFrame)
            end
        end)
    end

    -- The filter's answer as the chat frame takes it: true hides the line;
    -- false and the values shows them, nils kept where they were. Where
    -- lines are only restyled after they are added, the ones that should go
    -- are dropped here instead. An error shows the line as it came.
    local function Finish(frame, event, ok, hide, ...)
        if not ok then return false end
        if hide == true then return true end
        if config.ShouldDropBeforeAdd then
            local checked, drop = pcall(config.ShouldDropBeforeAdd, frame, event, (...))
            if checked and drop then return true end
        end
        return false, ...
    end

    local function ChatFilter(frame, event, ...)
        return Finish(frame, event, Carpenter:Profile("ChatCleaner:Filter", pcall, config.FilterImpl, frame, event, ...))
    end

    local function ChannelNoticeFilter(frame, event, notice)
        if config.ShouldDropChannelNotice then
            local checked, drop = pcall(config.ShouldDropChannelNotice, frame, notice)
            if checked and drop then
                return true
            end
        end
        return false
    end

    local function RegisterChatFilters()
        if filtersRegistered then return end
        filtersRegistered = true
        for _, event in ipairs(chatEvents) do
            ChatFrame_AddMessageEventFilter(event, ChatFilter)
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", ChannelNoticeFilter)
    end

    local function UnregisterChatFilters()
        if not filtersRegistered then return end
        filtersRegistered = false
        for _, event in ipairs(chatEvents) do
            ChatFrame_RemoveMessageEventFilter(event, ChatFilter)
        end
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", ChannelNoticeFilter)
    end

    local function Enable()
        featureEnabled = true
        HookChatFrames()
        RegisterChatFilters()
        ApplyEditBox()
        if config.SessionTracker and config.SessionTracker.Enable then
            config.SessionTracker:Enable()
        end
    end

    local function Disable()
        featureEnabled = false
        UnregisterChatFilters()
        RestoreChatFrames()
        RestoreEditBox()
        if config.SessionTracker and config.SessionTracker.Disable then
            config.SessionTracker:Disable()
        end
    end

    return {
        Enable = Enable,
        Disable = Disable,
        ApplyEditBox = function()
            if featureEnabled then ApplyEditBox() end
        end,
    }
end
