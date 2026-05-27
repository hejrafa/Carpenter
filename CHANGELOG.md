# Changelog

## 1.6.6

- Updated the release workflow to use the current GitHub checkout action runtime.
- Replaced the visible synthetic `- ` prefix on Classic/TBC no-objective quest tracker fallback text with a measured objective-text offset for exact first-line and wrapped-line alignment.
- Read Classic/TBC no-objective quest tracker fallback text from the accepted quest's log entry so another quest on the same NPC cannot leak into the tracker.
- Restored Retail player unit-frame class colors while resetting Carpenter's tint back to Blizzard's neutral health-bar texture for NPC and totem targets.
- Added a separate `CarpenterWellFed` smart macro that picks the best available Well Fed buff food while keeping buff food out of the normal recovery food macro.

## 1.6.5

- Fixed hidden chat buttons so hovering the chat area restores them to full opacity.
- Restored Carpenter Action Cam after closing the Narcissus AFK screen so its delayed camera reset does not leave the camera at Blizzard defaults.
- Restored Carpenter Action Cam after hiding and showing the full UI so the camera perspective does not fall back to Blizzard defaults.
- Adjusted nameplate debuff countdown text for small icons while letting cooldown-count addons take over.
- Added Rogue Deadly Poison to enemy nameplate debuff tracking, including stack counters on nameplate debuff icons.
- Stabilized enemy nameplate debuff refreshing on recycled and combat-created nameplates so tracked debuffs keep appearing.
- Added Classic/TBC no-objective quest tracking fallback so quests such as simple "speak with" quests can still appear in the default tracker.
- Wrapped long Classic/TBC objective tracker quest lines with aligned bullet continuations and reflowed the tracker height so long objective text no longer stretches awkwardly across the screen.
- Kept the Classic/TBC objective tracker at a stable width so shorter watched quests do not shrink the tracker.
- Kept Classic/TBC auto-tracked quests pinned after Blizzard's temporary auto-watch expires, while still respecting manual Shift-click untracking.
- Cleared the Classic/TBC objective tracker correctly after the final watched quest is manually untracked.
- Added a nested World Map Cleanup option to show or hide Carpenter's dungeon, raid, flight, and travel POI pins so Classic exploration can stay unspoiled by default.
- Added Classic/TBC bleed tracking to enemy nameplate debuffs for Rend, Deep Wounds, Garrote, Rupture, Rake, Rip, Pounce Bleed, and Lacerate without adding bleeds to unit-frame portrait debuffs.
- Enabled the Classic Settings Preset on TBC/Anniversary clients.
- Hardened Classic/TBC ready checks and raid frame class-color preset application against client API edge cases.
- Added a blank Lua error trace helper for diagnosing empty Lua error popups.
- Removed Fade Extra Action Bars from Classic Era availability and kept it TBC-only.

## 1.6.4

- Added Classic Era and TBC Rogue poison macros with automatic bag-based poison selection, PvE defaults, and Shift-held PvP priorities.
- Added draggable settings previews and clearer labels for the generated poison macros.
- Renamed the generated poison macros to `CarpenterDamage` and `CarpenterUtility`.
- Updated the Carpenter logo artwork.
- Added a World Map Cleanup interface option that lowers the small map, hides the fullscreen blackout, scales maximized maps to 85%, fades the map smoothly while moving unless hovered, hides continent town/city icons, and adds dungeon, raid, and same-faction travel pins.
- Refined World Map Cleanup visuals with dedicated settings art plus clearer travel and combined dungeon/raid map pin textures.
- Fixed World Map Cleanup fullscreen positioning so the maximized map applies its scaled layout immediately instead of visibly hopping into place.
- Cleaned up World Map Cleanup settings copy to avoid external-addon and game-version callouts.
- Fixed poison macro tooltips and action bar icons so Shift-swapping changes the displayed poison instead of keeping a fixed icon.
- Fixed remaining Chat Cleaner loot roll punctuation and colored loot item names inside party and raid loot messages.
- Colored grouped loot and loot-roll prefixes with party or raid chat colors, including bare `Loot:` item messages.
- Styled bare `Loot:` item lines that arrive through chat-frame post-processing, including first visible loot messages with a party- or raid-colored `Loot` label.
- Stopped battleground-result cleanup from hiding player chat that happens to contain story titles such as `Lost in Battle`.
- Changed compact home-bind chat styling from `Home:` to `Hearthstone:`.
- Kept the enemy name in compact Hardcore `was slain by` death messages.
- Updated release packaging so CurseForge and Wago receive only the latest version's changelog section.

## 1.6.3

