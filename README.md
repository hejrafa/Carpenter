# Carpenter

*Measure twice, cut the clutter.*

You like Blizzard's interface. You just wish it would stop shouting. Carpenter keeps the UI you know and gives it a good sanding: less visual noise, chat you can actually read, combat information where your eyes already are, and a handful of small automations that save you trips to the vendor.

Every tool in the box is optional and switched off until you pick it up. Type `/carpenter` or `/cp`, enable what you like, reload when asked, and leave the rest on the workbench.

## Why Carpenter?

- **No full UI replacement.** Just focused, one-click cleanups.
- **Nothing changes until you say so.** Every feature starts disabled.
- **Still feels like World of Warcraft.** Blizzard's UI stays recognizable, only calmer and easier to scan.
- **Quality of life, not autopilot.** The automations handle chores, never your gameplay.
- **One addon for every client.** Options that don't apply to your game are hidden automatically.

## What It Fixes

### Chat Gets Readable Again

Loot, experience, reputation, money, rolls, repairs, auctions, new abilities, and level-ups arrive as short, color-coded lines instead of paragraphs. Bot ads, gambling spam, and duplicate lines quietly disappear.

### Combat Information Is Easier To Scan

Class-colored health bars, combo points on your target's nameplate, crowd control and bleed tracking, a threat percentage on the target frame, and class-icon portraits help the important things stand out at a glance.

### The Default UI Stops Shouting

Macro names, keybind labels, minimap buttons, chat buttons, the stance bar, frame decorations, portrait combat text, and red error spam can all take a step back.

### Small Chores Disappear

Junk gets sold, gear gets repaired, new quests land in your tracker, mount-speed trinkets swap themselves, and your consumable and poison macros always point at the best thing in your bags.

## Features

### Action Bars

- **Hide Macro Names** - Keep macro labels off your action buttons.
- **Hide Keybind Text** - Keep hotkey labels off your action buttons.
- **Fade Extra Action Bars** - Fade bars 7 and 8 until you hover over them.
- **Out of Range Tint** - Darken abilities while your target is out of range.
- **Hide Stance Bar** - Hide the bar for forms, stances, and stealth. Your keybinds keep working.

### Interface

- **Fade Micro Menu & Bags** - Fade the micro menu and bag bar until you hover over them or open your bags.
- **Fade Exp & Rep Bars** - Lower the opacity of the experience and reputation bars.
- **Remove Minimap Clutter** - Fade addon and queue buttons until you hover, and hide the day/night icon and zoom buttons.
- **Hide Quest Tracker Titles** - Hide objective tracker section headers while keeping your objectives in view.
- **World Map Cleanup** - Lower the small map, drop the fullscreen blackout, fade the map while you move, hide continent town icons, and optionally show dungeon, raid, and travel pins.
- **Profession Icon Portrait** - Show your profession's icon in crafting windows.
- **Talent Icon Portrait** - Show your talent tree's icon in the talent window.
- **Enhanced Tooltip** - Tidy unit tooltips and show who the unit is targeting.
- **Scale Extra Ability** - Shrink the Extra Action and Zone Ability buttons to 80%.
- **Hide Boss Frames** - Fade boss unit frames and let your mouse pass through them.

### Unit Frames

- **Class Colored Health** - Color player, target, focus, and party health bars by class.
- **Threat Percentage** - Show your threat on the target frame.
- **Debuffs** - Highlight stuns, polymorphs, fears, and other crowd control on the player and target frames.
- **Buffs** - Highlight your big cooldowns and immunities on the player frame.
- **Class Icon Portrait** - Swap unit portraits for class icons.
- **Hide Unit Frame Combat Text** - Keep damage and healing numbers off your portraits.
- **Clean Unit Frame** - Hide the combat sword, Zzz rest animation, health loss effects, realm indicators, party title text, and other small decorations.
- **Hide Combo/Power Bar** - Hide class resource widgets such as combo points, runes, and holy power.

### Nameplates

- **Debuffs** - Show important crowd control and bleeds above enemy nameplates.
- **Combo Points** - Show your combo points on your target's nameplate.

### Chat

- **Filter** - Block bot ads, gambling spam, and duplicate lines.
- **Cleaner** - Restyle system and loot messages into short, color-coded lines.
- **Hide Chat Buttons** - Fade the chat buttons until you hover over the chat.

### Automations

