local WorldUnitDraw = {}
WorldUnitDraw.__index = WorldUnitDraw

local IMAGE_ROOT = "assets/images/units"
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54
local PULSE_SPEED = math.pi

function WorldUnitDraw.new(worldUnitSystem)
    local self = setmetatable({}, WorldUnitDraw)
    self.units = assert(worldUnitSystem, "World unit system is required"):getUnits()
    self.images = {}
    self.pulseTime = 0
    for _, unit in ipairs(self.units) do
        if not self.images[unit.id] then
            local path = ("%s/%s_hex.png"):format(IMAGE_ROOT, unit.id)
            assert(love.filesystem.getInfo(path, "file"),
                ("World unit image does not exist: %s"):format(path))
            local image = love.graphics.newImage(path)
            image:setFilter("nearest", "nearest")
            self.images[unit.id] = image
        end
    end
    return self
end

function WorldUnitDraw:update(dt)
    self.pulseTime = self.pulseTime + dt
end

function WorldUnitDraw:draw()
    local alpha = (math.sin(self.pulseTime * PULSE_SPEED) + 1) / 2
    love.graphics.setColor(1, 1, 1, alpha)
    for _, unit in ipairs(self.units) do
        love.graphics.draw(
            self.images[unit.id],
            unit.centerX - TILE_CENTER_X,
            unit.centerY - TILE_CENTER_Y
        )
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return WorldUnitDraw
