local WorldMoveSystem = {}
WorldMoveSystem.__index = WorldMoveSystem
local FactionSystem = require("src.sys.faction_sys")

local SECONDS_PER_HEX = 0.12

local function hexKey(q, r)
    return ("%d:%d"):format(q, r)
end

local function isPlayerControlled(stack)
    if not stack then
        return false
    end
    for _, unit in ipairs(stack.units) do
        if FactionSystem.isEnemy(unit) then
            return false
        end
    end
    return true
end

function WorldMoveSystem.new(worldUnitSystem, worldUnitStackSystem,
        pathfindingSystem, axialToCenter, combatStartSystem)
    local self = setmetatable({}, WorldMoveSystem)
    self.worldUnitSystem = assert(worldUnitSystem, "World unit system is required")
    self.worldUnitStackSystem = assert(worldUnitStackSystem,
        "World unit stack system is required")
    self.pathfindingSystem = assert(pathfindingSystem,
        "World pathfinding system is required")
    self.axialToCenter = assert(axialToCenter, "Axial conversion is required")
    self.combatStartSystem = combatStartSystem
    self.selectedUnit = nil
    self.selectedStack = nil
    self.sourceStack = nil
    self.reachableHexes = {}
    self.reachableByKey = {}
    self.hoveredDestination = nil
    self.movement = nil
    return self
end

