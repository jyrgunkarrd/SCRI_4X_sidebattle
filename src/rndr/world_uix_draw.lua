local WorldUIXDraw = {}
WorldUIXDraw.__index = WorldUIXDraw
local WorldUnitStackSystem = require("src.sys.world_ustack_sys")

local TERRAIN_IMAGE_ROOT = "assets/images/terrain"
local RESOURCE_IMAGE_ROOT = "assets/images/resources"
local PANEL_X = 24
local PANEL_WIDTH = 430
local PANEL_HEIGHT = 144
local PANEL_MARGIN_BOTTOM = 24
local IMAGE_SIZE = 112
local UNIT_IMAGE_ROOT = "assets/images/units"
local STACK_PANEL_MARGIN = 24
local STACK_PANEL_WIDTH = 540
local STACK_PANEL_HEIGHT = 760
local STACK_COLUMNS = 3
local STACK_ROWS = 4
local FONT_PATH = "assets/fonts/Furore.otf"
local UNIT_LABEL_MAX_FONT_SIZE = 18
local UNIT_LABEL_MIN_FONT_SIZE = 9

function WorldUIXDraw.new(options)
    options = options or {}
    local self = setmetatable({}, WorldUIXDraw)
    self.virtualHeight = options.virtualHeight or 1080
    self.virtualWidth = options.virtualWidth or 1920
    self.hoveredTerrain = nil
    self.hoveredResource = nil
    self.images = {}
    self.unitLabelFonts = {}
    self.phaseFont = love.graphics.newFont(FONT_PATH, 38)
    self.selectedStack = nil
    self.activeStack = nil
    return self
end

function WorldUIXDraw:drawTurnAnnouncement(turnSystem)
    local text, phase, alpha = turnSystem:getAnnouncement()
    if not text then
        return
    end
    local boxWidth = 520
    local boxHeight = 132
    local x = math.floor((self.virtualWidth - boxWidth) / 2 + 0.5)
    local y = math.floor((self.virtualHeight - boxHeight) / 2 + 0.5)
    love.graphics.setShader()
    love.graphics.setColor(0.015, 0.02, 0.035, 0.92 * alpha)
    love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 6, 6)
    if phase == "enemy" then
        love.graphics.setColor(1, 0x42 / 255, 0x42 / 255, alpha)
    else
        love.graphics.setColor(0.3, 0.7, 1, alpha)
    end
    love.graphics.rectangle("fill", x, y, 6, boxHeight, 3, 3)
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(self.phaseFont)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(text, x + 28, y + 23,
        boxWidth - 56, "center")
    love.graphics.setFont(previousFont)
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldUIXDraw:_getUnitLabelFont(text, maximumWidth, maximumHeight)
    for size = UNIT_LABEL_MAX_FONT_SIZE, UNIT_LABEL_MIN_FONT_SIZE, -1 do
        local font = self.unitLabelFonts[size]
        if not font then
            font = love.graphics.newFont(FONT_PATH, size)
            self.unitLabelFonts[size] = font
        end
        if font:getWidth(text) <= maximumWidth
            and font:getHeight() <= maximumHeight then
            return font
        end
    end
    return self.unitLabelFonts[UNIT_LABEL_MIN_FONT_SIZE]
end

function WorldUIXDraw:setSelectedStack(stack, activeStack)
    self.selectedStack = stack
    self.activeStack = activeStack
end


function WorldUIXDraw:_getStackPanelLayout()
    local panelX = self.virtualWidth - STACK_PANEL_WIDTH - STACK_PANEL_MARGIN
    local panelY = STACK_PANEL_MARGIN
    local gap = 8
    return {
        panelX = panelX,
        panelY = panelY,
        gridX = panelX + 16,
        gridY = panelY + 54,
        gap = gap,
        cellWidth = (STACK_PANEL_WIDTH - 32 - gap * 2) / STACK_COLUMNS,
        cellHeight = (STACK_PANEL_HEIGHT - 70 - gap * 3) / STACK_ROWS,
    }
end

function WorldUIXDraw:isPointInStackPanel(x, y)
    if not self.selectedStack then
        return false
    end
    local layout = self:_getStackPanelLayout()
    return x >= layout.panelX and x <= layout.panelX + STACK_PANEL_WIDTH
        and y >= layout.panelY and y <= layout.panelY + STACK_PANEL_HEIGHT
end

function WorldUIXDraw:getStackUnitAtPoint(x, y)
    if not self:isPointInStackPanel(x, y) then
        return nil
    end
    local layout = self:_getStackPanelLayout()
    for index, unit in ipairs(self.selectedStack.units) do
        local column = (index - 1) % STACK_COLUMNS
        local row = math.floor((index - 1) / STACK_COLUMNS)
        local cellX = layout.gridX
            + column * (layout.cellWidth + layout.gap)
        local cellY = layout.gridY
            + row * (layout.cellHeight + layout.gap)
        if x >= cellX and x <= cellX + layout.cellWidth
            and y >= cellY and y <= cellY + layout.cellHeight then
            return unit
        end
    end
    return nil
end

function WorldUIXDraw:_getUnitPanelImage(unit)
    local key = "unit-panel/" .. unit.id
    if self.images[key] then
        return self.images[key]
    end
    local panelPath = ("%s/%s_panel.png"):format(UNIT_IMAGE_ROOT, unit.id)
    local path = love.filesystem.getInfo(panelPath, "file")
        and panelPath or ("%s/%s.png"):format(UNIT_IMAGE_ROOT, unit.id)
    assert(love.filesystem.getInfo(path, "file"),
        ("World stack panel image does not exist: %s"):format(path))
    local image = love.graphics.newImage(path)
    image:setFilter("linear", "linear")
    self.images[key] = image
    return image
end

