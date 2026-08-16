local WorldMapSystem = require("src.sys.world_map_sys")
local WorldKeyboard = require("src.input.world_keyboard")
local DevWorld = require("data.dev_world")
local WorldUIXDraw = require("src.rndr.world_uix_draw")

local WorldMap = {}
WorldMap.__index = WorldMap

WorldMap.name = "world-map"

local VIRTUAL_WIDTH = 1920
local VIRTUAL_HEIGHT = 1080
local CAMERA_SPEED = 720
local CAMERA_BOUNDS_BUFFER = 360

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(value, maximum))
end

function WorldMap.new()
    return setmetatable({}, WorldMap)
end

function WorldMap:enter()
    self.canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.canvas:setFilter("nearest", "nearest")
    self.uiCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.uiCanvas:setFilter("linear", "linear")
    self.outputScale = 1
    self.outputOffsetX = 0
    self.outputOffsetY = 0
    self.middleDragging = false
    self.keyboard = WorldKeyboard.new()
    self.worldMapSystem = WorldMapSystem.new(DevWorld)
    self.worldUIXDraw = WorldUIXDraw.new({ virtualHeight = VIRTUAL_HEIGHT })
    self.cameraBounds = self.worldMapSystem:getCameraBounds(
        CAMERA_BOUNDS_BUFFER
    )
    self.cameraX, self.cameraY = self.worldMapSystem:getFocusPosition()
    self:_clampCamera()
end

function WorldMap:_updateHoveredTerrain()
    local screenX, screenY = love.mouse.getPosition()
    local virtualX = (screenX - self.outputOffsetX) / self.outputScale
    local virtualY = (screenY - self.outputOffsetY) / self.outputScale
    if virtualX < 0 or virtualX >= VIRTUAL_WIDTH
        or virtualY < 0 or virtualY >= VIRTUAL_HEIGHT then
        self.worldUIXDraw:setHoveredTerrain(nil)
        return
    end
    local worldX = self.cameraX + virtualX - VIRTUAL_WIDTH / 2
    local worldY = self.cameraY + virtualY - VIRTUAL_HEIGHT / 2
    local terrain = self.worldMapSystem:getTerrainAtWorldPosition(worldX, worldY)
    self.worldUIXDraw:setHoveredTerrain(terrain)
end

function WorldMap:_clampCamera()
    self.cameraX = clamp(
        self.cameraX,
        self.cameraBounds.minimumX,
        self.cameraBounds.maximumX
    )
    self.cameraY = clamp(
        self.cameraY,
        self.cameraBounds.minimumY,
        self.cameraBounds.maximumY
    )
end

function WorldMap:update(dt)
    self.worldMapSystem:update(dt)
    local movementX, movementY = self.keyboard:getMovement()
    self.cameraX = self.cameraX + movementX * CAMERA_SPEED * dt
    self.cameraY = self.cameraY + movementY * CAMERA_SPEED * dt
    self:_clampCamera()
    self:_updateHoveredTerrain()
end

function WorldMap:draw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0.025, 0.035, 0.055, 1)
    self.worldMapSystem:draw(
        self.cameraX,
        self.cameraY,
        VIRTUAL_WIDTH,
        VIRTUAL_HEIGHT
    )

    love.graphics.setCanvas(self.uiCanvas)
    love.graphics.clear(0, 0, 0, 0)
    self.worldUIXDraw:draw()
    love.graphics.setCanvas()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local scale = math.min(
        windowWidth / VIRTUAL_WIDTH,
        windowHeight / VIRTUAL_HEIGHT
    )
    local drawWidth = VIRTUAL_WIDTH * scale
    local drawHeight = VIRTUAL_HEIGHT * scale
    self.outputScale = scale
    self.outputOffsetX = math.floor((windowWidth - drawWidth) / 2)
    self.outputOffsetY = math.floor((windowHeight - drawHeight) / 2)

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self.canvas,
        self.outputOffsetX,
        self.outputOffsetY,
        0,
        scale,
        scale
    )
    love.graphics.draw(
        self.uiCanvas,
        self.outputOffsetX,
        self.outputOffsetY,
        0,
        scale,
        scale
    )
end

function WorldMap:keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function WorldMap:mousepressed(_x, _y, button)
    if button == 3 then
        self.middleDragging = true
    end
end

function WorldMap:mousereleased(_x, _y, button)
    if button == 3 then
        self.middleDragging = false
    end
end

function WorldMap:mousemoved(_x, _y, dx, dy)
    if not self.middleDragging then
        return
    end
    self.cameraX = self.cameraX - dx / self.outputScale
    self.cameraY = self.cameraY - dy / self.outputScale
    self:_clampCamera()
    self:_updateHoveredTerrain()
end

function WorldMap:exit()
    self.canvas = nil
    self.uiCanvas = nil
    self.keyboard = nil
    self.middleDragging = false
    self.worldMapSystem = nil
    self.worldUIXDraw = nil
end

return WorldMap
