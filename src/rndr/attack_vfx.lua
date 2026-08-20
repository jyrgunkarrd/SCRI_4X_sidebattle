local AttackVFX = {}
AttackVFX.__index = AttackVFX

local IMAGE_DIRECTORY = "assets/images/vfx"
local FONT_PATH = "assets/fonts/Furore.otf"

local function smoothstep(value)
    return value * value * (3 - 2 * value)
end

function AttackVFX.new(unitDraw, options)
    options = options or {}

    local self = setmetatable({}, AttackVFX)
    self.unitDraw = assert(unitDraw, "Unit renderer is required")
    self.approachDuration = options.approachDuration or 0.11
    self.impactDuration = options.impactDuration or 0.045
    self.recoilDuration = options.recoilDuration or 0.10
    self.hitGap = options.hitGap or 0.045
    self.approachDistance = options.approachDistance or 90
    self.recoilDistance = options.recoilDistance or 28
    self.imageScale = options.imageScale or 0.5
    self.backingPadding = options.backingPadding or 8
    self.shakeDuration = options.shakeDuration or 0.13
    self.shakeMagnitude = options.shakeMagnitude or 8
    self.flankingShakeDuration = options.flankingShakeDuration or 0.18
    self.flankingShakeMagnitude = options.flankingShakeMagnitude or 18
    self.flankingFlashDuration = options.flankingFlashDuration or 0.10
    self.defeatFlashDuration = options.defeatFlashDuration or 0.11
    self.defeatWipeDuration = options.defeatWipeDuration or 0.30
    self.defeatSlideDistance = options.defeatSlideDistance or 34
    self.damageNumberDuration = options.damageNumberDuration or 0.18
    self.damageNumberDropDuration = options.damageNumberDropDuration or 0.08
    self.damageNumberDropDistance = options.damageNumberDropDistance or 34
    self.damageFont = love.graphics.newFont(FONT_PATH, options.damageFontSize or 20)
    self.damageNumbers = {}
    self.images = {}
    self.queue = {}
    self.current = nil
    self.animationTime = 0
    return self
end

function AttackVFX:_spawnDamageNumber(target, damage)
    self.damageNumbers[#self.damageNumbers + 1] = {
        target = target,
        damage = damage,
        elapsed = 0,
    }
end

function AttackVFX:_updateDamageNumbers(dt)
    for index = #self.damageNumbers, 1, -1 do
        local number = self.damageNumbers[index]
        number.elapsed = number.elapsed + dt
        if number.elapsed >= self.damageNumberDuration then
            table.remove(self.damageNumbers, index)
        end
    end
end

function AttackVFX:_getImage(imageId)
    if not self.images[imageId] then
        local path = ("%s/%s.png"):format(IMAGE_DIRECTORY, imageId)
        assert(love.filesystem.getInfo(path, "file"),
            ("Attack VFX image does not exist: %s"):format(path))
        local image = love.graphics.newImage(path, { mipmaps = true })
        image:setFilter("linear", "linear", 8)
        image:setMipmapFilter("linear", 0)
        self.images[imageId] = image
    end
    return self.images[imageId]
end

