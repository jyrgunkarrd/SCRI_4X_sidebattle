local ArenaUIX = {}
ArenaUIX.__index = ArenaUIX

local function moveTowards(value, target, maximumDelta)
    if value < target then
        return math.min(value + maximumDelta, target)
    end
    return math.max(value - maximumDelta, target)
end

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

local function drawSizePips(unit, enemyArenaSystem, centerX, y, pipSize, gap)
    local size = enemyArenaSystem:getSize(unit)
    local isEnemy = enemyArenaSystem:isEnemy(unit)
    local occupied = isEnemy and enemyArenaSystem:isOccupied(unit)
    local filled = isEnemy
        and math.min(size, enemyArenaSystem:getEngagedSize(unit))
        or size
    local totalWidth = size * pipSize + (size - 1) * gap
    local startX = centerX - totalWidth / 2

    for index = 1, size do
        local x = math.floor(startX + (index - 1) * (pipSize + gap) + 0.5)
        local drawY = math.floor(y + 0.5)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", x, drawY, pipSize, pipSize)

        love.graphics.setColor(0.025, 0.035, 0.055, 0.95)
        love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)

        if index <= filled then
            if occupied then
                love.graphics.setColor(0.3, 0.86, 0.46, 1)
            elseif isEnemy then
                love.graphics.setColor(0.96, 0.56, 0.2, 1)
            else
                love.graphics.setColor(0.3, 0.7, 1, 1)
            end
            love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)
        end
    end
end

function ArenaUIX.new(options)
    options = options or {}

    local self = setmetatable({}, ArenaUIX)
    self.virtualWidth = options.virtualWidth or 1920
    self.virtualHeight = options.virtualHeight or 1080
    self.panelHeight = options.panelHeight or 240
    self.animationDuration = options.animationDuration or 0.24
    self.progress = 0
    self.targetProgress = 0
    self.selectedUnit = nil
    self.displayedUnit = nil
    return self
end

function ArenaUIX:setSelectedUnit(unit)
    self.selectedUnit = unit
    self.targetProgress = unit and 1 or 0

    if unit then
        self.displayedUnit = unit
    end
end

function ArenaUIX:update(dt)
    self.progress = moveTowards(
        self.progress,
        self.targetProgress,
        dt / self.animationDuration
    )

    if self.progress == 0 and not self.selectedUnit then
        self.displayedUnit = nil
    end
end

function ArenaUIX:isOpening()
    return self.targetProgress == 1 and self.progress < 1
end

function ArenaUIX:getVisiblePanelHeight()
    return self.panelHeight * smoothstep(self.progress)
end

function ArenaUIX:getArenaHeight()
    return self.virtualHeight - self:getVisiblePanelHeight()
end

function ArenaUIX:draw(unitDraw, enemyArenaSystem)
    if self.progress <= 0 then
        return
    end

    local panelY = self.virtualHeight - self:getVisiblePanelHeight()
    local width = self.virtualWidth
    local height = self.panelHeight

    love.graphics.setShader()
    love.graphics.setColor(0.055, 0.065, 0.095, 1)
    love.graphics.rectangle("fill", 0, panelY, width, height)

    love.graphics.setColor(0.32, 0.38, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, panelY, width, panelY)

    local margin = 20
    local portraitSize = math.min(height - margin * 2 - 32, 168)
    local portraitX = margin
    local portraitY = panelY + 16

    love.graphics.setColor(0.025, 0.03, 0.05, 1)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)
    love.graphics.setColor(0.3, 0.36, 0.48, 1)
    love.graphics.rectangle("line", portraitX, portraitY, portraitSize, portraitSize)

    if self.displayedUnit then
        local image = unitDraw:getPanelImage(self.displayedUnit.unitId)
        local padding = 12
        local availableSize = portraitSize - padding * 2
        local scale = math.min(
            availableSize / image:getWidth(),
            availableSize / image:getHeight()
        )
        local imageX = portraitX + portraitSize / 2
        local imageY = portraitY + (portraitSize + image:getHeight() * scale) / 2
        local scaleX = scale * unitDraw:getFacingSign(self.displayedUnit)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            image,
            imageX,
            imageY,
            0,
            scaleX,
            scale,
            image:getWidth() / 2,
            image:getHeight()
        )

        drawSizePips(
            self.displayedUnit,
            enemyArenaSystem,
            portraitX + portraitSize / 2,
            portraitY + portraitSize + 14,
            16,
            5
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaUIX
