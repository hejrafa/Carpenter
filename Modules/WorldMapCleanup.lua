--[[ Carpenter - World Map Cleanup ]]
-- Classic Era/TBC map tweaks: move the default map, reduce settlement markers,
-- and add practical POIs for dungeons, raids, and same-faction travel.

if Carpenter and Carpenter.Client and not Carpenter.Client.isClassic then return end

local CUSTOM_PIN_TEMPLATE = "CPWorldMapCleanupPinTemplate"
local LEATRIX_SMALL_MAP_X = 16
local LEATRIX_SMALL_MAP_Y = -104
local FULLSCREEN_MAP_SCALE = 0.85
local MOVING_MAP_ALPHA = 0.5
local MAP_FADE_DURATION = 0.25
local GROUP_MEMBER_PIN_SIZE = 12
local GROUP_MEMBER_PIN_TEXTURE = "Interface\\AddOns\\Carpenter\\Art\\Icons\\GroupMemberPin.tga"
local POI_TBC_ONLY = "tbc"

local frame = CreateFrame("Frame")
local originalFullscreenGeometry = nil
local originalBlackoutAlpha = nil
local originalMapAlpha = nil
local originalMapScale = nil
local originalScreenAnchorPoints = nil
local hiddenMapObjects = {}
local hookedWorldMap = false
local hookedTownCityPins = false
local hookedCursorScale = false
local originalScrollContainerGetCursorPosition = nil
local originalScrollContainerGetNormalizedCursorPosition = nil
local originalWorldMapGetNormalizedCursorPosition = nil
local customPOIProvider = nil
local scheduleNonce = 0
local centeredMapCanvasKey = nil
local originalGroupMemberPinSizes = nil
local hookedGroupMemberPins = false

local POI_ICON_SIZES = {
    Dungeon = 18,
    Raid = 18,
    Dunraid = 20,
    FlightA = 14,
    FlightH = 14,
    FlightN = 14,
    TravelA = 14,
    TravelH = 14,
    TravelN = 14,
}

local POI_ATLAS = {
    Dungeon = "Dungeon",
    Raid = "Raid",
    Dunraid = "Dungeon",
    FlightA = "TaxiNode_Alliance",
    FlightH = "TaxiNode_Horde",
    FlightN = "TaxiNode_Neutral",
    TravelA = "TaxiNode_Alliance",
    TravelH = "TaxiNode_Horde",
    TravelN = "TaxiNode_Neutral",
}

