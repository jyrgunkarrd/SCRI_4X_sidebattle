local FactionSystem = require("src.sys.faction_sys")
local ArenaCellLayout = require("src.rndr.arena_cell_layout")

local EnemyArenaSystem = {}
EnemyArenaSystem.__index = EnemyArenaSystem

function EnemyArenaSystem.new(arenaGrid)
    local self = setmetatable({}, EnemyArenaSystem)
    self.grid = assert(arenaGrid, "Arena grid is required")
    self.cellLayout = ArenaCellLayout.new(self.grid)
    return self
end

function EnemyArenaSystem:isEnemy(unit)
    return FactionSystem.isEnemy(unit)
end

function EnemyArenaSystem:isOccupied(unit)
    return unit and unit.occupied == true
end

function EnemyArenaSystem:getEnemiesAt(units, targW, targH)
    local enemies = {}
    for _, unit in ipairs(units) do
        if self:isEnemy(unit) and (unit.hp or 0) > 0
            and unit.targW == targW and unit.targH == targH then
            enemies[#enemies + 1] = unit
        end
    end
    return enemies
end

function EnemyArenaSystem:getPlayersAt(units, targW, targH)
    local players = {}
    for _, unit in ipairs(units) do
        if not self:isEnemy(unit) and (unit.hp or 0) > 0
            and unit.targW == targW and unit.targH == targH then
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

function EnemyArenaSystem:cellHasBlockingEnemy(units, targW, targH)
    for _, enemy in ipairs(self:getEnemiesAt(units, targW, targH)) do
        if not self:isOccupied(enemy) then
            return true
        end
    end
    return false
end

function EnemyArenaSystem:cellHasBlockingHostile(units, unit)
    if self:isEnemy(unit) then
        return self:cellHasBlockingPlayer(units, unit.targW, unit.targH)
    end
    return self:cellHasBlockingEnemy(units, unit.targW, unit.targH)
end

function EnemyArenaSystem:update(units)
    self.cellLayout:update(units)
end

function EnemyArenaSystem:getUnitAtWorldPosition(units, worldX, worldY,
        predicate)
    return self.cellLayout:getUnitAt(units, worldX, worldY, predicate)
end

function EnemyArenaSystem:getUnitInSlot(units, targW, targH, slot, predicate)
    return self.cellLayout:getUnitInSlot(
        units,
        targW,
        targH,
        slot,
        predicate
    )
end

function EnemyArenaSystem:getAvailableSlot(units, unit, targW, targH)
    return self.cellLayout:getAvailableSlot(units, unit, targW, targH)
end

function EnemyArenaSystem:canEnterCell(units, unit, targW, targH)
    return self.cellLayout:canEnter(units, unit, targW, targH)
end

function EnemyArenaSystem:commitUnitSlot(unit, targW, targH, slot)
    self.cellLayout:commitSlot(unit, targW, targH, slot)
end

function EnemyArenaSystem:getSlotOffset(slot)
    return self.cellLayout:getSlotOffset(slot)
end

function EnemyArenaSystem:drawCellSlots()
    self.cellLayout:draw()
end

return EnemyArenaSystem
