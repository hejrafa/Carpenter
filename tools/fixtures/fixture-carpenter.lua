-- Fills a fixture's Carpenter mock with the core helpers modules call
-- directly (Core/Carpenter.lua defines the real ones). Each mirrors the real
-- helper but runs on the globals the fixture mocks: C_Timer, hooksecurefunc.
-- A helper the fixture already mocked is kept.
--   Carpenter = dofile(repo .. "/tools/fixtures/fixture-carpenter.lua")(Carpenter)
return function(Carpenter)
    Carpenter = Carpenter or {}

    Carpenter.After = Carpenter.After or function(_, delay, callback)
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, callback)
        elseif delay == 0 then
            callback()
        end
    end

    Carpenter.SafeHook = Carpenter.SafeHook or function(_, target, method, handler)
        if type(target) == "string" and type(method) == "function" then
            if not hooksecurefunc or type(_G[target]) ~= "function" then return false end
            return pcall(hooksecurefunc, target, method) == true
        end
        if not hooksecurefunc or type(handler) ~= "function" then return false end
        if type(target) ~= "table" or type(method) ~= "string" then return false end
        if type(target[method]) ~= "function" then return false end
        return pcall(hooksecurefunc, target, method, handler) == true
    end

    Carpenter.SafeRegisterEvent = Carpenter.SafeRegisterEvent or function(_, frame, event)
        if not frame or not event or not frame.RegisterEvent then return false end
        return pcall(frame.RegisterEvent, frame, event) == true
    end

    Carpenter.SafeRegisterUnitEvent = Carpenter.SafeRegisterUnitEvent or function(_, frame, event, ...)
        if not frame or not event or not frame.RegisterUnitEvent then return false end
        return pcall(frame.RegisterUnitEvent, frame, event, ...) == true
    end

    Carpenter.Deferred = Carpenter.Deferred or {}
    Carpenter.Defer = Carpenter.Defer or function(self, key, delay, callback)
        if not key or type(callback) ~= "function" then return end
        local token = {}
        self.Deferred[key] = token
        self:After(delay or 0, function()
            if self.Deferred[key] ~= token then return end
            self.Deferred[key] = nil
            callback()
        end)
    end

    Carpenter.DeferMany = Carpenter.DeferMany or function(self, key, delays, callback)
        if not key or type(delays) ~= "table" or type(callback) ~= "function" then return end
        local token = {}
        local remaining = #delays
        self.Deferred[key] = token
        for _, delay in ipairs(delays) do
            self:After(delay or 0, function()
                if self.Deferred[key] ~= token then return end
                remaining = remaining - 1
                if remaining <= 0 then self.Deferred[key] = nil end
                callback()
            end)
        end
    end

    -- Fixtures call RunAfterCombatQueue where the game would fire
    -- PLAYER_REGEN_ENABLED. Errors propagate, so a failing callback fails.
    Carpenter.AfterCombatQueue = Carpenter.AfterCombatQueue or {}
    Carpenter.AfterCombat = Carpenter.AfterCombat or function(self, key, callback)
        if not key or type(callback) ~= "function" then return end
        self.AfterCombatQueue[key] = callback
    end
    Carpenter.CancelAfterCombat = Carpenter.CancelAfterCombat or function(self, key)
        if key then self.AfterCombatQueue[key] = nil end
    end
    Carpenter.RunAfterCombatQueue = Carpenter.RunAfterCombatQueue or function(self)
        local queue = self.AfterCombatQueue
        self.AfterCombatQueue = {}
        for _, callback in pairs(queue) do callback() end
    end

    Carpenter.RunStartupPasses = Carpenter.RunStartupPasses or function(self, key, delays, callback)
        if type(callback) ~= "function" then return end
        if key and type(delays) == "table" then
            self:DeferMany(key, delays, callback)
        elseif type(delays) ~= "table" then
            callback()
        else
            for _, delay in ipairs(delays) do self:After(delay or 0, callback) end
        end
    end

    Carpenter.Tickers = Carpenter.Tickers or {}
    Carpenter.StartTicker = Carpenter.StartTicker or function(self, key, interval, callback)
        if not key or type(callback) ~= "function" then return nil end
        self:StopTicker(key)
        if C_Timer and C_Timer.NewTicker then
            local ticker = C_Timer.NewTicker(interval or 1, callback)
            self.Tickers[key] = ticker
            return ticker
        end
        self.Tickers[key] = { callback = callback, interval = interval or 1 }
        return self.Tickers[key]
    end

    Carpenter.StopTicker = Carpenter.StopTicker or function(self, key)
        local ticker = key and self.Tickers[key]
        if ticker and ticker.Cancel then ticker:Cancel() end
        if key then self.Tickers[key] = nil end
    end

    return Carpenter
end
