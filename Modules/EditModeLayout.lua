--[[ Carpenter - Personal Edit Mode layout ]]
local _, ns = ...
ns.Private = ns.Private or {}

local EditModeLayout = ns.Private.EditModeLayout or {}
ns.Private.EditModeLayout = EditModeLayout

local layoutString = [=[
5 0 59 0 0 0 7 7 UIParent -271.5 64.0 -1 ##$$%,&('))$+$,# 0 1 0 7 7 UIParent -250.0 114.0 -1 ##$$%,&(')(#,# 0 2 0 1 1 UIParent 271.5 -864.0 -1 ##$$%,&(')(#,# 0 3 0 1 1 UIParent 250.0 -914.0 -1 ##$$%,&(')(#,# 0 4 0 4 4 UIParent 192.0 -450.0 -1 ##$$%)&('%(#,$ 0 5 0 4 4 UIParent 192.0 -450.0 -1 ##$$%)&('%(#,$ 0 6 0 4 4 UIParent 158.0 -500.0 -1 ##$$%)&('%(#,$ 0 7 0 4 4 UIParent 192.0 -450.0 -1 ##$$%)&('%(#,$ 0 10 0 7 7 UIParent -433.0 164.0 -1 ##$$&('% 0 11 0 4 4 UIParent 0.0 -400.0 -1 ##$$&('%,# 0 12 0 0 2 StanceBar 4.0 0.0 -1 ##$$&('% 1 -1 0 1 1 UIParent 0.0 -814.0 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 1 0 0 UIParent 4.0 -4.0 -1 $#3# 3 1 1 0 0 UIParent 250.0 -4.0 -1 %#3# 3 2 0 1 1 UIParent -550.0 -198.0 -1 %#&$3# 3 3 1 0 2 CompactRaidFrameManager 0.0 -7.0 -1 '#(#)#-G.//$1$3#5#6(7-7$8(9( 3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-=.+/$0$1#2(3#5#6(7-7$8(9( 3 5 1 5 5 UIParent 0.0 0.0 -1 &$*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 0 7 7 UIParent 0.0 242.8 -1 # 5 -1 0 7 7 UIParent 0.0 214.0 -1 # 6 0 1 2 2 UIParent -255.0 -10.0 -1 ##$#%#&.(()( 6 1 1 2 2 UIParent -270.0 -155.0 -1 ##$#%#'+(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 7 7 UIParent -846.5 74.8 -1 #&$J%$&r 9 -1 0 7 7 UIParent 450.0 164.0 -1 # 10 -1 0 5 5 UIParent -397.0 -104.7 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 0 0 0 UIParent 1544.6 -983.0 -1 ##$#%' 14 -1 0 0 0 UIParent 1582.7 -942.5 -1 ##$#%# 15 0 0 7 7 UIParent 0.0 2.0 -1 &# 15 1 1 7 7 UIParent 0.0 17.0 -1 &- 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 0 7 7 UIParent 0.0 214.0 -1 #$%$&#'((()#*-*$+#,&-#.#/(0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 0 5 5 UIParent -2.0 -314.1 -1 ##$%%$&_'[(#)U+#,$-(.&/# 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 0 4 4 UIParent 350.0 -400.0 -1 # 26 0 0 1 1 UIParent -729.6 -559.0 -1 #$ 26 1 0 1 1 UIParent -605.0 -559.0 -1 #$ 27 -1 1 4 4 Minimap -68.0 -68.0 -1 #- 28 -1 1 4 4 UIParent 0.0 0.0 -1 #& 29 0 1 7 7 UIParent 0.0 450.0 -1 #&$U%#&D&%'2($)$ 29 1 1 7 7 UIParent 0.0 425.0 -1 #&$U%#&D&%'2($)$ 29 2 1 7 7 UIParent 0.0 400.0 -1 #&$U%#&D&%'2($)$
]=]

EditModeLayout.LayoutString = layoutString:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
EditModeLayout.LayoutName = "Carpenter"

-- The string above is the author's WoW Forever export. Forever and Retail
-- share Blizzard's Edit Mode, but their layout strings differ: Forever writes
-- format 5 with an interface-style header and inserts its own systems (main
-- action bar end caps 26, Group Finder 27, swing timers 29, gamepad bar 30)
-- ahead of Loss of Control, which Retail 12.1.5 still keeps at 26 and whose
-- strings are format 2 with the system count repeated. Retail also has no
-- totem bar (25) in its Modern layout. C_EditMode.ConvertStringToLayoutInfo
-- rejects a Forever string on Retail, so the Retail string is built from the
-- Forever one here.
local FOREVER_LOSS_OF_CONTROL = 28
local RETAIL_LOSS_OF_CONTROL = 26
local FOREVER_ONLY_SYSTEMS = {
    [25] = true, -- TotemActionBar: absent from Retail's Modern layout
    [26] = true, -- MainActionBarEndCap
    [27] = true, -- GroupFinder
    [29] = true, -- SwingTimer
    [30] = true, -- GamepadMainActionBar
}

