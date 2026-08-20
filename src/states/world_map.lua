local WorldMapSystem = require("src.sys.world_map_sys")
local WorldKeyboard = require("src.input.world_keyboard")
local DevWorld = require("data.dev_world")
local WorldUIXDraw = require("src.rndr.world_uix_draw")
local WorldMouse = require("src.input.world_mouse")
local SFX = require("src.audio.sfx")
local ShoutText = require("src.rndr.shout_text")
local TurnSystem = require("src.sys.turn_sys")
local CombatStartSystem = require("src.sys.combat_start_sys")

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

function WorldMap.new(options)
    local self = setmetatable({}, WorldMap)
    self.options = options or {}
    return self
end

function WorldMap:enter()
    self.canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.canvas:setFilter("nearest", "nearest")
    self.uiCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.uiCanvas:setFilter("linear", "linear")
    self.outputScale = 1
    self.outputOffsetX = 0
    self.outputOffsetY = 0
    self.keyboard = WorldKeyboard.new()
    self.mouse = WorldMouse.new()
    self.sfx = SFX.new()
    self.shoutText = ShoutText.new()
    self.combatStartSystem = CombatStartSystem.new({
        onStart = assert(self.options.onCombatStart,
            "World map combat transition callback is required"),
    })
    self.worldMapSystem = WorldMapSystem.new(DevWorld, {
        combatStartSystem = self.combatStartSystem,
    })
    self.turnSystem = TurnSystem.new(self.worldMapSystem.worldUnitSystem, {
        startDuration = 0.6,
        endDuration = 0.6,
        announcementDuration = 1.2,
        onPhaseEntered = function(phase)
            if phase == TurnSystem.PHASE_PLAYER then
                self.sfx:playPlayerPhase()
            elseif phase == TurnSystem.PHASE_ENEMY then
                self.sfx:playEnemyTurn()
            end
        end,
    })
    self.worldUIXDraw = WorldUIXDraw.new({
        virtualWidth = VIRTUAL_WIDTH,
        virtualHeight = VIRTUAL_HEIGHT,
    })
    self.cameraBounds = self.worldMapSystem:getCameraBounds(
        CAMERA_BOUNDS_BUFFER
    )
    self.cameraX, self.cameraY = self.worldMapSystem:getFocusPosition()
    self:_clampCamera()
end

function WorldMap:_screenToVirtual(screenX, screenY)
    local virtualX = (screenX - self.outputOffsetX) / self.outputScale
    local virtualY = (screenY - self.outputOffsetY) / self.outputScale
    if virtualX < 0 or virtualX >= VIRTUAL_WIDTH
        or virtualY < 0 or virtualY >= VIRTUAL_HEIGHT then
        return nil, nil
    end
    return virtualX, virtualY
end

function WorldMap:_screenToWorld(screenX, screenY)
    local virtualX, virtualY = self:_screenToVirtual(screenX, screenY)
    if not virtualX then
        return nil, nil
    end
    return self.cameraX + virtualX - VIRTUAL_WIDTH / 2,
        self.cameraY + virtualY - VIRTUAL_HEIGHT / 2
end

