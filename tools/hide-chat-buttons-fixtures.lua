#!/usr/bin/env lua
-- Offline fixture checks for Hide Chat Buttons hover API compatibility.

local repo = arg and arg[1] or "."
if repo:sub(-1) == "/" then
    repo = repo:sub(1, -2)
end

unpack = unpack or table.unpack

local registeredFeature
local createdFrames = {}

CarpenterDB = { hideChatButtonsEnabled = true }
Carpenter = {
    Client = { isClassic = false },
    IsEnabled = function(_, key)
        return CarpenterDB[key] == true
    end,
    RegisterFeature = function(_, key, feature)
        if key == "hideChatButtonsEnabled" then
            registeredFeature = feature
        end
    end,
    DeferMany = function() end,
}

local function NewFrame(name)
    local frame = {
        name = name,
        alpha = 1,
        mouseOver = false,
        scripts = {},
        shown = true,
    }

    function frame:SetPoint() end
    function frame:SetFrameStrata() end
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents() end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsMouseOver() return self.mouseOver end

    return frame
end

UIParent = NewFrame("UIParent")
ChatFrame1 = NewFrame("ChatFrame1")
ChatFrame1Tab = NewFrame("ChatFrame1Tab")
ChatFrameMenuButton = NewFrame("ChatFrameMenuButton")
NUM_CHAT_WINDOWS = 1

function CreateFrame(_, name)
    local frame = NewFrame(name)
    createdFrames[#createdFrames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

function hooksecurefunc(target, method, handler)
    local original = target and target[method]
    if type(original) ~= "function" then return end

    target[method] = function(...)
        local results = { original(...) }
        handler(...)
        return unpack(results)
    end
end

C_Timer = { After = function() end }
MouseIsOver = nil

local function fail(message)
    io.stderr:write("hide-chat-buttons fixture failed: " .. message .. "\n")
    os.exit(1)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
    end
end

local function runUpdate(hoverFrame)
    local handler = hoverFrame.scripts.OnUpdate
    if not handler then fail("hover frame has no OnUpdate handler") end
    local ok, err = pcall(handler, hoverFrame, 0.05)
    if not ok then fail("hover update errored: " .. tostring(err)) end
end

local chunk, err = loadfile(repo .. "/Modules/HideChatButtons.lua")
if not chunk then error(err) end
chunk("Carpenter", {})

if not registeredFeature then fail("Hide Chat Buttons did not register its feature") end
local hoverFrame = createdFrames[1]
if not hoverFrame then fail("Hide Chat Buttons did not create its hover frame") end

registeredFeature:Enable()

-- Retail no longer guarantees the legacy MouseIsOver global. The frame method
-- must drive hover fading without it.
hoverFrame.mouseOver = true
runUpdate(hoverFrame)
assertEqual(ChatFrame1Tab.alpha, 0.25, "frame-method hover did not start the fade")

-- Older clients can still fall back to the legacy global if a region does not
-- expose IsMouseOver as a method.
hoverFrame.IsMouseOver = nil
hoverFrame.legacyMouseOver = true
MouseIsOver = function(frame) return frame.legacyMouseOver == true end
runUpdate(hoverFrame)
assertEqual(ChatFrame1Tab.alpha, 0.5, "legacy hover fallback did not continue the fade")

print("hide-chat-buttons fixtures: passed")
