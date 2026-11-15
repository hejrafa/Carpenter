--[[ Carpenter - secret values ]]
-- Retail and WoW Forever hide some values from addons: names and amounts in
-- combat, chat lines from the game's own channels, answers about units out of
-- reach. The game calls them secret. An addon may hand one back to the game,
-- but reading, comparing or doing math with it is an error. Classic has no
-- secret values, so there every value is readable.
--
-- Modules ask here instead of calling issecretvalue themselves;
-- tools/check-addon-shape.lua keeps it that way.
Carpenter = Carpenter or {}

local Secret = Carpenter.Secret or {}
Carpenter.Secret = Secret

-- Whether this client hides values from addons at all.
function Secret.ClientHidesValues()
    return type(issecretvalue) == "function"
end

-- True for a value the game hides from addons.
function Secret.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- True for a value that is there and that this addon may read.
function Secret.IsReadable(value)
    return value ~= nil and not Secret.IsSecret(value)
end

-- The value when it is a string with something in it that this addon may
-- read, else nil.
function Secret.ReadableString(value)
    if Secret.IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

-- The value when it is a number this addon may read, else nil.
function Secret.ReadableNumber(value)
    if Secret.IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

-- A yes/no answer from the game: true or false, or nil when the call failed
-- or the answer is hidden.
function Secret.ReadableBool(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or Secret.IsSecret(value) then return nil end
    return value == true
end
