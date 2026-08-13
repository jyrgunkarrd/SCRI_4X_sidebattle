local ArenaGrid = require("src.rndr.arena_grid")
local Camera = require("src.rndr.camera")
local Mouse = require("src.input.mouse")
local Keyboard = require("src.input.keyboard")
local CameraSystem = require("src.sys.camera_sys")
local UnitDefinitions = require("data.units.index")
local UnitSystem = require("src.sys.unit_sys")
local UnitDraw = require("src.rndr.unit_draw")
local DevTools = require("src.tools.dev_tools")
local ArenaScale = require("data.arena_scale")
local ArenaOverlays = require("src.rndr.arena_overlays")
local ArenaUIX = require("src.rndr.arena_uix")
local ArenaMovementSystem = require("src.sys.arena_mov_sys")
local EnemyArenaSystem = require("src.sys.en_arena_sys")
local ArenaEnvironmentBackground = require("src.rndr.arena_env_bg")
local ArenaEnvironments = require("data.arena_env")
local DevArenaLoader = require("data.dev_arena_loader")
local SFX = require("src.audio.sfx")
local ShoutText = require("src.rndr.shout_text")

local BattleArena = {}
BattleArena.__index = BattleArena

local VIRTUAL_WIDTH = 1920
local VIRTUAL_HEIGHT = 1080
local PROFILE_HEIGHT = 240
local HOVER_SETTLE_DELAY = 0.08

function BattleArena.new()
    return setmetatable({}, BattleArena)
end

function BattleArena:enter()
    self.canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.canvas:setFilter("linear", "linear")
    self.outputScale = 1
    self.outputOffsetX = 0
    self.outputOffsetY = 0

    self.arenaGrid = ArenaGrid.new({
        columns = 20,
        rows = 3,
        virtualWidth = VIRTUAL_WIDTH,
        virtualHeight = VIRTUAL_HEIGHT,
        anchor = "bottom",
    })
    self.arenaEnvironmentBackground = ArenaEnvironmentBackground.fromLoader(
        ArenaEnvironments,
        DevArenaLoader,
        {
            virtualWidth = VIRTUAL_WIDTH,
            virtualHeight = VIRTUAL_HEIGHT,
        }
    )

    self.camera = Camera.new({
        viewportWidth = VIRTUAL_WIDTH,
        viewportHeight = VIRTUAL_HEIGHT,
        worldWidth = self.arenaGrid.width,
        worldHeight = self.arenaGrid.height,
        zoom = 1,
        minimumZoom = 1,
        maximumZoom = 3,
    })
    self.mouse = Mouse.new({ dragThreshold = 6 })
    self.keyboard = Keyboard.new()
    self.cameraSystem = CameraSystem.new(self.camera, self.mouse, self.keyboard, {
        panSpeed = 900,
        zoomStep = 0.2,
        verticalDragThreshold = 140,
        verticalSmoothing = 12,
        fastPanMultiplier = 3.5,
    })
    self.unitSystem = UnitSystem.new(UnitDefinitions, self.arenaGrid)
    self.enemyArenaSystem = EnemyArenaSystem.new(self.arenaGrid)
    self.arenaMovementSystem = ArenaMovementSystem.new(
        self.arenaGrid,
        self.enemyArenaSystem,
        self.unitSystem
    )
    self.unitDraw = UnitDraw.new(self.arenaGrid, ArenaScale)
    self.arenaOverlays = ArenaOverlays.new()
    self.sfx = SFX.new()
    self.lastHoveredUnit = nil
    self.hoverCandidate = nil
    self.hoverCandidateActive = false
    self.hoverCandidateTime = 0
    self.shoutText = ShoutText.new()
    self.arenaUIX = ArenaUIX.new({
        virtualWidth = VIRTUAL_WIDTH,
        virtualHeight = VIRTUAL_HEIGHT,
        panelHeight = PROFILE_HEIGHT,
    })
    self.devTools = DevTools.new(self.unitSystem)
    self.devTools:injectFromLoader()
    self.enemyArenaSystem:update(self.unitSystem:getUnits())
end

function BattleArena:_screenToCanvas(screenX, screenY)
    return
        (screenX - self.outputOffsetX) / self.outputScale,
        (screenY - self.outputOffsetY) / self.outputScale
