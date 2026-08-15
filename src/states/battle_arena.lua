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
local TurnSystem = require("src.sys.turn_sys")
local CombatSystem = require("src.sys.combat_sys")
local AttackVFX = require("src.rndr.attack_vfx")
local ArenaAISystem = require("src.sys.arena_ai_sys")
local TagDefinitions = require("data.tags")
local TagSystem = require("src.sys.tag_sys")

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
        linesVisible = false,
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
    self.tagSystem = TagSystem.new(TagDefinitions)
    self.combatSystem = CombatSystem.new({
        unitSystem = self.unitSystem,
        enemyArenaSystem = self.enemyArenaSystem,
        tagSystem = self.tagSystem,
    })
    self.arenaAISystem = ArenaAISystem.new(
        self.arenaGrid,
        self.unitSystem,
        self.enemyArenaSystem,
        self.combatSystem,
        {
            initialDelay = 1.2,
            actionDelay = 0.18,
            moveDuration = 0.22,
        }
    )
    self.unitDraw = UnitDraw.new(self.arenaGrid, ArenaScale)
    self.attackVFX = AttackVFX.new(self.unitDraw)
    self.arenaOverlays = ArenaOverlays.new()
    self.sfx = SFX.new()
    self.lastHoveredUnit = nil
    self.rangedAttackTarget = nil
    self.rangedAttackPreview = nil
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
    self.turnSystem = TurnSystem.new(self.unitSystem, {
        startDuration = 0.6,
        endDuration = 0.6,
        announcementDuration = 1.2,
    })
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

function BattleArena:_unitAtScreenPosition(screenX, screenY, predicate)
    local canvasX, canvasY = self:_screenToCanvas(screenX, screenY)
    if not self:_isInsideArena(canvasX, canvasY) then
        return nil
    end

    local worldX, worldY = self.camera:screenToWorld(canvasX, canvasY)
    return self.unitDraw:getUnitAt(
        worldX,
        worldY,
        self.unitSystem:getUnits(),
        predicate
    )
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

function BattleArena:_clearPlayerInteraction()
    self.selectedUnit = nil
    self.hoveredUnit = nil
    self.lastHoveredUnit = nil
    self.hoverCandidate = nil
    self.hoverCandidateActive = false
    self.hoverCandidateTime = 0
    self.rangedAttackTarget = nil
    self.rangedAttackPreview = nil
    self.arenaUIX:setSelectedUnit(nil)
    self.arenaMovementSystem:setSelectedUnit(nil)
    self.arenaMovementSystem:clearHover()
    self.shoutText:clear()
    self.mouse:clearInteraction()
    self.keyboard:clearInteraction()
end

function BattleArena:_playAttackVFX(result, onComplete, suppressAutoDeselect)
    if not result then
        return
    end

    self.attackVFX:play(
        result,
        function(completed)
            if completed and completed.defeated then
                self.combatSystem:finalizeDefeat(completed.target)
            end
            self.enemyArenaSystem:update(self.unitSystem:getUnits())
            self.lastHoveredUnit = nil
            if onComplete then
                onComplete(completed)
            end
            if not suppressAutoDeselect
                and completed
                and completed.attacker == self.selectedUnit
                and completed.attacker.exhausted then
                self:_clearPlayerInteraction()
            end
        end,
        function(impact)
            self.sfx:playAttackImpact(impact.vfxImage)
        end,
        function(defeat)
            self.sfx:playDefeat(defeat.target.definition.def_sfx)
        end
    )
end

function BattleArena:_playMeleeExchange(attack, onComplete)
    if not attack then
        return false
    end

    local engagingUnit = attack.attacker
    local engagedUnit = attack.target
    local function finishExchange()
        if engagingUnit == self.selectedUnit and engagingUnit.exhausted then
            self:_clearPlayerInteraction()
        end
        if onComplete then
            onComplete(attack)
        end
    end

    self:_playAttackVFX(
        attack,
        function(completed)
            if not completed or completed.defeated
                or (engagedUnit.hp or 0) <= 0
                or not self.unitSystem:contains(engagedUnit) then
                finishExchange()
                return
            end
            local retaliation = self.combatSystem:performRetaliation(
                engagedUnit,
                engagingUnit
            )
            if retaliation then
                self:_playAttackVFX(
                    retaliation,
                    finishExchange,
                    true
                )
            else
                finishExchange()
            end
        end,
        true
    )
    return true
