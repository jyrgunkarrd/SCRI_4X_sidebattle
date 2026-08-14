local ArenaMovementSystem = {}
ArenaMovementSystem.__index = ArenaMovementSystem

local function cellKey(targW, targH)
    return targW .. ":" .. targH
end

function ArenaMovementSystem.new(arenaGrid, enemyArenaSystem, unitSystem)
    local self = setmetatable({}, ArenaMovementSystem)
    self.grid = assert(arenaGrid, "Arena grid is required")
    self.enemyArenaSystem = assert(enemyArenaSystem, "Enemy arena system is required")
    self.unitSystem = assert(unitSystem, "Unit system is required")
    self.selectedUnit = nil
    self.destinations = {}
    self.destinationLookup = {}
    self.hoveredDestination = nil
    self.hoveredEngagement = nil
    self.moveDuration = 0.22
    self.movement = nil
    return self
end

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

function ArenaMovementSystem:setSelectedUnit(unit)
    self.selectedUnit = unit
    self.destinations = {}
    self.destinationLookup = {}
    self.hoveredDestination = nil
    self.hoveredEngagement = nil

    if not unit or unit.engagedWith or unit.exhausted or self.movement
        or unit.isEnemy == true or unit.definition.enemy == true then
        return
    end

    local movementRange = self.unitSystem:getMovementPoints(unit)
    local units = self.unitSystem:getUnits()
    local currentEnemies = self.enemyArenaSystem:getEnemiesAt(
        units,
        unit.targW,
        unit.targH
    )
    local blockedInCurrentCell = self.enemyArenaSystem:cellHasBlockingEnemy(
        units,
        unit.targW,
        unit.targH
    )

    if blockedInCurrentCell then
        local destination = {
            targW = unit.targW,
            targH = unit.targH,
            movementCost = 0,
            enemies = currentEnemies,
            requiresEngagement = true,
        }
        self.destinations[1] = destination
        self.destinationLookup[cellKey(unit.targW, unit.targH)] = destination
        return
    end

    for _, direction in ipairs({ -1, 1 }) do
        for distance = 1, movementRange do
            local targW = unit.targW + direction * distance
            if targW < 1 or targW > self.grid.columns then
                break
            end

            local enemies = self.enemyArenaSystem:getEnemiesAt(
                units,
                targW,
                unit.targH
            )
            local isBlocked = self.enemyArenaSystem:cellHasBlockingEnemy(
                units,
                targW,
                unit.targH
            )
            local destination = {
                targW = targW,
                targH = unit.targH,
                movementCost = distance,
                enemies = enemies,
                requiresEngagement = isBlocked,
            }
            self.destinations[#self.destinations + 1] = destination
            self.destinationLookup[cellKey(targW, unit.targH)] = destination

            if isBlocked then
                break
            end
        end
    end
end

function ArenaMovementSystem:getDestinations()
    return self.destinations
end

function ArenaMovementSystem:getHoveredDestination()
    return self.hoveredDestination
end

function ArenaMovementSystem:getHoveredEngagement()
    return self.hoveredEngagement
end

function ArenaMovementSystem:worldToCell(worldX, worldY)
    local localX = worldX - self.grid.x
    local localY = worldY - self.grid.y

    if localX < 0 or localY < 0
        or localX >= self.grid.width or localY >= self.grid.height then
        return nil, nil
    end

    local targW = math.floor(localX / self.grid.cellSize) + 1
    local visualRow = math.floor(localY / self.grid.cellSize)
    local targH = self.grid.rows - visualRow
    return targW, targH
end

local function containsUnit(units, soughtUnit)
    for _, unit in ipairs(units) do
        if unit == soughtUnit then
            return true
        end
    end
    return false
end

function ArenaMovementSystem:updateHover(worldX, worldY, hoveredEnemy)
    local targW, targH = self:worldToCell(worldX, worldY)
    local destination = targW
        and self.destinationLookup[cellKey(targW, targH)]
        or nil
    local validEnemy = destination
        and hoveredEnemy
        and containsUnit(destination.enemies, hoveredEnemy)
        and self.enemyArenaSystem:canEngage(hoveredEnemy)

    self.hoveredEngagement = validEnemy and hoveredEnemy or nil
    self.hoveredDestination = destination
        and (not destination.requiresEngagement or validEnemy)
        and destination
        or nil
    return self.hoveredDestination
end

function ArenaMovementSystem:clearHover()
    self.hoveredDestination = nil
    self.hoveredEngagement = nil
end

function ArenaMovementSystem:moveSelectedToWorld(worldX, worldY, targetedEnemy)
    if not self.selectedUnit or self.selectedUnit.engagedWith
        or self.selectedUnit.exhausted or self.movement
        or self.selectedUnit.isEnemy == true
        or self.selectedUnit.definition.enemy == true then
        return false
    end

    local targW, targH = self:worldToCell(worldX, worldY)
    local destination = targW
        and self.destinationLookup[cellKey(targW, targH)]
        or nil

    if not destination then
        return false
    end

    local validEngagement = targetedEnemy
        and containsUnit(destination.enemies, targetedEnemy)
        and self.enemyArenaSystem:canEngage(targetedEnemy)

    if destination.requiresEngagement and not validEngagement then
        return false
    end

    if not self.unitSystem:spendMovementPoints(
        self.selectedUnit,
        destination.movementCost
    ) then
        return false
    end

    if destination.movementCost == 0 then
        local selectedOffset = self.selectedUnit.arenaCellOffsetX or 0
        local enemyOffset = targetedEnemy.arenaCellOffsetX or self.grid.cellSize / 4
        self.selectedUnit.facing = enemyOffset < selectedOffset
            and "left"
            or "right"
        local engaged = self.enemyArenaSystem:engage(
            self.selectedUnit,
            targetedEnemy
        )
        if not engaged then
            return false
        end

        local completed = {
            unit = self.selectedUnit,
            engagementTarget = targetedEnemy,
            movementCost = 0,
            completed = true,
        }
        self.destinations = {}
        self.destinationLookup = {}
        self.hoveredDestination = nil
        self.hoveredEngagement = nil
        self:setSelectedUnit(self.selectedUnit)
        return completed
    end

    local previousColumn = self.selectedUnit.targW
    self.selectedUnit.facing = destination.targW < previousColumn
        and "left"
        or "right"
    self.selectedUnit.targW = destination.targW
    self.selectedUnit.targH = destination.targH
    self.selectedUnit.visualTargW = previousColumn
    self.movement = {
        unit = self.selectedUnit,
        fromW = previousColumn,
        toW = destination.targW,
        engagementTarget = validEngagement and targetedEnemy or nil,
        elapsed = 0,
    }
    self.destinations = {}
    self.destinationLookup = {}
    self.hoveredDestination = nil
    self.hoveredEngagement = nil
    return {
        unit = self.selectedUnit,
        movementCost = destination.movementCost,
        completed = false,
    }
end

function ArenaMovementSystem:update(dt)
    if not self.movement then
        return
    end

    local movement = self.movement
    movement.elapsed = math.min(movement.elapsed + dt, self.moveDuration)
    local progress = movement.elapsed / self.moveDuration
    local easedProgress = smoothstep(progress)
    movement.unit.visualTargW = movement.fromW
        + (movement.toW - movement.fromW) * easedProgress

    if progress >= 1 then
        movement.unit.visualTargW = nil
        self.movement = nil
        local engagementTarget
        if movement.engagementTarget then
            local engaged = self.enemyArenaSystem:engage(
                movement.unit,
                movement.engagementTarget
            )
            engagementTarget = engaged and movement.engagementTarget or nil
        end

        if self.selectedUnit then
            self:setSelectedUnit(self.selectedUnit)
        end
        return {
            unit = movement.unit,
            engagementTarget = engagementTarget,
        }
    end
end

function ArenaMovementSystem:isMoving()
    return self.movement ~= nil
end

return ArenaMovementSystem
