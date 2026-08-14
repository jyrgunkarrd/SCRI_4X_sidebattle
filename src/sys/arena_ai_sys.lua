local ArenaAISystem = {}
ArenaAISystem.__index = ArenaAISystem

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

local function remainingHealthRatio(preview)
    return math.max(0, preview.currentHP - preview.totalDamage)
        / preview.maximumHP
end

local function unitOrder(left, right)
    if left.targW ~= right.targW then
        return left.targW < right.targW
    end
    if left.targH ~= right.targH then
        return left.targH < right.targH
    end
    return left.instanceId < right.instanceId
end

function ArenaAISystem.new(
    arenaGrid,
    unitSystem,
    enemyArenaSystem,
    combatSystem,
    options
)
    options = options or {}

    local self = setmetatable({}, ArenaAISystem)
    self.grid = assert(arenaGrid, "Arena grid is required")
    self.unitSystem = assert(unitSystem, "Unit system is required")
    self.enemyArenaSystem = assert(
        enemyArenaSystem,
        "Enemy arena system is required"
    )
    self.combatSystem = assert(combatSystem, "Combat system is required")
    self.initialDelay = options.initialDelay or 0.8
    self.actionDelay = options.actionDelay or 0.18
    self.moveDuration = options.moveDuration or 0.22
    self.phaseActive = false
    self.queue = {}
    self.queueIndex = 0
    self.currentUnit = nil
    self.movement = nil
    self.waitingForAttack = false
    self.delayRemaining = 0
    self.phaseCompleteReported = false
    return self
end

