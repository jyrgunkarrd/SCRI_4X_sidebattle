local WorldOverlayDraw = {}
WorldOverlayDraw.__index = WorldOverlayDraw

local HALF_WIDTH = 46
local QUARTER_WIDTH = 23
local HALF_HEIGHT = 40

local function drawHex(centerX, centerY, mode)
    love.graphics.polygon(mode,
        centerX - HALF_WIDTH, centerY,
        centerX - QUARTER_WIDTH, centerY - HALF_HEIGHT,
        centerX + QUARTER_WIDTH, centerY - HALF_HEIGHT,
        centerX + HALF_WIDTH, centerY,
        centerX + QUARTER_WIDTH, centerY + HALF_HEIGHT,
        centerX - QUARTER_WIDTH, centerY + HALF_HEIGHT)
end

function WorldOverlayDraw.new(worldMoveSystem, axialToCenter, worldUnitDraw)
    local self = setmetatable({}, WorldOverlayDraw)
    self.worldMoveSystem = assert(worldMoveSystem, "World movement system is required")
    self.axialToCenter = assert(axialToCenter, "Axial conversion is required")
    self.worldUnitDraw = assert(worldUnitDraw, "World unit renderer is required")
    return self
end

function WorldOverlayDraw:drawPath(path)
    love.graphics.setLineWidth(6)
    love.graphics.setColor(0.88, 0.95, 1, 0.88)
    love.graphics.line(path.points)
    love.graphics.setLineWidth(1)
end

function WorldOverlayDraw:drawUnitGhost(preview)
    local centerX, centerY = self.axialToCenter(
        preview.destination.q,
        preview.destination.r
    )
    self.worldUnitDraw:drawGhost(preview.unit, centerX, centerY)
end

function WorldOverlayDraw:drawMovementRange()
    for _, hex in ipairs(self.worldMoveSystem:getReachableHexes()) do
        self:drawMovementHex(hex)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldOverlayDraw:drawMovementHex(hex)
    local centerX, centerY = self.axialToCenter(hex.q, hex.r)
    love.graphics.setColor(0.15, 0.58, 1, 0.28)
    drawHex(centerX, centerY, "fill")
    love.graphics.setColor(0.35, 0.78, 1, 0.72)
    drawHex(centerX, centerY, "line")
end

function WorldOverlayDraw:drawSelection()
    local selectedUnit = self.worldMoveSystem:getSelectedUnit()
    if selectedUnit then
        love.graphics.setColor(1, 0.84, 0.25, 0.95)
        drawHex(selectedUnit.centerX, selectedUnit.centerY, "line")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldOverlayDraw:draw()
    self:drawMovementRange()
    self:drawSelection()
end

return WorldOverlayDraw