end

function BattleArena:_isInsideArena(canvasX, canvasY)
    return canvasX >= 0 and canvasX <= VIRTUAL_WIDTH
        and canvasY >= 0 and canvasY <= self.arenaUIX:getArenaHeight()
end

function BattleArena:_unitAtScreenPosition(screenX, screenY)
    local canvasX, canvasY = self:_screenToCanvas(screenX, screenY)
    if not self:_isInsideArena(canvasX, canvasY) then
        return nil
    end

    local worldX, worldY = self.camera:screenToWorld(canvasX, canvasY)
    return self.unitDraw:getUnitAt(worldX, worldY, self.unitSystem:getUnits())
end

function BattleArena:_updateUnitHover(candidate, dt)
    if candidate == self.hoveredUnit then
        self.hoverCandidate = nil
        self.hoverCandidateActive = false
        self.hoverCandidateTime = 0
        return
    end

    if not self.hoverCandidateActive or candidate ~= self.hoverCandidate then
        self.hoverCandidate = candidate
        self.hoverCandidateActive = true
        self.hoverCandidateTime = dt
    else
        self.hoverCandidateTime = self.hoverCandidateTime + dt
    end

    if self.hoverCandidateTime >= HOVER_SETTLE_DELAY then
        self.hoveredUnit = candidate
        self.hoverCandidate = nil
        self.hoverCandidateActive = false
        self.hoverCandidateTime = 0
    end
end

function BattleArena:update(dt)
    self.arenaOverlays:update(dt)
    self.shoutText:update(dt)
    self.arenaMovementSystem:update(dt)
    self.enemyArenaSystem:update(self.unitSystem:getUnits())
    local panelWasOpening = self.arenaUIX:isOpening()
    self.arenaUIX:update(dt)
    self.camera:setViewportSize(
        VIRTUAL_WIDTH,
        self.arenaUIX:getArenaHeight(),
        false
    )

    if panelWasOpening and self.selectedUnit then
        local _left, top, _right, bottom = self.unitDraw:getUnitBounds(
            self.selectedUnit
        )
        self.camera:ensureWorldVerticalVisible(top, bottom, 16)
    end

    self.cameraSystem:update(dt)

    local mouseX, mouseY = self.mouse:getPosition()
    if self.selectedUnit then
        self.hoveredUnit = nil
        self.hoverCandidate = nil
        self.hoverCandidateActive = false
        self.hoverCandidateTime = 0
    else
        self:_updateUnitHover(
            self:_unitAtScreenPosition(mouseX, mouseY),
            dt
        )
    end
    local canvasX, canvasY = self:_screenToCanvas(mouseX, mouseY)
    if self:_isInsideArena(canvasX, canvasY) then
        local worldX, worldY = self.camera:screenToWorld(canvasX, canvasY)
        local hoveredEnemy = self.unitDraw:getUnitAt(
            worldX,
            worldY,
            self.unitSystem:getUnits(),
            function(unit)
                return self.enemyArenaSystem:isEnemy(unit)
            end
        )
        self.arenaMovementSystem:updateHover(worldX, worldY, hoveredEnemy)
    else
        self.arenaMovementSystem:clearHover()
    end

    local soundHoveredUnit = self.arenaMovementSystem:getHoveredEngagement()
        or self.hoveredUnit
    if soundHoveredUnit and soundHoveredUnit ~= self.lastHoveredUnit then
        self.sfx:playUnitHover()
    end
    self.lastHoveredUnit = soundHoveredUnit

    local click = self.mouse:consumeClick()
    if click then
        self.selectedUnit = self:_unitAtScreenPosition(click.x, click.y)
        self.arenaUIX:setSelectedUnit(self.selectedUnit)
        self.arenaMovementSystem:setSelectedUnit(self.selectedUnit)

        if self.selectedUnit then
            self.sfx:playUnitSelect(self.selectedUnit.unitId)
            self.shoutText:show(self.selectedUnit)
        else
            self.shoutText:clear()
        end
    end
end

