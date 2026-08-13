local ArenaGrid = {}
ArenaGrid.__index = ArenaGrid

function ArenaGrid.new(options)
    options = options or {}

    local self = setmetatable({}, ArenaGrid)
    self.columns = options.columns or 20
    self.rows = options.rows or 3
    self.virtualWidth = options.virtualWidth or 1920
    self.virtualHeight = options.virtualHeight or 1080
    self.cellSize = math.floor(self.virtualHeight / self.rows)
    self.width = self.cellSize * self.columns
    self.height = self.cellSize * self.rows
    self.x = self.width > self.virtualWidth
        and 0
        or math.floor((self.virtualWidth - self.width) / 2)
    self.y = options.anchor == "bottom"
        and (self.virtualHeight - self.height)
        or math.floor((self.virtualHeight - self.height) / 2)
    return self
end

function ArenaGrid:draw()
    for row = 1, self.rows do
        for column = 1, self.columns do
            local x = self.x + (column - 1) * self.cellSize
            local y = self.y + (row - 1) * self.cellSize

            love.graphics.setColor(0.75, 0.85, 0.95, 0.45)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, self.cellSize, self.cellSize)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaGrid
