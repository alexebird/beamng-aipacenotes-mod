local dequeue = require('dequeue')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aip-audioManager'

function C:init(rallyManager)
  self.rallyManager = rallyManager
  self.pacenote_metadata = nil

  self.backend = 'gui'
  -- self.backend = 'lua'

  self:resetAudioQueue()
  -- self.damageAudioPlayedAt = nil
  -- self.damageTimeoutSecs = 1.5
end

function C:loadPacenoteMetadata()
  local missionDir = self.rallyManager.missionDir
  if not missionDir then return end

  local notebook = self.rallyManager.notebook
  local codriver = self.rallyManager.codriver
  local pacenotesDir = re_util.buildPacenotesDir(missionDir, notebook, codriver)

  local metadataFname = pacenotesDir..'/'..re_util.pacenotesMetadataBasename

  local json = jsonReadFile(metadataFname)
  if not json then
    log('W', logTag, 'couldnt find metadata file: '..metadataFname)
  end
  self.pacenote_metadata = json
  -- print(dumps(json))
end

function C:resetAudioQueue()
  log('D', logTag, "resetAudioQueue")
  self.queue = dequeue.new()

  if self.currAudioObj then
    -- self:stopSfxSource(self.currAudioObj.sourceId)
    self:_stopAudio()
    -- guihooks.trigger('aiPacenotes.codriverApp.stopAudio')
  end

  self.currAudioObj = nil
  self:loadPacenoteMetadata()
end

-- function C:stopSfxSource(sourceId)
--   local sfxSource = scenetree.findObjectById(sourceId)
--   if sfxSource then
--     sfxSource:stop(-1)
--   end
-- end

function C:_stopAudio()
  guihooks.trigger('aiPacenotes.codriverApp.stopAudio')
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
        self:_stopAudio()
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
  local pacenoteFgData = pacenote:asFlowgraphData(self.rallyManager.codriver)
  if pacenoteFgData then
    log('D', logTag, "enqueuePacenote: name='"..pacenote.name.."' note='"..pacenoteFgData.note_text.."'")

    return self:_enqueueFile(pacenote, pacenoteFgData, pacenoteFgData.audioFname, addToFront)
  else
    log('E', logTag, "enqueuePacenote: note is missing FGdata")
    return nil
  end
end

function C:enqueueStaticPacenoteByName(pacenote_name, addToFront)
  local pacenote = self.rallyManager.notebook:getStaticPacenoteByName(pacenote_name)
  if pacenote then
    -- log('D', logTag, "enqueueStaticPacenoteByName: adding '"..pacenote_name.."'")
    return self:enqueuePacenote(pacenote, addToFront)
  else
    log('E', logTag, "enqueueStaticPacenoteByName: couldnt find static pacenote with name '"..pacenote_name.."'")
    return nil
  end
end

function C:_enqueueFile(pacenote, fgData, fname, addToFront)
  addToFront = addToFront or false
  local audioObj = re_util.buildAudioObjPacenote(fname)
  audioObj.note_name = pacenote.name

  local _, basename, _ = path.split(fname)
  local metadataVal = self.pacenote_metadata[basename]
  if not metadataVal then
    log('E', logTag, "_enqueueFile: cant find metadata entry for basename=" .. basename)
    guihooks.message("Cant find audio file for pacenote '".. fgData.note_text .."'. Run RaceLink to generate audio files.", 5)
    return nil
  end
  audioObj.audioLen = tonumber(metadataVal.audioLen)

  if re_util.fileExists(fname) then
    -- log('D', logTag, "_enqueueFile: exists=yes front="..tostring(addToFront) .." fname=" .. fname)
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
  -- log('D', logTag, 'doPause: '..dumps(audioObj))
end

-- function C:previousAudioIsDone()
--   -- is there a next audio?
--   local queueHasAudio = not self.queue:is_empty()
--
--   -- has the current audio reached its timeout?
--   if self.currAudioObj then
--     local isPastExpireTime = re_util.getTime() > self.currAudioObj.timeout
--     if isPastExpireTime then
--       self.currAudioObj = nil
--       return queueHasAudio
--     else
--       return false
--     end
--     return queueHasAudio and isPastExpireTime
--   else
--     return queueHasAudio
--   end
-- end
--
-- function C:playNextInQueue1()
--   -- log('D', logTag, 'AudioManager.playNextInQueue len='..self.queue:length())
--   if self:previousAudioIsDone() then
--     self.currAudioObj = self.queue:pop_left()
--     if self.currAudioObj.audioType == 'pacenote' then
--       re_util.playPacenote(self.currAudioObj)
--     elseif self.currAudioObj.audioType == 'pause' then
--       self:doPause(self.currAudioObj)
--     else
--       log('E', logTag, 'unknown audioType: '..self.currAudioObj.audioType)
--     end
--   end
-- end

function C:isPlaying()
  if self.currAudioObj then
    return re_util.getTime() < self.currAudioObj.timeout
  else
    return false
  end
end

function C:getQueueInfo()
  return {
    queueSize = self.queue:length(),
    paused = not self:isPlaying(),
  }
end

function C:playNextInQueue()
  if not self:isPlaying() then
    self.currAudioObj = self.queue:pop_left()
    if self.currAudioObj then
      if self.currAudioObj.audioType == 'pacenote' then
        if self.backend == 'gui' then
          re_util.playPacenoteGui(self.currAudioObj)
        else
          re_util.playPacenote(self.currAudioObj)
        end
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