function ArenaAISystem:_beginPhase()
    self.phaseActive = true
    self.queue = {}
    for _, unit in ipairs(self.unitSystem:getUnits()) do
        if self.enemyArenaSystem:isEnemy(unit) and (unit.hp or 0) > 0 then
            self.queue[#self.queue + 1] = unit
        end
    end
    table.sort(self.queue, unitOrder)
    self.queueIndex = 0
    self.currentUnit = nil
    self.movement = nil
    self.waitingForAttack = false
    self.delayRemaining = self.initialDelay
    self.phaseCompleteReported = false
end

function ArenaAISystem:_endPhase()
    if self.movement and self.movement.unit then
        self.movement.unit.visualTargW = nil
    end
    self.phaseActive = false
    self.queue = {}
    self.queueIndex = 0
    self.currentUnit = nil
    self.movement = nil
    self.waitingForAttack = false
    self.delayRemaining = 0
    self.phaseCompleteReported = false
end

function ArenaAISystem:_livingPlayers()
    local players = {}
    for _, unit in ipairs(self.unitSystem:getUnits()) do
        if not self.enemyArenaSystem:isEnemy(unit) and (unit.hp or 0) > 0 then
            players[#players + 1] = unit
        end
    end
    return players
end

function ArenaAISystem:_nextUnit()
    while self.queueIndex < #self.queue do
        self.queueIndex = self.queueIndex + 1
        local unit = self.queue[self.queueIndex]
        if self.unitSystem:contains(unit) and (unit.hp or 0) > 0 then
            self.currentUnit = unit
            return unit
        end
    end
    self.currentUnit = nil
    return nil
end

function ArenaAISystem:_finishCurrentUnit()
    if self.currentUnit and self.unitSystem:contains(self.currentUnit) then
        self.currentUnit.exhausted = true
    end
    self.currentUnit = nil
    self.waitingForAttack = false
    self.delayRemaining = self.actionDelay
end

function ArenaAISystem:notifyAttackComplete()
    if not self.waitingForAttack then
        return false
    end
    self:_finishCurrentUnit()
    return true
end

function ArenaAISystem:_chooseMeleeTarget(unit, candidates, movementCost)
    local bestTarget
    local bestRatio
    for _, target in ipairs(candidates) do
        local preview = self.combatSystem:getMeleeAttackPreview(
            unit,
            target,
            movementCost
        )
        if preview then
            local ratio = remainingHealthRatio(preview)
            if not bestTarget or ratio < bestRatio
                or (ratio == bestRatio
                    and target.instanceId < bestTarget.instanceId) then
                bestTarget = target
                bestRatio = ratio
            end
        end
    end
    return bestTarget
end

function ArenaAISystem:_existingMeleePlan(unit)
    local candidates = {}
    for _, player in ipairs(self.enemyArenaSystem:getEngagedOpponents(unit)) do
        if self.unitSystem:contains(player) and (player.hp or 0) > 0 then
            candidates[#candidates + 1] = player
        end
    end
    local target = self:_chooseMeleeTarget(unit, candidates, 0)
    if not target then
        return nil
    end
    return {
        kind = "melee",
        target = target,
        movementCost = 0,
        toW = unit.targW,
        engage = false,
    }
end

function ArenaAISystem:_furthestOpenForwardPosition(unit)
    local units = self.unitSystem:getUnits()
    local movement = self.unitSystem:getMovementPoints(unit)
    local furthestW = unit.targW
    local furthestCost = 0

    if self.enemyArenaSystem:cellHasBlockingPlayer(
        units,
        unit.targW,
        unit.targH
    ) then
        return furthestW, furthestCost
    end

    for distance = 1, movement do
        local targW = unit.targW - distance
        if targW < 1 then
            break
        end
        if self.enemyArenaSystem:cellHasBlockingPlayer(
            units,
            targW,
            unit.targH
        ) then
            break
        end
        furthestW = targW
        furthestCost = distance
    end
    return furthestW, furthestCost
end

function ArenaAISystem:_meleePlan(unit)
    local existingPlan = self:_existingMeleePlan(unit)
    if existingPlan then
        return existingPlan
    end
    if not self.combatSystem:getMeleeAttack(unit) then
        return nil
    end

    local units = self.unitSystem:getUnits()
    local movement = self.unitSystem:getMovementPoints(unit)
    local maximumDistance = math.min(movement, unit.targW - 1)
    local bestPlan
    local bestRatio

    for distance = 0, maximumDistance do
        local targW = unit.targW - distance
        local candidates = self.enemyArenaSystem:getEngageablePlayersAt(
            units,
            targW,
            unit.targH
        )
        if #candidates > 0 then
            local target = self:_chooseMeleeTarget(unit, candidates, distance)
            if target then
                local preview = self.combatSystem:getMeleeAttackPreview(
                    unit,
                    target,
                    distance
                )
                local ratio = remainingHealthRatio(preview)
                if not bestPlan or ratio < bestRatio
                    or (ratio == bestRatio
                        and distance < bestPlan.movementCost)
                    or (ratio == bestRatio
                        and distance == bestPlan.movementCost
                        and target.instanceId < bestPlan.target.instanceId) then
                    bestPlan = {
                        kind = "melee",
                        target = target,
                        movementCost = distance,
                        toW = targW,
                        engage = true,
                    }
                    bestRatio = ratio
                end
            end
        end

        if self.enemyArenaSystem:cellHasBlockingPlayer(
            units,
            targW,
            unit.targH
        ) then
            break
        end
    end

    if bestPlan then
        return bestPlan
    end

    local toW, movementCost = self:_furthestOpenForwardPosition(unit)
    return {
        kind = "move",
        movementCost = movementCost,
        toW = toW,
    }
end

function ArenaAISystem:_rangedPositions(unit)
    local positions = {
        { targW = unit.targW, movementCost = 0 },
    }
    local units = self.unitSystem:getUnits()
    local movement = self.unitSystem:getMovementPoints(unit)

    if self.enemyArenaSystem:cellHasBlockingPlayer(
        units,
        unit.targW,
        unit.targH
    ) then
        return positions
    end

    for distance = 1, movement do
        local targW = unit.targW - distance
        if targW < 1 then
            break
        end
        if self.enemyArenaSystem:cellHasBlockingPlayer(
            units,
            targW,
            unit.targH
        ) then
            break
        end
        positions[#positions + 1] = {
            targW = targW,
            movementCost = distance,
        }
    end
    return positions
end

function ArenaAISystem:_bestRangedPositionForTarget(unit, target, positions)
    local originalW = unit.targW
    local best
    for _, position in ipairs(positions) do
        unit.targW = position.targW
        local preview = self.combatSystem:getRangedAttackPreview(
            unit,
            target,
            position.movementCost
        )
        unit.targW = originalW

        if preview and (not best
            or preview.hitChance > best.preview.hitChance
            or (preview.hitChance == best.preview.hitChance
                and position.movementCost < best.movementCost)) then
            best = {
                target = target,
                toW = position.targW,
                movementCost = position.movementCost,
                preview = preview,
            }
        end
    end
    unit.targW = originalW
    return best
end

function ArenaAISystem:_rangedPlan(unit)
    if not self.combatSystem:getRangedAttack(unit)
        or self.combatSystem:isUnitEngaged(unit) then
        return nil
    end

    local positions = self:_rangedPositions(unit)
    local bestPlan
    local bestRatio
    for _, target in ipairs(self:_livingPlayers()) do
        local plan = self:_bestRangedPositionForTarget(unit, target, positions)
        if plan then
            local ratio = remainingHealthRatio(plan.preview)
            if not bestPlan or ratio < bestRatio
                or (ratio == bestRatio
                    and plan.preview.hitChance > bestPlan.preview.hitChance)
                or (ratio == bestRatio
                    and plan.preview.hitChance == bestPlan.preview.hitChance
                    and target.instanceId < bestPlan.target.instanceId) then
                bestPlan = plan
                bestRatio = ratio
            end
        end
    end

    if bestPlan then
        bestPlan.kind = "ranged"
    end
    return bestPlan
end

function ArenaAISystem:_choosePlan(unit)
    local hasRanged = self.combatSystem:getRangedAttack(unit) ~= nil
    local hasMelee = self.combatSystem:getMeleeAttack(unit) ~= nil
    local units = self.unitSystem:getUnits()

    if self.combatSystem:isUnitEngaged(unit) then
        if hasMelee then
            return self:_meleePlan(unit)
        end
        return {
            kind = "move",
            movementCost = 0,
            toW = unit.targW,
        }
    end

    if self.enemyArenaSystem:cellHasBlockingPlayer(
        units,
        unit.targW,
        unit.targH
    ) then
        if hasMelee then
            return self:_meleePlan(unit)
        end

        local targets = self.enemyArenaSystem:getEngageablePlayersAt(
            units,
            unit.targW,
            unit.targH
        )
        table.sort(targets, unitOrder)
        if targets[1] then
            return {
                kind = "engage",
                target = targets[1],
                movementCost = 0,
                toW = unit.targW,
            }
        end
    end

    if hasRanged then
        local rangedPlan = self:_rangedPlan(unit)
        if rangedPlan then
            return rangedPlan
        end
    end
    if hasMelee then
        return self:_meleePlan(unit)
    end

    local toW, movementCost = self:_furthestOpenForwardPosition(unit)
    return {
        kind = "move",
        movementCost = movementCost,
        toW = toW,
    }
end

function ArenaAISystem:_executePlan(plan)
    local unit = self.currentUnit
    if not unit or not self.unitSystem:contains(unit) then
        self:_finishCurrentUnit()
        return nil
    end

    if plan.kind == "engage" then
        self.enemyArenaSystem:engageEnemyWithPlayer(unit, plan.target)
    elseif plan.kind == "melee" then
        if plan.engage and not self.enemyArenaSystem:engageEnemyWithPlayer(
            unit,
            plan.target
        ) then
            self:_finishCurrentUnit()
            return nil
        end
        local result = self.combatSystem:performMeleeAttack(unit, plan.target)
        if result then
            self.waitingForAttack = true
            return { type = "melee_attack", result = result }
        end
    elseif plan.kind == "ranged" then
        local result = self.combatSystem:performRangedAttack(unit, plan.target)
        if result then
            self.waitingForAttack = true
            return { type = "ranged_attack", result = result }
        end
    end

    self:_finishCurrentUnit()
    return nil
end

function ArenaAISystem:_startPlan(unit, plan)
    local movementCost = math.max(0, plan.movementCost or 0)
    if movementCost <= 0 or plan.toW == unit.targW then
        return self:_executePlan(plan)
    end
    if not self.unitSystem:spendMovementPoints(unit, movementCost) then
        self:_finishCurrentUnit()
        return nil
    end

    local fromW = unit.targW
    unit.facing = plan.toW < fromW and "left" or "right"
    unit.targW = plan.toW
    unit.visualTargW = fromW
    self.movement = {
        unit = unit,
        fromW = fromW,
        toW = plan.toW,
        elapsed = 0,
        plan = plan,
    }
    return { type = "movement", unit = unit }
end

function ArenaAISystem:_updateMovement(dt)
    local movement = self.movement
    movement.elapsed = math.min(movement.elapsed + dt, self.moveDuration)
    local progress = movement.elapsed / self.moveDuration
    local easedProgress = smoothstep(progress)
    movement.unit.visualTargW = movement.fromW
        + (movement.toW - movement.fromW) * easedProgress

    if progress < 1 then
        return nil
    end

    movement.unit.visualTargW = nil
    self.movement = nil
    self.enemyArenaSystem:update(self.unitSystem:getUnits())
    return self:_executePlan(movement.plan)
end

function ArenaAISystem:update(dt, isEnemyPhase)
    if not isEnemyPhase then
        if self.phaseActive then
            self:_endPhase()
        end
        return nil
    end
    if not self.phaseActive then
        self:_beginPhase()
    end
    if self.waitingForAttack then
        return nil
    end
    if self.movement then
        return self:_updateMovement(dt)
    end
    if self.delayRemaining > 0 then
        self.delayRemaining = math.max(0, self.delayRemaining - dt)
        return nil
    end

    local unit = self.currentUnit or self:_nextUnit()
    if not unit then
        if not self.phaseCompleteReported then
            self.phaseCompleteReported = true
            return { type = "phase_complete" }
        end
        return nil
    end

    local plan = self:_choosePlan(unit)
    return self:_startPlan(unit, plan)
end

return ArenaAISystem
