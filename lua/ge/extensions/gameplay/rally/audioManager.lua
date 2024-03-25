local dequeue = require('dequeue')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aip-audioManager'

function C:init(rallyManager)
  self.rallyManager = rallyManager

  self:resetAudioQueue()
  -- self.damageAudioPlayedAt = nil
  -- self.damageTimeoutSecs = 1.5
end

function C:resetAudioQueue()
  log('D', logTag, "resetAudioQueue")
  self.queue = dequeue.new()

  if self.currAudioObj and self.currAudioObj.sourceId then
    self:stopSfxSource(self.currAudioObj.sourceId)
  end

  self.currAudioObj = nil
end

function C:stopSfxSource(sourceId)
  local sfxSource = scenetree.findObjectById(sourceId)
  if sfxSource then
    sfxSource:stop(-1)
  end
end

function C:handleDamage()
  -- if self.currAudioObj and self.currAudioObj.sourceId then
  --   self:stopSfxSource(self.currAudioObj.sourceId)
  --   self.currAudioObj = nil
  -- end

  if self.currAudioObj then
    if not self.currAudioObj.damage then
      if self.currAudioObj.sourceId then
        -- immediately stop playing and clear currAudioObj so isPlaying will return false.
        -- the note that was playing wont be played again.
        self:stopSfxSource(self.currAudioObj.sourceId)
        self.currAudioObj = nil
        self.queue = dequeue.new()
        -- self:enqueueDamage()
      end
    end
  else
    -- self:enqueueDamage()
  end
end

function C:enqueueDamage()
  local ao = self:enqueueStaticPacenoteByName('damage_1', true)
  ao.damage = true
  ao.breathSuffixTime = 1.0
  ao = self:enqueuePauseSecs(0.5, true)
  ao.damage = true
end

function C:enqueuePauseSecs(secs, addToFront)
  addToFront = addToFront or false
  log('I', logTag, 'pause='..secs..'s front='..tostring(addToFront))
  local audioObj = re_util.buildAudioObjPause(secs)
  if addToFront then
    self.queue:push_left(audioObj)
  else
    self.queue:push_right(audioObj)
  end
  return audioObj
end

function C:enqueuePacenote(pacenote, addToFront)
  local pacenoteFgData = pacenote:asFlowgraphData(self.rallyManager.missionSettings, self.rallyManager.codriver)
  if pacenoteFgData then
    log('D', logTag, "enqueuePacenote: pacenote='"..pacenoteFgData.note_text.."'")
    return self:_enqueueFile(pacenoteFgData.audioFname, addToFront)
  else
    log('E', logTag, "enqueuePacenote: note is missing FGdata")
    return nil
  end
end

function C:enqueueStaticPacenoteByName(pacenote_name, addToFront)
  local pacenote = self.rallyManager.notebook:getStaticPacenoteByName(pacenote_name)
  if pacenote then
    log('D', logTag, "enqueueStaticPacenoteByName: adding '"..pacenote_name.."'")
    return self:enqueuePacenote(pacenote, addToFront)
  else
    log('E', logTag, "enqueueStaticPacenoteByName: couldnt find static pacenote with name '"..pacenote_name.."'")
    return nil
  end
end

function C:_enqueueFile(fname, addToFront)
  addToFront = addToFront or false
  local audioObj = re_util.buildAudioObjPacenote(fname)
  if re_util.fileExists(fname) then
    log('D', logTag, "_enqueueFile: exists=yes front="..tostring(addToFront) .." fname=" .. fname)
    if addToFront then
      self.queue:push_left(audioObj)
    else
      self.queue:push_right(audioObj)
    end
    return audioObj
  else
    log('E', logTag, "_enqueueFile: exists=no fname=" .. fname)
    return nil
  end
end

function C:doPause(audioObj)
  audioObj.time = re_util.getTime()
  audioObj.audioLen = audioObj.pauseTime
  audioObj.timeout = audioObj.time + audioObj.audioLen
  log('D', logTag, 'doPause: '..dumps(audioObj))
end

function C:isPlaying()
  if self.currAudioObj then
    return re_util.getTime() < self.currAudioObj.timeout
  else
    return false
  end
end

function C:playNextInQueue()
  if not self:isPlaying() then
    self.currAudioObj = self.queue:pop_left()
    if self.currAudioObj then
      if self.currAudioObj.audioType == 'pacenote' then
        re_util.playPacenote(self.currAudioObj)
      elseif self.currAudioObj.audioType == 'pause' then
        self:doPause(self.currAudioObj)
      else
        log('E', logTag, 'unknown audioType: '..self.currAudioObj.audioType)
      end
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
