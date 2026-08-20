local SFX = require("src.audio.sfx")

local StateController = {}
StateController.__index = StateController

local SHUTTER_CLOSE_DURATION = 0.25
local SHUTTER_HOLD_DURATION = 0.05
local SHUTTER_OPEN_DURATION = 0.30
local SHUTTER_COLOR = { 0.012, 0.02, 0.04, 1 }
local SHUTTER_EDGE_COLOR = { 254 / 255, 0, 109 / 255, 1 }
local SHUTTER_EDGE_HEIGHT = 4
local unpackValues = table.unpack or unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local function unpackArguments(arguments)
    return unpackValues(arguments, 1, arguments.n)
end

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

function StateController.new()
    local self = setmetatable({}, StateController)
    self.current = nil
    self.stack = {}
    self.sfx = SFX.new()
    self.transition = nil
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

function StateController:push(nextState, ...)
    assert(type(nextState) == "table", "The next state must be a table")
    assert(not self.transition, "A state transition is already active")
    self.transition = {
        phase = "closing",
        elapsed = 0,
        operation = "push",
        nextState = nextState,
        arguments = pack(...),
    }
    self.sfx:playShutter()
end

function StateController:pop(...)
    assert(#self.stack > 0, "There is no suspended state to restore")
    assert(not self.transition, "A state transition is already active")
    self.transition = {
        phase = "closing",
        elapsed = 0,
        operation = "pop",
        arguments = pack(...),
    }
    self.sfx:playShutter()
end

function StateController:_completeStateSwap(transition)
    if transition.operation == "push" then
        if self.current then
            if self.current.pause then
                self.current:pause()
            end
            self.stack[#self.stack + 1] = self.current
        end

        self.current = transition.nextState
        if self.current.enter then
            self.current:enter(unpackArguments(transition.arguments))
        end
        return
    end

    if self.current and self.current.exit then
        self.current:exit()
    end

    self.current = table.remove(self.stack)
    if self.current.resume then
        self.current:resume(unpackArguments(transition.arguments))
    end
end

function StateController:update(dt)
    local transition = self.transition
    if transition then
        transition.elapsed = transition.elapsed + dt
        if transition.phase == "closing"
            and transition.elapsed >= SHUTTER_CLOSE_DURATION then
            transition.elapsed = transition.elapsed - SHUTTER_CLOSE_DURATION
            transition.phase = "holding"
            self:_completeStateSwap(transition)
        elseif transition.phase == "holding"
            and transition.elapsed >= SHUTTER_HOLD_DURATION then
            transition.elapsed = transition.elapsed - SHUTTER_HOLD_DURATION
            transition.phase = "opening"
        elseif transition.phase == "opening"
            and transition.elapsed >= SHUTTER_OPEN_DURATION then
            self.transition = nil
        end
        return
    end
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function StateController:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
    local transition = self.transition
    if not transition then
        return
    end

    local amount
    if transition.phase == "closing" then
        amount = smoothstep(math.min(
            1,
            transition.elapsed / SHUTTER_CLOSE_DURATION
        ))
    elseif transition.phase == "holding" then
        amount = 1
    else
        amount = 1 - smoothstep(math.min(
            1,
            transition.elapsed / SHUTTER_OPEN_DURATION
        ))
    end

    local width, height = love.graphics.getDimensions()
    local panelHeight = math.ceil(height * 0.5 * amount)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setColor(SHUTTER_COLOR)
    love.graphics.rectangle("fill", 0, 0, width, panelHeight)
    love.graphics.rectangle(
        "fill",
        0,
        height - panelHeight,
        width,
        panelHeight
    )
    if panelHeight > 0 then
        local edgeHeight = math.min(SHUTTER_EDGE_HEIGHT, panelHeight)
        love.graphics.setColor(SHUTTER_EDGE_COLOR)
        love.graphics.rectangle(
            "fill",
            0,
            panelHeight - edgeHeight,
            width,
            edgeHeight
        )
        love.graphics.rectangle(
            "fill",
            0,
            height - panelHeight,
            width,
            edgeHeight
        )
    end
    love.graphics.pop()
end

function StateController:quit()
    if self.current and self.current.quit then
        return self.current:quit()
    end
    return false
end

function StateController:wheelmoved(x, y)
    if self.transition then
        return
    end
    if self.current and self.current.wheelmoved then
        self.current:wheelmoved(x, y)
    end
end

function StateController:keypressed(key, scancode, isRepeat)
    if self.transition then
        return
    end
    if self.current and self.current.keypressed then
        self.current:keypressed(key, scancode, isRepeat)
    end
end

function StateController:textinput(text)
    if self.transition then
        return
    end
    if self.current and self.current.textinput then
        self.current:textinput(text)
    end
end

function StateController:mousepressed(x, y, button, isTouch, presses)
    if self.transition then
        return
    end
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button, isTouch, presses)
    end
end

function StateController:mousereleased(x, y, button, isTouch, presses)
    if self.transition then
        return
    end
    if self.current and self.current.mousereleased then
        self.current:mousereleased(x, y, button, isTouch, presses)
    end
end

function StateController:mousemoved(x, y, dx, dy, isTouch)
    if self.transition then
        return
    end
    if self.current and self.current.mousemoved then
        self.current:mousemoved(x, y, dx, dy, isTouch)
    end
end

return StateController
