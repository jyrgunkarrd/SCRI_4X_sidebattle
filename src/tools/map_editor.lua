local MapEditor = {}
MapEditor.__index = MapEditor

local utf8 = require("utf8")

MapEditor.name = "map-editor"

local VIRTUAL_WIDTH = 1920
local VIRTUAL_HEIGHT = 1080
local LAYERS = {
    base = {
        label = "HEX BASE",
        root = "assets/images/maptiles/hex_bases",
        order = 1,
    },
    transition = {
        label = "HEX TRANSITION",
        root = "assets/images/maptiles/hex_transitions",
        order = 2,
    },
    road = {
        label = "RIVER / ROAD / BRIDGE",
        root = "assets/images/maptiles/river_road_bridge",
        order = 3,
    },
    river = {
        order = 4,
    },
    bridge = {
        order = 5,
    },
    overlay = {
        label = "HEX OVERLAY",
        root = "assets/images/maptiles/hex_overlays",
        order = 6,
    },
}
local MARKER_TYPES = {
    { name = "terrain", label = "TERRAIN", badge = "T", offsetX = -24 },
    { name = "resource", label = "RESOURCE", badge = "R", offsetX = 0 },
    { name = "site", label = "SITE", badge = "S", offsetX = 24 },
}
local TILE_SIZE = 96
local TILE_CENTER_X = 48
local TILE_CENTER_Y = 54
local HEX_STEP_X = 72
local HEX_STEP_Y = 84
local HEX_STAGGER_Y = 42
local HUD_HEIGHT = 128
local CAMERA_SPEED = 720
local MAP_ROOT = "assets/maps"

local function wrapIndex(index, count)
    if count <= 0 then
        return 0
    end
    return ((index - 1) % count) + 1
end

local function hexKey(q, r)
    return ("%d:%d"):format(q, r)
end

local function mapFileName(name)
    local fileName = name:gsub("[^%w%._%- ]", "_")
        :gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_")
    if fileName == "" then
        fileName = "map"
    end
    return fileName:lower():match("%.lua$") and fileName
        or fileName .. ".lua"
end

