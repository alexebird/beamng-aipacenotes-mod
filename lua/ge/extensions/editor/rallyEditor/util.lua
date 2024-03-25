-- usage:
--
-- local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
-- re_util.notebooksPath
--

local logTag = 'aipacenotes'

local M = {}

local autofill_blocker = '#'
local autodist_internal_level1 = '<none>'
local unknown_transcript_str = '[unknown]'
local aipPath = 'aipacenotes'
local notebooksPath = aipPath..'/notebooks'
local transcriptsPath = aipPath..'/transcripts'
local reccePath = aipPath..'/recce'
local recceRecordSubdir = 'primary'

local aipSettingsRoot = '/settings/aipacenotes'
local desktopTranscriptFname = aipSettingsRoot..'/desktop.transcripts.json'
local staticPacenotesFname = aipSettingsRoot..'/static_pacenotes.json'
local cornerAnglesFname = aipSettingsRoot..'/corner_angles.json'
local pacenotesMetadataBasename = 'metadata.json'
local notebookFileExt = 'notebook.json'

local transcriptsExt = 'transcripts.json'
local missionSettingsFname = 'mission.settings.json'
local default_notebook_name = 'primary'
local default_codriver_name = 'Sophia'
local default_codriver_voice = 'british_female'
local default_codriver_language = 'english'

local default_punctuation = '?'
local default_punctuation_last = '.'
local default_punctuation_distance_call = '.'
local validPunctuation = {"?", ".", "?", "!"}

local dist_km_threshold = 1000
local dist_large_threshold = 100
local kilo_unit_str = "km"
local dist_round_small = 10
local dist_round_large = 50
local dist_round_km = 250

local var_dl = '{dl}'
local var_dt = '{dt}'

-- html code: #00ffdebf
local aip_fg_color = ui_imgui.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

local function pacenote_hash(s)
    local hex_string = ""
    for i = 1, #s do
        local byte = string.byte(s, i)
        hex_string = hex_string .. string.format("%02x", byte)
    end

    local hash_value = 0
    for i = 1, #hex_string do
        hash_value = (hash_value * 33 + string.byte(hex_string, i)) % 2147483647
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
  if not name then return nil end

  -- Replace everything but letters and numbers with '_'
  name = string.gsub(name, "[^a-zA-Z0-9]", "_")

  -- Replace multiple consecutive '_' with a single '_'
  name = string.gsub(name, "(_+)", "_")

  return name
end

-- assumes that the file exists.
-- local function playPacenote2(audioObj)
--   local opts = { volume=audioObj.volume }
--   audioObj.time = getTime()




  -- local x = Engine.Audio.createSource('AudioGui', ' /gameplay/missions/driver_training/rallyStage/aip-test3/aipacenotes/notebooks/generated_pacenotes/primary/Sophia_english_british_female/pacenote_40820133.ogg')
  -- /gameplay/missions/driver_training/rallyStage/aip-test3/aipacenotes/notebooks/generated_pacenotes/primary/Sophia_english_british_female/pacenote_40820133.ogg

  -- paramGroupG = SFXParameterGroup()
  -- paramGroupG:setPrefixFilter('global_')
  -- paramGroupG:registerObject('')
  --
  -- paramGroupA = SFXParameterGroup()
  -- paramGroupA:registerObject('')
  --
  -- paramGroupB = SFXParameterGroup()
  -- paramGroupB:registerObject('')
  --
  -- soundA = Engine.Audio.createSource2('AudioGui', 'event:>TestGroup>TestEvent')
  -- paramGroupA:addSource(soundA)
  -- soundB = Engine.Audio.createSource2('AudioGui', 'event:>TestGroup>TestEvent')
  -- paramGroupB:addSource(soundB)
  --
  -- soundA:play(-1)
  -- soundB:play(-1)
  --
  -- paramGroupA:setParameterValue('test0', 0)
  -- paramGroupB:setParameterValue('test0', 0)
  --
  --
  -- local soundParams = SFXParameterGroup("CreditsSoundParams")
  -- creditsSoundId = Engine.Audio.createSource('AudioGui', 'event:>Music>credits')
  -- local snd = scenetree.findObjectById(creditsSoundId)
  -- if snd then
  --   snd:play(-1)
  --   soundParams:addSource(snd.obj)
  -- end

