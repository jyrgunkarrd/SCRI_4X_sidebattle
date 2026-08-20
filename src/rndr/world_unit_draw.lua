local WorldUnitDraw = {}
WorldUnitDraw.__index = WorldUnitDraw

local IMAGE_ROOT = "assets/images/units"
local FACTION_BACKGROUND_ROOT = "assets/images/fac_back"
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54
local PULSE_SPEED = math.pi

function WorldUnitDraw.new(worldUnitSystem)
    local self = setmetatable({}, WorldUnitDraw)
    self.units = assert(worldUnitSystem, "World unit system is required"):getUnits()
    self.images = {}
    self.factionBackgrounds = {}
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

function WorldUnitDraw:_getFactionBackground(faction)
    faction = faction or "neutral"
    if not self.factionBackgrounds[faction] then
        local path = ("%s/%s.png"):format(FACTION_BACKGROUND_ROOT, faction)
        assert(love.filesystem.getInfo(path, "file"),
            ("Unit faction background does not exist: %s"):format(path))
        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        self.factionBackgrounds[faction] = image
    end
    return self.factionBackgrounds[faction]
end

function WorldUnitDraw:_drawUnitLayers(unit, centerX, centerY)
    local drawX = centerX - TILE_CENTER_X
    local drawY = centerY - TILE_CENTER_Y
    love.graphics.draw(self:_getFactionBackground(unit.faction), drawX, drawY)
    love.graphics.draw(self.images[unit.id], drawX, drawY)
end

function WorldUnitDraw:update(dt)
    self.pulseTime = self.pulseTime + dt
end

function WorldUnitDraw:drawUnit(unit)
    local siteAlpha = (math.sin(self.pulseTime * PULSE_SPEED) + 1) / 2
    love.graphics.setColor(1, 1, 1, unit.siteId and siteAlpha or 1)
    self:_drawUnitLayers(unit, unit.centerX, unit.centerY)
end

function WorldUnitDraw:drawGhost(unit, centerX, centerY)
    love.graphics.setColor(1, 1, 1, 0.48)
    self:_drawUnitLayers(unit, centerX, centerY)
end

function WorldUnitDraw:draw()
    for _, unit in ipairs(self.units) do
        self:drawUnit(unit)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldUnitDraw:drawMovingUnits()
    for _, unit in ipairs(self.units) do
        if unit.isMoving and not unit.worldStackHidden then
            self:drawUnit(unit)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return WorldUnitDraw
