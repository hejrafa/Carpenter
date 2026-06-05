--[[ Carpenter - World Map Cleanup POI data ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Data = ns.Private.WorldMapCleanupData or {}
ns.Private.WorldMapCleanupData = Data

local TBC_ONLY = "tbc"

Data.TBCOnly = TBC_ONLY

Data.IconSizes = {
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

Data.Atlas = {
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

Data.POIs = {
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
        { "Raid", 46.9, 74.7, "Karazhan", "Raid", "Raid", 70, 70, nil, TBC_ONLY },
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
        { "FlightA", 38.2, 4, "Rebel Camp, Stranglethorn Vale", nil, "TaxiNode_Alliance", nil, nil, nil, TBC_ONLY },
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
        { "TravelA", 30.7, 41, "Boat to Valaar's Berth, Azuremyst Isle", nil, "TaxiNode_Alliance", nil, nil, 1943, TBC_ONLY },
    },
    [1440] = {
        { "Dungeon", 14.5, 14.2, "Blackfathom Deeps", "Dungeon", "Dungeon", 24, 32 },
        { "FlightA", 34.4, 48, "Astranaar, Ashenvale", nil, "TaxiNode_Alliance" },
        { "FlightA", 85, 43.4, "Forest Song, Ashenvale", nil, "TaxiNode_Alliance", nil, nil, nil, TBC_ONLY },
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
        { "FlightN", 42.8, 72.5, "Mudsprocket, Dustwallow Marsh", nil, "TaxiNode_Neutral", nil, nil, nil, TBC_ONLY },
        { "TravelA", 71.6, 56.4, "Boat to Menethil Harbor, Wetlands", nil, "TaxiNode_Alliance", nil, nil, 1437 },
    },
    [1446] = {
        { "Dungeon", 38.7, 20, "Zul'Farrak", "Dungeon", "Dungeon", 44, 54 },
        { "Dunraid", 65.7, 49.9, "Caverns of Time", "Black Morass, Hyjal Summit, Old Hillsbrad", "Dungeon", 66, 70, nil, TBC_ONLY },
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
        { "FlightN", 51.4, 82.2, "Emerald Sanctuary, Felwood", nil, "TaxiNode_Neutral", nil, nil, nil, TBC_ONLY },
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
        { "TravelH", 54.9, 11.3, "Silvermoon City", "Orb of Translocation", "TaxiNode_Horde", nil, nil, nil, TBC_ONLY },
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
        { "TravelH", 49.5, 14.8, "Undercity", "Orb of Translocation", "TaxiNode_Horde", nil, nil, 1458, TBC_ONLY },
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

function Data.IsDungeonKind(kind)
    return kind == "Dungeon" or kind == "Raid" or kind == "Dunraid"
end

function Data.IsTravelKind(kind)
    return kind == "FlightA" or kind == "FlightH" or kind == "FlightN" or
        kind == "TravelA" or kind == "TravelH" or kind == "TravelN"
end

function Data.ShouldShowKind(kind, faction)
    if Data.IsDungeonKind(kind) then return true end
    if kind == "FlightN" or kind == "TravelN" then return true end

    if faction == "Alliance" then
        return kind == "FlightA" or kind == "TravelA"
    elseif faction == "Horde" then
        return kind == "FlightH" or kind == "TravelH"
    end

    return false
end

function Data.IsPOIAvailableForClient(pinInfo, isTBC)
    if pinInfo[10] == TBC_ONLY then
        return isTBC == true
    end

    return true
end

function Data.BuildPOIName(pinInfo)
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

function Data.BuildPOIInfo(pinInfo)
    local kind = pinInfo[1]
    return {
        position = CreateVector2D(pinInfo[2] / 100, pinInfo[3] / 100),
        name = Data.BuildPOIName(pinInfo),
        description = pinInfo[5],
        atlasName = pinInfo[6] or Data.Atlas[kind],
        CPKind = kind,
        CPTargetMapID = pinInfo[9],
    }
end

function Data.GetIconSize(kind)
    return Data.IconSizes[kind] or 20
end
