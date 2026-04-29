Create a new Carpenter addon module based on the user's description: $ARGUMENTS

## Instructions

You are creating a new feature module for the Carpenter WoW addon (Classic Anniversary / TBC). Follow these exact steps:

### 1. Create the Module Lua File

Create `Modules/<ModuleName>.lua` following this exact pattern:

```lua
--[[ Carpenter - <Feature Name> ]]
-- <One-line description of what this module does>

-- =========================
-- Config
-- =========================
local function IsEnabled()
    if not CarpenterDB then return true end
    if CarpenterDB.<configKey>Enabled == nil then return true end
    return CarpenterDB.<configKey>Enabled
end

-- =========================
-- Core Logic
-- =========================

-- <Module logic goes here>
-- Use local variables only (no globals)
-- Use hooksecurefunc() to hook Blizzard functions, never replace them
-- Store custom data on frames with _Carpenter_ prefixed keys
-- Check IsEnabled() at the start of every callback

-- =========================
-- Events
-- =========================
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if not IsEnabled() then return end
    -- Initialize hooks and state here
end)
```

Key conventions:
- All variables MUST be `local` (no global pollution)
- Use `hooksecurefunc()` to intercept Blizzard functions without replacing them
- Every event handler and hook callback must check `if not IsEnabled() then return end`
- For version-specific code: `local _, _, _, interfaceVersion = GetBuildInfo(); local isTBC = interfaceVersion >= 20000`
- For container API compat: `local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots`
- Header comment: `--[[ Carpenter - ModuleName ]]`
- Section dividers: `-- =========================`
- Defensive nil checks: `if not frame then return end`

### 2. Register the Default Setting

Add the new default to `Carpenter.lua` in the `defaults` table, inside the appropriate category section:

```lua
<configKey>Enabled = false,
```

Settings categories in order: Action Bars, Interface, Unit Frames, Nameplates, Chat, Automations, Text, Immersion.

### 3. Add to TOC Files

Add `Modules\<ModuleName>.lua` to ALL three TOC files under the appropriate `# Category` comment:
- `Carpenter.toc` (primary)
- `Carpenter_TBC.toc`
- `Carpenter_Vanilla.toc`

### 4. Add Config UI Entry

In `config.lua`, add a `CreateCheckbox()` call in the appropriate category section:

```lua
if IsFeatureAvailable("<configKey>Enabled") then
    CreateCheckbox("<configKey>Enabled", "<Display Label>",
        LightGrey .. "<Description paragraph 1>\n\n" ..
        "Detailed description with " .. LighterCream .. "highlighted terms" .. LightGrey .. " for emphasis.", nil,
        "Interface\\AddOns\\Carpenter\\Images\\<imagename>.png")
end
```

Description style:
- First paragraph: describe the PROBLEM (opinionated, conversational tone)
- Second paragraph: describe the SOLUTION with LighterCream highlights on key terms
- Use `nil` for the sideLogic param unless the feature needs extra sidebar controls
- Set requiresReload to `false` only if the feature can toggle live (most need reload)

### 5. If TBC-Only

If the feature only works on TBC (interface >= 20000), add it to `IsFeatureAvailable()` in config.lua:

```lua
if configKey == "menuTransparencyEnabled" or configKey == "smallerExpBarEnabled" or configKey == "<newKey>" then
    return isTBC
end
```

### Summary

After creating the module, list all files modified and provide the full config key name so the user can test with `/cp`.