function AttackVFX:play(result, onComplete, onImpact, onDefeat)
    local strikeCount = result and result.strikes
        and #result.strikes
        or (result and result.hits and #result.hits or 0)
    if not result or not result.vfxImage or strikeCount == 0 then
        if result and result.defeated and onDefeat then
            onDefeat(result)
        end
        if onComplete then
            onComplete(result)
        end
        return false
    end

    self.queue[#self.queue + 1] = {
        result = result,
        image = self:_getImage(result.vfxImage),
        hitCount = strikeCount,
        hitIndex = 1,
        elapsed = 0,
        impactTriggered = false,
        shakeRemaining = 0,
        activeShakeDuration = self.shakeDuration,
        flankingFlashRemaining = 0,
        isFlanking = result.ignoresArmor == true
            and result.attackType ~= "ranged",
        defeatActive = false,
        defeatElapsed = 0,
        onComplete = onComplete,
        onImpact = onImpact,
        onDefeat = onDefeat,
    }
    if not self.current then
        self.current = table.remove(self.queue, 1)
    end
    return true
end

function AttackVFX:_clearTargetOffset(animation)
    local target = animation and animation.result.target
    if target then
        target.attackVfxOffsetX = nil
        target.attackVfxOffsetY = nil
        target.attackVfxFlashAmount = nil
        target.defeatFlashAmount = nil
        target.defeatWipeAmount = nil
        target.defeatSlideX = nil
    end
end

function AttackVFX:_finishCurrent()
    local completed = self.current
    self:_clearTargetOffset(completed)
    self.current = table.remove(self.queue, 1)
    if completed and completed.onComplete then
        completed.onComplete(completed.result)
    end
end

function AttackVFX:update(dt)
    self.animationTime = self.animationTime + dt
    self:_updateDamageNumbers(dt)
    local animation = self.current
    if not animation then
        return
    end

    if animation.defeatActive then
        animation.defeatElapsed = animation.defeatElapsed + dt
        local target = animation.result.target
        if animation.defeatElapsed < self.defeatFlashDuration then
            local progress = animation.defeatElapsed / self.defeatFlashDuration
            target.defeatFlashAmount = math.sin(progress * math.pi)
            target.defeatWipeAmount = 0
            target.defeatSlideX = 0
        else
            local wipeElapsed = animation.defeatElapsed - self.defeatFlashDuration
            local progress = math.min(1, wipeElapsed / self.defeatWipeDuration)
            local easedProgress = smoothstep(progress)
            target.defeatFlashAmount = 0
            target.defeatWipeAmount = easedProgress
            target.defeatSlideX = -self.unitDraw:getFacingSign(target)
                * self.defeatSlideDistance * easedProgress
            if progress >= 1 then
                self:_finishCurrent()
            end
        end
        return
    end

    animation.elapsed = animation.elapsed + dt
    if not animation.impactTriggered
        and animation.elapsed >= self.approachDuration then
        animation.impactTriggered = true
        local strike = animation.result.strikes
            and animation.result.strikes[animation.hitIndex]
        local damage = strike
            and strike.hit
            and strike.damage
            or (not animation.result.strikes
                and animation.result.hits[animation.hitIndex])
        if damage and damage > 0 then
            animation.activeShakeDuration = animation.isFlanking
                and self.flankingShakeDuration
                or self.shakeDuration
            animation.shakeRemaining = animation.activeShakeDuration
            if animation.isFlanking then
                animation.flankingFlashRemaining = self.flankingFlashDuration
            end
            self:_spawnDamageNumber(animation.result.target, damage)
            if animation.onImpact then
                animation.onImpact(animation.result, animation.hitIndex)
            end
        end
    end

    local target = animation.result.target
    if animation.shakeRemaining > 0 and target then
        animation.shakeRemaining = math.max(0, animation.shakeRemaining - dt)
        local strength = animation.shakeRemaining
            / animation.activeShakeDuration
        local magnitude = animation.isFlanking
            and self.flankingShakeMagnitude
            or self.shakeMagnitude
        local verticalMultiplier = animation.isFlanking and 0.75 or 0.45
        local horizontalFrequency = animation.isFlanking and 154 or 96
        local verticalFrequency = animation.isFlanking and 181 or 113
        target.attackVfxOffsetX = math.sin(
            self.animationTime * horizontalFrequency
        ) * magnitude * strength
        target.attackVfxOffsetY = math.cos(
            self.animationTime * verticalFrequency
        ) * magnitude * verticalMultiplier * strength
    elseif target then
        target.attackVfxOffsetX = nil
        target.attackVfxOffsetY = nil
    end

    if animation.flankingFlashRemaining > 0 and target then
        animation.flankingFlashRemaining = math.max(
            0,
            animation.flankingFlashRemaining - dt
        )
        target.attackVfxFlashAmount = animation.flankingFlashRemaining
            / self.flankingFlashDuration
    elseif target then
        target.attackVfxFlashAmount = nil
    end

    local strikeDuration = self.approachDuration
        + self.impactDuration
        + self.recoilDuration
        + self.hitGap
    if animation.elapsed >= strikeDuration then
        animation.hitIndex = animation.hitIndex + 1
        if animation.hitIndex > animation.hitCount then
            if animation.result.defeated then
                animation.defeatActive = true
                animation.defeatElapsed = 0
                self:_clearTargetOffset(animation)
                if animation.onDefeat then
                    animation.onDefeat(animation.result)
                end
                return
            end
            self:_finishCurrent()
            return
        end
        animation.elapsed = animation.elapsed - strikeDuration
        animation.impactTriggered = false
        animation.shakeRemaining = 0
        animation.flankingFlashRemaining = 0
    end
end

function AttackVFX:drawDamageNumbers(camera)
    love.graphics.setShader()
    love.graphics.setFont(self.damageFont)

    for _, number in ipairs(self.damageNumbers) do
        local left, top, right = self.unitDraw:getUnitBounds(number.target)
        local centerX, screenTop = camera:worldToScreen((left + right) / 2, top)
        local dropProgress = smoothstep(math.min(
            1,
            number.elapsed / self.damageNumberDropDuration
        ))
        local finalY = screenTop - 24
        local centerY = finalY
            - self.damageNumberDropDistance * (1 - dropProgress)
        local fadeDuration = 0.045
        local fadeStart = self.damageNumberDuration - fadeDuration
        local alpha = number.elapsed > fadeStart
            and math.max(0, 1 - (number.elapsed - fadeStart) / fadeDuration)
            or 1
        local text = tostring(number.damage)
        local paddingX = 10
        local paddingY = 5
        local width = self.damageFont:getWidth(text) + paddingX * 2
        local height = self.damageFont:getHeight() + paddingY * 2
        local x = math.floor(centerX - width / 2 + 0.5)
        local y = math.floor(centerY - height / 2 + 0.5)

        love.graphics.setColor(0, 0, 0, 0.92 * alpha)
        love.graphics.rectangle("fill", x, y, width, height)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(
            text,
            x,
            y + paddingY,
            width,
            "center"
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function AttackVFX:isActive()
    return self.current ~= nil or #self.queue > 0
end

function AttackVFX:draw()
    local animation = self.current
    if not animation then
        return
    end
    if animation.defeatActive then
        return
    end

    local result = animation.result
    local attacker = result.attacker
    local target = result.target
    local targetImage, targetX, targetY, targetScale = self.unitDraw:getUnitVisualAt(
        target,
        target.targW,
        target.targH
    )
    local centerY = targetY - targetImage:getHeight() * targetScale / 2
    local facingSign = self.unitDraw:getFacingSign(attacker)
    local impactX = targetX
    local startX = impactX - facingSign * self.approachDistance
    local recoilX = impactX - facingSign * self.recoilDistance
    local elapsed = animation.elapsed
    local x
    local alpha = 1

    if elapsed < self.approachDuration then
        local progress = smoothstep(elapsed / self.approachDuration)
        x = startX + (impactX - startX) * progress
    elseif elapsed < self.approachDuration + self.impactDuration then
        x = impactX
    elseif elapsed < self.approachDuration
        + self.impactDuration + self.recoilDuration then
        local recoilElapsed = elapsed
            - self.approachDuration
            - self.impactDuration
        local progress = smoothstep(recoilElapsed / self.recoilDuration)
        x = impactX + (recoilX - impactX) * progress
        alpha = 1 - progress * 0.65
    else
        return
    end

    love.graphics.setShader()
    local backingSize = math.max(
        animation.image:getWidth(),
        animation.image:getHeight()
    ) * self.imageScale + self.backingPadding * 2
    love.graphics.setColor(0, 0, 0, 0.9 * alpha)
    love.graphics.rectangle(
        "fill",
        x - backingSize / 2,
        centerY - backingSize / 2,
        backingSize,
        backingSize
    )
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        animation.image,
        x,
        centerY,
        0,
        self.imageScale * facingSign,
        self.imageScale,
        animation.image:getWidth() / 2,
        animation.image:getHeight() / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return AttackVFX
