-- Shared harness for the offline fixtures: assertion helpers, a frame mock,
-- and installers for the game globals most modules touch (CreateFrame,
-- hooksecurefunc, C_Timer, GetCursorPosition, UIParent) plus a Carpenter
-- mock filled with the core helpers (tools/fixture-carpenter.lua).
--
--   local H = dofile(repo .. "/tools/fixture-harness.lua")(repo, "chat-fade")
--   H.installCreateFrame(); H.installHooks(); H.installCursor(); H.installUIParent()
--   H.carpenter({ IsEnabled = ..., RegisterFeature = H.captureFeature("chatFadeEnabled") })
--   H.load("Core/HoverFade.lua"); H.load("Modules/ChatFade.lua")
--   H.settle(30, 0.1)   -- runs the last OnUpdate handler 30 times at 0.1s
--
-- Frames are plain tables with per-instance methods, so a fixture can
-- replace or remove any method on one frame (frame.IsMouseOver = nil).
local unpack = unpack or table.unpack

return function(repo, name)
    local H = {
        repo = repo,
        name = name or "fixture",
        createdFrames = {},
        scripts = {},
        timers = {},
        features = {},
        cursor = { x = 0, y = 0 },
    }

    -- =========================
    -- Assertions
    -- =========================
    function H.fail(message)
        io.stderr:write(H.name .. " fixture failed: " .. tostring(message) .. "\n")
        os.exit(1)
    end

    function H.assertEqual(actual, expected, message)
        if actual ~= expected then
            H.fail(message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
        end
    end

    function H.assertTrue(value, message)
        if not value then H.fail(message) end
    end

    function H.assertContains(text, needle, label)
        if type(text) ~= "string" or not text:find(needle, 1, true) then
            H.fail(label .. " is missing")
        end
    end

    -- =========================
    -- Frame mock
    -- =========================
    -- Fields: name, parent, left, bottom, width, height, scale, alpha,
    -- shown, visible (overrides the shown-and-parent rule), mouseOver.
    local methods = {}

    function methods:GetName() return self.name end
    function methods:GetParent() return self.parent end
    function methods:SetParent(parent) self.parent = parent end
    function methods:GetObjectType() return self.objectType or "Frame" end
    function methods:IsForbidden() return false end
    function methods:IsProtected() return false end

    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:SetShown(shown) self.shown = shown and true or false end
    function methods:IsShown() return self.shown end
    function methods:IsVisible()
        if self.visible ~= nil then return self.visible end
        if not self.shown then return false end
        local parent = self.parent
        return parent == nil or not parent.IsVisible or parent:IsVisible()
    end

    function methods:GetAlpha() return self.alpha end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:SetIgnoreParentAlpha(ignore) self.ignoreParentAlpha = ignore end
    function methods:IsIgnoringParentAlpha() return self.ignoreParentAlpha == true end

    function methods:GetLeft() return self.left end
    function methods:GetBottom() return self.bottom end
    function methods:GetRight() return self.left and self.left + (self.width or 0) end
    function methods:GetTop() return self.bottom and self.bottom + (self.height or 0) end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetWidth(width) self.width = width end
    function methods:SetHeight(height) self.height = height end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:GetSize() return self.width, self.height end
    function methods:GetScale() return self.scale or 1 end
    function methods:SetScale(scale) self.scale = scale end
    function methods:GetEffectiveScale() return self.scale or 1 end

    function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function methods:ClearAllPoints() self.points = {} end
    function methods:GetNumPoints() return #self.points end
    function methods:GetPoint(index) local point = self.points[index or 1]; if point then return unpack(point) end end
    function methods:SetFrameStrata(strata) self.strata = strata end
    function methods:GetFrameStrata() return self.strata end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:GetFrameLevel() return self.level or 0 end
    function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
    function methods:IsMouseEnabled() return self.mouseEnabled == true end
    function methods:IsMouseOver() return self.mouseOver == true end
    function methods:SetAttribute(key, value) self.attributes[key] = value end
    function methods:GetAttribute(key) return self.attributes[key] end

    -- The latest handler for each script name is also kept in H.scripts, so
    -- a fixture can drive a module's OnUpdate without finding its frame.
    function methods:SetScript(script, handler)
        self.scripts[script] = handler
        H.scripts[script] = handler and { frame = self, handler = handler } or nil
    end
    function methods:GetScript(script) return self.scripts[script] end
    function methods:HasScript() return true end
    function methods:HookScript(script, handler)
        local existing = self.scripts[script]
        self.scripts[script] = function(...)
            if existing then existing(...) end
            handler(...)
        end
    end

    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:RegisterUnitEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:UnregisterAllEvents() self.events = {} end
    function methods:IsEventRegistered(event) return self.events[event] == true end

    function methods:GetRegions() return unpack(self.regions) end
    function methods:GetNumRegions() return #self.regions end
    function methods:GetChildren() return unpack(self.children) end
    function methods:GetNumChildren() return #self.children end

    function H.Frame(fields)
        local frame = { alpha = 1, shown = true, scripts = {}, events = {}, points = {}, regions = {}, children = {}, attributes = {} }
        for key, method in pairs(methods) do frame[key] = method end
        for key, value in pairs(fields or {}) do frame[key] = value end
        if frame.parent and frame.parent.children then
            table.insert(frame.parent.children, frame)
        end
        return frame
    end

    -- A frame the module reaches by global name.
    function H.NamedFrame(name, fields)
        fields = fields or {}
        fields.name = name
        local frame = H.Frame(fields)
        _G[name] = frame
        return frame
    end

    -- =========================
    -- Game globals
    -- =========================
    function H.installCreateFrame()
        CreateFrame = function(_, frameName, parent)
            local frame = H.Frame({ name = frameName, parent = parent })
            H.createdFrames[#H.createdFrames + 1] = frame
            if frameName then _G[frameName] = frame end
            return frame
        end
        return H.createdFrames
    end

    -- hooksecurefunc(table, "Method", hook) and hooksecurefunc("Global", hook):
    -- the hook runs after the original with the same arguments.
    function H.installHooks()
        hooksecurefunc = function(target, method, hook)
            if type(target) == "string" then
                target, method, hook = _G, target, method
            end
            local original = target[method]
            if type(original) ~= "function" then
                error("hooksecurefunc: " .. tostring(method) .. " is not a function")
            end
            target[method] = function(...)
                local results = { original(...) }
                hook(...)
                return unpack(results)
            end
        end
    end

    -- C_Timer modes: "ignore" drops callbacks, "immediate" runs them at once,
    -- "queue" keeps them in H.timers for H.runTimers().
    function H.installTimers(mode)
        mode = mode or "immediate"
        local function schedule(delay, callback)
            if mode == "immediate" then
                callback()
            elseif mode == "queue" then
                H.timers[#H.timers + 1] = { delay = delay, callback = callback }
            end
        end
        C_Timer = {
            After = schedule,
            NewTicker = function(interval, callback)
                local ticker = { interval = interval, callback = callback, cancelled = false }
                function ticker:Cancel() self.cancelled = true end
                H.timers[#H.timers + 1] = ticker
                return ticker
            end,
        }
    end

    function H.runTimers()
        local pending = H.timers
        H.timers = {}
        for _, timer in ipairs(pending) do
            if timer.callback and not timer.cancelled then timer.callback() end
        end
    end

    function H.installCursor()
        GetCursorPosition = function() return H.cursor.x, H.cursor.y end
    end

    function H.setCursor(x, y)
        H.cursor.x, H.cursor.y = x, y
    end

    function H.installUIParent(width, height)
        return H.NamedFrame("UIParent", { left = 0, bottom = 0, width = width or 1920, height = height or 1080 })
    end

    -- =========================
    -- Carpenter and modules
    -- =========================
    -- A RegisterFeature that keeps the feature for key in H.features[key].
    function H.captureFeature(expectedKey)
        return function(_, key, feature)
            if expectedKey and key ~= expectedKey then
                H.fail("unexpected feature key " .. tostring(key))
            end
            H.features[key] = feature
        end
    end

    function H.carpenter(fields)
        Carpenter = dofile(repo .. "/tools/fixture-carpenter.lua")(fields or {})
        return Carpenter
    end

    function H.load(path, ns)
        local chunk, err = loadfile(repo .. "/" .. path)
        if not chunk then H.fail(err) end
        return chunk("Carpenter", ns or { Private = {} })
    end

    -- Runs the latest handler for script (OnUpdate by default) times over.
    function H.settle(times, elapsed, script)
        local entry = H.scripts[script or "OnUpdate"]
        if not entry then H.fail("no " .. (script or "OnUpdate") .. " handler was registered") end
        for _ = 1, times or 30 do
            entry.handler(entry.frame, elapsed or 0.1)
        end
    end

    return H
end
