local dequeue = require('dequeue')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes'

function C:init(rallyManager)
  self.rallyManager = rallyManager

  self:resetAudioQueue()
  self.damageAudioPlayedAt = nil
end

function C:resetAudioQueue()
  self.queue = dequeue.new()

  if self.currAudioObj and self.currAudioObj.sourceId then
    self:stopSfxSource(self.currAudioObj.sourceId)
  end

  self.currAudioObj = nil
  self.damageTimeoutSecs = 3
end

function C:stopSfxSource(sourceId)
  local sfxSource = scenetree.findObjectById(sourceId)
  if sfxSource then
    sfxSource:stop(-1)
  end
end

function C:enqueueDamageSfx()
  local now = re_util.getTime()
  if not self.damageAudioPlayedAt or now - self.damageAudioPlayedAt > self.damageTimeoutSecs then
    self.damageAudioPlayedAt = now
    local goNote = self.rallyManager.notebook:getStaticPacenoteByName('damage_1')
    local fgNote = goNote:asFlowgraphData(self.rallyManager.missionSettings, self.rallyManager.codriver)
    self:enqueuePauseSecs(0.5)
    self:enqueuePacenote(fgNote)
  end
end

function C:enqueuePauseSecs(secs)
  log('I', logTag, 'pause='..secs..'s')
  local audioObj = re_util.buildAudioObjPause(secs)
  self.queue:push_right(audioObj)
end

function C:enqueuePacenote(pacenoteFgData)
  log('I', logTag, "pacenote='" .. pacenoteFgData.note_text .. "', filename=" .. pacenoteFgData.audioFname)
  self:enqueueFile(pacenoteFgData.audioFname)
end

function C:enqueueStaticPacenoteByName(pacenote_name)
  local pacenote = self.rallyManager.notebook:getStaticPacenoteByName(pacenote_name)
  if pacenote then
    local fgNote = pacenote:asFlowgraphData(self.rallyManager.missionSettings, self.rallyManager.codriver)
    self:enqueuePacenote(fgNote)
  end
end

function C:enqueueFile(fname)
  local audioObj = re_util.buildAudioObjPacenote(fname)
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

function C:doPause(audioObj)
  audioObj.audioLen = audioObj.pauseTime
  audioObj.timeout = audioObj.time + audioObj.audioLen
end

function C:playNextInQueue()
  if self:previousAudioIsDone() then
    self.currAudioObj = self.queue:pop_left()
    if self.currAudioObj.audioType == 'pacenote' then
      re_util.playPacenote(self.currAudioObj)
    elseif self.currAudioObj.audioType == 'pause' then
      self:doPause(self.currAudioObj)
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