local function ConvertForeverLayoutToRetail(text)
    local tokens = {}
    for token in text:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    local version = tonumber(tokens[1])
    if not version or version < 3 then return nil end
    -- Format 4+ headers carry the interface style between version and count.
    local headerLength = version >= 4 and 3 or 2
    local count = tonumber(tokens[headerLength])
    if not count then return nil end

    local records = {}
    local index = headerLength + 1
    for _ = 1, count do
        local record = {}
        -- system, systemIndex, isInDefaultPosition, point, relativePoint, relativeTo, offsetX, offsetY
        for _ = 1, 8 do
            record[#record + 1] = tokens[index]
            index = index + 1
        end
        -- Secondary anchor: "-1" when absent, otherwise five more tokens.
        local secondaryCount = tokens[index] == "-1" and 1 or 5
        for _ = 1, secondaryCount do
            record[#record + 1] = tokens[index]
            index = index + 1
        end
        record[#record + 1] = tokens[index] -- settings blob
        index = index + 1
        if record[#record] == nil then return nil end
        records[#records + 1] = record
    end
    if index ~= #tokens + 1 then return nil end

    local kept = {}
    for _, record in ipairs(records) do
        local system = tonumber(record[1])
        if system == FOREVER_LOSS_OF_CONTROL then
            record[1] = tostring(RETAIL_LOSS_OF_CONTROL)
            kept[#kept + 1] = table.concat(record, " ")
        elseif not FOREVER_ONLY_SYSTEMS[system] then
            kept[#kept + 1] = table.concat(record, " ")
        end
    end

    return "2 " .. #kept .. " " .. #kept .. " " .. table.concat(kept, " ")
end

EditModeLayout.ForeverLayoutString = layoutString:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
EditModeLayout.RetailLayoutString = ConvertForeverLayoutToRetail(EditModeLayout.ForeverLayoutString)
EditModeLayout.LayoutName = "Carpenter"

-- The author runs this same layout on Retail and WoW Forever, which share
-- Blizzard's Edit Mode.
function EditModeLayout.IsAvailable()
    local client = Carpenter and Carpenter.Client
    return client ~= nil and (client.isRetail == true or client.isForever == true)
end

-- The layout string in the running client's own format.
function EditModeLayout.GetLayoutString()
    local client = Carpenter and Carpenter.Client
    if client and client.isForever then
        return EditModeLayout.ForeverLayoutString
    end
    return EditModeLayout.RetailLayoutString
end

function EditModeLayout.Install()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end

    local api = C_EditMode
    if not api or type(api.GetLayouts) ~= "function" or
        type(api.ConvertStringToLayoutInfo) ~= "function" or
        type(api.SaveLayouts) ~= "function" then
        return false, "unsupported"
    end

    local text = EditModeLayout.GetLayoutString()
    if type(text) ~= "string" then
        return false, "unsupported"
    end

    local ok, importedLayout = pcall(api.ConvertStringToLayoutInfo, text)
    if not ok or type(importedLayout) ~= "table" or type(importedLayout.systems) ~= "table" then
        return false, "invalid"
    end

    local accountLayoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    importedLayout.layoutName = EditModeLayout.LayoutName
    importedLayout.layoutType = accountLayoutType

    local layoutsOk, layoutInfo = pcall(api.GetLayouts)
    if not layoutsOk or type(layoutInfo) ~= "table" or type(layoutInfo.layouts) ~= "table" then
        return false, "unavailable"
    end

    local savedIndex
    for index, existingLayout in ipairs(layoutInfo.layouts) do
        if existingLayout.layoutName == EditModeLayout.LayoutName then
            savedIndex = index
            break
        end
    end

    local updated = savedIndex ~= nil
    if updated then
        layoutInfo.layouts[savedIndex] = importedLayout
    else
        table.insert(layoutInfo.layouts, importedLayout)
        savedIndex = #layoutInfo.layouts
    end

    local saveOk = pcall(api.SaveLayouts, layoutInfo)
    if not saveOk then
        return false, "save"
    end

    if not updated and type(api.OnLayoutAdded) == "function" then
        local presetCount = Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues or 2
        local layoutIndex = presetCount + savedIndex
        pcall(api.OnLayoutAdded, layoutIndex, false, true)
    end

    return true, updated and "updated" or "created"
end

local function FindSavedLayout()
    local api = C_EditMode
    if not api or type(api.GetLayouts) ~= "function" then return nil end
    local ok, layoutInfo = pcall(api.GetLayouts)
    if not ok or type(layoutInfo) ~= "table" or type(layoutInfo.layouts) ~= "table" then return nil end
    for index, existingLayout in ipairs(layoutInfo.layouts) do
        if existingLayout.layoutName == EditModeLayout.LayoutName then
            return index, layoutInfo
        end
    end
    return nil, layoutInfo
end

function EditModeLayout.IsInstalled()
    return FindSavedLayout() ~= nil
end

-- Mirrors Blizzard's EditModeManagerFrameMixin:DeleteLayout. The layout in
-- use is left alone so removing it never yanks the UI to another layout.
function EditModeLayout.Remove()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end

    local api = C_EditMode
    if not api or type(api.SaveLayouts) ~= "function" then
        return false, "unsupported"
    end

    local savedIndex, layoutInfo = FindSavedLayout()
    if not layoutInfo then
        return false, "unavailable"
    end
    if not savedIndex then
        return true, "removed"
    end

    local presetCount = Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues or 2
    local layoutIndex = presetCount + savedIndex
    if layoutInfo.activeLayout == layoutIndex then
        return false, "active"
    end

    table.remove(layoutInfo.layouts, savedIndex)
    if not pcall(api.SaveLayouts, layoutInfo) then
        return false, "save"
    end
    if type(api.OnLayoutDeleted) == "function" then
        pcall(api.OnLayoutDeleted, layoutIndex)
    end

    return true, "removed"
end
