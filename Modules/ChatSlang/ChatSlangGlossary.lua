--[[ Carpenter - Chat Slang glossary ]]
-- Glossary text and usage examples come from SlangSight 0.1.8-beta1 by PacHD,
-- used under the MIT License. See LICENSE-SlangSight.txt in this folder.
local _, ns = ...
ns.Private = ns.Private or {}

local entries = {}
ns.Private.ChatSlangGlossary = entries

local RAW = [==[
10-MAN|Ten-player raid|Raids|A raid for ten players; availability depends on the game version.
1H|One-Handed|Items|A weapon used in one hand.
1V1|One versus one|PvP|Two players fighting each other.
25-MAN|Twenty-five-player raid|Raids|A raid for twenty-five players; expansion terminology.
2H|Two-Handed|Items|A weapon requiring both hands.
40-MAN|Forty-player raid|Raids|A raid for forty players.
5-MAN|Five-player party|Groups|A five-player group, usually for a dungeon.
AB|Arathi Basin / Arcane Blast / Arcane Brilliance|PvP|Battleground or mage spell abbreviation; spell availability depends on version.
ABAR|Arcane Barrage|Classes|Mage spell shorthand; version-dependent.
AC|Auchenai Crypts / Armor Class|Dungeons|An Outland dungeon, or armor class in older RPG terminology.
AD|Argent Dawn|Leveling|Faction name.
ADD|Additional Enemy|PvE|An extra enemy joining an encounter.
ADDON|Addon|World|Player-made interface extension.
ADDS|Additional Enemies|PvE|Multiple extra enemies in an encounter.
AE|Arcane Explosion / Area Effect|Classes|Mage spell or area-effect shorthand.
AFAIK|As Far As I Know|Chat|Signals uncertainty about a statement.
AFK|Away From Keyboard|Chat|The player is temporarily away.
AGGRO|Aggro|Combat|An enemy is attacking or focused on a player.
AGGRO RADIUS|Aggro radius|Combat|Distance at which an enemy notices you.
AGI|Agility|Stats|A primary character statistic.
AH|Auction House|Trading|Marketplace where players list and purchase items.
AI|Arcane Intellect|Classes|Mage intellect buff; also artificial intelligence outside spell discussions.
ALCH|Alchemy|Professions|Profession that creates potions and other alchemical products.
ALT|Alternate Character|Characters|Another character belonging to a player.
AM|Arcane Missiles|Classes|Mage spell shorthand.
AOE|Area of Effect|Combat|An ability that affects an area or multiple targets.
AP|Attack Power / Arcane Power|Stats|Physical-damage statistic, or mage damage cooldown.
AQ|Ahn'Qiraj|Raids|General shorthand for Ahn'Qiraj content.
AQ20|Ruins of Ahn'Qiraj|Raids|The smaller Ahn'Qiraj raid.
AQ40|Temple of Ahn'Qiraj|Raids|The larger Ahn'Qiraj raid.
ARM|Armory|Dungeons|Often refers to the Scarlet Monastery Armory wing.
ARMOR|Armor|Stats|Reduces certain incoming physical damage.
ATM|At The Moment|Chat|Means right now.
ATTUNEMENT|Attunement|Progression|Required access quest or prerequisite.
AV|Alterac Valley|PvP|Large-scale battleground.
AVATAR|Player character|Other|Your in-game character.
BACKPEDAL|Backpedal|Combat|Move backwards rather than strafe or turn.
BARRENS CHAT|Barrens chat|Chat/Slang|Nickname for chaotic zone chatter.
BB|Booty Bay|Leveling|Town in Stranglethorn Vale.
BENCH|Bench|Guild|Raiders sitting out the current group.
BFD|Blackfathom Deeps|Dungeons|A dungeon.
BG|Battleground|PvP|An instanced PvP match between teams.
BGS|Battlegrounds|PvP|Plural of BG; instanced PvP matches.
BIND|Bind / Soulbind|Items|Makes an item belong to a character so it cannot normally be traded.
BIO|Bathroom break|Chat|A brief real-life break.
BIS|Best in Slot|Gear|Best item for a slot under a particular build, role and available content; not universally best for every player.
BODY PULL|Body pull|Combat|Start combat by proximity.
BOE|Bind on Equip|Items|Item becomes soulbound when equipped.
BOK|Blessing of Kings|Classes|Paladin stat buff.
BOM|Blessing of Might|Classes|Paladin attack-power buff.
BOOMKIN|Moonkin druid|Classes|Nickname for a Balance druid.
BOOST|Boost|Groups|Help someone level or complete content quickly.
BOP|Bind on Pickup / Blessing of Protection|Items|Loot binding rule, or paladin protection from physical attacks.
BOSS|Boss|PvE|A powerful encounter enemy.
BOT|Bot / Bastion of Twilight|Chat|Usually a character controlled by automation. In Cataclysm raid discussions, BoT can instead mean Bastion of Twilight; capitalization alone is not decisive.
BOW|Blessing of Wisdom|Classes|Paladin mana-regeneration buff.
BRACKET|PvP bracket|PvP|Level range grouped together for battlegrounds.
BRB|Be Right Back|Chat|The player will return shortly.
BRD|Blackrock Depths|Dungeons|A large Classic dungeon in Blackrock Mountain, often split into shorter runs for specific bosses, quests or items.
BREZ|Battle Resurrection|Classes|Resurrection usable during combat.
BRS|Blackrock Spire|Dungeons|Includes Lower and Upper Blackrock Spire.
BRT|Be Right There|Chat|The player is on the way.
BS|Blacksmithing / Backstab / Battle Shout|Professions|Profession, rogue attack, or warrior buff.
BT|Bloodthirst|Classes|Warrior attack shorthand.
BTW|By The Way|Chat|Introduces an additional point.
BUFF|Buff|Game slang|A beneficial effect, or a change that makes something stronger.
BUILD|Build|Characters|A particular talent, gear or ability setup.
BURST|Burst Damage|Combat|A short period of very high damage.
BWL|Blackwing Lair|Raids|A raid.
C|Copper / Cathedral Shorthand|Trading|Usually copper in a price. In a clearly established Scarlet Monastery wing list it can mean Cathedral; use CATH for a less ambiguous dungeon reference.
CAMP|Camp|PvP|Stay nearby to repeatedly attack or await a spawn.
CAP|Capture / Cap|PvP|Capture an objective, or reach a level or stat limit.
CAREBEAR|Carebear|Chat/Slang|Derogatory label for someone who avoids PvP.
CARRY|Carry|Groups|A stronger player helps others complete content.
CATA|Cataclysm|Other WoW versions|Expansion name.
CATH|Cathedral|Dungeons|Often refers to the Scarlet Monastery Cathedral wing.
CC|Crowd Control|Combat|Effects that stop or restrict an enemy, such as stun, fear or polymorph.
CD|Cooldown|Combat|Time before an ability can be used again.
CDS|Cooldowns|Combat|Abilities currently recharging, or important abilities saved for later.
CLASS LEAD|Class leader|Guild|Officer responsible for a class group.
CLEAR|Clear|PvE|Defeat the required enemies or finish an area.
CLEAVE|Cleave|Combat|Damage to additional nearby targets.
COA|Curse of Agony|Classes|Warlock periodic-damage curse.
COC|Cone of Cold|Classes|Mage frontal frost spell.
COD|Cash on Delivery / Curse of Doom|Trading|Mail payment option, or warlock curse.
COE|Curse of the Elements|Classes|Warlock curse.
COEX|Curse of Exhaustion|Classes|Warlock slowing curse.
CRAFT|Craft|Professions|Create an item using a profession.
CRIT|Critical Strike|Stats|Chance to land a critical hit or heal.
CS|Counterspell / Cheap Shot|Classes|Mage interrupt or rogue stun; context matters.
CTF|Capture The Flag|PvP|Flag-based objective format.
DARN|Darnassus|Leveling|City shorthand.
DBM|Deadly Boss Mods|World|Boss-assistance addon name.
DC|Disconnect / Discord|Chat|Usually a lost game connection; can also refer to Discord in community or voice-chat discussions.
DD|Direct Damage / Damage Dealer|Combat|Can mean damage applied immediately rather than over time, or a player filling a damage-dealing role. Combat mechanics and recruitment use different meanings.
DE|Disenchant|Professions|Break an eligible item into enchanting materials.
DEBUFF|Debuff|Game slang|A harmful effect placed on a character.
DEF|Defend / Defense|Stats|Protect an objective, or a defensive statistic in Classic discussions.
DEMO|Demonology / Demoralizing Shout|Classes|Warlock specialization or warrior shout.
DESPAWN|Despawn|World|A creature or object disappears.
DI|Divine Intervention / Dark Intent|Classes|Different class abilities in different versions.
DING|Level Up|Leveling|Slang announcing that a character gained a level.
DISCO|Disconnected|Chat/Slang|Lost connection.
DISPEL|Dispel|Combat|Remove removable spell effects; targets and effect types vary.
DK|Death Knight|Classes|Expansion class; not a claim of Forever availability.
DKP|Dragon Kill Points|Loot|Guild/community points used to distribute raid loot.
DM|Deadmines / Dire Maul / Direct Message|Dungeons|Two different dungeons, or a private message. A wing suffix such as DME usually indicates Dire Maul.
DM TRIB|Dire Maul Tribute|Dungeons|A tribute-focused run through Dire Maul North.
DME|Dire Maul East|Dungeons|Eastern wing.
DMF|Darkmoon Faire|World|Recurring event.
DMN|Dire Maul North|Dungeons|Northern wing.
DMT|Dire Maul Tribute|Dungeons|Tribute run through Dire Maul North.
DMW|Dire Maul West|Dungeons|Western wing.
DOT|Damage over Time|Combat|Damage applied repeatedly over a duration.
DPS|Damage Per Second / Damage Dealer|Roles|Damage output, or a player whose role is dealing damage.
DR|Diminishing Returns|PvP|Repeated crowd control can have reduced duration depending on the mechanic.
DRU|Druid|Classes|Shorthand for Druid.
DRUID|Druid|Classes|Hybrid shapeshifting class.
DUNGEON|Dungeon|PvE|Instanced group PvE content.
DW|Dual Wield|Items|Use a weapon in each hand.
EFR|Enemy Flag Room|PvP|Opponent's flag room.
EI|Enemy Infantry|PvP|Enemy players.
ELE|Elemental|Classes|Shaman specialization shorthand.
ENCH|Enchanting|Professions|Profession for enchanting gear and processing magical materials.
ENG|Engineering|Professions|Profession that creates gadgets, devices and other engineered items.
ENH|Enhancement|Classes|Shaman specialization shorthand.
EP|Eastern Plaguelands|Leveling|Zone shorthand.
EPGP|Effort Points / Gear Points|Loot|Loot priority based on an effort-to-gear ratio.
EPL|Eastern Plaguelands|Places|Zone in the Eastern Kingdoms.
EPYON PULL|Epyon pull|Chat/Slang|Obscure historical name for a reckless charge.
EVADE|Evade|PvE|An enemy becomes temporarily unhittable and resets or ignores attacks.
EVISC|Eviscerate|Classes|Rogue finishing attack.
EVO|Evocation|Classes|Mage mana-recovery spell.
EXALTED|Exalted|Progression|A high reputation rank in systems that use classic reputation tiers.
FACE MELTING|Face melting|Chat/Slang|Very strong damage; associated with shadow priests.
FACE PULL|Face pull|Combat|Accidentally engaging by proximity.
FAP|Free Action Potion|Items|Potion against stuns and movement restrictions.
FARM|Farm|Game slang|Repeatedly do content to obtain items, gold, reputation or experience.
FC|Flag Carrier|PvP|The player currently carrying a battleground flag.
FEAR|Fear|Combat|Makes a target flee uncontrollably.
FF|Faerie Fire|Classes|Druid armor-reduction spell.
FFS|For F---'s Sake|Chat|Expresses frustration; profanity.
FORT|Fortitude|Classes|Priest stamina buff.
FOTM|Flavor of the Month|Game slang|A class/build currently popular because it is perceived as strong.
FP|Flight Path|Travel|Travel route between flight masters.
FPP|Fire Protection Potion|Items|Fire-damage absorption potion.
FR|Fire / Frost Resistance|Stats|Usually fire resistance; confirm which damage school is meant.
FRR|Frost Resistance|Stats|Resistance to frost damage.
FTL|For The Loss|Chat|Expresses disapproval.
FTW|For The Win|Chat|Expresses approval or enthusiasm.
GADGETZAN|Gadgetzan|Leveling|Town in Tanaris.
GADS|Gadgetzan|Places|Town shorthand.
GANK|Gank|PvP|An ambush, often against a disadvantaged opponent.
GB|Guild Bank|Guild|Shared guild storage; implementation depends on version.
GCD|Global Cooldown|Combat|The short shared cooldown triggered by many abilities.
GDKP|Gold Dragon Kill Points|Loot|Loot system where items are auctioned for in-game gold; rules and availability depend on the server/version.
GFPP|Greater Fire Protection Potion|Items|Stronger fire-damage absorption potion.
GG|Good Game|Chat|Commonly said at the end of a match or activity.
GJ|Good Job|Chat|A compliment after a successful play.
GL|Good Luck / Guild Leader|Guild|A friendly wish, or the leader of a guild.
GLASS CANNON|Glass cannon|Combat|High damage with low survivability.
GLOBAL LFG|Global Looking For Group|Groups|Historical name for a worldwide group-finding channel.
GM|Game Master / Guild Master / Grand Marshal|Guild|Support staff, guild leader, or Alliance PvP rank; context matters.
GNOMER|Gnomeregan|Dungeons|Dungeon near Dun Morogh.
GOLD FARMER|Gold farmer|Trading|Someone farming currency, sometimes for real-money sales.
GOTW|Gift of the Wild|Classes|Druid group buff in some versions.
GQUIT|Guild Quit|Guild|Leaving a guild.
GRAND MARSHAL|Grand Marshal|PvP|Alliance rank title.
GRATS|Congratulations|Chat|Congratulating another player.
GRAYS|Poor-quality items|Loot|Gray item quality.
GREED|Greed|Loot|Loot choice indicating interest without main need.
GRIEF|Grief|Chat|Deliberately disrupt another player's experience.
GRIEFER|Griefer|Chat/Slang|Someone deliberately disrupting others.
GRIND|Grind|Game slang|Repeat an activity for progression or rewards.
GRINDING|Grinding|Leveling|Repeated activity for progress.
GS|GearScore / Goldshire / Giantstalker|Gear|Equipment rating, a town, or hunter armor set; context matters.
GTFO|Get The F--- Out|Chat|Forceful instruction to leave; profanity.
GUILD|Guild|Guild|An organized group of players.
GY|Graveyard|Dungeons|Resurrection location, or the Graveyard wing of Scarlet Monastery.
GY RUN|Graveyard run|PvE|Returning to your corpse as a ghost.
GZ|Congratulations|Chat|Short for congratulations or grats.
HATE|Threat|Combat|Enemy hostility towards a player.
HEAL|Healer / Healing|Roles|Usually refers to a healer or a request for healing.
HEALS|Healing / Healer|Roles|Common shorthand for healing or the healer role.
HEMO|Hemorrhage|Classes|Rogue attack shorthand.
HERB|Herbalism / Herb|Professions|Gathering profession or a gathered plant.
HF|Have Fun|Chat|Often paired with GL: GL HF.
HILLSBRAD FOOTHILLS|Hillsbrad Foothills|Leveling|Eastern Kingdoms zone.
HIT|Hit / Hit Chance|Stats|Related to successfully landing attacks; exact mechanics depend on the ruleset.
HOJ|Hammer of Justice / Hand of Justice|Classes|Paladin stun or BRD trinket.
HONOR|Honor|PvP|PvP reward/currency system where supported.
HOP|Hand of Protection|Classes|Paladin ability name in some versions.
HOS|Hand of Salvation|Classes|Paladin ability name in some versions.
HOT|Heal over Time / Hour of Twilight|Combat|Usually periodic healing; in expansion discussions, a dungeon name.
HOTW|Heart of the Wild|Classes|Druid talent.
HPS|Healing Per Second|Roles|A measure of healing output.
HR|Hard Reserve|Loot|An item is reserved and not available for normal group rolls.
HS|Hearthstone / Healthstone / Heroic Strike|Travel|Return-home item, warlock healing item, or warrior attack. Check the speaker and context.
HT|Healing Touch|Classes|Druid healing spell.
HUNT|Hunter|Classes|Shorthand for Hunter.
HUNTER|Hunter|Classes|Ranged class with pets.
HW|High Warlord|PvP|Horde rank title.
HWL|High Warlord|PvP|Horde rank title.
IDC|I Don't Care|Chat|Expresses indifference; can sound dismissive.
IDK|I Don't Know|Chat|The player does not know.
IF|Ironforge|Places|Major Alliance city.
IGGY|Ignore|Chat/Slang|Informal reference to ignoring someone.
IIRC|If I Recall Correctly|Chat|Introduces something remembered with uncertainty.
ILVL|Item Level|Gear|A numerical measure of an item's power where supported.
IMHO|In My Humble / Honest Opinion|Chat|Introduces a personal opinion.
IMO|In My Opinion|Chat|Introduces a personal opinion.
INC|Incoming|PvP|Enemies are approaching a location.
INCOMING|Incoming|Combat|Warning of approaching enemies or an imminent action.
INT|Intellect / Interrupt|Stats|A stat, mage intellect buff, or request to interrupt; context matters.
INTERRUPT|Interrupt|Combat|Stop an active spell cast.
INV|Invite / Inventory|Groups|Usually a group invitation; can also mean inventory.
INVITE|Invite|Groups|Add a player to a party or raid.
IRL|In Real Life|Chat|Outside the game.
IRONLAG|Ironforge|Chat/Slang|Historical nickname about city lag.
KDR|Kill/death ratio|PvP|Kills compared with deaths.
KEK|Laughter|Chat|Historical cross-faction rendering associated with LOL.
KITE|Kiting|Combat|Keep distance from an enemy while continuing to move or attack.
KITING|Kiting|Combat|Keeping an enemy at a distance.
KOS|Kill on Sight|PvP|Attack this player whenever encountered.
KS|Kill Stealing / Kingslayer|Chat/Slang|Taking credit for another player's kill, or the Kingslayer title associated with defeating the Lich King in Wrath-era content; context matters.
LAGFORGE|Ironforge|Chat/Slang|Historical nickname about city lag.
LAGRIMMAR|Orgrimmar|Chat/Slang|Historical nickname about city lag.
LAP|Living Action Potion|Items|Potion used against disabling movement/control effects.
LB|Lightning Bolt / Lawbringer|Classes|Shaman spell or paladin armor set.
LBRS|Lower Blackrock Spire|Dungeons|A dungeon.
LC|Loot Council|Loot|A designated group decides loot recipients.
LEAD|Leader|Groups|The party or raid leader.
LEEROY|Leeroy|Chat/Slang|Charging in before the group is ready.
LF|Looking For|Groups|General shorthand used before what someone wants.
LF1M|Looking For One More|Groups|A group needs one additional player.
LF2M|Looking For Two More|Groups|A group needs two additional players.
LFG|Looking For Group|Groups|The player wants to join a group.
LFM|Looking For More|Groups|A group is recruiting more players.
LFM HEAL|Looking For More: Healer|Groups|The group needs a healer.
LFM TANK|Looking For More: Tank|Groups|The group needs a tank.
LFW|Looking For Work|Trading|Advertising crafting services.
LIB|Library|Dungeons|Often refers to the Scarlet Monastery Library wing.
LIP|Limited Invulnerability Potion|Items|Temporary physical-damage protection potion.
LOCK|Warlock|Classes|Common shorthand for Warlock.
LOCKOUT|Lockout|Raids|Restrictions on repeating or looting instance content.
LOH|Lay on Hands|Classes|Paladin emergency heal.
LOM|Low on Mana|Combat|The player is running low on mana.
LOOT COUNCIL|Loot council|Loot|Leaders choose who receives items.
LOS|Line of Sight|Combat|Using terrain or obstacles to block attacks or spells.
LOTP|Leader of the Pack|Classes|Druid talent.
LVL|Level|Leveling|A character's level.
LW|Leatherworking|Professions|Profession focused on leather and related crafted gear.
MAGE|Mage|Classes|Spellcasting class.
MAIN|Main Character|Characters|The character a player primarily plays.
MAIN ASSIST|Main assist|Roles|Player choosing the group's attack target.
MARA|Maraudon|Dungeons|A dungeon.
MARK|Mark|Combat|Hunter's Mark, a druid buff, or a target icon.
MATS|Materials|Professions|Crafting ingredients or trade goods.
MB|Mana Break / Mind Blast|Groups|Pause to restore mana, or priest damage spell.
MC|Molten Core / Mind Control|Raids|Classic raid, or priest control spell.
MCP|Manual Crowd Pummeler|Items|Gnomeregan weapon with a temporary attack-speed effect.
MDPS|Melee DPS|Roles|Damage dealer fighting at close range.
META|Meta|Game slang|Popular or currently effective strategies, builds or choices.
MH|Main Hand|Items|The primary weapon hand.
MINING|Mining|Professions|Gathering profession for ore and stone.
ML|Master Looter|Loot|Player designated to distribute loot.
MOB|Mobile / Enemy Creature|PvE|Common term for a game-controlled enemy creature.
MOBS|Enemy Creatures|PvE|Plural of mob.
MOO|Moo|Chat/Slang|Cow sound, often a tauren joke.
MOP|Mists of Pandaria|Other WoW versions|Expansion name.
MOTD|Message of the Day|Groups|Guild announcement or login notice.
MOTW|Mark of the Wild|Classes|Druid buff.
MOUNT|Mount|Travel|Rideable creature or vehicle used for faster travel.
MP5|Mana Per Five Seconds|Stats|Mana regeneration statistic.
MS|Main Spec / Mortal Strike|Loot|Primary role in loot discussions, or warrior attack that reduces healing.
MS > OS|Main Spec Before Off Spec|Loot|Main-role gear needs take priority.
MS/OS|Main Spec / Off Spec|Loot|Usually main-role loot priority over secondary-role needs.
MS>OS|Main Spec Before Off Spec|Loot|Main-role gear needs have priority over secondary-role needs.
MSOS|Main Spec over Off Spec|Loot|Loot rule giving main-spec needs priority over off-spec.
MT|Main Tank / Mistell / Mistype / Dungeon shorthand|Roles|Main tank in groups; mistell for a message sent to the wrong chat, or mistype for a typing error. In expansion discussions: Mana-Tombs or Magisters Terrace.
MULGROLL|Mulgroll|Chat/Slang|Obscure historical joke about low loot rolls.
NAXX|Naxxramas|Raids|A raid.
NE|Night Elf|Characters|Race shorthand.
NEED|Need|Loot|Loot choice indicating the item is needed for use.
NELF|Night Elf|Characters|Informal race name.
NERF|Nerf|Game slang|A change that makes something weaker.
NINJA|Ninja Looting|Loot|Taking loot against the group's agreed rules.
NINJA PULL|Ninja pull|PvE|Starting a fight without group agreement.
NODE|Gathering Node|Professions|A resource point such as an herb or ore vein.
NP|No Problem|Chat|A casual response meaning no problem.
NPC|Non-Player Character|World|A character controlled by the game.
NR|Nature Resistance|Stats|Resistance to nature damage.
NS|Nature's Swiftness|Classes|Druid/shaman instant-cast talent shorthand; also Northshire or Nightslayer.
NVM|Never Mind|Chat|Ignore the previous statement or request.
OBO|Or Best Offer|Trading|Seller will consider other offers.
OFC|Of Course|Chat|Means certainly or obviously.
OFFICER|Officer|Guild|Guild member with management responsibilities.
OH|Off Hand|Items|The secondary hand or off-hand item.
OMW|On My Way|Chat|The player is travelling to you.
ONY|Onyxia|Raids|Usually refers to Onyxia or Onyxia's Lair.
OOM|Out of Mana|Combat|The player has no mana left.
OP|Overpowered|Game slang|Something considered excessively strong.
OPENER|Opener|Combat|Actions used at the start of combat.
ORE|Ore|Professions|Mining material used by crafting professions.
ORG|Orgrimmar|Places|Major Horde city.
OS|Off Spec|Loot|Secondary role/spec used for loot priority.
OT|Off Tank|Roles|Secondary tank handling additional enemies or mechanics.
OVERHEALING|Overhealing|Combat|Healing beyond missing health.
PACK|Enemy pack|PvE|Enemies usually engaged together.
PAL|Paladin|Classes|Shorthand for Paladin.
PALA|Paladin|Classes|Shorthand for Paladin.
PALLY|Paladin|Classes|Informal class name.
PARSE|Parse|Raids|Logged performance ranking or analysis.
PARSING|Parsing|Raids|Comparing combat performance through logs.
PASS|Pass|Loot|Decline a loot roll.
PAT|Patrol|PvE|A moving group/enemy that may enter your fight.
PATROL|Patrol|PvE|Moving enemies that can unexpectedly enter a fight.
PATTERN|Pattern|Professions|A profession recipe, often for tailoring or leatherworking.
PC|Player Character|World|A character controlled by a player.
PEEL|Peel|PvP|Use control or pressure to get an enemy off a teammate.
PI|Power Infusion|Classes|Priest empowering buff.
PM|Private Message|Chat|A private message.
POH|Prayer of Healing|Classes|Priest group-healing spell.
POLY|Polymorph|Classes|Mage transformation crowd control.
PORT|Portal|Travel|A magical portal to another location.
POT|Potion|Items|A potion, or using one.
PRE-BIS|Pre-Raid Best in Slot|Gear|Best slot item before raiding, for a chosen build.
PRE-RAID BIS|Pre-Raid Best in Slot|Gear|Best slot item before raid content, for a build.
PRIE|Priest|Classes|Shorthand for Priest.
PRIEST|Priest|Classes|Healing and spellcasting class.
PRIO|Priority|Loot|Preference in loot allocation.
PROC|Proc|Mechanics|An effect that activates when its trigger conditions occur.
PROF|Profession|Professions|A crafting or gathering skill.
PROG|Progression|Raids|Working towards a first successful boss kill.
PST|Please Send Tell|Chat|Whisper or privately message the player.
PTR|Public Test Realm|World|Server for testing upcoming changes.
PUG|Pick-Up Group|Groups|A group formed with players who do not normally play together.
PULL|Pull|PvE|Start a fight by engaging enemies.
PURGE|Purge|Combat|Usually remove an enemy's beneficial magic effect.
PVE|Player versus Environment|PvE|Content against game-controlled enemies.
PVP|Player versus Player|PvP|Combat against other players.
PW:S|Power Word: Shield|Classes|Priest damage-absorption spell.
PWNED|Owned|Chat|Slang for being decisively beaten.
PYRO|Pyroblast|Classes|Mage fire spell.
Q|Quest|Leveling|Sometimes used as shorthand for quest; context matters.
QUEST|Quest|Leveling|A task given by the game for objectives and rewards.
R|Ready|Groups|Sometimes used in ready checks or chat to indicate readiness.
RAID|Raid|PvE|Large-group PvE content, usually containing bosses.
RAQ|Ruins of Ahn'Qiraj|Raids|Alternative to AQ20.
RDY|Ready|Groups|The player is ready.
RECIPE|Recipe|Professions|Instructions learned to craft an item.
REGEN|Regeneration|Stats|Recovery of a resource over time.
RELOG|Relog|Chat|Log out and back into the game.
REP|Reputation|Progression|Standing with a faction or organization.
REROLL|Reroll|Characters|Start a different character or switch main.
RES|Reserved / Resistance / Resurrection|Loot|Reserved loot in recruitment messages; otherwise resistance or resurrection.
RESET|Reset|PvE|Return an encounter or enemies to their initial state.
RESPAWN|Respawn|World|An enemy, object or player returning after death/despawn.
RESPEC|Respecialize|Characters|Change talents, specialization or build choices.
RESTO|Restoration|Classes|Healing specialization shorthand.
REZ|Resurrection|Groups|Bring a dead player back to life.
RFC|Ragefire Chasm|Dungeons|A dungeon.
RFD|Razorfen Downs|Dungeons|Classic dungeon in the Barrens.
RFK|Razorfen Kraul|Dungeons|A dungeon.
RL|Raid Leader / Real Life|Groups|Person leading a raid, or life outside the game.
RMT|Real-Money Trading|Trading|Buying or selling game assets for real money.
RNG|Random Number Generator|Mechanics|Player shorthand for random outcomes such as drops or procs.
ROG|Rogue|Classes|Common shorthand for Rogue.
ROGUE|Rogue|Classes|Stealth-focused melee class.
ROLL|Roll|Loot|Use a random roll to decide who receives an item.
ROOT|Root|Combat|Prevents movement.
ROSTER|Roster|Guild|List of members in a guild or group.
RR|Round Robin / Redridge Mountains|Loot|A rotating loot allocation method, or the Redridge Mountains zone. Loot discussion and travel context distinguish them.
SALV|Blessing of Salvation|Classes|Paladin threat-reduction buff.
SAPPER|Goblin Sapper Charge|Items|Engineering explosive causing area damage.
SB|Shadow Bolt / Shield Bash / Shield Block|Classes|Warlock spell or warrior ability.
SCHOLO|Scholomance|Dungeons|Classic dungeon in Western Plaguelands.
SFK|Shadowfang Keep|Dungeons|Classic dungeon in Silverpine Forest.
SGC|Savage Gladiator Chain|Items|Chest armor sought in Blackrock Depths.
SHAM|Shaman|Classes|Shorthand for Shaman.
SHAMAN|Shaman|Classes|Hybrid spellcasting class.
SHEEP|Polymorph|Classes|Mage crowd-control shorthand.
SK|Suicide Kings|Loot|Taking loot moves you down a priority list.
SKIN|Skinning|Professions|Gathering profession for hides and leather.
SL|Soul Link / Siphon Life / Shadowlands|Classes|Warlock ability or expansion; check context.
SLS|Shroud Loot System|Loot|Guild points-and-bidding loot rules.
SM|Scarlet Monastery / Shadow Mastery|Dungeons|Dungeon complex, or warlock talent.
SND|Slice and Dice|Classes|Rogue attack-speed buff.
SOS|Swamp of Sorrows|Places|Zone name.
SOULBOUND|Soulbound|Items|An item permanently bound to a character.
SP|Spell Power|Stats|A stat associated with spell effectiveness in rulesets that use it.
SPAWN|Spawn|World|Where or when a creature/object appears.
SPEC|Specialization|Characters|A character's chosen combat specialization or build focus.
SPI|Spirit|Stats|A statistic present in some WoW rulesets and itemization.
SR|Soft Reserve|Loot|Loot system where players reserve an item before a run.
SS|Soulstone / Sinister Strike / Southshore|Classes|Warlock resurrection effect, rogue attack, or Hillsbrad town.
ST|Sunken Temple / Single Target|Dungeons|Context determines whether this means Sunken Temple or Single Target.
STA|Stamina|Stats|A character statistic associated with health.
STFU|Shut The F--- Up|Chat|Insulting instruction to stop talking.
STOCKS|The Stockade|Dungeons|Dungeon in Stormwind.
STR|Strength|Stats|A primary character statistic.
STRAT|Stratholme|Dungeons|Classic dungeon in Eastern Plaguelands, commonly divided into living and undead runs.
STRAT LIVE|Stratholme Living Side|Dungeons|The Scarlet section of Stratholme.
STRAT UD|Stratholme Undead Side|Dungeons|The undead section of Stratholme.
STUN|Stun|Combat|Temporarily prevents movement and actions.
STV|Stranglethorn Vale|Places|A zone in the Eastern Kingdoms.
SUMM|Summon|Groups|A request for or reference to summoning a player.
SUMMON|Summon|Groups|Bring a player to a location using an available summon mechanic.
SW|Stormwind|Places|Major Alliance city.
SW:P|Shadow Word: Pain|Classes|Priest periodic-damage spell.
TAG|Tag|Combat|Claim initial credit/engagement on a creature under the relevant game rules.
TAILOR|Tailoring|Professions|Profession that creates cloth items and related goods.
TANK|Tank|Roles|Role that holds enemy attention and survives incoming damage.
TAP|Life Tap / Claim an Enemy|Combat|The warlock Life Tap ability, or damaging an enemy to claim credit or loot eligibility. Enemy tagging and sharing rules depend on version.
TAQ|Temple of Ahn'Qiraj|Raids|Alternative to AQ40.
TAUNT|Taunt|Combat|An ability intended to make an enemy attack the tank.
TB|Thunder Bluff|Places|Major Horde city.
TBC|The Burning Crusade|Other WoW versions|Expansion name.
TBH|To Be Honest|Chat|Introduces a frank opinion.
THREAT|Threat|Combat|The mechanic that influences which player an enemy attacks.
THX|Thanks|Chat|Short for thanks.
TM|Tarren Mill|Places|Horde settlement in Hillsbrad.
TOON|Character|Characters|Slang for a player character.
TP|Teleport|Travel|Teleportation; meaning can vary by community.
TPS|Threat Per Second|Combat|Rate of threat generation.
TRASH|Trash Mobs|PvE|Regular enemies between bosses.
TRIAL|Trial member|Guild|Recruit being evaluated.
TRINKET|Trinket|Items|Equipment slot often providing stats or an effect.
TWINK|Twink|Game slang|A character heavily optimized for a particular level bracket.
TY|Thank You|Chat|Short for thank you.
UBER|Excellent|Chat|Describes something very strong or impressive.
UBRS|Upper Blackrock Spire|Dungeons|A dungeon/raid-sized classic instance depending on version.
UC|Undercity|Places|Major Horde city in relevant versions.
ULD|Uldaman|Dungeons|A dungeon.
ULDA|Uldaman|Dungeons|Alternative to ULD.
VC|Voice Chat / The Deadmines|Groups|Voice communication, or a community abbreviation for The Deadmines. Check whether the conversation is about speaking or a dungeon.
VENDOR|Vendor|Trading|NPC that buys and sells goods.
VT|Vendor Trash|Loot|Items mainly worth selling to NPCs.
WAND|Wand|Items|Ranged caster weapon.
WAR|Warrior / Warlock|Classes|Ambiguous; community usage depends on context.
WARR|Warrior|Classes|Common shorthand for Warrior.
WB|Welcome Back / World Boss|Chat|Meaning depends on context.
WC|Wailing Caverns / Wrong Channel|Dungeons|Dungeon name, or correction after sending a message to the wrong channel.
WF|Windfury / World First / Westfall|Classes|A shaman effect, a first worldwide achievement, or the Westfall zone. Check whether the conversation concerns spells, progression or travel.
WIPE|Wipe|PvE|The entire group, or nearly the entire group, dies and the attempt fails.
WOD|Warlords of Draenor|Other WoW versions|Expansion name.
WOTLK|Wrath of the Lich King|Other WoW versions|Expansion name.
WPL|Western Plaguelands|Places|Zone in the Eastern Kingdoms.
WSG|Warsong Gulch|PvP|Capture-the-flag battleground.
WTB|Want to Buy|Trading|The player wants to purchase an item or service.
WTF|What The F---|Chat|Expresses surprise or frustration; profanity.
WTH|What The Hell|Chat|Expresses surprise or frustration; mild profanity.
WTS|Want to Sell|Trading|The player is offering an item or service for sale.
WTT|Want to Trade|Trading|The player wants to exchange items or services.
WW|Whirlwind|Classes|Warrior area attack.
XMUTE|Transmute|Professions|Alchemy material conversion.
XP|Experience Points|Leveling|Progress toward gaining a level.
XR|Crossroads|Places|Settlement in the Barrens.
Zerg|Zerg|Game slang|Overwhelm an objective or enemy with numbers.
ZF|Zul'Farrak|Dungeons|A dungeon.
ZG|Zul'Gurub|Raids|A raid.
ZUG|Zug Zug|Game slang|WoW community slang associated with aggressive melee play; originally an Orc expression.
GTG|Good To Go / Got To Go|Chat|Ready to start, or needing to leave; context matters.
FFA|Free For All|Loot|Eligible group members may loot freely.
HIT CAP|Hit cap|Stats|Threshold where more hit no longer reduces misses for a particular attack and target; depends on ruleset.
DEF CAP|Defense cap|Stats|Usually the defense threshold for avoiding enemy critical hits in older rulesets; not a universal maximum.
CRIT CAP|Critical strike cap|Stats|Limit on effective critical-strike chance in a particular attack calculation; depends on ruleset.
SHARD|Enchanting Shard / Disenchant / Soul Shard|Items|An enchanting material or a request to disenchant an item; in warlock discussion it can mean a Soul Shard used by certain spells. Mechanics vary by version.
EFFECTIVE HEALING|Effective healing|Combat|Healing that actually restores missing health.
ROTATION|Rotation|Combat|The usual sequence or priority of abilities during combat.
LOL|Laughing Out Loud|Chat|Expresses laughter or amusement.
LMAO|Laughing My Ass Off|Chat|Expresses strong amusement; contains mild profanity.
JK|Just Kidding|Chat|The previous statement was a joke.
OMG|Oh My God|Chat|Expresses surprise, excitement or frustration.
IDM|I Don't Mind|Chat|The player is happy with either option or has no objection.
NW|No Worries|Chat|Reassurance that something is not a problem.
TYVM|Thank You Very Much|Chat|An enthusiastic thank-you.
OTW|On The Way|Chat|The player is travelling to the destination; similar to OMW.
G2G|Got To Go / Good To Go|Chat|May mean leaving or ready to start. Ask if the context is unclear.
KICK|Interrupt / Remove From Group|Combat|Often a request to interrupt a spell, named after the rogue ability. In group management, remove a player.
BUBBLE|Paladin Protection Spell|Classes|Nickname for Divine Shield or a protection spell used on another player. The exact spell and protection depend on context and game version.
SAP|Sap|Classes|Rogue crowd-control ability used to disable a target before combat; restrictions depend on the game version.
COMP|Composition|Groups|The mix of classes, roles or specializations in a party, raid or arena team.
NUKE|Focus Heavy Damage|Combat|Deal heavy damage quickly, often to a specified priority target.
SOAK|Soak Damage / Mechanic|Combat|Intentionally stand in or take a mechanic to absorb it or share its damage, as required by the encounter.
LF3M|Looking For Three More|Groups|A group needs three additional players.
PROT|Protection|Classes|Shorthand for a warrior or paladin protection build or specialization.
KITTY|Cat-Form Druid|Classes|Nickname for a druid playing melee damage in cat form, usually a feral build.
MOONKIN|Moonkin / Balance Druid|Classes|Druid form associated with Balance spellcasting; also a nickname for a Balance druid where supported.
BOOMY|Balance Druid|Classes|Nickname for a Balance druid, similar to boomkin.
BEAR|Bear-Form Druid|Classes|Usually a druid tank in bear form. Build or specialization names vary by game version.
COOKIES|Healthstones / Conjured Food|Items|Usually warlock Healthstones; sometimes mage conjured food. Check who is being asked and the context.
BLUEBERRY|Voidwalker|Classes|Nickname for the blue warlock Voidwalker demon pet.
123|Summon Request|Groups|Often typed in chat to request a summon after the group asks who needs one. Not a spell or automatic summon command.
X|Sign Me Up / Invite Me|Groups|Sometimes a response to 'X for invites'. Meaning depends on the group's instructions. Search-only: not automatically detected in chat.
1|Invite / Summon Request|Groups|Sometimes a response to 'type 1 for an invite' or '1 for summons'. Follow the group's instructions. Search-only: not automatically detected in chat.
HP|Health / Hit Points|Stats|How much damage a character can take before dying; often used when discussing remaining health.
DMG|Damage|Combat|Short form of damage, usually referring to an attack's damage or total damage dealt.
CASTER|Spellcasting Character|Roles|A character that relies on spells for damage, healing or control; the surrounding discussion determines the role.
MEZ|Mesmerize / Temporary Incapacitation|Combat|Older MMO shorthand for crowd control that temporarily disables a target, such as Polymorph. Exact effects vary by game and spell.
STACK|Item Stack / Stacking Effects|Items|Several identical items grouped in one inventory slot. In combat it can instead mean accumulating effects or players standing together.
LOOT|Items or Rewards / Collect Loot|Loot|Rewards obtained from enemies, containers or activities; also the act of collecting those rewards.
PET|Player-Controlled Companion|Classes|A companion controlled by a player, such as a hunter beast or warlock demon. A cosmetic companion is a different kind of pet.
NEWBIE|New or Inexperienced Player|Chat|Someone still learning the game. Being new does not imply unwillingness to learn or a particular skill level.
VENDOR TRASH|Items Mainly Sold to NPCs|Loot|Loot usually kept for its sale value at an NPC merchant, often poor-quality gray items. Alias of VT.
NBG|Need Before Greed|Loot|A loot rule giving players who need an item for use priority over players who mainly want its sale or other value. Confirm the group's rules.
HARD RES|Hard Reserve|Loot|An item set aside for a specified player or purpose before the run, normally unavailable for other players to roll on. Alias of HR.
SOFT RES|Soft Reserve|Loot|Players declare an item preference before a run. If it drops, eligible players who reserved it usually get priority; limits and tie rules vary. Alias of SR.
+1 RESET|Reset Loot Priority Counters|Loot|In a plus-one loot system, item wins affect priority for later rolls. A reset clears those counters at an agreed point; ask when and how the group resets them.
LOOT TRADING|Trading Eligible Loot After Pickup|Loot|Passing an eligible looted item to another player after pickup. Soulbound-item eligibility, trade windows and restrictions depend on the game version and content.
SELLABLES RESERVED|Sellable Drops Reserved|Loot|A run condition assigning sellable drops to the organizer or designated players, sometimes in return for carrying the group. Ask which items, materials and currency are included.
ORB RUN|Stratholme Righteous Orb Run|Dungeons|A run of Stratholme's living side focused on obtaining Righteous Orbs. Orb distribution and other reserved loot depend on the group's agreement.
JUMP RUNS|Dire Maul East Jump Runs|Dungeons|Usually repeated Dire Maul East farming routes that start with a jump to bypass part of the entrance route. The term can describe other routes in another context.
DME JUMPS|Dire Maul East Jump Runs|Dungeons|Recruitment shorthand for Dire Maul East farming runs using a jump route. Check the intended route and how drops will be shared.
DMJR|Dire Maul Jump Run|Dungeons|An abbreviation usually referring to a Dire Maul East jump run, rather than a full dungeon clear.
REND|Rend Blackhand / UBRS Rend Run|Dungeons|In UBRS recruitment, a run intended to reach Warchief Rend Blackhand, often stopping after that encounter. In warrior spell discussion, Rend is a bleed ability.
JED|Jed Runeshaper / UBRS Rare Check|Dungeons|A rare enemy in Upper Blackrock Spire associated with the Briarwood Reed trinket. A Jed run checks for or targets him; he is not present in every instance.
JED/REND|UBRS Jed and Rend Run|Dungeons|An Upper Blackrock Spire run focused on Jed Runeshaper, if present, and Warchief Rend Blackhand. It usually does not promise a full clear.
DMNT|Dire Maul North Tribute|Dungeons|Another abbreviation for a Dire Maul North tribute run; the same basic destination as DMT.
TRIBUTE|Dire Maul Tribute Run|Dungeons|In Dire Maul groups, a North-wing run that keeps certain bosses alive before defeating the final boss to obtain tribute rewards. Confirm the route with the group.
OG|Orgrimmar|Places|An alternative abbreviation for Orgrimmar, the Horde city. Also written ORG; other chat contexts may use OG differently.
CR|Crossroads / Corpse Retrieval|World|Can mean the Crossroads settlement in the Barrens, or returning to retrieve your corpse after death. Travel or death context distinguishes them.
C.O.D|Cash on Delivery|Trading|Mail sent with a payment requirement that the recipient must pay to collect the attached item. A dotted spelling of COD.
EXP|Experience Points|Leveling|Another abbreviation for experience earned toward leveling, also written XP. Context can instead use exp as shorthand for experience or experienced.
DE-BUFF|Debuff|Combat|A harmful effect on a character or enemy. A hyphenated spelling of DEBUFF; which effects can be removed depends on the spell and effect type.
SM/RUIN|Shadow Mastery / Ruin|Classes|Classic warlock build shorthand combining the Shadow Mastery and Ruin talents. This names a talent combination, not a guarantee that it is available or optimal in every version.
DS/RUIN|Demonic Sacrifice / Ruin|Classes|Classic warlock build shorthand combining Demonic Sacrifice and Ruin. The build's mechanics depend on the talent version and chosen demon.
MD/RUIN|Master Demonologist / Ruin|Classes|Classic warlock build shorthand combining Master Demonologist and Ruin. Demon-related benefits depend on the pet and talent version.
NF/SL|Nightfall / Soul Link|Classes|Classic warlock PvP build shorthand combining Nightfall and Soul Link. Here SL means Soul Link, not Siphon Life.
NF/CONFLAG|Nightfall / Conflagrate|Classes|Classic warlock build shorthand combining Nightfall and Conflagrate, commonly discussed for PvP. Talent availability and behavior depend on version.
SL/SB|Soul Link / Shadowburn|Classes|Classic warlock PvP build shorthand combining Soul Link and Shadowburn. In this build name, SB means Shadowburn rather than Shadow Bolt.
MARA BLUE|Maraudon Blue / Purple Entrance Route|Dungeons|Recruitment shorthand for a Maraudon route through the blue/purple entrance area. Ask which bosses or quests the group plans to complete.
MARA PURPLE|Maraudon Purple Entrance Route|Dungeons|A Maraudon group using the purple entrance route, also described as blue/purple. The route name alone does not specify a full clear.
MARA ORANGE|Maraudon Orange Entrance Route|Dungeons|A Maraudon group using the orange entrance route. Confirm the target bosses and quests before joining.
MARA PRINCESS|Maraudon Princess Run|Dungeons|A Maraudon run focused on Princess Theradras, often using a shortcut to the inner section. Check whether other nearby bosses are included.
WOW|World of Warcraft|World|Short name for the game.
CAMPER|Camper|PvP|A player staying near one spot, often waiting for a spawn or repeatedly attacking opponents there.
GANKING|Ganking|PvP|Ambushing another player, often when they are at a disadvantage.
25M|Twenty-five-player raid|Raids|Raid-size shorthand for twenty-five players; used in versions with that raid size.
HM|Hard Mode|Raids|A harder encounter setting or optional challenge; its activation and rewards depend on the encounter and game version.
FARMED|Farmed|Game slang|Repeatedly gathered, cleared or defeated to obtain rewards; in PvP it can mean being repeatedly killed.
JC|Jewelcrafting / Jewelcrafter|Professions|The gem-crafting profession or a player with it. Introduced in The Burning Crusade; availability depends on the game version.
ICC|Icecrown Citadel|Raids|A raid in Icecrown introduced in Wrath of the Lich King; expansion-specific shorthand.
KARA|Karazhan|Dungeons|Usually the Karazhan raid from The Burning Crusade. Later versions also have Return to Karazhan dungeon content; check the intended activity.
DAL|Dalaran|Travel|City abbreviation. Its location and role vary between expansions, notably Wrath of the Lich King and Legion.
RMP|Rogue / Mage / Priest|PvP|A three-player arena composition using these classes; relevance depends on the PvP ruleset.
20M|Twenty-player raid|Raids|Raid-size shorthand for twenty players; the intended raid depends on the game version.
MULE|Storage Character|Characters|An alternate character mainly used to hold items or manage storage; often also called a bank alt.
RDPS|Ranged DPS|Roles|Damage dealers attacking from a distance, or their damage output; context distinguishes the role from the measurement.
BFA|Battle for Azeroth|Other WoW versions|Expansion abbreviation.
NAX|Naxxramas|Raids|An alternative spelling of Naxx. The raid exists in different forms across Classic and Wrath-era content.
SHAT|Shattrath City|Travel|Short name for the Outland city associated with The Burning Crusade.
ARPEN|Armor Penetration|Stats|A shorthand stat name for bypassing some armor in rulesets that use it; its mechanics vary by version.
IDD|Indeed|Chat|Informal shorthand expressing agreement or confirmation.
NB|Nightborne|Characters|Race abbreviation in later-expansion discussions; not a standard original Classic playable race.
VELF|Void Elf|Characters|Later-expansion race nickname; not a standard original Classic playable race.
WAGGRO|Wife Aggro|Chat|A joking way to say a spouse wants the player's attention, often explaining a break or departure.
BELF|Blood Elf|Characters|Race nickname associated with The Burning Crusade and later versions; not a standard original Classic playable race.
SHATT|Shattrath City|Travel|Another short spelling for Shattrath, the Outland city associated with The Burning Crusade.
DISC|Discipline|Classes|Priest talent-tree or specialization shorthand; the build and role depend on the game version.
RTK|Return to Karazhan|Dungeons|A Legion dungeon set in Karazhan; distinguish it from the earlier Karazhan raid.
MUT|Mutilate|Classes|Rogue ability or build shorthand associated with The Burning Crusade and later rulesets; availability depends on version.
10M|Ten-player raid|Raids|Raid-size shorthand for ten players; used in versions with that raid size.
HP5|Health Per Five Seconds|Stats|A health-regeneration stat expressing health restored over five seconds; availability and mechanics depend on version.
BOT MAFIA|Organized Bot Groups|Trading|Community slang for suspected coordinated automated characters controlling farming spots or resources. The label alone does not prove botting.
WG|Wintergrasp|PvP|A Wrath of the Lich King outdoor PvP zone and battle; expansion-specific shorthand.
BC|The Burning Crusade|Other WoW versions|An alternative to TBC for the expansion name.
]==]
for line in RAW:gmatch("[^\r\n]+") do
    local key, title, category, desc = line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
    if key then
        key = key:upper()
        entries[key] = { key = key, title = title, category = category, desc = desc }
    end
