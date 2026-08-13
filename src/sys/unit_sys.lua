local UnitSystem = {}
UnitSystem.__index = UnitSystem

function UnitSystem.new(unitDefinitions, arenaGrid)
    local self = setmetatable({}, UnitSystem)
    self.definitions = assert(unitDefinitions, "Unit definitions are required")
    self.grid = assert(arenaGrid, "Arena grid is required")
    self.units = {}
    self.nextInstanceId = 1
    return self
end

function UnitSystem:inject(unitId, population, targW, targH)
    local definition = self.definitions.get(unitId)
    assert(definition, ("Unknown unit id '%s'"):format(tostring(unitId)))
    assert(type(definition.size) == "number"
        and definition.size >= 1
        and definition.size % 1 == 0,
        ("Unit '%s' must have a positive integer size"):format(unitId))

    population = population or 1
    assert(type(population) == "number" and population >= 1 and population % 1 == 0,
        "Unit population must be a positive integer")
    assert(type(targW) == "number" and targW % 1 == 0
        and targW >= 1 and targW <= self.grid.columns,
        ("targ_w must be between 1 and %d"):format(self.grid.columns))
    assert(type(targH) == "number" and targH % 1 == 0
        and targH >= 1 and targH <= self.grid.rows,
        ("targ_h must be between 1 and %d"):format(self.grid.rows))

    for populationIndex = 1, population do
        local isEnemy = definition.enemy == true
        self.units[#self.units + 1] = {
            instanceId = self.nextInstanceId,
            definition = definition,
            unitId = unitId,
            populationIndex = populationIndex,
            population = population,
            targW = targW,
            targH = targH,
            isEnemy = isEnemy,
            facing = isEnemy and "left" or "right",
            flanking = false,
        }
        self.nextInstanceId = self.nextInstanceId + 1
    end
end

function UnitSystem:getUnits()
    return self.units
end

return UnitSystem
