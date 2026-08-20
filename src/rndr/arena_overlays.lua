local ArenaOverlays = {}
ArenaOverlays.__index = ArenaOverlays

local KILL_ICON_PATH = "assets/images/icons/kill.png"

local UNIT_TREATMENT_SHADER = [[
extern vec3 flashColor;
extern number flashAmount;
extern number statusBrightness;
extern number exhaustionSilhouette;
extern vec3 damageColor;
extern number damageLevel;
extern number exhaustionDesaturation;
extern number defeatFlash;
extern number defeatWipe;

vec4 effect(vec4 vertexColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates)
{
    vec4 pixel = Texel(texture, textureCoordinates) * vertexColor;
    pixel.rgb = mix(pixel.rgb, vec3(0.0), exhaustionSilhouette);

    number damageEdge = 0.006;
    number damageMask = smoothstep(
        1.0 - damageLevel - damageEdge,
        1.0 - damageLevel + damageEdge,
        textureCoordinates.y
    );
    number greyscale = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    vec3 damagedPixel = mix(vec3(greyscale), damageColor, 0.68);
    pixel.rgb = mix(pixel.rgb, damagedPixel, damageMask);
    number exhaustedGreyscale = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    pixel.rgb = mix(
        pixel.rgb,
        vec3(exhaustedGreyscale),
        exhaustionDesaturation
    );
    pixel.rgb = mix(pixel.rgb, vec3(1.0, 0.04, 0.04), defeatFlash);
    pixel.rgb = mix(pixel.rgb, flashColor, flashAmount);
    pixel.rgb *= statusBrightness;
    number wipeBoundary = 1.1 - defeatWipe * 1.2;
    number wipeVisibility = 1.0 - smoothstep(
        wipeBoundary - 0.04,
        wipeBoundary + 0.04,
        textureCoordinates.x
    );
    pixel.a *= wipeVisibility;
    return pixel;
}
]]

function ArenaOverlays.new(options)
    options = options or {}

    local self = setmetatable({}, ArenaOverlays)
    self.cellDimBrightness = options.cellDimBrightness or 0.45
    self.damageFillSpeed = options.damageFillSpeed or 0.8
    self.exhaustedBrightness = options.exhaustedBrightness or 0.62
    self.exhaustedDesaturation = options.exhaustedDesaturation or 0.62
    self.unitTreatmentShader = love.graphics.newShader(UNIT_TREATMENT_SHADER)
    self.font = love.graphics.getFont()
    self.killIcon = love.graphics.newImage(KILL_ICON_PATH, { mipmaps = true })
    self.killIcon:setFilter("linear", "linear", 8)
    self.killIcon:setMipmapFilter("linear", 0)
    self.displayedDamage = setmetatable({}, { __mode = "k" })
    self.animationTime = 0
    return self
end

local function moveTowards(value, target, maximumDelta)
    if value < target then
        return math.min(value + maximumDelta, target)
    end
    return math.max(value - maximumDelta, target)
end

function ArenaOverlays:update(dt, units)
    self.animationTime = self.animationTime + dt
    for _, unit in ipairs(units or {}) do
        local maximumHP = math.max(1, unit.maximumHP or unit.definition.hp or 1)
        local currentHP = math.max(0, math.min(maximumHP, unit.hp or maximumHP))
        local targetDamage = 1 - currentHP / maximumHP
        local displayedDamage = self.displayedDamage[unit] or 0
        self.displayedDamage[unit] = moveTowards(
            displayedDamage,
            targetDamage,
            self.damageFillSpeed * dt
        )
    end
end

function ArenaOverlays:beginUnitDim()
    self.unitTreatmentShader:send("flashColor", { 1, 1, 1 })
    self.unitTreatmentShader:send("flashAmount", 0)
    self.unitTreatmentShader:send("statusBrightness", self.cellDimBrightness)
    self.unitTreatmentShader:send("exhaustionSilhouette", 0)
    self.unitTreatmentShader:send("damageColor", { 0xd4 / 255, 0, 0 })
    self.unitTreatmentShader:send("damageLevel", 0)
    self.unitTreatmentShader:send("exhaustionDesaturation", 0)
    self.unitTreatmentShader:send("defeatFlash", 0)
    self.unitTreatmentShader:send("defeatWipe", 0)
    love.graphics.setShader(self.unitTreatmentShader)
