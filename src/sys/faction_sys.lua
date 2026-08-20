local FactionSystem = {}

function FactionSystem.getFaction(unit)
    if not unit then
        return "neutral"
    end
    local definition = unit.definition or unit
    return unit.faction or definition.start_faction or "neutral"
end

function FactionSystem.isEnemy(unit)
    return FactionSystem.getFaction(unit) == "enemy"
end

return FactionSystem
