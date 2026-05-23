# Carpenter

Make WoW's default UI quieter without replacing it. Carpenter trims visual noise, cleans up chat, improves combat readability, and adds small automations that save clicks.

It is built for players who like Blizzard's UI, but want it calmer, sharper, and less fussy. Every feature is optional and disabled by default. Open `/carpenter` or `/cp`, enable what you like, reload when prompted, and leave the rest alone.

## Why Carpenter?

- No full UI replacement, just focused cleanup toggles.
- Every feature is optional and off by default.
- Works across Retail/Mainline, Classic Era, Anniversary, and TBC with flavor-specific options.
- Keeps Blizzard's UI recognizable while making common information easier to scan.
- Adds quality-of-life automation without changing how the game plays.

## What It Fixes

### Chat Gets Readable Again

Carpenter restyles loot, XP, reputation, money, rolls, repairs, auctions, learned skills, level-ups, and other system messages into compact, color-coded lines. It also filters common bot spam, gambling messages, and duplicate chat lines.

### Combat Information Is Easier To Scan

Class-colored health bars, nameplate cast names, combo points, crowd-control tracking, threat percentage, class-icon portraits, and cleaner unit frames help important information stand out faster.

### The Default UI Stops Shouting

Hide macro names, hotkey labels, minimap clutter, chat buttons, stance bars, frame decoration, combat text on unit frames, error spam, and other visual noise that builds up around the default UI.

### Small Chores Disappear

Auto sell junk, auto repair, auto track newly accepted quests, swap mount-speed trinkets, generate consumable macros, and generate Rogue poison macros that follow your bags.

## Features

### Action Bars

- **Hide Macro Names** - Remove macro text from action buttons.
- **Hide Keybind Text** - Remove hotkey labels from action buttons.
- **Fade Extra Action Bars** - Fade bars 7 and 8 until you hover them.
- **Out of Range Tint** - Darken abilities when your target is out of range.
- **Hide Stance Bar** - Hide the stance, form, and stealth bar.

### Interface

- **Fade Micro Menu & Bags** - Hide the micro menu and bag bar until you hover.
- **Resize Exp & Rep Bars** - Make experience and reputation bars smaller and less visually loud.
- **Remove Minimap Clutter** - Hide minimap zoom buttons, day/night icon, and zone text.
- **World Map Cleanup** - Lower the small map, remove fullscreen blackout, fade while moving, hide continent city clutter, and optionally show dungeon, raid, and same-faction travel pins.
- **Enhanced Tooltip** - Clean up unit tooltips with clearer health, level, and target information.
- **Scale Extra Ability** - Reduce oversized Retail extra action and zone ability buttons.

### Unit Frames

- **Class Colored Health** - Use class colors for player, target, focus, and party health bars where class information is available.
- **Threat Percentage** - Show your threat percentage on the target frame.
- **Target Percentages** - Show compact health and resource percentages on target frames.
- **Debuffs** - Highlight important crowd control effects on player and target unit frames.
- **Buffs** - Highlight important player buffs on the player unit frame.
- **Class Icon Portrait** - Replace unit portraits with class icons.
- **Hide Unit Frame Combat Text** - Remove floating combat numbers and state text from unit frames.
- **Clean Unit Frame** - Hide Retail frame clutter such as PvP icons, rest animation, health-loss effects, realm indicators, party title text, and related decoration.
- **Hide Boss Frames** - Fade Retail boss frames and disable mouse interaction.
- **Hide Combo/Power Bar** - Hide Retail class resource widgets.
- **Hide Group Indicator** - Hide the small group marker on the player frame.

### Nameplates

- **Debuffs** - Show important crowd control effects above enemy nameplates.
- **Combo Points** - Display combo points on the target nameplate.
- **Cast Bar** - Show spell icons, names, progress, and interrupt feedback under enemy nameplates.
- **Class Colored Health** - Use class colors for enemy player nameplate health bars.
- **Raid Target Icon Aligned** - Move raid target icons closer to the nameplate they belong to.

### Chat

- **Filter** - Block common bot spam, gambling messages, and duplicate lines.
- **Cleaner** - Restyle system, loot, experience, reputation, money, skill, level-up, currency, repair, auction, and roll messages.
- **Hide Chat Buttons** - Hide Social, Channels, Voice, scroll, and minimize buttons until you hover the chat area.

### Automations

