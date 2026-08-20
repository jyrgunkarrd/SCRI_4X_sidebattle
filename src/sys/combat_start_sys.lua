local FactionSystem = require("src.sys.faction_sys")

local CombatStartSystem = {}
CombatStartSystem.__index = CombatStartSystem

local ARENA_COLUMNS = 20
local STACK_COLUMNS = 3
local PLAYER_COLUMNS_BY_ROW = { 4, 3, 2, 1 }
local ENEMY_COLUMNS_BY_ROW = { 17, 18, 19, 20 }

local function addPlacements(
    placements,
    stack,
    faction,
    columnsByRow,
    combatRole
)
    for index, unit in ipairs(stack.units) do
        local row = stack.panelRowByUnit and stack.panelRowByUnit[unit]
            or math.floor((index - 1) / STACK_COLUMNS) + 1
        local column = assert(columnsByRow[row],
            "Combat stack exceeds the four supported panel rows")
        placements[#placements + 1] = {
            unitId = unit.id,
            faction = faction,
            targW = column,
            targH = 1,
            worldUnit = unit,
            combatRole = combatRole,
            worldOrigin = {
                q = unit.q,
                r = unit.r,
                centerX = unit.centerX,
                centerY = unit.centerY,
            },
        }
    end
end

function CombatStartSystem.new(options)
    options = options or {}
    local self = setmetatable({}, CombatStartSystem)
    self.onStart = assert(options.onStart,
        "Combat start callback is required")
    self.pendingEncounter = nil
    return self
end

function CombatStartSystem:canInitiate(firstStack, secondStack)
    if not firstStack or not secondStack then
        return false
    end
    local firstFaction = FactionSystem.getFaction(firstStack.representative)
    local secondFaction = FactionSystem.getFaction(secondStack.representative)
    return (firstFaction == "player" and secondFaction == "enemy")
        or (firstFaction == "enemy" and secondFaction == "player")
end

function CombatStartSystem:initiate(firstStack, secondStack)
    assert(self:canInitiate(firstStack, secondStack),
        "Combat requires player and enemy formations")
    local firstFaction = FactionSystem.getFaction(firstStack.representative)
    local playerStack = firstFaction == "player" and firstStack or secondStack
    local enemyStack = firstFaction == "enemy" and firstStack or secondStack
    local placements = {}
    addPlacements(
        placements,
        playerStack,
        "player",
        PLAYER_COLUMNS_BY_ROW,
        playerStack == firstStack and "attacker" or "defender"
    )
    addPlacements(
        placements,
        enemyStack,
        "enemy",
        ENEMY_COLUMNS_BY_ROW,
        enemyStack == firstStack and "attacker" or "defender"
    )
    local defender = assert(secondStack.representative,
        "The defending formation requires a representative")
    local encounter = {
        arenaColumns = ARENA_COLUMNS,
        playerStack = playerStack,
        enemyStack = enemyStack,
        attackerFaction = firstFaction,
        defenderOrigin = {
            q = secondStack.q,
            r = secondStack.r,
            centerX = defender.centerX,
            centerY = defender.centerY,
        },
        placements = placements,
    }
    self.pendingEncounter = encounter
    return encounter
end

function CombatStartSystem:dispatchPending()
    local encounter = self.pendingEncounter
    if not encounter then
        return false
    end
    self.pendingEncounter = nil
    self.onStart(encounter)
    return true
end

return CombatStartSystem
