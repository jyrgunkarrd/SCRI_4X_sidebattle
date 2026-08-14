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

function EnemyArenaSystem:canEngage(unit)
    return unit ~= nil
        and (unit.hp or 0) > 0
        and #self:getEngagers(unit) < self:getSize(unit)
end

function EnemyArenaSystem:isAtEngagementCapacity(unit)
    return unit ~= nil
        and #self:getEngagers(unit) >= self:getSize(unit)
end

function EnemyArenaSystem:isEngaged(unit)
    return unit ~= nil
        and (unit.engagedWith ~= nil or #self:getEngagers(unit) > 0)
end

function EnemyArenaSystem:getEngagedOpponents(unit)
    local opponents = {}
    if not unit then
        return opponents
    end
    if unit.engagedWith then
        opponents[#opponents + 1] = unit.engagedWith
    end
    for _, engager in ipairs(self:getEngagers(unit)) do
        opponents[#opponents + 1] = engager
    end
    return opponents
end

function EnemyArenaSystem:getPrimaryOpponent(unit)
    local opponents = self:getEngagedOpponents(unit)
    table.sort(opponents, instanceOrder)
    return opponents[1]
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

function EnemyArenaSystem:engage(unit, target)
    if not unit or not target or unit == target
        or self:isEnemy(unit) == self:isEnemy(target)
        or not self:canEngage(target)
        or unit.targW ~= target.targW or unit.targH ~= target.targH then
        return false
    end

    local isFlanking = self:isOccupied(target)
    self:disengage(unit)
    local engagers = self:getEngagers(target)
    engagers[#engagers + 1] = unit
    unit.engagedWith = target
    unit.flanking = isFlanking
    return true
end

function EnemyArenaSystem:isFlanking(unit)
    return unit.flanking == true and unit.engagedWith ~= nil
end

function EnemyArenaSystem:isFlanked(unit)
    for _, engager in ipairs(self:getEngagers(unit)) do
        if self:isFlanking(engager) then
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

function EnemyArenaSystem:getPlayersAt(units, targW, targH)
    local players = {}
    for _, unit in ipairs(units) do
        if not self:isEnemy(unit)
            and (unit.hp or 0) > 0
            and unit.targW == targW
            and unit.targH == targH then
            players[#players + 1] = unit
        end
    end
    return players
end

function EnemyArenaSystem:getEngageablePlayersAt(units, targW, targH)
    local players = {}
    for _, unit in ipairs(self:getPlayersAt(units, targW, targH)) do
        if self:canEngage(unit) then
            players[#players + 1] = unit
        end
    end
    return players
end

function EnemyArenaSystem:cellHasBlockingPlayer(units, targW, targH)
    for _, player in ipairs(self:getPlayersAt(units, targW, targH)) do
        if not self:isOccupied(player) then
            return true
        end
    end
    return false
end

function EnemyArenaSystem:engageEnemyWithPlayer(enemy, player)
    if not self:isEnemy(enemy) or self:isEnemy(player)
        or not self:canEngage(player) then
        return false
    end
    return self:engage(enemy, player)
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
            cell = {
                players = {},
                enemies = {},
                playerFlankers = {},
                enemyFlankers = {},
            }
            cells[key] = cell
        end

        local faction
        if self:isFlanking(unit) and self:isEnemy(unit) then
            faction = cell.enemyFlankers
        elseif self:isFlanking(unit) then
            faction = cell.playerFlankers
        elseif self:isEnemy(unit) then
            faction = cell.enemies
        else
            faction = cell.players
        end
        faction[#faction + 1] = unit
    end

    for _, cell in pairs(cells) do
        local playerSide = {}
        for _, player in ipairs(cell.players) do
            playerSide[#playerSide + 1] = player
        end
        for _, flanker in ipairs(cell.enemyFlankers) do
            playerSide[#playerSide + 1] = flanker
        end

        local enemySide = {}
        for _, enemy in ipairs(cell.enemies) do
            enemySide[#enemySide + 1] = enemy
        end
        for _, flanker in ipairs(cell.playerFlankers) do
            enemySide[#enemySide + 1] = flanker
        end

        if #playerSide > 0 and #enemySide > 0 then
            self:_placeInHalf(playerSide, -1)
            self:_placeInHalf(enemySide, 1)
        end
    end
end

return EnemyArenaSystem