end

function ArenaOverlays:endUnitDim()
    love.graphics.setShader()
end

function ArenaOverlays:beginUnitStatus(unit, enemyArenaSystem, dimmed, isSelected)
    local isExhausted = unit.exhausted == true
    local usesSelectedExhaustionTreatment = isExhausted and isSelected == true
    local usesExhaustionSilhouette = isExhausted and not isSelected
    local impactFlash = unit.attackVfxFlashAmount or 0
    local color = impactFlash > 0
        and { 0xff / 255, 0xd4 / 255, 0x31 / 255 }
        or (unit.occupied and { 0xfe / 255, 0, 0x6d / 255 } or nil)
    local pulse = impactFlash > 0
        and impactFlash
        or (color and (0.18 + 0.32
            * (0.5 + 0.5 * math.sin(self.animationTime * 3.5))) or 0)
    self.unitTreatmentShader:send("flashColor", color or { 1, 1, 1 })
    self.unitTreatmentShader:send("flashAmount", pulse)
    self.unitTreatmentShader:send(
        "statusBrightness",
        (dimmed and self.cellDimBrightness or 1)
            * (usesSelectedExhaustionTreatment
                and self.exhaustedBrightness or 1)
    )
    self.unitTreatmentShader:send(
        "exhaustionSilhouette",
        usesExhaustionSilhouette and 1 or 0
    )
    self.unitTreatmentShader:send("damageColor", { 0xd4 / 255, 0, 0 })
    self.unitTreatmentShader:send(
        "damageLevel",
        self.displayedDamage[unit] or 0
    )
    self.unitTreatmentShader:send(
        "exhaustionDesaturation",
        usesSelectedExhaustionTreatment and self.exhaustedDesaturation or 0
    )
    self.unitTreatmentShader:send("defeatFlash", unit.defeatFlashAmount or 0)
    self.unitTreatmentShader:send("defeatWipe", unit.defeatWipeAmount or 0)
    love.graphics.setShader(self.unitTreatmentShader)
    return true
end

function ArenaOverlays:endUnitStatus()
    love.graphics.setShader()
end

function ArenaOverlays:_cellRect(grid, destination)
    local x = grid.x + (destination.targW - 1) * grid.cellWidth
    local visualRow = grid.rows - destination.targH
    local y = grid.y + visualRow * grid.cellHeight
    return x, y, grid.cellWidth, grid.cellHeight
end

function ArenaOverlays:drawMovement(movementSystem, unitDraw)
    local selectedUnit = movementSystem.selectedUnit
    if not selectedUnit then
        return
    end

    local grid = movementSystem.grid
    local hoveredDestination = movementSystem:getHoveredDestination()

    for _, destination in ipairs(movementSystem:getDestinations()) do
        local x, y, width, height = self:_cellRect(grid, destination)
        local isHovered = destination == hoveredDestination

        love.graphics.setColor(
            destination.requiresMeleeTarget and 0.9 or (isHovered and 0.28 or 0.16),
            destination.requiresMeleeTarget and 0.42 or (isHovered and 0.72 or 0.55),
            destination.requiresMeleeTarget and 0.2 or 1,
            isHovered and 0.24 or 0.14
        )
        love.graphics.rectangle("fill", x, y, width, height)
    end

    if hoveredDestination and (hoveredDestination.movementCost or 0) > 0 then
        local selectedImage, selectedX, selectedY, selectedScale = unitDraw:getUnitVisualAt(
            selectedUnit,
            selectedUnit.targW,
            selectedUnit.targH
        )
        local ghostCellOffset = movementSystem.enemyArenaSystem:getSlotOffset(
            hoveredDestination.arenaSlot or selectedUnit.arenaSlot
        )
        local ghostImage, ghostX, ghostY, ghostScale = unitDraw:getUnitVisualAt(
            selectedUnit,
            hoveredDestination.targW,
            hoveredDestination.targH,
            nil,
            nil,
            ghostCellOffset
        )
        local selectedCenterY = selectedY
            - selectedImage:getHeight() * selectedScale / 2
        local ghostCenterY = ghostY - ghostImage:getHeight() * ghostScale / 2
        local ghostFacing = hoveredDestination.targW < selectedUnit.targW
            and "left"
            or "right"
        local ghostScaleX = ghostScale
            * unitDraw:getFacingSign(selectedUnit, ghostFacing)

        love.graphics.setColor(0.35, 0.82, 1, 0.8)
        love.graphics.setLineWidth(5)
        love.graphics.line(selectedX, selectedCenterY, ghostX, ghostCenterY)

        love.graphics.setColor(0.72, 0.9, 1, 0.42)
        love.graphics.draw(
            ghostImage,
            ghostX,
            ghostY,
            0,
            ghostScaleX,
            ghostScale,
            ghostImage:getWidth() / 2,
            ghostImage:getHeight()
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ArenaOverlays:drawRangedAttackLine(attacker, target, unitDraw)
    if not attacker or not target then
        return
    end

    local attackerLeft, attackerTop, attackerRight, attackerBottom
        = unitDraw:getUnitBounds(attacker)
    local targetLeft, targetTop, targetRight, targetBottom
        = unitDraw:getUnitBounds(target)
    local startX = (attackerLeft + attackerRight) / 2
    local startY = (attackerTop + attackerBottom) / 2
    local endX = (targetLeft + targetRight) / 2
    local endY = (targetTop + targetBottom) / 2
    local deltaX = endX - startX
    local deltaY = endY - startY
    local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if length <= 0 then
        return
    end

    local spacing = 22
    local dotRadius = 4
    love.graphics.setShader()
    love.graphics.setColor(1, 0x42 / 255, 0x42 / 255, 0.92)
    for distance = 0, length, spacing do
        local progress = distance / length
        love.graphics.circle(
            "fill",
            startX + deltaX * progress,
            startY + deltaY * progress,
            dotRadius
        )
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPanelBacking(x, y, width, height)
    love.graphics.setColor(0.012, 0.018, 0.03, 0.94)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)
    love.graphics.setColor(0.34, 0.4, 0.52, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 4, 4)
