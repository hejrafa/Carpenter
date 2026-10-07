--[[ Carpenter - Chat Slang engine ]]
-- Finds glossary terms in a chat line, picks a meaning from nearby words, and
-- spells the whole line out in plain words. The context rules are adapted from
-- SlangSight by PacHD (MIT License, see LICENSE-SlangSight.txt).
local _, ns = ...
ns.Private = ns.Private or {}

local Engine = ns.Private.ChatSlangEngine or {}
ns.Private.ChatSlangEngine = Engine

local glossary = ns.Private.ChatSlangGlossary or {}
Engine.Glossary = glossary

local MAX_TERMS = 12
local MAX_MESSAGE_BYTES = 4096
local CONTEXT_RADIUS = 65
local BEFORE_RADIUS = 30

-- Searchable glossary entries that are too short or generic to link in chat.
local SEARCH_ONLY = {
    X = true, ["1"] = true, C = true, R = true, ["123"] = true,
}

-- Everyday words with a WoW meaning. They only link when typed in capitals, so
-- "if you need a tank" stays plain while "LFM BRD, IF meetup" still explains.
local CAPS_ONLY = {
    AD = true, ADD = true, ADDON = true, ADDS = true, AH = true, AM = true,
    ARM = true, ARMOR = true, ATTUNEMENT = true, AVATAR = true, BACKPEDAL = true,
    BEAR = true, BENCH = true, BIND = true, BOOST = true, BOSS = true, BOT = true,
    BOW = true, BRACKET = true, BUFF = true, BUILD = true, BURST = true,
    CAMP = true, CAMPER = true, CAP = true, CARRY = true, CASTER = true,
    CLEAR = true, CLEAVE = true, CRAFT = true, DE = true, DEBUFF = true,
    DISPEL = true, DRUID = true, DUNGEON = true, EVADE = true, EXALTED = true,
    ["EFFECTIVE HEALING"] = true, FARM = true, FARMED = true, FEAR = true,
    ["GOLD FARMER"] = true, GREED = true, GRIEF = true, GRIEFER = true,
    GRIND = true, GRINDING = true, GUILD = true, HATE = true, HEAL = true,
    HEALS = true, HERB = true, HIT = true, HM = true, HONOR = true, HOP = true,
    HOT = true, HUNT = true, HUNTER = true, IF = true, INCOMING = true,
    INTERRUPT = true, INVITE = true, KICK = true, LAP = true, LEAD = true,
    LIP = true, LOCK = true, LOCKOUT = true, LOOT = true, LOS = true,
    MAGE = true, MAIN = true, MARK = true, MINING = true, MOB = true,
    MOBS = true, MOO = true, MOUNT = true, NEED = true, NEWBIE = true,
    NODE = true, OFFICER = true, OPENER = true, ORE = true, OVERHEALING = true,
    PACK = true, PASS = true, PAT = true, PATROL = true, PATTERN = true,
    PET = true, PORT = true, POT = true, PRIEST = true, PULL = true,
    PURGE = true, QUEST = true, RAID = true, RECIPE = true, RESET = true,
    RESPAWN = true, ROGUE = true, ROLL = true, ROOT = true, ROSTER = true,
    ROTATION = true, SHAMAN = true, SHARD = true, SHEEP = true, SKIN = true,
    SOULBOUND = true, SPAWN = true, STACK = true, STUN = true, SUMMON = true,
    TAG = true, TAILOR = true, TANK = true, TAP = true, TAUNT = true,
    THREAT = true, TRASH = true, TRIAL = true, TRINKET = true, VENDOR = true,
    ["VENDOR TRASH"] = true, WAND = true, WAR = true, WIPE = true, WOW = true,
    ["GRAND MARSHAL"] = true, ["HILLSBRAD FOOTHILLS"] = true, GADGETZAN = true,
}

