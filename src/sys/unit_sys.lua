local UnitSystem = {}
UnitSystem.__index = UnitSystem
local FactionSystem = require("src.sys.faction_sys")

local function movementPointMaximum(definition)
    return math.max(0, math.floor(tonumber(
        definition.h_mov or definition.h_move
    ) or 0))
end

function UnitSystem.new(unitDefinitions, arenaGrid)
    local self = setmetatable({}, UnitSystem)
    self.definitions = assert(unitDefinitions, "Unit definitions are required")
    self.grid = assert(arenaGrid, "Arena grid is required")
    self.units = {}
    self.nextInstanceId = 1
    return self
end

function UnitSystem:inject(unitId, population, targW, targH, options)
    options = options or {}
    local definition = self.definitions.get(unitId)
    assert(definition, ("Unknown unit id '%s'"):format(tostring(unitId)))
    population = population or 1
    assert(type(population) == "number" and population >= 1 and population % 1 == 0,
        "Unit population must be a positive integer")
    assert(type(targW) == "number" and targW % 1 == 0
        and targW >= 1 and targW <= self.grid.columns,
        ("targ_w must be between 1 and %d"):format(self.grid.columns))
    assert(type(targH) == "number" and targH % 1 == 0
        and targH >= 1 and targH <= self.grid.rows,
        ("targ_h must be between 1 and %d"):format(self.grid.rows))

    local injectedUnits = {}
    for populationIndex = 1, population do
        local faction = options.faction or definition.start_faction or "neutral"
        local isEnemy = FactionSystem.isEnemy({
            definition = definition,
            faction = faction,
        })
        local maximumMovementPoints = movementPointMaximum(definition)
        local maximumHP = math.max(1, math.floor(tonumber(definition.hp) or 1))
        local currentHP = tonumber(options.currentHP)
            or (options.worldUnit and tonumber(options.worldUnit.hp))
            or maximumHP
        currentHP = math.max(1, math.min(maximumHP, currentHP))
        local unit = {
            instanceId = self.nextInstanceId,
            definition = definition,
            unitId = unitId,
            populationIndex = populationIndex,
            population = population,
            targW = targW,
            targH = targH,
            faction = faction,
            facing = isEnemy and "left" or "right",
            occupied = false,
            maximumMovementPoints = maximumMovementPoints,
            movementPoints = maximumMovementPoints,
            maximumHP = maximumHP,
            hp = currentHP,
            exhausted = false,
            retaliateAvailable = true,
            worldUnit = options.worldUnit,
        }
        self.units[#self.units + 1] = unit
        injectedUnits[#injectedUnits + 1] = unit
        self.nextInstanceId = self.nextInstanceId + 1
    end
    return injectedUnits
end

function UnitSystem:getUnits()
    return self.units
end

function UnitSystem:getMaximumMovementPoints(unit)
    return unit.maximumMovementPoints
        or movementPointMaximum(unit.definition)
end

function UnitSystem:getMovementPoints(unit)
    if unit.movementPoints == nil then
        unit.movementPoints = self:getMaximumMovementPoints(unit)
    end
    return unit.movementPoints
end

function UnitSystem:spendMovementPoints(unit, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local remaining = self:getMovementPoints(unit)
    if amount > remaining then
        return false
    end

    unit.movementPoints = remaining - amount
    return true
end

function UnitSystem:resetMovementPoints(unit)
    unit.movementPoints = self:getMaximumMovementPoints(unit)
end

function UnitSystem:resetAllMovementPoints()
    for _, unit in ipairs(self.units) do
        self:resetMovementPoints(unit)
    end
end

function UnitSystem:readyUnit(unit)
    unit.exhausted = false
end

function UnitSystem:readyAllUnits()
    for _, unit in ipairs(self.units) do
        self:readyUnit(unit)
    end
end

function UnitSystem:readyPlayerUnits()
    for _, unit in ipairs(self.units) do
        if not FactionSystem.isEnemy(unit) then
            self:readyUnit(unit)
        end
    end
end

function UnitSystem:resetRetaliateAction(unit)
    unit.retaliateAvailable = true
end

function UnitSystem:resetAllRetaliateActions()
    for _, unit in ipairs(self.units) do
        self:resetRetaliateAction(unit)
    end
end

function UnitSystem:clearAllOccupied()
    for _, unit in ipairs(self.units) do
        unit.occupied = false
    end
end

function UnitSystem:contains(unit)
    for _, candidate in ipairs(self.units) do
        if candidate == unit then
            return true
        end
    end
    return false
end

function UnitSystem:remove(unit)
    for index = #self.units, 1, -1 do
        if self.units[index] == unit then
            table.remove(self.units, index)
            return true
        end
    end
    return false
end

return UnitSystem