- **Mount Speed Trinket** - Equip Carrot on a Stick in Classic Era, or Riding Crop/Carrot in TBC, when mounting.
- **Consumable Macros** - Create draggable macros that track your best food, water, health potion, mana potion, and supported bandage.
- **Poison Macros** - Create Rogue poison macros with PvE priorities by default and PvP priorities while holding Shift.
- **Auto Track Quests** - Add newly accepted quests to the objective tracker and keep tracked quests pinned after Classic's temporary auto-watch expires.
- **Auto Sell Junk** - Sell grey items at vendors. Hold Shift to skip.
- **Auto Repair** - Repair gear at vendors. Hold Shift to skip.

### Text

- **Poison Warning** - Alert when your weapon buff is missing or about to expire.
- **Hide Error Messages** - Silence common spam like "Out of range" and "Not enough energy" while keeping useful errors visible.

### Settings

- **Classic Settings Preset** - Apply a quick Classic baseline for auto loot, nameplates, health percentages, and extra action bars.

### Immersion

- **Action Cam** - Enable an over-the-shoulder cinematic camera.

## Installation

Download Carpenter from CurseForge, Wago, or GitHub Releases. For a manual install, place the `Carpenter` folder in the matching client AddOns directory:

```text
World of Warcraft/_retail_/Interface/AddOns/Carpenter
World of Warcraft/_classic_era_/Interface/AddOns/Carpenter
World of Warcraft/_anniversary_/Interface/AddOns/Carpenter
```

## Configuration

Type `/carpenter` or `/cp` in-game to open the settings panel. Every feature is off by default, so enable only the pieces you want.

Some settings apply immediately. Others require a UI reload and will show a reload hint in the settings panel.

## Compatibility

- Retail / Mainline
- WoW Classic Era
- WoW Classic Anniversary
- WoW Classic TBC

Some options are only available on specific game flavors. Carpenter hides unsupported settings automatically.

## Project Structure

- `Core/` - shared bootstrap, client detection, feature lifecycle helpers, and safe unit helpers
- `Localization/` - English defaults plus German, Spanish, French, Portuguese, and Russian overrides
- `Modules/` - feature modules loaded by the Retail, Classic Era, and TBC TOCs
- `Art/` - addon icons, masks, and settings preview artwork
- `tools/` - local validation, fixture, packaging, asset, localization, and worktree helper scripts
- `DESCRIPTION.md` - CurseForge/Wago-facing project description
- `CHANGELOG.md` - source release notes; `tools/release.sh check` extracts the current version section into `.release/CHANGELOG.md` for publishing

## Local Validation

Run the full release validation before tagging or packaging:

```bash
tools/release.sh check
```

That validates TOC references, changelog metadata, Lua syntax, chat-cleaner fixtures, smart-macro fixtures, localization coverage, and artwork references.

## Release Publishing

GitHub Actions packages Carpenter only when a version tag is pushed. Normal pushes to `main` do not publish. The workflow validates the tag against the committed TOC/changelog metadata, runs `tools/release.sh check`, builds the addon zip with the BigWigs WoW Packager, creates a GitHub Release, and uploads the same package to CurseForge and Wago.

Required GitHub repository secrets:

- `CF_API_KEY`: CurseForge API token. Create it from your CurseForge account API Tokens page: https://www.curseforge.com/account/api-tokens
- `CF_PROJECT_ID`: CurseForge numeric project ID. Open the Carpenter project page on CurseForge and copy the Project ID from the About Project box.
- `WAGO_API_TOKEN`: Wago Addons API token. Create it from the Wago developer portal: https://addons.wago.io/account/api-tokens
- `WAGO_PROJECT_ID`: Wago project ID. Open the Wago developer dashboard and copy the alphanumeric ID shown under the Carpenter project name.

Add secrets in GitHub at `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`.

Release flow:

```bash
tools/release.sh check
git tag v1.6.5
git push origin main v1.6.5
```

The tag must be strict `vMAJOR.MINOR.PATCH`, and the number must match `## Version:` in all TOC files. Platform project IDs stay in GitHub secrets; do not add `X-Curse-Project-ID` or `X-Wago-ID` to the TOCs.

The package rules live in `.pkgmeta`; `.github`, local tools, caches, and docs such as `README.md` and `DESCRIPTION.md` are excluded from release zips. CurseForge and Wago receive only the latest version's extracted changelog section, not the full historical changelog.
