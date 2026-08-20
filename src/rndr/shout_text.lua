local ShoutText = {}
ShoutText.__index = ShoutText
local utf8 = require("utf8")
local FactionSystem = require("src.sys.faction_sys")

local FONT_PATH = "assets/fonts/Furore.otf"

local function getSelectShout(unit)
    local shout = unit and unit.definition.shout
    if type(shout) ~= "table" then
        return nil
    end

    if type(shout.select) == "string" then
        return shout.select
    end

    for _, entry in ipairs(shout) do
        if type(entry) == "table" and type(entry.select) == "string" then
            return entry.select
        end
    end

    return nil
end

local function visibleText(text, characterCount)
    local totalCharacters = utf8.len(text) or #text
    if characterCount >= totalCharacters then
        return text
    end

    local nextByte = utf8.offset(text, characterCount + 1)
    return nextByte and text:sub(1, nextByte - 1) or text
end

function ShoutText.new(options)
    options = options or {}

    local self = setmetatable({}, ShoutText)
    self.duration = options.duration or 0.9
    self.fadeDuration = options.fadeDuration or 0.3
    self.appearDuration = options.appearDuration or 0.12
    self.charactersPerSecond = options.charactersPerSecond or 64
    self.maximumWidth = options.maximumWidth or 360
    self.paddingX = options.paddingX or 18
    self.paddingY = options.paddingY or 10
    self.font = love.graphics.newFont(FONT_PATH, options.fontSize or 22)
    self.unit = nil
    self.text = nil
    self.timeRemaining = 0
    self.elapsed = 0
    self.characterCount = 0
    self.typingDuration = 0
    return self
end

function ShoutText:show(unit)
    local text = getSelectShout(unit)
    if not text or text == "" then
        self:clear()
        return
    end

    self.unit = unit
    self.text = text
    self.characterCount = utf8.len(text) or #text
    self.typingDuration = self.characterCount / self.charactersPerSecond
    self.elapsed = 0
    self.timeRemaining = self.typingDuration + self.duration
end

function ShoutText:clear()
    self.unit = nil
    self.text = nil
    self.timeRemaining = 0
    self.elapsed = 0
    self.characterCount = 0
    self.typingDuration = 0
end

function ShoutText:update(dt)
    if self.timeRemaining <= 0 then
        return
    end

    self.elapsed = self.elapsed + dt
    self.timeRemaining = math.max(0, self.timeRemaining - dt)
    if self.timeRemaining == 0 then
        self:clear()
    end
end

function ShoutText:draw(unitDraw, camera, arenaHeight)
    if not self.unit or not self.text then
        return
    end

    local left, _top, right, bottom = unitDraw:getUnitBounds(self.unit)
    local centerX, screenBottom = camera:worldToScreen((left + right) / 2, bottom)
    local textWidth = math.min(self.font:getWidth(self.text), self.maximumWidth)
    local wrapWidth = math.max(1, textWidth)
    local _, wrappedLines = self.font:getWrap(self.text, wrapWidth)
    local boxWidth = wrapWidth + self.paddingX * 2
    local boxHeight = #wrappedLines * self.font:getHeight() + self.paddingY * 2
    local x = math.floor(math.max(8, math.min(
        centerX - boxWidth / 2,
        camera.viewportWidth - boxWidth - 8
    )) + 0.5)
    local y = math.floor(math.max(8, math.min(
        screenBottom - boxHeight - 8,
        arenaHeight - boxHeight - 8
    )) + 0.5)
    local alpha = math.min(1, self.timeRemaining / self.fadeDuration)
        * math.min(1, self.elapsed / self.appearDuration)
    local revealedCharacters = math.min(
        self.characterCount,
        math.floor(self.elapsed * self.charactersPerSecond)
    )
    local displayedText = visibleText(self.text, revealedCharacters)
    local isEnemy = FactionSystem.isEnemy(self.unit)

    love.graphics.setShader()
    love.graphics.setColor(0.015, 0.02, 0.035, 0.88 * alpha)
    love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 5, 5)
    if isEnemy then
        love.graphics.setColor(1, 0x42 / 255, 0x42 / 255, 0.9 * alpha)
    else
        love.graphics.setColor(0.62, 0.78, 0.94, 0.9 * alpha)
    end
    love.graphics.rectangle("fill", x, y, 4, boxHeight, 2, 2)

    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(
        displayedText,
        x + self.paddingX,
        y + self.paddingY,
        wrapWidth,
        "center"
    )
    love.graphics.setColor(1, 1, 1, 1)
end

function ShoutText:drawWorld(cameraX, cameraY, viewportWidth, viewportHeight)
    if not self.unit or not self.text then
        return
    end

    local centerX = self.unit.centerX - cameraX + viewportWidth / 2
    local unitBottom = self.unit.centerY - cameraY + viewportHeight / 2 + 54
    local textWidth = math.min(self.font:getWidth(self.text), self.maximumWidth)
    local wrapWidth = math.max(1, textWidth)
    local _, wrappedLines = self.font:getWrap(self.text, wrapWidth)
    local boxWidth = wrapWidth + self.paddingX * 2
    local boxHeight = #wrappedLines * self.font:getHeight() + self.paddingY * 2
    local x = math.floor(math.max(8, math.min(
        centerX - boxWidth / 2,
        viewportWidth - boxWidth - 8
    )) + 0.5)
    local y = math.floor(math.max(8, math.min(
        unitBottom + 8,
        viewportHeight - boxHeight - 8
    )) + 0.5)
    local alpha = math.min(1, self.timeRemaining / self.fadeDuration)
        * math.min(1, self.elapsed / self.appearDuration)
    local revealedCharacters = math.min(
        self.characterCount,
        math.floor(self.elapsed * self.charactersPerSecond)
    )
    local displayedText = visibleText(self.text, revealedCharacters)

    love.graphics.setShader()
    love.graphics.setColor(0.015, 0.02, 0.035, 0.88 * alpha)
    love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 5, 5)
    love.graphics.setColor(0.62, 0.78, 0.94, 0.9 * alpha)
    love.graphics.rectangle("fill", x, y, 4, boxHeight, 2, 2)
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(
        displayedText,
        x + self.paddingX,
        y + self.paddingY,
        wrapWidth,
        "center"
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return ShoutText
