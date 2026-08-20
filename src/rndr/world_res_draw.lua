local WorldResourceDraw = {}
WorldResourceDraw.__index = WorldResourceDraw

local IMAGE_ROOT = "assets/images/resources"
local TILE_SIZE = 96
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54

function WorldResourceDraw.new(worldResourceSystem)
    local self = setmetatable({}, WorldResourceDraw)
    self.resources = assert(worldResourceSystem,
        "World resource system is required"):getResources()
    self.images = {}
    self.imageData = {}

    for _, resource in ipairs(self.resources) do
        if not self.images[resource.id] then
            local path = ("%s/%s.png"):format(IMAGE_ROOT, resource.id)
            assert(love.filesystem.getInfo(path, "file"),
                ("World resource image does not exist: %s"):format(path))
            local image = love.graphics.newImage(path)
            image:setFilter("nearest", "nearest")
            assert(image:getWidth() == TILE_SIZE and image:getHeight() == TILE_SIZE,
                ("World resource image must be %dx%d: %s"):format(
                    TILE_SIZE, TILE_SIZE, path))
            self.images[resource.id] = image
            self.imageData[resource.id] = love.image.newImageData(path)
        end
    end
    return self
end

function WorldResourceDraw:containsPoint(resource, worldX, worldY)
    if not resource then
        return false
    end
    local pixelX = math.floor(worldX - resource.centerX + TILE_CENTER_X)
    local pixelY = math.floor(worldY - resource.centerY + TILE_CENTER_Y)
    if pixelX < 0 or pixelY < 0
        or pixelX >= TILE_SIZE or pixelY >= TILE_SIZE then
        return false
    end
    local _, _, _, alpha = self.imageData[resource.id]:getPixel(pixelX, pixelY)
    return alpha > 0
end

function WorldResourceDraw:getResourceAtPoint(worldX, worldY)
    for index = #self.resources, 1, -1 do
        local resource = self.resources[index]
        if self:containsPoint(resource, worldX, worldY) then
            return resource
        end
    end
    return nil
end

function WorldResourceDraw:draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, resource in ipairs(self.resources) do
        love.graphics.draw(
            self.images[resource.id],
            resource.centerX - TILE_CENTER_X,
            resource.centerY - TILE_CENTER_Y
        )
    end
end

return WorldResourceDraw
