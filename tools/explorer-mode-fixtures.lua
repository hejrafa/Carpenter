#!/usr/bin/env lua
-- Pins Explorer Mode's fading behavior: fade out after the delay, hover
-- reveal, combat and Edit Mode restores, hidden-health waiting, and restoring
-- original alphas when turned off. Drives the module through events, timers,
-- and OnUpdate only, so it holds across internal restructuring.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

local failures = {}
local function check(condition, message)
    if not condition then failures[#failures + 1] = message end
end

-- =========================
-- Game stubs
-- =========================
local now = 0
local inCombat = false
local healthSecret = false
local mouseOver = {}
local cursorX = 0
local editModeActive = false
local createdFrames = {}
local timers = {}

function GetTime() return now end
function InCombatLockdown() return inCombat end
function UnitHealth()
    if healthSecret then error("secret health") end
    return 100
end
function UnitHealthMax()
    if healthSecret then error("secret health") end
    return 100
end
function MouseIsOver(frameObject) return mouseOver[frameObject] == true end
function GetCursorPosition() return cursorX, 0 end
function hooksecurefunc() end

local function NewFrame(name, parent)
    local frameObject = {
        name = name, parent = parent, alpha = 1, shown = true,
        children = {}, regions = {}, scripts = {}, events = {},
    }
    function frameObject:GetName() return self.name end
    function frameObject:GetParent() return self.parent end
    function frameObject:SetAlpha(alpha) self.alpha = alpha end
    function frameObject:GetAlpha() return self.alpha end
    function frameObject:IsShown() return self.shown end
    function frameObject:Show() self.shown = true end
    function frameObject:Hide() self.shown = false end
    function frameObject:IsForbidden() return false end
    function frameObject:SetScript(script, handler) self.scripts[script] = handler end
    function frameObject:GetScript(script) return self.scripts[script] end
    function frameObject:HookScript() end
    function frameObject:RegisterEvent(event) self.events[event] = true end
    function frameObject:RegisterUnitEvent(event) self.events[event] = true end
    function frameObject:UnregisterEvent(event) self.events[event] = nil end
    function frameObject:UnregisterAllEvents() self.events = {} end
    function frameObject:GetRegions() return table.unpack(self.regions) end
    function frameObject:GetChildren() return table.unpack(self.children) end
    function frameObject:GetNumChildren() return #self.children end
    if parent then parent.children[#parent.children + 1] = frameObject end
    if name then _G[name] = frameObject end
    return frameObject
end

function CreateFrame(_, name, parent)
    local frameObject = NewFrame(name, parent)
    createdFrames[#createdFrames + 1] = frameObject
    return frameObject
end

UIParent = NewFrame("UIParent")
UIParent.GetEffectiveScale = function() return 1 end

local function NewCooldown(name, parent)
    local cooldown = NewFrame(name, parent)
    cooldown.draw = { SetDrawSwipe = true, SetDrawBling = true, SetDrawEdge = true }
    function cooldown:SetCooldown() end
    function cooldown:GetDrawSwipe() return self.draw.SetDrawSwipe end
    function cooldown:SetDrawSwipe(value) self.draw.SetDrawSwipe = value end
    function cooldown:GetDrawBling() return self.draw.SetDrawBling end
    function cooldown:SetDrawBling(value) self.draw.SetDrawBling = value end
    function cooldown:GetDrawEdge() return self.draw.SetDrawEdge end
    function cooldown:SetDrawEdge(value) self.draw.SetDrawEdge = value end
    return cooldown
end

local playerFrame = NewFrame("PlayerFrame", UIParent)
local playerTexture = { alpha = 1, SetAlpha = function(self, a) self.alpha = a end, GetAlpha = function(self) return self.alpha end }
playerFrame.regions = { playerTexture }
local targetFrame = NewFrame("TargetFrame", UIParent)
targetFrame.alpha = 0.8
local mainMenuBar = NewFrame("MainMenuBar", UIParent)
local actionButton = NewFrame("ActionButton1", mainMenuBar)
local cooldown = NewCooldown("ActionButton1Cooldown", actionButton)
actionButton.cooldown = cooldown
Minimap = NewFrame("Minimap", UIParent)

EditModeManagerFrame = { IsEditModeActive = function() return editModeActive end }

CarpenterDB = { explorerModeEnabled = true, explorerModeChatWindowRepairVersion = 1 }
local feature
Carpenter = {
    Client = { isTBC = true, isClassic = true },
    Deferred = {},
    IsEnabled = function(_, key) return CarpenterDB[key] == true end,
    Defer = function(self, key, delay, callback) self.Deferred[key] = { at = now + delay, callback = callback } end,
    After = function(_, delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end,
    SafeRegisterEvent = function(_, frameObject, event) frameObject:RegisterEvent(event) return true end,
    SafeRegisterUnitEvent = function(_, frameObject, event) frameObject:RegisterUnitEvent(event) return true end,
    RegisterFeature = function(_, key, registered)
        assert(key == "explorerModeEnabled", "unexpected feature key " .. tostring(key))
        feature = registered
    end,
}

local ns = { Private = {} }
local function Load(path)
    assert(loadfile(repo .. "/" .. path))("Carpenter", ns)
end

-- Load Explorer Mode the way the TOCs do: the module file or its folder.
local function LoadExplorerMode()
    local toc = io.open(repo .. "/Carpenter_TBC.toc"):read("*a")
    for line in toc:gmatch("[^\r\n]+") do
        local path = line:gsub("\\", "/")
        if path:find("ExplorerMode", 1, true) and path:match("%.lua$") then
            Load(path)
        end
    end
end
LoadExplorerMode()
assert(feature, "Explorer Mode should register its feature")
local ExplorerMode = ns.Private.ExplorerMode

-- =========================
-- Drivers
-- =========================
local function RunDue()
    local due = {}
    for key, entry in pairs(Carpenter.Deferred) do
        if entry.at <= now then due[#due + 1] = key end
    end
    for _, key in ipairs(due) do
        local entry = Carpenter.Deferred[key]
        if entry and entry.at <= now then
            Carpenter.Deferred[key] = nil
            entry.callback()
        end
    end
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
    end
end

local function Tick(seconds)
    local step = 0.05
    local steps = math.floor(seconds / step + 0.5)
    for _ = 1, steps do
        now = now + step
        cursorX = cursorX + 1
        RunDue()
        for _, frameObject in ipairs(createdFrames) do
            local onUpdate = frameObject.scripts.OnUpdate
            if onUpdate and frameObject.shown then
                onUpdate(frameObject, step)
            end
        end
    end
end

local function Fire(event, unit)
    for _, frameObject in ipairs(createdFrames) do
        if frameObject.events[event] and frameObject.scripts.OnEvent then
            frameObject.scripts.OnEvent(frameObject, event, unit)
        end
    end
end

local function Faded(frameObject) return frameObject.alpha < 0.01 end
local function Visible(frameObject) return frameObject.alpha > 0.99 end

-- =========================
-- Scenarios
-- =========================

-- 1. Turning it on fades the HUD out after the delay; the minimap stays.
feature:Enable()
Tick(0.5)
check(Visible(playerFrame), "HUD should stay visible during the fade-out delay")
Tick(5)
check(Faded(playerFrame) and Faded(targetFrame) and playerTexture.alpha < 0.01, "unit frames should fade out")
check(Faded(actionButton), "action buttons should fade out")
check(cooldown.draw.SetDrawSwipe == false, "cooldown swipes should hide while faded on Classic")
check(Visible(Minimap), "the minimap should never fade")
check(ExplorerMode.IsFaded(), "IsFaded should report the faded state")

-- 2. Hovering a frame brings it back, and it fades again after leaving.
mouseOver[playerFrame] = true
Tick(1)
check(Visible(playerFrame), "hovering should reveal the frame")
check(Faded(targetFrame), "hovering one frame should not reveal others")
mouseOver[playerFrame] = nil
Tick(3)
check(Faded(playerFrame), "the frame should fade again after the mouse leaves")

-- 3. Hovering an action button reveals the action bar cluster.
mouseOver[actionButton] = true
Tick(1)
check(Visible(actionButton), "hovering an action button should reveal the action bar")
check(cooldown.draw.SetDrawSwipe == true, "revealed buttons should show cooldown swipes again")
mouseOver[actionButton] = nil
Tick(3)
check(Faded(actionButton), "the action bar should fade again after the mouse leaves")

-- 4. Entering combat restores everything at once; leaving fades again.
inCombat = true
Fire("PLAYER_REGEN_DISABLED")
check(Visible(playerFrame) and Visible(actionButton), "combat should restore the HUD immediately")
check(cooldown.draw.SetDrawSwipe == true, "combat should restore cooldown swipes")
check(not ExplorerMode.IsFaded(), "combat should clear the faded state")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Tick(6)
check(Faded(playerFrame), "leaving combat should fade the HUD again")

-- 5. Edit Mode while faded restores the HUD.
editModeActive = true
local ok, err = pcall(Tick, 1)
check(ok, "hover driver errored in Edit Mode: " .. tostring(err))
check(Visible(playerFrame), "Edit Mode should restore the HUD")
editModeActive = false
Fire("PLAYER_TARGET_CHANGED")
Tick(6)
check(Faded(playerFrame), "leaving Edit Mode should fade the HUD again")

-- 6. Hidden health (Retail and Forever) waits for health to settle.
Carpenter.Client = { isRetail = true, isForever = true }
healthSecret = true
inCombat = true
Fire("PLAYER_REGEN_DISABLED")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Tick(3)
check(Visible(playerFrame), "hidden health should hold the fade until health settles")
Tick(5)
check(Faded(playerFrame), "hidden health should fade once health has settled")
Fire("UNIT_HEALTH", "player")
Tick(1)
check(Visible(playerFrame), "a hidden health change should bring the HUD back")
Tick(7)
check(Faded(playerFrame), "the HUD should fade again after hidden health settles")

-- 7. Turning it off restores every frame's original alpha.
CarpenterDB.explorerModeEnabled = false
feature:Disable()
check(Visible(playerFrame) and playerTexture.alpha > 0.99, "turning off should restore the player frame")
check(math.abs(targetFrame.alpha - 0.8) < 0.001, "turning off should restore the original alpha")
check(Visible(actionButton), "turning off should restore action buttons")
check(not ExplorerMode.IsFaded(), "turning off should clear the faded state")

if #failures > 0 then
    io.stderr:write(table.concat(failures, "\n") .. "\n")
    os.exit(1)
end

print("explorer mode fixtures passed")