local POI_DATA = {
    [1411] = {
        { "TravelH", 50.9, 13.9, "Zeppelin to Undercity, Tirisfal Glades", nil, "TaxiNode_Horde", nil, nil, 1420 },
        { "TravelH", 50.6, 12.6, "Zeppelin to Grom'gol Base Camp, Stranglethorn Vale", nil, "TaxiNode_Horde", nil, nil, 1434 },
    },
    [1413] = {
        { "Dungeon", 46, 36.4, "Wailing Caverns", "Dungeon", "Dungeon", 17, 24 },
        { "Dungeon", 42.9, 90.2, "Razorfen Kraul", "Dungeon", "Dungeon", 29, 38 },
        { "Dungeon", 49, 93.9, "Razorfen Downs", "Dungeon", "Dungeon", 37, 46 },
        { "FlightN", 63.1, 37.2, "Ratchet, The Barrens", nil, "TaxiNode_Neutral" },
        { "FlightH", 51.5, 30.3, "The Crossroads, The Barrens", nil, "TaxiNode_Horde" },
        { "FlightH", 44.4, 59.2, "Camp Taurajo, The Barrens", nil, "TaxiNode_Horde" },
        { "TravelN", 63.7, 38.6, "Boat to Booty Bay, Stranglethorn Vale", nil, "TaxiNode_Neutral", nil, nil, 1434 },
    },
    [1417] = {
        { "FlightA", 45.8, 46.1, "Refuge Pointe, Arathi Highlands", nil, "TaxiNode_Alliance" },
        { "FlightH", 73.1, 32.7, "Hammerfall, Arathi Highlands", nil, "TaxiNode_Horde" },
    },
    [1418] = {
        { "Dungeon", 44.6, 12.1, "Uldaman", "Dungeon", "Dungeon", 41, 51 },
        { "FlightH", 4, 44.8, "Kargath, Badlands", nil, "TaxiNode_Horde" },
    },
    [1419] = {
        { "FlightA", 65.5, 24.3, "Nethergarde Keep, Blasted Lands", nil, "TaxiNode_Alliance" },
    },
    [1420] = {
        { "Dungeon", 82.6, 33.8, "Scarlet Monastery", "Dungeon", "Dungeon", 34, 45 },
        { "TravelH", 60.7, 58.8, "Zeppelin to Orgrimmar, Durotar", nil, "TaxiNode_Horde", nil, nil, 1411 },
        { "TravelH", 61.9, 59.1, "Zeppelin to Grom'gol Base Camp, Stranglethorn Vale", nil, "TaxiNode_Horde", nil, nil, 1434 },
    },
    [1421] = {
        { "Dungeon", 44.8, 67.8, "Shadowfang Keep", "Dungeon", "Dungeon", 22, 30 },
        { "FlightH", 45.6, 42.6, "The Sepulcher, Silverpine Forest", nil, "TaxiNode_Horde" },
    },
    [1422] = {
        { "Dungeon", 69.7, 73.2, "Scholomance", "Dungeon", "Dungeon", 58, 60 },
        { "FlightA", 42.9, 85.1, "Chillwind Camp, Western Plaguelands", nil, "TaxiNode_Alliance" },
    },
    [1423] = {
        { "Dungeon", 31.3, 15.7, "Stratholme (Main Gate)", "Dungeon", "Dungeon", 58, 60 },
        { "Dungeon", 47.9, 23.9, "Stratholme (Service Gate)", "Dungeon", "Dungeon", 58, 60 },
        { "Raid", 39.9, 25.9, "Naxxramas", "Raid", "Raid", 60, 60 },
        { "FlightA", 81.6, 59.3, "Light's Hope Chapel, Eastern Plaguelands", nil, "TaxiNode_Alliance" },
        { "FlightH", 80.2, 57, "Light's Hope Chapel, Eastern Plaguelands", nil, "TaxiNode_Horde" },
    },
    [1424] = {
        { "FlightA", 49.3, 52.3, "Southshore, Hillsbrad Foothills", nil, "TaxiNode_Alliance" },
        { "FlightH", 60.1, 18.6, "Tarren Mill, Hillsbrad Foothills", nil, "TaxiNode_Horde" },
    },
    [1425] = {
        { "FlightA", 11.1, 46.2, "Aerie Peak, The Hinterlands", nil, "TaxiNode_Alliance" },
        { "FlightH", 81.7, 81.8, "Revantusk Village, The Hinterlands", nil, "TaxiNode_Horde" },
    },
    [1426] = {
        { "Dungeon", 24.3, 39.8, "Gnomeregan", "Dungeon", "Dungeon", 29, 38 },
    },
    [1427] = {
        { "Dunraid", 34.8, 85.3, "Blackrock Mountain", "Blackrock Depths, Lower Blackrock Spire, Upper Blackrock Spire, |nMolten Core, Blackwing Lair", "Dungeon", 52, 60 },
        { "FlightA", 37.9, 30.8, "Thorium Point, Searing Gorge", nil, "TaxiNode_Alliance" },
        { "FlightH", 34.8, 30.9, "Thorium Point, Searing Gorge", nil, "TaxiNode_Horde" },
    },
    [1428] = {
        { "Dunraid", 29.4, 38.3, "Blackrock Mountain", "Blackrock Depths, Lower Blackrock Spire, Upper Blackrock Spire, |nMolten Core, Blackwing Lair", "Dungeon", 52, 60 },
        { "FlightA", 84.3, 68.3, "Morgan's Vigil, Burning Steppes", nil, "TaxiNode_Alliance" },
        { "FlightH", 65.7, 24.2, "Flame Crest, Burning Steppes", nil, "TaxiNode_Horde" },
    },
    [1430] = {
        { "Raid", 46.9, 74.7, "Karazhan", "Raid", "Raid", 70, 70, nil, POI_TBC_ONLY },
    },
    [1431] = {
        { "FlightA", 77.5, 44.3, "Darkshire, Duskwood", nil, "TaxiNode_Alliance" },
    },
    [1432] = {
        { "FlightA", 33.9, 50.9, "Thelsamar, Loch Modan", nil, "TaxiNode_Alliance" },
    },
    [1433] = {
        { "FlightA", 30.6, 59.4, "Lake Everstill, Redridge Mountains", nil, "TaxiNode_Alliance" },
    },
    [1434] = {
        { "Raid", 53.9, 17.6, "Zul'Gurub", "Raid", "Raid", 60, 60 },
        { "FlightA", 27.5, 77.8, "Booty Bay, Stranglethorn Vale", nil, "TaxiNode_Alliance" },
        { "FlightA", 38.2, 4, "Rebel Camp, Stranglethorn Vale", nil, "TaxiNode_Alliance", nil, nil, nil, POI_TBC_ONLY },
        { "FlightH", 26.9, 77.1, "Booty Bay, Stranglethorn Vale", nil, "TaxiNode_Horde" },
        { "FlightH", 32.5, 29.4, "Grom'gol Base Camp, Stranglethorn Vale", nil, "TaxiNode_Horde" },
        { "TravelN", 25.9, 73.1, "Boat to Ratchet, The Barrens", nil, "TaxiNode_Neutral", nil, nil, 1413 },
        { "TravelH", 31.4, 30.2, "Zeppelin to Orgrimmar, Durotar", nil, "TaxiNode_Horde", nil, nil, 1411 },
        { "TravelH", 31.6, 29.1, "Zeppelin to Undercity, Tirisfal Glades", nil, "TaxiNode_Horde", nil, nil, 1420 },
    },
    [1435] = {
        { "Dungeon", 69.9, 53.6, "Temple of Atal'Hakkar", "Dungeon", "Dungeon", 50, 60 },
        { "FlightH", 46.1, 54.8, "Stonard, Swamp of Sorrows", nil, "TaxiNode_Horde" },
    },
    [1436] = {
        { "Dungeon", 42.5, 71.7, "The Deadmines", "Dungeon", "Dungeon", 17, 26 },
        { "FlightA", 56.6, 52.6, "Sentinel Hill, Westfall", nil, "TaxiNode_Alliance" },
    },
    [1437] = {
        { "FlightA", 9.5, 59.7, "Menethil Harbor, Wetlands", nil, "TaxiNode_Alliance" },
        { "TravelA", 5, 63.5, "Boat to Theramore Isle, Dustwallow Marsh", nil, "TaxiNode_Alliance", nil, nil, 1445 },
        { "TravelA", 4.6, 57.1, "Boat to Auberdine, Darkshore", nil, "TaxiNode_Alliance", nil, nil, 1439 },
    },
    [1438] = {
        { "FlightA", 58.4, 94, "Rut'theran Village, Teldrassil", nil, "TaxiNode_Alliance" },
        { "TravelA", 54.9, 96.8, "Boat to Auberdine, Darkshore", nil, "TaxiNode_Alliance", nil, nil, 1439 },
    },
    [1439] = {
        { "FlightA", 36.3, 45.6, "Auberdine, Darkshore", nil, "TaxiNode_Alliance" },
        { "TravelA", 32.4, 43.8, "Boat to Menethil Harbor, Wetlands", nil, "TaxiNode_Alliance", nil, nil, 1437 },
        { "TravelA", 33.2, 40.1, "Boat to Rut'theran Village, Teldrassil", nil, "TaxiNode_Alliance", nil, nil, 1438 },
        { "TravelA", 30.7, 41, "Boat to Valaar's Berth, Azuremyst Isle", nil, "TaxiNode_Alliance", nil, nil, 1943, POI_TBC_ONLY },
    },
    [1440] = {
        { "Dungeon", 14.5, 14.2, "Blackfathom Deeps", "Dungeon", "Dungeon", 24, 32 },
        { "FlightA", 34.4, 48, "Astranaar, Ashenvale", nil, "TaxiNode_Alliance" },
        { "FlightA", 85, 43.4, "Forest Song, Ashenvale", nil, "TaxiNode_Alliance", nil, nil, nil, POI_TBC_ONLY },
        { "FlightH", 73.2, 61.6, "Splintertree Post, Ashenvale", nil, "TaxiNode_Horde" },
        { "FlightH", 12.2, 33.8, "Zoram'gar Outpost, Ashenvale", nil, "TaxiNode_Horde" },
    },
    [1441] = {
        { "FlightH", 45.1, 49.1, "Freewind Post, Thousand Needles", nil, "TaxiNode_Horde" },
    },
    [1442] = {
        { "FlightA", 36.4, 7.2, "Stonetalon Peak, Stonetalon Mountains", nil, "TaxiNode_Alliance" },
        { "FlightH", 45.1, 59.8, "Sun Rock Retreat, Stonetalon Mountains", nil, "TaxiNode_Horde" },
    },
    [1443] = {
        { "Dungeon", 29.1, 62.5, "Maraudon", "Dungeon", "Dungeon", 46, 55 },
        { "FlightA", 64.7, 10.5, "Nijel's Point, Desolace", nil, "TaxiNode_Alliance" },
        { "FlightH", 21.6, 74.1, "Shadowprey Village, Desolace", nil, "TaxiNode_Horde" },
    },
    [1444] = {
        { "FlightA", 30.2, 43.2, "Feathermoon Stronghold, Feralas", nil, "TaxiNode_Alliance" },
        { "FlightH", 75.4, 44.4, "Camp Mojache, Feralas", nil, "TaxiNode_Horde" },
        { "FlightA", 89.5, 45.9, "Thalanaar, Feralas", nil, "TaxiNode_Alliance" },
        { "Dungeon", 62.5, 24.9, "Dire Maul (North)", "Dungeon", "Dungeon", 56, 60 },
        { "Dungeon", 60.3, 30.2, "Dire Maul (West)", "Dungeon", "Dungeon", 56, 60 },
        { "Dungeon", 64.8, 30.2, "Dire Maul (East)", "Dungeon", "Dungeon", 56, 60 },
        { "TravelA", 43.3, 42.8, "Boat to Feathermoon Stronghold, Feralas", nil, "TaxiNode_Alliance" },
        { "TravelA", 31, 39.8, "Boat to The Forgotten Coast, Feralas", nil, "TaxiNode_Alliance" },
    },
    [1445] = {
        { "Raid", 52.6, 76.8, "Onyxia's Lair", "Raid", "Raid", 60, 60 },
        { "FlightA", 67.5, 51.3, "Theramore Isle, Dustwallow Marsh", nil, "TaxiNode_Alliance" },
        { "FlightH", 35.6, 31.9, "Brackenwall Village, Dustwallow Marsh", nil, "TaxiNode_Horde" },
        { "FlightN", 42.8, 72.5, "Mudsprocket, Dustwallow Marsh", nil, "TaxiNode_Neutral", nil, nil, nil, POI_TBC_ONLY },
        { "TravelA", 71.6, 56.4, "Boat to Menethil Harbor, Wetlands", nil, "TaxiNode_Alliance", nil, nil, 1437 },
    },
    [1446] = {
        { "Dungeon", 38.7, 20, "Zul'Farrak", "Dungeon", "Dungeon", 44, 54 },
        { "Dunraid", 65.7, 49.9, "Caverns of Time", "Black Morass, Hyjal Summit, Old Hillsbrad", "Dungeon", 66, 70, nil, POI_TBC_ONLY },
        { "FlightA", 51, 29.3, "Gadgetzan, Tanaris", nil, "TaxiNode_Alliance" },
        { "FlightH", 51.6, 25.4, "Gadgetzan, Tanaris", nil, "TaxiNode_Horde" },
    },
    [1447] = {
        { "FlightA", 11.9, 77.6, "Talrendis Point, Azshara", nil, "TaxiNode_Alliance" },
        { "FlightH", 22, 49.6, "Valormok, Azshara", nil, "TaxiNode_Horde" },
    },
    [1448] = {
        { "FlightA", 62.5, 24.2, "Talonbranch Glade, Felwood", nil, "TaxiNode_Alliance" },
        { "FlightH", 34.4, 54, "Bloodvenom Post, Felwood", nil, "TaxiNode_Horde" },
        { "FlightN", 51.4, 82.2, "Emerald Sanctuary, Felwood", nil, "TaxiNode_Neutral", nil, nil, nil, POI_TBC_ONLY },
    },
    [1449] = {
        { "FlightN", 45.2, 5.8, "Marshal's Refuge, Un'Goro Crater", nil, "TaxiNode_Neutral" },
    },
    [1450] = {
        { "FlightA", 48.1, 67.4, "Lake Elune'ara, Moonglade", nil, "TaxiNode_Alliance" },
        { "FlightH", 32.1, 66.6, "Moonglade", nil, "TaxiNode_Horde" },
    },
    [1451] = {
        { "Raid", 28.6, 92.4, "Ahn'Qiraj", "Ruins of Ahn'Qiraj, Temple of Ahn'Qiraj", "Raid", 60, 60 },
        { "FlightA", 50.6, 34.5, "Cenarion Hold, Silithus", nil, "TaxiNode_Alliance" },
        { "FlightH", 48.7, 36.7, "Cenarion Hold, Silithus", nil, "TaxiNode_Horde" },
    },
    [1452] = {
        { "FlightA", 62.3, 36.6, "Everlook, Winterspring", nil, "TaxiNode_Alliance" },
        { "FlightH", 60.5, 36.3, "Everlook, Winterspring", nil, "TaxiNode_Horde" },
    },
    [1453] = {
        { "Dungeon", 42.3, 59, "The Stockade", "Dungeon", "Dungeon", 24, 32 },
        { "FlightA", 66.3, 62.1, "Trade District, Stormwind", nil, "TaxiNode_Alliance" },
        { "TravelA", 60.5, 12.4, "Tram to Tinker Town, Ironforge", nil, "TaxiNode_Alliance", nil, nil, 1455 },
    },
    [1454] = {
        { "Dungeon", 52.6, 49, "Ragefire Chasm", "Dungeon", "Dungeon", 13, 18 },
        { "FlightH", 45.1, 63.9, "Valley of Strength, Orgrimmar", nil, "TaxiNode_Horde" },
    },
    [1455] = {
        { "FlightA", 55.5, 47.8, "The Great Forge, Ironforge", nil, "TaxiNode_Alliance" },
        { "TravelA", 73, 50.2, "Tram to Dwarven District, Stormwind", nil, "TaxiNode_Alliance", nil, nil, 1453 },
    },
    [1456] = {
        { "FlightH", 47, 49.8, "Central Mesa, Thunder Bluff", nil, "TaxiNode_Horde" },
    },
    [1458] = {
        { "FlightH", 63.3, 48.5, "Trade Quarter, Undercity", nil, "TaxiNode_Horde" },
        { "TravelH", 54.9, 11.3, "Silvermoon City", "Orb of Translocation", "TaxiNode_Horde", nil, nil, nil, POI_TBC_ONLY },
    },
    [1941] = {
        { "FlightH", 54.4, 50.7, "Silvermoon City, Eversong Woods", nil, "TaxiNode_Horde" },
    },
    [1942] = {
        { "FlightH", 45.4, 30.5, "Tranquillien, Ghostlands", nil, "TaxiNode_Horde" },
        { "FlightN", 74.7, 67.1, "Zul'Aman, Ghostlands", nil, "TaxiNode_Neutral" },
        { "Raid", 82.3, 64.3, "Zul'Aman", "Raid", "Raid", 70, 70 },
    },
    [1943] = {
        { "FlightA", 31.9, 46.4, "The Exodar, Azuremyst Isle", nil, "TaxiNode_Alliance" },
        { "TravelA", 20.3, 54.2, "Boat to Rut'theran Village, Teldrassil", nil, "TaxiNode_Alliance", nil, nil, 1439 },
    },
    [1944] = {
        { "Dungeon", 47.7, 53.6, "Hellfire Ramparts", "Dungeon", "Dungeon", 58, 67 },
        { "Dungeon", 47.7, 52, "The Shattered Halls", "Dungeon", "Dungeon", 69, 70 },
        { "Dungeon", 46, 51.8, "The Blood Furnace", "Dungeon", "Dungeon", 61, 68 },
        { "Raid", 46.6, 52.8, "Magtheridon's Lair", "Raid", "Raid", 70, 70 },
        { "FlightA", 25.2, 37.2, "Temple of Telhamat, Hellfire Peninsula", nil, "TaxiNode_Alliance" },
        { "FlightA", 54.6, 62.4, "Honor Hold, Hellfire Peninsula", nil, "TaxiNode_Alliance" },
        { "FlightA", 87.4, 52.4, "The Dark Portal, Hellfire Peninsula", nil, "TaxiNode_Alliance" },
        { "FlightA", 78.4, 34.9, "Shatter Point, Hellfire Peninsula", nil, "TaxiNode_Alliance" },
        { "FlightH", 56.2, 36.2, "Thrallmar, Hellfire Peninsula", nil, "TaxiNode_Horde" },
        { "FlightH", 27.8, 60, "Falcon Watch, Hellfire Peninsula", nil, "TaxiNode_Horde" },
        { "FlightH", 87.4, 48.2, "The Dark Portal, Hellfire Peninsula", nil, "TaxiNode_Horde" },
        { "FlightH", 61.6, 81.2, "Spinebreaker Ridge, Hellfire Peninsula", nil, "TaxiNode_Horde" },
        { "TravelA", 88.6, 52.8, "Stormwind City", "Portal", "TaxiNode_Alliance", nil, nil, 1453 },
        { "TravelH", 88.6, 47.7, "Orgrimmar", "Portal", "TaxiNode_Horde", nil, nil, 1454 },
    },
    [1946] = {
        { "FlightA", 41.2, 28.8, "Orebor Harborage, Zangarmarsh", nil, "TaxiNode_Alliance" },
        { "FlightA", 67.8, 51.4, "Telredor, Zangarmarsh", nil, "TaxiNode_Alliance" },
        { "FlightH", 33, 51, "Zabra'jin, Zangarmarsh", nil, "TaxiNode_Horde" },
        { "FlightH", 84.8, 55, "Swamprat Post, Zangarmarsh", nil, "TaxiNode_Horde" },
    },
    [1947] = {
        { "FlightA", 68.5, 63.7, "The Exodar, Azuremyst Isle", nil, "TaxiNode_Alliance" },
    },
    [1948] = {
        { "Raid", 71, 46.4, "Black Temple", "Raid", "Raid", 70, 70 },
        { "FlightA", 37.6, 55.4, "Wildhammer Stronghold, Shadowmoon Valley", nil, "TaxiNode_Alliance" },
        { "FlightH", 30.2, 29.2, "Shadowmoon Village, Shadowmoon Valley", nil, "TaxiNode_Horde" },
        { "FlightN", 63.4, 30.4, "Altar of Sha'tar, Shadowmoon Valley", nil, "TaxiNode_Neutral" },
        { "FlightN", 56.2, 57.8, "Sanctum of the Stars, Shadowmoon Valley", nil, "TaxiNode_Neutral" },
    },
    [1949] = {
        { "Raid", 68.7, 24.3, "Gruul's Lair", "Raid", "Raid", 70, 70 },
        { "FlightA", 37.8, 61.4, "Sylvanaar, Blade's Edge Mountains", nil, "TaxiNode_Alliance" },
        { "FlightA", 61, 70.4, "Toshley's Station, Blade's Edge Mountains", nil, "TaxiNode_Alliance" },
        { "FlightH", 52, 54.2, "Thunderlord Stronghold, Blade's Edge Mountains", nil, "TaxiNode_Horde" },
        { "FlightH", 76.4, 65.8, "Mok'Nathal Village, Blade's Edge Mountains", nil, "TaxiNode_Horde" },
        { "FlightN", 61.6, 39.6, "Evergrove, Blade's Edge Mountains", nil, "TaxiNode_Neutral" },
    },
    [1950] = {
        { "FlightA", 57.7, 53.9, "Blood Watch, Bloodmyst Isle", nil, "TaxiNode_Alliance" },
    },
    [1951] = {
        { "FlightA", 54.2, 75, "Telaar, Nagrand", nil, "TaxiNode_Alliance" },
        { "FlightH", 57.2, 35.2, "Garadar, Nagrand", nil, "TaxiNode_Horde" },
    },
    [1952] = {
        { "Dungeon", 43.2, 65.6, "Sethekk Halls", "Dungeon", "Dungeon", 67, 70 },
        { "Dungeon", 36.1, 65.6, "Auchenai Crypts", "Dungeon", "Dungeon", 65, 70 },
        { "Dungeon", 39.6, 71, "Shadow Labyrinth", "Dungeon", "Dungeon", 69, 70 },
        { "Dungeon", 39.7, 60.2, "Mana-Tombs", "Dungeon", "Dungeon", 64, 70 },
        { "FlightA", 59.4, 55.4, "Allerian Stronghold, Terokkar Forest", nil, "TaxiNode_Alliance" },
        { "FlightH", 49.2, 43.4, "Stonebreaker Hold, Terokkar Forest", nil, "TaxiNode_Horde" },
        { "FlightN", 33.1, 23.1, "Shattrath City, Terokkar Forest", nil, "TaxiNode_Neutral" },
    },
    [1953] = {
        { "Dungeon", 71.7, 55, "The Botanica", "Dungeon", "Dungeon", 70, 70 },
        { "Dungeon", 74.4, 57.7, "The Arcatraz", "Dungeon", "Dungeon", 70, 70 },
        { "Dungeon", 70.6, 69.7, "The Mechanar", "Dungeon", "Dungeon", 70, 70 },
        { "Raid", 73.7, 63.7, "The Eye", "Raid", "Raid", 70, 70 },
        { "FlightN", 33.8, 64, "Area 52, Netherstorm", nil, "TaxiNode_Neutral" },
        { "FlightN", 45.2, 34.8, "The Stormspire, Netherstorm", nil, "TaxiNode_Neutral" },
        { "FlightN", 65.2, 66.6, "Cosmowrench, Netherstorm", nil, "TaxiNode_Neutral" },
    },
    [1954] = {
        { "TravelH", 49.5, 14.8, "Undercity", "Orb of Translocation", "TaxiNode_Horde", nil, nil, 1458, POI_TBC_ONLY },
    },
    [1955] = {
        { "FlightN", 64.1, 41.1, "Shattrath City, Terokkar Forest", nil, "TaxiNode_Neutral" },
        { "TravelN", 48.5, 42, "Isle of Quel'Danas", "Portal", "TaxiNode_Neutral", nil, nil, 1957 },
        { "TravelA", 55.8, 36.5, "Alliance Cities", "Darnassus, Stormwind, Ironforge", "TaxiNode_Alliance" },
        { "TravelH", 52.2, 52.9, "Horde Cities", "Thunder Bluff, Orgrimmar, Undercity", "TaxiNode_Horde" },
        { "TravelA", 59.6, 46.7, "The Exodar", "Portal", "TaxiNode_Alliance" },
        { "TravelH", 59.2, 48.4, "Silvermoon City", "Portal", "TaxiNode_Horde" },
    },
    [1957] = {
        { "Dungeon", 61.2, 30.9, "Magisters' Terrace", "Dungeon", "Dungeon", 68, 70 },
        { "Raid", 44.3, 45.6, "Sunwell Plateau", "Raid", "Raid", 70, 70 },
        { "FlightA", 48.5, 25.2, "Shattered Sun Staging Area, Isle of Quel'Danas", nil, "TaxiNode_Alliance" },
        { "FlightH", 48.4, 25.1, "Shattered Sun Staging Area, Isle of Quel'Danas", nil, "TaxiNode_Horde" },
    },
}

