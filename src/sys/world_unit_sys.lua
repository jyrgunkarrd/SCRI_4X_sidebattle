local UnitDefinitions = require("data.units.index")

local WorldUnitSystem = {}
WorldUnitSystem.__index = WorldUnitSystem

function WorldUnitSystem.new(siteSystem)
    local self = setmetatable({}, WorldUnitSystem)
    self.units = {}
    self.nextInstanceId = 1

    for _, site in ipairs(assert(siteSystem, "Site system is required"):getSites()) do
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
                self.units[#self.units + 1] = {
                    instanceId = self.nextInstanceId,
                    id = definition.id,
                    definition = definition,
                    siteId = site.id,
                    q = site.q,
                    r = site.r,
                    centerX = site.centerX,
                    centerY = site.centerY,
                }
                self.nextInstanceId = self.nextInstanceId + 1
            end
        end
    end
    return self
end

function WorldUnitSystem:getUnits()
    return self.units
end

return WorldUnitSystem
