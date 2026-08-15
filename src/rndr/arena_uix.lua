local ArenaUIX = {}
ArenaUIX.__index = ArenaUIX

local FONT_PATH = "assets/fonts/Furore.otf"

local function moveTowards(value, target, maximumDelta)
    if value < target then
        return math.min(value + maximumDelta, target)
    end
    return math.max(value - maximumDelta, target)
end

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

local function drawSizePips(unit, enemyArenaSystem, centerX, y, pipSize, gap)
    local size = enemyArenaSystem:getSize(unit)
    local isEnemy = enemyArenaSystem:isEnemy(unit)
    local occupied = isEnemy and enemyArenaSystem:isOccupied(unit)
    local filled = isEnemy
        and math.min(size, enemyArenaSystem:getEngagedSize(unit))
        or size
    local totalWidth = size * pipSize + (size - 1) * gap
    local startX = centerX - totalWidth / 2

    for index = 1, size do
        local x = math.floor(startX + (index - 1) * (pipSize + gap) + 0.5)
        local drawY = math.floor(y + 0.5)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", x, drawY, pipSize, pipSize)

        love.graphics.setColor(0.025, 0.035, 0.055, 0.95)
        love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)

        if index <= filled then
            if occupied then
                love.graphics.setColor(0.3, 0.86, 0.46, 1)
            elseif isEnemy then
                love.graphics.setColor(0.96, 0.56, 0.2, 1)
            else
                love.graphics.setColor(0.3, 0.7, 1, 1)
            end
            love.graphics.rectangle("fill", x + 2, drawY + 2, pipSize - 4, pipSize - 4)
        end
    end
end

local function drawMovementGauge(unit, movementSystem, x, y, width)
    local unitSystem = movementSystem.unitSystem
    local maximum = unitSystem:getMaximumMovementPoints(unit)
    local remaining = unitSystem:getMovementPoints(unit)
    local hoveredDestination = movementSystem.selectedUnit == unit
        and movementSystem:getHoveredDestination()
        or nil
    local previewCost = hoveredDestination
        and math.min(remaining, hoveredDestination.movementCost or 0)
        or 0
    local previewRemaining = remaining - previewCost

    love.graphics.setColor(0.78, 0.84, 0.94, 1)
    love.graphics.print(
        ("MOVEMENT  %d / %d"):format(remaining, maximum),
        x,
        y
    )

    if previewCost > 0 then
        love.graphics.setColor(1, 0.58, 0.18, 1)
        love.graphics.print(
            ("COST  %d"):format(previewCost),
            x + width - 92,
            y
        )
    end

    local gaugeY = math.floor(y + 30 + 0.5)
    local gaugeHeight = 22
    if maximum <= 0 then
        love.graphics.setColor(0.015, 0.02, 0.035, 1)
        love.graphics.rectangle("fill", x, gaugeY, width, gaugeHeight)
        return
    end

    local gap = 5
    local segmentWidth = (width - gap * (maximum - 1)) / maximum
    for index = 1, maximum do
        local segmentX = math.floor(x + (index - 1) * (segmentWidth + gap) + 0.5)
        local nextX = math.floor(x + index * segmentWidth + (index - 1) * gap + 0.5)
        local drawWidth = math.max(1, nextX - segmentX)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle(
            "fill",
            segmentX,
            gaugeY,
            drawWidth,
            gaugeHeight
        )

        if index <= previewRemaining then
            love.graphics.setColor(0.3, 0.7, 1, 1)
        elseif index <= remaining then
            love.graphics.setColor(1, 0.58, 0.18, 1)
        else
            love.graphics.setColor(0.055, 0.07, 0.1, 1)
        end
        love.graphics.rectangle(
            "fill",
            segmentX + 2,
            gaugeY + 2,
            math.max(1, drawWidth - 4),
            gaugeHeight - 4
        )
    end
end

local function drawHPGauge(unit, x, y, width)
    local maximumHP = math.max(1, tonumber(
        unit.maximumHP or unit.definition.hp
    ) or 1)
    local currentHP = math.max(0, math.min(
        maximumHP,
        tonumber(unit.hp) or maximumHP
    ))
    local ratio = currentHP / maximumHP
    local gaugeY = math.floor(y + 30 + 0.5)
    local gaugeHeight = 22

    love.graphics.setColor(0.78, 0.84, 0.94, 1)
    love.graphics.print(
        ("HP  %d / %d"):format(currentHP, maximumHP),
        x,
        y
    )

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x, gaugeY, width, gaugeHeight)
    love.graphics.setColor(0.055, 0.07, 0.1, 1)
    love.graphics.rectangle("fill", x + 2, gaugeY + 2, width - 4, gaugeHeight - 4)

    local fillWidth = math.floor((width - 4) * ratio + 0.5)
    if fillWidth > 0 then
        love.graphics.setColor(0xd4 / 255, 0, 0, 1)
        love.graphics.rectangle(
            "fill",
            x + 2,
            gaugeY + 2,
            fillWidth,
            gaugeHeight - 4
        )
    end
