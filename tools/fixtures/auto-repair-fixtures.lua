#!/usr/bin/env lua
-- Verifies Auto Repair: own gold by default, guild funds when the option is on
-- and the daily allowance covers the repair, and a fall back to own gold when
-- the server refuses the guild repair. Only a repair that went through is
-- reported, and only own gold counts toward the merchant summary.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end

local ns = {
    L = { GEAR_REPAIRED = "Gear repaired", GEAR_REPAIRED_GUILD = "Gear repaired with guild funds" },
    Private = { Colors = { gray = { colorCode = "" }, palered = { colorCode = "" } } },
}

local addonFrame
local registeredFeature
local messages = {}
local repairs = {}
local timers = {}

function CreateFrame()
    addonFrame = { events = {} }
    function addonFrame:SetScript(_, handler) self.OnEvent = handler end
    function addonFrame:RegisterEvent(event) self.events[event] = true end
    function addonFrame:UnregisterAllEvents() self.events = {} end
    return addonFrame
end

C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function RunTimers()
    local due = timers
    timers = {}
    for _, callback in ipairs(due) do callback() end
end

ERR_GUILD_NOT_ENOUGH_MONEY = "The guild bank does not have enough money"
ERR_NOT_ENOUGH_MONEY = "You don't have enough money."

