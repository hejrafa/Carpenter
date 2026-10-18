--[[ Carpenter - Personal RP macros ]]
-- The author's favorite roleplay macros, kept on the hidden settings page so
-- they can be rebuilt on any client or account in one click. Each one is an
-- account-wide (General) macro; installing again updates it in place.
local _, ns = ...
ns.Private = ns.Private or {}

local RPMacros = ns.Private.RPMacros or {}
ns.Private.RPMacros = RPMacros

-- Icons are file IDs, so they don't depend on the client's icon-name lookup.
RPMacros.Macros = {
    {
        name = "Bow",
        icon = 237573,
        body = "/bow",
    },
    {
        name = "1v1",
        icon = 132269,
        body = "/whistle\n/s 1v1",
    },
}

function RPMacros.Install(macro)
    if type(macro) ~= "table" then
        return false, "invalid"
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" then
        return false, "unsupported"
    end

    local index = GetMacroIndexByName(macro.name)
    if index and index > 0 then
        local ok = pcall(EditMacro, index, macro.name, macro.icon, macro.body)
        return ok, ok and "updated" or "failed"
    end

    local numAccount = type(GetNumMacros) == "function" and GetNumMacros()
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    if numAccount and numAccount >= maxAccount then
        return false, "full"
    end

    local ok, created = pcall(CreateMacro, macro.name, macro.icon, macro.body, nil)
    if not ok or not created or created == 0 then
        return false, "failed"
    end
    return true, "created"
end