end

function BattleArena:_handleAIEvent(event)
    if not event then
        return
    end

    if event.type == "movement" then
        self.sfx:playMovementOrder(event.unit.definition.move_sfx)
    elseif event.type == "melee_attack" then
        self:_playMeleeExchange(event.result, function()
            self.arenaAISystem:notifyAttackComplete()
        end)
    elseif event.type == "ranged_attack" then
        self:_playAttackVFX(
            event.result,
            function()
                self.arenaAISystem:notifyAttackComplete()
            end,
            true
        )
    elseif event.type == "phase_complete" then
        self.turnSystem:advanceEnemyTurn()
    end
end

function BattleArena:_handleCompletedMovement(completedMovement)
    if not completedMovement or not completedMovement.engagementTarget then
        return
    end

    local attack = self.combatSystem:performMeleeAttack(
        completedMovement.unit,
        completedMovement.engagementTarget
    )
    self:_playMeleeExchange(attack)
    if self.selectedUnit == completedMovement.unit then
        self.arenaMovementSystem:setSelectedUnit(self.selectedUnit)
    end
end

function BattleArena:update(dt)
    self.arenaOverlays:update(
        dt,
        self.unitSystem:getUnits()
    )
    self.shoutText:update(dt)
    local completedMovement = self.arenaMovementSystem:update(dt)
    self:_handleCompletedMovement(completedMovement)
    self.attackVFX:update(dt)
    self.enemyArenaSystem:update(self.unitSystem:getUnits())
    local previousPhase = self.turnSystem:getPhase()
    self.turnSystem:update(dt)
    self:_handleAIEvent(self.arenaAISystem:update(
        dt,
        self.turnSystem:isEnemyTurn()
    ))
    if previousPhase ~= self.turnSystem:getPhase()
        and not self.turnSystem:isPlayerTurn() then
        self:_clearPlayerInteraction()
    end
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

    if not self.turnSystem:isPlayerTurn() then
        self.hoveredUnit = nil
        self.rangedAttackTarget = nil
        self.rangedAttackPreview = nil
        self.arenaMovementSystem:clearHover()
        self.lastHoveredUnit = nil
        return
    end

    if self.attackVFX:isActive() then
        self.hoveredUnit = nil
        self.rangedAttackTarget = nil
        self.rangedAttackPreview = nil
        self.arenaMovementSystem:clearHover()
        self.lastHoveredUnit = nil
        self.mouse:clearInteraction()
        self.keyboard:clearInteraction()
        return
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
            self:_unitAtScreenPosition(
                mouseX,
                mouseY,
                function(unit)
                    return unit.exhausted ~= true
                end
            ),
            dt
        )
    end
    local canvasX, canvasY = self:_screenToCanvas(mouseX, mouseY)
    self.rangedAttackTarget = nil
    self.rangedAttackPreview = nil
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
        local rangedPreview = not self.arenaMovementSystem:isMoving()
            and not self.keyboard:isControlDown()
            and self.combatSystem:getRangedAttackPreview(
                self.selectedUnit,
                hoveredEnemy
            )
            or nil
        if rangedPreview then
            self.rangedAttackTarget = hoveredEnemy
            self.rangedAttackPreview = rangedPreview
            self.arenaMovementSystem:clearHover()
        else
            self.arenaMovementSystem:updateHover(worldX, worldY, hoveredEnemy)
        end
    else
        self.arenaMovementSystem:clearHover()
    end

    local soundHoveredUnit = self.rangedAttackTarget
        or self.arenaMovementSystem:getHoveredEngagement()
        or self.hoveredUnit
    if soundHoveredUnit and soundHoveredUnit ~= self.lastHoveredUnit then
        self.sfx:playUnitHover()
    end
    self.lastHoveredUnit = soundHoveredUnit

    local click = self.mouse:consumeClick()
    if click then
        self.rangedAttackTarget = nil
        self.rangedAttackPreview = nil
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
    local attackTarget = self.rangedAttackTarget or engagementTarget
    local focusedUnit = attackTarget or self.hoveredUnit
    local engagedFocusTargets = self.selectedUnit
        and not self.enemyArenaSystem:isEnemy(self.selectedUnit)
        and self.enemyArenaSystem:getEngagedOpponents(self.selectedUnit)
        or nil
    local showsEngagementAvailability = self.selectedUnit
        and not self.enemyArenaSystem:isEnemy(self.selectedUnit)
        and (not self.combatSystem:getRangedAttack(self.selectedUnit)
            or self.keyboard:isControlDown())
    self.unitDraw:draw(
        self.unitSystem:getUnits(),
        focusedUnit,
        self.arenaOverlays,
        self.selectedUnit,
        {
            dimEnemiesOnly = attackTarget ~= nil,
            deferFocusedUnit = attackTarget ~= nil,
            engagedFocusTargets = engagedFocusTargets,
            dimUnavailableEngagements = showsEngagementAvailability,
            enemyArenaSystem = self.enemyArenaSystem,
        }
    )
    self.arenaOverlays:drawMovement(
        self.arenaMovementSystem,
        self.unitDraw
    )
    if self.rangedAttackTarget then
        self.arenaOverlays:drawRangedAttackLine(
            self.selectedUnit,
            self.rangedAttackTarget,
            self.unitDraw
        )
    end
    if attackTarget then
        self.unitDraw:drawUnit(
            attackTarget,
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
    self.attackVFX:draw()
    self.camera:detach()
    self.attackVFX:drawDamageNumbers(self.camera)
    if engagementTarget then
        self.arenaOverlays:drawEngagementCapacity(
            self.arenaMovementSystem,
            self.unitDraw,
            self.camera
        )
    end
    if attackTarget then
        self.arenaOverlays:drawAttackPreview(
            self.arenaMovementSystem,
            self.unitDraw,
            self.camera,
            self.combatSystem,
            self.rangedAttackTarget,
            self.rangedAttackPreview
        )
    end
    self.shoutText:draw(
        self.unitDraw,
        self.camera,
        self.arenaUIX:getArenaHeight()
    )
    love.graphics.setScissor()
    self.arenaUIX:drawTurnAnnouncement(self.turnSystem)
    self.arenaUIX:draw(
        self.unitDraw,
        self.enemyArenaSystem,
        self.arenaMovementSystem
    )
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
    if not self.turnSystem:isPlayerTurn() or self.attackVFX:isActive() then
        return
    end

    local mouseX, mouseY = self.mouse:getPosition()
    local canvasX, canvasY = self:_screenToCanvas(mouseX, mouseY)
    if self:_isInsideArena(canvasX, canvasY) then
        self.mouse:wheelmoved(x, y)
    end
end

function BattleArena:mousepressed(x, y, button)
    if not self.turnSystem:isPlayerTurn() or self.attackVFX:isActive() then
        return
    end

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
        if not self.arenaMovementSystem:isMoving()
            and not self.keyboard:isControlDown() then
            local rangedAttack = self.combatSystem:performRangedAttack(
                self.selectedUnit,
                targetedEnemy
            )
            if rangedAttack then
                self:_playAttackVFX(rangedAttack)
                self.enemyArenaSystem:update(self.unitSystem:getUnits())
                self.lastHoveredUnit = nil
                return
            end
        end
        local attack = self.combatSystem:performMeleeAttack(
            self.selectedUnit,
            targetedEnemy
        )
        if attack then
            self:_playMeleeExchange(attack)
            self.enemyArenaSystem:update(self.unitSystem:getUnits())
            self.lastHoveredUnit = nil
            return
        end
        local movementOrder = self.arenaMovementSystem:moveSelectedToWorld(
            worldX,
            worldY,
            targetedEnemy
        )
        if movementOrder and movementOrder.completed then
            self:_handleCompletedMovement(movementOrder)
        elseif movementOrder then
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
    if not self.turnSystem:isPlayerTurn() or self.attackVFX:isActive() then
        return
    end
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

    if key == "space" then
        if not isRepeat and not self.attackVFX:isActive()
            and not self.arenaMovementSystem:isMoving()
            and self.turnSystem:advancePlayerTurn() then
            self:_clearPlayerInteraction()
        end
        return
    end

    if key == "tab" then
        if not isRepeat then
            self.arenaGrid:toggleLines()
        end
        return
    end

    if not self.turnSystem:isPlayerTurn() then
        return
    end

    self.cameraSystem:keypressed(key, isRepeat)
end

function BattleArena:exit()
    self.canvas = nil
end

return BattleArena