function BattleArena:draw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0.035, 0.045, 0.075, 1)
    love.graphics.setScissor(0, 0, VIRTUAL_WIDTH, self.arenaUIX:getArenaHeight())
    self.arenaEnvironmentBackground:draw(self.camera)
    self.camera:attach()
    self.arenaEnvironmentBackground:drawFloor(self.arenaGrid)
    self.arenaGrid:draw()
    local engagementTarget = self.arenaMovementSystem:getHoveredEngagement()
    local focusedUnit = engagementTarget or self.hoveredUnit
    self.unitDraw:draw(
        self.unitSystem:getUnits(),
        focusedUnit,
        self.arenaOverlays,
        self.selectedUnit,
        {
            dimEnemiesOnly = engagementTarget ~= nil,
            deferFocusedUnit = engagementTarget ~= nil,
            enemyArenaSystem = self.enemyArenaSystem,
        }
    )
    self.arenaOverlays:drawMovement(
        self.arenaMovementSystem,
        self.unitDraw
    )
    if engagementTarget then
        self.unitDraw:drawUnit(
            engagementTarget,
            self.arenaOverlays,
            self.enemyArenaSystem
        )
    end
    if self.selectedUnit then
        self.unitDraw:drawUnit(
            self.selectedUnit,
            self.arenaOverlays,
            self.enemyArenaSystem
        )
    end
    self.camera:detach()
    if engagementTarget then
        self.arenaOverlays:drawEngagementCapacity(
            self.arenaMovementSystem,
            self.unitDraw,
            self.camera
        )
    end
    self.shoutText:draw(
        self.unitDraw,
        self.camera,
        self.arenaUIX:getArenaHeight()
    )
    love.graphics.setScissor()
    self.arenaUIX:draw(self.unitDraw, self.enemyArenaSystem)
    love.graphics.setCanvas()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local scale = math.min(windowWidth / VIRTUAL_WIDTH, windowHeight / VIRTUAL_HEIGHT)
    local drawWidth = VIRTUAL_WIDTH * scale
    local drawHeight = VIRTUAL_HEIGHT * scale
    local offsetX = math.floor((windowWidth - drawWidth) / 2)
    local offsetY = math.floor((windowHeight - drawHeight) / 2)
    self.outputScale = scale
    self.outputOffsetX = offsetX
    self.outputOffsetY = offsetY
    self.cameraSystem:setOutputTransform(scale, offsetX, offsetY)

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, offsetX, offsetY, 0, scale, scale)
end

function BattleArena:wheelmoved(x, y)
    local mouseX, mouseY = self.mouse:getPosition()
    local canvasX, canvasY = self:_screenToCanvas(mouseX, mouseY)
    if self:_isInsideArena(canvasX, canvasY) then
        self.mouse:wheelmoved(x, y)
    end
end

function BattleArena:mousepressed(x, y, button)
    local canvasX, canvasY = self:_screenToCanvas(x, y)
    if button == 2 and self:_isInsideArena(canvasX, canvasY) then
        self.mouse:pressed(x, y, button)
        local worldX, worldY = self.camera:screenToWorld(canvasX, canvasY)
        local targetedEnemy = self.unitDraw:getUnitAt(
            worldX,
            worldY,
            self.unitSystem:getUnits(),
            function(unit)
                return self.enemyArenaSystem:isEnemy(unit)
            end
        )
        local orderIssued = self.arenaMovementSystem:moveSelectedToWorld(
            worldX,
            worldY,
            targetedEnemy
        )
        if orderIssued then
            self.sfx:playMovementOrder(
                self.selectedUnit.definition.move_sfx
            )
        end
        return
    end

    if button ~= 1 or self:_isInsideArena(canvasX, canvasY) then
        self.mouse:pressed(x, y, button)
    end
end

function BattleArena:mousereleased(x, y, button)
    self.mouse:released(x, y, button)
end

function BattleArena:mousemoved(x, y, dx, dy)
    self.mouse:moved(x, y, dx, dy)
end

function BattleArena:keypressed(key, _scancode, isRepeat)
    if key == "escape" then
        love.event.quit()
        return
    end

    self.cameraSystem:keypressed(key, isRepeat)
end

function BattleArena:exit()
    self.canvas = nil
end

return BattleArena