local function IsEnabled()
    return Carpenter and Carpenter:IsEnabled("worldMapCleanupEnabled")
end

local function SafeRegisterEvent(event)
    if not event then return end
    pcall(frame.RegisterEvent, frame, event)
end

local function CaptureFramePoints(frameToCapture)
    if not frameToCapture or not frameToCapture.GetNumPoints then return nil end

    local points = {}
    local numPoints = frameToCapture:GetNumPoints() or 0
    for index = 1, numPoints do
        local point, relativeTo, relativePoint, xOfs, yOfs = frameToCapture:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
        }
    end

    return points
end

local function RestoreFramePoints(frameToRestore, points)
    if not frameToRestore or not points or not frameToRestore.ClearAllPoints or not frameToRestore.SetPoint then return end

    frameToRestore:ClearAllPoints()
    for _, point in ipairs(points) do
        if point.relativeTo then
            frameToRestore:SetPoint(point.point, point.relativeTo, point.relativePoint, point.xOfs, point.yOfs)
        else
            frameToRestore:SetPoint(point.point, point.xOfs, point.yOfs)
        end
    end
end

local function CaptureMapScale(mapFrame)
    if originalMapScale ~= nil or not mapFrame or not mapFrame.GetScale then return end
    originalMapScale = mapFrame:GetScale() or 1
