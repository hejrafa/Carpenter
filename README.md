# Carpenter

UI tweaks and quality-of-life improvements for WoW Classic. Turn on what you need, leave the rest off.

The default UI is cluttered and missing information. Carpenter fixes it.

## Features

### Action Bars
- **Hide Macro Names** — Remove macro text from action buttons
- **Hide Keybind Text** — Remove hotkey labels from action buttons
- **Fade Extra Action Bars** — Bars 7 & 8 fade out until you hover
- **Out of Range Tint** — Darkens abilities when your target is out of range
- **Hide Stance Bar** — Hides the stance/form/stealth bar

### Interface
- **Fade Micro Menu & Bags** — Hides until you hover *(TBC only)*
- **Resize Exp & Rep Bars** — Smaller, transparent bars *(TBC only)*
- **Remove Minimap Clutter** — Hides zoom buttons, day/night icon, zone text
- **Enhanced Tooltip** — Cleaner unit tooltips with target-of-target info

### Unit Frames
- **Class Colored Health** — Health bars use class colors instead of green
- **Threat Percentage** — Shows your threat % on the target frame
- **Debuffs** — Highlights CC effects on player and target frames
- **Class Icon Portrait** — Replaces portraits with class icons
- **Hide Combat Text** — Removes floating numbers from unit frames

### Nameplates
- **Debuffs** — Shows CC effects above enemy nameplates
- **Combo Points** — Displays combo points on the target nameplate
- **Spell Names** — Shows spell names on nameplate cast bars
- **Class Colored Health** — Enemy player nameplates use class colors
- **Raid Target Icon Aligned** — Moves raid icons flush with the nameplate

### Chat
- **Filter** — Blocks bot spam, gambling, and duplicates
- **Cleaner** — Restyles system/loot messages (exp, rep, money, etc.)
- **Hide Chat Buttons** — Hides Social, Channels, Voice buttons until hover

### Automations
- **Mount Speed Trinket** — Auto-equips Carrot on a Stick in Classic Era, or Riding Crop/Carrot in TBC, when mounting
- **Consumable Macros** — Creates smart macros that always use your best food, water, potions, and bandages
- **Auto Track Quests** — Adds newly accepted quests to the objective tracker
- **Auto Sell Junk** — Sells grey items at vendors (hold Shift to skip)
- **Auto Repair** — Repairs gear at vendors (hold Shift to skip)

### Text
- **Poison Warning** — Alerts when your weapon buff is about to expire
- **Hide Error Messages** — Silences spam like "Out of range" and "Not enough energy"

### Immersion
- **Action Cam** — Over-the-shoulder cinematic camera

## Installation

Download or clone this repo into your AddOns folder:
```
World of Warcraft/_anniversary_/Interface/AddOns/Carpenter
```

## Configuration

Type `/carpenter` or `/cp` in-game to open the settings panel. Every feature is off by default — toggle what you want and reload your UI.

## Compatibility

- Retail / Mainline (12.0.x) - shell support only; gameplay options are disabled until validated
- WoW Classic Anniversary / Vanilla (1.15.x)
- WoW Classic TBC (2.5.x)

Some features (Micro Menu fade, Exp/Rep bar resize) are TBC-only.

## Project Structure

- `Core/` - shared bootstrap and client compatibility checks
- `Localization/` - English defaults plus locale-specific overrides
- `Modules/` - feature modules loaded by the Retail, Classic Era, and TBC TOCs
- `tools/` - local validation, fixture, packaging, and worktree helper scripts
- `CHANGELOG.md` - source release notes; `tools/release.sh check` extracts the current version section into `.release/CHANGELOG.md` for publishing

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
git tag v1.6.4
git push origin main v1.6.4
```

The tag must be strict `vMAJOR.MINOR.PATCH`, and the number must match `## Version:` in all TOC files. Platform project IDs stay in GitHub secrets; do not add `X-Curse-Project-ID` or `X-Wago-ID` to the TOCs.

The package rules live in `.pkgmeta`; `.github`, `_Dev`, local tools, caches, and docs such as `README.md` and `DESCRIPTION.md` are excluded from release zips. CurseForge and Wago receive only the latest version's extracted changelog section, not the full historical changelog.
