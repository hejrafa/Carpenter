--[[ Carpenter - Smart Macro stat weights ]]
-- How much each stat a Well Fed buff gives is worth to the character, so the
-- Well Fed macro reaches for the food a rogue, a mage or a tank would pick.
-- The role comes from the group role the player took (tank or healer), else
-- from the talent tree with the most points (the spec on Retail), else from
-- the class. Values are per point of the stat, in points of the role's main
-- stat; a percent of critical strike counts per 1%. Stats missing from a
-- role are worth nothing to it, and buffs outside combat (fishing, herbalism,
-- movement speed) are worth nothing to anyone.
local _, ns = ...
ns.Private = ns.Private or {}

local StatWeights = ns.Private.SmartMacroStatWeights or {}
ns.Private.SmartMacroStatWeights = StatWeights

local SECONDARY = 1

local ROLE_WEIGHTS = {
    agilityMelee = {
        agility = 1, strength = 0.6, attackPower = 0.45, stamina = 0.3, spirit = 0.05, hp5 = 0.3, armor = 0.02,
        hitRating = 1, critRating = 1, critPercent = 14, haste = SECONDARY, mastery = SECONDARY, versatility = SECONDARY,
    },
    strengthMelee = {
        strength = 1, agility = 0.6, attackPower = 0.5, stamina = 0.3, spirit = 0.05, hp5 = 0.3, armor = 0.02,
        hitRating = 1, critRating = 1, critPercent = 14, haste = SECONDARY, mastery = SECONDARY, versatility = SECONDARY,
    },
    ranged = {
        agility = 1, attackPower = 0.4, intellect = 0.25, stamina = 0.3, spirit = 0.05, mp5 = 0.5, strength = 0.05,
        hitRating = 1, critRating = 1, critPercent = 14, haste = SECONDARY, mastery = SECONDARY, versatility = SECONDARY,
    },
    tank = {
        stamina = 1, armor = 0.08, agility = 0.6, strength = 0.6, attackPower = 0.2, resistance = 0.3, hp5 = 0.5,
        spirit = 0.05, hitRating = 0.5, critRating = 0.3, critPercent = 5,
        haste = SECONDARY, mastery = SECONDARY, versatility = SECONDARY,
    },
    caster = {
        spellDamage = 1, spellPower = 1, intellect = 0.6, spirit = 0.25, mp5 = 0.8, stamina = 0.25,
        hitRating = 1, critRating = 1, critPercent = 10, spellCritPercent = 10,
        haste = SECONDARY, mastery = SECONDARY, versatility = SECONDARY,
    },
    healer = {
        healing = 1, spellPower = 1, intellect = 0.9, spirit = 0.6, mp5 = 1.2, stamina = 0.25,
        critRating = 1, critPercent = 8, spellCritPercent = 8,
        haste = SECONDARY, mastery = SECONDARY, versatility = SECONDARY,
    },
}

-- How much Spirit is worth differs within a role.
local CLASS_TWEAKS = {
    healer = {
        PRIEST = { spirit = 0.8 },
        DRUID = { spirit = 0.8 },
        SHAMAN = { spirit = 0.4 },
        PALADIN = { spirit = 0.2 },
    },
    caster = {
        MAGE = { spirit = 0.3 },
        WARLOCK = { spirit = 0.15 },
        PRIEST = { spirit = 0.4 },
    },
}

-- The role of each talent tree, in the game's order. Forever's talent
-- groups and Classic's talent tabs share it.
local TREE_ROLES = {
    WARRIOR = { "strengthMelee", "strengthMelee", "tank" },
    PALADIN = { "healer", "tank", "strengthMelee" },
    HUNTER = { "ranged", "ranged", "ranged" },
    ROGUE = { "agilityMelee", "agilityMelee", "agilityMelee" },
    PRIEST = { "healer", "healer", "caster" },
    SHAMAN = { "caster", "strengthMelee", "healer" },
    MAGE = { "caster", "caster", "caster" },
    WARLOCK = { "caster", "caster", "caster" },
    DRUID = { "caster", "agilityMelee", "healer" },
    DEATHKNIGHT = { "tank", "strengthMelee", "strengthMelee" },
}

-- Before any talent points, or when none can be read.
local CLASS_ROLES = {
    WARRIOR = "strengthMelee", PALADIN = "strengthMelee", HUNTER = "ranged", ROGUE = "agilityMelee",
    PRIEST = "healer", SHAMAN = "caster", MAGE = "caster", WARLOCK = "caster", DRUID = "caster",
    DEATHKNIGHT = "strengthMelee", MONK = "agilityMelee", DEMONHUNTER = "agilityMelee", EVOKER = "caster",
}

-- Stats that don't help in a fight; any useful stat beats them.
StatWeights.NonCombatStats = { fishing = true, herbalism = true, movementSpeed = true }

local function Returns(ok, ...)
    if ok then return ... end
    return nil
end

local function Call(func, ...)
    if type(func) ~= "function" then return nil end
    return Returns(pcall(func, ...))