--   local paramGroupA = SFXParameterGroup('foo')
--   paramGroupA:setPrefixFilter('foo_')
--   -- print(dumps(paramGroupA))
--   print(dumps(paramGroupA.__index))
--   -- print(dumps(getmetatable(paramGroupA)))
--   -- paramGroupA:registerObject('')
--   paramGroupA:setParameterValue('foo_CabinFilterReverbStrength', 0)
--   paramGroupA:setParameterValue('c_CabinFilterReverbStrength', 0)
--
--
--   local globalParams = Engine.Audio.getGlobalParams()
--   print(dumps(globalParams))
--   local providers = Engine.Audio.getInfo()
--   print(dumps(providers))
--
--   local fname = "/gameplay/missions/driver_training/rallyStage/aip-test3/aipacenotes/notebooks/generated_pacenotes/primary/Sophia_english_british_female/pacenote_1394115997.ogg"
--   -- local fname = 'event:>Music>credits'
--
--   local soundId = Engine.Audio.createSource('AudioGui', fname)
--   local snd = scenetree.findObjectById(soundId)
--   paramGroupA:addSource(snd.obj)
--   snd:play(-1)
--
--
--
--
--
--   local paramGroupA = SFXParameterGroup('foo')
--   paramGroupA:setPrefixFilter('foo_')
--   paramGroupA:setParameterValue('foo_CabinFilterReverbStrength', 0)
--   local fname = "/gameplay/missions/driver_training/rallyStage/aip-test3/aipacenotes/notebooks/generated_pacenotes/primary/Sophia_english_british_female/pacenote_1394115997.ogg"
--   local soundId = Engine.Audio.createSource('AudioGui', fname)
--   local snd = scenetree.findObjectById(soundId)
--   paramGroupA:addSource(snd.obj)
--   snd:play(-1)
--
--
--
--
--
--   -- local ch = 'AudioGUI'
--
--   -- local res = Engine.Audio.playOnce(ch, audioObj.pacenoteFname, opts)
--   -- printFields(res)
--
--   -- if not res then
--   --   log('E', logTag, 'error playing audio')
--   --   return
--   -- end
--
--   -- local sfxSource = scenetree.findObjectById(res.sourceId)
--   -- log('D', logTag, dumps(sfxSource))
--   -- printFields(sfxSource)
--
--   -- set these fields, so that the next time flow triggers audio playing, the timeout will be respected.
--   -- audioObj.audioLen = res.len
--   -- audioObj.timeout = audioObj.time + audioObj.audioLen + audioObj.breathSuffixTime
--   -- audioObj.sourceId = res.sourceId
--   -- log('D', logTag, 'playPacenote channel='..ch..' '..dumps(audioObj))
-- end

-- assumes that the file exists.
local function playPacenote(audioObj)
  local opts = { volume=audioObj.volume }
  audioObj.time = getTime()

  local ch = 'AudioGUI' -- volume is controlled by OTHER
  -- local ch = 'AudioMusic' -- volume is controlled by MUSIC

  local res = Engine.Audio.playOnce(ch, audioObj.pacenoteFname, opts)
  -- printFields(res)

  if not res then
    log('E', logTag, 'error playing audio')
    return
  end

  -- local sfxSource = scenetree.findObjectById(res.sourceId)
  -- log('D', logTag, dumps(sfxSource))
  -- printFields(sfxSource)

  -- set these fields, so that the next time flow triggers audio playing, the timeout will be respected.
  audioObj.audioLen = res.len
  audioObj.timeout = audioObj.time + audioObj.audioLen + audioObj.breathSuffixTime
  audioObj.sourceId = res.sourceId
  log('D', logTag, 'playPacenote channel='..ch..' '..dumps(audioObj))
end

local function playPacenoteGui(audioObj)
  -- local opts = { volume=audioObj.volume }
  audioObj.time = getTime()

  -- local ch = 'AudioGUI' -- volume is controlled by OTHER
  -- local ch = 'AudioMusic' -- volume is controlled by MUSIC

  -- local res = Engine.Audio.playOnce(ch, audioObj.pacenoteFname, opts)
  -- printFields(res)

  local req = {
    name = audioObj.note_name,
    url = audioObj.pacenoteFname,
    volume = audioObj.volume,
  }
  guihooks.trigger('aiPacenotes.codriverApp.playAudio', req)

  -- if not res then
  --   log('E', logTag, 'error playing audio')
  --   return
  -- end

  -- local sfxSource = scenetree.findObjectById(res.sourceId)
  -- log('D', logTag, dumps(sfxSource))
  -- printFields(sfxSource)

  -- set these fields, so that the next time flow triggers audio playing, the timeout will be respected.
  -- audioObj.audioLen = res.len
  audioObj.timeout = audioObj.time + audioObj.audioLen + audioObj.breathSuffixTime
  -- audioObj.sourceId = res.sourceId
  -- log('D', logTag, 'playPacenoteGui '..dumps(audioObj))
end

