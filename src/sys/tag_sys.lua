local TagSystem = {}
TagSystem.__index = TagSystem

local function definitionFor(subject)
    if not subject then
        return nil
    end
    return subject.definition or subject
end

local function interactionList(func)
    if type(func) ~= "table" then
        return {}
    end
    if func.targ_tag ~= nil or func.dmg_mult ~= nil then
        return { func }
    end
    return func
end

function TagSystem.new(tagDefinitions)
    assert(type(tagDefinitions) == "table", "Tag definitions are required")

    local self = setmetatable({}, TagSystem)
    self.interactionsByTag = {}

    for index, definition in ipairs(tagDefinitions) do
        assert(type(definition) == "table",
            ("Tag definition %d must be a table"):format(index))
        assert(type(definition.tagid) == "string" and definition.tagid ~= "",
            ("Tag definition %d requires a tagid"):format(index))
        assert(not self.interactionsByTag[definition.tagid],
            ("Duplicate tag definition: %s"):format(definition.tagid))

        local interactions = {}
        for interactionIndex, interaction in ipairs(
            interactionList(definition.func)
        ) do
            assert(type(interaction) == "table",
                ("Interaction %d for '%s' must be a table"):format(
                    interactionIndex,
                    definition.tagid
                ))
            assert(type(interaction.targ_tag) == "string"
                and interaction.targ_tag ~= "",
                ("Interaction %d for '%s' requires targ_tag"):format(
                    interactionIndex,
                    definition.tagid
                ))
            if interaction.dmg_mult ~= nil then
                assert(type(interaction.dmg_mult) == "number"
                    and interaction.dmg_mult > 0,
                    ("Interaction %d for '%s' has invalid dmg_mult"):format(
                        interactionIndex,
                        definition.tagid
                    ))
            end
            interactions[#interactions + 1] = interaction
        end
        self.interactionsByTag[definition.tagid] = interactions
    end

    return self
end

function TagSystem:getTags(subject)
    local definition = definitionFor(subject)
    if not definition or type(definition.tags) ~= "table" then
        return {}
    end
    return definition.tags
end

function TagSystem:getTagLookup(subject)
    local lookup = {}
    for _, tagId in ipairs(self:getTags(subject)) do
        if type(tagId) == "string" then
            lookup[tagId] = true
        end
    end
    return lookup
end

function TagSystem:hasTag(subject, tagId)
    return self:getTagLookup(subject)[tagId] == true
end

function TagSystem:getMatchingInteractions(source, target)
    local matches = {}
    local sourceTags = self:getTagLookup(source)
    local targetTags = self:getTagLookup(target)

    for sourceTag in pairs(sourceTags) do
        for _, interaction in ipairs(
            self.interactionsByTag[sourceTag] or {}
        ) do
            if targetTags[interaction.targ_tag] then
                matches[#matches + 1] = interaction
            end
        end
    end
    return matches
end

function TagSystem:getDamageMultiplier(attacker, target)
    local multiplier = 1
    for _, interaction in ipairs(
        self:getMatchingInteractions(attacker, target)
    ) do
        if interaction.dmg_mult ~= nil then
            multiplier = multiplier * interaction.dmg_mult
        end
    end
    return multiplier
end

return TagSystem
