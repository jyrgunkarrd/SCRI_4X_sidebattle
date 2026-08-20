local SFX = {}
SFX.__index = SFX

local UNIT_VOICE_DIRECTORY = "assets/audio/sfx/voices/units"
local ATTACK_DIRECTORY = "assets/audio/sfx/atk"
local DEFEAT_DIRECTORY = "assets/audio/sfx/def"
local UNIT_HOVER_PATH = "assets/audio/sfx/unit_hover.wav"
local CLICK_PATH = "assets/audio/sfx/click.wav"
local SHUTTER_PATH = "assets/audio/sfx/shutter.wav"
local PLAYER_PHASE_PATHS = {
    "assets/audio/sfx/play_phase.wav",
    "assets/audio/sfx/play_turn.wav",
}
local ENEMY_PHASE_PATHS = {
    "assets/audio/sfx/en_phase.wav",
    "assets/audio/sfx/end_turn.wav",
}
local MOVEMENT_ORDER_PATHS = {
    default = "assets/audio/sfx/move.wav",
    veh = "assets/audio/sfx/move_veh.wav",
}

function SFX.new()
    local self = setmetatable({}, SFX)
    self.sources = {}
    self.currentVoice = nil
    return self
end

function SFX:_getSource(path)
    if not self.sources[path] then
        assert(love.filesystem.getInfo(path, "file"),
            ("Sound effect does not exist: %s"):format(path))
        self.sources[path] = love.audio.newSource(path, "static")
    end
    return self.sources[path]
end

function SFX:_playFirstAvailable(paths)
    for _, path in ipairs(paths) do
        if love.filesystem.getInfo(path, "file") then
            local source = self:_getSource(path)
            source:stop()
            source:play()
            return true
        end
    end
    return false
end

function SFX:playUnitSelect(unitId)
    assert(type(unitId) == "string" and unitId ~= "",
        "A unit id is required to play its selection voice")

    if self.currentVoice then
        self.currentVoice:stop()
    end

    local path = ("%s/%s.wav"):format(UNIT_VOICE_DIRECTORY, unitId)
    if not love.filesystem.getInfo(path, "file") then
        return false
    end
    self.currentVoice = self:_getSource(path)
    self.currentVoice:stop()
    self.currentVoice:play()
    return true
end

function SFX:playUnitHover()
    local source = self:_getSource(UNIT_HOVER_PATH)
    source:stop()
    source:play()
end

function SFX:playClick()
    local source = self:_getSource(CLICK_PATH)
    source:stop()
    source:play()
end

function SFX:playShutter()
    local source = self:_getSource(SHUTTER_PATH)
    source:stop()
    source:play()
end

function SFX:playPlayerPhase()
    return self:_playFirstAvailable(PLAYER_PHASE_PATHS)
end

function SFX:playEnemyTurn()
    return self:_playFirstAvailable(ENEMY_PHASE_PATHS)
end

function SFX:playMovementOrder(movementType)
    local path = MOVEMENT_ORDER_PATHS[movementType]
        or MOVEMENT_ORDER_PATHS.default
    local source = self:_getSource(path)
    source:stop()
    source:play()
end

function SFX:playAttackImpact(attackImageId)
    if type(attackImageId) ~= "string" or attackImageId == "" then
        return false
    end

    local path = ("%s/%s.wav"):format(ATTACK_DIRECTORY, attackImageId)
    if not love.filesystem.getInfo(path, "file") then
        return false
    end

    local source = self:_getSource(path)
    source:stop()
    source:play()
    return true
end

function SFX:playDefeat(defeatSoundId)
    if type(defeatSoundId) ~= "string" or defeatSoundId == "" then
        return false
    end

    local path = ("%s/%s.wav"):format(DEFEAT_DIRECTORY, defeatSoundId)
    if not love.filesystem.getInfo(path, "file") then
        return false
    end

    local source = self:_getSource(path)
    source:stop()
    source:play()
    return true
end

return SFX
