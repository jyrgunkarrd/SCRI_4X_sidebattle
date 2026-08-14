local SFX = {}
SFX.__index = SFX

local UNIT_VOICE_DIRECTORY = "assets/audio/sfx/voices/units"
local ATTACK_DIRECTORY = "assets/audio/sfx/atk"
local DEFEAT_DIRECTORY = "assets/audio/sfx/def"
local UNIT_HOVER_PATH = "assets/audio/sfx/unit_hover.wav"
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

function SFX:playUnitSelect(unitId)
    assert(type(unitId) == "string" and unitId ~= "",
        "A unit id is required to play its selection voice")

    if self.currentVoice then
        self.currentVoice:stop()
    end

    local path = ("%s/%s.wav"):format(UNIT_VOICE_DIRECTORY, unitId)
    self.currentVoice = self:_getSource(path)
    self.currentVoice:stop()
    self.currentVoice:play()
end

function SFX:playUnitHover()
    local source = self:_getSource(UNIT_HOVER_PATH)
    source:stop()
    source:play()
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
