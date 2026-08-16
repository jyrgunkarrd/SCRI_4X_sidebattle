local TerrainDefinitions = require("data.terrain")

local WorldTerrainSystem = {}
WorldTerrainSystem.__index = WorldTerrainSystem

local function hexKey(q, r)
    return q .. ":" .. r
end

function WorldTerrainSystem.new(map)
    assert(type(map) == "table", "World map data is required")
    local self = setmetatable({}, WorldTerrainSystem)
    self.definitionsById = {}
    self.paintedHexes = {}
    self.terrainByHex = {}

    for _, definition in ipairs(TerrainDefinitions) do
        assert(type(definition.id) == "string" and definition.id ~= "",
            "Terrain definition is missing a valid id")
        assert(not self.definitionsById[definition.id],
            ("Duplicate terrain id '%s'"):format(definition.id))
        self.definitionsById[definition.id] = definition
    end

    local mapName = map.name
    assert(type(mapName) == "string" and mapName ~= "",
        "World map is missing its name")
    self.defaultTerrainId = "flat_" .. mapName
    assert(self.definitionsById[self.defaultTerrainId],
        ("Missing default terrain definition '%s'"):format(
            self.defaultTerrainId))

    for _, tile in ipairs(map.tiles or {}) do
        if tile.layer == "base" then
            self.paintedHexes[hexKey(tile.q, tile.r)] = true
        end
    end

    for _, marker in ipairs(map.markers or {}) do
        if marker.type == "terrain" then
            assert(type(marker.q) == "number" and type(marker.r) == "number",
                ("Terrain marker '%s' is missing valid axial coordinates")
                    :format(tostring(marker.value)))
            local definition = self.definitionsById[marker.value]
            assert(definition,
                ("World map references unknown terrain id '%s'"):format(
                    tostring(marker.value)))
            local key = hexKey(marker.q, marker.r)
            assert(not self.terrainByHex[key],
                ("World map contains multiple terrain markers at %s"):format(key))
            self.terrainByHex[key] = definition
        end
    end
    return self
end

function WorldTerrainSystem:get(q, r)
    local key = hexKey(q, r)
    if not self.paintedHexes[key] then
        return nil
    end
    return self.terrainByHex[key]
        or self.definitionsById[self.defaultTerrainId]
end

return WorldTerrainSystem
