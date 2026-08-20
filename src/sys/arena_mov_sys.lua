local ArenaMovementSystem = {}
ArenaMovementSystem.__index = ArenaMovementSystem
local FactionSystem = require("src.sys.faction_sys")

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
    self.hoveredMeleeTarget = nil
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
    self.hoveredMeleeTarget = nil

    if not unit or unit.exhausted or self.movement
        or FactionSystem.isEnemy(unit) then
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

    if #currentEnemies > 0 then
        local destination = {
            targW = unit.targW,
            targH = unit.targH,
            movementCost = 0,
            enemies = currentEnemies,
            requiresMeleeTarget = true,
        }
        self.destinations[#self.destinations + 1] = destination
        self.destinationLookup[cellKey(unit.targW, unit.targH)] = destination
        if blockedInCurrentCell then
            return
        end
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
            local availableSlot = self.enemyArenaSystem:getAvailableSlot(
                units,
                unit,
                targW,
                unit.targH
            )
            if availableSlot then
                local destination = {
                    targW = targW,
                    targH = unit.targH,
                    movementCost = distance,
                    enemies = enemies,
                    requiresMeleeTarget = isBlocked,
                    arenaSlot = availableSlot,
                }
                self.destinations[#self.destinations + 1] = destination
                self.destinationLookup[cellKey(targW, unit.targH)] = destination
            end

            if isBlocked then
                break
            end
        end
    end
end

function ArenaMovementSystem:getDestinations()
    return self.destinations
end

function ArenaMovementSystem:getFurthestOpenDestination(direction)
    if not self.selectedUnit or (direction ~= -1 and direction ~= 1) then
        return nil
    end

    local originW = self.selectedUnit.targW
    local furthest
    for _, destination in ipairs(self.destinations) do
        local delta = destination.targW - originW
        local isInDirection = direction < 0 and delta < 0
            or direction > 0 and delta > 0
        if isInDirection and not destination.requiresMeleeTarget
            and (not furthest
                or math.abs(delta) > math.abs(furthest.targW - originW)) then
            furthest = destination
        end
    end
    return furthest
end

function ArenaMovementSystem:getHoveredDestination()
    return self.hoveredDestination
end

function ArenaMovementSystem:getHoveredMeleeTarget()
    return self.hoveredMeleeTarget
end

function ArenaMovementSystem:worldToCell(worldX, worldY)
    local localX = worldX - self.grid.x
    local localY = worldY - self.grid.y

    if localX < 0 or localY < 0
        or localX >= self.grid.width or localY >= self.grid.height then
        return nil, nil
    end

    local targW = math.floor(localX / self.grid.cellWidth) + 1
    local visualRow = math.floor(localY / self.grid.cellHeight)
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
    local validMeleeTarget = destination
        and hoveredEnemy
        and containsUnit(destination.enemies, hoveredEnemy)
        and (hoveredEnemy.hp or 0) > 0

    self.hoveredMeleeTarget = validMeleeTarget and hoveredEnemy or nil
    self.hoveredDestination = destination
        and (not destination.requiresMeleeTarget or validMeleeTarget)
        and destination
        or nil
    return self.hoveredDestination
end

function ArenaMovementSystem:clearHover()
    self.hoveredDestination = nil
    self.hoveredMeleeTarget = nil
end

function ArenaMovementSystem:moveSelectedToWorld(worldX, worldY, targetedEnemy)
    if not self.selectedUnit
        or self.selectedUnit.exhausted or self.movement
        or FactionSystem.isEnemy(self.selectedUnit) then
        return false
    end

    local targW, targH = self:worldToCell(worldX, worldY)
    local destination = targW
        and self.destinationLookup[cellKey(targW, targH)]
        or nil

    if not destination then
        return false
    end

    local validMeleeTarget = targetedEnemy
        and containsUnit(destination.enemies, targetedEnemy)
        and (targetedEnemy.hp or 0) > 0

    if destination.requiresMeleeTarget and not validMeleeTarget then
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
        local enemyOffset = targetedEnemy.arenaCellOffsetX or 0
        self.selectedUnit.facing = enemyOffset < selectedOffset
            and "left"
            or "right"
        local completed = {
            unit = self.selectedUnit,
            meleeTarget = targetedEnemy,
            movementCost = 0,
            completed = true,
        }
        self.destinations = {}
        self.destinationLookup = {}
        self.hoveredDestination = nil
        self.hoveredMeleeTarget = nil
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
        toSlot = destination.arenaSlot,
        meleeTarget = validMeleeTarget and targetedEnemy or nil,
        elapsed = 0,
    }
    self.destinations = {}
    self.destinationLookup = {}
    self.hoveredDestination = nil
    self.hoveredMeleeTarget = nil
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
        self.enemyArenaSystem:commitUnitSlot(
            movement.unit,
            movement.toW,
            movement.unit.targH,
            movement.toSlot
        )
        movement.unit.visualTargW = nil
        self.movement = nil
        if self.selectedUnit then
            self:setSelectedUnit(self.selectedUnit)
        end
        return {
            unit = movement.unit,
            meleeTarget = movement.meleeTarget,
        }
    end
end

function ArenaMovementSystem:isMoving()
    return self.movement ~= nil
end

return ArenaMovementSystem
