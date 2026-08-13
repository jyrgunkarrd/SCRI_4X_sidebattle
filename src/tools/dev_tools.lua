local DevTools = {}
DevTools.__index = DevTools

function DevTools.new(unitSystem)
    local self = setmetatable({}, DevTools)
    self.unitSystem = assert(unitSystem, "Unit system is required")
    return self
end

function DevTools:injectFromLoader(moduleName)
    moduleName = moduleName or "data.dev_unit_loader"
    local placements = require(moduleName)
    assert(type(placements) == "table", moduleName .. " must return a table")

    for index, placement in ipairs(placements) do
        assert(type(placement) == "table",
            ("Placement %d in %s must be a table"):format(index, moduleName))

        local unitIds = placement.unitid or placement.id
        if type(unitIds) == "string" then
            unitIds = { unitIds }
        end
        assert(type(unitIds) == "table" and #unitIds > 0,
            ("Placement %d in %s must provide unitid"):format(index, moduleName))

        for _, unitId in ipairs(unitIds) do
            self.unitSystem:inject(
                unitId,
                placement.pop or placement.population,
                placement.targ_w,
                placement.targ_h
            )
        end
    end
end

return DevTools
