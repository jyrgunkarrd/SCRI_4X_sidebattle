local SiteDefinitions = require("data.sites.index")

local SiteSystem = {}
SiteSystem.__index = SiteSystem

function SiteSystem.new(markers, axialToCenter)
    assert(type(axialToCenter) == "function", "Axial conversion is required")
    local self = setmetatable({}, SiteSystem)
    self.sites = {}
    self.byId = {}

    for _, marker in ipairs(markers or {}) do
        if marker.type == "site" then
            assert(type(marker.q) == "number" and type(marker.r) == "number",
                ("Site marker '%s' is missing valid axial coordinates"):format(
                    tostring(marker.value)))
            local definition = SiteDefinitions.get(marker.value)
            assert(definition,
                ("World map references unknown site id '%s'"):format(
                    tostring(marker.value)))
            assert(not self.byId[definition.id],
                ("World map contains duplicate site id '%s'"):format(definition.id))
            local centerX, centerY = axialToCenter(marker.q, marker.r)
            local site = {
                id = definition.id,
                definition = definition,
                q = marker.q,
                r = marker.r,
                centerX = centerX,
                centerY = centerY,
            }
            self.sites[#self.sites + 1] = site
            self.byId[site.id] = site
        end
    end

    table.sort(self.sites, function(left, right)
        if left.centerY ~= right.centerY then
            return left.centerY < right.centerY
        end
        return left.centerX < right.centerX
    end)
    return self
end

function SiteSystem:getSites()
    return self.sites
end

function SiteSystem:get(id)
    return self.byId[id]
end

return SiteSystem