function WorldMap:_updateHoveredPanel()
    local screenX, screenY = love.mouse.getPosition()
    local virtualX, virtualY = self:_screenToVirtual(screenX, screenY)
    if virtualX
        and self.worldUIXDraw:isPointInStackPanel(virtualX, virtualY) then
        self.worldMapSystem:clearMovementHover()
        return
    end
    local worldX, worldY = self:_screenToWorld(screenX, screenY)
    if not worldX then
        self.worldMapSystem:clearMovementHover()
        self.worldUIXDraw:setHoveredTerrain(nil)
        return
    end
    self.worldMapSystem:setMovementHoverAtWorldPosition(worldX, worldY)
    local resource = self.worldMapSystem:getResourceAtWorldPosition(worldX, worldY)
    if resource then
        self.worldUIXDraw:setHoveredResource(resource.definition)
        return
    end
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
    local previousPhase = self.turnSystem:getPhase()
    self.turnSystem:update(dt)
    if self.turnSystem:isEnemyTurn() then
        local announcement = self.turnSystem:getAnnouncement()
        if not announcement then
            self.turnSystem:advanceEnemyTurn()
        end
    end
    if previousPhase ~= self.turnSystem:getPhase()
        and not self.turnSystem:isPlayerTurn() then
        self.worldMapSystem:deselectUnit()
        self.worldUIXDraw:setSelectedStack(nil, nil)
        self.shoutText:clear()
    end
    self.worldUIXDraw:setSelectedStack(
        self.worldMapSystem:getSelectedUnitSourceStack(),
        self.worldMapSystem:getSelectedUnitStack()
    )
    self.shoutText:update(dt)
    local movementX, movementY = self.keyboard:getMovement()
    self.cameraX = self.cameraX + movementX * CAMERA_SPEED * dt
    self.cameraY = self.cameraY + movementY * CAMERA_SPEED * dt
    local panX, panY = self.mouse:consumePan()
    self.cameraX = self.cameraX - panX / self.outputScale
    self.cameraY = self.cameraY - panY / self.outputScale
    self:_clampCamera()

    for _, click in ipairs(self.mouse:consumeLeftClicks()) do
        if self.turnSystem:isPlayerTurn() then
        local virtualX, virtualY = self:_screenToVirtual(click.x, click.y)
        local clickedPanel = virtualX
            and self.worldUIXDraw:isPointInStackPanel(virtualX, virtualY)
        if clickedPanel then
            local panelUnit = self.worldUIXDraw:getStackUnitAtPoint(
                virtualX,
                virtualY
            )
            if panelUnit then
                local _unit, activeStack, changed =
                    self.worldMapSystem:toggleUnitInSelection(panelUnit)
                self.worldUIXDraw:setSelectedStack(
                    self.worldMapSystem:getSelectedUnitSourceStack(),
                    activeStack
                )
                if changed then
                    self.sfx:playClick()
                    self.shoutText:clear()
                end
            end
        else
            local worldX, worldY = self:_screenToWorld(click.x, click.y)
            if worldX then
                local unit, stack =
                    self.worldMapSystem:selectUnitAtWorldPosition(
                        worldX,
                        worldY
                    )
                self.worldUIXDraw:setSelectedStack(stack, stack)
                if unit then
                    self.sfx:playUnitSelect(unit.id)
                    self.shoutText:show(unit)
                else
                    self.shoutText:clear()
                end
            else
                self.worldMapSystem:deselectUnit()
                self.worldUIXDraw:setSelectedStack(nil, nil)
                self.shoutText:clear()
            end
        end
        end
    end
    for _, click in ipairs(self.mouse:consumeRightClicks()) do
        if self.turnSystem:isPlayerTurn() then
        local virtualX, virtualY = self:_screenToVirtual(click.x, click.y)
        local clickedPanel = virtualX
            and self.worldUIXDraw:isPointInStackPanel(virtualX, virtualY)
        local worldX, worldY = self:_screenToWorld(click.x, click.y)
        if worldX and not clickedPanel then
            local moved = self.worldMapSystem:moveSelectedUnitToWorldPosition(
                worldX,
                worldY
            )
            if moved then
                self.sfx:playMovementOrder()
            end
        end
        end
    end
    self:_updateHoveredPanel()
    if self.combatStartSystem:dispatchPending() then
        return
    end
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
    self.worldUIXDraw:drawTurnAnnouncement(self.turnSystem)
    self.shoutText:drawWorld(
        self.cameraX,
        self.cameraY,
        VIRTUAL_WIDTH,
        VIRTUAL_HEIGHT
    )
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

function WorldMap:keypressed(key, _scancode, isRepeat)
    if key == "escape" then
        love.event.quit()
        return
    end
    if key == "space" and not isRepeat
        and not self.worldMapSystem:isUnitMovementActive()
        and self.turnSystem:advancePlayerTurn() then
        self.worldMapSystem:deselectUnit()
        self.worldUIXDraw:setSelectedStack(nil, nil)
        self.shoutText:clear()
        return
    end
    if key == "m" and not isRepeat
        and self.turnSystem:isPlayerTurn()
        and self.worldMapSystem:getSelectedUnitSourceStack()
        and not self.worldMapSystem:isUnitMovementActive() then
        local _unit, activeStack, changed =
            self.worldMapSystem:selectUnitsWithMovementRemaining()
        if changed then
            self.worldUIXDraw:setSelectedStack(
                self.worldMapSystem:getSelectedUnitSourceStack(),
                activeStack
            )
            self.sfx:playClick()
            self.shoutText:clear()
        end
    end
end

function WorldMap:pause()
    self.worldMapSystem:deselectUnit()
    self.worldUIXDraw:setSelectedStack(nil, nil)
    self.worldMapSystem:clearMovementHover()
    self.shoutText:clear()
    self.mouse = WorldMouse.new()
end

function WorldMap:resume(combatResult)
    if combatResult then
        self.worldMapSystem:applyCombatResult(combatResult)
        self.lastBattleResult = combatResult
    end
    self.worldUIXDraw:setSelectedStack(nil, nil)
    self:_updateHoveredPanel()
end

function WorldMap:mousepressed(x, y, button)
    self.mouse:mousepressed(x, y, button)
end

function WorldMap:mousereleased(x, y, button)
    self.mouse:mousereleased(x, y, button)
end

function WorldMap:mousemoved(x, y, dx, dy)
    self.mouse:mousemoved(x, y, dx, dy)
end

function WorldMap:exit()
    self.canvas = nil
    self.uiCanvas = nil
    self.keyboard = nil
    self.mouse = nil
    self.sfx = nil
    self.shoutText = nil
    self.worldMapSystem = nil
    self.turnSystem = nil
    self.combatStartSystem = nil
    self.worldUIXDraw = nil
end

return WorldMap
