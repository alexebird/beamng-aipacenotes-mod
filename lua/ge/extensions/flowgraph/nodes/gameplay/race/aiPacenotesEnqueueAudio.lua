-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local dequeue = require('dequeue')
local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenote Enqueue Audio'
C.description = 'Adds an audio object to the play queue based on the audios unhashed text.'
-- C.category = 'aipacenotes'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'flow', name = 'enqueue', description = 'Inflow for when audio is enqueued.'},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Inflow for resetting audio queue.'},
  {dir = 'in', type = 'flow', name = 'damage', description = 'Inflow for damage audio .'},
  {dir = 'in', type = 'string', name = 'note', description = 'The pacenote.'},
  {dir = 'in', type = 'table', tableType = 'aipSettings', name = 'aipSettings', description = 'The settings object.'},
}

C.tags = {'scenario', 'aipacenotes'}

local logTag = 'aipacenotes'

function C:init(mgr, ...)
  self:resetAudioQueue()
end

function C:resetAudioQueue()
  self.queue = dequeue.new()

  if self.currAudioObj then
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

function C:playDamageSfx()
  local fn = '/tmp/pacenote_damage.ogg'
  local res = Engine.Audio.playOnce('AudioGui', fn)
end

function C:enqueueFromPinIns()
  local pacenote = self.pinIn.note.value
  local missionDir = self.pinIn.aipSettings.value.missionDir
  local notebookName = re_util.normalize_name(self.pinIn.aipSettings.value.notebookName)
  local codriverName = self.pinIn.aipSettings.value.notebook.codriver
  local codriverLang = self.pinIn.aipSettings.value.language
  local codriverVoice = self.pinIn.aipSettings.value.voice
  local codriverStr = re_util.normalize_name(codriverName..'_'..codriverLang..'_'..codriverVoice)
  local pacenoteHash = re_util.pacenote_hash(pacenote)

  local pacenoteFname = missionDir ..'/'.. re_util.notebooksPath .. 'generated_pacenotes/' .. notebookName .. '/' .. codriverStr .. '/pacenote_' .. pacenoteHash .. '.ogg'
  log('I', logTag, "pacenote='" .. pacenote .. "', filename=" .. pacenoteFname)

  local audioObj = re_util.buildAudioObj(pacenoteFname)
  -- local audioObj = {
  --   audioType = 'pacenote',
  --   pacenoteFname = pacenoteFname,
  --   volume = 2,
  --   time = re_util.getTime(),
  --   audioLen = nil,
  --   timeout = nil,
  --   sourceId = nil,
  --   breathSuffixTime = 0.15, -- add time to represent the co-driver taking a breath after reading a pacenote.
  -- }

  if re_util.fileExists(pacenoteFname) then
    self.queue:push_right(audioObj)
  else
    log('E', logTag, "pacenote audio file does not exist: " .. pacenoteFname)
    return
  end
end

-- function C:makeBreath(breathLengthSeconds)
--   local time = getTime()
--   return {
--     audioType = 'breath',
--     time = time,
--     audioLen = breathLengthSeconds,
--     timeout = time + breathLengthSeconds,
--   }

-- end

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


-- local function playBreath(audioObj)
  -- local opts = { volume=audioObj.volume }
  -- local res = Engine.Audio.playOnce('AudioGUI', audioObj.pacenoteFname, opts)

  -- these are already set for breaths.
  -- audioObj.audioLen = res.len
  -- audioObj.timeout = audioObj.time + audioObj.audioLen

  -- log('D', 'wtf', 'audioObj audioLen='..tostring(audioObj.audioLen) .. ' timeout='..tostring(audioObj.timeout))
-- end

function C:work(args)
  if self.pinIn.reset.value then
    self:resetAudioQueue()
    return
  end

  if self.pinIn.damage.value then
    self:resetAudioQueue()
    -- self:playDamageSfx()
    return
  end

  if self.pinIn.enqueue.value then
    self:enqueueFromPinIns()
  end

  -- for x in self.queue:iter_left() do
  --   log('D', 'wtf', 'queue entry: ' .. dumps(x))
  -- end

  -- this doesnt need to be in a while loop because flow is always coming in.
  if self:previousAudioIsDone() then
    self.currAudioObj = self.queue:pop_left()
    -- log('D', 'wtf', dumps(self.currAudioObj))
    if self.currAudioObj.audioType == 'pacenote' then
      re_util.playPacenote(self.currAudioObj)
    -- elseif self.currAudioObj.audioType == 'breath' then
      -- playBreath(self.currAudioObj)
    else
      log('E', logTag, 'unknown audioType: '..self.currAudioObj.audioType)
    end
  end
end

return _flowgraph_createNode(C)