end

local function CaptureSmallMapAnchor()
    if originalScreenAnchorPoints or not _G.WorldMapScreenAnchor then return end
    originalScreenAnchorPoints = CaptureFramePoints(_G.WorldMapScreenAnchor)
end

local function IsMapFullscreen(mapFrame)
    if not mapFrame then return false end
    if mapFrame.IsMaximized then
        local ok, maximized = pcall(mapFrame.IsMaximized, mapFrame)
        if ok then return maximized == true end
    end
    return mapFrame.isMaximized == true
end

local function CaptureFullscreenGeometry(mapFrame)
    if originalFullscreenGeometry or not IsMapFullscreen(mapFrame) then return end

    originalFullscreenGeometry = {
        points = CaptureFramePoints(mapFrame),
        width = mapFrame.GetWidth and mapFrame:GetWidth() or nil,
        height = mapFrame.GetHeight and mapFrame:GetHeight() or nil,
    }
end

local function RestoreFullscreenSize(mapFrame)
    if not mapFrame or not mapFrame.SetSize or not originalFullscreenGeometry then return end
    if not originalFullscreenGeometry.width or not originalFullscreenGeometry.height then return end
    if mapFrame.GetWidth and mapFrame.GetHeight then
        local currentWidth = mapFrame:GetWidth() or 0
        local currentHeight = mapFrame:GetHeight() or 0
        if math.abs(currentWidth - originalFullscreenGeometry.width) < 1 and
            math.abs(currentHeight - originalFullscreenGeometry.height) < 1 then
            return
        end
    end

    mapFrame:SetSize(originalFullscreenGeometry.width, originalFullscreenGeometry.height)
    if mapFrame.OnFrameSizeChanged then mapFrame:OnFrameSizeChanged() end