function WorldUIXDraw:_drawSelectedStack()
    local stack = self.selectedStack
    if not stack then
        return
    end
    local layout = self:_getStackPanelLayout()
    local panelX = layout.panelX
    local panelY = layout.panelY
    love.graphics.setColor(0.025, 0.035, 0.06, 0.96)
    love.graphics.rectangle("fill", panelX, panelY,
        STACK_PANEL_WIDTH, STACK_PANEL_HEIGHT)
    love.graphics.setColor(1, 0.84, 0.25, 1)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5,
        STACK_PANEL_WIDTH - 1, STACK_PANEL_HEIGHT - 1)
    love.graphics.setColor(0.94, 0.97, 1, 1)
    local formationName = WorldUnitStackSystem.getFormationName(#stack.units)
    love.graphics.print(("%s  %d/%d"):format(
        formationName:upper(),
        #stack.units,
        STACK_COLUMNS * STACK_ROWS
    ), panelX + 18, panelY + 16)

    local gridX = layout.gridX
    local gridY = layout.gridY
    local gap = layout.gap
    local cellWidth = layout.cellWidth
    local cellHeight = layout.cellHeight
    local activeUnits = {}
    if self.activeStack then
        for _, activeUnit in ipairs(self.activeStack.units) do
            activeUnits[activeUnit] = true
        end
    end
    for index, unit in ipairs(stack.units) do
        local column = (index - 1) % STACK_COLUMNS
        local row = math.floor((index - 1) / STACK_COLUMNS)
        local x = gridX + column * (cellWidth + gap)
        local y = gridY + row * (cellHeight + gap)
        love.graphics.setColor(0.07, 0.09, 0.13, 1)
        love.graphics.rectangle("fill", x, y, cellWidth, cellHeight)
        if activeUnits[unit] then
            love.graphics.setColor(1, 0.84, 0.25, 1)
        else
            love.graphics.setColor(0.18, 0.22, 0.28, 1)
        end
        love.graphics.rectangle("line", x + 0.5, y + 0.5,
            cellWidth - 1, cellHeight - 1)
        local image = self:_getUnitPanelImage(unit)
        local imageHeight = cellHeight - 28
        local scale = math.min(cellWidth / image:getWidth(),
            imageHeight / image:getHeight())
        local contentAlpha = unit.exhausted and 0.32 or 1
        love.graphics.setColor(1, 1, 1, contentAlpha)
        love.graphics.draw(image, x + cellWidth / 2, y + imageHeight / 2,
            0, scale, scale, image:getWidth() / 2, image:getHeight() / 2)
        local unitName = unit.definition.name or unit.id
        local labelHeight = 20
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self:_getUnitLabelFont(
            unitName,
            cellWidth - 8,
            labelHeight
        ))
        love.graphics.setColor(0.94, 0.97, 1, contentAlpha)
        love.graphics.printf(unitName, x + 4, y + cellHeight - 24,
            cellWidth - 8, "center")
        love.graphics.setFont(previousFont)
    end
end

function WorldUIXDraw:setHoveredTerrain(terrain)
    self.hoveredTerrain = terrain
    self.hoveredResource = nil
end

function WorldUIXDraw:setHoveredResource(resource)
    self.hoveredResource = resource
    self.hoveredTerrain = nil
end

function WorldUIXDraw:_getImage(definition, imageRoot)
    local suffix = imageRoot == RESOURCE_IMAGE_ROOT and "_panel" or ""
    local key = imageRoot .. "/" .. definition.id .. suffix
    local image = self.images[key]
    if image then
        return image
    end
    local path = ("%s/%s%s.png"):format(
        imageRoot,
        definition.id,
        suffix
    )
    assert(love.filesystem.getInfo(path, "file"),
        ("World UI image does not exist: %s"):format(path))
    image = love.graphics.newImage(path)
    image:setFilter("linear", "linear")
    self.images[key] = image
    return image
end

function WorldUIXDraw:draw()
    local panelY = self.virtualHeight - PANEL_HEIGHT - PANEL_MARGIN_BOTTOM
    love.graphics.setColor(0.025, 0.035, 0.06, 0.94)
    love.graphics.rectangle("fill", PANEL_X, panelY, PANEL_WIDTH, PANEL_HEIGHT)
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.rectangle("line", PANEL_X + 0.5, panelY + 0.5,
        PANEL_WIDTH - 1, PANEL_HEIGHT - 1)

    local imageX = PANEL_X + 16
    local imageY = panelY + 16
    love.graphics.setColor(0.07, 0.09, 0.13, 1)
    love.graphics.rectangle("fill", imageX, imageY, IMAGE_SIZE, IMAGE_SIZE)

    local definition = self.hoveredResource or self.hoveredTerrain
    local imageRoot = self.hoveredResource
        and RESOURCE_IMAGE_ROOT or TERRAIN_IMAGE_ROOT
    if definition then
        local image = self:_getImage(definition, imageRoot)
        local scale = math.min(
            IMAGE_SIZE / image:getWidth(),
            IMAGE_SIZE / image:getHeight()
        )
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, imageX + IMAGE_SIZE / 2,
            imageY + IMAGE_SIZE / 2, 0, scale, scale,
            image:getWidth() / 2, image:getHeight() / 2)
    end

    love.graphics.setColor(0.65, 0.74, 0.88, 1)
    local heading = self.hoveredResource and "RESOURCE" or "TERRAIN"
    love.graphics.print(heading, PANEL_X + 150, panelY + 30)
    love.graphics.setColor(0.94, 0.97, 1, 1)
    love.graphics.printf(definition and definition.name or "NO TERRAIN",
        PANEL_X + 150, panelY + 64, PANEL_WIDTH - 174, "left")
    self:_drawSelectedStack()
end

return WorldUIXDraw