local function sortedValues(values)
    local result = {}
    for _, value in pairs(values) do
        result[#result + 1] = value
    end
    table.sort(result, function(left, right)
        if left.q ~= right.q then
            return left.q < right.q
        end
        return left.r < right.r
    end)
    return result
end

local function nativeMapRoot()
    local source = love.filesystem.getSource()
    if source and not source:lower():match("%.love$") then
        return source .. "/" .. MAP_ROOT
    end
    return love.filesystem.getSourceBaseDirectory() .. "/" .. MAP_ROOT
end

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
    -- Cube correction can create IEEE negative zero at the origin. Numeric
    -- zero compares normally, but its string form can produce a different
    -- lookup key on some Lua runtimes.
    if roundedX == 0 then roundedX = 0 end
    if roundedZ == 0 then roundedZ = 0 end
    return roundedX, roundedZ
end

local function worldToAxial(worldX, worldY)
    local fractionalQ = worldX / HEX_STEP_X
    local fractionalR = worldY / HEX_STEP_Y - fractionalQ / 2
    return roundAxial(fractionalQ, fractionalR)
end

local function tileDrawOrder(left, right)
    if left.layerOrder ~= right.layerOrder then
        return left.layerOrder < right.layerOrder
    end
    if left.centerY ~= right.centerY then
        return left.centerY < right.centerY
    end
    if left.centerX ~= right.centerX then
        return left.centerX < right.centerX
    end
    return left.isGhost ~= true and right.isGhost == true
end

local function naturalSortKey(value)
    return value:lower():gsub("%d+", function(number)
        return ("%010d"):format(tonumber(number))
    end)
end

local function pngFiles(directory)
    local files = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local path = directory .. "/" .. item
        if love.filesystem.getInfo(path, "file")
            and item:lower():match("%.png$") then
            files[#files + 1] = item
        end
    end
    table.sort(files, function(left, right)
        local leftKey = naturalSortKey(left)
        local rightKey = naturalSortKey(right)
        return leftKey == rightKey and left < right or leftKey < rightKey
    end)
    return files
end

local function discoverFolders(root)
    local folders = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(root)) do
        local path = root .. "/" .. item
        if love.filesystem.getInfo(path, "directory") then
            local files = pngFiles(path)
            if #files > 0 then
                folders[#folders + 1] = {
                    name = item,
                    path = path,
                    files = files,
                }
            end
        end
    end
    table.sort(folders, function(left, right)
        return left.name:lower() < right.name:lower()
    end)
    return folders
end

function MapEditor.new()
    return setmetatable({}, MapEditor)
end

function MapEditor:enter()
    self.mapCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.mapCanvas:setFilter("nearest", "nearest")
    self.uiCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    self.uiCanvas:setFilter("linear", "linear")
    self.outputScale = 1
    self.outputOffsetX = 0
    self.outputOffsetY = 0
    self.cameraX = -VIRTUAL_WIDTH / 2
    self.cameraY = -VIRTUAL_HEIGHT / 2
    self.layerCatalogs = {}
    for layerName, layer in pairs(LAYERS) do
        if layer.root then
            local folders = discoverFolders(layer.root)
            assert(#folders > 0,
                ("No map tile folders found in %s"):format(layer.root))
            self.layerCatalogs[layerName] = {
                folders = folders,
                folderIndex = 1,
                tileIndex = 1,
            }
        end
    end
    self.activeMode = "base"
    self.imageCache = {}
    self.tiles = {
        base = {}, transition = {}, road = {}, river = {}, bridge = {}, overlay = {},
    }
    self.markers = { terrain = {}, resource = {}, site = {} }
    self.markerTypeIndex = 1
    self.markerCount = 0
    self.pickerActive = false
    self.copiedMarkerString = nil
    self.markerInput = nil
    self.mapName = nil
    self.nameInput = nil
    self.loadPanel = nil
    self.statusMessage = nil
    self.dirty = false
    self.exitPrompt = false
    self.tileCount = 0
    self.sortedTiles = {}
    self.drawOrderDirty = false
    self.boundsDirty = true
    self.bounds = nil
    self.hoverQ = nil
    self.hoverR = nil
    self.paintButton = nil
    self.lastToolQ = nil
    self.lastToolR = nil
    self.middleDragging = false
end

function MapEditor:_currentFolder()
    local catalog = self.layerCatalogs[self.activeMode]
    return catalog.folders[catalog.folderIndex]
end

function MapEditor:_currentTileAsset()
    local folder = self:_currentFolder()
    local catalog = self.layerCatalogs[self.activeMode]
    local fileName = folder and folder.files[catalog.tileIndex]
    if not fileName then
        return nil
    end
    return {
        folder = folder.name,
        name = fileName,
        path = folder.path .. "/" .. fileName,
    }
end

function MapEditor:_activePaintLayer()
    if self.activeMode ~= "road" then
        return self.activeMode
    end
    local folderName = self:_currentFolder().name:lower()
    if folderName:find("bridge", 1, true) then
        return "bridge"
    elseif folderName:find("river", 1, true) then
        return "river"
    end
    return "road"
end

function MapEditor:_getImage(path)
    local image = self.imageCache[path]
    if image then
        return image
    end

    image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    assert(image:getWidth() == TILE_SIZE and image:getHeight() == TILE_SIZE,
        ("Map tile must be %dx%d: %s"):format(
            TILE_SIZE,
            TILE_SIZE,
            path
        ))
    self.imageCache[path] = image
    return image
end

function MapEditor:_renderCameraPosition()
    return math.floor(self.cameraX + 0.5), math.floor(self.cameraY + 0.5)
end

function MapEditor:_screenToVirtual(screenX, screenY)
    local virtualX = (screenX - self.outputOffsetX) / self.outputScale
    local virtualY = (screenY - self.outputOffsetY) / self.outputScale
    if virtualX < 0 or virtualY < 0
        or virtualX >= VIRTUAL_WIDTH or virtualY >= VIRTUAL_HEIGHT then
        return nil, nil
    end
    return virtualX, virtualY
end

function MapEditor:_screenToHex(screenX, screenY)
    local virtualX, virtualY = self:_screenToVirtual(screenX, screenY)
    if not virtualX or virtualY < HUD_HEIGHT then
        return nil, nil
    end
    local cameraX, cameraY = self:_renderCameraPosition()
    return worldToAxial(virtualX + cameraX, virtualY + cameraY)
end

function MapEditor:_setHoverFromScreen(screenX, screenY)
    self.hoverQ, self.hoverR = self:_screenToHex(screenX, screenY)
end

function MapEditor:_markMapChanged()
    self.drawOrderDirty = true
    self.boundsDirty = true
    self.dirty = true
end

function MapEditor:_paint(q, r)
    local asset = self:_currentTileAsset()
    if not asset then
        return false
    end

    local key = hexKey(q, r)
    local paintLayer = self:_activePaintLayer()
    local layerTiles = self.tiles[paintLayer]
    local tile = layerTiles[key]
    if not tile then
        tile = { q = q, r = r }
        layerTiles[key] = tile
        self.tileCount = self.tileCount + 1
    elseif tile.path == asset.path then
        return false
    end

    local centerX, centerY = axialToCenter(q, r)
    tile.folder = asset.folder
    tile.name = asset.name
    tile.path = asset.path
    tile.layer = paintLayer
    tile.layerOrder = LAYERS[paintLayer].order
    tile.image = self:_getImage(asset.path)
    tile.centerX = centerX
    tile.centerY = centerY
    tile.drawX = centerX - TILE_CENTER_X
    tile.drawY = centerY - TILE_CENTER_Y
    self:_markMapChanged()
    return true
end

function MapEditor:_erase(q, r)
    local key = hexKey(q, r)
    local layerTiles = self.tiles[self:_activePaintLayer()]
    if not layerTiles[key] then
        return false
    end
    layerTiles[key] = nil
    self.tileCount = self.tileCount - 1
    self:_markMapChanged()
    return true
end

function MapEditor:_currentMarkerType()
    return MARKER_TYPES[self.markerTypeIndex]
end

function MapEditor:_setMarker(q, r, value)
    local markerType = self:_currentMarkerType()
    local markerTable = self.markers[markerType.name]
    local key = hexKey(q, r)
    if not markerTable[key] then
        markerTable[key] = { q = q, r = r, value = value }
        self.markerCount = self.markerCount + 1
    else
        markerTable[key].value = value
    end
    self:_markMapChanged()
end

function MapEditor:_eraseMarker(q, r)
    local markerTable = self.markers[self:_currentMarkerType().name]
    local key = hexKey(q, r)
    if not markerTable[key] then
        return false
    end
    markerTable[key] = nil
    self.markerCount = self.markerCount - 1
    self:_markMapChanged()
    return true
end

function MapEditor:_beginMarkerInput(q, r)
    local marker = self.markers[self:_currentMarkerType().name][hexKey(q, r)]
    self.markerInput = {
        q = q,
        r = r,
        value = marker and marker.value or "",
    }
    love.keyboard.setTextInput(true)
end

function MapEditor:_finishMarkerInput(save)
    if save then
        self:_setMarker(
            self.markerInput.q,
            self.markerInput.r,
            self.markerInput.value
        )
    end
    self.markerInput = nil
    love.keyboard.setTextInput(false)
end

function MapEditor:_pickAt(q, r)
    local key = hexKey(q, r)
    if self.activeMode == "marker" then
        local marker = self.markers[self:_currentMarkerType().name][key]
        if not marker then
            return false
        end
        self.copiedMarkerString = marker.value
    else
        local tile = self.tiles[self:_activePaintLayer()][key]
        if not tile then
            return false
        end
        local catalog = self.layerCatalogs[self.activeMode]
        for folderIndex, folder in ipairs(catalog.folders) do
            if folder.name == tile.folder then
                catalog.folderIndex = folderIndex
                for tileIndex, fileName in ipairs(folder.files) do
                    if fileName == tile.name then
                        catalog.tileIndex = tileIndex
                        break
                    end
                end
                break
            end
        end
    end
    self.pickerActive = false
    return true
end

function MapEditor:_beginNameInput(saveAfterNaming, quitAfterSave)
    self.paintButton = nil
    self.lastToolQ = nil
    self.lastToolR = nil
    self.nameInput = {
        value = self.mapName or "",
        saveAfterNaming = saveAfterNaming == true,
        quitAfterSave = quitAfterSave == true,
    }
    love.keyboard.setTextInput(true)
end

function MapEditor:_finishNameInput(save)
    local input = self.nameInput
    self.nameInput = nil
    love.keyboard.setTextInput(false)
    if not save then
        return
    end
    local name = input.value:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        self.statusMessage = "MAP NAME CANNOT BE EMPTY"
        return
    end
    if self.mapName ~= name then
        self.mapName = name
        self.dirty = true
    end
    if input.saveAfterNaming then
        self:_saveMap(input.quitAfterSave)
    end
end

function MapEditor:_mapSource()
    local lines = {
        "return {",
        "    version = 1,",
        ("    name = %q,"):format(self.mapName),
        "    tiles = {",
    }
    for _, layerName in ipairs({
        "base", "transition", "road", "river", "bridge", "overlay",
    }) do
        for _, tile in ipairs(sortedValues(self.tiles[layerName])) do
            lines[#lines + 1] = ("        { layer = %q, q = %d, r = %d, folder = %q, name = %q, path = %q },")
                :format(layerName, tile.q, tile.r, tile.folder, tile.name, tile.path)
        end
    end
    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "    markers = {"
    for _, markerType in ipairs(MARKER_TYPES) do
        for _, marker in ipairs(sortedValues(self.markers[markerType.name])) do
            lines[#lines + 1] = ("        { type = %q, q = %d, r = %d, value = %q },")
                :format(markerType.name, marker.q, marker.r, marker.value)
        end
    end
    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

function MapEditor:_saveMap(quitAfterSave)
    if not self.mapName then
        self:_beginNameInput(true, quitAfterSave)
        return
    end
    local path = nativeMapRoot() .. "/" .. mapFileName(self.mapName)
    local file, errorMessage = io.open(path, "wb")
    if not file then
        self.statusMessage = "SAVE FAILED: " .. tostring(errorMessage)
            .. "  [" .. path .. "]"
        return
    end
    local writeSucceeded, writeError = file:write(self:_mapSource())
    local closeSucceeded, closeError = file:close()
    if not writeSucceeded or closeSucceeded == nil then
        self.statusMessage = "SAVE FAILED: "
            .. tostring(writeError or closeError or "WRITE ERROR")
        return
    end
    self.dirty = false
    self.statusMessage = "SAVED  " .. mapFileName(self.mapName)
    if quitAfterSave then
        love.event.quit()
    end
end

function MapEditor:_showLoadPanel()
    self.paintButton = nil
    self.lastToolQ = nil
    self.lastToolR = nil
    local files = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(MAP_ROOT)) do
        if love.filesystem.getInfo(MAP_ROOT .. "/" .. item, "file")
            and item:lower():match("%.lua$") then
            files[#files + 1] = item
        end
    end
    table.sort(files, function(left, right)
        return left:lower() < right:lower()
    end)
    self.loadPanel = { files = files, selected = #files > 0 and 1 or 0 }
end

function MapEditor:_loadMap(fileName)
    local chunk, loadError = love.filesystem.load(MAP_ROOT .. "/" .. fileName)
    if not chunk then
        self.statusMessage = "LOAD FAILED: " .. tostring(loadError)
        return false
    end
    local ok, map = pcall(chunk)
    if not ok or type(map) ~= "table" then
        self.statusMessage = "LOAD FAILED: INVALID MAP"
        return false
    end

    local tiles = {
        base = {}, transition = {}, road = {}, river = {}, bridge = {}, overlay = {},
    }
    local markers = { terrain = {}, resource = {}, site = {} }
    local tileCount, markerCount = 0, 0
    for _, savedTile in ipairs(map.tiles or {}) do
        if LAYERS[savedTile.layer] and type(savedTile.q) == "number"
            and type(savedTile.r) == "number" and type(savedTile.path) == "string" then
            local centerX, centerY = axialToCenter(savedTile.q, savedTile.r)
            local tile = {
                q = savedTile.q, r = savedTile.r,
                folder = savedTile.folder, name = savedTile.name,
                path = savedTile.path, layer = savedTile.layer,
                layerOrder = LAYERS[savedTile.layer].order,
                image = self:_getImage(savedTile.path),
                centerX = centerX, centerY = centerY,
                drawX = centerX - TILE_CENTER_X,
                drawY = centerY - TILE_CENTER_Y,
            }
            tiles[savedTile.layer][hexKey(tile.q, tile.r)] = tile
            tileCount = tileCount + 1
        end
    end
    for _, savedMarker in ipairs(map.markers or {}) do
        if markers[savedMarker.type] and type(savedMarker.q) == "number"
            and type(savedMarker.r) == "number" and type(savedMarker.value) == "string" then
            local key = hexKey(savedMarker.q, savedMarker.r)
            markers[savedMarker.type][key] = {
                q = savedMarker.q, r = savedMarker.r, value = savedMarker.value,
            }
            markerCount = markerCount + 1
        end
    end
    self.tiles = tiles
    self.markers = markers
    self.tileCount = tileCount
    self.markerCount = markerCount
    self.mapName = type(map.name) == "string" and map.name
        or fileName:gsub("%.lua$", "")
    self.loadPanel = nil
    self:_markMapChanged()
    self.dirty = false
    self.statusMessage = "LOADED  " .. fileName
    return true
end

function MapEditor:_applyToolAtHover()
    if self.pickerActive or self.activeMode == "marker"
        or not self.paintButton or self.hoverQ == nil then
        self.lastToolQ = nil
        self.lastToolR = nil
        return false
    end

    local startQ = self.lastToolQ or self.hoverQ
    local startR = self.lastToolR or self.hoverR
    local deltaQ = self.hoverQ - startQ
    local deltaR = self.hoverR - startR
    local distance = math.max(
        math.abs(deltaQ),
        math.abs(deltaR),
        math.abs(deltaQ + deltaR)
    )
    local changed = false
    for step = 0, distance do
        local progress = distance > 0 and step / distance or 0
        local q, r = roundAxial(
            startQ + deltaQ * progress,
            startR + deltaR * progress
        )
        if self.paintButton == 1 then
            changed = self:_paint(q, r) or changed
        elseif self.paintButton == 2 then
            changed = self:_erase(q, r) or changed
        end
    end
    self.lastToolQ = self.hoverQ
    self.lastToolR = self.hoverR
    return changed
end

function MapEditor:_changeFolder(delta)
    local catalog = self.layerCatalogs[self.activeMode]
    catalog.folderIndex = wrapIndex(
        catalog.folderIndex + delta,
        #catalog.folders
    )
    catalog.tileIndex = 1
end

function MapEditor:_changeTile(delta)
    local folder = self:_currentFolder()
    local catalog = self.layerCatalogs[self.activeMode]
    catalog.tileIndex = wrapIndex(
        catalog.tileIndex + delta,
        #folder.files
    )
end

function MapEditor:_getSortedTiles()
    if self.drawOrderDirty then
        self.sortedTiles = {}
        for _, layerTiles in pairs(self.tiles) do
            for _, tile in pairs(layerTiles) do
                self.sortedTiles[#self.sortedTiles + 1] = tile
            end
        end
        table.sort(self.sortedTiles, tileDrawOrder)
        self.drawOrderDirty = false
    end
    return self.sortedTiles
end

function MapEditor:getMapBounds()
    if not self.boundsDirty then
        return self.bounds
    end

    local minimumQ, maximumQ, minimumR, maximumR
    for _, layerTiles in pairs(self.tiles) do
        for _, tile in pairs(layerTiles) do
            minimumQ = minimumQ and math.min(minimumQ, tile.q) or tile.q
            maximumQ = maximumQ and math.max(maximumQ, tile.q) or tile.q
            minimumR = minimumR and math.min(minimumR, tile.r) or tile.r
            maximumR = maximumR and math.max(maximumR, tile.r) or tile.r
        end
    end
    for _, markerType in ipairs(MARKER_TYPES) do
        for _, marker in pairs(self.markers[markerType.name]) do
            minimumQ = minimumQ and math.min(minimumQ, marker.q) or marker.q
            maximumQ = maximumQ and math.max(maximumQ, marker.q) or marker.q
            minimumR = minimumR and math.min(minimumR, marker.r) or marker.r
            maximumR = maximumR and math.max(maximumR, marker.r) or marker.r
        end
    end
    self.bounds = minimumQ and {
        minimumQ = minimumQ,
        maximumQ = maximumQ,
        minimumR = minimumR,
        maximumR = maximumR,
        width = maximumQ - minimumQ + 1,
        height = maximumR - minimumR + 1,
    } or nil
    self.boundsDirty = false
    return self.bounds
end

function MapEditor:update(dt)
    if self.markerInput or self.nameInput or self.loadPanel or self.exitPrompt then
        return
    end
    local horizontal = 0
    local vertical = 0
    if love.keyboard.isDown("a", "left") then
        horizontal = horizontal - 1
    end
    if love.keyboard.isDown("d", "right") then
        horizontal = horizontal + 1
    end
    if love.keyboard.isDown("w", "up") then
        vertical = vertical - 1
    end
    if love.keyboard.isDown("s", "down") then
        vertical = vertical + 1
    end
    if horizontal ~= 0 or vertical ~= 0 then
        local length = math.sqrt(horizontal * horizontal + vertical * vertical)
        self.cameraX = self.cameraX
            + horizontal / length * CAMERA_SPEED * dt
        self.cameraY = self.cameraY
            + vertical / length * CAMERA_SPEED * dt
    end

    local mouseX, mouseY = love.mouse.getPosition()
    self:_setHoverFromScreen(mouseX, mouseY)
    self:_applyToolAtHover()
end

function MapEditor:_isVisible(tile, cameraX, cameraY)
    return tile.drawX + TILE_SIZE >= cameraX
        and tile.drawX <= cameraX + VIRTUAL_WIDTH
        and tile.drawY + TILE_SIZE >= cameraY
        and tile.drawY <= cameraY + VIRTUAL_HEIGHT
end

function MapEditor:_ghostTile()
    if self.pickerActive or self.activeMode == "marker" or self.hoverQ == nil then
        return nil
    end

    local centerX, centerY = axialToCenter(self.hoverQ, self.hoverR)
    local paintLayer = self:_activePaintLayer()
    local existing = self.tiles[paintLayer][hexKey(self.hoverQ, self.hoverR)]
    local image
    local erasing = self.paintButton == 2
    if erasing then
        image = existing and existing.image or nil
    else
        local asset = self:_currentTileAsset()
        image = asset and self:_getImage(asset.path) or nil
    end
    if not image then
        return nil
    end

    return {
        image = image,
        centerX = centerX,
        centerY = centerY,
        drawX = centerX - TILE_CENTER_X,
        drawY = centerY - TILE_CENTER_Y,
        layerOrder = LAYERS[paintLayer].order,
        isGhost = true,
        erasing = erasing,
    }
end

function MapEditor:_drawMap()
    local cameraX, cameraY = self:_renderCameraPosition()
    local drawTiles = {}
    for _, tile in ipairs(self:_getSortedTiles()) do
        if self:_isVisible(tile, cameraX, cameraY) then
            drawTiles[#drawTiles + 1] = tile
        end
    end
    local ghost = self:_ghostTile()
    if ghost then
        drawTiles[#drawTiles + 1] = ghost
    end
    table.sort(drawTiles, tileDrawOrder)

    love.graphics.push()
    love.graphics.translate(-cameraX, -cameraY)
    for _, tile in ipairs(drawTiles) do
        if tile.isGhost then
            if tile.erasing then
                love.graphics.setColor(1, 0.25, 0.25, 0.52)
            else
                love.graphics.setColor(1, 1, 1, 0.56)
            end
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.draw(tile.image, tile.drawX, tile.drawY)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function MapEditor:_drawMarkers()
    local cameraX, cameraY = self:_renderCameraPosition()
    love.graphics.push()
    love.graphics.translate(-cameraX, -cameraY)
    for _, markerType in ipairs(MARKER_TYPES) do
        for _, marker in pairs(self.markers[markerType.name]) do
            local centerX, centerY = axialToCenter(marker.q, marker.r)
            local badgeX = centerX + markerType.offsetX
            local badgeY = centerY - 2
            love.graphics.setColor(0.04, 0.055, 0.085, 0.96)
            love.graphics.circle("fill", badgeX, badgeY, 13)
            love.graphics.setColor(0.35, 0.78, 1, 1)
            love.graphics.circle("line", badgeX, badgeY, 13)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(markerType.badge, badgeX - 13, badgeY - 9, 26, "center")
        end
    end
    if self.activeMode == "marker" and not self.pickerActive
        and self.hoverQ ~= nil then
        local markerType = self:_currentMarkerType()
        local centerX, centerY = axialToCenter(self.hoverQ, self.hoverR)
        local badgeX = centerX + markerType.offsetX
        local badgeY = centerY - 2
        love.graphics.setColor(1, self.paintButton == 2 and 0.25 or 1,
            self.paintButton == 2 and 0.25 or 1, 0.5)
        love.graphics.circle("fill", badgeX, badgeY, 13)
        love.graphics.setColor(0.05, 0.07, 0.1, 0.8)
        love.graphics.printf(markerType.badge, badgeX - 13, badgeY - 9, 26, "center")
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function MapEditor:_drawHUD()
    local bounds = self:getMapBounds()

    love.graphics.setColor(0.02, 0.025, 0.045, 0.97)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, HUD_HEIGHT)
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.rectangle("fill", 0, HUD_HEIGHT - 4, VIRTUAL_WIDTH, 4)

    love.graphics.setColor(0.9, 0.94, 1, 1)
    local asset
    if self.activeMode == "marker" then
        local markerType = self:_currentMarkerType()
        love.graphics.print("MARKER", 20, 14)
        love.graphics.print(("TYPE  [%d/%d]  %s"):format(
            self.markerTypeIndex, #MARKER_TYPES, markerType.label), 20, 42)
    else
        local layer = LAYERS[self.activeMode]
        local catalog = self.layerCatalogs[self.activeMode]
        local folder = self:_currentFolder()
        asset = self:_currentTileAsset()
        love.graphics.print(("%s  [%d/%d]  %s"):format(
            layer.label, catalog.folderIndex, #catalog.folders,
            folder.name:upper()), 20, 14)
        love.graphics.print(("TILE  [%d/%d]  %s"):format(
            catalog.tileIndex, #folder.files, asset.name), 20, 42)
    end
    local sizeText = bounds
        and ("%d x %d axial bounds"):format(bounds.width, bounds.height)
        or "empty"
    love.graphics.print(
        ("HEXES  %d  |  MARKERS  %d  |  MAP  %s"):format(
            self.tileCount, self.markerCount, sizeText),
        20,
        70
    )

    love.graphics.setColor(0.7, 0.78, 0.9, 1)
    love.graphics.print("B BASE   T TRANSITION   R RIVER/ROAD/BRIDGE   O OVERLAY   M MARKER", 460, 20)
    love.graphics.print("[ ] FOLDER   , . ITEM   P PICKER   LMB PAINT   RMB ERASE", 560, 52)
    love.graphics.print("WASD / ARROWS PAN   MMB DRAG PAN", 1180, 36)
    love.graphics.print("E SAVE   N NAME   L LOAD", 1180, 66)
    love.graphics.setColor(0.9, 0.94, 1, 1)
    love.graphics.print("NAME  " .. (self.mapName or "UNTITLED")
        .. (self.dirty and "  *" or ""), 20, 88)
    if self.statusMessage then
        love.graphics.setColor(1, 0.82, 0.25, 1)
        love.graphics.print(self.statusMessage, 560, 76)
    end

    local previewSize = 76
    local previewX = VIRTUAL_WIDTH - previewSize - 18
    local previewY = 12
    love.graphics.setColor(0.06, 0.075, 0.11, 1)
    love.graphics.rectangle(
        "fill",
        previewX,
        previewY,
        previewSize,
        previewSize
    )
    love.graphics.setColor(0.3, 0.36, 0.48, 1)
    love.graphics.rectangle(
        "line",
        previewX + 0.5,
        previewY + 0.5,
        previewSize - 1,
        previewSize - 1
    )
    if asset then
        local image = self:_getImage(asset.path)
        local scale = math.min(
            (previewSize - 8) / image:getWidth(),
            (previewSize - 8) / image:getHeight()
        )
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, previewX + previewSize / 2,
            previewY + previewSize / 2, 0, scale, scale,
            image:getWidth() / 2, image:getHeight() / 2)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(self:_currentMarkerType().badge,
            previewX, previewY + 25, previewSize, "center")
    end

    if self.pickerActive then
        love.graphics.setColor(1, 0.82, 0.25, 1)
        love.graphics.print("PICKER: CLICK AN EXISTING ITEM", 560, 76)
    end
end

function MapEditor:_drawMarkerInput()
    if not self.markerInput then
        return
    end
    local width, height = 760, 150
    local x = (VIRTUAL_WIDTH - width) / 2
    local y = (VIRTUAL_HEIGHT - height) / 2
    love.graphics.setColor(0.025, 0.035, 0.06, 0.98)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.35, 0.78, 1, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ENTER MARKER TEXT", x + 22, y + 18)
    love.graphics.setColor(0.09, 0.115, 0.16, 1)
    love.graphics.rectangle("fill", x + 22, y + 52, width - 44, 42)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.markerInput.value .. "_", x + 34, y + 63)
    love.graphics.setColor(0.7, 0.78, 0.9, 1)
    love.graphics.print("ENTER SAVE    ESC CANCEL", x + 22, y + 112)
end

function MapEditor:_drawNameInput()
    if not self.nameInput then
        return
    end
    local width, height = 760, 150
    local x = (VIRTUAL_WIDTH - width) / 2
    local y = (VIRTUAL_HEIGHT - height) / 2
    love.graphics.setColor(0.025, 0.035, 0.06, 0.98)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.35, 0.78, 1, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ENTER MAP NAME", x + 22, y + 18)
    love.graphics.setColor(0.09, 0.115, 0.16, 1)
    love.graphics.rectangle("fill", x + 22, y + 52, width - 44, 42)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.nameInput.value .. "_", x + 34, y + 63)
    love.graphics.setColor(0.7, 0.78, 0.9, 1)
    love.graphics.print("ENTER CONFIRM    ESC CANCEL", x + 22, y + 112)
end

function MapEditor:_drawLoadPanel()
    if not self.loadPanel then
        return
    end
    local width, height = 820, 650
    local x = (VIRTUAL_WIDTH - width) / 2
    local y = (VIRTUAL_HEIGHT - height) / 2
    love.graphics.setColor(0.025, 0.035, 0.06, 0.98)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.35, 0.78, 1, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("LOAD MAP", x + 24, y + 20)
    if #self.loadPanel.files == 0 then
        love.graphics.setColor(0.7, 0.78, 0.9, 1)
        love.graphics.print("NO SAVED MAPS FOUND", x + 24, y + 72)
    else
        local first = math.max(1, math.min(self.loadPanel.selected - 7,
            math.max(1, #self.loadPanel.files - 14)))
        local last = math.min(#self.loadPanel.files, first + 14)
        for index = first, last do
            local rowY = y + 62 + (index - first) * 34
            if index == self.loadPanel.selected then
                love.graphics.setColor(0.12, 0.3, 0.48, 1)
                love.graphics.rectangle("fill", x + 20, rowY - 5, width - 40, 30)
            end
            love.graphics.setColor(0.9, 0.94, 1, 1)
            love.graphics.print(self.loadPanel.files[index], x + 34, rowY)
        end
    end
    love.graphics.setColor(0.7, 0.78, 0.9, 1)
    love.graphics.print("UP/DOWN SELECT    ENTER LOAD    ESC CANCEL", x + 24, y + height - 42)
end

function MapEditor:_drawExitPrompt()
    if not self.exitPrompt then
        return
    end
    local width, height = 720, 180
    local x = (VIRTUAL_WIDTH - width) / 2
    local y = (VIRTUAL_HEIGHT - height) / 2
    love.graphics.setColor(0.025, 0.035, 0.06, 0.98)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 0.62, 0.24, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SAVE CHANGES BEFORE EXITING?", x + 24, y + 28)
    love.graphics.setColor(0.7, 0.78, 0.9, 1)
    love.graphics.print("Y SAVE    N DISCARD    ESC CANCEL", x + 24, y + 92)
end

function MapEditor:draw()
    love.graphics.setCanvas(self.mapCanvas)
    love.graphics.clear(0.035, 0.045, 0.065, 1)
    self:_drawMap()

    love.graphics.setCanvas(self.uiCanvas)
    love.graphics.clear(0, 0, 0, 0)
    self:_drawMarkers()
    self:_drawHUD()
    self:_drawMarkerInput()
    self:_drawNameInput()
    self:_drawLoadPanel()
    self:_drawExitPrompt()
    love.graphics.setCanvas()

    local windowWidth, windowHeight = love.graphics.getDimensions()
    local scale = math.min(
        windowWidth / VIRTUAL_WIDTH,
        windowHeight / VIRTUAL_HEIGHT
    )
    local drawWidth = VIRTUAL_WIDTH * scale
    local drawHeight = VIRTUAL_HEIGHT * scale
    self.outputScale = scale
    self.outputOffsetX = math.floor((windowWidth - drawWidth) / 2)
    self.outputOffsetY = math.floor((windowHeight - drawHeight) / 2)

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self.mapCanvas,
        self.outputOffsetX,
        self.outputOffsetY,
        0,
        scale,
        scale
    )
    love.graphics.draw(
        self.uiCanvas,
        self.outputOffsetX,
        self.outputOffsetY,
        0,
        scale,
        scale
    )
end

function MapEditor:keypressed(key, _scancode, isRepeat)
    if self.exitPrompt then
        if key == "y" then
            self.exitPrompt = false
            self:_saveMap(true)
        elseif key == "n" then
            self.exitPrompt = false
            self.allowQuit = true
            love.event.quit()
        elseif key == "escape" then
            self.exitPrompt = false
        end
        return
    end
    if self.markerInput then
        if key == "return" or key == "kpenter" then
            self:_finishMarkerInput(true)
        elseif key == "escape" then
            self:_finishMarkerInput(false)
        elseif key == "backspace" then
            local byteOffset = utf8.offset(self.markerInput.value, -1)
            if byteOffset then
                self.markerInput.value = self.markerInput.value:sub(1, byteOffset - 1)
            end
        end
        return
    end
    if self.nameInput then
        if key == "return" or key == "kpenter" then
            self:_finishNameInput(true)
        elseif key == "escape" then
            self:_finishNameInput(false)
        elseif key == "backspace" then
            local byteOffset = utf8.offset(self.nameInput.value, -1)
            if byteOffset then
                self.nameInput.value = self.nameInput.value:sub(1, byteOffset - 1)
            end
        end
        return
    end
    if self.loadPanel then
        if key == "escape" then
            self.loadPanel = nil
        elseif #self.loadPanel.files > 0 then
            if key == "up" then
                self.loadPanel.selected = wrapIndex(
                    self.loadPanel.selected - 1, #self.loadPanel.files)
            elseif key == "down" then
                self.loadPanel.selected = wrapIndex(
                    self.loadPanel.selected + 1, #self.loadPanel.files)
            elseif key == "return" or key == "kpenter" then
                self:_loadMap(self.loadPanel.files[self.loadPanel.selected])
            end
        end
        return
    end
    if key == "escape" then
        if self.dirty then
            self.paintButton = nil
            self.exitPrompt = true
        else
            love.event.quit()
        end
    elseif not isRepeat and key == "e" then
        self:_saveMap()
    elseif not isRepeat and key == "n" then
        self:_beginNameInput(false)
    elseif not isRepeat and key == "l" then
        self:_showLoadPanel()
    elseif not isRepeat and self.activeMode ~= "marker"
        and (key == "[" or key == "leftbracket") then
        self:_changeFolder(-1)
    elseif not isRepeat and self.activeMode ~= "marker"
        and (key == "]" or key == "rightbracket") then
        self:_changeFolder(1)
    elseif not isRepeat and key == "," then
        if self.activeMode == "marker" then
            self.markerTypeIndex = wrapIndex(self.markerTypeIndex - 1, #MARKER_TYPES)
            self.copiedMarkerString = nil
        else
            self:_changeTile(-1)
        end
    elseif not isRepeat and key == "." then
        if self.activeMode == "marker" then
            self.markerTypeIndex = wrapIndex(self.markerTypeIndex + 1, #MARKER_TYPES)
            self.copiedMarkerString = nil
        else
            self:_changeTile(1)
        end
    elseif not isRepeat and key == "p" then
        self.pickerActive = not self.pickerActive
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    elseif not isRepeat and key == "b" then
        self.activeMode = "base"
        self.pickerActive = false
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    elseif not isRepeat and key == "t" then
        self.activeMode = "transition"
        self.pickerActive = false
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    elseif not isRepeat and key == "r" then
        self.activeMode = "road"
        self.pickerActive = false
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    elseif not isRepeat and key == "o" then
        self.activeMode = "overlay"
        self.pickerActive = false
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    elseif not isRepeat and key == "m" then
        self.activeMode = "marker"
        self.pickerActive = false
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    end
end

function MapEditor:textinput(text)
    if self.markerInput then
        self.markerInput.value = self.markerInput.value .. text
    elseif self.nameInput then
        self.nameInput.value = self.nameInput.value .. text
    end
end

function MapEditor:mousepressed(x, y, button)
    if self.loadPanel then
        if button == 1 and #self.loadPanel.files > 0 then
            local virtualX, virtualY = self:_screenToVirtual(x, y)
            local panelWidth, panelHeight = 820, 650
            local panelX = (VIRTUAL_WIDTH - panelWidth) / 2
            local panelY = (VIRTUAL_HEIGHT - panelHeight) / 2
            local first = math.max(1, math.min(self.loadPanel.selected - 7,
                math.max(1, #self.loadPanel.files - 14)))
            local row = virtualY and math.floor((virtualY - panelY - 57) / 34) or -1
            local index = first + row
            if virtualX and virtualX >= panelX + 20
                and virtualX <= panelX + panelWidth - 20
                and row >= 0 and row <= 14
                and index <= #self.loadPanel.files then
                self:_loadMap(self.loadPanel.files[index])
            end
        end
        return
    end
    if self.markerInput or self.nameInput or self.exitPrompt then
        return
    end
    if button == 3 then
        self.middleDragging = true
        return
    end
    if button ~= 1 and button ~= 2 then
        return
    end
    self:_setHoverFromScreen(x, y)
    if self.hoverQ == nil then
        return
    end
    if self.pickerActive then
        if button == 1 then
            self:_pickAt(self.hoverQ, self.hoverR)
        end
        return
    end
    if self.activeMode == "marker" then
        local markerTable = self.markers[self:_currentMarkerType().name]
        local existing = markerTable[hexKey(self.hoverQ, self.hoverR)]
        if button == 2 then
            self:_eraseMarker(self.hoverQ, self.hoverR)
        elseif existing then
            self:_beginMarkerInput(self.hoverQ, self.hoverR)
        elseif self.copiedMarkerString ~= nil then
            self:_setMarker(self.hoverQ, self.hoverR, self.copiedMarkerString)
        else
            self:_beginMarkerInput(self.hoverQ, self.hoverR)
        end
        return
    end
    self.paintButton = button
    self.lastToolQ = nil
    self.lastToolR = nil
    self:_applyToolAtHover()
end

function MapEditor:mousereleased(_x, _y, button)
    if button == 3 then
        self.middleDragging = false
    elseif button == self.paintButton then
        self.paintButton = nil
        self.lastToolQ = nil
        self.lastToolR = nil
    end
end

function MapEditor:mousemoved(x, y, dx, dy)
    if self.markerInput or self.nameInput or self.loadPanel or self.exitPrompt then
        return
    end
    if self.middleDragging then
        self.cameraX = self.cameraX - dx / self.outputScale
        self.cameraY = self.cameraY - dy / self.outputScale
    end
    self:_setHoverFromScreen(x, y)
    self:_applyToolAtHover()
end

function MapEditor:exit()
    love.keyboard.setTextInput(false)
    self.mapCanvas = nil
    self.uiCanvas = nil
    self.tiles = {}
    self.markers = {}
    self.sortedTiles = {}
    self.imageCache = {}
end

function MapEditor:quit()
    if self.dirty and not self.allowQuit then
        self.paintButton = nil
        self.exitPrompt = true
        return true
    end
    return false
end

return MapEditor