- Removed the settings scrollbar again and refined the settings panel's top and bottom spacing, including footer version alignment with the reload hint.
- Removed Enhance UI so the feature can be redesigned later without carrying the old module and settings.
- Updated Mount Speed Trinket support so Classic Era only uses Carrot on a Stick, while TBC supports Riding Crop and Carrot on a Stick.
- Improved Consumable Macros on Classic clients by refreshing bag scans when food, water, and consumables change.
- Fixed duplicate merchant money summaries after selling items.
- Simplified Chat Cleaner output by keeping player names the same color as the rest of each message, capitalizing level-up messages as `Reached Level`, and removing the unreliable guild recruitment filter.
- Fixed Chat Cleaner loot messages so loot text is white, `Loot:` prefixes are stripped, and roll lines no longer leak `selected` wording or stray punctuation.
- Tightened the draggable consumable macro icon spacing in the settings sidebar.

## 1.6.2

- Stopped NPC unit frames and recycled NPC nameplates from retaining Carpenter's class-colored health state.
- Split class health coloring into smaller unit-frame and nameplate modules backed by shared safe unit helpers.
- Added Chat Cleaner fixtures, localization parity checks, and a release helper for validation, packaging, and worktree updates.
- Added tag-driven GitHub Actions packaging for GitHub Releases, CurseForge, and Wago using BigWigsMods/packager.

## 1.6.1

- Fixed Retail secret-value taint paths in enhanced tooltip unit detection and class-colored health bar updates.
- Kept Retail NPC party frames out of class health coloring and unit-frame aura portrait replacement while preserving player party frame behavior.
- Removed Retail Hide Group Indicator support and made Threat Percentage explicitly unavailable on Retail.
- Guarded Carpenter's custom threat indicator so it cannot create target or focus threat frames on Retail.
- Hardened the Retail unit-frame cleaner so compact party frame visuals are not hidden or reparented, and legacy hidden party health-loss textures are restored.
- Added Spanish localization coverage for `esES` and `esMX` clients, including settings labels, descriptions, addon messages, Chat Cleaner output, tooltips, warnings, and addon metadata.
- Added Brazilian Portuguese localization coverage for `ptBR` clients, including settings labels, descriptions, addon messages, Chat Cleaner output, tooltips, warnings, and addon metadata.

## 1.6.0

- Hid Carpenter's styled quest accepted line when Story Mode is already replacing that accepted message for one of its story quests.
- Added Classic settings preview images for Enhance UI, Unit Frame Buffs, Target Percentages, and Classic Settings Preset, and included action bar 4 in the Classic Settings preset.
- Improved Chat Cleaner Hardcore death announcements with compact cause-aware styling for slain, drowned, fall, burn, fatigue, and other death messages.
- Fixed Hardcore fall death announcements that use `fell to their death`, `fell to his death`, or `fell to her death` wording.
- Fixed Chat Cleaner loot roll styling so self-roll lines class-color `You` consistently.
- Collapsed the default inactivity AFK message from `AFK: AFK` to `AFK` while keeping custom AFK messages intact.
- Added German, French, and Russian localization files for settings labels, sidebar descriptions, addon messages, Chat Cleaner output, tooltips, warnings, and Retail addon-compartment tooltip text.
- Moved settings sidebar descriptions out of `Modules/ConfigOptions.lua` and into localization keys so future translations can land without touching settings layout code.
- Added localized TOC notes for German, French, and Russian clients.

## 1.5.1

- Shortened Hardcore death channel messages to remove the channel prefix and death source details.

## 1.5.0

- Refactored Classic/TBC/Retail feature startup through shared lifecycle registration, refresh, and deferred execution helpers for more reliable enable/disable behavior.
- Split Chat Cleaner into focused helper modules for loot, rewards, social/system messages, session tracking, post-processing, and shared utilities.
- Improved Chat Cleaner performance and reliability by reducing repeated inline parsing, centralizing message formatting helpers, and making chat filter registration idempotent.
- Hardened chat session tracking for merchant, mail, repair, auction, money, loot, honor, queue, quest, level-up, reputation, and skill messages.
- Migrated multiple Classic modules to lifecycle-managed events and timers so toggles cleanly register, unregister, and refresh without duplicate hooks.
- Fixed the split settings panel so option sections render correctly on Retail.
- Fixed Retail unit-frame cleaner nameplate lookups for party and raid unit events.
- Guarded NPC health bars from stale class-color tinting when unit frames or nameplates are recycled.
- Hid unsupported target percentage and settings preset options on Anniversary/TBC.
- Improved Enhanced Tooltip compatibility on Anniversary/TBC, including player tooltip refresh handling and target-line sizing.

## 1.4.3

- Added an opt-in Classic target health and resource percentage display for hostile targets and player targets with proper settings text and Blizzard-style target-frame placement.
- Added Classic health percentage status text to the Classic Settings preset without enabling the target-frame percentage option by default.

## 1.4.2

