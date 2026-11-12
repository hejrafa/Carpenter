#!/usr/bin/env lua
-- Verifies Poison Warning warns two minutes before a weapon enchant ends and
-- when it wears off, both on WoW Forever (C_Item.GetWeaponEnchantInfo per
-- slot) and on Classic (the old GetWeaponEnchantInfo global). An enchant the
-- client stops reporting with time and charges left (around a loading screen,
-- or a swapped weapon) didn't wear off and must stay quiet. On Forever it also
-- corrects a weapon buff timer Blizzard's buff frame left stuck at 0 after a
-- load, from the time the game reports.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local failures = {}
local function check(condition, message)
    if not condition then failures[#failures + 1] = message end
end

local function Run(clientName, setupClient)
    local messages = {}
    local ticker
    local eventHandlers = {}
    local now = 1000
    -- reported: whether the client reports the enchant right now.
    local enchant = { reported = true, msLeft = 115000, charges = 0 }

    ITEM_ENCHANT_TIME_LEFT_MIN = "%s (%d min)"
    ITEM_ENCHANT_TIME_LEFT_SEC = "%s (%d sec)"
    GetTime = function() return now end
    UIErrorsFrame = { AddMessage = function(_, text) messages[#messages + 1] = text end }
    UIParent, WorldFrame = {}, {}
    MerchantFrame, GameTooltip = nil, nil
    IsBagOpen = function() return false end
    CreateFrame = function(_, name)
        local frameObject = {}
        function frameObject:SetOwner() end
        function frameObject:ClearLines() end
        function frameObject:SetInventoryItem() end
        function frameObject:NumLines() return 1 end
        function frameObject:Hide() end
        function frameObject:RegisterEvent() end
        function frameObject:SetScript(script, handler)
            if script == "OnEvent" then eventHandlers[#eventHandlers + 1] = handler end
        end
        if name then _G[name] = frameObject end
        return frameObject
    end
    _G.CarpenterScanTooltipTextLeft1 = {
        GetText = function() return enchant.reported and "Instant Poison VI (2 min)" or nil end,
        GetTextColor = function() return 0, 1, 0 end,
    }
    C_Timer = { NewTicker = function(_, callback)
        ticker = { callback = callback, Cancel = function(self) self.cancelled = true end }
        return ticker
    end }
    hooksecurefunc = function(target, method, hook)
        local original = target[method]
        target[method] = function(...)
            original(...)
            hook(...)
        end
    end
    -- Blizzard's formatter, for times under a day.
    SecondsToTimeAbbrev = function(seconds)
        if seconds >= 90 then return "%d m", math.ceil(seconds / 60) end
        return "%d s", math.floor(seconds)
    end
    BUFF_WARNING_TIME, BUFF_DURATION_WARNING_TIME = 31, 90
    HIGHLIGHT_FONT_COLOR, NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 }, { r = 1, g = 0.82, b = 0 }

    -- One of Blizzard's buff buttons; its UpdateDuration shows the time it holds.
    local function NewBuffButton()
        local button = { auraType = "TempEnchant", alpha = 1, Duration = { shown = true } }
        function button.Duration:IsShown() return self.shown end
        function button.Duration:SetFormattedText(format, ...) self.text = string.format(format, ...) end
        function button.Duration:SetVertexColor() end
        function button:SetAlpha(alpha) self.alpha = alpha end
        function button:GetParent() return { auraWarningMaxAlpha = 1 } end
        function button:UpdateDuration(timeLeft) self.Duration:SetFormattedText(SecondsToTimeAbbrev(timeLeft)) end
        return button
    end
    BuffFrame = clientName == "forever" and { auraFrames = { NewBuffButton() } } or nil

    setupClient(enchant)

    local feature
    CarpenterDB = { enchantWarningEnabled = true }
    Carpenter = {
        L = {},
        Client = clientName == "forever" and { isForever = true, isMainline = true } or { isVanilla = true },
        IsEnabled = function(_, key) return CarpenterDB[key] == true end,
        RegisterFeature = function(_, _, registered) feature = registered end,
    }

    Carpenter = dofile(repo .. "/tools/fixtures/fixture-carpenter.lua")(Carpenter)
    assert(loadfile(repo .. "/Modules/EnchantWarning.lua"))("Carpenter", { Private = {} })
    feature:Enable()
    assert(ticker, clientName .. ": enabling should start the check")

    -- One second passes, the enchant's time with it, then the check runs.
    local function Tick(count)
        for _ = 1, count or 1 do
            now = now + 1
            enchant.msLeft = math.max(0, enchant.msLeft - 1000)
            ticker.callback()
        end
    end
    local function Fire(event)
        for _, handler in ipairs(eventHandlers) do handler(nil, event) end
    end
    local function Apply(msLeft, charges)
        enchant.reported, enchant.msLeft, enchant.charges = true, msLeft, charges or 0
    end
    local function Got()
        return "[" .. table.concat(messages, " | ") .. "]"
    end

    -- Two minutes left: warn once.
    Tick(2)
    check(#messages == 1 and messages[1]:find("Instant Poison VI", 1, true) and messages[1]:find("2 min", 1, true),
        clientName .. ": expected one two-minute warning, got " .. Got())

    -- A loading screen: no enchant reported from leaving the world until a
    -- couple of checks after entering it, then it's back.
    Fire("PLAYER_LEAVING_WORLD")
    enchant.reported = false
    Tick(3)
    Fire("PLAYER_ENTERING_WORLD")
    Tick(7)
    enchant.reported = true
    Tick(2)
    check(#messages == 1, clientName .. ": a loading screen should not say the enchant wore off, got " .. Got())

    -- Missing for a moment with no loading screen (or a swapped weapon).
    enchant.reported = false
    Tick()
    enchant.reported = true
    Tick()
    check(#messages == 1, clientName .. ": an enchant missing with time left should stay quiet, got " .. Got())

    -- Its time runs out.
    Apply(3500)
    Tick(3)
    enchant.reported = false
    Tick()
    check(#messages == 2 and messages[2]:find("Instant Poison VI", 1, true) and messages[2]:find("worn off", 1, true),
        clientName .. ": expected a worn off message, got " .. Got())
    Tick(2)
    check(#messages == 2, clientName .. ": a worn off enchant should be announced once, got " .. Got())

    -- Its charges run out with half an hour left.
    Apply(1800000, 2)
    Tick()
    enchant.reported = false
    Tick()
    check(#messages == 3 and messages[3]:find("worn off", 1, true),
        clientName .. ": expected a worn off message when the charges ran out, got " .. Got())

    -- Plenty of charges and time left: not worn off.
    Apply(1800000, 40)
    Tick()
    enchant.reported = false
    Tick()
    check(#messages == 3, clientName .. ": an enchant with charges left should stay quiet, got " .. Got())

    -- It runs out during a loading screen: announced once the checks resume.
    Apply(5000)
    Tick()
    Fire("PLAYER_LEAVING_WORLD")
    Tick(3)
    enchant.reported = false
    Fire("PLAYER_ENTERING_WORLD")
    Tick(6)
    check(#messages == 4 and messages[4]:find("worn off", 1, true),
        clientName .. ": an enchant that ran out while loading should be announced, got " .. Got())

    if clientName == "forever" then
        local button = BuffFrame.auraFrames[1]
        -- A frame of Blizzard's OnUpdate: the blink alpha, then the duration.
        local function Draw()
            local timeLeft = math.max(button.buttonInfo.expirationTime - now, 0)
            button:SetAlpha(timeLeft < BUFF_WARNING_TIME and 0.3 or 1)
            button:UpdateDuration(timeLeft)
        end
        local function Shown()
            return tostring(button.Duration.text) .. " at alpha " .. tostring(button.alpha)
        end

        -- Blizzard read the weapon buff right after a load, while the game
        -- reported no time left; so does the game, for now.
        Apply(0, 60)
        button.buttonInfo = { ID = 16, expirationTime = now }
        Draw()
        check(button.Duration.text == "0 s", "forever: a timer the game agrees with should stay, got " .. Shown())

        -- The game reports the real time: the timer shows it and stops blinking.
        enchant.msLeft = 1110000
        now = now + 1
        Draw()
        check(button.Duration.text == "19 m" and button.alpha == 1,
            "forever: a weapon buff timer stuck at 0 should show the game's time, got " .. Shown())
        now = now + 60
        Draw()
        check(button.Duration.text == "18 m", "forever: the corrected timer should count down, got " .. Shown())

        -- Blizzard's own next update is left alone.
        button.buttonInfo = { ID = 16, expirationTime = now + 300 }
        Draw()
        check(button.Duration.text == "5 m", "forever: a timer Blizzard updated should be left alone, got " .. Shown())

        -- A weapon buff really running out: both at zero.
        enchant.msLeft = 1000
        button.buttonInfo = { ID = 16, expirationTime = now }
        Draw()
        check(button.Duration.text == "0 s" and button.alpha == 0.3,
            "forever: a weapon buff running out should keep Blizzard's timer, got " .. Shown())

        -- Other buffs are left alone.
        enchant.msLeft = 1110000
        button.auraType = "Buff"
        button.buttonInfo = { ID = 16, expirationTime = now }
        Draw()
        check(button.Duration.text == "0 s", "forever: other buffs should be left alone, got " .. Shown())
        button.auraType = "TempEnchant"
    end

    feature:Disable()
    check(ticker.cancelled, clientName .. ": disabling should stop the check")

    if clientName == "forever" then
        local button = BuffFrame.auraFrames[1]
        button.buttonInfo = { ID = 16, expirationTime = now }
        button:UpdateDuration(0)
        check(button.Duration.text == "0 s", "forever: with Poison Warning off the timer should be left alone, got "
            .. tostring(button.Duration.text))
    end
end

-- WoW Forever: per-slot enchant lists, no old global.
Run("forever", function(enchant)
    GetWeaponEnchantInfo = nil
    Enum = { WeaponSlot = { MainHand = 0, OffHand = 1, Ranged = 2 } }
    C_Item = {
        GetWeaponEnchantInfo = function(slot)
            if slot == Enum.WeaponSlot.MainHand and enchant.reported then
                return { {
                    hasEnchant = true, timeLeft = enchant.msLeft, charges = enchant.charges,
                    enchantID = 1, enchantType = 0,
                } }
            end
            return {}
        end,
    }
    C_TooltipInfo = {
        GetInventoryItem = function()
            if not enchant.reported then return { lines = {} } end
            return { lines = { { leftText = "Instant Poison VI (2 min)", leftColor = { r = 0, g = 1, b = 0 } } } }
        end,
    }
end)

-- Classic: the old global.
Run("classic", function(enchant)
    C_Item, C_TooltipInfo, Enum = nil, nil, nil
    GetWeaponEnchantInfo = function()
        if not enchant.reported then return false, nil, nil, nil, false, nil, nil, nil end
        return true, enchant.msLeft, enchant.charges, 1, false, nil, nil, nil
    end
end)

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("enchant warning fixtures passed")
