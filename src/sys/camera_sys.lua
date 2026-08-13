local CameraSystem = {}
CameraSystem.__index = CameraSystem

function CameraSystem.new(camera, mouse, keyboard, options)
    options = options or {}

    local self = setmetatable({}, CameraSystem)
    self.camera = assert(camera, "Camera is required")
    self.mouse = assert(mouse, "Mouse input is required")
    self.keyboard = assert(keyboard, "Keyboard input is required")
    self.panSpeed = options.panSpeed or 900
    self.zoomStep = options.zoomStep or 0.2
    self.verticalDragThreshold = options.verticalDragThreshold or 140
    self.verticalSmoothing = options.verticalSmoothing or 12
    self.fastPanMultiplier = options.fastPanMultiplier or 3.5
    self.verticalLevel = 3
    self.verticalTargetY = nil
    self.verticalDrag = 0
    self.outputScale = 1
    self.outputOffsetX = 0
    self.outputOffsetY = 0
    return self
end

function CameraSystem:_levelY(level)
    return self.camera:getMaximumY() * (level - 1) / 2
end

function CameraSystem:_nearestVerticalLevel()
    local maximumY = self.camera:getMaximumY()
    if maximumY <= 0.001 then
        return self.verticalLevel
    end

    local normalized = self.camera.y / maximumY
    return math.max(1, math.min(3, math.floor(normalized * 2 + 1.5)))
end

function CameraSystem:_stepVertical(direction)
    if direction == 0 or self.camera:getMaximumY() <= 0.001 then
        return
    end

    local baseLevel = self.verticalTargetY
        and self.verticalLevel
        or self:_nearestVerticalLevel()
    self.verticalLevel = math.max(1, math.min(3, baseLevel + direction))
    self.verticalTargetY = self:_levelY(self.verticalLevel)
end

function CameraSystem:keypressed(key, isRepeat)
    if isRepeat then
        return
    end

    local shiftDown = self.keyboard:isShiftDown()
    if shiftDown and (key == "w" or key == "up") then
        self.verticalLevel = 1
        self.verticalTargetY = nil
        self.camera:setY(self:_levelY(1))
        return
    elseif shiftDown and (key == "s" or key == "down") then
        self.verticalLevel = 3
        self.verticalTargetY = nil
        self.camera:setY(self:_levelY(3))
        return
    elseif key == "q" then
        self.camera:setX(0)
        return
    elseif key == "e" then
        self.camera:setX(self.camera:getMaximumX())
        return
    end

    self.keyboard:keypressed(key, isRepeat)
end

function CameraSystem:setOutputTransform(scale, offsetX, offsetY)
    self.outputScale = math.max(scale or 1, 0.001)
    self.outputOffsetX = offsetX or 0
    self.outputOffsetY = offsetY or 0
end

function CameraSystem:update(dt)
    local moveX = self.keyboard:getHorizontalMovement()
    local worldPanSpeed = self.panSpeed / self.camera.zoom
    if self.keyboard:isShiftDown() then
        worldPanSpeed = worldPanSpeed * self.fastPanMultiplier
    end
    self.camera:move(moveX * worldPanSpeed * dt, 0)

    local keyboardStep = self.keyboard:consumeVerticalStep()
    if keyboardStep ~= 0 then
        self:_stepVertical(keyboardStep < 0 and -1 or 1)
    end

    local dragX, dragY = self.mouse:consumeDrag()
    local dragScale = self.outputScale * self.camera.zoom
    self.camera:move(-dragX / dragScale, 0)

    self.verticalDrag = self.verticalDrag + dragY
    if math.abs(self.verticalDrag) >= self.verticalDragThreshold then
        -- Dragging the scene downward reveals the upper arena; dragging it
        -- upward reveals the lower arena.
        self:_stepVertical(self.verticalDrag > 0 and -1 or 1)
        self.verticalDrag = 0
    elseif not self.mouse:isLeftButtonDown() then
        self.verticalDrag = 0
    end

    local _wheelX, wheelY = self.mouse:consumeWheel()
    if wheelY ~= 0 then
        self.verticalLevel = self:_nearestVerticalLevel()
        local mouseX, mouseY = self.mouse:getPosition()
        local anchorX = (mouseX - self.outputOffsetX) / self.outputScale
        anchorX = math.max(0, math.min(anchorX, self.camera.viewportWidth))
        self.camera:setZoom(
            self.camera.zoom + wheelY * self.zoomStep,
            anchorX,
            self.camera.viewportHeight
        )
        self.verticalTargetY = self:_levelY(self.verticalLevel)
    end

    if self.verticalTargetY then
        self.verticalTargetY = self:_levelY(self.verticalLevel)
        local blend = 1 - math.exp(-self.verticalSmoothing * dt)
        local nextY = self.camera.y
            + (self.verticalTargetY - self.camera.y) * blend

        if math.abs(self.verticalTargetY - nextY) < 0.05 then
            nextY = self.verticalTargetY
            self.verticalTargetY = nil
        end
        self.camera:setY(nextY)
    end
end

return CameraSystem