local REPLACEMENTS = {
    LFM = "Looking for more players:",
    LFG = "Looking for a group",
    LF1M = "Looking for one more player",
    LF2M = "Looking for two more players",
    WTB = "Want to buy",
    WTS = "Want to sell",
    PST = "whisper if interested",
    HR = "reserved for a specified player",
    NBG = "Need Before Greed",
    IDC = "I don't care",
    NEED = "need",
    TRINKET = "trinket",
}

-- Slash-separated titles that are one idea rather than competing meanings.
local EQUIVALENT = {
    HP = true, MEZ = true, LOOT = true, JC = true, HEAL = true, HEALS = true,
    HERB = true, HIT = true, IMHO = true, BIND = true, MOB = true, MOONKIN = true,
    ["MS/OS"] = true, ["SM/RUIN"] = true, ["DS/RUIN"] = true, ["MD/RUIN"] = true,
    ["NF/SL"] = true, ["NF/CONFLAG"] = true, ["SL/SB"] = true, ["MARA BLUE"] = true,
    JED = true, SOAK = true, X = true,
}

local trie

local function IsPlainString(value)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "string"
end
Engine.IsPlainString = IsPlainString

local function IsWordChar(char)
    return char ~= "" and char:match("[%w_]") ~= nil
end

local function BuildTrie()
    trie = {}
    for key, entry in pairs(glossary) do
        if not SEARCH_ONLY[key] then
            local node = trie
            for i = 1, #key do
                local char = key:sub(i, i)
                node[char] = node[char] or {}
                node = node[char]
            end
            node.entry = entry
        end
    end
end

-- Every glossary key that starts at pos and ends on a word boundary, longest
-- first, so "LFM TANK" wins over "LFM" but "LFM" still applies if it must.
local function FindCandidates(upper, pos)
    if not trie then BuildTrie() end
    local candidates
    local node = trie
    local cursor = pos
    while cursor <= #upper do
        node = node[upper:sub(cursor, cursor)]
        if not node then break end
        if node.entry and not IsWordChar(upper:sub(cursor + 1, cursor + 1)) then
            candidates = candidates or {}
            table.insert(candidates, 1, { entry = node.entry, finish = cursor })
        end
        cursor = cursor + 1
    end
    return candidates
end

local function HasWord(text, list)
    for token in list:gmatch("[^,]+") do
        if text:find("%f[%w]" .. token .. "%f[%W]") then return true end
    end
    return false
end

