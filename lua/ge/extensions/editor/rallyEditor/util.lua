-- usage:
--
-- local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
-- re_util.notebooksPath
--

local logTag = 'aipacenotes'

local M = {}


local unknown_transcript_str = '[unknown]'
local notebooksPath = 'aipacenotes/notebooks/'
local default_notebook_name = 'primary'
local default_codriver_name = 'Sophia'
local default_codriver_voice = 'british_female'
local default_codriver_language = 'english'

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

local function buildAudioObjPacenote(pacenoteFname)
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

local function buildAudioObjPause(pauseSecs)
  local audioObj = {
    audioType = 'pause',
    time = getTime(),
    audioLen = nil,
    timeout = nil,
    pauseTime = pauseSecs,
  }

  return audioObj
end

local function hasPunctuation(last_char)
  return last_char == "." or last_char == "?" or last_char == "!"
end

local function detectMissionManagerMissionId()
  if gameplay_missions_missionManager then
    return gameplay_missions_missionManager.getForegroundMissionId()
  else
    return nil
  end
end

local function detectMissionEditorMissionId()
  if editor_missionEditor then
    local selectedMission = editor_missionEditor.getSelectedMissionId()
    if selectedMission then
      return selectedMission.id
    else
      return nil
    end
  else
    return nil
  end
end

local function detectMissionIdHelper()
  local missionId = nil
  local missionDir = nil

  -- first try the mission manager.
  local theMissionId = detectMissionManagerMissionId()
  if theMissionId then
    log('D', logTag, 'missionId "'.. theMissionId ..'"detected from missionManager')
  else
    log('W', logTag, 'no mission detected from missionManager')
  end

  -- then try the mission editor
  if not theMissionId then
    theMissionId = detectMissionEditorMissionId()
    if theMissionId then
      log('D', logTag, 'missionId "'.. theMissionId ..'"detected from missionEditor')
    else
      log('W', logTag, 'no mission detected from editor')
    end
  end

  if not theMissionId then
    log('E', logTag, 'couldnt detect missionId')
    return nil, nil, 'missionId could not be detected'
  end

  missionId = theMissionId
  missionDir = '/gameplay/missions/'..theMissionId

  return missionId, missionDir, nil
end

local function getMissionSettingsHelper(missionDir)
  local settingsFname = missionDir..'/aipacenotes/mission.settings.json'
  if not FS:fileExists(settingsFname) then
    return nil, "mission settings file not found: "..settingsFname
  end

  log('I', logTag, 'reading settings file: ' .. tostring(settingsFname))
  local json = jsonReadFile(settingsFname)
  if not json then
    return nil, 'unable to read settings file at: ' .. tostring(settingsFname)
  end

  local settings = require('/lua/ge/extensions/gameplay/notebook/path_mission_settings')(settingsFname)
  settings:onDeserialized(json)
  return settings, nil
end

local function getNotebookHelper(missionDir, missionSettings)
  local notebookFname = missionDir..'/'..notebooksPath..missionSettings.notebook.filename
  if not FS:fileExists(notebookFname) then
    return nil, "notebook file not found: "..notebookFname
  end

  log('D', logTag, 'reading notebook file: ' .. notebookFname)
  local json = jsonReadFile(notebookFname)
  if not json then
    return nil, 'unable to read notebook file at: ' .. notebookFname
  end

  local notebook = require('/lua/ge/extensions/gameplay/notebook/path')("New Path")
  notebook:onDeserialized(json)

  return notebook, nil
end


M.pacenote_hash = pacenote_hash
M.fileExists = fileExists
M.getTime = getTime
M.normalize_name = normalize_name
M.playPacenote = playPacenote
M.buildAudioObjPacenote = buildAudioObjPacenote
M.buildAudioObjPause = buildAudioObjPause
M.hasPunctuation = hasPunctuation

M.detectMissionManagerMissionId = detectMissionManagerMissionId
M.detectMissionEditorMissionId = detectMissionEditorMissionId
M.detectMissionIdHelper = detectMissionIdHelper
M.getMissionSettingsHelper = getMissionSettingsHelper
M.getNotebookHelper = getNotebookHelper

M.unknown_transcript_str = unknown_transcript_str
M.notebooksPath = notebooksPath
M.default_notebook_name = default_notebook_name
M.default_codriver_name = default_codriver_name
M.default_codriver_voice = default_codriver_voice
M.default_codriver_language = default_codriver_language

return M
