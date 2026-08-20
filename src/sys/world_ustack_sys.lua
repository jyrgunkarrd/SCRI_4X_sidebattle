local WorldUnitStackSystem = {}
WorldUnitStackSystem.__index = WorldUnitStackSystem
local FactionSystem = require("src.sys.faction_sys")

local MAXIMUM_STACK_SIZE = 12

local function priority(unit)
    local value = unit.definition.stack_prio
    return type(value) == "number" and value or math.huge
end

local function representativeOrder(left, right)
    local leftPriority = priority(left)
    local rightPriority = priority(right)
    if leftPriority ~= rightPriority then
        return leftPriority < rightPriority
    end
    return left.instanceId < right.instanceId
end

function WorldUnitStackSystem.new(worldUnitSystem)
    local self = setmetatable({}, WorldUnitStackSystem)
    self.worldUnitSystem = assert(worldUnitSystem, "World unit system is required")
    self.maximumSize = MAXIMUM_STACK_SIZE
    self:updateVisibility()
    return self
end

function WorldUnitStackSystem:_makeStack(q, r, units)
    if not units or #units == 0 then
        return nil
    end
    local ordered = {}
    local faction = FactionSystem.getFaction(units[1])
    for _, unit in ipairs(units) do
        assert(FactionSystem.getFaction(unit) == faction,
            ("Units from different factions cannot share hex %d:%d"):format(
                q, r))
        ordered[#ordered + 1] = unit
    end
    table.sort(ordered, representativeOrder)
    local panelRowByUnit = {}
    for index, unit in ipairs(ordered) do
        panelRowByUnit[unit] = math.floor((index - 1) / 3) + 1
    end
    return {
        q = q,
        r = r,
        units = ordered,
        representative = ordered[1],
        faction = faction,
        panelRowByUnit = panelRowByUnit,
    }
end

function WorldUnitStackSystem:getAt(q, r)
    return self:_makeStack(q, r, self.worldUnitSystem:getUnitsAt(q, r))
end

function WorldUnitStackSystem:makeSelection(q, r, units)
    return self:_makeStack(q, r, units)
end

function WorldUnitStackSystem:getMovementRange(stack)
    local movementRange
    for _, unit in ipairs(stack.units) do
        local value = self.worldUnitSystem:getMovementPoints(unit)
        assert(type(value) == "number" and value >= 0
            and value == math.floor(value),
            ("Unit '%s' map_move must be a non-negative integer"):format(
                unit.id))
        movementRange = movementRange and math.min(movementRange, value) or value
    end
    return movementRange or 0
end

function WorldUnitStackSystem.getFormationName(unitCount)
    assert(type(unitCount) == "number" and unitCount >= 1
        and unitCount <= MAXIMUM_STACK_SIZE,
        "Formation size must be between 1 and 12 units")
    if unitCount <= 6 then
        return "Squad"
    end
    if unitCount <= 11 then
        return "Platoon"
    end
    return "Company"
end

function WorldUnitStackSystem:getOpposingStackAt(stack, q, r)
    local occupants = self:getAt(q, r)
    if occupants and occupants.faction ~= stack.faction then
        return occupants
    end
    return nil
end

function WorldUnitStackSystem:canEnter(stack, q, r, allowCombat, combatStartSystem)
    if stack.q == q and stack.r == r then
        return true
    end
    local occupants = self.worldUnitSystem:getUnitsAt(q, r)
    if #occupants > 0 then
        local occupyingStack = self:getAt(q, r)
        if occupyingStack.faction ~= stack.faction then
            return allowCombat and combatStartSystem
                and combatStartSystem:canInitiate(stack, occupyingStack)
                or false
        end
    end
    return #stack.units + #occupants <= self.maximumSize
end

function WorldUnitStackSystem:updateVisibility()
    for _, unit in ipairs(self.worldUnitSystem:getUnits()) do
        unit.worldStackHidden = true
    end
    for _, units in pairs(self.worldUnitSystem:getUnitsByHex()) do
        assert(#units <= self.maximumSize,
            ("World unit stack exceeds the %d-unit limit"):format(
                self.maximumSize))
        local stationary = {}
        local moving = {}
        for _, unit in ipairs(units) do
            local group = unit.isMoving and moving or stationary
            group[#group + 1] = unit
        end
        local first = units[1]
        local stationaryStack = self:_makeStack(first.q, first.r, stationary)
        local movingStack = self:_makeStack(first.q, first.r, moving)
        if stationaryStack then
            stationaryStack.representative.worldStackHidden = nil
        end
        if movingStack then
            movingStack.representative.worldStackHidden = nil
        end
    end
end

return WorldUnitStackSystem
