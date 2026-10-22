--[[ Carpenter - Personal Edit Mode layout ]]
local _, ns = ...
ns.Private = ns.Private or {}

local EditModeLayout = ns.Private.EditModeLayout or {}
ns.Private.EditModeLayout = EditModeLayout

local layoutString = [=[
5 0 59 0 0 0 7 7 UIParent -271.5 64.0 -1 ##$$%,&('))$+$,# 0 1 0 7 7 UIParent -250.0 114.0 -1 ##$$%,&(')(#,# 0 2 0 1 1 UIParent 271.5 -864.0 -1 ##$$%,&(')(#,# 0 3 0 1 1 UIParent 250.0 -914.0 -1 ##$$%,&(')(#,# 0 4 0 4 4 UIParent 192.0 -450.0 -1 ##$$%)&('%(#,$ 0 5 0 4 4 UIParent 192.0 -450.0 -1 ##$$%)&('%(#,$ 0 6 0 4 4 UIParent 158.0 -500.0 -1 ##$$%)&('%(#,$ 0 7 0 4 4 UIParent 192.0 -450.0 -1 ##$$%)&('%(#,$ 0 10 0 7 7 UIParent -433.0 164.0 -1 ##$$&('% 0 11 0 4 4 UIParent 0.0 -400.0 -1 ##$$&('%,# 0 12 0 0 2 StanceBar 4.0 0.0 -1 ##$$&('% 1 -1 0 1 1 UIParent 0.0 -814.0 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 1 0 0 UIParent 4.0 -4.0 -1 $#3# 3 1 1 0 0 UIParent 250.0 -4.0 -1 %#3# 3 2 0 1 1 UIParent -550.0 -198.0 -1 %#&$3# 3 3 1 0 2 CompactRaidFrameManager 0.0 -7.0 -1 '#(#)#-G.//$1$3#5#6(7-7$8(9( 3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-=.+/#0#1#2(3#5#6(7-7$8(9( 3 5 1 5 5 UIParent 0.0 0.0 -1 &$*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 0 7 7 UIParent 0.0 242.8 -1 # 5 -1 0 7 7 UIParent 0.0 214.0 -1 # 6 0 1 2 2 UIParent -255.0 -10.0 -1 ##$#%#&.(()( 6 1 1 2 2 UIParent -270.0 -155.0 -1 ##$#%#'+(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 7 7 UIParent -846.5 74.8 -1 #&$J%$&r 9 -1 0 7 7 UIParent 450.0 164.0 -1 # 10 -1 0 5 5 UIParent -397.0 -104.7 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 0 0 0 UIParent 1544.6 -983.0 -1 ##$#%' 14 -1 0 0 0 UIParent 1582.7 -942.5 -1 ##$#%# 15 0 0 7 7 UIParent 0.0 2.0 -1 &# 15 1 1 7 7 UIParent 0.0 17.0 -1 &- 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 0 7 7 UIParent 0.0 214.0 -1 #$%$&#'((()#*-*$+#,&-#.#/(0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 0 5 5 UIParent -2.0 -314.1 -1 ##$%%$&_'[(#)U+#,$-(.&/# 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 0 4 4 UIParent 350.0 -400.0 -1 # 26 0 0 1 1 UIParent -729.6 -559.0 -1 #$ 26 1 0 1 1 UIParent -605.0 -559.0 -1 #$ 27 -1 1 4 4 Minimap -68.0 -68.0 -1 #- 28 -1 1 4 4 UIParent 0.0 0.0 -1 #& 29 0 1 7 7 UIParent 0.0 450.0 -1 #&$U%#&D&%'2($)$ 29 1 1 7 7 UIParent 0.0 425.0 -1 #&$U%#&D&%'2($)$ 29 2 1 7 7 UIParent 0.0 400.0 -1 #&$U%#&D&%'2($)$
]=]

EditModeLayout.LayoutString = layoutString:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
EditModeLayout.LayoutName = "Carpenter"

-- The author runs this same layout on Retail and WoW Forever, which share
-- Blizzard's Edit Mode.
function EditModeLayout.IsAvailable()
    local client = Carpenter and Carpenter.Client
    return client ~= nil and (client.isRetail == true or client.isForever == true)
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

    local ok, importedLayout = pcall(api.ConvertStringToLayoutInfo, EditModeLayout.LayoutString)
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
