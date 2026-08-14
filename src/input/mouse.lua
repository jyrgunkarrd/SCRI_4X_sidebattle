local Mouse = {}
Mouse.__index = Mouse

function Mouse.new(options)
    options = options or {}

    local self = setmetatable({}, Mouse)
    self.x, self.y = love.mouse.getPosition()
    self.wheelX = 0
    self.wheelY = 0
    self.dragX = 0
    self.dragY = 0
    self.leftDown = false
    self.isDragging = false
    self.dragThreshold = options.dragThreshold or 6
    self.pressX = 0
    self.pressY = 0
    self.pendingClick = nil
    return self
end

function Mouse:pressed(x, y, button)
    self.x, self.y = x, y
    if button == 1 then
        self.leftDown = true
        self.isDragging = false
        self.pressX = x
        self.pressY = y
        self.dragX = 0
        self.dragY = 0
    end
end

function Mouse:released(x, y, button)
    self.x, self.y = x, y
    if button == 1 then
        if self.leftDown and not self.isDragging then
            self.pendingClick = { x = x, y = y }
        end
        self.leftDown = false
        self.isDragging = false
    end
end

function Mouse:moved(x, y, dx, dy)
    self.x, self.y = x, y
    if not self.leftDown then
        return
    end

    if not self.isDragging then
        local totalX = x - self.pressX
        local totalY = y - self.pressY
        local thresholdSquared = self.dragThreshold * self.dragThreshold

        if totalX * totalX + totalY * totalY >= thresholdSquared then
            self.isDragging = true
            self.dragX = self.dragX + totalX
            self.dragY = self.dragY + totalY
        end
    else
        self.dragX = self.dragX + dx
        self.dragY = self.dragY + dy
    end
end

function Mouse:consumeClick()
    local click = self.pendingClick
    self.pendingClick = nil
    return click
end

function Mouse:getPosition()
    return self.x, self.y
end

function Mouse:isLeftButtonDown()
    return self.leftDown
end

function Mouse:wheelmoved(x, y)
    self.wheelX = self.wheelX + x
    self.wheelY = self.wheelY + y
end

function Mouse:consumeDrag()
    local x, y = self.dragX, self.dragY
    self.dragX = 0
    self.dragY = 0
    return x, y
end

function Mouse:consumeWheel()
    local x, y = self.wheelX, self.wheelY
    self.wheelX = 0
    self.wheelY = 0
    return x, y
end

function Mouse:clearInteraction()
    self.wheelX = 0
    self.wheelY = 0
    self.dragX = 0
    self.dragY = 0
    self.leftDown = false
    self.isDragging = false
    self.pendingClick = nil
end

return Mouse