local function buildAudioObjPacenote(pacenoteFname)
  local audioObj = {
    audioType = 'pacenote',
    pacenoteFname = pacenoteFname,
    volume = 1,
    created_at = getTime(),
    time = nil,
    audioLen = nil,
    timeout = nil,
    sourceId = nil,
    breathSuffixTime = 0.3, -- add time to represent the co-driver taking a breath after reading a pacenote.
  }

  return audioObj
end

local function buildAudioObjPause(pauseSecs)
  local audioObj = {
    audioType = 'pause',
    created_at = getTime(),
    time = nil,
    audioLen = nil,
    timeout = nil,
    pauseTime = pauseSecs,
  }

  return audioObj
end

local function hasPunctuation(last_char)
  -- return last_char == "." or last_char == "?" or last_char == "!"

  for _,char in ipairs(validPunctuation) do
    if last_char == char then
      return true
    end
  end

  return false
end

local function stripWhitespace(str)
  return str:gsub("^%s*(.-)%s*$", "%1")
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

local function getNotebookHelper(missionDir, missionSettings)
  local notebookFname = missionDir..'/'..notebooksPath..'/'..missionSettings.notebook.filename
  if not FS:fileExists(notebookFname) then
    return nil, "notebook file not found: "..notebookFname
  end

  log('D', logTag, 'reading notebook file: ' .. notebookFname)
  local json = jsonReadFile(notebookFname)
  if not json then
    return nil, 'unable to read notebook file at: ' .. notebookFname
  end

  local notebook = require('/lua/ge/extensions/gameplay/notebook/path')()
  notebook:setFname(notebookFname)
  notebook:onDeserialized(json)

  return notebook, nil
end

local function missionTranscriptsDir(missionDir)
  return missionDir..'/'..transcriptsPath
end

local function missionRecceDir(missionDir)
  return missionDir..'/'..reccePath
end

local function missionTranscriptPath(missionDir, basename, addExt)
  addExt = addExt or false
  local rv = missionTranscriptsDir(missionDir)..'/'..basename
  if addExt then
    rv = rv..'.'..transcriptsExt
  end
  return rv
end

local function missionRecceRecordDir(missionDir)
  local rv = missionRecceDir(missionDir)..'/'..recceRecordSubdir
  return rv
end

local function missionReccePath(missionDir, basename)
  local subdir = missionRecceRecordDir(missionDir)
  local rv = subdir..'/'..basename
  -- local rv = missionRecceDir(missionDir)..'/'..subdir..'/'..basename
  return rv
end

local function drivelineFile(missionDir)
  return missionReccePath(missionDir, 'driveline.json')
end

local function cutsFile(missionDir)
  return missionReccePath(missionDir, 'cuts.json')
end

local function transcriptsFile(missionDir)
  return missionReccePath(missionDir, 'transcripts.json')
end

-- args are both vec3's representing a position.
local function calculateForwardNormal(snap_pos, next_pos)
  local flip = false
  local dx = next_pos.x - snap_pos.x
  local dy = next_pos.y - snap_pos.y
  local dz = next_pos.z - snap_pos.z

  local magnitude = math.sqrt(dx*dx + dy*dy + dz*dz)
  if magnitude == 0 then
    error("The two positions must not be identical.")
  end

  local normal = vec3(dx / magnitude, dy / magnitude, dz / magnitude)

  if flip then
    normal = -normal
  end

  return normal
end

local function loadCornerAnglesFile()
  local filename = cornerAnglesFname
  local json = jsonReadFile(filename)
  if json then
    return json, nil
  else
    local err = 'unable to find corner_angles file: ' .. tostring(filename)
    log('E', 'aipacenotes', err)
    return nil, err
  end
end

local function determineCornerCall(angles, steering)
  local absSteeringVal = math.abs(steering)
  for i,angle in ipairs(angles) do
    if absSteeringVal >= angle.fromAngleDegrees and absSteeringVal < angle.toAngleDegrees then
      local direction = steering >= 0 and "L" or "R"
      local cornerCallWithDirection = angle.cornerCall..direction
      if angle.cornerCall == '_deadzone' then
        cornerCallWithDirection = 'c'
      end

    local range = angle.toAngleDegrees - angle.fromAngleDegrees
    local pct = (absSteeringVal - angle.fromAngleDegrees) / range
      return angle, string.upper(cornerCallWithDirection), pct
    end
  end
end

local function trimString(txt)
  if not txt then return txt end
  return txt:gsub("^%s*(.-)%s*$", "%1")
end

local function stripBasename(thepath)
  if not thepath then return nil end

  if thepath:sub(-1) == "/" then
    thepath = thepath:sub(1, -2)
  end
  local dirname, fn, e = path.split(thepath)

  if dirname:sub(-1) == "/" then
    dirname = dirname:sub(1, -2)
  end
  return dirname
