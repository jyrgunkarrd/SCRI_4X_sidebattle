local ArenaOverlays = {}
ArenaOverlays.__index = ArenaOverlays

local BRIGHTNESS_SHADER = [[
extern number brightness;

vec4 effect(vec4 vertexColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates)
{
    vec4 pixel = Texel(texture, textureCoordinates) * vertexColor;
    pixel.rgb *= brightness;
    return pixel;
}
]]

local STATUS_FLASH_SHADER = [[
extern vec3 flashColor;
extern number flashAmount;
extern number statusBrightness;

vec4 effect(vec4 vertexColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates)
{
    vec4 pixel = Texel(texture, textureCoordinates) * vertexColor;
    pixel.rgb = mix(pixel.rgb, flashColor, flashAmount);
    pixel.rgb *= statusBrightness;
    return pixel;
}
]]

function ArenaOverlays.new(options)
    options = options or {}

    local self = setmetatable({}, ArenaOverlays)
    self.cellDimBrightness = options.cellDimBrightness or 0.45
    self.brightnessShader = love.graphics.newShader(BRIGHTNESS_SHADER)
    self.statusFlashShader = love.graphics.newShader(STATUS_FLASH_SHADER)
    self.animationTime = 0
    return self
end

function ArenaOverlays:update(dt)
    self.animationTime = self.animationTime + dt
end

function ArenaOverlays:beginUnitDim()
    self.brightnessShader:send("brightness", self.cellDimBrightness)
    love.graphics.setShader(self.brightnessShader)
end

function ArenaOverlays:endUnitDim()
    love.graphics.setShader()
end

function ArenaOverlays:beginUnitStatus(unit, enemyArenaSystem, dimmed)
    local color
    if enemyArenaSystem:isFlanking(unit) then
        color = { 0x2e / 255, 0xff / 255, 0xb9 / 255 }
    elseif enemyArenaSystem:isFlanked(unit) then
        color = { 0xff / 255, 0x42 / 255, 0x42 / 255 }
    else
        return false
    end

    local pulse = 0.18 + 0.32
        * (0.5 + 0.5 * math.sin(self.animationTime * 3.5))
    self.statusFlashShader:send("flashColor", color)
    self.statusFlashShader:send("flashAmount", pulse)
    self.statusFlashShader:send(
        "statusBrightness",
        dimmed and self.cellDimBrightness or 1
    )
    love.graphics.setShader(self.statusFlashShader)
    return true
end

function ArenaOverlays:endUnitStatus()
    love.graphics.setShader()
end

function ArenaOverlays:_cellRect(grid, destination)
    local x = grid.x + (destination.targW - 1) * grid.cellSize
    local visualRow = grid.rows - destination.targH
    local y = grid.y + visualRow * grid.cellSize
    return x, y, grid.cellSize
end

function ArenaOverlays:drawMovement(movementSystem, unitDraw)
    local selectedUnit = movementSystem.selectedUnit
    if not selectedUnit then
        return
    end

    local grid = movementSystem.grid
    local hoveredDestination = movementSystem:getHoveredDestination()

    for _, destination in ipairs(movementSystem:getDestinations()) do
        local x, y, size = self:_cellRect(grid, destination)
        local isHovered = destination == hoveredDestination

        love.graphics.setColor(
            destination.requiresEngagement and 0.9 or (isHovered and 0.28 or 0.16),
            destination.requiresEngagement and 0.42 or (isHovered and 0.72 or 0.55),
            destination.requiresEngagement and 0.2 or 1,
            isHovered and 0.24 or 0.14
        )
        love.graphics.rectangle("fill", x, y, size, size)
    end

    if hoveredDestination then
        local selectedImage, selectedX, selectedY, selectedScale = unitDraw:getUnitVisualAt(
            selectedUnit,
            selectedUnit.targW,
            selectedUnit.targH
        )
        local engagementTarget = movementSystem:getHoveredEngagement()
        local previewsFlank = engagementTarget
            and movementSystem.enemyArenaSystem:isOccupied(engagementTarget)
        local ghostCellOffset
        if previewsFlank then
            ghostCellOffset = grid.cellSize / 4
        elseif #hoveredDestination.enemies > 0 then
            ghostCellOffset = -grid.cellSize / 4
        end
        local ghostImage, ghostX, ghostY, ghostScale = unitDraw:getUnitVisualAt(
            selectedUnit,
            hoveredDestination.targW,
            hoveredDestination.targH,
            nil,
            nil,
            ghostCellOffset
        )
        local selectedCenterY = selectedY
            - selectedImage:getHeight() * selectedScale / 2
        local ghostCenterY = ghostY - ghostImage:getHeight() * ghostScale / 2
        local ghostFacing = hoveredDestination.targW < selectedUnit.targW
            and "left"
            or "right"
        local ghostScaleX = ghostScale
            * unitDraw:getFacingSign(selectedUnit, ghostFacing)

        love.graphics.setColor(0.35, 0.82, 1, 0.8)
        love.graphics.setLineWidth(5)
        love.graphics.line(selectedX, selectedCenterY, ghostX, ghostCenterY)

        love.graphics.setColor(0.72, 0.9, 1, 0.42)
        love.graphics.draw(
            ghostImage,
            ghostX,
            ghostY,
            0,
            ghostScaleX,
            ghostScale,
            ghostImage:getWidth() / 2,
            ghostImage:getHeight()
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ArenaOverlays:drawEngagementCapacity(movementSystem, unitDraw, camera)
    local enemy = movementSystem:getHoveredEngagement()
    if not enemy then
        return
    end

    local enemyArenaSystem = movementSystem.enemyArenaSystem
    local size = enemyArenaSystem:getSize(enemy)
    local engagedSize = math.min(size, enemyArenaSystem:getEngagedSize(enemy))
    local incomingSize = movementSystem.selectedUnit
        and enemyArenaSystem:getSize(movementSystem.selectedUnit)
        or 0
    local previewSize = math.min(size, engagedSize + incomingSize)
    local occupied = enemyArenaSystem:isOccupied(enemy)
    local left, top, right = unitDraw:getUnitBounds(enemy)
    local centerX, screenTop = camera:worldToScreen((left + right) / 2, top)
    local pipSize = 12
    local gap = 4
    local totalWidth = size * pipSize + (size - 1) * gap
    local startX = centerX - totalWidth / 2
    local y = screenTop - pipSize - 14
    local flashAlpha = 0.35 + 0.65
        * (0.5 + 0.5 * math.sin(self.animationTime * 9))

    for index = 1, size do
        local x = math.floor(startX + (index - 1) * (pipSize + gap) + 0.5)
        local drawY = math.floor(y + 0.5)
        love.graphics.setColor(0.8, 0.9, 1, 0.95)
        love.graphics.rectangle("fill", x, drawY, pipSize, pipSize)

        love.graphics.setColor(0.025, 0.035, 0.055, 0.95)
        love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)

        if index <= engagedSize then
            love.graphics.setColor(
                occupied and 0.3 or 0.96,
                occupied and 0.86 or 0.56,
                occupied and 0.46 or 0.2,
                1
            )
            love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)
        elseif index <= previewSize then
            love.graphics.setColor(1, 0.58, 0.18, flashAlpha)
            love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaOverlays
