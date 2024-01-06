-- usage:
--
-- local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
-- re_util.notebooksPath
--

local logTag = 'aipacenotes'

local M = {}

local function pacenote_hash(s)
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

local function normalize_name(name)
  -- Replace everything but letters and numbers with '_'
  name = string.gsub(name, "[^a-zA-Z0-9]", "_")

  -- Replace multiple consecutive '_' with a single '_'
  name = string.gsub(name, "(_+)", "_")

  return name
end

-- assumes that the file exists.
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
end

local function buildAudioObj(pacenoteFname)
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

  return audioObj
end

local function hasPunctuation(last_char)
  return last_char == "." or last_char == "?" or last_char == "!"
end

M.pacenote_hash = pacenote_hash
M.fileExists = fileExists
M.getTime = getTime
M.normalize_name = normalize_name
M.playPacenote = playPacenote
M.buildAudioObj = buildAudioObj
M.hasPunctuation = hasPunctuation

M.unknown_transcript_str = '[unknown]'
M.notebooksPath = 'aipacenotes/notebooks/'
M.default_codriver_name = 'Sophia'
M.default_codriver_voice = 'british_female'
M.default_codriver_language = 'english'

return M