end

local function GetScaledMapCursorPosition(container, mapFrame)
    local x, y = MapCanvasScrollControllerMixin.GetCursorPosition(container)
    if not x or not y then return x, y end

    local scale = mapFrame and mapFrame.GetScale and mapFrame:GetScale() or 1
    if scale == 0 then return x, y end

    return x / scale, y / scale
end

local function HookScaledMapCursor()
    if hookedCursorScale then return end

    local mapFrame = _G.WorldMapFrame
    local scrollContainer = mapFrame and mapFrame.ScrollContainer
    if not scrollContainer or not MapCanvasScrollControllerMixin or not MapCanvasScrollControllerMixin.GetCursorPosition then return end

    originalScrollContainerGetCursorPosition = scrollContainer.GetCursorPosition
    scrollContainer.GetCursorPosition = function(container)
        return GetScaledMapCursorPosition(container, mapFrame)
    end

    originalScrollContainerGetNormalizedCursorPosition = scrollContainer.GetNormalizedCursorPosition
    if originalScrollContainerGetNormalizedCursorPosition then
        scrollContainer.GetNormalizedCursorPosition = function(container)
            if MapCanvasScrollControllerMixin.GetNormalizedCursorPosition then
                return MapCanvasScrollControllerMixin.GetNormalizedCursorPosition(container)
            end

            local x, y = container:GetCursorPosition()
            if not x or not y then return x, y end

            local width = container.GetWidth and container:GetWidth() or 0
            local height = container.GetHeight and container:GetHeight() or 0
            if width == 0 or height == 0 then return nil, nil end

            return x / width, y / height
        end
    end

    originalWorldMapGetNormalizedCursorPosition = mapFrame.GetNormalizedCursorPosition
    if originalWorldMapGetNormalizedCursorPosition then
        mapFrame.GetNormalizedCursorPosition = function(frame)
            local container = frame.ScrollContainer
            if container and container.GetNormalizedCursorPosition then
                return container:GetNormalizedCursorPosition()
            end
            return originalWorldMapGetNormalizedCursorPosition(frame)
        end
    end

    hookedCursorScale = true
end

local function RestoreScaledMapCursor()
    local mapFrame = _G.WorldMapFrame
    local scrollContainer = mapFrame and mapFrame.ScrollContainer
    if scrollContainer and originalScrollContainerGetCursorPosition then
        scrollContainer.GetCursorPosition = originalScrollContainerGetCursorPosition
    end
    if scrollContainer and originalScrollContainerGetNormalizedCursorPosition then
        scrollContainer.GetNormalizedCursorPosition = originalScrollContainerGetNormalizedCursorPosition
    end
    if mapFrame and originalWorldMapGetNormalizedCursorPosition then
        mapFrame.GetNormalizedCursorPosition = originalWorldMapGetNormalizedCursorPosition
    end

    originalScrollContainerGetCursorPosition = nil
    originalScrollContainerGetNormalizedCursorPosition = nil
    originalWorldMapGetNormalizedCursorPosition = nil
    hookedCursorScale = false
end

local function HideMapBlackout()
    local mapFrame = _G.WorldMapFrame
    local blackout = mapFrame and mapFrame.BlackoutFrame
    if not blackout then return end

    if originalBlackoutAlpha == nil and blackout.GetAlpha then
        originalBlackoutAlpha = blackout:GetAlpha()
    end

    if blackout.SetAlpha then blackout:SetAlpha(0) end
    if blackout.Hide then blackout:Hide() end
end

local function RestoreMapBlackout()
    local mapFrame = _G.WorldMapFrame
    local blackout = mapFrame and mapFrame.BlackoutFrame
    if not blackout then return end

    if blackout.SetAlpha then blackout:SetAlpha(originalBlackoutAlpha or 1) end
    if IsMapFullscreen(mapFrame) and blackout.Show then blackout:Show() end
end

local function IsMouseOverMap(mapFrame)
    if not mapFrame then return false end
    if mapFrame.IsMouseOver then
        local ok, isMouseOver = pcall(mapFrame.IsMouseOver, mapFrame)
        if ok then return isMouseOver == true end
    end
    if MouseIsOver then
        local ok, isMouseOver = pcall(MouseIsOver, mapFrame)
        if ok then return isMouseOver == true end
    end
    return false
end

local function CaptureMapAlpha(mapFrame)
    if originalMapAlpha ~= nil or not mapFrame or not mapFrame.GetAlpha then return end
    originalMapAlpha = mapFrame:GetAlpha() or 1
end

local function GetRestingMapAlpha()
    return originalMapAlpha or 1
end

local function ApplyMovingMapFade(elapsed, immediate)
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not mapFrame.SetAlpha or not mapFrame.GetAlpha then return end

    CaptureMapAlpha(mapFrame)

    local desiredAlpha = GetRestingMapAlpha()
    if IsEnabled() then
        local moving = IsPlayerMoving and IsPlayerMoving()
        if moving and not IsMouseOverMap(mapFrame) then
            desiredAlpha = MOVING_MAP_ALPHA
        end
    end

    if immediate then
        mapFrame:SetAlpha(desiredAlpha)
        return
    end

    local currentAlpha = mapFrame:GetAlpha() or desiredAlpha
    local alphaDiff = desiredAlpha - currentAlpha
    if math.abs(alphaDiff) < 0.01 then
        mapFrame:SetAlpha(desiredAlpha)
        return
    end

    local progress = math.min(1, (elapsed or 0) / MAP_FADE_DURATION)
    if progress <= 0 then return end

    mapFrame:SetAlpha(currentAlpha + (alphaDiff * progress))
end

local function ApplyFullscreenMapLayout(mapFrame)
    if not IsMapFullscreen(mapFrame) then return false end

    CaptureFullscreenGeometry(mapFrame)
    HideMapBlackout()
    HookScaledMapCursor()

    mapFrame.CP_WorldMapCleanupApplying = true
    RestoreFullscreenSize(mapFrame)
    if mapFrame.ClearAllPoints and mapFrame.SetPoint and UIParent then
        mapFrame:ClearAllPoints()
        mapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if mapFrame.SetScale and (not mapFrame.GetScale or math.abs((mapFrame:GetScale() or 1) - FULLSCREEN_MAP_SCALE) > 0.001) then
        mapFrame:SetScale(FULLSCREEN_MAP_SCALE)
    end
    mapFrame.CP_WorldMapCleanupApplying = false
    return true
