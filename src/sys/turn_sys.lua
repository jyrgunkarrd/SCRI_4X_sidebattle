local TurnSystem = {}
TurnSystem.__index = TurnSystem

TurnSystem.PHASE_START = "start"
TurnSystem.PHASE_PLAYER = "player"
TurnSystem.PHASE_ENEMY = "enemy"
TurnSystem.PHASE_END = "end"

function TurnSystem.new(unitSystem, options)
    options = options or {}

    local self = setmetatable({}, TurnSystem)
    self.unitSystem = assert(unitSystem, "Unit system is required")
    self.startDuration = options.startDuration or 0.6
    self.endDuration = options.endDuration or 0.6
    self.announcementDuration = options.announcementDuration or 1.2
    self.announcementFadeDuration = options.announcementFadeDuration or 0.15
    self.turnCount = 0
    self.phase = nil
    self.phaseElapsed = 0
    self.announcementText = nil
    self.announcementPhase = nil
    self.announcementElapsed = 0
    self.announcementTimeRemaining = 0
    self:_enterPhase(TurnSystem.PHASE_START)
    return self
end

function TurnSystem:_setAnnouncement(text, phase)
    self.announcementText = text
    self.announcementPhase = phase
    self.announcementElapsed = 0
    self.announcementTimeRemaining = self.announcementDuration
end

function TurnSystem:_clearAnnouncement()
    self.announcementText = nil
    self.announcementPhase = nil
    self.announcementElapsed = 0
    self.announcementTimeRemaining = 0
end

function TurnSystem:_enterPhase(phase)
    self.phase = phase
    self.phaseElapsed = 0
    self:_clearAnnouncement()

    if phase == TurnSystem.PHASE_START then
        self.turnCount = self.turnCount + 1
        self.unitSystem:resetAllMovementPoints()
        self.unitSystem:readyAllUnits()
        self.unitSystem:resetAllRetaliateActions()
    elseif phase == TurnSystem.PHASE_PLAYER then
        self:_setAnnouncement(
            ("TURN %d\nPLAYER TURN"):format(self.turnCount),
            phase
        )
    elseif phase == TurnSystem.PHASE_ENEMY then
        self:_setAnnouncement(
            ("TURN %d\nENEMY TURN"):format(self.turnCount),
            phase
        )
    end
end

function TurnSystem:update(dt)
    self.phaseElapsed = self.phaseElapsed + dt

    if self.announcementTimeRemaining > 0 then
        self.announcementElapsed = self.announcementElapsed + dt
        self.announcementTimeRemaining = math.max(
            0,
            self.announcementTimeRemaining - dt
        )
        if self.announcementTimeRemaining == 0 then
            self:_clearAnnouncement()
        end
    end

    if self.phase == TurnSystem.PHASE_START
        and self.phaseElapsed >= self.startDuration then
        self:_enterPhase(TurnSystem.PHASE_PLAYER)
    elseif self.phase == TurnSystem.PHASE_END
        and self.phaseElapsed >= self.endDuration then
        self:_enterPhase(TurnSystem.PHASE_START)
    end
end

function TurnSystem:advancePlayerTurn()
    if self.phase ~= TurnSystem.PHASE_PLAYER then
        return false
    end

    self:_enterPhase(TurnSystem.PHASE_ENEMY)
    return true
end

function TurnSystem:advanceEnemyTurn()
    if self.phase ~= TurnSystem.PHASE_ENEMY then
        return false
    end

    self:_enterPhase(TurnSystem.PHASE_END)
    return true
end

function TurnSystem:isPlayerTurn()
    return self.phase == TurnSystem.PHASE_PLAYER
end

function TurnSystem:isEnemyTurn()
    return self.phase == TurnSystem.PHASE_ENEMY
end

function TurnSystem:getPhase()
    return self.phase
end

function TurnSystem:getTurnCount()
    return self.turnCount
end

function TurnSystem:getAnnouncement()
    if not self.announcementText then
        return nil
    end

    local alpha = math.min(
        1,
        self.announcementElapsed / self.announcementFadeDuration,
        self.announcementTimeRemaining / self.announcementFadeDuration
    )
    return self.announcementText, self.announcementPhase, alpha
end

return TurnSystem
