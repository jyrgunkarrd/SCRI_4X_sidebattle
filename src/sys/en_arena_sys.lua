local EnemyArenaSystem = {}
EnemyArenaSystem.__index = EnemyArenaSystem

local function cellKey(targW, targH)
    return targW .. ":" .. targH
end

local function instanceOrder(left, right)
    return left.instanceId < right.instanceId
end

function EnemyArenaSystem.new(arenaGrid)
    local self = setmetatable({}, EnemyArenaSystem)
    self.grid = assert(arenaGrid, "Arena grid is required")
    return self
end

function EnemyArenaSystem:isEnemy(unit)
    return unit.isEnemy == true or unit.definition.enemy == true
end

function EnemyArenaSystem:getSize(unit)
    return math.max(1, math.floor(tonumber(unit.definition.size) or 1))
end

function EnemyArenaSystem:getEngagers(enemy)
    enemy.engagedBy = enemy.engagedBy or {}
    return enemy.engagedBy
end

function EnemyArenaSystem:getEngagedSize(enemy)
    local total = 0
    for _, unit in ipairs(self:getEngagers(enemy)) do
        total = total + self:getSize(unit)
    end
    return total
end

function EnemyArenaSystem:isOccupied(enemy)
    return self:getEngagedSize(enemy) >= self:getSize(enemy)
end

function EnemyArenaSystem:canEngage(enemy)
    return self:isEnemy(enemy)
        and #self:getEngagers(enemy) < self:getSize(enemy)
end

function EnemyArenaSystem:isAtEngagementCapacity(enemy)
    return self:isEnemy(enemy)
        and #self:getEngagers(enemy) >= self:getSize(enemy)
end

function EnemyArenaSystem:disengage(unit)
    local enemy = unit.engagedWith
    if not enemy then
        unit.flanking = false
        return
    end

    local engagers = self:getEngagers(enemy)
    for index = #engagers, 1, -1 do
        if engagers[index] == unit then
            table.remove(engagers, index)
        end
    end
    unit.engagedWith = nil
    unit.flanking = false
end

function EnemyArenaSystem:engage(unit, enemy)
    if self:isEnemy(unit) or not self:canEngage(enemy)
        or unit.targW ~= enemy.targW or unit.targH ~= enemy.targH then
        return false
    end

    local isFlanking = self:isOccupied(enemy)
    self:disengage(unit)
    local engagers = self:getEngagers(enemy)
    engagers[#engagers + 1] = unit
    unit.engagedWith = enemy
    unit.flanking = isFlanking
    return true
end

function EnemyArenaSystem:isFlanking(unit)
    return unit.flanking == true and unit.engagedWith ~= nil
end

function EnemyArenaSystem:isFlanked(enemy)
    if not self:isEnemy(enemy) then
        return false
    end

    for _, unit in ipairs(self:getEngagers(enemy)) do
        if self:isFlanking(unit) then
            return true
        end
    end

    return false
end

function EnemyArenaSystem:getEnemiesAt(units, targW, targH)
    local enemies = {}
    for _, unit in ipairs(units) do
        if self:isEnemy(unit) and unit.targW == targW and unit.targH == targH then
            enemies[#enemies + 1] = unit
        end
    end
    return enemies
end

function EnemyArenaSystem:cellHasBlockingEnemy(units, targW, targH)
    for _, enemy in ipairs(self:getEnemiesAt(units, targW, targH)) do
        if not self:isOccupied(enemy) then
            return true
        end
    end
    return false
end

function EnemyArenaSystem:_placeInHalf(units, side)
    table.sort(units, instanceOrder)

    local halfCenter = side * self.grid.cellSize / 4
    local usableWidth = math.max(0, self.grid.cellSize / 2 - 32)
    local spacing = #units > 1
        and math.min(32, usableWidth / (#units - 1))
        or 0

    for index, unit in ipairs(units) do
        unit.arenaCellOffsetX = halfCenter
            + (index - (#units + 1) / 2) * spacing
    end
end

function EnemyArenaSystem:update(units)
    local cells = {}

    for _, unit in ipairs(units) do
        unit.arenaCellOffsetX = nil

        local key = cellKey(unit.targW, unit.targH)
        local cell = cells[key]
        if not cell then
            cell = { players = {}, enemies = {}, flankers = {} }
            cells[key] = cell
        end

        local faction
        if self:isEnemy(unit) then
            faction = cell.enemies
        elseif self:isFlanking(unit) then
            faction = cell.flankers
        else
            faction = cell.players
        end
        faction[#faction + 1] = unit
    end

    for _, cell in pairs(cells) do
        if #cell.enemies > 0 and (#cell.players > 0 or #cell.flankers > 0) then
            if #cell.players > 0 then
                self:_placeInHalf(cell.players, -1)
            end

            local enemySide = {}
            for _, enemy in ipairs(cell.enemies) do
                enemySide[#enemySide + 1] = enemy
            end
            for _, flanker in ipairs(cell.flankers) do
                enemySide[#enemySide + 1] = flanker
            end
            self:_placeInHalf(enemySide, 1)
        end
    end
end

return EnemyArenaSystem
