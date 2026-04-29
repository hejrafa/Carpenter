Add spell entries to the Carpenter SpellData.lua database: $ARGUMENTS

## Instructions

You are adding spell data entries to `SpellData.lua` for the Carpenter WoW addon. This database is used by DebuffTracker and other modules to identify and categorize auras.

### Spell Categories

Use these exact constants (defined at top of SpellData.lua):

| Constant | Use For |
|----------|---------|
| `CROWD_CONTROL` | Stuns, Fears, Polys, Saps, Blinds, Sleeps, Incapacitates |
| `ROOT` | Frost Nova, Entangling Roots, Hamstring (immobilizes) |
| `BUFF_DEFENSIVE` | Shield Wall, Ice Block, Divine Shield, Evasion |
| `BUFF_OFFENSIVE` | Recklessness, Arcane Power, Combustion, trinket procs |
| `BUFF_OTHER` | Misc buffs that don't fit offensive/defensive |
| `INTERRUPT` | Kick, Counterspell, Pummel, Earth Shock |
| `IMMUNITY` | Full damage immunities (Divine Shield, Ice Block) |
| `IMMUNITY_SPELL` | Spell-only immunities (Grounding Totem, Spell Reflect) |

### Entry Format

Standard entry:
```lua
[<spellID>] = { type = <CATEGORY> }, -- <Spell Name>
```

Spell rank chain (ranks 2+ reference rank 1):
```lua
[<rank1ID>] = { type = <CATEGORY> }, -- <Spell Name>
[<rank2ID>] = { parent = <rank1ID> }, -- <Spell Name> (Rank 2)
[<rank3ID>] = { parent = <rank1ID> }, -- <Spell Name> (Rank 3)
```

### Steps

1. **Look up spell IDs**: Search for the correct Classic/TBC spell IDs. Use wowhead.com/classic or similar for Classic Anniversary spell IDs. Do NOT use retail spell IDs.

2. **Determine the category**: Classify the spell using the table above. When in doubt:
   - If it stops you from acting → `CROWD_CONTROL`
   - If it stops you from moving but you can still cast → `ROOT`
   - If it protects → `BUFF_DEFENSIVE`
   - If it enhances damage → `BUFF_OFFENSIVE`

3. **Find the right section**: SpellData.lua is organized by class:
   - Racials
   - Other (items, engineering, etc.)
   - Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior

4. **Add entries**: Place them in the correct class section, maintaining spell ID order within each section.

5. **Handle spell ranks**: For spells with multiple ranks:
   - Rank 1 gets the full `{ type = CATEGORY }` entry
   - All subsequent ranks use `{ parent = <rank1ID> }` pointing to rank 1's spell ID
   - This avoids duplicating the type across every rank

6. **Priority/Warning debuffs**: If the spell should always be visible on nameplates (like Mortal Strike, Faerie Fire), also add it to:
   - `addon.PriorityDebuffs` table - for always-visible but normal-sized debuffs
   - `addon.WarningDebuffs` table - for enlarged/highlighted dangerous debuffs (Unstable Affliction, Vampiric Touch)

### Validation

After adding entries, verify:
- No duplicate spell IDs in the file
- All `parent` references point to existing spell IDs in the table
- Comments match the actual spell name for that ID
- Spell IDs are for Classic (1.12.x / 2.4.3), NOT retail

### Example

Adding Mage Frost Nova (all ranks):
```lua
-- In the Mage section:
[122] = { type = ROOT }, -- Frost Nova
[865] = { parent = 122 }, -- Frost Nova (Rank 2)
[6131] = { parent = 122 }, -- Frost Nova (Rank 3)
[10230] = { parent = 122 }, -- Frost Nova (Rank 4)
[27088] = { parent = 122 }, -- Frost Nova (Rank 5)
```