end

-- local function setCameraTarget(pos)
--   if pos then
--     pos = vec3(pos)
--     local cam_rot = core_camera.getForward()
--     local elevation = editor_rallyEditor.getPrefTopDownCameraElevation()
--     local newCamPos = pos + (-cam_rot:normalized() * elevation)
--     core_camera.setPosition(0, newCamPos)
--   end
-- end

local function matchSearchPattern(searchPattern, stringToMatch)
  -- Escape special characters in Lua patterns except '*'
  searchPattern = searchPattern:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
  -- Replace '*' with Lua's '.*' to act as a wildcard
  searchPattern = searchPattern:gsub("%*", ".*")

  return stringToMatch:match(searchPattern) ~= nil
end

-- local function loadMissionSettings(folder)
--   local settingsFname = folder..'/'..aipPath..'/'..missionSettingsFname
--   local settings = require('/lua/ge/extensions/gameplay/notebook/pathMissionSettings')(settingsFname)
--
--   if FS:fileExists(settingsFname) then
--     local json = jsonReadFile(settingsFname)
--     if not json then
--       log('E', 'aipacenotes', 'error reading mission.settings.json file: ' .. tostring(settingsFname))
--       return nil
--     else
--       settings:onDeserialized(json)
--     end
--   end
--
--   return settings
-- end

local function buildPacenotesDir(missionDir, notebook, codriver)
  local notebookBasename = normalize_name(notebook:basenameNoExt()) or 'none'
  local codriverName = codriver.name
  local codriverLang = codriver.language
  local codriverVoice = codriver.voice
  local codriverStr = normalize_name(codriverName..'_'..codriverLang..'_'..codriverVoice)
  local dirname = missionDir..'/'..notebooksPath..'/generated_pacenotes/'..notebookBasename..'/'..codriverStr
  return dirname
end

-- vars
M.aipPath = aipPath
M.aipSettingsRoot = aipSettingsRoot
M.aip_fg_color = aip_fg_color
M.autodist_internal_level1 = autodist_internal_level1
M.autofill_blocker = autofill_blocker
M.default_codriver_language = default_codriver_language
M.default_codriver_name = default_codriver_name
M.default_codriver_voice = default_codriver_voice
M.default_notebook_name = default_notebook_name
M.default_punctuation = default_punctuation
M.default_punctuation_last = default_punctuation_last
M.default_punctuation_distance_call = default_punctuation_distance_call
M.desktopTranscriptFname = desktopTranscriptFname
-- M.dragModes = dragModes
M.missionSettingsFname = missionSettingsFname
M.notebooksPath = notebooksPath
M.pacenotesMetadataBasename = pacenotesMetadataBasename
M.notebookFileExt = notebookFileExt
M.staticPacenotesFname = staticPacenotesFname
M.transcriptsExt = transcriptsExt
M.transcriptsPath = transcriptsPath
M.unknown_transcript_str = unknown_transcript_str
M.validPunctuation = validPunctuation
M.dist_km_threshold = dist_km_threshold
M.dist_large_threshold = dist_large_threshold
M.kilo_unit_str = kilo_unit_str
M.dist_round_small = dist_round_small
M.dist_round_large = dist_round_large
M.dist_round_km = dist_round_km
M.var_dl = var_dl
M.var_dt = var_dt

-- funcs
M.buildAudioObjPacenote = buildAudioObjPacenote
M.buildAudioObjPause = buildAudioObjPause
M.calculateForwardNormal = calculateForwardNormal
M.detectMissionEditorMissionId = detectMissionEditorMissionId
M.detectMissionIdHelper = detectMissionIdHelper
M.detectMissionManagerMissionId = detectMissionManagerMissionId
M.determineCornerCall = determineCornerCall
M.fileExists = fileExists
M.getNotebookHelper = getNotebookHelper
M.getTime = getTime
M.hasPunctuation = hasPunctuation
M.loadCornerAnglesFile = loadCornerAnglesFile
M.matchSearchPattern = matchSearchPattern
M.missionTranscriptPath = missionTranscriptPath
M.missionRecceRecordDir = missionRecceRecordDir
M.missionReccePath = missionReccePath

M.drivelineFile = drivelineFile
M.cutsFile = cutsFile
M.transcriptsFile = transcriptsFile

M.buildPacenotesDir = buildPacenotesDir
M.missionTranscriptsDir = missionTranscriptsDir
M.normalize_name = normalize_name
M.stripWhitespace = stripWhitespace
M.pacenote_hash = pacenote_hash
M.playPacenote = playPacenote
M.playPacenoteGui = playPacenoteGui
M.trimString = trimString
M.stripBasename = stripBasename

return M
