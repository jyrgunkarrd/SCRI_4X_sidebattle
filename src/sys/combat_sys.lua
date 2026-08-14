local CombatSystem = {}
CombatSystem.__index = CombatSystem

local ARMOR_BASE = 100
local DEFAULT_ARMOR_EFFECTIVENESS = 9

function CombatSystem.new(options)
    options = options or {}

    local self = setmetatable({}, CombatSystem)
    self.unitSystem = options.unitSystem
    self.enemyArenaSystem = options.enemyArenaSystem
    self.armorEffectiveness = options.armorEffectiveness
        or DEFAULT_ARMOR_EFFECTIVENESS
    self.random = options.random
        or (love and love.math and love.math.random)
        or math.random
    assert(type(self.armorEffectiveness) == "number"
        and self.armorEffectiveness >= 0,
        "Armor effectiveness must be a non-negative number")
    return self
end

local function attackProperty(attack, property)
    if type(attack) ~= "table" then
        return nil
    end
    if attack[property] ~= nil then
        return attack[property]
    end
    for _, entry in ipairs(attack) do
        if type(entry) == "table" and entry[property] ~= nil then
            return entry[property]
        end
    end
    return nil
end

function CombatSystem:getArmorDamageMultiplier(armor)
    armor = math.max(0, tonumber(armor) or 0)
    return ARMOR_BASE
        / (ARMOR_BASE + armor * self.armorEffectiveness)
end

function CombatSystem:getArmorDamageReduction(armor)
    return 1 - self:getArmorDamageMultiplier(armor)
end

function CombatSystem:getEffectiveArmor(armor, penetration)
    local targetArmor = math.max(0, tonumber(armor) or 0)
    local attackPenetration = math.max(0, tonumber(penetration) or 0)
    return math.max(0, targetArmor - attackPenetration)
end

function CombatSystem:calculateDamageAfterArmor(rawDamage, armor, penetration)
    assert(type(rawDamage) == "number", "Raw damage must be a number")
    rawDamage = math.max(0, rawDamage)
    if rawDamage == 0 then
        return 0
    end

    local effectiveArmor = self:getEffectiveArmor(armor, penetration)
    local reducedDamage = rawDamage
        * self:getArmorDamageMultiplier(effectiveArmor)
    return math.max(1, math.ceil(reducedDamage))
end

function CombatSystem:resolveArmorDamage(rawDamage, armor, penetration)
    assert(type(rawDamage) == "number", "Raw damage must be a number")
    rawDamage = math.max(0, rawDamage)
    local targetArmor = math.max(0, tonumber(armor) or 0)
    local attackPenetration = math.max(0, tonumber(penetration) or 0)
    local effectiveArmor = self:getEffectiveArmor(
        targetArmor,
        attackPenetration
    )
    local multiplier = self:getArmorDamageMultiplier(effectiveArmor)
    return {
        rawDamage = rawDamage,
        armor = targetArmor,
        penetration = attackPenetration,
        effectiveArmor = effectiveArmor,
        reduction = 1 - multiplier,
        finalDamage = self:calculateDamageAfterArmor(
            rawDamage,
            targetArmor,
            attackPenetration
        ),
    }
end

function CombatSystem:getMeleeAttack(unit)
    return unit and unit.definition and unit.definition.m_atk or nil
end

function CombatSystem:getRangedAttack(unit)
    return unit and unit.definition and unit.definition.r_atk or nil
end

function CombatSystem:getAttackPenetration(attack)
    return math.max(0, tonumber(attackProperty(attack, "pen")) or 0)
end

function CombatSystem:_getAttackHitCount(unit, attack, movementCost)
    if attackProperty(attack, "type") ~= "multihit" then
        return 1
    end

    local maximum = self.unitSystem:getMaximumMovementPoints(unit)
    local remaining = math.max(
        0,
        self.unitSystem:getMovementPoints(unit)
            - math.max(0, tonumber(movementCost) or 0)
    )
    if maximum > 0 and remaining >= maximum then
        return 3
    elseif remaining > 0 then
        return 2
    end
    return 1
end


function CombatSystem:getMeleeHitCount(unit, movementCost)
    return self:_getAttackHitCount(
        unit,
        self:getMeleeAttack(unit),
        movementCost
    )
