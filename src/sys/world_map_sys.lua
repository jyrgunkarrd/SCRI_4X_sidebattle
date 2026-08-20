local SiteSystem = require("src.sys.site_sys")
local SiteDraw = require("src.rndr.site_draw")
local WorldUnitSystem = require("src.sys.world_unit_sys")
local WorldUnitStackSystem = require("src.sys.world_ustack_sys")
local WorldUnitDraw = require("src.rndr.world_unit_draw")
local WorldTerrainSystem = require("src.sys.world_terrain_sys")
local WorldResourceSystem = require("src.sys.world_res_sys")
local WorldResourceDraw = require("src.rndr.world_res_draw")
local WorldPathfindingSystem = require("src.sys.world_pathfinding_sys")
local WorldMoveSystem = require("src.sys.world_move_sys")
local WorldOverlayDraw = require("src.rndr.world_overlay_draw")

local WorldMapSystem = {}
WorldMapSystem.__index = WorldMapSystem

local TILE_SIZE = 96
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54
local PATH_UNIT_CLEARANCE = 4
local HEX_STEP_X = 72
local HEX_STEP_Y = 84
local HEX_STAGGER_Y = 42
local LAYER_ORDER = {
    base = 1,
    transition = 2,
    road = 3,
    river = 4,
    bridge = 5,
    overlay = 6,
}

local function axialToCenter(q, r)
    return q * HEX_STEP_X, r * HEX_STEP_Y + q * HEX_STAGGER_Y
end

local function roundAxial(fractionalQ, fractionalR)
    local cubeX = fractionalQ
    local cubeZ = fractionalR
    local cubeY = -cubeX - cubeZ
    local roundedX = math.floor(cubeX + 0.5)
    local roundedY = math.floor(cubeY + 0.5)
    local roundedZ = math.floor(cubeZ + 0.5)
    local differenceX = math.abs(roundedX - cubeX)
    local differenceY = math.abs(roundedY - cubeY)
    local differenceZ = math.abs(roundedZ - cubeZ)
    if differenceX > differenceY and differenceX > differenceZ then
        roundedX = -roundedY - roundedZ
    elseif differenceY > differenceZ then
        roundedY = -roundedX - roundedZ
    else
        roundedZ = -roundedX - roundedY
    end
    if roundedX == 0 then roundedX = 0 end
    if roundedZ == 0 then roundedZ = 0 end
    return roundedX, roundedZ
end

local function worldToAxial(worldX, worldY)
    local fractionalQ = worldX / HEX_STEP_X
    local fractionalR = worldY / HEX_STEP_Y - fractionalQ / 2
    return roundAxial(fractionalQ, fractionalR)
end

local function drawOrder(left, right)
    if left.layerOrder ~= right.layerOrder then
        return left.layerOrder < right.layerOrder
    end
    if left.centerY ~= right.centerY then
        return left.centerY < right.centerY
    end
    return left.centerX < right.centerX
end

local function depthDrawOrder(left, right)
    if left.centerY ~= right.centerY then
        return left.centerY < right.centerY
    end
    if left.centerX ~= right.centerX then
        return left.centerX < right.centerX
    end
    return left.localOrder < right.localOrder
end

local function loadImage(path)
    assert(love.filesystem.getInfo(path, "file"),
        ("World map image does not exist: %s"):format(path))
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function trimPathFromUnit(pathPoints)
    if #pathPoints < 4 then
        return
    end
    local startX, startY = pathPoints[1], pathPoints[2]
    local deltaX = pathPoints[3] - startX
    local deltaY = pathPoints[4] - startY
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if distance == 0 then
        return
    end
    local boundaryScale = math.huge
    if deltaX ~= 0 then
        boundaryScale = math.min(boundaryScale,
            TILE_CENTER_X / math.abs(deltaX))
    end
    if deltaY ~= 0 then
        boundaryScale = math.min(boundaryScale,
            TILE_CENTER_Y / math.abs(deltaY))
    end
    local clearanceScale = PATH_UNIT_CLEARANCE / distance
    local scale = math.min(1, boundaryScale + clearanceScale)
    pathPoints[1] = startX + deltaX * scale
    pathPoints[2] = startY + deltaY * scale
end

