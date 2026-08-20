local SiteDraw = {}
SiteDraw.__index = SiteDraw

local IMAGE_ROOT = "assets/images/sites"
local FACTION_BACKGROUND_ROOT = "assets/images/fac_back"
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54

local function loadImage(path, description)
    assert(love.filesystem.getInfo(path, "file"),
        ("%s does not exist: %s"):format(description, path))
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function SiteDraw.new(siteSystem)
    local self = setmetatable({}, SiteDraw)
    self.sites = assert(siteSystem, "Site system is required"):getSites()
    self.images = {}
    self.factionBackgrounds = {}
    for _, site in ipairs(self.sites) do
        local path = ("%s/%s.png"):format(IMAGE_ROOT, site.id)
        self.images[site.id] = loadImage(path, "Site image")
        self:_getFactionBackground(site.faction)
    end
    return self
end

function SiteDraw:_getFactionBackground(faction)
    faction = faction or "neutral"
    if not self.factionBackgrounds[faction] then
        local path = ("%s/%s.png"):format(FACTION_BACKGROUND_ROOT, faction)
        self.factionBackgrounds[faction] = loadImage(
            path,
            ("Faction background for '%s'"):format(faction)
        )
    end
    return self.factionBackgrounds[faction]
end

function SiteDraw:drawSite(site)
    local drawX = site.centerX - TILE_CENTER_X
    local drawY = site.centerY - TILE_CENTER_Y
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self:_getFactionBackground(site.faction), drawX, drawY)
    love.graphics.draw(self.images[site.id], drawX, drawY)
end

function SiteDraw:draw()
    for _, site in ipairs(self.sites) do
        self:drawSite(site)
    end
end

return SiteDraw