end

local function attackProperty(attack, property)
    if type(attack) ~= "table" then
        return nil
    end
    if attack[property] ~= nil then
        return attack[property]
    end
    for _, entry in ipairs(attack) do
        if type(entry) == "table" and entry[property] ~= nil then
            return entry[property]
        end
    end
    return nil
end

local function attackProfiles(definition)
    local profiles = {}
    if definition.m_atk then
        profiles[#profiles + 1] = {
            label = "MELEE ATTACK",
            attack = definition.m_atk,
            ranged = false,
            color = { 1, 0.58, 0.18 },
        }
    end
    if definition.r_atk then
        profiles[#profiles + 1] = {
            label = "RANGED ATTACK",
            attack = definition.r_atk,
            ranged = true,
            color = { 1, 0x42 / 255, 0x42 / 255 },
        }
    end
    return profiles
end

local function formatProfileValue(value, fallback)
    if value == nil then
        return fallback or "--"
    end
    local number = tonumber(value)
    if number and number % 1 == 0 then
        return tostring(math.floor(number))
    end
    return tostring(value)
end

local function drawAttackProfile(profile, x, y, width, height)
    local attack = profile.attack
    local damage = attackProperty(attack, "dmg")
    local penetration = attackProperty(attack, "pen") or 0
    local attackType = string.upper(tostring(
        attackProperty(attack, "type") or "single"
    ))
    if attackType == "MULTIHIT" then
        attackType = "BURST"
    end

    love.graphics.setColor(0.025, 0.03, 0.05, 0.94)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)
    love.graphics.setColor(0.3, 0.36, 0.48, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 4, 4)

    love.graphics.setColor(profile.color[1], profile.color[2], profile.color[3], 1)
    love.graphics.rectangle("fill", x, y, 5, height, 3, 3)
    love.graphics.print(profile.label, x + 18, y + 12)

    love.graphics.setColor(0.78, 0.84, 0.94, 1)
    love.graphics.print(
        "DAMAGE  " .. formatProfileValue(damage),
        x + 18,
        y + 52
    )
    love.graphics.print(
        "PENETRATION  " .. formatProfileValue(penetration, "0"),
        x + 18,
        y + 82
    )
    love.graphics.print("TYPE  " .. attackType, x + 18, y + 112)

    if profile.ranged then
        local optimalRange = attackProperty(attack, "rng_opt")
        local maximumRange = attackProperty(attack, "rng_max")
            or attackProperty(attack, "rng")
        love.graphics.print(
            "OPTIMAL RANGE  " .. formatProfileValue(optimalRange),
            x + 18,
            y + 142
        )
        love.graphics.print(
            "MAXIMUM RANGE  " .. formatProfileValue(maximumRange),
            x + 18,
            y + 172
        )
    end
end