end

function CombatSystem:getRangedHitCount(unit, movementCost)
    return self:_getAttackHitCount(
        unit,
        self:getRangedAttack(unit),
        movementCost
    )
end

function CombatSystem:isUnitEngaged(unit)
    if not unit then
        return false
    end
    if self.enemyArenaSystem:isEnemy(unit) then
        return #self.enemyArenaSystem:getEngagers(unit) > 0
    end
    return unit.engagedWith ~= nil
end

function CombatSystem:getCellRange(attacker, target)
    if not attacker or not target then
        return math.huge
    end
    return math.max(
        math.abs(attacker.targW - target.targW),
        math.abs(attacker.targH - target.targH)
    )
end

local function getIntermediateCells(attacker, target)
    local cells = {}
    local x, y = attacker.targW, attacker.targH
    local targetX, targetY = target.targW, target.targH
    local deltaX = math.abs(targetX - x)
    local deltaY = math.abs(targetY - y)
    local stepX = x < targetX and 1 or -1
    local stepY = y < targetY and 1 or -1
    local errorValue = deltaX - deltaY

    while x ~= targetX or y ~= targetY do
        local doubledError = errorValue * 2
        if doubledError > -deltaY then
            errorValue = errorValue - deltaY
            x = x + stepX
        end
        if doubledError < deltaX then
            errorValue = errorValue + deltaX
            y = y + stepY
        end

        if x ~= targetX or y ~= targetY then
            cells[#cells + 1] = { targW = x, targH = y }
        end
    end
    return cells
end

function CombatSystem:getRangedObstructionCount(attacker, target)
    local intermediateCells = getIntermediateCells(attacker, target)
    local units = self.unitSystem:getUnits()
    local count = 0

    -- The first intermediate cell is directly adjacent to the attacker and
    -- is explicitly exempt from the obstruction penalty.
    for index = 2, #intermediateCells do
        local cell = intermediateCells[index]
        local occupied = false
        for _, unit in ipairs(units) do
            if (unit.hp or 0) > 0
                and unit.targW == cell.targW
                and unit.targH == cell.targH then
                occupied = true
                break
            end
        end
        if occupied then
            count = count + 1
        end
    end
    return count
end

function CombatSystem:getRangedHitChance(attacker, target)
    local attack = self:getRangedAttack(attacker)
    local maximumRange = math.max(0, tonumber(
        attackProperty(attack, "rng_max") or attackProperty(attack, "rng")
    ) or 0)
    local optimalRange = math.max(0, tonumber(
        attackProperty(attack, "rng_opt")
    ) or maximumRange)
    optimalRange = math.min(optimalRange, maximumRange)
    local range = self:getCellRange(attacker, target)
    if range <= 0 or range > maximumRange then
        return nil
    end

    local baseChance = range <= optimalRange and 100 or 50
    local obstructionCount = self:getRangedObstructionCount(attacker, target)
    return math.max(5, baseChance - obstructionCount * 25),
        range,
        obstructionCount
end

function CombatSystem:canRangedAttack(attacker, target)
    if not attacker or not target or attacker == target
        or attacker.exhausted or (attacker.hp or 0) <= 0
        or (target.hp or 0) <= 0
        or self:isUnitEngaged(attacker)
        or (attacker.targW == target.targW
            and attacker.targH == target.targH)
        or self.enemyArenaSystem:isEnemy(attacker)
            == self.enemyArenaSystem:isEnemy(target) then
        return false
    end

    local attack = self:getRangedAttack(attacker)
    local damage = tonumber(attackProperty(attack, "dmg"))
    local hitChance = self:getRangedHitChance(attacker, target)
    return damage ~= nil and damage > 0 and hitChance ~= nil
end

function CombatSystem:getRangedAttackPreview(attacker, target)
    if not self:canRangedAttack(attacker, target) then
        return nil
    end

    local attack = self:getRangedAttack(attacker)
    local rawDamage = tonumber(attackProperty(attack, "dmg"))
    local targetArmor = math.max(0, tonumber(target.definition.armor) or 0)
    local penetration = self:getAttackPenetration(attack)
    local effectiveArmor = self:getEffectiveArmor(targetArmor, penetration)
    local damagePerHit = self:calculateDamageAfterArmor(
        rawDamage,
        targetArmor,
        penetration
    )
    local availableHits = self:getRangedHitCount(attacker)
    local currentHP = math.max(0, tonumber(target.hp) or 0)
    local hitsToDefeat = math.max(1, math.ceil(currentHP / damagePerHit))
    local hitCount = math.min(availableHits, hitsToDefeat)
    local totalDamage = math.min(currentHP, damagePerHit * hitCount)
    local hitChance, range, obstructionCount = self:getRangedHitChance(
        attacker,
        target
    )

    return {
        attackType = "ranged",
        rawDamage = rawDamage,
        armor = effectiveArmor,
        targetArmor = targetArmor,
        penetration = penetration,
        damagePerHit = damagePerHit,
        isMultihit = attackProperty(attack, "type") == "multihit",
        hitCount = hitCount,
        totalDamage = totalDamage,
        currentHP = currentHP,
        maximumHP = math.max(
            1,
            tonumber(target.maximumHP or target.definition.hp) or 1
        ),
        willDefeat = totalDamage >= currentHP,
        hitChance = hitChance,
        range = range,
        obstructionCount = obstructionCount,
    }
end

function CombatSystem:getMeleeAttackPreview(attacker, target, movementCost)
    if not attacker or not target or attacker == target
        or attacker.exhausted or (attacker.hp or 0) <= 0
        or (target.hp or 0) <= 0 then
        return nil
    end

    local attack = self:getMeleeAttack(attacker)
    local rawDamage = tonumber(attackProperty(attack, "dmg"))
    if not rawDamage or rawDamage <= 0 then
        return nil
    end

    local targetArmor = math.max(0, tonumber(target.definition.armor) or 0)
    local penetration = self:getAttackPenetration(attack)
    local effectiveArmor = self:getEffectiveArmor(targetArmor, penetration)
    local damagePerHit = self:calculateDamageAfterArmor(
        rawDamage,
        targetArmor,
        penetration
    )
    local availableHits = self:getMeleeHitCount(attacker, movementCost)
    local currentHP = math.max(0, tonumber(target.hp) or 0)
    local hitsToDefeat = math.max(1, math.ceil(currentHP / damagePerHit))
    local hitCount = math.min(availableHits, hitsToDefeat)
    local totalDamage = math.min(currentHP, damagePerHit * hitCount)

    return {
        rawDamage = rawDamage,
        armor = effectiveArmor,
        targetArmor = targetArmor,
        penetration = penetration,
        damagePerHit = damagePerHit,
        isMultihit = attackProperty(attack, "type") == "multihit",
        hitCount = hitCount,
        totalDamage = totalDamage,
        currentHP = currentHP,
        maximumHP = math.max(
            1,
            tonumber(target.maximumHP or target.definition.hp) or 1
        ),
        willDefeat = totalDamage >= currentHP,
    }
end

function CombatSystem:canMeleeAttack(attacker, target)
    if not attacker or not target or attacker == target
        or attacker.exhausted or (attacker.hp or 0) <= 0
        or (target.hp or 0) <= 0 then
        return false
    end

    local attack = self:getMeleeAttack(attacker)
    local damage = tonumber(attackProperty(attack, "dmg"))
    local engaged = attacker.engagedWith == target
        or target.engagedWith == attacker
    return damage ~= nil and damage > 0 and engaged
end

function CombatSystem:_defeatUnit(unit)
    unit.hp = 0
    if self.enemyArenaSystem:isEnemy(unit) then
        local engagers = self.enemyArenaSystem:getEngagers(unit)
        for _, engager in ipairs(engagers) do
            engager.engagedWith = nil
            engager.flanking = false
        end
        unit.engagedBy = {}
    else
        self.enemyArenaSystem:disengage(unit)
    end
    self.unitSystem:remove(unit)
end

function CombatSystem:performMeleeAttack(attacker, target)
    if not self:canMeleeAttack(attacker, target) then
        return nil
    end

    local attack = self:getMeleeAttack(attacker)
    local rawDamage = tonumber(attackProperty(attack, "dmg"))
    local penetration = self:getAttackPenetration(attack)
    local requestedHits = self:getMeleeHitCount(attacker)
    local result = {
        attacker = attacker,
        target = target,
        requestedHits = requestedHits,
        hits = {},
        totalDamage = 0,
        penetration = penetration,
        defeated = false,
        vfxImage = attackProperty(attack, "img"),
    }

    for _ = 1, requestedHits do
        if target.hp <= 0 then
            break
        end
        local damage = self:calculateDamageAfterArmor(
            rawDamage,
            target.definition.armor,
            penetration
        )
        target.hp = math.max(0, target.hp - damage)
        result.hits[#result.hits + 1] = damage
        result.totalDamage = result.totalDamage + damage
    end

    attacker.exhausted = true
    if target.hp <= 0 then
        result.defeated = true
        target.defeated = true
    end
    return result
end

function CombatSystem:canRetaliate(attacker, target)
    if not attacker or not target or attacker == target
        or attacker.retaliateAvailable == false
        or (attacker.hp or 0) <= 0
        or (target.hp or 0) <= 0
        or not self.unitSystem:contains(attacker)
        or not self.unitSystem:contains(target) then
        return false
    end

    local attack = self:getMeleeAttack(attacker)
    local damage = tonumber(attackProperty(attack, "dmg"))
    local engaged = attacker.engagedWith == target
        or target.engagedWith == attacker
    return damage ~= nil and damage > 0 and engaged
end

function CombatSystem:performRetaliation(attacker, target)
    if not self:canRetaliate(attacker, target) then
        return nil
    end

    local attack = self:getMeleeAttack(attacker)
    local rawDamage = tonumber(attackProperty(attack, "dmg"))
    local penetration = self:getAttackPenetration(attack)
    local damage = self:calculateDamageAfterArmor(
        rawDamage,
        target.definition.armor,
        penetration
    )
    local result = {
        attackType = "retaliation",
        attacker = attacker,
        target = target,
        requestedHits = 1,
        hits = { damage },
        totalDamage = damage,
        penetration = penetration,
        isRetaliation = true,
        defeated = false,
        vfxImage = attackProperty(attack, "img"),
    }

    attacker.retaliateAvailable = false
    target.hp = math.max(0, target.hp - damage)
    if target.hp <= 0 then
        result.defeated = true
        target.defeated = true
    end
    return result
end

function CombatSystem:performRangedAttack(attacker, target)
    if not self:canRangedAttack(attacker, target) then
        return nil
    end

    local attack = self:getRangedAttack(attacker)
    local rawDamage = tonumber(attackProperty(attack, "dmg"))
    local penetration = self:getAttackPenetration(attack)
    local requestedHits = self:getRangedHitCount(attacker)
    local hitChance = self:getRangedHitChance(attacker, target)
    local result = {
        attackType = "ranged",
        attacker = attacker,
        target = target,
        requestedHits = requestedHits,
        strikes = {},
        hits = {},
        totalDamage = 0,
        penetration = penetration,
        hitChance = hitChance,
        defeated = false,
        vfxImage = attackProperty(attack, "img"),
    }

    if target.targW < attacker.targW then
        attacker.facing = "left"
    elseif target.targW > attacker.targW then
        attacker.facing = "right"
    end

    for _ = 1, requestedHits do
        if target.hp <= 0 then
            break
        end

        local didHit = self.random() < hitChance / 100
        local strike = { hit = didHit, damage = 0 }
        result.strikes[#result.strikes + 1] = strike
        if didHit then
            local damage = self:calculateDamageAfterArmor(
                rawDamage,
                target.definition.armor,
                penetration
            )
            strike.damage = damage
            target.hp = math.max(0, target.hp - damage)
            result.hits[#result.hits + 1] = damage
            result.totalDamage = result.totalDamage + damage
        end
    end

    attacker.exhausted = true
    if target.hp <= 0 then
        result.defeated = true
        target.defeated = true
    end
    return result
end

function CombatSystem:finalizeDefeat(unit)
    if not unit or (unit.hp or 0) > 0 or not self.unitSystem:contains(unit) then
        return false
    end
    self:_defeatUnit(unit)
    return true
end

return CombatSystem
