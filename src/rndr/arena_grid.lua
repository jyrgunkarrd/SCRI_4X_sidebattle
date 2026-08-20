local ArenaGrid = {}
ArenaGrid.__index = ArenaGrid

function ArenaGrid.new(options)
    options = options or {}

    local self = setmetatable({}, ArenaGrid)
    self.columns = options.columns or 20
    self.rows = options.rows or 3
    self.virtualWidth = options.virtualWidth or 1920
    self.virtualHeight = options.virtualHeight or 1080
    self.cellHeight = math.floor(self.virtualHeight / self.rows)
    self.cellWidth = options.cellWidth or self.cellHeight
    self.cellSize = self.cellHeight
    self.width = self.cellWidth * self.columns
    self.height = self.cellHeight * self.rows
    self.linesVisible = options.linesVisible == true
    self.x = self.width > self.virtualWidth
        and 0
        or math.floor((self.virtualWidth - self.width) / 2)
    self.y = options.anchor == "bottom"
        and (self.virtualHeight - self.height)
        or math.floor((self.virtualHeight - self.height) / 2)
    return self
end

function ArenaGrid:setLinesVisible(visible)
    self.linesVisible = visible == true
end

function ArenaGrid:toggleLines()
    self.linesVisible = not self.linesVisible
    return self.linesVisible
end

function ArenaGrid:areLinesVisible()
    return self.linesVisible
end

function ArenaGrid:draw()
    if not self.linesVisible then
        return
    end

    for row = 1, self.rows do
        for column = 1, self.columns do
            local x = self.x + (column - 1) * self.cellWidth
            local y = self.y + (row - 1) * self.cellHeight

            love.graphics.setColor(0.75, 0.85, 0.95, 0.45)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y,
                self.cellWidth, self.cellHeight)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaGrid
