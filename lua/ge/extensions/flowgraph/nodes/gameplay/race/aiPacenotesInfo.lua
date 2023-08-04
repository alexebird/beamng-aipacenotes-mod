-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Pacenotes Info'
C.description = 'Get data related to the AI Pacenotes mod.'
C.category = 'aipacenotes'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  -- {dir = 'in', type = 'bool', name = 'useRaceEditor', description = 'Should the race file be pulled from the race tool.'},

  {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.', impulse = false},
  {dir = 'out', type = 'flow', name = 'active', description = 'Outflow if pacenotes ARE detected for this mission.', impulse = false},
  {dir = 'out', type = 'flow', name = 'inactive', description = 'Outflow if pacenotes ARE NOT detected for this mission.', impulse = false},
  {dir = 'out', type = 'string', name = 'currentVersion', default = nil, description = 'The version string of the installed pacenotes version. (see <mission-path>/pacenotes/settings.json)'},
  {dir = 'out', type = 'number', name = 'volume', default = nil, description = 'The volume when playing audio files. (see <mission-path>/pacenotes/settings.json)'},

  {dir = 'out', type = 'string', name = 'missionDir', default = nil, description = 'Path of the mission\'s root directory.'},
  {dir = 'out', type = 'string', name = 'raceFile', default = nil, description = 'Path of the mission\'s race file.'},

  {dir = 'out', type = 'bool', name = 'unavailable', default = true, description = 'If AI pacenotes are detected and enabled for this mission.'},

  -- {dir = 'out', type = 'table', name = 'settings', description = 'Settings from the settings.json file in the mission\'s pacenotes dir.'},
  -- {dir = 'out', type = 'bool', name = 'usingAiPacenotes', default = false, description = 'Returns true if if the timeTrial mission is using AI pacenotes (based on detecting the settings file).'},
  -- {dir = 'out', type = 'string', name = 'currentVersion', default = nil, description = 'The version string of the installed pacenotes version.'},
  -- {dir = 'out', type = 'string', name = 'volume', default = nil, description = 'The version string of the installed pacenotes version.'},
  -- {dir = 'out', type = 'string', name = 'showWaypoints', default = true, description = 'If waypoint markers and audio should be shown.'},
}

C.tags = {'scenario', 'aipacenotes'}

local logTag = 'aipacenotes'

function C:init(mgr, ...)
  self.missionId = nil
  self.missionDir = nil
  self.raceFile = nil
  self.pacenotesFile = nil
  self.settings = nil
  
  self:detectMissionId()
end

function C:getMissionSpecificSettings()
  if self.settings then
    return self.settings
  end
  if not self.missionDir then
    self:detectMissionId()
  end
  local settingsFname = self.missionDir..'/pacenotes/settings.json'
  log('D', logTag, 'reading settings file: ' .. tostring(settingsFname))
  local json = jsonReadFile(settingsFname)
  if not json then
    log('E', logTag, 'unable to read settings file at: ' .. tostring(settingsFname))
    return nil
  end
  self.settings = json
  return self.settings
end

local function fileExists(filename)
  log('D', logTag, 'checking file exists: '..filename)
  local file = io.open(filename, "r")
  if file == nil then
    return false
  else
    file:close()
    return true
  end
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

function C:detectMissionId()
  self.missionId = nil
  self.missionDir = nil

  -- first try the mission manager.
  local theMissionId = detectMissionManagerMissionId()
  if theMissionId then
    log('D', logTag, 'missionId "'.. theMissionId ..'"detected from missionManager')
  end

  -- then try the mission editor
  if not theMissionId then
    theMissionId = detectMissionEditorMissionId()
    if theMissionId then
      log('D', logTag, 'missionId "'.. theMissionId ..'"detected from missionEditor')
    end
  end

  if theMissionId then
    self.missionId = theMissionId
    self.missionDir = '/gameplay/missions/'..theMissionId
  else
    log('E', logTag, 'couldnt detect missionId')
  end
end

function C:getPacenotesFile()
  if self.pacenotesFile then
    return self.pacenotesFile
  end
  self.pacenotesFile = self.missionDir..'/pacenotes.pacenotes.json'
  if not fileExists(self.pacenotesFile) then
    self.pacenotesFile = nil
  end
  return self.pacenotesFile
end

function C:getRaceFile()
  if self.raceFile then
    return self.raceFile
  end
  self.raceFile = self.missionDir..'/race.race.json'
  if not fileExists(self.raceFile) then
    self.raceFile = nil
  end
  return self.raceFile

  -- local ret = editor_raceEditorTurbo
  -- if ret then
  --   self.pinOut.file.value = ret.getCurrentFilename()
  -- else
  --   self.pinOut.file.value = 'race.race.json'
  -- end
  -- if useRaceEditor == true then
  --   log('D', logTag, 'using race file from Race Editor')
  --   raceFname = editor_raceEditorTurbo.getCurrentFilename()
  --   missionDir = getTheDirname(raceFname)
  -- else
  --   raceFname = 'race.race.json'
  --   missionDir = 'gameplay/missions/' .. detectMissionId()
  -- end
end

function C:work(args)
  local missionDir = self.missionDir
  local raceFname = self:getRaceFile()
  local isActive = not not self:getPacenotesFile()
  local settings = self:getMissionSpecificSettings()

  self.pinOut.flow.value = self.pinIn.flow.value
  self.pinOut.active.value = isActive
  self.pinOut.inactive.value = not isActive
  self.pinOut.unavailable.value = not isActive

  if settings then
    self.pinOut.currentVersion.value = settings.currentVersion
    self.pinOut.volume.value = settings.volume
  end

  self.pinOut.raceFile.value = raceFname
  self.pinOut.missionDir.value = missionDir
end

return _flowgraph_createNode(C)