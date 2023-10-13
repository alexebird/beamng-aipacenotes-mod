-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local dequeue = require('dequeue')

local im  = ui_imgui


local C = {}

C.name = 'AI Pacenote Enqueue Audio'
C.description = 'Adds an audio object to the play queue based on the audios unhashed text.'
-- C.category = 'aipacenotes'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'flow', name = 'enqueue', description = 'Inflow for when audio is enqueued.'},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Inflow for resetting audio queue.'},
  {dir = 'in', type = 'string', name = 'note', description = 'The pacenote.'},
  {dir = 'in', type = 'string', name = 'notebookName', description = 'The notebook name.'},
  {dir = 'in', type = 'string', name = 'missionDir', description = 'Root path of the mission.'},
  -- {dir = 'in', type = 'number', name = 'volume', description = 'The volume.'},
}

C.tags = {'scenario', 'aipacenotes'}

local logTag = 'aipacenotes'

function C:init(mgr, ...)
  self:resetAudioQueue()
end

function C:resetAudioQueue()
  self.queue = dequeue.new()

  if self.currAudioObj then
    local sfxSource = scenetree.findObjectById(self.currAudioObj.sourceId)
    if sfxSource then
      sfxSource:stop(-1)
    end
    local fn = '/tmp/pacenote_damage.ogg'
    local res = Engine.Audio.playOnce('AudioGui', fn)
  end

  self.currAudioObj = nil
end

local function normalize_text(s)
  local hash_value = 0
  for i = 1, #s do
    hash_value = (hash_value * 33 + string.byte(s, i)) % 2147483647
  end
  return hash_value
end

local function fileExists(filename)
  local file = io.open(filename, "r")
  if file == nil then
    return false
  else
    file:close()
    return true
  end
end

local function getTime()
  -- os.clockhp appears to be beamng-specific.
  return os.clockhp()
end

-- function printFields(obj)
--   for k, v in pairs(obj) do
--     -- if type(v) == "function" then
--       print(k)
--     -- end
--   end
-- end

function C:enqueueFromPinIns()
  local pacenote = self.pinIn.note.value
  local missionDir = self.pinIn.missionDir.value
  local pacenoteHash = normalize_text(pacenote)
  local pacenotesVersion = self.pinIn.notebookName.value
  -- local volume = self.pinIn.volume.value

  -- printFunctions(Engine.Audio)

  local pacenoteFname = missionDir .. '/pacenotes/' .. pacenotesVersion .. '/pacenote_' .. pacenoteHash .. '.ogg'
  log('I', logTag, "pacenote='" .. pacenote .. "', filename=" .. pacenoteFname)

  local audioObj = {
    audioType = 'pacenote',
    pacenoteFname = pacenoteFname,
    volume = 2,
    time = getTime(),
    audioLen = nil,
    timeout = nil,
    sourceId = nil,
    breathSuffixTime = 0.15, -- add time to represent the co-driver taking a breath after reading a pacenote.
  }

  if fileExists(pacenoteFname) then
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
    local isPastExpireTime = getTime() > self.currAudioObj.timeout
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

local function playPacenote(audioObj)
  local opts = { volume=audioObj.volume }
  local ch = 'AudioGUI' -- volume is controlled by OTHER
  -- local ch = 'AudioMusic' -- volume is controlled by MUSIC
  local res = Engine.Audio.playOnce(ch, audioObj.pacenoteFname, opts)
  -- printFields(res)
  local sfxSource = scenetree.findObjectById(res.sourceId)
  -- log('D', logTag, dumps(sfxSource))
  -- printFields(sfxSource)
  if res == nil then
    log('E', logTag, 'error playing audio')
  end
  -- set these fields, so that the next time flow triggers audio playing, the timeout will be respected.
  audioObj.audioLen = res.len
  audioObj.timeout = audioObj.time + audioObj.audioLen + audioObj.breathSuffixTime
  audioObj.sourceId = res.sourceId
  log('D', logTag, 'audioObj audioLen='..tostring(audioObj.audioLen) .. ' timeout='..tostring(audioObj.timeout))

  -- once we know the timeout of the audio, we can calculate the breath timeout.
  -- self.queue:push_right(self:makeBreath(2.0))
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
      playPacenote(self.currAudioObj)
    -- elseif self.currAudioObj.audioType == 'breath' then
      -- playBreath(self.currAudioObj)
    else
      log('E', logTag, 'unknown audioType: '..self.currAudioObj.audioType)
    end
  end
end

return _flowgraph_createNode(C)