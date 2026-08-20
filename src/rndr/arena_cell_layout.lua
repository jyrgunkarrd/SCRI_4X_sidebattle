local FactionSystem = require("src.sys.faction_sys")

local ArenaCellLayout = {}
ArenaCellLayout.__index = ArenaCellLayout

local SLOT_COUNT = 6
local PLAYER_SLOTS = { 3, 2, 1 }
local ENEMY_SLOTS = { 4, 5, 6 }
local LAYER_LIFT_PER_STEP = 8

local function cellKey(targW, targH)
    return targW .. ":" .. targH
end

local function unitLayer(unit)
    return tonumber(unit.definition.layer) or 1
end

local function factionCellKey(unit)
    return cellKey(unit.targW, unit.targH)
        .. (FactionSystem.isEnemy(unit) and ":enemy" or ":player")
end

function ArenaCellLayout.new(arenaGrid)
    local self = setmetatable({}, ArenaCellLayout)
    self.grid = assert(arenaGrid, "Arena grid is required")
    return self
end

function ArenaCellLayout:_slotsFor(unit)
    return FactionSystem.isEnemy(unit) and ENEMY_SLOTS or PLAYER_SLOTS
end

function ArenaCellLayout:getAvailableSlot(units, unit, targW, targH)
    local destinationKey = cellKey(targW, targH)
    if unit.arenaSlot and unit.arenaSlotCellKey == destinationKey then
        return unit.arenaSlot
    end
    local occupied = {}
    for _, occupant in ipairs(units) do
        if occupant ~= unit and occupant.targW == targW
            and occupant.targH == targH
            and FactionSystem.isEnemy(occupant) == FactionSystem.isEnemy(unit)
            and occupant.arenaSlot then
            occupied[occupant.arenaSlot] = true
        end
    end
    for _, slot in ipairs(self:_slotsFor(unit)) do
        if not occupied[slot] then
            return slot
        end
    end
    return nil
end

function ArenaCellLayout:canEnter(units, unit, targW, targH)
    return self:getAvailableSlot(units, unit, targW, targH) ~= nil
end

function ArenaCellLayout:commitSlot(unit, targW, targH, slot)
    unit.arenaSlot = assert(slot, "An arena destination slot is required")
    unit.arenaSlotCellKey = cellKey(targW, targH)
end

function ArenaCellLayout:_slotOffset(slot)
    local slotWidth = self.grid.cellWidth / SLOT_COUNT
    return (slot - (SLOT_COUNT + 1) / 2) * slotWidth
end

function ArenaCellLayout:getSlotOffset(slot)
    return self:_slotOffset(slot)
end

function ArenaCellLayout:update(units)
    local layersByFactionCell = {}
    for _, unit in ipairs(units) do
        local key = factionCellKey(unit)
        local layer = unitLayer(unit)
        local layers = layersByFactionCell[key]
        if not layers then
            layers = {}
            layersByFactionCell[key] = layers
        end
        layers[layer] = true
    end

    local layerRankByFactionCell = {}
    for key, layerSet in pairs(layersByFactionCell) do
        local orderedLayers = {}
        for layer in pairs(layerSet) do
            orderedLayers[#orderedLayers + 1] = layer
        end
        table.sort(orderedLayers)

        local ranks = {}
        for index, layer in ipairs(orderedLayers) do
            ranks[layer] = index - 1
        end
        layerRankByFactionCell[key] = ranks
    end

    for _, unit in ipairs(units) do
        local currentKey = cellKey(unit.targW, unit.targH)
        if not unit.visualTargW and unit.arenaSlotCellKey ~= currentKey then
            self:commitSlot(
                unit,
                unit.targW,
                unit.targH,
                self:getAvailableSlot(units, unit, unit.targW, unit.targH)
            )
        end
        assert(unit.arenaSlot,
            ("No faction slot is available in arena cell %s"):format(
                currentKey))
        unit.arenaCellOffsetX = self:_slotOffset(unit.arenaSlot)
        local layerRanks = layerRankByFactionCell[factionCellKey(unit)]
        unit.arenaLayerOffsetY = layerRanks[unitLayer(unit)]
            * LAYER_LIFT_PER_STEP
    end
end

function ArenaCellLayout:worldToSlot(worldX, worldY)
    local localX = worldX - self.grid.x
    local localY = worldY - self.grid.y
    if localX < 0 or localY < 0
        or localX >= self.grid.width or localY >= self.grid.height then
        return nil, nil, nil
    end
    local targW = math.floor(localX / self.grid.cellWidth) + 1
    local visualRow = math.floor(localY / self.grid.cellHeight)
    local targH = self.grid.rows - visualRow
    local withinCellX = localX % self.grid.cellWidth
    local slotWidth = self.grid.cellWidth / SLOT_COUNT
    local slot = math.min(SLOT_COUNT,
        math.floor(withinCellX / slotWidth) + 1)
    return targW, targH, slot
end

function ArenaCellLayout:getUnitAt(units, worldX, worldY, predicate)
    local targW, targH, slot = self:worldToSlot(worldX, worldY)
    if not slot then
        return nil
    end
    return self:getUnitInSlot(units, targW, targH, slot, predicate)
end

function ArenaCellLayout:getUnitInSlot(units, targW, targH, slot, predicate)
    if not slot or slot < 1 or slot > SLOT_COUNT then
        return nil
    end
    for _, unit in ipairs(units) do
        if unit.targW == targW and unit.targH == targH
            and unit.arenaSlot == slot
            and (not predicate or predicate(unit)) then
            return unit
        end
    end
    return nil
end

function ArenaCellLayout:draw()
    local slotWidth = self.grid.cellWidth / SLOT_COUNT
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.38, 0.66, 0.9, 0.22)
    for row = 1, self.grid.rows do
        local top = self.grid.y + (row - 1) * self.grid.cellHeight
        local bottom = top + self.grid.cellHeight
        for column = 1, self.grid.columns do
            local left = self.grid.x + (column - 1) * self.grid.cellWidth
            for slot = 1, SLOT_COUNT - 1 do
                local x = math.floor(left + slot * slotWidth) + 0.5
                love.graphics.line(x, top, x, bottom)
            end
            local factionBoundary = math.floor(left + 3 * slotWidth) + 0.5
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.62, 0.78, 0.94, 0.42)
            love.graphics.line(factionBoundary, top, factionBoundary, bottom)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.38, 0.66, 0.9, 0.22)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaCellLayout
