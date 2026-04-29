--[[ Carpenter - SmartMacros ]]
-- Resolves C_Container API differences and macro update handling across WoW versions.

local addonName, ns = ...
local addonFrame = CreateFrame("Frame")

-- API Abstraction to handle different WoW versions (Classic, Cata, Retail)
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local GetItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local ITEMS = {
    Food = { name = "CarpenterFood", btnName = "CP_Food_Btn" },
    Water = { name = "CarpenterWater", btnName = "CP_Water_Btn" },
    Pot = { name = "CarpenterHP", btnName = "CP_Pot_Btn" },
    Mana = { name = "CarpenterMana", btnName = "CP_Mana_Btn" },
    Band = { name = "CarpenterBand", btnName = "CP_Band_Btn" }
}

-- Scanning Tooltip
local scanTooltip = CreateFrame("GameTooltip", "CP_ScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetBestItem(category)
    local bestItem = nil
    local bestScore = -1
    local playerLevel = UnitLevel("player")

    for bag = 0, 4 do
        local numSlots = GetNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemID = GetItemID(bag, slot)
                if itemID then
                    local name, _, _, iLevel, reqLevel, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemID)

                    -- Basic filter: Must be a consumable (Class 0)
                    if name and (reqLevel or 0) <= playerLevel and classID == 0 then
                        scanTooltip:ClearLines()
                        scanTooltip:SetBagItem(bag, slot)
                        scanTooltip:Show() -- Force tooltip to populate before we read (avoids empty/incomplete data)

                        local tooltipText = ""
                        for i = 1, scanTooltip:NumLines() do
                            local line = _G["CP_ScanTooltipTextLeft" .. i]
                            local text = line and line:GetText()
                            if text then tooltipText = tooltipText .. " " .. text:lower() end
                        end

                        local isMatch = false
                        local isConjured = tooltipText:find("conjured")
                        local nameLower = name and name:lower() or ""
                        local isConjuredByName = nameLower:find("conjured")
                        -- Conjured food/water: match by name so we detect before tooltip is "seen"
                        local conjuredWater = isConjuredByName and (nameLower:find("water") or nameLower:find("mana") or nameLower:find("drink") or nameLower:find("refreshing"))
                        local conjuredFood = isConjuredByName and (nameLower:find("food") or nameLower:find("strudel") or nameLower:find("bread") or nameLower:find("muffin") or nameLower:find("roll") or nameLower:find("biscuit") or nameLower:find("cookie") or nameLower:find("pie") or nameLower:find("cinnamon"))
                        -- TBC+ food by name (e.g. dual-regen like Underspore Pod, Sporeling Snack)
                        local tbcFoodByName = nameLower:find("underspore") or nameLower:find("sporeling") or (nameLower:find("pod") and nameLower:find("spore"))
                        local isHealthstone = tooltipText:find("healthstone")
                        
                        -- Detect if food has a buff (Well Fed or stat bonuses). Do NOT use "use:" - plain food also says "Use: Restores X health".
                        local hasBuff = false
                        if category == "Food" then
                            hasBuff = tooltipText:find("well fed") or
                                     tooltipText:find("%+%d+ strength") or
                                     tooltipText:find("%+%d+ agility") or
                                     tooltipText:find("%+%d+ stamina") or
                                     tooltipText:find("%+%d+ intellect") or
                                     tooltipText:find("%+%d+ spirit") or
                                     tooltipText:find("%+%d+ attack power") or
                                     tooltipText:find("%+%d+ spell damage") or
                                     tooltipText:find("%+%d+ healing") or
                                     tooltipText:find("%+%d+ hit") or
                                     tooltipText:find("%+%d+ crit")
                        end

                        -- CATEGORY FILTERING
                        if category == "Water" then
                            -- SubClass 5 is Food/Drink. Must restore mana; or conjured by name
                            if subClassID == 5 and (conjuredWater or tooltipText:find("mana") or tooltipText:find("drink")) then
                                isMatch = true
                            end
                        elseif category == "Food" then
                            -- SubClass 5 is Food/Drink. Must restore health; or conjured/TBC food by name
                            if subClassID == 5 and (conjuredFood or tbcFoodByName or tooltipText:find("health") or tooltipText:find("food") or tooltipText:find("eat")) then
                                -- Avoid dual-regen items for "Food" category unless conjured or known TBC food (e.g. Underspore Pod)
                                if not tooltipText:find("mana") or isConjured or conjuredFood or tbcFoodByName then
                                    isMatch = true
                                end
                            end
                        elseif category == "Pot" then
                            -- SubClass 1 is specifically "Potion".
                            -- We also allow Healthstones (which might be classified as SubClass 0/Other)
                            if (subClassID == 1 or isHealthstone) and tooltipText:find("health") then
                                isMatch = true
                            end
                        elseif category == "Mana" then
                            -- SubClass 1 is specifically "Potion". Must be mana.
                            if subClassID == 1 and tooltipText:find("mana") then
                                isMatch = true
                            end
                        elseif category == "Band" then
                            -- SubClass 7 is specifically "Bandage"
                            if subClassID == 7 or tooltipText:find("bandage") then
                                isMatch = true
                            end
                        end

                        if isMatch then
                            -- SCORE CALCULATION
                            local score = iLevel or 0

                            if category == "Food" then
                                -- Food prioritization:
                                -- 1. Conjured food (highest priority)
                                -- 2. Highest item level food WITHOUT buff (preferred over buff food)
                                -- 3. Highest item level food WITH buff (lowest priority)
                                if isConjured or conjuredFood then
                                    -- Conjured food: highest priority
                                    score = score + 5000
                                elseif not hasBuff then
                                    -- Food without buff: always prefer over buff food (even if slightly worse iLevel)
                                    score = score + 5000
                                else
                                    -- Food with buff: penalize so non-buff food wins (clamp so we still pick something if only buff food exists)
                                    score = math.max(0, score - 5000)
                                end
                            else
                                -- Other categories (Water, Pot, Mana, Band)
                                -- Priority boost for Conjured items
                                if isConjured then
                                    score = score + 5000
                                end

                                -- High priority boost for Healthstones in the Pot category
                                if category == "Pot" and isHealthstone then
                                    score = score + 10000
                                end
                            end

                            if score > bestScore then
                                bestScore = score
                                bestItem = name
                            end
                        end
                    end
                end
            end
        end
    end
    return bestItem
