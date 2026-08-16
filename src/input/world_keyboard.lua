local WorldKeyboard = {}
WorldKeyboard.__index = WorldKeyboard

function WorldKeyboard.new()
    return setmetatable({}, WorldKeyboard)
end

function WorldKeyboard:getMovement()
    local x, y = 0, 0
    if love.keyboard.isDown("a", "left") then x = x - 1 end
    if love.keyboard.isDown("d", "right") then x = x + 1 end
    if love.keyboard.isDown("w", "up") then y = y - 1 end
    if love.keyboard.isDown("s", "down") then y = y + 1 end

    if x ~= 0 and y ~= 0 then
        local diagonal = 1 / math.sqrt(2)
        x, y = x * diagonal, y * diagonal
    end
    return x, y
end

return WorldKeyboard
