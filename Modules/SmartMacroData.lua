--[[ Carpenter - Smart Macro data ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Data = ns.Private.SmartMacroData or {}
ns.Private.SmartMacroData = Data

Data.Items = {
    Food = { name = "CarpenterFood", legacyName = "ClassicFood" },
    WellFed = { name = "CarpenterWellFed" },
    Water = { name = "CarpenterWater", legacyName = "ClassicWater" },
    Pot = { name = "CarpenterHP", legacyName = "ClassicHP" },
    Mana = { name = "CarpenterMana", legacyName = "ClassicMana" },
    Band = { name = "CarpenterBand", legacyName = "ClassicBand" },
}

Data.RetailItems = {
    Food = Data.Items.Food,
    WellFed = Data.Items.WellFed,
    Water = Data.Items.Water,
    Pot = Data.Items.Pot,
    Mana = Data.Items.Mana,
}

Data.InternalCategories = {
    Healthstone = true,
}

Data.ClassHealSpells = {
    RECUPERATE = 1248165,
    CRIMSON_VIAL = 185311,
}

Data.FoodNameHints = {
    "apple", "banana", "basilisk", "bean", "berry", "bleu", "bread", "brie", "brisket", "burger", "cake",
    "catfish", "cheese", "cherry", "chops", "clam", "clefthoof", "cod", "cookie", "cornbread", "crab",
    "dumpling", "egg", "fish", "fruit", "ham", "haunch", "jerky", "lobster", "mackerel", "meat", "mild",
    "morel", "muffin", "mushroom", "mutton", "omelet", "pie", "pork", "pumpkin", "quail", "ravager dog",
    "ribs", "roll", "salmon", "sausage", "serpent", "shank", "sharp", "snapper", "sporeling", "steak",
    "stew", "strudel", "talbuk", "tenderloin", "trout", "truffle", "tuber", "warp burger", "watermelon",
    "wolf", "yellowtail", "zesty",
}

Data.WaterNameHints = {
    "drink", "juice", "milk", "spring water", "water",
}

Data.TooltipKeywords = {
    use = { "use:", "benutzen:" },
    health = { "health", "gesundheit" },
    healthstone = { "healthstone", "gesundheitsstein" },
    mana = { "mana" },
    wellFed = { "well fed", "gut genährt", "gut genaehrt", "satt" },
    foodAndDrink = { "remain seated while", "sitzen bleiben" },
    conjured = { "conjured item", "conjured", "mana bun", "mana strudel", "mana biscuit", "mana cake", "mana pie", "herbeigezauberter gegenstand", "herbeigezaubert" },
}

-- Hard fallback for common Classic/TBC foods in case item info or tooltip text is sparse.
Data.KnownFoodIDs = {
    [117] = true, [414] = true, [422] = true, [787] = true, [1113] = true, [1114] = true, [1487] = true,
    [1707] = true, [2070] = true, [2287] = true, [2679] = true, [2680] = true, [2681] = true, [2682] = true,
    [2683] = true, [2684] = true, [2685] = true, [2687] = true, [2888] = true, [3662] = true, [3663] = true,
    [3664] = true, [3665] = true, [3666] = true, [3726] = true, [3727] = true, [3728] = true, [3729] = true,
    [3770] = true, [3771] = true, [4592] = true, [4593] = true, [4594] = true, [4599] = true, [4601] = true,
    [4602] = true, [4604] = true, [4605] = true, [4606] = true, [4607] = true, [4608] = true, [5472] = true,
    [5473] = true, [5474] = true, [5476] = true, [5477] = true, [5525] = true, [6038] = true, [6290] = true,
    [6316] = true, [6887] = true, [8364] = true, [8950] = true, [8952] = true, [8953] = true, [8957] = true,
    [9681] = true, [12209] = true, [12210] = true, [12213] = true, [12214] = true, [12215] = true, [12216] = true,
    [12217] = true, [12218] = true, [12224] = true, [13810] = true, [13927] = true, [13928] = true, [13929] = true,
    [13930] = true, [13931] = true, [13932] = true, [13933] = true, [13934] = true, [13935] = true, [16766] = true,
    [17119] = true, [17222] = true, [17406] = true, [18254] = true, [19304] = true, [19696] = true, [21023] = true,
    [21030] = true, [21031] = true, [21033] = true, [22324] = true, [22645] = true, [22895] = true, [23495] = true,
    [27635] = true, [27636] = true, [27651] = true, [27655] = true, [27656] = true, [27657] = true, [27658] = true,
    [27659] = true, [27660] = true, [27661] = true, [27662] = true, [27663] = true, [27664] = true, [27665] = true,
    [27666] = true, [27667] = true, [27668] = true, [27669] = true, [27671] = true, [27854] = true, [27855] = true,
    [27856] = true, [27857] = true, [28486] = true, [29393] = true, [29448] = true, [30458] = true, [31672] = true,
    [33052] = true, [33053] = true, [33872] = true, [34062] = true, [35563] = true, [35565] = true,
}

Data.KnownWaterIDs = {
    [159] = true, [1179] = true, [1205] = true, [1645] = true, [1708] = true, [2136] = true, [2288] = true,
    [3772] = true, [5350] = true, [8077] = true, [8078] = true, [8766] = true, [8079] = true, [10841] = true,
    [18300] = true, [22018] = true, [28399] = true, [29395] = true, [30703] = true, [32453] = true, [33444] = true,
}

Data.KnownConjuredFoodIDs = {
    [1113] = true, [1114] = true, [1487] = true, [8075] = true, [8076] = true, [22895] = true, [22019] = true,
    [34062] = true,
}

Data.KnownConjuredWaterIDs = {
    [5350] = true, [8077] = true, [8078] = true, [8079] = true, [10841] = true, [18300] = true, [22018] = true,
    [28399] = true, [30703] = true, [33312] = true,
}

Data.KnownHealthIDs = {
    [118] = true, [858] = true, [929] = true, [1710] = true, [3928] = true, [13446] = true, [22829] = true,
    [32947] = true, [43569] = true,
}

Data.KnownManaIDs = {
    [2455] = true, [3385] = true, [3827] = true, [6149] = true, [13443] = true, [22832] = true, [32948] = true,
    [43570] = true,
}

Data.KnownHealthstoneIDs = {
    [5509] = true, [5510] = true, [5511] = true, [5512] = true, [9421] = true, [19004] = true, [19005] = true,
    [19006] = true, [19007] = true, [19008] = true, [19009] = true, [19010] = true, [19011] = true, [19012] = true,
    [19013] = true, [22103] = true, [22104] = true, [22105] = true, [22106] = true, [22107] = true, [22108] = true,
}

Data.KnownBandageIDs = {
    [1251] = true, [2581] = true, [3530] = true, [3531] = true, [6450] = true, [6451] = true, [8544] = true,
    [8545] = true, [14529] = true, [14530] = true, [21990] = true, [21991] = true, [34721] = true, [34722] = true,
}

Data.ConsumableClassID = 0
Data.PotionSubclassID = 1
Data.FoodDrinkSubclassID = 5
Data.BandageSubclassID = 7
Data.TradeskillClassID = 7
Data.CookingSubclassID = 8
Data.MiscellaneousClassID = 15
Data.ReagentSubclassID = 1

function Data.IsRetail()
    return Carpenter and Carpenter.Client and Carpenter.Client.isRetail
end

function Data.GetActiveItems()
    return Data.IsRetail() and Data.RetailItems or Data.Items
end

function Data.GetScanCategories()
    local categories = {}
    for category in pairs(Data.GetActiveItems()) do
        categories[category] = true
    end
    for category in pairs(Data.InternalCategories) do
        categories[category] = true
    end
    return categories
end