end

local function RestoreMapScale(mapFrame)
    if mapFrame and mapFrame.SetScale and originalMapScale then
        mapFrame:SetScale(originalMapScale)
    end
end

local function ApplySmallMapAnchor()
    local anchor = _G.WorldMapScreenAnchor
    if not anchor or not anchor.ClearAllPoints or not anchor.SetPoint then return false end

    CaptureSmallMapAnchor()
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LEATRIX_SMALL_MAP_X, LEATRIX_SMALL_MAP_Y)
    return true
end

local function ApplyMapPosition()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not mapFrame.ClearAllPoints or not mapFrame.SetPoint then return end

    CaptureMapAlpha(mapFrame)
    CaptureMapScale(mapFrame)

    if IsMapFullscreen(mapFrame) then
        CaptureFullscreenGeometry(mapFrame)
    else
        CaptureSmallMapAnchor()
    end

    if not IsEnabled() then return end

    if ApplyFullscreenMapLayout(mapFrame) then return end

    RestoreMapScale(mapFrame)
    ApplySmallMapAnchor()
end

local function RestoreMapPosition()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not mapFrame.ClearAllPoints or not mapFrame.SetPoint then return end
    if not originalScreenAnchorPoints and not originalFullscreenGeometry then
        RestoreMapBlackout()
        return
    end

    mapFrame.CP_WorldMapCleanupApplying = true

    if IsMapFullscreen(mapFrame) and originalFullscreenGeometry then
        RestoreFullscreenSize(mapFrame)
        RestoreFramePoints(mapFrame, originalFullscreenGeometry.points)
    elseif originalScreenAnchorPoints then
        RestoreFramePoints(_G.WorldMapScreenAnchor, originalScreenAnchorPoints)
    end

    RestoreMapScale(mapFrame)
    mapFrame.CP_WorldMapCleanupApplying = false
    RestoreMapBlackout()
    ApplyMovingMapFade(0, true)
end

local function IsClassicClient()
    return Carpenter and Carpenter.Client and Carpenter.Client.isClassic
end

local function IsDungeonPOI(kind)
    return kind == "Dungeon" or kind == "Raid" or kind == "Dunraid"
end

local function IsTravelPOI(kind)
    return kind == "FlightA" or kind == "FlightH" or kind == "FlightN" or
        kind == "TravelA" or kind == "TravelH" or kind == "TravelN"
end

local function ShouldShowPOI(kind)
    if IsDungeonPOI(kind) then return true end
    if kind == "FlightN" or kind == "TravelN" then return true end

    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Alliance" then
        return kind == "FlightA" or kind == "TravelA"
    elseif faction == "Horde" then
        return kind == "FlightH" or kind == "TravelH"
    end

    return false
end

local function IsPOIAvailableForClient(pinInfo)
    if pinInfo[10] == POI_TBC_ONLY then
        return Carpenter and Carpenter.Client and Carpenter.Client.isTBC
    end

    return true
end

local function GetWorldMapID()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return nil end

    if mapFrame.mapID then return mapFrame.mapID end

    if mapFrame.GetMapID then
        local mapID = mapFrame:GetMapID()
        if mapID then return mapID end
    end

    return nil
end

local function GetMapCanvasID(map)
    if not map then return nil end

    if map.GetMapID then
        local mapID = map:GetMapID()
        if mapID then return mapID end
    end

    return map.mapID
end

local function GetPOIMapID(map)
    return GetWorldMapID() or GetMapCanvasID(map)
end

local function GetMapCanvasCenterKey(mapFrame, scrollContainer, mapID)
    if not mapID or not scrollContainer then return nil end

    local width = scrollContainer.GetWidth and scrollContainer:GetWidth() or 0
    local height = scrollContainer.GetHeight and scrollContainer:GetHeight() or 0
    if width <= 0 or height <= 0 then return nil end

    local mode = IsMapFullscreen(mapFrame) and "fullscreen" or "windowed"
    return tostring(mapID) .. ":" .. mode .. ":" .. math.floor(width + 0.5) .. "x" .. math.floor(height + 0.5)
end

local function GetMapCanvasBaseScale(scrollContainer)
    if scrollContainer.zoomLevels and scrollContainer.zoomLevels[1] and scrollContainer.zoomLevels[1].scale then
        return scrollContainer.zoomLevels[1].scale
    end

    if scrollContainer.GetScaleForMinZoom then
        local ok, scale = pcall(scrollContainer.GetScaleForMinZoom, scrollContainer)
        if ok then return scale end
    end

    return nil
end

local function CenterMapCanvasForCurrentMap()
    local mapFrame = _G.WorldMapFrame
    local scrollContainer = mapFrame and mapFrame.ScrollContainer
    if not IsEnabled() or not mapFrame or not scrollContainer then return end

    local mapID = GetWorldMapID()
    local centerKey = GetMapCanvasCenterKey(mapFrame, scrollContainer, mapID)
    if not centerKey or centeredMapCanvasKey == centerKey then return end

    local baseScale = GetMapCanvasBaseScale(scrollContainer)
    if baseScale and scrollContainer.InstantPanAndZoom then
        local ok = pcall(scrollContainer.InstantPanAndZoom, scrollContainer, baseScale, 0.5, 0.5, true)
        if not ok then return end
    elseif scrollContainer.SetPanTarget then
        pcall(scrollContainer.SetPanTarget, scrollContainer, 0.5, 0.5)
    else
        return
    end

    centeredMapCanvasKey = centerKey
end

local function BuildPOIName(pinInfo)
    local name = pinInfo[4] or ""
    local minLevel = pinInfo[7]
    local maxLevel = pinInfo[8]

    if minLevel and maxLevel then
        if minLevel == maxLevel then
            name = name .. " (" .. maxLevel .. ")"
        else
            name = name .. " (" .. minLevel .. "-" .. maxLevel .. ")"
        end
    end

    return name
end

local function BuildPOIInfo(pinInfo)
    local kind = pinInfo[1]
    return {
        position = CreateVector2D(pinInfo[2] / 100, pinInfo[3] / 100),
        name = BuildPOIName(pinInfo),
        description = pinInfo[5],
        atlasName = pinInfo[6] or POI_ATLAS[kind],
        CPKind = kind,
        CPTargetMapID = pinInfo[9],
    }
end

local function GetPOIIconSize(kind)
    return POI_ICON_SIZES[kind] or 20
end

local function ApplyPOIIconVisuals(pin, info)
    local size = GetPOIIconSize(info.CPKind)
    local textures = { pin.Texture, pin.HighlightTexture }

    if pin.SetSize then pin:SetSize(size, size) end

    for _, texture in ipairs(textures) do
        if texture then
            if texture.SetAtlas and info.atlasName then
                pcall(texture.SetAtlas, texture, info.atlasName, false)
            end
            if texture.SetScale then texture:SetScale(1) end
            if texture.SetRotation then texture:SetRotation(0) end
            if texture.SetSize then texture:SetSize(size, size) end
        end
    end
end

