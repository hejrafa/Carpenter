# Carpenter

*Measure twice, cut the clutter.*

Carpenter keeps Blizzard's UI and sands it down: quieter bars, readable chat, combat info where you already look, and a few chores done for you. Every option starts off. Type `/cp`, pick what you like, and leave the rest on the workbench.

## What's in the box

- **Action bars** - Hide macro names, keybinds, and the stance bar. Fade extra bars and tint abilities that are out of range.
- **Interface** - Fade the XP bar and minimap clutter. Tidy the quest tracker, world map, and tooltips, and silence error spam.
- **Unit frames** - Class-colored health, threat, crowd control and cooldown highlights, class-icon portraits, and fewer decorations.
- **Nameplates** - Crowd control, bleeds, and combo points above your enemies.
- **Chat** - Loot, XP, money, and rolls as short color-coded lines, with bot and gambling spam filtered out.
- **Chores** - Sell junk, repair, track new quests, swap mount-speed trinkets, warn about missing poisons, and keep food, potion, and poison macros pointed at your best stuff.
- **Immersion** - Action Cam, Explorer Mode to fade the HUD out of combat, and fades for the micro menu, bags, and minimap until you hover over them.

## Works on

Retail, Classic Era and Anniversary, Burning Crusade Classic, and WoW Forever (beta). Carpenter only shows the options your game supports.

Get it from CurseForge, Wago, or GitHub Releases, or drop the `Carpenter` folder into your game's `Interface/AddOns`.

## Development

- `Core/` - bootstrap, client detection, and the feature manifest
- `Modules/` - features, loaded per client by the TOCs
- `Localization/` - English, plus German, Spanish, French, Portuguese, and Russian
- `Art/` - icons and settings previews for Classic, Retail, and Forever
- `tools/` - checks, fixtures, and the release script

Run every check (TOCs, changelog, Lua syntax, fixtures, localization, art, addon shape) before tagging:

```bash
bash tools/release.sh check
```

## Releasing

Pushing a `vMAJOR.MINOR.PATCH` tag that matches `## Version:` in the TOCs runs the checks and publishes the package to GitHub, CurseForge, and Wago. Pushes to `main` alone publish nothing.

```bash
git tag vX.Y.Z
git push origin main vX.Y.Z
```

The workflow needs the repository secrets `CF_API_KEY`, `CF_PROJECT_ID`, `WAGO_API_TOKEN`, and `WAGO_PROJECT_ID`. The project description isn't uploaded: paste `DESCRIPTION.md` into CurseForge and Wago by hand.
