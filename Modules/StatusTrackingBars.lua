--[[ Carpenter - shared status tracking bar discovery ]]
local _, ns = ...
ns = ns or {}
ns.Private = ns.Private or {}

local TrackingBars = ns.Private.StatusTrackingBars or {}
ns.Private.StatusTrackingBars = TrackingBars

local BAR_NAMES = {
    "MainMenuExpBar",
    "ReputationWatchBar",
}

local WATCH_BAR_NAMES = {
    "ArtifactWatchBar",
    "HonorWatchBar",
}

local CONTAINER_NAMES = {
    "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer",
}

local function AddObject(objects, seen, object)
    if not object or seen[object] then return end
    seen[object] = true
    objects[#objects + 1] = object
end

local function CollectObjects(includeWatchBars)
    local objects = {}
    local seen = {}

    for _, name in ipairs(BAR_NAMES) do
        AddObject(objects, seen, _G[name])
    end

    if includeWatchBars then
        for _, name in ipairs(WATCH_BAR_NAMES) do
            AddObject(objects, seen, _G[name])
        end
    end

    for _, name in ipairs(CONTAINER_NAMES) do
        local container = _G[name]
        if container then
            AddObject(objects, seen, container)
            AddObject(objects, seen, container.BarContainer)
            if type(container.bars) == "table" then
                for _, bar in ipairs(container.bars) do
                    AddObject(objects, seen, bar)
                end
            end
        end
    end

    return objects, seen
end

local function HasTrackedAncestor(object, trackedObjects)
    local current = object
    local depth = 0

    while current and current.GetParent and depth < 16 do
        local ok, parent = pcall(current.GetParent, current)
        if not ok or not parent then return false end
        if trackedObjects[parent] then return true end
        current = parent
        depth = depth + 1
    end

    return false
end

function TrackingBars.ForEach(callback, includeWatchBars)
    if type(callback) ~= "function" then return end
    local objects = CollectObjects(includeWatchBars)
    for _, object in ipairs(objects) do
        callback(object)
    end
end

function TrackingBars.ForEachRoot(callback, includeWatchBars)
    if type(callback) ~= "function" then return end
    local objects, trackedObjects = CollectObjects(includeWatchBars)
    for _, object in ipairs(objects) do
        if not HasTrackedAncestor(object, trackedObjects) then
            callback(object)
        end
    end
end

