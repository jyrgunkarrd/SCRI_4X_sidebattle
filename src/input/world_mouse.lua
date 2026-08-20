local WorldMouse = {}
WorldMouse.__index = WorldMouse

function WorldMouse.new()
    local self = setmetatable({}, WorldMouse)
    self.middleDown = false
    self.panX = 0
    self.panY = 0
    self.leftClicks = {}
    self.rightClicks = {}
    return self
end

function WorldMouse:mousepressed(x, y, button)
    if button == 1 then
        self.leftClicks[#self.leftClicks + 1] = { x = x, y = y }
    elseif button == 2 then
        self.rightClicks[#self.rightClicks + 1] = { x = x, y = y }
    elseif button == 3 then
        self.middleDown = true
    end
end

function WorldMouse:mousereleased(_x, _y, button)
    if button == 3 then
        self.middleDown = false
    end
end

function WorldMouse:mousemoved(_x, _y, dx, dy)
    if self.middleDown then
        self.panX = self.panX + dx
        self.panY = self.panY + dy
    end
end

function WorldMouse:consumePan()
    local x, y = self.panX, self.panY
    self.panX, self.panY = 0, 0
    return x, y
end

function WorldMouse:consumeLeftClicks()
    local clicks = self.leftClicks
    self.leftClicks = {}
    return clicks
end

function WorldMouse:consumeRightClicks()
    local clicks = self.rightClicks
    self.rightClicks = {}
    return clicks
end

return WorldMouse
