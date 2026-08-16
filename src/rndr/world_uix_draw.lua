local WorldUIXDraw = {}
WorldUIXDraw.__index = WorldUIXDraw

local IMAGE_ROOT = "assets/images/terrain"
local PANEL_X = 24
local PANEL_WIDTH = 430
local PANEL_HEIGHT = 144
local PANEL_MARGIN_BOTTOM = 24
local IMAGE_SIZE = 112

function WorldUIXDraw.new(options)
    options = options or {}
    local self = setmetatable({}, WorldUIXDraw)
    self.virtualHeight = options.virtualHeight or 1080
    self.hoveredTerrain = nil
    self.images = {}
    return self
end

function WorldUIXDraw:setHoveredTerrain(terrain)
    self.hoveredTerrain = terrain
end

function WorldUIXDraw:_getTerrainImage(terrain)
    local image = self.images[terrain.id]
    if image then
        return image
    end
    local path = ("%s/%s.png"):format(IMAGE_ROOT, terrain.id)
    assert(love.filesystem.getInfo(path, "file"),
        ("Terrain image does not exist: %s"):format(path))
    image = love.graphics.newImage(path)
    image:setFilter("linear", "linear")
    self.images[terrain.id] = image
    return image
end

function WorldUIXDraw:draw()
    local panelY = self.virtualHeight - PANEL_HEIGHT - PANEL_MARGIN_BOTTOM
    love.graphics.setColor(0.025, 0.035, 0.06, 0.94)
    love.graphics.rectangle("fill", PANEL_X, panelY, PANEL_WIDTH, PANEL_HEIGHT)
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.rectangle("line", PANEL_X + 0.5, panelY + 0.5,
        PANEL_WIDTH - 1, PANEL_HEIGHT - 1)

    local imageX = PANEL_X + 16
    local imageY = panelY + 16
    love.graphics.setColor(0.07, 0.09, 0.13, 1)
    love.graphics.rectangle("fill", imageX, imageY, IMAGE_SIZE, IMAGE_SIZE)

    local terrain = self.hoveredTerrain
    if terrain then
        local image = self:_getTerrainImage(terrain)
        local scale = math.min(
            IMAGE_SIZE / image:getWidth(),
            IMAGE_SIZE / image:getHeight()
        )
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, imageX + IMAGE_SIZE / 2,
            imageY + IMAGE_SIZE / 2, 0, scale, scale,
            image:getWidth() / 2, image:getHeight() / 2)
    end

    love.graphics.setColor(0.65, 0.74, 0.88, 1)
    love.graphics.print("TERRAIN", PANEL_X + 150, panelY + 30)
    love.graphics.setColor(0.94, 0.97, 1, 1)
    love.graphics.printf(terrain and terrain.name or "NO TERRAIN",
        PANEL_X + 150, panelY + 64, PANEL_WIDTH - 174, "left")
end

return WorldUIXDraw
