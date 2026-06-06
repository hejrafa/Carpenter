--[[ Carpenter - Smart Macro builder ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Builder = ns.Private.SmartMacroBuilder or {}
ns.Private.SmartMacroBuilder = Builder

local Data = ns.Private.SmartMacroData or {}
local CLASS_HEAL_SPELLS = Data.ClassHealSpells or {}

local function IsRetail()
    return Data.IsRetail and Data.IsRetail()
end

local function GetSpellName(spellID, fallback)
    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if type(spellInfo) == "table" and spellInfo.name then
            return spellInfo.name
        end
    end
    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name then return name end
    end
    return fallback
end

local function IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    if _G.IsPlayerSpell then
        return _G.IsPlayerSpell(spellID)
    end
    return false
end

local function UpdateMacro(name, body, createIfMissing)
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex == 0 then
        if createIfMissing then
            CreateMacro(name, "INV_Misc_QuestionMark", body, 1)
        end
        return
    end

    local _, _, curBody = GetMacroInfo(macroIndex)
    if curBody ~= body then
        EditMacro(macroIndex, name, nil, body)
    end
end

local function DeleteMacroByName(name)
    if not DeleteMacro then return end
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex > 0 then
        DeleteMacro(macroIndex)
    end
end

local function BuildHealthMacroBody(potion, healthstone)
    local lines = {}
    local entries = {}
    local recuperate = GetSpellName(CLASS_HEAL_SPELLS.RECUPERATE, "Recuperate")
    local crimsonVial = GetSpellName(CLASS_HEAL_SPELLS.CRIMSON_VIAL, "Crimson Vial")
    local _, class = UnitClass("player")
    local tooltip

    if recuperate and (IsRetail() or IsSpellKnown(CLASS_HEAL_SPELLS.RECUPERATE)) then
        tooltip = tooltip or ("[nocombat] " .. recuperate)
        entries[#entries + 1] = {
            line = "/cast [nocombat] " .. recuperate,
            stopLine = "/stopmacro [nocombat]",
        }
    end

    if class == "ROGUE" and crimsonVial and IsSpellKnown(CLASS_HEAL_SPELLS.CRIMSON_VIAL) then
        tooltip = tooltip and (tooltip .. "; [combat] " .. crimsonVial) or ("[combat] " .. crimsonVial)
        entries[#entries + 1] = {
            line = "/castsequence [@player,combat] reset=combat " .. crimsonVial,
        }
    end

    if healthstone and healthstone.name then
        tooltip = tooltip and (tooltip .. "; " .. healthstone.name) or healthstone.name
        entries[#entries + 1] = {
            line = "/use " .. healthstone.name,
        }
    end

    if potion and potion.name then
        tooltip = tooltip and (tooltip .. "; " .. potion.name) or potion.name
        entries[#entries + 1] = {
            line = "/use " .. potion.name,
        }
    end

    lines[#lines + 1] = tooltip and ("#showtooltip " .. tooltip) or "#showtooltip"

    for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry.line
        if entry.stopLine then
            lines[#lines + 1] = entry.stopLine
        end
    end

    return table.concat(lines, "\n")
end

local function BuildMacroBody(item)
    if not item or not item.name then
        return "#showtooltip\n"
    end

    return "#showtooltip " .. item.name .. "\n/use " .. item.name
end

Builder.UpdateMacro = UpdateMacro
Builder.DeleteMacroByName = DeleteMacroByName
Builder.BuildHealthMacroBody = BuildHealthMacroBody
Builder.BuildMacroBody = BuildMacroBody