end

local function drawHitPips(centerX, y, count)
    local pipSize = 8
    local gap = 4
    local totalWidth = count * pipSize + math.max(0, count - 1) * gap
    local startX = math.floor(centerX - totalWidth / 2 + 0.5)

    for index = 1, count do
        local x = startX + (index - 1) * (pipSize + gap)
        love.graphics.setColor(1, 0.58, 0.18, 1)
        love.graphics.rectangle("fill", x, y, pipSize, pipSize)
    end
end

local function hitPipsWidth(count)
    local pipSize = 8
    local gap = 4
    return count * pipSize + math.max(0, count - 1) * gap
end

local function drawCenteredText(font, text, x, y, width)
    love.graphics.print(
        text,
        math.floor(x + (width - font:getWidth(text)) / 2 + 0.5),
        y
    )
end

local function drawPreviewHPGauge(preview, x, y, width, height)
    local innerX = x + 2
    local innerY = y + 2
    local innerWidth = width - 4
    local innerHeight = height - 4
    local currentRatio = math.min(1, preview.currentHP / preview.maximumHP)
    local remainingHP = math.max(0, preview.currentHP - preview.totalDamage)
    local remainingRatio = math.min(1, remainingHP / preview.maximumHP)
    local remainingWidth = math.floor(innerWidth * remainingRatio + 0.5)
    local currentWidth = math.floor(innerWidth * currentRatio + 0.5)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.055, 0.07, 0.1, 1)
    love.graphics.rectangle("fill", innerX, innerY, innerWidth, innerHeight)

    if remainingWidth > 0 then
        love.graphics.setColor(0xd4 / 255, 0, 0, 1)
        love.graphics.rectangle(
            "fill",
            innerX,
            innerY,
            remainingWidth,
            innerHeight
        )
    end
    if currentWidth > remainingWidth then
        love.graphics.setColor(1, 0.58, 0.18, 0.95)
        love.graphics.rectangle(
            "fill",
            innerX + remainingWidth,
            innerY,
            currentWidth - remainingWidth,
            innerHeight
        )
    end
end