local function EnsurePinMixin()
    if _G.CPWorldMapCleanupPinMixin then return true end
    if not BaseMapPoiPinMixin or not BaseMapPoiPinMixin.CreateSubPin then return false end

    _G.CPWorldMapCleanupPinMixin = BaseMapPoiPinMixin:CreateSubPin("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")

    function _G.CPWorldMapCleanupPinMixin:OnAcquired(info)
        self.CPWorldMapCleanupPin = true
        BaseMapPoiPinMixin.OnAcquired(self, info)
        self.CPKind = info.CPKind
        self.CPTargetMapID = info.CPTargetMapID

        ApplyPOIIconVisuals(self, info)
    end

    function _G.CPWorldMapCleanupPinMixin:OnMouseUp(button)
        if button == "LeftButton" and self.CPTargetMapID and _G.WorldMapFrame and _G.WorldMapFrame.SetMapID then
            _G.WorldMapFrame:SetMapID(self.CPTargetMapID)
        elseif button == "RightButton" and _G.WorldMapFrame and _G.WorldMapFrame.NavigateToParentMap then
            _G.WorldMapFrame:NavigateToParentMap()
        end
    end

    return true
end

local function RemovePOIPinsFromMap(map)
    if map and map.RemoveAllPinsByTemplate then
        pcall(map.RemoveAllPinsByTemplate, map, CUSTOM_PIN_TEMPLATE)
    end
end

local function RemovePOIPins()
    local mapFrame = _G.WorldMapFrame
    RemovePOIPinsFromMap(mapFrame)

    if customPOIProvider and customPOIProvider.GetMap then
        local providerMap = customPOIProvider:GetMap()
        if providerMap ~= mapFrame then
            RemovePOIPinsFromMap(providerMap)
        end
    end
end

local function EnsurePOIProvider()
    if customPOIProvider then return true end

    local mapFrame = _G.WorldMapFrame
    if not IsClassicClient() or not mapFrame or not mapFrame.AddDataProvider then return false end
    if not CreateFromMixins or not MapCanvasDataProviderMixin or not CreateVector2D then return false end
    if not EnsurePinMixin() then return false end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RefreshAllData()
        local map = self.GetMap and self:GetMap()
        RemovePOIPinsFromMap(map)
        if map ~= _G.WorldMapFrame then RemovePOIPinsFromMap(_G.WorldMapFrame) end

        if not IsEnabled() or not map then return end

        local pins = POI_DATA[GetPOIMapID(map)]
        if not pins then return end

        for _, pinInfo in ipairs(pins) do
            if IsPOIAvailableForClient(pinInfo) and ShouldShowPOI(pinInfo[1]) and POI_ATLAS[pinInfo[1]] then
                pcall(map.AcquirePin, map, CUSTOM_PIN_TEMPLATE, BuildPOIInfo(pinInfo))
            end
        end
    end

    mapFrame:AddDataProvider(provider)
    customPOIProvider = provider
    return true
end

local function ApplyPOIPins()
    if not IsEnabled() then
        RemovePOIPins()
        return
    end

    if EnsurePOIProvider() and customPOIProvider and customPOIProvider.RefreshAllData then
        customPOIProvider:RefreshAllData()
    end
end

local function StoreHiddenState(object)
    if hiddenMapObjects[object] then return end

    hiddenMapObjects[object] = {
        shown = object.IsShown and object:IsShown() or nil,
        alpha = object.GetAlpha and object:GetAlpha() or nil,
        mouseEnabled = object.IsMouseEnabled and object:IsMouseEnabled() or nil,
    }
end

local function HideMapObject(object)
    if not object then return end

    StoreHiddenState(object)
    if object.Hide then object:Hide() end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.EnableMouse then object:EnableMouse(false) end
end

local function RestoreMapObjects()
    for object, state in pairs(hiddenMapObjects) do
        if object then
            if object.SetAlpha then object:SetAlpha(state.alpha or 1) end
            if object.EnableMouse and state.mouseEnabled ~= nil then object:EnableMouse(state.mouseEnabled) end
            if object.Show and state.shown then
                object:Show()
            elseif object.Hide and state.shown == false then
                object:Hide()
            end
        end
    end
    hiddenMapObjects = {}
end

local function IsContinentMapID(mapID)
    return mapID == 1414 or mapID == 1415 or mapID == 1945 or mapID == 947 or
        mapID == 12 or mapID == 13 or mapID == 1467
end

local function TextureCoordsMatch(texture, a, b, c, d, e, f, g, h)
    if not texture or not texture.GetTexCoord then return false end

    local ta, tb, tc, td, te, tf, tg, th = texture:GetTexCoord()
    return math.abs((ta or 0) - a) < 0.0001 and
        math.abs((tb or 0) - b) < 0.0001 and
        math.abs((tc or 0) - c) < 0.0001 and
        math.abs((td or 0) - d) < 0.0001 and
        math.abs((te or 0) - e) < 0.0001 and
        math.abs((tf or 0) - f) < 0.0001 and
        math.abs((tg or 0) - g) < 0.0001 and
        math.abs((th or 0) - h) < 0.0001
end

local function TextureIsTownOrCity(texture)
    if not texture or not texture.GetTexture then return false end

    local textureID = texture:GetTexture()
    if textureID ~= 136441 and textureID ~= "Interface\\Minimap\\POIIcons" and textureID ~= "Interface\\MINIMAP\\POIIcons" then
        return false
    end

    return TextureCoordsMatch(texture, 0.5, 0, 0.5, 0.125, 0.625, 0, 0.625, 0.125) or
        TextureCoordsMatch(texture, 0.625, 0, 0.625, 0.125, 0.75, 0, 0.75, 0.125)
end

local function HideTownCityPin(pin)
    if not IsEnabled() or not pin or pin.CPWorldMapCleanupPin then return end
    if not IsContinentMapID(GetWorldMapID()) then return end

    if pin.Texture and TextureIsTownOrCity(pin.Texture) then
        HideMapObject(pin)
    end
end

local function HookTownCityPins()
    if hookedTownCityPins or not hooksecurefunc or not BaseMapPoiPinMixin then return end

    hooksecurefunc(BaseMapPoiPinMixin, "OnAcquired", function(pin)
        HideTownCityPin(pin)
    end)
    hookedTownCityPins = true
end

local function ApplyExistingTownCityPins()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame then return end

    if mapFrame.EnumerateAllPins then
        for pin in mapFrame:EnumerateAllPins() do
            HideTownCityPin(pin)
        end
    elseif mapFrame.EnumeratePinsByTemplate then
        for pin in mapFrame:EnumeratePinsByTemplate("BaseMapPoiPinTemplate") do
            HideTownCityPin(pin)
        end
    end
end

local function ApplyTownCityIcons()
    RestoreMapObjects()
    if not IsEnabled() or not _G.WorldMapFrame then return end

    HookTownCityPins()
    ApplyExistingTownCityPins()
end

local function CaptureGroupMemberPinSizes(pin)
    if originalGroupMemberPinSizes or not pin or not pin.dataProvider then return end
    if not pin.dataProvider.GetUnitPinSizesTable then return end

    local sizes = pin.dataProvider:GetUnitPinSizesTable()
    if not sizes then return end

    originalGroupMemberPinSizes = {
        party = sizes.party,
        raid = sizes.raid,
    }
end

local function SetGroupMemberPinTexture(pin)
    if not pin or not pin.SetPinTexture then return end

    pcall(pin.SetPinTexture, pin, "party", GROUP_MEMBER_PIN_TEXTURE)
    pcall(pin.SetPinTexture, pin, "raid", GROUP_MEMBER_PIN_TEXTURE)
end

local function HookGroupMemberPinAppearance(pin)
    if not pin or pin.CP_WorldMapCleanupGroupPinHooked or not hooksecurefunc then return end
    if not pin.UpdateAppearanceData then return end

    hooksecurefunc(pin, "UpdateAppearanceData", function(self)
        if IsEnabled() then SetGroupMemberPinTexture(self) end
    end)
    pin.CP_WorldMapCleanupGroupPinHooked = true
