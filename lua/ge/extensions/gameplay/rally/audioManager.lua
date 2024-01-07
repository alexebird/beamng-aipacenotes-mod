local dequeue = require('dequeue')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes'

function C:init()
  self:resetAudioQueue()
end

function C:resetAudioQueue()
  self.queue = dequeue.new()

  if self.currAudioObj then
    self:stopSfxSource(self.currAudioObj.sourceId)
  end

  self.currAudioObj = nil
  self.damageAudioPlayedAt = nil
  self.damageTimeoutSecs = 3
end

function C:stopSfxSource(sourceId)
  local sfxSource = scenetree.findObjectById(sourceId)
  if sfxSource then
    sfxSource:stop(-1)
  end
end

function C:playDamageSfx()
  local now = re_util.getTime()
  if not self.damageAudioPlayedAt or now - self.damageAudioPlayedAt > self.damageTimeoutSecs then
    self.damageAudioPlayedAt = re_util.getTime()
    local fname = '/art/aipacenotes/sound/pacenote_damage.ogg'
    self:enqueueFile(fname)
  end
end

function C:enqueuePacenote(pacenoteFgData)
  log('I', logTag, "pacenote='" .. pacenoteFgData.note_text .. "', filename=" .. pacenoteFgData.audioFname)
  self:enqueueFile(pacenoteFgData.audioFname)
end

function C:enqueueFile(fname)
  local audioObj = re_util.buildAudioObj(fname)
  if re_util.fileExists(fname) then
    self.queue:push_right(audioObj)
  else
    log('E', logTag, "audio file does not exist: " .. fname)
  end
end

function C:previousAudioIsDone()
  -- is there a next audio?
  local queueHasAudio = not self.queue:is_empty()

  -- has the current audio reached its timeout?
  if self.currAudioObj then
    local isPastExpireTime = re_util.getTime() > self.currAudioObj.timeout
    if isPastExpireTime then
      self.currAudioObj = nil
      return queueHasAudio
    else
      return false
    end
    return queueHasAudio and isPastExpireTime
  else
    return queueHasAudio
  end
end

function C:playNextInQueue()
  if self:previousAudioIsDone() then
    self.currAudioObj = self.queue:pop_left()
    if self.currAudioObj.audioType == 'pacenote' then
      re_util.playPacenote(self.currAudioObj)
    -- elseif self.currAudioObj.audioType == 'breath' then
      -- playBreath(self.currAudioObj)
    else
      log('E', logTag, 'unknown audioType: '..self.currAudioObj.audioType)
    end
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