function ArenaOverlays:drawAttackPreview(
    movementSystem,
    unitDraw,
    camera,
    combatSystem,
    rangedTarget,
    rangedPreview
)
    local enemy = rangedTarget or movementSystem:getHoveredMeleeTarget()
    local selectedUnit = movementSystem.selectedUnit
    if not enemy or not selectedUnit then
        return
    end

    local preview = rangedPreview
    if not preview then
        local destination = movementSystem:getHoveredDestination()
        if not destination then
            return
        end
        preview = combatSystem:getMeleeAttackPreview(
            selectedUnit,
            enemy,
            destination.movementCost
        )
    end
    if not preview then
        return
    end

    local damageText
    if preview.armor > 0 then
        damageText = ("DMG  %d  >  %d"):format(
            preview.rawDamage,
            preview.damagePerHit
        )
    else
        damageText = ("DMG  %d"):format(preview.rawDamage)
    end
    local chanceText = preview.hitChance
        and ("HIT %d%%"):format(preview.hitChance)
        or nil
    local hpText = ("HP  %d / %d"):format(
        preview.currentHP,
        preview.maximumHP
    )
    local pipWidth = preview.isMultihit
        and hitPipsWidth(preview.hitCount)
        or 0
    local detailWidth = chanceText and preview.isMultihit
        and self.font:getWidth(chanceText) + pipWidth + 40
        or (chanceText and self.font:getWidth(chanceText) + 24
            or (preview.isMultihit and pipWidth + 24 or 0))

    local left, top, right = unitDraw:getUnitBounds(enemy)
    local centerX, screenTop = camera:worldToScreen((left + right) / 2, top)
    local panelWidth = math.max(
        190,
        self.font:getWidth(damageText) + 24,
        self.font:getWidth(hpText) + 24,
        detailWidth
    )
    local panelHeight = 84
    local panelGap = 10
    local rowWidth = panelWidth * 2 + panelGap
    local panelX = math.max(
        8,
        math.min(camera.viewportWidth - rowWidth - 8, centerX - rowWidth / 2)
    )
    panelX = math.floor(panelX + 0.5)
    local panelY = math.max(8, screenTop - panelHeight - 40)
    panelY = math.floor(panelY + 0.5)
    local healthX = panelX + panelWidth + panelGap

    love.graphics.setShader()
    love.graphics.setFont(self.font)
    drawPanelBacking(panelX, panelY, panelWidth, panelHeight)
    drawPanelBacking(healthX, panelY, panelWidth, panelHeight)

    local topRowY = panelY + 12
    local detailCenterY = panelY + 57
    local detailTextY = math.floor(
        detailCenterY - self.font:getHeight() / 2 + 0.5
    )
    love.graphics.setColor(0.9, 0.94, 1, 1)
    drawCenteredText(
        self.font,
        damageText,
        panelX,
        (preview.isMultihit or preview.hitChance)
            and topRowY
            or math.floor(panelY + (panelHeight - self.font:getHeight()) / 2),
        panelWidth
    )
    if preview.hitChance then
        if preview.isMultihit then
            love.graphics.setColor(1, 0x42 / 255, 0x42 / 255, 1)
            love.graphics.print(
                chanceText,
                panelX + 12,
                detailTextY
            )
            drawHitPips(
                panelX + panelWidth - 12 - pipWidth / 2,
                math.floor(detailCenterY - 4 + 0.5),
                preview.hitCount
            )
        else
            love.graphics.setColor(1, 0x42 / 255, 0x42 / 255, 1)
            drawCenteredText(
                self.font,
                chanceText,
                panelX,
                detailTextY,
                panelWidth
            )
        end
    elseif preview.isMultihit then
        drawHitPips(
            panelX + panelWidth / 2,
            math.floor(detailCenterY - 4 + 0.5),
            preview.hitCount
        )
    end

    love.graphics.setColor(0.9, 0.94, 1, 1)
    drawCenteredText(
        self.font,
        hpText,
        healthX,
        topRowY,
        panelWidth
    )
    if preview.willDefeat then
        local iconSize = 27
        local iconScale = math.min(
            iconSize / self.killIcon:getWidth(),
            iconSize / self.killIcon:getHeight()
        )
        love.graphics.setColor(1, 0.26, 0.26, 1)
        love.graphics.draw(
            self.killIcon,
            healthX + panelWidth / 2,
            detailCenterY,
            0,
            iconScale,
            iconScale,
            self.killIcon:getWidth() / 2,
            self.killIcon:getHeight() / 2
        )
    else
        drawPreviewHPGauge(
            preview,
            healthX + 14,
            math.floor(detailCenterY - 8 + 0.5),
            panelWidth - 28,
            16
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ArenaOverlays