end

local function SetGroupMemberPinAppearance(pin, enabled)
    if not pin then return end

    if enabled then
        HookGroupMemberPinAppearance(pin)
        SetGroupMemberPinTexture(pin)
    end

    if pin.SetAppearanceField then
        pcall(pin.SetAppearanceField, pin, "party", "useClassColor", enabled == true)
        pcall(pin.SetAppearanceField, pin, "raid", "useClassColor", enabled == true)
    end

    if enabled and pin.SetAppearanceField then
        pcall(pin.SetAppearanceField, pin, "party", "sublevel", 0)
        pcall(pin.SetAppearanceField, pin, "raid", "sublevel", 0)
    end

    if pin.dataProvider and pin.dataProvider.GetUnitPinSizesTable then
        local sizes = pin.dataProvider:GetUnitPinSizesTable()
        if sizes then
            if enabled then
                CaptureGroupMemberPinSizes(pin)
                sizes.party = GROUP_MEMBER_PIN_SIZE
                sizes.raid = GROUP_MEMBER_PIN_SIZE
            elseif originalGroupMemberPinSizes then
                sizes.party = originalGroupMemberPinSizes.party
                sizes.raid = originalGroupMemberPinSizes.raid
            end
        end
    end

    if pin.UpdateShownUnits then pcall(pin.UpdateShownUnits, pin) end
    if pin.SynchronizePinSizes then pcall(pin.SynchronizePinSizes, pin) end
end

local function ForEachGroupMemberPin(callback)
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or not callback then return end

    if mapFrame.EnumeratePinsByTemplate then
        for pin in mapFrame:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
            callback(pin)
        end
    elseif mapFrame.EnumerateAllPins then
        for pin in mapFrame:EnumerateAllPins() do
            if pin and pin.SetAppearanceField and pin.dataProvider and pin.SynchronizePinSizes then
                callback(pin)
            end
        end
    end
end

local function ApplyGroupMemberPins()
    if not IsEnabled() then return end

    ForEachGroupMemberPin(function(pin)
        SetGroupMemberPinAppearance(pin, true)
    end)
end

local function RestoreGroupMemberPins()
    ForEachGroupMemberPin(function(pin)
        SetGroupMemberPinAppearance(pin, false)
    end)
    originalGroupMemberPinSizes = nil
end

local function HookGroupMemberPins()
    if hookedGroupMemberPins or not hooksecurefunc or not _G.GroupMembersPinMixin then return end
    if not _G.GroupMembersPinMixin.OnAcquired then return end

    hooksecurefunc(_G.GroupMembersPinMixin, "OnAcquired", function()
        ApplyGroupMemberPins()
    end)
    hookedGroupMemberPins = true
end

local function ApplyWorldMapCleanup()
    ApplyMapPosition()
    CenterMapCanvasForCurrentMap()
    ApplyTownCityIcons()
    HookGroupMemberPins()
    ApplyGroupMemberPins()
    ApplyPOIPins()
    ApplyMovingMapFade(0, false)
end

local function ApplyWorldMapCleanupImmediately()
    if IsEnabled() then ApplyWorldMapCleanup() end
end

frame:SetScript("OnUpdate", function(_, elapsed)
    local mapFrame = _G.WorldMapFrame
    if mapFrame and mapFrame.IsShown and mapFrame:IsShown() then
        ApplyMovingMapFade(elapsed, false)
    end
end)

local function ScheduleApply(delay)
    if Carpenter and Carpenter.Defer then
        scheduleNonce = scheduleNonce + 1
        Carpenter:Defer("WorldMapCleanup:apply:" .. scheduleNonce, delay or 0, ApplyWorldMapCleanup)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, ApplyWorldMapCleanup)
    else
        ApplyWorldMapCleanup()
    end
end

local function HookWorldMap()
    local mapFrame = _G.WorldMapFrame
    if hookedWorldMap or not mapFrame then return end

    EnsurePOIProvider()
    HookTownCityPins()

    if mapFrame.HookScript then
        mapFrame:HookScript("OnShow", function()
            ApplyWorldMapCleanupImmediately()
            ScheduleApply(0.15)
        end)
    end

    if mapFrame.BlackoutFrame and mapFrame.BlackoutFrame.HookScript then
        mapFrame.BlackoutFrame:HookScript("OnShow", function()
            if IsEnabled() then HideMapBlackout() end
        end)
    end

    if hooksecurefunc then
        if mapFrame.RefreshAllData then hooksecurefunc(mapFrame, "RefreshAllData", function() ScheduleApply(0) end) end
        if mapFrame.OnMapChanged then
            hooksecurefunc(mapFrame, "OnMapChanged", function()
                CenterMapCanvasForCurrentMap()
                ScheduleApply(0)
            end)
        end
        if mapFrame.Maximize then
            hooksecurefunc(mapFrame, "Maximize", function()
                ApplyWorldMapCleanupImmediately()
                ScheduleApply(0.1)
            end)
        end
        if mapFrame.Minimize then
            hooksecurefunc(mapFrame, "Minimize", function()
                ApplyWorldMapCleanupImmediately()
                ScheduleApply(0.1)
            end)
        end
        if mapFrame.SynchronizeDisplayState then
            hooksecurefunc(mapFrame, "SynchronizeDisplayState", function()
                ApplyWorldMapCleanupImmediately()
                ScheduleApply(0.1)
            end)
        end
    end

    hookedWorldMap = true
end

frame:SetScript("OnEvent", function(_, event, addOnName)
    if event == "ADDON_LOADED" and addOnName ~= "Blizzard_WorldMap" then return end

    HookWorldMap()
    ApplyWorldMapCleanupImmediately()
    ScheduleApply(0.2)
end)

local feature = {}

function feature:Enable()
    SafeRegisterEvent("ADDON_LOADED")
    SafeRegisterEvent("PLAYER_LOGIN")
    SafeRegisterEvent("PLAYER_ENTERING_WORLD")
    SafeRegisterEvent("PLAYER_LEVEL_UP")
    SafeRegisterEvent("PLAYER_STARTED_MOVING")
    SafeRegisterEvent("PLAYER_STOPPED_MOVING")
    SafeRegisterEvent("WORLD_MAP_UPDATE")
    SafeRegisterEvent("AREA_POIS_UPDATED")

    HookWorldMap()
    ApplyWorldMapCleanupImmediately()
    if Carpenter and Carpenter.DeferMany then
        Carpenter:DeferMany("WorldMapCleanup:startup", { 0.2, 1, 3 }, ApplyWorldMapCleanup)
    else
        ScheduleApply(0.2)
        ScheduleApply(1)
        ScheduleApply(3)
    end
end

function feature:Disable()
    frame:UnregisterAllEvents()
    centeredMapCanvasKey = nil
    RestoreGroupMemberPins()
    RestoreMapObjects()
    RemovePOIPins()
    RestoreScaledMapCursor()
    RestoreMapPosition()
    ApplyMovingMapFade(0, true)
end

function Carpenter_ApplyWorldMapCleanup()
    HookWorldMap()
    if IsEnabled() then
        ApplyWorldMapCleanup()
    else
        centeredMapCanvasKey = nil
        RestoreGroupMemberPins()
        RestoreMapObjects()
        RemovePOIPins()
        RestoreScaledMapCursor()
        RestoreMapPosition()
        ApplyMovingMapFade(0, true)
    end
end

if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("worldMapCleanupEnabled", feature)
end
