Review the Carpenter addon code for issues. Focus area (optional): $ARGUMENTS

## Instructions

You are reviewing code for the Carpenter WoW addon (Classic Anniversary / TBC). Perform a thorough code review checking for all categories below. If a focus area was specified, prioritize that but still check others.

### Review Checklist

#### 1. WoW API Issues
- **Taint risk**: Using `securecall` or modifying protected frames outside combat? Calling secure functions from insecure code?
- **Missing nil checks**: Always check `UnitExists(unit)` before `UnitClass(unit)`, `UnitHealth(unit)`, etc.
- **Deprecated APIs**: Check for APIs removed in Classic Anniversary (1.15.x) or TBC (2.5.x). Container API should use compat pattern: `(C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots`
- **Frame references**: Using `_G["FrameName"]` for frames that may not exist yet? Check timing (PLAYER_LOGIN vs ADDON_LOADED)
- **Event registration**: Events registered but never unregistered when feature disabled?
- **Protected function hooks**: Never replace protected functions. Use `hooksecurefunc()` only.

#### 2. Performance Problems
- **OnUpdate abuse**: OnUpdate handlers running expensive logic every frame without throttling? Nameplate/health updates should use ~20Hz max or event-driven
- **String concatenation in loops**: Use `table.concat()` for building strings in hot paths
- **Repeated global lookups**: Cache frequently used globals locally: `local pairs = pairs`, `local UnitHealth = UnitHealth`
- **Unnecessary frame creation**: Creating frames in OnUpdate or per-tick callbacks instead of once at init
- **Tooltip scanning overhead**: `GameTooltip:SetBagItem()` triggers full tooltip rebuild - cache results where possible
- **Memory churn**: Creating tables in hot paths instead of reusing/recycling

#### 3. Carpenter Convention Violations
- **Global pollution**: ALL module variables must be `local`. Only `CarpenterDB` and explicit exports (like `Carpenter_OpenConfig`) should be global
- **Missing IsEnabled() check**: Every callback, hook, and event handler must check `if not IsEnabled() then return end`
- **IsEnabled() pattern**: Must follow exact pattern:
  ```lua
  local function IsEnabled()
      if not CarpenterDB then return true end
      if CarpenterDB.featureKey == nil then return true end
      return CarpenterDB.featureKey
  end
  ```
- **Missing default in Carpenter.lua**: Every feature key must have a default in the `defaults` table
- **Missing TOC entry**: Module must be in all three `.toc` files
- **Missing config.lua entry**: Every feature needs a `CreateCheckbox()` entry
- **Frame key prefix**: Custom data stored on frames must use `_Carpenter_` prefix
- **Section dividers**: Use `-- =========================` between sections
- **Header comment**: Must start with `--[[ Carpenter - ModuleName ]]`

#### 4. Bug Patterns
- **Race conditions**: Hooking functions before they exist (wrong event timing)
- **Missing event args**: `UNIT_HEALTH` passes `unit` arg - are handlers using it or re-querying?
- **Nameplate lifecycle**: Are cast bars / debuff icons cleaned up on `NAME_PLATE_UNIT_REMOVED`?
- **SavedVariables not ready**: Accessing `CarpenterDB` before `ADDON_LOADED` fires
- **Secure frame in combat**: Modifying action buttons, unit frames, or nameplates during combat lockdown
- **Spell rank handling**: SpellData entries should use `parent` for spell rank chains

#### 5. Security
- **No user input in loadstring/RunScript**: Never construct Lua from player data
- **Macro text injection**: SmartMacros content must be sanitized
- **Tooltip data leaks**: Don't expose hidden tooltip data to chat

### Output Format

For each issue found, report:
```
[SEVERITY] File:Line - Description
  Problem: What's wrong
  Fix: How to fix it
```

Severity levels:
- **CRITICAL**: Will cause errors, taint, or data loss
- **WARNING**: Performance issue or potential bug
- **STYLE**: Convention violation, won't break anything
- **INFO**: Suggestion for improvement

End with a summary: total issues by severity, overall code health assessment, and top 3 priorities to fix.
