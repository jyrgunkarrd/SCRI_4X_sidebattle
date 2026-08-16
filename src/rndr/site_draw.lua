local SiteDraw = {}
SiteDraw.__index = SiteDraw

local IMAGE_ROOT = "assets/images/sites"
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54

function SiteDraw.new(siteSystem)
    local self = setmetatable({}, SiteDraw)
    self.sites = assert(siteSystem, "Site system is required"):getSites()
    self.images = {}
    for _, site in ipairs(self.sites) do
        local path = ("%s/%s.png"):format(IMAGE_ROOT, site.id)
        assert(love.filesystem.getInfo(path, "file"),
            ("Site image does not exist: %s"):format(path))
        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        self.images[site.id] = image
    end
    return self
end

function SiteDraw:draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, site in ipairs(self.sites) do
        love.graphics.draw(
            self.images[site.id],
            site.centerX - TILE_CENTER_X,
            site.centerY - TILE_CENTER_Y
        )
    end
end

return SiteDraw