local shiftDown, repairCost, canRepair, money, guildRefuses
function IsShiftKeyDown() return shiftDown end
function CanMerchantRepair() return true end
function GetRepairAllCost() return repairCost, canRepair end
function GetMoney() return money end
function RepairAllItems(useGuild)
    repairs[#repairs + 1] = useGuild and "guild" or "own"
    -- A refused guild repair changes nothing; the fixture then sends the error.
    if useGuild and guildRefuses then return end
    repairCost, canRepair = 0, false
end

local canGuildRepair, allowance
local function InstallGuildCalls()
    CanGuildBankRepair = function() return canGuildRepair end
    GetGuildBankWithdrawMoney = function() return allowance end
end
InstallGuildCalls()

CarpenterDB = {}
Carpenter = {
    MerchantState = {},
    MinusSign = "\226\136\146",
    IsEnabled = function(_, key) return key == "autoRepair" end,
    AddChatMessage = function(_, message) messages[#messages + 1] = message end,
    FormatMoney = function(_, amount) return tostring(amount) end,
    RegisterFeature = function(_, key, feature)
        if key == "autoRepair" then registeredFeature = feature end
    end,
}
Carpenter = dofile(repo .. "/tools/fixtures/fixture-carpenter.lua")(Carpenter)
assert(loadfile(repo .. "/Modules/AutoRepair.lua"))("Carpenter", ns)

assert(registeredFeature and registeredFeature.Enable, "Auto Repair feature was not registered")
registeredFeature:Enable()
assert(addonFrame.events.MERCHANT_SHOW and addonFrame.events.UI_ERROR_MESSAGE, "Auto Repair should listen for the merchant and for refusals")

-- Gear to repair for 120 copper, 500 copper to spend, and a guild allowance
-- that covers it.
local function Reset(guildFunds)
    CarpenterDB.autoRepairGuildFundsEnabled = guildFunds
    shiftDown, repairCost, canRepair, money, guildRefuses = false, 120, true, 500, false
    canGuildRepair, allowance = true, 1000
    repairs, messages, timers = {}, {}, {}
    Carpenter.MerchantState = {}
end
local function OpenMerchant()
    addonFrame:OnEvent("MERCHANT_SHOW")
    RunTimers()
end
local function Refuse(message)
    addonFrame:OnEvent("UI_ERROR_MESSAGE", 1, message)
end
local function Expect(repairList, messageList, label)
    assert(table.concat(repairs, ",") == repairList, label .. ": expected repairs [" .. repairList .. "], got [" .. table.concat(repairs, ",") .. "]")
    assert(table.concat(messages, ",") == messageList, label .. ": expected messages [" .. messageList .. "], got [" .. table.concat(messages, ",") .. "]")
end

local OWN_LINE = "\226\136\146|r Gear repaired: 120|r"
local GUILD_LINE = "\226\136\146|r Gear repaired with guild funds: 120|r"

-- Off: the guild is never asked, and the summary counts the gold.
Reset(false)
OpenMerchant()
Expect("own", OWN_LINE, "option off")
assert(Carpenter.MerchantState.autoRepaired == true and Carpenter.MerchantState.autoRepairAmount == -120, "own gold should count toward the merchant summary")

-- A setting that was never saved reads as off.
Reset(nil)
OpenMerchant()
Expect("own", OWN_LINE, "option unset")

-- On: the guild pays, reported once the server had time to refuse.
Reset(true)
OpenMerchant()
Expect("guild", "", "guild repair before the result")
RunTimers()
Expect("guild", GUILD_LINE, "guild repair after the result")
assert(not Carpenter.MerchantState.autoRepaired and Carpenter.MerchantState.autoRepairAmount == nil, "guild money should stay out of the merchant summary")

-- The guild pays even when the player couldn't.
Reset(true)
money = 10
OpenMerchant()
RunTimers()
Expect("guild", GUILD_LINE, "player short on gold")

-- An allowance of exactly the cost covers it; the guild leader's -1 means no limit.
Reset(true)
allowance = 120
OpenMerchant()
RunTimers()
Expect("guild", GUILD_LINE, "allowance equal to the cost")
Reset(true)
allowance = -1
OpenMerchant()
RunTimers()
Expect("guild", GUILD_LINE, "guild leader")

-- The player pays when the guild can't.
Reset(true)
allowance = 119
OpenMerchant()
Expect("own", OWN_LINE, "allowance short by one")
Reset(true)
canGuildRepair = false
OpenMerchant()
Expect("own", OWN_LINE, "no guild repair permission")

-- Refused for a short bank: the player pays instead, and no guild line follows.
Reset(true)
guildRefuses = true
OpenMerchant()
Refuse(ERR_GUILD_NOT_ENOUGH_MONEY)
Expect("guild,own", OWN_LINE, "refused guild repair")
assert(Carpenter.MerchantState.autoRepairAmount == -120, "the fallback should count toward the merchant summary")
RunTimers()
Expect("guild,own", OWN_LINE, "refused guild repair after the result")

-- Refused and the player can't pay either: nothing is claimed.
Reset(true)
guildRefuses = true
money = 10
OpenMerchant()
Refuse(ERR_NOT_ENOUGH_MONEY)
RunTimers()
Expect("guild", "", "refused with no gold to fall back on")

-- Other errors, and any error with no repair waiting, change nothing.
Reset(true)
OpenMerchant()
Refuse("Interface action failed")
RunTimers()
Expect("guild", GUILD_LINE, "unrelated error")
Refuse(ERR_GUILD_NOT_ENOUGH_MONEY)
Expect("guild", GUILD_LINE, "refusal with nothing waiting")

-- A hidden error text can't be read, so it's left alone.
Reset(true)
local HIDDEN = {}
issecretvalue = function(value) return value == HIDDEN end
OpenMerchant()
Refuse(HIDDEN)
RunTimers()
Expect("guild", GUILD_LINE, "hidden error text")
issecretvalue = nil

-- Turning the feature off drops a repair still waiting for its result.
Reset(true)
OpenMerchant()
registeredFeature:Disable()
RunTimers()
Expect("guild", "", "turned off while waiting")
registeredFeature:Enable()

-- Holding Shift skips the repair, and there's nothing to do without damage.
Reset(true)
shiftDown = true
OpenMerchant()
Expect("", "", "shift held")
Reset(true)
repairCost, canRepair = 0, false
OpenMerchant()
Expect("", "", "nothing to repair")

-- Classic Era has no guild repair calls: the player pays.
Reset(true)
CanGuildBankRepair, GetGuildBankWithdrawMoney = nil, nil
OpenMerchant()
Expect("own", OWN_LINE, "client without guild repair")
InstallGuildCalls()

-- The checkbox is wired up, saved by default, and hidden on Classic Era.
local function Read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end
assert(Read("Core/Carpenter.lua"):find("autoRepairGuildFundsEnabled = false", 1, true), "the option should default to off")
assert(Read("Settings/ConfigSidebar.lua"):find("CarpenterDB.autoRepairGuildFundsEnabled = self:GetChecked()", 1, true), "the checkbox should save the option")
assert(Read("Settings/ConfigOptions.lua"):find("isVanilla) and ShowAutoRepairOptions", 1, true), "the checkbox should be hidden on Classic Era")

print("auto-repair fixtures: passed")
