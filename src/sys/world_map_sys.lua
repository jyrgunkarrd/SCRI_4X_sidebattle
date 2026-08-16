local SiteSystem = require("src.sys.site_sys")
local SiteDraw = require("src.rndr.site_draw")
local WorldUnitSystem = require("src.sys.world_unit_sys")
local WorldUnitDraw = require("src.rndr.world_unit_draw")
local WorldTerrainSystem = require("src.sys.world_terrain_sys")

local WorldMapSystem = {}
WorldMapSystem.__index = WorldMapSystem

local TILE_SIZE = 96
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54
local HEX_STEP_X = 72
local HEX_STEP_Y = 84
local HEX_STAGGER_Y = 42
local LAYER_ORDER = {
    base = 1,
    transition = 2,
    road = 3,
    river = 4,
    bridge = 5,
    overlay = 6,
}

local function axialToCenter(q, r)
    return q * HEX_STEP_X, r * HEX_STEP_Y + q * HEX_STAGGER_Y
end

local function roundAxial(fractionalQ, fractionalR)
    local cubeX = fractionalQ
    local cubeZ = fractionalR
    local cubeY = -cubeX - cubeZ
    local roundedX = math.floor(cubeX + 0.5)
    local roundedY = math.floor(cubeY + 0.5)
    local roundedZ = math.floor(cubeZ + 0.5)
    local differenceX = math.abs(roundedX - cubeX)
    local differenceY = math.abs(roundedY - cubeY)
    local differenceZ = math.abs(roundedZ - cubeZ)
    if differenceX > differenceY and differenceX > differenceZ then
        roundedX = -roundedY - roundedZ
    elseif differenceY > differenceZ then
        roundedY = -roundedX - roundedZ
    else
        roundedZ = -roundedX - roundedY
    end
    return roundedX, roundedZ
end

local function worldToAxial(worldX, worldY)
    local fractionalQ = worldX / HEX_STEP_X
    local fractionalR = worldY / HEX_STEP_Y - fractionalQ / 2
    return roundAxial(fractionalQ, fractionalR)
end

local function drawOrder(left, right)
    if left.layerOrder ~= right.layerOrder then
        return left.layerOrder < right.layerOrder
    end
    if left.centerY ~= right.centerY then
        return left.centerY < right.centerY
    end
    return left.centerX < right.centerX
end

local function loadImage(path)
    assert(love.filesystem.getInfo(path, "file"),
        ("World map image does not exist: %s"):format(path))
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function WorldMapSystem.new(worldDefinition)
    assert(type(worldDefinition) == "table", "World definition must be a table")
    assert(type(worldDefinition.mapid) == "string" and worldDefinition.mapid ~= "",
        "World definition is missing a valid mapid")

    local self = setmetatable({}, WorldMapSystem)
    self.worldDefinition = worldDefinition
    self.map = require("assets.world." .. worldDefinition.mapid)
    self.tiles = {}
    self:_loadTiles()
    self.siteSystem = SiteSystem.new(self.map.markers, axialToCenter)
    self.siteDraw = SiteDraw.new(self.siteSystem)
    self.worldUnitSystem = WorldUnitSystem.new(self.siteSystem)
    self.worldUnitDraw = WorldUnitDraw.new(self.worldUnitSystem)
    self.worldTerrainSystem = WorldTerrainSystem.new(self.map)
    return self
end

function WorldMapSystem:_loadTiles()
    local minimumX, maximumX, minimumY, maximumY
    for _, savedTile in ipairs(self.map.tiles or {}) do
        local layerOrder = LAYER_ORDER[savedTile.layer]
        assert(layerOrder, ("Unknown world map layer: %s"):format(
            tostring(savedTile.layer)))
        assert(type(savedTile.q) == "number" and type(savedTile.r) == "number",
            "World map tile is missing valid axial coordinates")
        assert(type(savedTile.path) == "string", "World map tile is missing its path")
        local image = loadImage(savedTile.path)
        assert(image:getWidth() == TILE_SIZE and image:getHeight() == TILE_SIZE,
            ("World map tile must be %dx%d: %s"):format(
                TILE_SIZE, TILE_SIZE, savedTile.path))
        local centerX, centerY = axialToCenter(savedTile.q, savedTile.r)
        self.tiles[#self.tiles + 1] = {
            image = image,
            layerOrder = layerOrder,
            centerX = centerX,
            centerY = centerY,
            drawX = centerX - TILE_CENTER_X,
            drawY = centerY - TILE_CENTER_Y,
        }
        local drawX = centerX - TILE_CENTER_X
        local drawY = centerY - TILE_CENTER_Y
        minimumX = minimumX and math.min(minimumX, drawX) or drawX
        maximumX = maximumX and math.max(maximumX, drawX + TILE_SIZE)
            or drawX + TILE_SIZE
        minimumY = minimumY and math.min(minimumY, drawY) or drawY
        maximumY = maximumY and math.max(maximumY, drawY + TILE_SIZE)
            or drawY + TILE_SIZE
    end
    assert(minimumX, "World map must contain at least one painted tile")
    self.tileBounds = {
        minimumX = minimumX,
        maximumX = maximumX,
        minimumY = minimumY,
        maximumY = maximumY,
    }
    table.sort(self.tiles, drawOrder)
end

function WorldMapSystem:getSite(id)
    return self.siteSystem:get(id)
end

function WorldMapSystem:getFocusPosition()
    local focusId = self.worldDefinition.foc_site
    assert(type(focusId) == "string" and focusId ~= "",
        "World definition is missing a valid foc_site")
    local site = self:getSite(focusId)
    assert(site, ("Focused site '%s' is not placed on the world map"):format(focusId))
    return site.centerX, site.centerY
end

function WorldMapSystem:getCameraBounds(buffer)
    buffer = math.max(0, buffer or 0)
    return {
        minimumX = self.tileBounds.minimumX - buffer,
        maximumX = self.tileBounds.maximumX + buffer,
        minimumY = self.tileBounds.minimumY - buffer,
        maximumY = self.tileBounds.maximumY + buffer,
    }
end

function WorldMapSystem:getTerrainAtWorldPosition(worldX, worldY)
    local q, r = worldToAxial(worldX, worldY)
    return self.worldTerrainSystem:get(q, r), q, r
end

function WorldMapSystem:update(dt)
    self.worldUnitDraw:update(dt)
end

function WorldMapSystem:draw(cameraX, cameraY, viewportWidth, viewportHeight)
    love.graphics.push()
    love.graphics.translate(
        math.floor(viewportWidth / 2 - cameraX),
        math.floor(viewportHeight / 2 - cameraY)
    )
    love.graphics.setColor(1, 1, 1, 1)
    for _, tile in ipairs(self.tiles) do
        love.graphics.draw(tile.image, tile.drawX, tile.drawY)
    end
    self.siteDraw:draw()
    self.worldUnitDraw:draw()
    love.graphics.pop()
end

return WorldMapSystem