- **Mount Speed Trinket** - Equip your Riding Crop or Carrot on a Stick when you mount up, and put your old trinket back when you land.
- **Consumable Macros** - Draggable macros that always use your best food, Well Fed food, water, potions, and bandage.
- **Rogue Macros** - Poison macros for each hand, with PvP picks on Shift, plus a Thistle Tea macro that brews everything you can.
- **Auto Track Quests** - Add newly accepted quests to your tracker and keep them pinned.
- **Auto Sell Junk** - Sell grey items at merchants. Hold Shift to skip.
- **Auto Repair** - Repair your gear at vendors. Hold Shift to skip.

### Text

- **Poison Warning** - Get a warning when your poison or other weapon buff is missing or about to wear off.
- **Hide Error Messages** - Silence "Out of range", "Not enough energy", and friends, while important errors still get through.

### Immersion

- **Action Cam** - See Azeroth from over your shoulder.
- **Explorer Mode** - Slowly fade the HUD out of combat so the world gets the whole screen. *(Beta)*

## Installation

Download Carpenter from CurseForge, Wago, or GitHub Releases. For a manual install, place the `Carpenter` folder in the AddOns directory of your game client, for example:

```text
World of Warcraft/_retail_/Interface/AddOns/Carpenter
World of Warcraft/_classic_era_/Interface/AddOns/Carpenter
World of Warcraft/_anniversary_/Interface/AddOns/Carpenter
```

## Configuration

Type `/carpenter` or `/cp` in-game to open the workshop. Hover over any option to see what it does before you switch it on.

Most options apply immediately. A few need a UI reload, and the settings panel will tell you when.

## Compatibility

Carpenter runs on:

- World of Warcraft
- WoW Classic Era and Anniversary realms
- WoW Classic: The Burning Crusade
- WoW Forever (beta)

Not every option exists on every client. Carpenter only shows the ones your game supports.

## Project Structure

- `Core/` - shared bootstrap, client detection, feature lifecycle helpers, and safe unit helpers
- `Localization/` - English defaults plus German, Spanish, French, Portuguese, and Russian overrides
- `Modules/` - feature modules, loaded by each game client's TOC
- `Art/` - addon icons, masks, and settings preview artwork
- `tools/` - local validation, fixture, packaging, asset, localization, and worktree helper scripts
- `DESCRIPTION.md` - CurseForge/Wago-facing project description
- `CHANGELOG.md` - source release notes; the release workflow extracts the current version section into `.packager/changelog.md` for publishing

## Local Validation

Run the full release validation before tagging or packaging:

```bash
bash tools/release.sh check
```

That validates TOC references, changelog metadata, Lua syntax, offline fixtures, localization coverage, artwork references, and cross-file addon shape.

## Release Publishing

GitHub Actions packages Carpenter only when a version tag is pushed. Normal pushes to `main` do not publish. The workflow validates the tag against the committed TOC/changelog metadata, runs `bash tools/release.sh check`, builds the addon zip with the BigWigs WoW Packager, creates a GitHub Release, and uploads the same package to CurseForge and Wago.

Required GitHub repository secrets:

- `CF_API_KEY`: CurseForge API token. Create it from your CurseForge account API Tokens page: https://www.curseforge.com/account/api-tokens
- `CF_PROJECT_ID`: CurseForge numeric project ID. Open the Carpenter project page on CurseForge and copy the Project ID from the About Project box.
- `WAGO_API_TOKEN`: Wago Addons API token. Create it from the Wago developer portal: https://addons.wago.io/account/api-tokens
- `WAGO_PROJECT_ID`: Wago project ID. Open the Wago developer dashboard and copy the alphanumeric ID shown under the Carpenter project name.

Add secrets in GitHub at `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`.

Release flow:

```bash
bash tools/release.sh check
git tag v1.6.8
git push origin main v1.6.8
```

The tag must be strict `vMAJOR.MINOR.PATCH`, and the number must match `## Version:` in all TOC files. Platform project IDs stay in GitHub secrets; do not add `X-Curse-Project-ID` or `X-Wago-ID` to the TOCs.

The package rules live in `.pkgmeta`; `.github`, local tools, caches, and docs such as `README.md` and `DESCRIPTION.md` are excluded from release zips. During tag builds, GitHub Actions writes a temporary `.packager/pkgmeta.yaml` so CurseForge and Wago receive only the latest version's extracted changelog section, not the full historical changelog.