- Fixed Classic Era target and target-of-target class health coloring so NPC unit frames keep Blizzard's default health bar color while player unit frames still use class colors.
- Added compact home-bind chat styling such as `Home: The Sepulcher`.
- Fixed malformed loot roll fallback messages that could show `rolls ?:` when a roll number or item was missing.
- Removed the Classic Enhance UI flight map changes so the default taxi map stays untouched.
- Changed food macro scoring so Well Fed food is only selected when no normal health-restoring food is available.
- Fixed Retail enhanced tooltips so protected unit values from refreshed unit-frame tooltips no longer throw `UnitReaction` errors.
- Stopped fading Social and Quick Join buttons with Hide Chat Buttons to avoid stuck half-visible social toast states.
- Removed the redundant Mainline TOC and made `Carpenter.toc` the Retail TOC for interface `120005`.
- Matched the Retail TOC to StoryMode's format with `120001, 120005` support and addon-compartment metadata.
- Removed duplicate manual addon-compartment registration now that Retail uses TOC-driven callbacks.
- Fixed Vanilla food and water macro detection by falling back to full tooltip restore text when `useText` is empty.

## 1.4.1

- Improved Chat Cleaner styling for Classic level-up reward messages, including reached-level, hit point, talent point, and stat increase lines.
- Styled newly gained skill messages such as "You have gained the Subtlety skill."
- Fixed the HP consumable macro in Classic/TBC by removing combat conditionals from healthstone and potion `/use` lines.
- Fixed Retail food macro detection by reading modern tooltip data more broadly.
- Refined level-up reward chat lines to use compact `+` formatting for hit points, talent points, and stat gains.
- Added Cannibalize support and cooldown-aware ordering to the HP consumable macro so ready heals appear first.
- Added the Auto Track Quests settings preview image.
- Reorganized addon artwork into `Art/Icons`, `Art/Masks`, and `Art/Settings` folders with separate Classic and Retail settings previews.
- Merged Retail unit frame combat text hiding into the renamed Clean Unit Frame option.
- Added a Classic Settings category with a Preset option for auto loot, enemy nameplates, minion nameplates, and action bars 2/3.
- Added Classic Enhance UI support for wider quest log, profession, trainer, and flight map frames, including a trainer scroll-area fix.
- Updated Classic chat cleanup with Story Mode yellow styling, cleaner Hardcore level 60 messages, profession-learn deduping, and duplicate merchant money protection.
- Refined Classic/TBC consumable macros by removing Cannibalize from the health macro and excluding health regeneration potions from immediate health restores.
- Added player buff highlights for important self buffs such as Sprint, Slice and Dice, offensive cooldowns, defensive cooldowns, and immunities.
- Applied class-colored health bars to target-of-target frames.
- Kept Sap-related errors such as "Invalid target" and "Target is in combat" visible when error hiding is enabled.
- Fixed Retail Clean Unit Frame target reputation color hiding so it no longer nudges target name or level text, and refreshed the Retail class health bar preview image.
- Fixed Retail chat tabs sometimes ignoring the hidden chat-button opacity state until clicked.

## 1.4.0

- Renamed the addon to Carpenter and refreshed addon metadata.
- Added dedicated Retail, Classic Era, and TBC TOC support.
- Moved shared startup code into `Core/` and added a compatibility layer for client-specific feature availability.
- Added localization scaffolding with English defaults and German overrides for metadata, settings shell text, and addon chat messages.
- Enabled validated Retail support for shared Carpenter modules without applying Retail-only behavior to Classic/TBC clients.
- Reworked Consumable Macros so food selection is stable and based on the best matching item, not bag position.
- Kept Consumable Macros from recreating legacy `Classic*` macros while still updating them when already present.
- Improved Chat Cleaner styling for level-up rewards, stat gains, reputation gains, currency receives, loot receives, instance saves, and other Retail receive messages.
- Tuned nameplate combo point size and spacing.
- Added the cover fade mask treatment to settings preview images.
- Let positional ability errors like "Must be behind your target" show again.
- Added Auto Track Quests for newly accepted quests.
- Added Retail support for enhanced tooltip styling with secure tooltip guards and hidden tooltip health bars.
- Added Retail support for Action Cam spell overlay Y-offset handling.
- Added Retail UI cleanup for fading the micro menu and bags together, with wider hover handling.
- Added Retail chat cleanup for hiding chat buttons and chat tabs.
- Added Retail unit frame cleanup options for hiding PvP icons, power/class resource bars, boss frames, rest animation, combat icon, health loss FX, group indicator, role icon, PvP timer, realm indicator, player corner icon, party frame title text, and target reputation color.
- Added Retail unit frame combat text hiding and class-colored health bar support.
- Registered Carpenter with the Retail AddOn Compartment menu.
