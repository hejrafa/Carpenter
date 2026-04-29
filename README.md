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
- **Filter** — Blocks guild recruitment spam, bots, gambling, and duplicates
- **Cleaner** — Restyles system/loot messages (exp, rep, money, etc.)
- **Hide Chat Buttons** — Hides Social, Channels, Voice buttons until hover

### Automations
- **Mount Speed Trinket** — Auto-equips Riding Crop or Carrot on a Stick when mounting
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
- `Modules/` - feature modules loaded by the Classic Era and TBC TOCs
