-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Pacenote Play'
C.description = 'Plays a pacenote audio file.'
C.category = 'aipacenotes'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'string', name = 'note', description = 'The pacenote.'},
  {dir = 'in', type = 'string', name = 'version', description = 'Pacenotes version string.'},
  {dir = 'in', type = 'string', name = 'missionDir', description = 'Root path of the mission.'},
  {dir = 'in', type = 'number', name = 'volume', description = 'The volume.'},

  -- {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.', impulse = false},
  -- {dir = 'out', type = 'string', name = 'file', description = 'Pacenote filename.'},
}

C.tags = {'scenario', 'aipacenotes'}

local logTag = 'aipacenotes'

local function normalize_text(s)
  local hash_value = 0
  for i = 1, #s do
    hash_value = (hash_value * 33 + string.byte(s, i)) % 2147483647
  end
  return hash_value
end

-- local function readMissionSpecificSettings(missionDir)
--   local settingsFname = missionDir .. '/pacenotes/settings.json'
--   log('D', logTag, 'settings file: ' .. tostring(settingsFname))
--   local json = jsonReadFile(settingsFname)
--   if not json then
--     log('E', logTag, 'unable to read settings file at: ' .. tostring(settingsFname))
--     return
--   end
--   return json
-- end

-- local function file_exists(filename)
--   local file = io.open(filename, "r")
--   if file == nil then
--     return false
--   else
--     file:close()
--     return true
--   end
-- end

-- local function getTheDirname(path)
--     return string.match(path, "(.+)/[^/]*$")
-- end

-- for cli running and testing of code only
-- local isDev = os.getenv("DEV")
-- if isDev == "t" then
--   print(normalize_text("Hello, World!"))
-- else
--   entrypoint()
-- end

function C:init(mgr, ...)
  -- self.data.detailed = false
end

-- local function getMissionId()
--   local theMissionId = nil

--   if gameplay_missions_missionManager then
--      theMissionId = gameplay_missions_missionManager.getForegroundMissionId()
--   end

--   if not theMissionId and editor_missionEditor then
--     local selectedMission = editor_missionEditor.getSelectedMissionId()
--     if selectedMission then
--       theMissionId = selectedMission.id
--     end
--   end

--   return theMissionId
-- end

local function fileExists(filename)
  local file = io.open(filename, "r")
  if file == nil then
    return false
  else
    file:close()
    return true
  end
end

function C:work(args)
  local pacenote = self.pinIn.note.value
  -- local pathData = self.pinIn.pathData.value
  -- local useRaceEditor = self.pinIn.useRaceEditor.value

  -- local raceFname = nil
  local missionDir = self.pinIn.missionDir.value

  -- if useRaceEditor == true then
  --   log('D', logTag, 'using race file from Race Editor')
  --   raceFname = editor_raceEditorTurbo.getCurrentFilename()
  --   missionDir = getTheDirname(raceFname)
    -- local pnWindow = editor_raceEditorTurbo.getPacenotesWindow()
  -- else
    -- raceFname = 'race.race.json'
    -- missionDir = 'gameplay/missions/' .. gameplay_missions_missionManager.getForegroundMissionId()
    -- missionDir = 'gameplay/missions/' .. getMissionId()
  -- end

  -- log('I', logTag, 'got pacenote=' .. pacenote)

  -- local settings = readMissionSpecificSettings(missionDir)
  -- if not settings then
    -- log('E', logTag, 'settings were nil')
    -- return
  -- end
  local pacenoteHash = normalize_text(pacenote)
  local pacenotesVersion = self.pinIn.version.value
  local volume = self.pinIn.volume.value

  local pacenoteFname = missionDir .. '/pacenotes/' .. pacenotesVersion .. '/pacenote_' .. pacenoteHash .. '.ogg'
  log('I', logTag, "pacenote='" .. pacenote .. "', filename=" .. pacenoteFname)

  if fileExists(pacenoteFname) then
    Engine.Audio.playOnce('AudioGui', pacenoteFname, { volume=volume })
  else
    log('E', logTag, "pacenote audio file does not exist: " .. pacenoteFname)
    return
  end

  -- self.pinOut.file.value = pacenoteFname
end

return _flowgraph_createNode(C)