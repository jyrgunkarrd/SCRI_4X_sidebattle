local MapDemo = {}
MapDemo.__index = MapDemo

MapDemo.name = "map-demo"

local VIRTUAL_WIDTH = 1920
local VIRTUAL_HEIGHT = 1080
local TILE_DIRECTORY = "assets/images/maptiles/hex_bases/green_water"
local TILE_WIDTH = 96
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54
local HEX_STEP_X = 72
local HEX_STEP_Y = 84
local HEX_STAGGER_Y = 42

local CLUSTER = {
    { q = 0, r = 0, tile = "PH2_FjordSummerWater_00.png" },
    { q = 1, r = 0, tile = "PH2_FjordSummerWater_01.png" },
    { q = 1, r = -1, tile = "PH2_FjordSummerWater_02.png" },
    { q = 0, r = -1, tile = "PH2_FjordSummerWater_03.png" },
    { q = -1, r = 0, tile = "PH2_FjordSummerWater_04.png" },
    { q = -1, r = 1, tile = "PH2_FjordSummerWater_05.png" },
    { q = 0, r = 1, tile = "PH2_FjordSummerWater_06.png" },
}

local function axialToCenter(q, r)
    return VIRTUAL_WIDTH / 2 + q * HEX_STEP_X,
        VIRTUAL_HEIGHT / 2 + r * HEX_STEP_Y + q * HEX_STAGGER_Y
end

local function tileDrawOrder(left, right)
    if left.centerY ~= right.centerY then
        return left.centerY < right.centerY
    end
    return left.centerX < right.centerX
end

function MapDemo.new()
    return setmetatable({}, MapDemo)
end

function MapDemo:enter()
    self.canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.canvas:setFilter("nearest", "nearest")
    self.tiles = {}

    for _, entry in ipairs(CLUSTER) do
        local path = ("%s/%s"):format(TILE_DIRECTORY, entry.tile)
        assert(
            love.filesystem.getInfo(path, "file"),
            ("Map tile does not exist: %s"):format(path)
        )

        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        assert(
            image:getWidth() == TILE_WIDTH and image:getHeight() == TILE_WIDTH,
            ("Map tile must be %dx%d: %s"):format(
                TILE_WIDTH,
                TILE_WIDTH,
                path
            )
        )

        local centerX, centerY = axialToCenter(entry.q, entry.r)
        self.tiles[#self.tiles + 1] = {
            image = image,
            centerX = centerX,
            centerY = centerY,
            drawX = centerX - TILE_CENTER_X,
            drawY = centerY - TILE_CENTER_Y,
        }
    end

    table.sort(self.tiles, tileDrawOrder)
end

function MapDemo:draw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0.025, 0.035, 0.055, 1)
    love.graphics.setColor(1, 1, 1, 1)
    for _, tile in ipairs(self.tiles) do
        love.graphics.draw(tile.image, tile.drawX, tile.drawY)
    end
    love.graphics.setCanvas()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local scale = math.min(
        windowWidth / VIRTUAL_WIDTH,
        windowHeight / VIRTUAL_HEIGHT
    )
    local drawWidth = VIRTUAL_WIDTH * scale
    local drawHeight = VIRTUAL_HEIGHT * scale
    local offsetX = math.floor((windowWidth - drawWidth) / 2)
    local offsetY = math.floor((windowHeight - drawHeight) / 2)

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, offsetX, offsetY, 0, scale, scale)
end

function MapDemo:keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

return MapDemo
