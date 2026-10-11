-- Makes a newer Lua behave like Lua 5.1, which WoW and the release CI run, so
-- fixtures that rely on 5.2+ features fail locally instead of in CI.
-- release.sh loads this before every fixture and check.
if _VERSION == "Lua 5.1" then return end

-- 5.1 has a global unpack and none of the newer library functions.
unpack = unpack or table.unpack
table.unpack, table.pack, table.move = nil, nil, nil
string.pack, string.unpack, string.packsize = nil, nil, nil
math.type, math.tointeger = nil, nil
utf8 = nil

-- 5.1's loadfile takes only a file name; environments come from setfenv.
local loadFile = loadfile
loadfile = function(path)
    return loadFile(path)
end

setfenv = function(fn, env)
    local index = 1
    while true do
        local name = debug.getupvalue(fn, index)
        if name == nil then break end
        if name == "_ENV" then
            debug.upvaluejoin(fn, index, function() return env end, 1)
            break
        end
        index = index + 1
    end
    return fn
end

-- 5.1's load only takes a function; strings go through loadstring.
local loadChunk = load
loadstring = function(text, name)
    return loadChunk(text, name)
end
load = function(chunk, ...)
    if type(chunk) == "string" then
        error("load(string) needs Lua 5.2+; use loadstring", 2)
    end
    return loadChunk(chunk, ...)
end
