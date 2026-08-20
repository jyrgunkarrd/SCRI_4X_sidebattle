local ArenaEnvironmentBackground = {}
ArenaEnvironmentBackground.__index = ArenaEnvironmentBackground

local BACKGROUND_DIRECTORY = "assets/images/arena_backgrounds"
local IMAGE_EXTENSIONS = {
    png = true,
    jpg = true,
    jpeg = true,
    bmp = true,
    tga = true,
}

local function hexColor(value, fieldName)
    assert(type(value) == "string",
        ("Arena environment %s must be a hexadecimal color string"):format(fieldName))

    local hex = value:gsub("^#", "")
    assert(hex:match("^[%x]+$") and (#hex == 6 or #hex == 8),
        ("Arena environment %s must use RRGGBB or RRGGBBAA format"):format(fieldName))

    local red = tonumber(hex:sub(1, 2), 16) / 255
    local green = tonumber(hex:sub(3, 4), 16) / 255
    local blue = tonumber(hex:sub(5, 6), 16) / 255
    local alpha = #hex == 8 and tonumber(hex:sub(7, 8), 16) / 255 or 1
    return { red, green, blue, alpha }
end

local function readFloor(environment)
    assert(type(environment.floor) == "table",
        ("Arena environment '%s' must provide floor settings"):format(environment.id))

    local fill = environment.floor.fill
    local back = environment.floor.back

    for _, entry in ipairs(environment.floor) do
        assert(type(entry) == "table",
            ("Arena environment '%s' has an invalid floor entry"):format(environment.id))
        fill = entry.fill or fill
        back = entry.back or back
    end

    assert(fill, ("Arena environment '%s' floor is missing fill"):format(environment.id))
    assert(back, ("Arena environment '%s' floor is missing back"):format(environment.id))

    return {
        fill = hexColor(fill, "floor.fill"),
        back = hexColor(back, "floor.back"),
    }
end

local function findEnvironment(environments, environmentId)
    local found

    for _, environment in ipairs(environments) do
        assert(type(environment.id) == "string" and environment.id ~= "",
            "Every arena environment definition must have an id")

        if environment.id == environmentId then
            assert(not found,
                ("Duplicate arena environment id '%s'"):format(environmentId))
            found = environment
        end
    end

    assert(found,
        ("Unknown arena environment id '%s'"):format(tostring(environmentId)))
    return found
end

function ArenaEnvironmentBackground.fromLoader(environments, loader, options)
    assert(type(environments) == "table", "Arena environments must be a table")
    assert(type(loader) == "table", "Arena loader must return a table")
    assert(type(loader.env) == "string" and loader.env ~= "",
        "Arena loader must provide an env id")

    return ArenaEnvironmentBackground.new(
        findEnvironment(environments, loader.env),
        options
    )
end

function ArenaEnvironmentBackground.new(environment, options)
    options = options or {}

    local self = setmetatable({}, ArenaEnvironmentBackground)
    self.environment = assert(environment, "Arena environment is required")
    self.virtualWidth = options.virtualWidth or 1920
    self.virtualHeight = options.virtualHeight or 1080
    self.minimumParallax = options.minimumParallax or 0.08
    self.maximumParallax = options.maximumParallax or 0.55
    self.layers = {}

    assert(type(environment.bg_img) == "string" and environment.bg_img ~= "",
        ("Arena environment '%s' must provide bg_img"):format(environment.id))

    self.floor = readFloor(environment)
    self:_loadLayers(environment.bg_img)
    return self
end

function ArenaEnvironmentBackground:_loadLayers(folderName)
    local folder = ("%s/%s"):format(BACKGROUND_DIRECTORY, folderName)
    assert(love.filesystem.getInfo(folder, "directory"),
        ("Arena background folder does not exist: %s"):format(folder))

    local layerNumbers = {}
    for _, filename in ipairs(love.filesystem.getDirectoryItems(folder)) do
        local numberText, extension = filename:match("^(%d+)%.([%a%d]+)$")
        extension = extension and extension:lower()

        if numberText and IMAGE_EXTENSIONS[extension] then
            local layerNumber = tonumber(numberText)
            assert(not layerNumbers[layerNumber],
                ("Duplicate arena background layer %d in %s"):format(
                    layerNumber,
                    folder
                ))

            local path = ("%s/%s"):format(folder, filename)
            local image = love.graphics.newImage(path, { mipmaps = true })
            image:setFilter("linear", "linear", 8)
            image:setMipmapFilter("linear", 0)
            layerNumbers[layerNumber] = true
            self.layers[#self.layers + 1] = {
                number = layerNumber,
                image = image,
                scale = self.virtualHeight / image:getHeight(),
            }
        end
    end

    assert(#self.layers > 0,
        ("Arena background folder contains no numbered images: %s"):format(folder))

    table.sort(self.layers, function(left, right)
        return left.number < right.number
    end)

    local layerCount = #self.layers
    for index, layer in ipairs(self.layers) do
        local progress = layerCount > 1 and (index - 1) / (layerCount - 1) or 0
        layer.parallax = self.minimumParallax
            + (self.maximumParallax - self.minimumParallax) * progress
        layer.tileWidth = layer.image:getWidth() * layer.scale
    end
end

function ArenaEnvironmentBackground:draw(camera)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)

    for _, layer in ipairs(self.layers) do
        local offset = (camera.x * layer.parallax) % layer.tileWidth
        local x = -offset

        while x < self.virtualWidth do
            love.graphics.draw(layer.image, x, 0, 0, layer.scale, layer.scale)
            x = x + layer.tileWidth
        end
    end

    love.graphics.pop()
end

function ArenaEnvironmentBackground:drawFloor(grid)
    local floorHeight = grid.cellHeight / 20 + 8
    local backingOverhang = 8
    local arenaBottom = grid.y + grid.height
    local fillTop = arenaBottom - floorHeight
    local backTop = fillTop - backingOverhang

    love.graphics.setColor(self.floor.back)
    love.graphics.rectangle(
        "fill",
        grid.x,
        backTop,
        grid.width,
        floorHeight + backingOverhang
    )

    love.graphics.setColor(self.floor.fill)
    love.graphics.rectangle(
        "fill",
        grid.x,
        fillTop,
        grid.width,
        floorHeight
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaEnvironmentBackground
