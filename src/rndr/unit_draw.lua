local UnitDraw = {}
UnitDraw.__index = UnitDraw

local IMAGE_DIRECTORY = "assets/images/units"

function UnitDraw.new(arenaGrid, arenaScale)
    local self = setmetatable({}, UnitDraw)
    self.grid = assert(arenaGrid, "Arena grid is required")
    arenaScale = arenaScale or {}
    self.arenaScale = arenaScale.scale or 1
    assert(type(self.arenaScale) == "number" and self.arenaScale > 0,
        "Arena scale must be a positive number")
    self.images = {}
    self.panelImages = {}
    return self
end

function UnitDraw:_getImage(unitId)
    if not self.images[unitId] then
        local path = ("%s/%s.png"):format(IMAGE_DIRECTORY, unitId)
        assert(love.filesystem.getInfo(path, "file"),
            ("Unit '%s' has no matching image at %s"):format(unitId, path))
        local image = love.graphics.newImage(path, {
            mipmaps = true,
        })
        image:setFilter("linear", "linear", 8)
        image:setMipmapFilter("linear", 0)
        self.images[unitId] = image
    end
    return self.images[unitId]
end

function UnitDraw:getImage(unitId)
    return self:_getImage(unitId)
end

function UnitDraw:getPanelImage(unitId)
    if not self.panelImages[unitId] then
        local panelPath = ("%s/%s_panel.png"):format(IMAGE_DIRECTORY, unitId)

        if love.filesystem.getInfo(panelPath, "file") then
            local image = love.graphics.newImage(panelPath, {
                mipmaps = true,
            })
            image:setFilter("linear", "linear", 8)
            image:setMipmapFilter("linear", 0)
            self.panelImages[unitId] = image
        else
            self.panelImages[unitId] = self:_getImage(unitId)
        end
    end

    return self.panelImages[unitId]
end

function UnitDraw:getFacingSign(unit, facing)
    return (facing or unit.facing or "right") == "left" and -1 or 1
end

local function drawOrder(left, right)
    local leftLayer = tonumber(left.definition.layer) or 1
    local rightLayer = tonumber(right.definition.layer) or 1

    -- LÖVE draws later items on top, so lower layer values are emitted last.
    if leftLayer ~= rightLayer then
        return leftLayer > rightLayer
    end

    if left.targH ~= right.targH then
        return left.targH > right.targH
    end
    if left.targW ~= right.targW then
        return left.targW < right.targW
    end
    local leftOffset = left.arenaCellOffsetX or 0
    local rightOffset = right.arenaCellOffsetX or 0
    if leftOffset ~= rightOffset then
        -- Later draws appear on top, so right-hand slots are emitted first.
        return leftOffset > rightOffset
    end
    if left.unitId ~= right.unitId then
        return left.unitId < right.unitId
    end

    -- Population indices run left to right. Draw rightmost units first so
    -- the units to their left overlap them.
    if left.populationIndex ~= right.populationIndex then
        return left.populationIndex > right.populationIndex
    end

    return left.instanceId < right.instanceId
end

function UnitDraw:_orderedUnits(units)
    local orderedUnits = {}
    for index, unit in ipairs(units) do
        orderedUnits[index] = unit
    end
    table.sort(orderedUnits, drawOrder)
    return orderedUnits
end

function UnitDraw:_visualAt(unit, targW, targH, lift, scaleMultiplier, cellOffsetX)
    local image = self:_getImage(unit.unitId)
    local relativeScale = unit.definition.scale or 1
    local scale = self.arenaScale * relativeScale * (scaleMultiplier or 1)
    local cellLeft = self.grid.x + (targW - 1) * self.grid.cellWidth
    local visualRow = self.grid.rows - targH
    local cellTop = self.grid.y + visualRow * self.grid.cellHeight
    local spacing = math.min(32,
        self.grid.cellWidth / math.max(unit.population, 1))
    local populationOffset = cellOffsetX
    if populationOffset == nil then
        populationOffset = (unit.populationIndex - (unit.population + 1) / 2) * spacing
    end

    return image,
        cellLeft + self.grid.cellWidth / 2 + populationOffset,
        cellTop + self.grid.cellHeight
            - (lift or 0)
            - (unit.arenaLayerOffsetY or 0),
        scale
end

function UnitDraw:_visual(unit, lift, scaleMultiplier)
    local image, x, y, scale = self:_visualAt(
        unit,
        unit.visualTargW or unit.targW,
        unit.targH,
        lift,
        scaleMultiplier,
        unit.arenaCellOffsetX
    )
    return image,
        x + (unit.attackVfxOffsetX or 0) + (unit.defeatSlideX or 0),
        y + (unit.attackVfxOffsetY or 0),
        scale
end

function UnitDraw:getUnitVisualAt(
    unit,
    targW,
    targH,
    lift,
    scaleMultiplier,
    cellOffsetX
)
    if cellOffsetX == nil and targW == unit.targW and targH == unit.targH then
        cellOffsetX = unit.arenaCellOffsetX
    end
    return self:_visualAt(
        unit,
        targW,
        targH,
        lift,
        scaleMultiplier,
        cellOffsetX
    )
end

function UnitDraw:_drawUnit(unit, lift, scaleMultiplier)
    local image, x, y, scale = self:_visual(unit, lift, scaleMultiplier)
    local scaleX = scale * self:getFacingSign(unit)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        image,
        x,
        y,
        0,
        scaleX,
        scale,
        image:getWidth() / 2,
        image:getHeight()
    )
end

function UnitDraw:getUnitBounds(unit, lift, scaleMultiplier)
    local image, x, y, scale = self:_visual(unit, lift, scaleMultiplier)
    local width = image:getWidth() * scale
    local height = image:getHeight() * scale
    return x - width / 2, y - height, x + width / 2, y
end

function UnitDraw:getUnitAt(worldX, worldY, units, predicate)
    local orderedUnits = self:_orderedUnits(units)

    for index = #orderedUnits, 1, -1 do
        local unit = orderedUnits[index]
        local left, top, right, bottom = self:getUnitBounds(unit)

        if (not predicate or predicate(unit))
            and worldX >= left and worldX <= right
            and worldY >= top and worldY <= bottom then
            return unit
        end
    end

    return nil
end

function UnitDraw:drawUnit(unit, overlays, enemyArenaSystem, isSelected)
    local hasStatus = overlays and enemyArenaSystem
        and overlays:beginUnitStatus(
            unit,
            enemyArenaSystem,
            false,
            isSelected
        )
    self:_drawUnit(unit)
    if hasStatus then
        overlays:endUnitStatus()
    end
end

function UnitDraw:draw(units, hoveredUnit, overlays, excludedUnit, options)
    options = options or {}
    local orderedUnits = self:_orderedUnits(units)
    for _, unit in ipairs(orderedUnits) do
        if unit ~= hoveredUnit and unit ~= excludedUnit then
            local sharesHoveredCell = hoveredUnit
                and unit.targW == hoveredUnit.targW
                and unit.targH == hoveredUnit.targH
            local isEnemy = options.enemyArenaSystem
                and options.enemyArenaSystem:isEnemy(unit)
            local shouldDim = sharesHoveredCell
                and (not options.dimEnemiesOnly or isEnemy)
            local hasStatus = overlays and options.enemyArenaSystem
                and overlays:beginUnitStatus(
                    unit,
                    options.enemyArenaSystem,
                    shouldDim,
                    false
                )

            if shouldDim and overlays and not hasStatus then
                overlays:beginUnitDim()
            end
            self:_drawUnit(unit)
            if hasStatus then
                overlays:endUnitStatus()
            elseif shouldDim and overlays then
                overlays:endUnitDim()
            end
        end
    end

    if hoveredUnit and hoveredUnit ~= excludedUnit and not options.deferFocusedUnit then
        self:drawUnit(hoveredUnit, overlays, options.enemyArenaSystem, false)
    end
end

return UnitDraw