end

-- Update the secure buttons and the actual macros
local function ProcessUpdate()
    if InCombatLockdown() then
        addonFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    for key, config in pairs(ITEMS) do
        local best = GetBestItem(key)
        local btn = _G[config.btnName]

        -- Create/Update the hidden secure button
        if not btn then
            btn = CreateFrame("Button", config.btnName, UIParent, "SecureActionButtonTemplate")
            btn:SetAttribute("type", "item")
        end

        -- Only update if the item changed to prevent macro flicker
        local currentItem = btn:GetAttribute("item")
        if currentItem ~= (best or "") then
            btn:SetAttribute("item", best or "")

            -- Update the actual Macro
            local macroIndex = GetMacroIndexByName(config.name)
            local body = "#showtooltip " .. (best or "") .. "\n/use " .. (best or "")

            if macroIndex == 0 then
                CreateMacro(config.name, "INV_Misc_QuestionMark", body, 1)
            else
                local _, _, curBody = GetMacroInfo(macroIndex)
                if curBody ~= body then
                    EditMacro(macroIndex, config.name, nil, body)
                end
            end
        end
    end
end

-- =========================================================
-- Robust Event Orchestration
-- =========================

local isDirty = false

addonFrame:RegisterEvent("BAG_UPDATE")
addonFrame:RegisterEvent("BAG_UPDATE_DELAYED")
addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") -- Trigger on item use

addonFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        isDirty = true
    elseif event == "BAG_UPDATE_DELAYED" then
        isDirty = true
    elseif event == "BAG_UPDATE" or (event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player") then
        isDirty = true
    elseif event == "PLAYER_ENTERING_WORLD" then
        ProcessUpdate()
    end
end)

-- The OnUpdate script handles the "Dirty Flag"
-- This ensures that if 10 BAG_UPDATE events fire at once,
-- we only do 1 scan after everything has settled.
addonFrame:SetScript("OnUpdate", function(self, elapsed)
    if isDirty and not InCombatLockdown() then
        isDirty = false
        ProcessUpdate()
    end
end)

-- Public API for other modules
ns.UpdateSmartMacros = function() isDirty = true end
