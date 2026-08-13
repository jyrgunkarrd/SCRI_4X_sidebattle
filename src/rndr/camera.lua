local Camera = {}
Camera.__index = Camera

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(value, maximum))
end

function Camera.new(options)
    options = options or {}

    local self = setmetatable({}, Camera)
    self.x = options.x or 0
    self.y = options.y or 0
    self.viewportWidth = options.viewportWidth or 1920
    self.viewportHeight = options.viewportHeight or 1080
    self.worldWidth = options.worldWidth or self.viewportWidth
    self.worldHeight = options.worldHeight or self.viewportHeight
    self.zoom = options.zoom or 1
    self.minimumZoom = options.minimumZoom or 1
    self.maximumZoom = options.maximumZoom or 3
    self.zoom = clamp(self.zoom, self.minimumZoom, self.maximumZoom)
    self:_clampPosition()

    return self
end

function Camera:_clampPosition()
    local maximumX = math.max(0, self.worldWidth - self.viewportWidth / self.zoom)
    local maximumY = math.max(0, self.worldHeight - self.viewportHeight / self.zoom)
    self.x = clamp(self.x, 0, maximumX)
    self.y = clamp(self.y, 0, maximumY)
end

function Camera:setZoom(zoom, anchorX, anchorY)
    anchorX = anchorX or self.viewportWidth / 2
    anchorY = anchorY or self.viewportHeight / 2
    local worldAnchorX = self.x + anchorX / self.zoom
    local worldAnchorY = self.y + anchorY / self.zoom

    self.zoom = clamp(zoom, self.minimumZoom, self.maximumZoom)
    self.x = worldAnchorX - anchorX / self.zoom
    self.y = worldAnchorY - anchorY / self.zoom
    self:_clampPosition()
end

function Camera:move(dx, dy)
    self.x = self.x + (dx or 0)
    self.y = self.y + (dy or 0)
    self:_clampPosition()
end

function Camera:getMaximumY()
    return math.max(0, self.worldHeight - self.viewportHeight / self.zoom)
end

function Camera:getMaximumX()
    return math.max(0, self.worldWidth - self.viewportWidth / self.zoom)
end

function Camera:setX(x)
    self.x = x
    self:_clampPosition()
end

function Camera:setY(y)
    self.y = y
    self:_clampPosition()
end

function Camera:setViewportSize(width, height, preserveBottom)
    local bottomEdge = self.y + self.viewportHeight / self.zoom

    self.viewportWidth = width or self.viewportWidth
    self.viewportHeight = height or self.viewportHeight

    if preserveBottom then
        self.y = bottomEdge - self.viewportHeight / self.zoom
    end

    self:_clampPosition()
end

function Camera:ensureWorldVerticalVisible(top, bottom, screenPadding)
    local worldPadding = (screenPadding or 0) / self.zoom
    local visibleTop = self.y + worldPadding
    local visibleBottom = self.y + self.viewportHeight / self.zoom - worldPadding

    if bottom > visibleBottom then
        self.y = self.y + (bottom - visibleBottom)
    elseif top < visibleTop then
        self.y = self.y - (visibleTop - top)
    end

    self:_clampPosition()
end

function Camera:screenToWorld(x, y)
    return self.x + x / self.zoom, self.y + y / self.zoom
end

function Camera:worldToScreen(x, y)
    return (x - self.x) * self.zoom, (y - self.y) * self.zoom
end

function Camera:attach()
    love.graphics.push()
    love.graphics.scale(self.zoom, self.zoom)
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:detach()
    love.graphics.pop()
end

return Camera
