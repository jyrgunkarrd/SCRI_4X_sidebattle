local StateController = {}
StateController.__index = StateController

function StateController.new()
    local self = setmetatable({}, StateController)
    self.current = nil
    return self
end

function StateController:change(nextState, ...)
    assert(type(nextState) == "table", "The next state must be a table")

    if self.current and self.current.exit then
        self.current:exit()
    end

    self.current = nextState

    if self.current.enter then
        self.current:enter(...)
    end
end

function StateController:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function StateController:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
end

function StateController:wheelmoved(x, y)
    if self.current and self.current.wheelmoved then
        self.current:wheelmoved(x, y)
    end
end

function StateController:keypressed(key, scancode, isRepeat)
    if self.current and self.current.keypressed then
        self.current:keypressed(key, scancode, isRepeat)
    end
end

function StateController:mousepressed(x, y, button, isTouch, presses)
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button, isTouch, presses)
    end
end

function StateController:mousereleased(x, y, button, isTouch, presses)
    if self.current and self.current.mousereleased then
        self.current:mousereleased(x, y, button, isTouch, presses)
    end
end

function StateController:mousemoved(x, y, dx, dy, isTouch)
    if self.current and self.current.mousemoved then
        self.current:mousemoved(x, y, dx, dy, isTouch)
    end
end

return StateController
