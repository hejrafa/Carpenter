# Changelog

## 1.5.0

- Improved Chat Cleaner styling for Classic level-up reward messages, including reached-level, hit point, talent point, and stat increase lines.
- Styled newly gained skill messages such as "You have gained the Subtlety skill."
- Fixed the HP consumable macro in Classic/TBC by removing combat conditionals from healthstone and potion `/use` lines.
- Fixed Retail food macro detection by reading modern tooltip data more broadly.
- Added the Auto Track Quests settings preview image.

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
