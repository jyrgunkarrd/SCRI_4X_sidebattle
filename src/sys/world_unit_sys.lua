local UnitDefinitions = require("data.units.index")
local FactionSystem = require("src.sys.faction_sys")

local WorldUnitSystem = {}
WorldUnitSystem.__index = WorldUnitSystem

local function hexKey(q, r)
    return ("%d:%d"):format(q, r)
end

local function addToHex(self, unit)
    local key = hexKey(unit.q, unit.r)
    local units = self.byHex[key]
    if not units then
        units = {}
        self.byHex[key] = units
    end
    units[#units + 1] = unit
end

function WorldUnitSystem.new(siteSystem)
    local self = setmetatable({}, WorldUnitSystem)
    self.siteSystem = assert(siteSystem, "Site system is required")
    self.units = {}
    self.byHex = {}
    self.nextInstanceId = 1

    for _, site in ipairs(self.siteSystem:getUnitSpawnPoints()) do
        local placedSite = self.siteSystem:getAt(site.q, site.r)
        local startingUnits = site.definition.start_units or {}
        assert(type(startingUnits) == "table",
            ("Site '%s' start_units must be a table"):format(site.id))
        for _, entry in ipairs(startingUnits) do
            local definition = UnitDefinitions.get(entry.unitid)
            assert(definition,
                ("Site '%s' references unknown starting unit '%s'"):format(
                    site.id, tostring(entry.unitid)))
            local quantity = entry.qty or 1
            assert(type(quantity) == "number" and quantity >= 1
                and quantity == math.floor(quantity),
                ("Starting unit quantity for '%s' must be a positive integer")
                    :format(definition.id))
            for _ = 1, quantity do
                local unit = {
                    instanceId = self.nextInstanceId,
                    id = definition.id,
                    definition = definition,
                    faction = definition.start_faction or "neutral",
                    siteId = placedSite and placedSite.id or nil,
                    q = site.q,
                    r = site.r,
                    centerX = site.centerX,
                    centerY = site.centerY,
                    maximumMovementPoints = definition.map_move or 0,
                    movementPoints = definition.map_move or 0,
                    exhausted = (definition.map_move or 0) <= 0,
                    maximumHP = math.max(1,
                        math.floor(tonumber(definition.hp) or 1)),
                    hp = math.max(1,
                        math.floor(tonumber(definition.hp) or 1)),
                }
                self.units[#self.units + 1] = unit
                addToHex(self, unit)
                self.nextInstanceId = self.nextInstanceId + 1
            end
        end
    end
    return self
end

function WorldUnitSystem:getUnits()
    return self.units
end

function WorldUnitSystem:getUnitAt(q, r)
    local units = self.byHex[hexKey(q, r)]
    return units and units[#units] or nil
end

function WorldUnitSystem:getUnitsAt(q, r)
    return self.byHex[hexKey(q, r)] or {}
end

function WorldUnitSystem:getUnitsByHex()
    return self.byHex
end

function WorldUnitSystem:getMaximumMovementPoints(unit)
    return unit.maximumMovementPoints or unit.definition.map_move or 0
end

function WorldUnitSystem:getMovementPoints(unit)
    if unit.movementPoints == nil then
        unit.movementPoints = self:getMaximumMovementPoints(unit)
    end
    return unit.movementPoints
end

function WorldUnitSystem:spendMovementPoints(unit, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local remaining = self:getMovementPoints(unit)
    if amount > remaining then
        return false
    end
    unit.movementPoints = remaining - amount
    unit.exhausted = unit.movementPoints <= 0
    return true
end

function WorldUnitSystem:resetAllMovementPoints()
    for _, unit in ipairs(self.units) do
        unit.movementPoints = self:getMaximumMovementPoints(unit)
    end
end

function WorldUnitSystem:readyAllUnits()
    for _, unit in ipairs(self.units) do
        unit.exhausted = self:getMovementPoints(unit) <= 0
    end
end

function WorldUnitSystem:readyPlayerUnits()
    for _, unit in ipairs(self.units) do
        if not FactionSystem.isEnemy(unit) then
            unit.exhausted = false
        end
    end
end

function WorldUnitSystem:resetAllRetaliateActions()
    for _, unit in ipairs(self.units) do
        unit.retaliateAvailable = true
    end
end

function WorldUnitSystem:setFaction(unit, faction)
    assert(unit and unit.instanceId, "A world unit is required")
    assert(type(faction) == "string" and faction ~= "",
        "A unit faction id is required")
    unit.faction = faction
    return unit
end

function WorldUnitSystem:moveUnit(unit, q, r, centerX, centerY)
    assert(unit and unit.instanceId, "A world unit is required")
    local oldKey = hexKey(unit.q, unit.r)
    local oldUnits = self.byHex[oldKey]
    if oldUnits then
        for index = #oldUnits, 1, -1 do
            if oldUnits[index] == unit then
                table.remove(oldUnits, index)
                break
            end
        end
        if #oldUnits == 0 then
            self.byHex[oldKey] = nil
        end
    end
    unit.q, unit.r = q, r
    unit.centerX, unit.centerY = centerX, centerY
    local site = self.siteSystem:getAt(q, r)
    unit.siteId = site and site.id or nil
    addToHex(self, unit)
end

function WorldUnitSystem:remove(unit)
    if not unit then
        return false
    end

    local removed = false
    for index = #self.units, 1, -1 do
        if self.units[index] == unit then
            table.remove(self.units, index)
            removed = true
            break
        end
    end
    if not removed then
        return false
    end

    local key = hexKey(unit.q, unit.r)
    local units = self.byHex[key]
    for index = units and #units or 0, 1, -1 do
        if units[index] == unit then
            table.remove(units, index)
            break
        end
    end
    if units and #units == 0 then
        self.byHex[key] = nil
    end
    return true
end

function WorldUnitSystem:applyCombatResult(result)
    assert(type(result) == "table", "A combat result is required")
    for _, unit in ipairs(result.defeatedUnits or {}) do
        self:remove(unit)
    end
    local encounter = result.encounter or {}
    local attackerWon = result.winner == encounter.attackerFaction
    for _, survivor in ipairs(result.survivors or {}) do
        local unit = survivor.worldUnit
        if unit then
            unit.maximumHP = survivor.maximumHP
                or unit.maximumHP
                or math.max(1, math.floor(tonumber(unit.definition.hp) or 1))
            unit.hp = math.max(1, math.min(
                unit.maximumHP,
                tonumber(survivor.hp) or unit.maximumHP
            ))
            local origin = attackerWon
                and survivor.combatRole == "attacker"
                and encounter.defenderOrigin
                or survivor.worldOrigin
            if origin then
                self:moveUnit(
                    unit,
                    origin.q,
                    origin.r,
                    origin.centerX,
                    origin.centerY
                )
            end
        end
    end
end

return WorldUnitSystem