function WorldMoveSystem:_rebuildReachableHexes()
    self.reachableHexes = {}
    self.reachableByKey = {}
    self.hoveredDestination = nil
    local stack = self.selectedStack
    if not stack or not isPlayerControlled(stack) then
        return
    end
    local unit = stack.representative
    local movementRange = self.worldUnitStackSystem:getMovementRange(stack)

    for deltaQ = -movementRange, movementRange do
        local minimumR = math.max(-movementRange, -deltaQ - movementRange)
        local maximumR = math.min(movementRange, -deltaQ + movementRange)
        for deltaR = minimumR, maximumR do
            local q = unit.q + deltaQ
            local r = unit.r + deltaR
            local path, cost = self.pathfindingSystem:findPath(
                unit.q, unit.r, q, r, {
                    isPassable = function(pathQ, pathR)
                        local isDestination = pathQ == q and pathR == r
                        return self.worldUnitStackSystem:canEnter(
                            stack,
                            pathQ,
                            pathR,
                            isDestination,
                            self.combatStartSystem
                        )
                    end,
                })
            if path and cost <= movementRange
                and self.worldUnitStackSystem:canEnter(
                    stack, q, r, true, self.combatStartSystem) then
                local entry = {
                    q = q,
                    r = r,
                    cost = cost,
                    path = path,
                    opposingStack = self.worldUnitStackSystem
                        :getOpposingStackAt(stack, q, r),
                }
                self.reachableHexes[#self.reachableHexes + 1] = entry
                self.reachableByKey[hexKey(q, r)] = entry
            end
        end
    end
end

function WorldMoveSystem:_updateSelectionVisibility()
    self.worldUnitStackSystem:updateVisibility()
    if not self.sourceStack or not self.selectedStack then
        return
    end
    for _, unit in ipairs(self.sourceStack.units) do
        unit.worldStackHidden = true
    end
    self.selectedStack.representative.worldStackHidden = nil
end

function WorldMoveSystem:selectAt(q, r)
    if self.movement then
        return self.selectedUnit, self.sourceStack
    end
    self.sourceStack = self.worldUnitStackSystem:getAt(q, r)
    self.selectedStack = self.sourceStack
    self.selectedUnit = self.selectedStack
        and self.selectedStack.representative or nil
    self:_updateSelectionVisibility()
    self:_rebuildReachableHexes()
    return self.selectedUnit, self.selectedStack
end

function WorldMoveSystem:deselect()
    if self.movement then
        return
    end
    self.selectedUnit = nil
    self.selectedStack = nil
    self.sourceStack = nil
    self.worldUnitStackSystem:updateVisibility()
    self:_rebuildReachableHexes()
end

function WorldMoveSystem:getSelectedUnit()
    return self.selectedUnit
end

function WorldMoveSystem:getSelectedStack()
    return self.selectedStack
end

function WorldMoveSystem:getSourceStack()
    return self.sourceStack
end

function WorldMoveSystem:isMoving()
    return self.movement ~= nil
end

function WorldMoveSystem:toggleUnitSelection(unit)
    if self.movement or not self.sourceStack or not unit then
        return self.selectedUnit, self.selectedStack, false
    end
    local belongsToSource = false
    for _, sourceUnit in ipairs(self.sourceStack.units) do
        if sourceUnit == unit then
            belongsToSource = true
            break
        end
    end
    if not belongsToSource then
        return self.selectedUnit, self.selectedStack, false
    end

    local selectedUnits = {}
    local wasSelected = false
    if self.selectedStack then
        for _, selectedUnit in ipairs(self.selectedStack.units) do
            if selectedUnit == unit then
                wasSelected = true
            else
                selectedUnits[#selectedUnits + 1] = selectedUnit
            end
        end
    end
    if not wasSelected then
        selectedUnits[#selectedUnits + 1] = unit
    end
    self.selectedStack = self.worldUnitStackSystem:makeSelection(
        self.sourceStack.q,
        self.sourceStack.r,
        selectedUnits
    )
    if self.selectedStack then
        self.selectedStack.panelRowByUnit = self.sourceStack.panelRowByUnit
    end
    self.selectedUnit = self.selectedStack
        and self.selectedStack.representative or nil
    self:_updateSelectionVisibility()
    self:_rebuildReachableHexes()
    return self.selectedUnit, self.selectedStack, true
end

function WorldMoveSystem:selectUnitsWithMovementRemaining()
    if self.movement or not self.sourceStack then
        return self.selectedUnit, self.selectedStack, false
    end
    local selectedUnits = {}
    for _, unit in ipairs(self.sourceStack.units) do
        if self.worldUnitSystem:getMovementPoints(unit) > 0 then
            selectedUnits[#selectedUnits + 1] = unit
        end
    end
    if #selectedUnits == 0 then
        return self.selectedUnit, self.selectedStack, false
    end
    self.selectedStack = self.worldUnitStackSystem:makeSelection(
        self.sourceStack.q,
        self.sourceStack.r,
        selectedUnits
    )
    self.selectedStack.panelRowByUnit = self.sourceStack.panelRowByUnit
    self.selectedUnit = self.selectedStack
        and self.selectedStack.representative or nil
    self:_updateSelectionVisibility()
    self:_rebuildReachableHexes()
    return self.selectedUnit, self.selectedStack, true
end

function WorldMoveSystem:getReachableHexes()
    return self.reachableHexes
end

function WorldMoveSystem:setHoveredHex(q, r)
    local destination = self.selectedUnit
        and self.reachableByKey[hexKey(q, r)] or nil
    if destination and destination.cost > 0 then
        self.hoveredDestination = destination
    else
        self.hoveredDestination = nil
    end
end

function WorldMoveSystem:clearHoveredHex()
    self.hoveredDestination = nil
end

function WorldMoveSystem:getMovementPreview()
    if not self.selectedUnit or not self.hoveredDestination then
        return nil
    end
    return {
        unit = self.selectedUnit,
        destination = self.hoveredDestination,
        path = self.hoveredDestination.path,
    }
end

function WorldMoveSystem:moveSelectedTo(q, r)
    if self.movement then
        return false
    end
    local stack = self.selectedStack
    local unit = self.selectedUnit
    local destination = isPlayerControlled(stack)
        and self.reachableByKey[hexKey(q, r)] or nil
    if not destination then
        return false
    end
    for _, movingUnit in ipairs(stack.units) do
        assert(self.worldUnitSystem:spendMovementPoints(
            movingUnit,
            destination.cost
        ), "World movement cost exceeded a selected unit's remaining points")
    end
    if destination.opposingStack then
        self.reachableHexes = {}
        self.reachableByKey = {}
        self.hoveredDestination = nil
        self.combatStartSystem:initiate(stack, destination.opposingStack)
        return true, destination.path, true
    end
    local points = {}
    for _, pathHex in ipairs(destination.path) do
        local centerX, centerY = self.axialToCenter(pathHex.q, pathHex.r)
        points[#points + 1] = { x = centerX, y = centerY }
    end
    self.movement = {
        unit = unit,
        units = stack.units,
        destination = destination,
        points = points,
        segment = 1,
        segmentTime = 0,
    }
    for _, movingUnit in ipairs(stack.units) do
        movingUnit.isMoving = true
        movingUnit.siteId = nil
    end
    self.worldUnitStackSystem:updateVisibility()
    self.reachableHexes = {}
    self.reachableByKey = {}
    self.hoveredDestination = nil
    return true, destination.path
end

function WorldMoveSystem:update(dt)
    local movement = self.movement
    if not movement then
        return
    end

    movement.segmentTime = movement.segmentTime + dt
    while movement.segmentTime >= SECONDS_PER_HEX
        and movement.segment < #movement.points do
        movement.segmentTime = movement.segmentTime - SECONDS_PER_HEX
        movement.segment = movement.segment + 1
    end

    if movement.segment >= #movement.points then
        local destination = movement.destination
        local finalPoint = movement.points[#movement.points]
        for _, unit in ipairs(movement.units) do
            unit.centerX = finalPoint.x
            unit.centerY = finalPoint.y
            self.worldUnitSystem:moveUnit(
                unit,
                destination.q,
                destination.r,
                finalPoint.x,
                finalPoint.y
            )
            unit.isMoving = nil
        end
        self.worldUnitStackSystem:updateVisibility()
        self.selectedStack = self.worldUnitStackSystem:getAt(
            destination.q,
            destination.r
        )
        self.sourceStack = self.selectedStack
        self.selectedUnit = self.selectedStack.representative
        self.movement = nil
        self:_rebuildReachableHexes()
        return
    end

    local from = movement.points[movement.segment]
    local to = movement.points[movement.segment + 1]
    local progress = movement.segmentTime / SECONDS_PER_HEX
    local eased = progress * progress * (3 - 2 * progress)
    local centerX = from.x + (to.x - from.x) * eased
    local centerY = from.y + (to.y - from.y) * eased
    for _, unit in ipairs(movement.units) do
        unit.centerX = centerX
        unit.centerY = centerY
    end
end

return WorldMoveSystem
