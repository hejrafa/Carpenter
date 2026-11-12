#!/usr/bin/env lua
-- Offline fixture checks for the Forever target level fix.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then repo = repo:sub(1, -2) end
local H = dofile(repo .. "/tools/fixtures/fixture-harness.lua")(repo, "forever-target-level")
local fail, assertEqual = H.fail, H.assertEqual

H.installCreateFrame()
H.installHooks()

-- A target frame as Forever builds it: the number and the skull share the
-- level circle, in two sibling frames.
local units = {}
local function NewTargetFrame(name, unit)
    local frame = H.NamedFrame(name, { unit = unit, showLevel = true })
    local main = H.Frame({ parent = frame })
    local contextual = H.Frame({ parent = frame })
    main.LevelText = H.Frame({ parent = main, text = "" })
    function main.LevelText:SetText(text) self.text = tostring(text) end
    contextual.HighLevelTexture = H.Frame({ parent = contextual, shown = false })
    frame.TargetFrameContent = { TargetFrameContentMain = main, TargetFrameContentContextual = contextual }

    -- TargetFrameMixin:CheckLevel (Mainline, used by Forever).
    function frame:CheckLevel()
        local info = units[self.unit] or {}
        local levelText = self.TargetFrameContent.TargetFrameContentMain.LevelText
        local skull = self.TargetFrameContent.TargetFrameContentContextual.HighLevelTexture
        if info.level and info.level > 0 then
            levelText:SetText(info.level)
            levelText:Show()
            skull:Hide()
        else
            levelText:Hide()
            skull:Show()
        end
    end
    -- Camelot's override: shows the number for anything but a battle pet.
    function frame:CheckBattlePet()
        local isBattlePet = (units[self.unit] or {}).battlePet == true
        self.TargetFrameContent.TargetFrameContentMain.LevelText:SetShown(not isBattlePet)
    end
    -- TargetFrameMixin:Update, as far as the level goes.
    function frame:Update()
        if self.showLevel then self:CheckLevel() end
        self:CheckBattlePet()
    end
    return frame
end

local function Shown(frame)
    local levelText = frame.TargetFrameContent.TargetFrameContentMain.LevelText
    local skull = frame.TargetFrameContent.TargetFrameContentContextual.HighLevelTexture
    return levelText.shown, skull.shown, levelText.text
end

local function Load(isForever)
    H.carpenter({ Client = { isForever = isForever, isMainline = true } })
    H.load("Modules/ForeverTargetLevel.lua")
end

-- =========================
-- WoW Forever
-- =========================
local target = NewTargetFrame("TargetFrame", "target")
local focus = NewTargetFrame("FocusFrame", "focus")
local boss = NewTargetFrame("Boss1TargetFrame", "boss1")

-- Without the fix, Blizzard's own update shows the old number with the skull.
units.target = { level = 20 }
target:Update()
units.target = { level = -1 }
target:Update()
local levelShown, skullShown, text = Shown(target)
if not (levelShown and skullShown and text == "20") then
    fail("the fixture should reproduce the skull showing with the last target's level")
end

Load(true)
levelShown, skullShown = Shown(target)
assertEqual(levelShown, false, "loading should hide a stale number already behind the skull")
assertEqual(skullShown, true, "loading should leave the skull")

units.target = { level = 20 }
target:Update()
levelShown, skullShown, text = Shown(target)
assertEqual(levelShown, true, "a normal target should show its level")
assertEqual(skullShown, false, "a normal target should show no skull")
assertEqual(text, "20", "a normal target should show its own level")

units.target = { level = -1 }
target:Update()
levelShown, skullShown = Shown(target)
assertEqual(levelShown, false, "a skull target should show no number")
assertEqual(skullShown, true, "a skull target should keep the skull")

-- A level change on the same skull target runs CheckLevel alone.
target:CheckLevel()
assertEqual((Shown(target)), false, "a level event on a skull target should show no number")

units.target = { level = 26 }
target:Update()
levelShown, skullShown, text = Shown(target)
assertEqual(levelShown, true, "the next normal target should show its level again")
assertEqual(text, "26", "the next normal target should show its own level")

-- A battle pet keeps Blizzard's handling: no number, and no skull from us.
units.target = { level = 5, battlePet = true }
target:Update()
assertEqual((Shown(target)), false, "a battle pet should show no number")

units.focus = { level = 20 }
focus:Update()
units.focus = { level = -1 }
focus:Update()
assertEqual((Shown(focus)), false, "the focus frame should show no number with the skull")

units.boss1 = { level = -1 }
boss:Update()
assertEqual((Shown(boss)), false, "a boss frame should show no number with the skull")

-- A frame made after load is hooked at login.
local lateBoss = NewTargetFrame("Boss2TargetFrame", "boss2")
local loginFrame = H.createdFrames[#H.createdFrames]
if not (loginFrame and loginFrame.events.PLAYER_LOGIN) then fail("the fix should wait for PLAYER_LOGIN") end
loginFrame.scripts.OnEvent(loginFrame, "PLAYER_LOGIN")
units.boss2 = { level = 20 }
lateBoss:Update()
units.boss2 = { level = -1 }
lateBoss:Update()
assertEqual((Shown(lateBoss)), false, "a frame made after load should show no number with the skull")

-- =========================
-- Other clients
-- =========================
local retailTarget = NewTargetFrame("TargetFrame", "target")
units.target = { level = 20 }
retailTarget:Update()
Load(false)
units.target = { level = -1 }
retailTarget:Update()
assertEqual((Shown(retailTarget)), true, "other clients should be left alone")

print("forever-target-level fixtures passed")
