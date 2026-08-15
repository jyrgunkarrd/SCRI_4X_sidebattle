local StateController = require("src.states.state_controller")
local BattleArena = require("src.states.battle_arena")
local MapEditor = require("src.tools.map_editor")

local states
local gameFont

local function hasArgument(arguments, soughtArgument)
    for _, argument in ipairs(arguments or {}) do
        if argument == soughtArgument then
            return true
        end
    end
    return false
end

function love.load(arguments, unfilteredArguments)
    love.graphics.setDefaultFilter("nearest", "nearest")
    gameFont = love.graphics.newFont("assets/fonts/Furore.otf", 16)
    love.graphics.setFont(gameFont)

    states = StateController.new()
    if hasArgument(arguments, "--map-editor")
        or hasArgument(unfilteredArguments, "--map-editor") then
        states:change(MapEditor.new())
    else
        states:change(BattleArena.new())
    end
end

function love.update(dt)
    states:update(dt)
end

function love.draw()
    states:draw()
end

function love.wheelmoved(x, y)
    states:wheelmoved(x, y)
end

function love.keypressed(key, scancode, isRepeat)
    states:keypressed(key, scancode, isRepeat)
end

function love.textinput(text)
    states:textinput(text)
end

function love.mousepressed(x, y, button, isTouch, presses)
    states:mousepressed(x, y, button, isTouch, presses)
end

function love.mousereleased(x, y, button, isTouch, presses)
    states:mousereleased(x, y, button, isTouch, presses)
end

function love.mousemoved(x, y, dx, dy, isTouch)
    states:mousemoved(x, y, dx, dy, isTouch)
end