-- context is the lowercase message with link labels blanked out; start and
-- finish are the term's byte positions inside it.
local function Resolve(entry, context, start, finish)
    local key = entry.key
    local near = context:sub(math.max(1, start - CONTEXT_RADIUS), math.min(#context, finish + CONTEXT_RADIUS))
    local before = context:sub(math.max(1, start - BEFORE_RADIUS), start - 1)

    if key == "OH" then
        if not HasWord(near, "weapon,weapons,dagger,sword,mace,axe,shield,equip,equipped,slot,mainhand,offhand,mh,dps,upgrade") then
            return nil
        end
        return "Off Hand", false, true
    elseif key == "GS" then
        local score = HasWord(near, "score,gearscore,minimum,required") or before:match("your%s*$") ~= nil or near:match("%d%d%d%d") ~= nil
        local town = HasWord(near, "meet,heading,travel,going")
        local set = HasWord(near, "shoulders,armor,pieces,set")
        if score and not town and not set then return "GearScore", false, true end
        if town and not score and not set then return "Goldshire", false, true end
        if set and not score and not town then return "Giantstalker", false, true end
    elseif key == "VC" then
        local voice = HasWord(near, "discord,voice,mic,microphone,speak,talk")
        local dungeon = HasWord(near, "deadmines,van,cleef,dungeon")
        if voice and not dungeon then return "Voice Chat", false, true end
        if dungeon and not voice then return "The Deadmines", false, true end
    elseif key == "WF" then
        local travel = HasWord(near, "heading,travelling,traveling,westfall,stormwind,meet")
        local spell = HasWord(near, "shaman,totem,windfury,buff")
        if travel and not spell then return "Westfall", false, true end
        if spell and not travel then return "Windfury", false, true end
    elseif key == "DM" then
        local private = HasWord(near, "whisper,pm,message,discord") or near:match("dm%s+me") ~= nil or near:match("send%s+me%s+a%s+dm") ~= nil
        local deadmines = HasWord(near, "deadmines,van,cleef,westfall")
        local direMaul = HasWord(near, "dire,maul,tribute,feralas,dme,dmn,dmw") or near:match("dm%s+north") ~= nil or near:match("dm%s+east") ~= nil or near:match("dm%s+west") ~= nil
        if private and not deadmines and not direMaul then return "direct message", false, true end
        if deadmines and not private and not direMaul then return "The Deadmines", false, true end
        if direMaul and not private and not deadmines then return "Dire Maul", false, true end
    elseif key == "HS" then
        local home = HasWord(near, "hearth,hearthstone,inn,innkeeper") or near:match("hs%s+home") ~= nil
        local health = HasWord(near, "healthstone,healthstones,warlock,lock,cookies,heal,healing")
        local strike = HasWord(near, "heroic,strike,rage,queue,queued")
        if home and not health and not strike then return "Hearthstone", false, true end
        if health and not home and not strike then return "Healthstone", false, true end
        if strike and not home and not health then return "Heroic Strike", false, true end
    elseif key == "RES" then
        local loot = HasWord(near, "loot,item,trinket,drop,drops,reserved,hr") or near:match("hard%s+res") ~= nil or near:match("soft%s+res") ~= nil
        local resistance = HasWord(near, "resistance,fire,frost,nature,shadow,arcane")
        local resurrection = HasWord(near, "dead,corpse,rez,resurrect,resurrection") or near:match("res%s+me") ~= nil
        if loot and not resistance and not resurrection then return "reserved", false, true end
        if resistance and not loot and not resurrection then return "resistance", false, true end
        if resurrection and not loot and not resistance then return "resurrection", false, true end
    elseif key == "MT" then
        local choices = {
            { HasWord(near, "tank,tanking,aggro,threat,offtank") or near:match("mt%s+pull") ~= nil, "Main Tank" },
            { HasWord(near, "mistell,channel,chat") or near:match("wrong%s+person") ~= nil, "Mistell" },
            { HasWord(near, "typo,mistype,typing,spelling"), "Mistype" },
            { HasWord(near, "auchindoun") or near:match("mana[%s%-]+tombs") ~= nil, "Mana-Tombs" },
            { HasWord(near, "magisters") or near:match("quel[%s']+danas") ~= nil, "Magisters' Terrace" },
        }
        local selected, count = nil, 0
        for _, choice in ipairs(choices) do
            if choice[1] then
                selected = choice[2]
                count = count + 1
            end
        end
        if count == 1 then return selected, false, true end
    elseif key == "DD" or key == "DPS" then
        if HasWord(near, "lfm,lf1m,lf2m,need,recruiting") then return "damage dealer", false, true end
    end

    local ambiguous = entry.title:find(" / ", 1, true) and not EQUIVALENT[key]
    return REPLACEMENTS[key] or entry.title, ambiguous and true or false, false
end
Engine.Resolve = Resolve

-- Splits a chat line into plain text and escape sequences. Hyperlinks,
-- textures, and protected strings are copied untouched; their labels show in
-- the plain-words line but never count as context.
local function Segment(message)
    local segments = {}
    local contextParts = {}
    local contextLength = 0

    local function AddPlain(text)
        if text == "" then return end
        segments[#segments + 1] = { plain = true, raw = text, offset = contextLength }
        contextParts[#contextParts + 1] = text
        contextLength = contextLength + #text
    end

    local function AddEscape(raw, display)
        segments[#segments + 1] = { raw = raw, display = display or "" }
        if display and display ~= "" then
            contextParts[#contextParts + 1] = " "
            contextLength = contextLength + 1
        end
    end

    local pos = 1
    while pos <= #message do
        local bar = message:find("|", pos, true)
        if not bar then
            AddPlain(message:sub(pos))
            break
        end
        AddPlain(message:sub(pos, bar - 1))

        local kind = message:sub(bar + 1, bar + 1)
        local finish, display
        if kind == "H" then
            local labelStart = message:find("|h", bar + 2, true)
            local labelEnd = labelStart and message:find("|h", labelStart + 2, true)
            if labelEnd then
                finish = labelEnd + 1
                display = message:sub(labelStart + 2, labelEnd - 1):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            end
        elseif kind == "T" or kind == "A" or kind == "K" then
            local closer = message:find("|" .. kind:lower(), bar + 2, true)
            if closer then
                finish = closer + 1
                display = ""
            end
        elseif kind == "c" then
            local named = message:match("^|cn[%w_]+:", bar)
            if named then
                finish = bar + #named - 1
            elseif message:sub(bar + 2, bar + 9):match("^%x%x%x%x%x%x%x%x$") then
                finish = bar + 9
            end
        elseif kind == "r" then
            finish = bar + 1
        elseif kind == "|" then
            finish = bar + 1
            display = "|"
        end

        if not finish then
            -- Unterminated or unknown escape: keep the rest verbatim.
            AddEscape(message:sub(bar), "")
            break
        end
        AddEscape(message:sub(bar, finish), display)
        pos = finish + 1
    end

    return segments, table.concat(contextParts):lower()
end

-- Returns converted, plainWords, terms, or nil when nothing was found.
-- makeLink(term, index, written) returns the escape sequence that replaces the
-- written term in the converted line.
function Engine.Process(message, makeLink)
    if not IsPlainString(message) or #message > MAX_MESSAGE_BYTES then return nil end

    local segments, context = Segment(message)
    local converted, plainWords, terms = {}, {}, {}

    for _, segment in ipairs(segments) do
        if not segment.plain then
            converted[#converted + 1] = segment.raw
            plainWords[#plainWords + 1] = segment.display
        else
            local text = segment.raw
            local upper = text:upper()
            local pos, flushed = 1, 1
            while pos <= #text do
                local match
                if #terms < MAX_TERMS and not IsWordChar(upper:sub(pos - 1, pos - 1)) then
                    for _, candidate in ipairs(FindCandidates(upper, pos) or {}) do
                        local written = text:sub(pos, candidate.finish)
                        if not CAPS_ONLY[candidate.entry.key] or written == written:upper() then
                            local offset = segment.offset
                            local meaning, uncertain, fromContext = Resolve(candidate.entry, context, offset + pos, offset + candidate.finish)
                            if meaning then
                                match = {
                                    key = candidate.entry.key,
                                    entry = candidate.entry,
                                    written = written,
                                    meaning = meaning,
                                    uncertain = uncertain,
                                    fromContext = fromContext,
                                    finish = candidate.finish,
                                }
                                break
                            end
                        end
                    end
                end

                if match then
                    local before = text:sub(flushed, pos - 1)
                    converted[#converted + 1] = before
                    plainWords[#plainWords + 1] = before
                    terms[#terms + 1] = match
                    converted[#converted + 1] = makeLink(match, #terms, match.written)
                    plainWords[#plainWords + 1] = match.uncertain and ("[" .. match.meaning .. "]") or match.meaning
                    pos = match.finish + 1
                    flushed = pos
                    match.finish = nil
                else
                    pos = pos + 1
                end
            end
            local rest = text:sub(flushed)
            converted[#converted + 1] = rest
            plainWords[#plainWords + 1] = rest
        end
    end

    if #terms == 0 then return nil end
    return table.concat(converted), table.concat(plainWords), terms
end

function Engine.Lookup(key)
    if not IsPlainString(key) then return nil end
    return glossary[key:upper()]
end