end

local function Client()
    return Carpenter and Carpenter.Client or {}
end

local function GetClassToken()
    if not UnitClass then return nil end
    local _, classToken = Call(UnitClass, "player")
    return type(classToken) == "string" and classToken or nil
end

-- The talent tree (1 to 3) with the most points, or nil.
local function MostSpentTree(spentByTree)
    local bestTree, bestSpent = nil, 0
    for tree = 1, 3 do
        local spent = spentByTree[tree] or 0
        if spent > bestSpent then
            bestTree, bestSpent = tree, spent
        end
    end
    return bestTree
end

-- WoW Forever: one talent tree per class with three groups, each a classic
-- talent tree; the points spent in a group are its tree's.
local function ForeverTreeSpent()
    local traits, classTalents = _G.C_Traits, _G.C_ClassTalents
    if not (traits and classTalents) then return nil end
    local configID = Call(classTalents.GetActiveConfigID)
    if not configID and _G.C_SpecializationInfo then
        configID = Call(_G.C_SpecializationInfo.GetCombatConfigIDForSpecGroup,
            Call(_G.GetActiveSpecGroup) or 1)
    end
    if type(configID) ~= "number" then return nil end
    local configInfo = Call(traits.GetConfigInfo, configID)
    local treeID = type(configInfo) == "table" and type(configInfo.treeIDs) == "table" and configInfo.treeIDs[1]
    if type(treeID) ~= "number" then return nil end

    local groups = Call(traits.GetGroupDisplayInfoByTreeID, treeID)
    if type(groups) ~= "table" or #groups == 0 then return nil end
    local treeByGroup, groupIDs = {}, {}
    for _, group in ipairs(groups) do
        if type(group.groupID) == "number" and type(group.orderIndex) == "number" then
            treeByGroup[group.groupID] = group.orderIndex + 1
            groupIDs[#groupIDs + 1] = group.groupID
        end
    end
    local currencies = Call(traits.GetGroupCurrencyInfo, configID, groupIDs)
    if type(currencies) ~= "table" then return nil end
    local spentByTree = {}
    for _, info in ipairs(currencies) do
        local tree = treeByGroup[info.traitNodeGroupID]
        local currency = type(info.currencyInfos) == "table" and info.currencyInfos[1]
        if tree and type(currency) == "table" and type(currency.spent) == "number" then
            spentByTree[tree] = (spentByTree[tree] or 0) + currency.spent
        end
    end
    return spentByTree
end

-- Classic: the talent tabs. Old clients return name, icon, pointsSpent;
-- newer ones id, name, description, icon, pointsSpent.
local function ClassicTreeSpent()
    if type(_G.GetTalentTabInfo) ~= "function" then return nil end
    local spentByTree = {}
    for tree = 1, 3 do
        local results = { pcall(_G.GetTalentTabInfo, tree) }
        if results[1] then
            local spent = type(results[2]) == "string" and results[4] or results[6]
            if type(spent) == "number" then spentByTree[tree] = spent end
        end
    end
    return spentByTree
end

-- Retail: the spec's role and main stat.
local function RetailRole(classToken)
    local spec = Call(_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecialization)
        or Call(_G.GetSpecialization)
    if type(spec) ~= "number" then return nil end
    local getInfo = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
    local _, _, _, _, role, primaryStat = Call(getInfo, spec)
    if role == "TANK" then return "tank" end
    if role == "HEALER" then return "healer" end
    if primaryStat == 4 then return "caster" end
    if primaryStat == 2 then return classToken == "HUNTER" and "ranged" or "agilityMelee" end
    if primaryStat == 1 then return "strengthMelee" end
    return nil
end

function StatWeights.GetRole()
    local classToken = GetClassToken()
    local assigned = Call(_G.UnitGroupRolesAssigned, "player")
    if assigned == "TANK" then return "tank", classToken, "group role" end
    if assigned == "HEALER" then return "healer", classToken, "group role" end

    local client = Client()
    if client.isRetail then
        local role = RetailRole(classToken)
        if role then return role, classToken, "spec" end
    else
        local spentByTree = client.isForever and ForeverTreeSpent() or ClassicTreeSpent()
        local tree = spentByTree and MostSpentTree(spentByTree)
        local roles = classToken and TREE_ROLES[classToken]
        if tree and roles and roles[tree] then return roles[tree], classToken, "talents" end
    end
    return CLASS_ROLES[classToken or ""] or "strengthMelee", classToken, "class"
end

function StatWeights.GetWeights()
    local role, classToken, source = StatWeights.GetRole()
    local weights = {}
    for stat, weight in pairs(ROLE_WEIGHTS[role] or {}) do
        weights[stat] = weight
    end
    local tweaks = CLASS_TWEAKS[role] and classToken and CLASS_TWEAKS[role][classToken]
    for stat, weight in pairs(tweaks or {}) do
        weights[stat] = weight
    end
    return weights, role, source
end

StatWeights.RoleWeights = ROLE_WEIGHTS