local function drawTagColumn(tags, x, y, width, height)
    love.graphics.setColor(0.025, 0.03, 0.05, 0.94)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)
    love.graphics.setColor(0.3, 0.36, 0.48, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle(
        "line",
        x + 0.5,
        y + 0.5,
        width - 1,
        height - 1,
        4,
        4
    )

    love.graphics.setColor(0.4, 0.78, 1, 1)
    love.graphics.rectangle("fill", x, y, 5, height, 3, 3)
    love.graphics.print("TAGS", x + 18, y + 12)

    love.graphics.setColor(0.78, 0.84, 0.94, 1)
    if type(tags) ~= "table" or #tags == 0 then
        love.graphics.print("--", x + 18, y + 52)
        return
    end

    local lineHeight = 29
    for index, tagId in ipairs(tags) do
        love.graphics.printf(
            string.upper(tostring(tagId)),
            x + 18,
            y + 52 + (index - 1) * lineHeight,
            width - 36,
            "left"
        )
    end
end

function ArenaUIX.new(options)
    options = options or {}

    local self = setmetatable({}, ArenaUIX)
    self.virtualWidth = options.virtualWidth or 1920
    self.virtualHeight = options.virtualHeight or 1080
    self.panelHeight = options.panelHeight or 240
    self.animationDuration = options.animationDuration or 0.24
    self.progress = 0
    self.targetProgress = 0
    self.selectedUnit = nil
    self.displayedUnit = nil
    self.font = love.graphics.getFont()
    self.phaseFont = love.graphics.newFont(FONT_PATH, 36)
    return self
end

function ArenaUIX:setSelectedUnit(unit)
    self.selectedUnit = unit
    self.targetProgress = unit and 1 or 0

    if unit then
        self.displayedUnit = unit
    end
end

function ArenaUIX:update(dt)
    self.progress = moveTowards(
        self.progress,
        self.targetProgress,
        dt / self.animationDuration
    )

    if self.progress == 0 and not self.selectedUnit then
        self.displayedUnit = nil
    end
end

function ArenaUIX:isOpening()
    return self.targetProgress == 1 and self.progress < 1
end

function ArenaUIX:getVisiblePanelHeight()
    return self.panelHeight * smoothstep(self.progress)
end

function ArenaUIX:getArenaHeight()
    return self.virtualHeight - self:getVisiblePanelHeight()
end

function ArenaUIX:drawTurnAnnouncement(turnSystem)
    local text, phase, alpha = turnSystem:getAnnouncement()
    if not text then
        return
    end

    local boxWidth = 520
    local boxHeight = 132
    local x = math.floor((self.virtualWidth - boxWidth) / 2 + 0.5)
    local y = math.floor((self.virtualHeight - boxHeight) / 2 + 0.5)
    local isEnemy = phase == "enemy"

    love.graphics.setShader()
    love.graphics.setColor(0.015, 0.02, 0.035, 0.92 * alpha)
    love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 6, 6)

    if isEnemy then
        love.graphics.setColor(1, 0x42 / 255, 0x42 / 255, alpha)
    else
        love.graphics.setColor(0.3, 0.7, 1, alpha)
    end
    love.graphics.rectangle("fill", x, y, 6, boxHeight, 3, 3)

    love.graphics.setFont(self.phaseFont)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(
        text,
        x + 28,
        y + 23,
        boxWidth - 56,
        "center"
    )
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 1)
end

function ArenaUIX:draw(unitDraw, enemyArenaSystem, movementSystem)
    if self.progress <= 0 then
        return
    end

    local panelY = self.virtualHeight - self:getVisiblePanelHeight()
    local width = self.virtualWidth
    local height = self.panelHeight

    love.graphics.setShader()
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.055, 0.065, 0.095, 1)
    love.graphics.rectangle("fill", 0, panelY, width, height)

    love.graphics.setColor(0.32, 0.38, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, panelY, width, panelY)

    local margin = 20
    local portraitSize = math.min(height - margin * 2 - 32, 168)
    local portraitX = margin
    local portraitY = panelY + 16

    love.graphics.setColor(0.025, 0.03, 0.05, 1)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)
    love.graphics.setColor(0.3, 0.36, 0.48, 1)
    love.graphics.rectangle("line", portraitX, portraitY, portraitSize, portraitSize)

    if self.displayedUnit then
        local image = unitDraw:getPanelImage(self.displayedUnit.unitId)
        local padding = 12
        local availableSize = portraitSize - padding * 2
        local scale = math.min(
            availableSize / image:getWidth(),
            availableSize / image:getHeight()
        )
        local imageX = portraitX + portraitSize / 2
        local imageY = portraitY + (portraitSize + image:getHeight() * scale) / 2
        local scaleX = scale * unitDraw:getFacingSign(self.displayedUnit)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            image,
            imageX,
            imageY,
            0,
            scaleX,
            scale,
            image:getWidth() / 2,
            image:getHeight()
        )

        drawSizePips(
            self.displayedUnit,
            enemyArenaSystem,
            portraitX + portraitSize / 2,
            portraitY + portraitSize + 14,
            16,
            5
        )

        drawMovementGauge(
            self.displayedUnit,
            movementSystem,
            portraitX + portraitSize + 32,
            panelY + 48,
            360
        )

        local statsX = portraitX + portraitSize + 32
        drawHPGauge(
            self.displayedUnit,
            statsX,
            panelY + 118,
            360
        )

        local armor = tonumber(self.displayedUnit.definition.armor)
        if armor then
            love.graphics.setColor(0.78, 0.84, 0.94, 1)
            love.graphics.print(
                ("ARMOR  %d"):format(armor),
                statsX,
                panelY + 190
            )
        end

        local profiles = attackProfiles(self.displayedUnit.definition)
        local profileX = statsX + 400
        local profileY = panelY + 18
        local profileWidth = 300
        local profileHeight = 204
        local profileGap = 18
        for index, profile in ipairs(profiles) do
            drawAttackProfile(
                profile,
                profileX + (index - 1) * (profileWidth + profileGap),
                profileY,
                profileWidth,
                profileHeight
            )
        end
        drawTagColumn(
            self.displayedUnit.definition.tags,
            profileX + #profiles * (profileWidth + profileGap),
            profileY,
            profileWidth,
            profileHeight
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaUIX
