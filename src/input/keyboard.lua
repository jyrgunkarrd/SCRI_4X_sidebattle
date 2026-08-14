local Keyboard = {}
Keyboard.__index = Keyboard

function Keyboard.new()
    local self = setmetatable({}, Keyboard)
    self.verticalStep = 0
    return self
end

function Keyboard:isDown(...)
    return love.keyboard.isDown(...)
end

function Keyboard:getMovement()
    local x, y = 0, 0

    if self:isDown("a", "left") then x = x - 1 end
    if self:isDown("d", "right") then x = x + 1 end
    if self:isDown("w", "up") then y = y - 1 end
    if self:isDown("s", "down") then y = y + 1 end

    if x ~= 0 and y ~= 0 then
        local diagonal = 1 / math.sqrt(2)
        x, y = x * diagonal, y * diagonal
    end

    return x, y
end

function Keyboard:getHorizontalMovement()
    local x = 0
    if self:isDown("a", "left") then x = x - 1 end
    if self:isDown("d", "right") then x = x + 1 end
    return x
end

function Keyboard:isShiftDown()
    return self:isDown("lshift", "rshift")
end

function Keyboard:isControlDown()
    return self:isDown("lctrl", "rctrl")
end

function Keyboard:keypressed(key, isRepeat)
    if isRepeat then
        return
    end

    if key == "w" or key == "up" then
        self.verticalStep = self.verticalStep - 1
    elseif key == "s" or key == "down" then
        self.verticalStep = self.verticalStep + 1
    end
end

function Keyboard:consumeVerticalStep()
    local step = self.verticalStep
    self.verticalStep = 0
    return step
end

function Keyboard:clearInteraction()
    self.verticalStep = 0
end

return Keyboard
