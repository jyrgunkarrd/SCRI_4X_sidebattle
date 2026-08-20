local ResourceDefinitions = require("data.resources")

local WorldResourceSystem = {}
WorldResourceSystem.__index = WorldResourceSystem

local function hexKey(q, r)
    return ("%d:%d"):format(q, r)
end

function WorldResourceSystem.new(markers, axialToCenter)
    assert(type(axialToCenter) == "function", "Axial conversion is required")
    local self = setmetatable({}, WorldResourceSystem)
    self.definitionsById = {}
    self.resources = {}
    self.byHex = {}

    for _, definition in ipairs(ResourceDefinitions) do
        assert(type(definition) == "table", "Invalid resource definition")
        assert(type(definition.id) == "string" and definition.id ~= "",
            "Resource definition is missing a valid id")
        assert(not self.definitionsById[definition.id],
            ("Duplicate resource id '%s'"):format(definition.id))
        self.definitionsById[definition.id] = definition
    end

    for _, marker in ipairs(markers or {}) do
        if marker.type == "resource" then
            assert(type(marker.q) == "number" and type(marker.r) == "number",
                ("Resource marker '%s' is missing valid axial coordinates")
                    :format(tostring(marker.value)))
            local definition = self.definitionsById[marker.value]
            assert(definition,
                ("World map references unknown resource id '%s'"):format(
                    tostring(marker.value)))
            local key = hexKey(marker.q, marker.r)
            assert(not self.byHex[key],
                ("World map contains multiple resource markers at %s"):format(key))
            local centerX, centerY = axialToCenter(marker.q, marker.r)
            local resource = {
                id = definition.id,
                definition = definition,
                q = marker.q,
                r = marker.r,
                centerX = centerX,
                centerY = centerY,
            }
            self.resources[#self.resources + 1] = resource
            self.byHex[key] = resource
        end
    end

    table.sort(self.resources, function(left, right)
        if left.centerY ~= right.centerY then
            return left.centerY < right.centerY
        end
        return left.centerX < right.centerX
    end)
    return self
end

function WorldResourceSystem:getResources()
    return self.resources
end

function WorldResourceSystem:getAt(q, r)
    return self.byHex[hexKey(q, r)]
end

return WorldResourceSystem