function WorldMapSystem.new(worldDefinition, options)
    options = options or {}
    assert(type(worldDefinition) == "table", "World definition must be a table")
    assert(type(worldDefinition.mapid) == "string" and worldDefinition.mapid ~= "",
        "World definition is missing a valid mapid")

    local self = setmetatable({}, WorldMapSystem)
    self.worldDefinition = worldDefinition
    self.map = require("assets.world." .. worldDefinition.mapid)
    self.tiles = {}
    self.baseHexes = {}
    self:_loadTiles()
    self.siteSystem = SiteSystem.new(self.map.markers, axialToCenter)
    self.siteDraw = SiteDraw.new(self.siteSystem)
    self.worldUnitSystem = WorldUnitSystem.new(self.siteSystem)
    self.worldUnitStackSystem = WorldUnitStackSystem.new(self.worldUnitSystem)
    self.worldUnitDraw = WorldUnitDraw.new(self.worldUnitSystem)
    self.pathfindingSystem = WorldPathfindingSystem.new({
        isPassable = function(q, r)
            return self:hasBaseHex(q, r)
        end,
    })
    self.worldMoveSystem = WorldMoveSystem.new(
        self.worldUnitSystem,
        self.worldUnitStackSystem,
        self.pathfindingSystem,
        axialToCenter,
        options.combatStartSystem
    )
    self.worldOverlayDraw = WorldOverlayDraw.new(
        self.worldMoveSystem,
        axialToCenter,
        self.worldUnitDraw
    )
    self.worldTerrainSystem = WorldTerrainSystem.new(self.map)
    self.worldResourceSystem = WorldResourceSystem.new(
        self.map.markers,
        axialToCenter
    )
    self.worldResourceDraw = WorldResourceDraw.new(self.worldResourceSystem)
    return self
end

function WorldMapSystem:_loadTiles()
    local minimumX, maximumX, minimumY, maximumY
    for _, savedTile in ipairs(self.map.tiles or {}) do
        local layerOrder = LAYER_ORDER[savedTile.layer]
        assert(layerOrder, ("Unknown world map layer: %s"):format(
            tostring(savedTile.layer)))
        assert(type(savedTile.q) == "number" and type(savedTile.r) == "number",
            "World map tile is missing valid axial coordinates")
        assert(type(savedTile.path) == "string", "World map tile is missing its path")
        local image = loadImage(savedTile.path)
        assert(image:getWidth() == TILE_SIZE and image:getHeight() == TILE_SIZE,
            ("World map tile must be %dx%d: %s"):format(
                TILE_SIZE, TILE_SIZE, savedTile.path))
        local centerX, centerY = axialToCenter(savedTile.q, savedTile.r)
        self.tiles[#self.tiles + 1] = {
            image = image,
            q = savedTile.q,
            r = savedTile.r,
            layerOrder = layerOrder,
            centerX = centerX,
            centerY = centerY,
            drawX = centerX - TILE_CENTER_X,
            drawY = centerY - TILE_CENTER_Y,
        }
        if savedTile.layer == "base" then
            self.baseHexes[("%d:%d"):format(savedTile.q, savedTile.r)] = true
        end
        local drawX = centerX - TILE_CENTER_X
        local drawY = centerY - TILE_CENTER_Y
        minimumX = minimumX and math.min(minimumX, drawX) or drawX
        maximumX = maximumX and math.max(maximumX, drawX + TILE_SIZE)
            or drawX + TILE_SIZE
        minimumY = minimumY and math.min(minimumY, drawY) or drawY
        maximumY = maximumY and math.max(maximumY, drawY + TILE_SIZE)
            or drawY + TILE_SIZE
    end
    assert(minimumX, "World map must contain at least one painted tile")
    self.tileBounds = {
        minimumX = minimumX,
        maximumX = maximumX,
        minimumY = minimumY,
        maximumY = maximumY,
    }
    table.sort(self.tiles, drawOrder)
end

function WorldMapSystem:getSite(id)
    return self.siteSystem:get(id)
end

function WorldMapSystem:hasBaseHex(q, r)
    return self.baseHexes[("%d:%d"):format(q, r)] == true
end

function WorldMapSystem:worldToHex(worldX, worldY)
    return worldToAxial(worldX, worldY)
end

function WorldMapSystem:selectUnitAtWorldPosition(worldX, worldY)
    local q, r = worldToAxial(worldX, worldY)
    return self.worldMoveSystem:selectAt(q, r)
end

function WorldMapSystem:deselectUnit()
    self.worldMoveSystem:deselect()
end

function WorldMapSystem:applyCombatResult(result)
    self.worldMoveSystem:deselect()
    self.worldUnitSystem:applyCombatResult(result)
    self.worldUnitStackSystem:updateVisibility()
end

function WorldMapSystem:getSelectedUnitStack()
    return self.worldMoveSystem:getSelectedStack()
end

function WorldMapSystem:getSelectedUnitSourceStack()
    return self.worldMoveSystem:getSourceStack()
end

function WorldMapSystem:toggleUnitInSelection(unit)
    return self.worldMoveSystem:toggleUnitSelection(unit)
end

function WorldMapSystem:selectUnitsWithMovementRemaining()
    return self.worldMoveSystem:selectUnitsWithMovementRemaining()
end

function WorldMapSystem:isUnitMovementActive()
    return self.worldMoveSystem:isMoving()
end

function WorldMapSystem:moveSelectedUnitToWorldPosition(worldX, worldY)
    local q, r = worldToAxial(worldX, worldY)
    return self.worldMoveSystem:moveSelectedTo(q, r)
end