end

local EXAMPLES = [==[
BG|Anyone up for a BG?|Anyone want to play a battleground?
BGS|Doing BGS tonight.|Playing battlegrounds tonight.
LFG|LFG BRD, DPS.|A damage dealer is looking for a Blackrock Depths group.
LFM|LFM BRD, need tank.|A Blackrock Depths group needs more players, including a tank.
LF1M|LF1M healer.|The group needs one more player, specifically a healer.
LF2M|LF2M DPS.|The group needs two more damage dealers.
PST|WTS potions, PST.|Selling potions; whisper me if interested.
WTB|WTB herbs.|I want to buy herbs.
WTS|WTS potions.|I want to sell potions.
WTT|WTT herbs for ore.|I want to trade herbs for ore.
DPS|Need 2 DPS.|The group needs two damage dealers.
HPS|My HPS went up.|My healing per second increased.
OOM|OOM, wait before pulling.|I have no mana; wait before starting the next fight.
LOM|LOM, need a drink soon.|I am low on mana and will need to restore it.
MB|MB before the boss.|Please pause so we can restore mana before the boss.
PUG|Joining a PUG.|Joining a group assembled from players who do not usually play together.
AFK|AFK 2 min.|Away from the keyboard for two minutes.
BRB|BRB, getting water.|I will be right back after getting water.
BIS|Is this my BIS weapon?|Is this the best weapon for my particular setup?
AOE|Use AOE on these mobs.|Use abilities that hit several enemies.
DOT|Keep your DOT up.|Keep the periodic damage effect active.
HOT|Put a HOT on the tank.|Apply a healing effect that restores health over time.
CC|CC the marked mob.|Disable or control the enemy with the target marker.
CD|That spell is on CD.|That spell is recharging.
CDS|Save CDS for the boss.|Save your important cooldown abilities for the boss.
LOS|The healer needs LOS.|The healer needs an unobstructed line to the target.
INC|INC farm, 3 enemies.|Three enemies are approaching the farm objective.
FC|Protect our FC.|Protect our flag carrier.
GY|Meet at the GY.|Meet at the graveyard.
MT|Follow the MT.|Follow the main tank; in this group context, MT means main tank.
OT|OT, pick up the adds.|The off tank should hold the additional enemies.
AGGRO|I have aggro!|The enemy is attacking me.
ADDS|Adds behind us!|Additional enemies are joining the fight behind us.
PULL|Wait before the next pull.|Wait before engaging the next enemies.
WIPE|That was a wipe.|The group died and the attempt failed.
TANK|Need a tank for BRD.|We need someone to hold enemy attention in Blackrock Depths.
HEALS|Need heals!|I need healing; in other contexts, heals may mean a healer.
MATS|Bring your own mats.|Bring the crafting materials yourself.
AH|Check the AH price.|Check the price on the auction house.
DE|Can you DE this item?|Can you disenchant this item?
ALCH|Looking for an alch.|Looking for an alchemist.
MOTW|Can I get MOTW?|Please cast Mark of the Wild on me.
MOTD|Read the guild MOTD.|Read the guild's message of the day.
GL|GL with the run!|Good luck with the dungeon run.
GM|Ask our GM about raid time.|Ask our guild master; GM can mean something else in another context.
INV|INV me, please.|Please invite me to the group.
INT|Need INT buff.|Please give me the intellect buff; this context does not mean interrupt.
HS|Warlock, can I get an HS?|Please give me a healthstone; HS can also mean hearthstone.
BRD|Anyone running BRD?|Is anyone doing Blackrock Depths?
LBRS|LFG LBRS.|Looking for a group for Lower Blackrock Spire.
WSG|Queueing WSG.|Joining the queue for Warsong Gulch.
AV|Anyone doing AV?|Is anyone playing Alterac Valley?
AB|Defend stables in AB.|Defend the stables objective in Arathi Basin.
AP|This item gives more AP.|This item increases attack power.
MAIN|My main is a warrior.|The character I play most is a warrior.
ALT|Leveling my alt.|Leveling one of my other characters.
KITE|Kite the enemy away.|Keep the enemy at a distance while moving.
FACE PULL|Sorry, that was a face pull.|I accidentally started combat by getting too close.
GLASS CANNON|My build is a glass cannon.|My setup deals high damage but survives poorly.
KDR|Trying to improve my KDR.|Trying to get more kills relative to deaths.
LFW|LFW blacksmith, bring mats.|A blacksmith is offering crafting services; supply the materials.
OBO|WTS sword 20g OBO.|Selling a sword for 20 gold, while considering other offers.
XMUTE|Anyone have xmute ready?|Does an alchemist have the needed transmute available?
MP5|This ring has MP5.|The ring provides mana regeneration measured per five seconds.
GTG|Everyone here? GTG!|In this context, the group is ready to start.
TPS|Wait, the tank needs more TPS.|Give the tank time to generate enough threat.
GFPP|Bring GFPP for the run.|Bring Greater Fire Protection Potions.
BIO|Bio, back in two minutes.|Taking a short bathroom break.
PRIO|Tank has prio on this item.|The group's loot rules give the tank priority for that item.
FFA|Loot is FFA.|Eligible players may loot freely under this setting.
PASS|Pass if you do not want it.|Decline the chance to win that item.
PRE-BIS|Working on my pre-BIS set.|Collecting the best available gear before entering raids.
DMT|LFM DMT, need tank.|A Dire Maul Tribute group needs a tank.
STRAT UD|LFG Strat UD.|Looking for a group for the undead section of Stratholme.
STOCKS|Anyone running Stocks?|Is anyone doing The Stockade dungeon?
GNOMER|Need healer for Gnomer.|A Gnomeregan group needs a healer.
REZ|Can someone rez me?|Can someone resurrect my character?
CLEAVE|Watch the boss cleave.|Be careful of damage that also hits nearby targets.
INTERRUPT|Interrupt that cast!|Stop the enemy spell before it finishes casting.
DISPEL|Dispel the debuff if you can.|Use an appropriate ability to remove the harmful effect.
PURGE|Purge the enemy shield.|Remove the enemy's beneficial shield effect if it is removable.
ROOT|Root that enemy.|Prevent that enemy from moving.
PACK|Wait before the next pack.|Do not engage the next group of enemies yet.
OPENER|Save that spell for your opener.|Use that spell during your starting combat sequence.
OVERHEALING|Most of that heal was overhealing.|Much of the healing exceeded the health that was missing.
ATTUNEMENT|Need to finish my raid attunement.|I must complete the access requirements before entering that raid.
BOOMKIN|We have a boomkin.|The group has a Balance druid.
BREZ|Can you brez the healer?|Can you resurrect the healer during combat?
SHEEP|Sheep the marked target.|Use Polymorph on the enemy with the marker.
SALV|Could I get salv?|Please give me the paladin threat-reduction buff.
SS|Warlock, SS the healer.|In this context, SS means apply a soulstone to the healer.
MS>OS|Loot rules are MS>OS.|Gear for your primary role has priority over gear for a secondary role.
RES|LFM, trinket res.|The trinket is reserved; ask about the rules before joining.
MC|Priest, MC that enemy.|In this context, MC means Mind Control, rather than Molten Core.
BOP|Paladin, BOP the healer.|In this context, BOP means Blessing of Protection, rather than an item binding rule.
PROG|Tonight is a prog night.|The raid is attempting bosses it has not yet defeated.
BENCH|I am on the bench tonight.|I am sitting out the current raid group.
LOCKOUT|Check your raid lockout.|Check whether you are saved or restricted from repeating raid content.
LOL|That sheep ran straight into the boss, lol.|The player finds what happened funny.
LMAO|Lmao, we both fell off the same bridge.|The player is laughing about the accident.
JK|You owe me 100 gold. JK!|The gold demand was a joke.
OMG|OMG, that item finally dropped!|The player is excited about the drop.
IDM|We can do either dungeon, IDM.|The player has no preference between the dungeons.
NW|NW, we can try the pull again.|The mistake is not a problem; the group can retry.
TYVM|TYVM for the enchant!|The player is thanking someone for enchanting an item.
OTW|OTW to the dungeon entrance.|The player is travelling to the entrance.
G2G|Everyone buffed and G2G?|Here it asks whether everyone is ready; elsewhere G2G can mean someone must leave.
KICK|Kick the healer's next cast.|Interrupt the enemy healer's spell.
BUBBLE|Bubble yourself if you are about to die.|The paladin is being asked to use a personal protection spell.
SAP|Sap the marked target before we pull.|The rogue should control the marked enemy before combat starts.
COMP|Our comp needs another healer.|The group's mix of roles is missing a healer.
NUKE|Nuke the marked add first.|Focus heavy damage on that additional enemy.
SOAK|Two players need to soak this mechanic.|Two players should handle the mechanic together as required by the encounter.
LF3M|LF3M dungeon, need tank and heals.|The group needs three players, including a tank and healer.
PROT|LF prot warrior for this run.|The group wants a warrior using a protection build.
KITTY|The kitty is doing melee DPS.|The druid in cat form is dealing close-range damage.
MOONKIN|Invite the moonkin for ranged DPS.|Invite the Balance druid as a ranged damage dealer.
BOOMY|We have a boomy in the group.|The group contains a Balance druid.
BEAR|Let the bear pull first.|Let the druid tank start the fight.
COOKIES|Lock, can we get cookies before the pull?|The group is asking the warlock for Healthstones.
BLUEBERRY|My blueberry is tanking the mob.|The warlock's Voidwalker is holding the enemy's attention.
123|Type 123 if you need a summon.|Replying 123 tells the group you want to be summoned.
X|X for invites to the group.|Replying X signals that you want an invitation.
1|Type 1 if you need a summon.|Replying 1 signals a summon request in this group's context.
VC|Join VC before we start.|Join voice chat; in a dungeon recruitment message VC can instead mean Deadmines.
DC|The group link is in our DC.|Here DC means Discord; during gameplay it often means a disconnect.
HP|My HP is low; wait before pulling.|The player has little health remaining and wants the group to pause.
DMG|That spell does a lot of dmg.|The spell deals a large amount of damage.
CASTER|We need a caster for this group.|The group wants someone whose role uses spells; ask which role is needed.
MEZ|Mez the marked enemy before we pull.|Temporarily disable the marked enemy with appropriate crowd control.
STACK|WTB a stack of herbs.|The buyer wants a stack of crafting herbs; confirm the quantity and price.
LOOT|Wait until everyone is ready to loot.|Pause before collecting the encounter's rewards.
PET|Put your pet on passive for this pull.|Stop the companion from attacking automatically during this engagement.
NEWBIE|I'm a newbie; can you explain the boss?|The player is learning and wants the encounter explained.
VENDOR TRASH|Selling my vendor trash before the next run.|The player is selling low-value loot to an NPC merchant.
NBG|This run uses NBG.|The group gives legitimate item needs priority over greed; ask for its exact rules.
HARD RES|LFM BRD, one item hard res.|An item is reserved; ask which one before joining.
SOFT RES|Choose your soft res before the raid.|Declare the item you want to reserve under this group's rules.
+1 RESET|We have a +1 reset at the final boss.|The group plans to clear loot priority counters at an agreed boss.
LOOT TRADING|Is loot trading available for this item?|The player asks whether the item can be passed to another eligible player.
SELLABLES RESERVED|LFM dungeon carry, sellables reserved.|The organizer claims certain sellable drops; clarify exactly what is reserved.
ORB RUN|LFM Strat Live orb run.|A group is farming Righteous Orbs in Stratholme's living side.
JUMP RUNS|Doing jump runs in DME tonight.|The player plans repeated Dire Maul East farming routes.
DME JUMPS|LF partner for DME jumps.|The player wants a partner for Dire Maul East jump runs.
DMJR|LFM DMJR; agree on loot before we start.|A Dire Maul jump-run group wants players to settle loot rules first.
REND|LFM UBRS Rend run.|The group plans to reach Rend Blackhand, usually rather than clear all of UBRS.
JED|Checking this UBRS for Jed.|The player is checking whether the rare enemy Jed Runeshaper is present.
JED/REND|Need healer for Jed/Rend.|The UBRS group wants a healer for its Jed and Rend route.
DMNT|LFG DMNT, tank ready.|A tank is looking for a Dire Maul North tribute group.
TRIBUTE|Anyone doing a Dire Maul tribute?|The player wants a North-wing run aimed at tribute rewards.
OG|Meet me in OG.|The player is asking to meet in Orgrimmar.
CR|Meet at CR in the Barrens.|Here CR means Crossroads; death-related chat can mean corpse retrieval.
C.O.D|Send the herbs C.O.D for the agreed price.|Mail the herbs with the agreed payment requirement.
EXP|This quest gives good exp.|The quest awards a useful amount of experience toward leveling.
DE-BUFF|Can someone remove this de-buff?|The player wants an eligible harmful effect removed.
SM/RUIN|I'm using SM/Ruin on my warlock.|The player's Classic warlock build includes Shadow Mastery and Ruin.
DS/RUIN|Trying a DS/Ruin build.|The player is trying a warlock build with Demonic Sacrifice and Ruin.
MD/RUIN|Our warlock uses MD/Ruin.|The warlock build includes Master Demonologist and Ruin.
NF/SL|Going NF/SL for PvP.|The warlock is choosing a Nightfall and Soul Link build for player combat.
NF/CONFLAG|Testing NF/Conflag in duels.|The warlock is testing a Nightfall and Conflagrate build.
SL/SB|I'm playing SL/SB today.|The warlock is using Soul Link and Shadowburn in this build context.
MARA BLUE|LFM Mara Blue, quest run.|The group is using Maraudon's blue/purple route for quests.
MARA PURPLE|LFG Mara Purple.|The player wants a group for the Maraudon purple entrance route.
MARA ORANGE|Need healer for Mara Orange.|A Maraudon orange-route group needs a healer.
MARA PRINCESS|LFM Mara Princess; ask about the route.|The group is targeting Princess Theradras; clarify which other bosses are included.
DD|LFM dungeon, need one DD.|The group needs one damage dealer; DD can also mean direct damage.
RR|Meet me in RR for quests.|Here RR means Redridge Mountains, rather than Round Robin loot.
WF|Heading to WF from Stormwind.|In this travel context, WF means Westfall.
SHARD|Warlock, do you have a shard for summons?|Here shard means a warlock Soul Shard, rather than an enchanting material.
TAP|Don't tap that quest mob yet.|Here tap means damaging the enemy to claim credit, rather than using Life Tap.
C|SM C run, need tank.|With Scarlet Monastery already specified, C can mean the Cathedral wing.
WOW|This is my first time playing WoW.|The player is new to World of Warcraft.
CAMPER|There is a camper near the quest spot.|A player is staying near that location; ask whether they are waiting for a spawn or attacking others.
GANKING|Someone is ganking players near the road.|A player is ambushing other players in that area.
25M|LFM 25m raid, need healers.|A twenty-five-player raid group needs healers in a version supporting that raid size.
HM|Are we doing this boss on HM?|The player asks whether the group will attempt the boss's harder mode.
FARMED|We farmed this dungeon for drops.|The group repeatedly cleared the dungeon to obtain items.
JC|LF JC to cut this gem.|The player wants a jewelcrafter to prepare a gem in a version supporting Jewelcrafting.
ICC|LFM ICC tonight.|The group is recruiting for Icecrown Citadel, a Wrath-era raid.
KARA|Our TBC group is going to Kara.|The group plans to enter the Karazhan raid.
DAL|Meet me in Dal.|The player wants to meet in Dalaran; confirm which location if the version has multiple relevant forms.
RMP|Our arena team plays RMP.|The team uses a rogue, mage and priest.
20M|Need one healer for a 20m raid.|A twenty-player raid group has an open healer slot.
MULE|Sending these herbs to my mule.|The player is transferring crafting materials to a storage character.
RDPS|LFM dungeon, need RDPS.|The group is recruiting ranged damage dealers.
BFA|I started playing during BFA.|The player began during the Battle for Azeroth expansion.
NAX|LFM Nax, check the raid version.|The group is recruiting for Naxxramas; confirm the intended version.
SHAT|Meet at Shat before the run.|The player wants to meet in Shattrath City.
ARPEN|Does this item have Arpen?|The player asks whether the item provides armor penetration in the relevant ruleset.
IDD|That pull was difficult, idd.|The player agrees that the pull was difficult.
NB|My mage is an NB.|The player says the character is Nightborne in a version supporting that race.
VELF|I made a Velf priest.|The player created a Void elf priest in a version supporting that race.
WAGGRO|Waggro, need a short break.|The player jokingly says their spouse needs their attention.
BELF|I'm playing a Belf paladin.|The player uses a Blood elf paladin in a version supporting that combination.
SHATT|Heading to Shatt for supplies.|The player is travelling to Shattrath City.
DISC|Our healer is a disc priest.|The priest is using a Discipline build or specialization.
RTK|Anyone up for RTK?|The player wants a Return to Karazhan dungeon group in a version with that content.
MUT|Testing a mut build on my rogue.|The player is testing a rogue build centered on Mutilate in a supported ruleset.
10M|We have a 10m raid tonight.|The group plans a ten-player raid.
HP5|This gear has some hp5.|The item provides health regeneration expressed per five seconds.
BOT MAFIA|People are calling that farming group a bot mafia.|Players suspect coordinated automation; the slang is an accusation rather than proof.
WG|The WG battle is starting.|The Wintergrasp PvP battle is beginning in a version with that activity.
BC|I played during BC.|The player played during The Burning Crusade.
]==]
for line in EXAMPLES:gmatch("[^\r\n]+") do
    local key, sentence, meaning = line:match("^([^|]+)|([^|]+)|(.+)$")
    key = key and key:upper()
    if key and entries[key] then
        entries[key].example = { sentence = sentence, meaning = meaning }
    end
end