function WorldMapSystem:setMovementHoverAtWorldPosition(worldX, worldY)
    local q, r = worldToAxial(worldX, worldY)
    self.worldMoveSystem:setHoveredHex(q, r)
end

function WorldMapSystem:clearMovementHover()
    self.worldMoveSystem:clearHoveredHex()
end

function WorldMapSystem:getFocusPosition()
    local focusId = self.worldDefinition.foc_site
    assert(type(focusId) == "string" and focusId ~= "",
        "World definition is missing a valid foc_site")
    local site = self:getSite(focusId)
    assert(site, ("Focused site '%s' is not placed on the world map"):format(focusId))
    return site.centerX, site.centerY
end

function WorldMapSystem:getCameraBounds(buffer)
    buffer = math.max(0, buffer or 0)
    return {
        minimumX = self.tileBounds.minimumX - buffer,
        maximumX = self.tileBounds.maximumX + buffer,
        minimumY = self.tileBounds.minimumY - buffer,
        maximumY = self.tileBounds.maximumY + buffer,
    }
end

function WorldMapSystem:getTerrainAtWorldPosition(worldX, worldY)
    local q, r = worldToAxial(worldX, worldY)
    return self.worldTerrainSystem:get(q, r), q, r
end

function WorldMapSystem:getResourceAtWorldPosition(worldX, worldY)
    return self.worldResourceDraw:getResourceAtPoint(worldX, worldY)
end

function WorldMapSystem:update(dt)
    self.worldMoveSystem:update(dt)
    self.worldUnitDraw:update(dt)
end

function WorldMapSystem:_getDepthSortedDrawables()
    local drawables = {}
    for _, tile in ipairs(self.tiles) do
        drawables[#drawables + 1] = {
            kind = "tile",
            value = tile,
            centerX = tile.centerX,
            centerY = tile.centerY,
            localOrder = tile.layerOrder,
        }
    end
    for _, site in ipairs(self.siteSystem:getSites()) do
        drawables[#drawables + 1] = {
            kind = "site",
            value = site,
            centerX = site.centerX,
            centerY = site.centerY,
            localOrder = 10,
        }
    end
    for _, hex in ipairs(self.worldMoveSystem:getReachableHexes()) do
        local centerX, centerY = axialToCenter(hex.q, hex.r)
        drawables[#drawables + 1] = {
            kind = "movement",
            value = hex,
            centerX = centerX,
            centerY = centerY,
            localOrder = 20,
        }
    end
    local preview = self.worldMoveSystem:getMovementPreview()
    if preview then
        local pathPoints = {}
        local previewDepthX, previewDepthY
        for _, pathHex in ipairs(preview.path) do
            local pointX, pointY = axialToCenter(pathHex.q, pathHex.r)
            pathPoints[#pathPoints + 1] = pointX
            pathPoints[#pathPoints + 1] = pointY
            if not previewDepthY or pointY > previewDepthY then
                previewDepthX, previewDepthY = pointX, pointY
            end
        end
        trimPathFromUnit(pathPoints)
        drawables[#drawables + 1] = {
            kind = "movement_path",
            value = { points = pathPoints },
            centerX = previewDepthX,
            centerY = previewDepthY,
            localOrder = 22,
        }
        drawables[#drawables + 1] = {
            kind = "movement_ghost",
            value = preview,
            centerX = previewDepthX,
            centerY = previewDepthY,
            localOrder = 25,
        }
    end
    for _, unit in ipairs(self.worldUnitSystem:getUnits()) do
        if not unit.isMoving and not unit.worldStackHidden then
            drawables[#drawables + 1] = {
                kind = "unit",
                value = unit,
                centerX = unit.centerX,
                centerY = unit.centerY,
                localOrder = 30,
            }
        end
    end
    table.sort(drawables, depthDrawOrder)
    return drawables
end

function WorldMapSystem:draw(cameraX, cameraY, viewportWidth, viewportHeight)
    love.graphics.push()
    love.graphics.translate(
        math.floor(viewportWidth / 2 - cameraX),
        math.floor(viewportHeight / 2 - cameraY)
    )
    for _, drawable in ipairs(self:_getDepthSortedDrawables()) do
        if drawable.kind == "tile" then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                drawable.value.image,
                drawable.value.drawX,
                drawable.value.drawY
            )
        elseif drawable.kind == "site" then
            self.siteDraw:drawSite(drawable.value)
        elseif drawable.kind == "movement" then
            self.worldOverlayDraw:drawMovementHex(drawable.value)
        elseif drawable.kind == "movement_path" then
            self.worldOverlayDraw:drawPath(drawable.value)
        elseif drawable.kind == "movement_ghost" then
            self.worldOverlayDraw:drawUnitGhost(drawable.value)
        elseif drawable.kind == "unit" then
            self.worldUnitDraw:drawUnit(drawable.value)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    self.worldUnitDraw:drawMovingUnits()
    self.worldResourceDraw:draw()
    self.worldOverlayDraw:drawSelection()
    love.graphics.pop()
end

return WorldMapSystem
