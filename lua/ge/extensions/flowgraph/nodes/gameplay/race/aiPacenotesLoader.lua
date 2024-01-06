-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenotes Loader'
C.description = 'Loads initial data.'

C.category = 'once_p_duration'
C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'string', name = 'raceFname', description = 'The race file.', default = 'race.race.json'},
  -- {dir = 'in', type = 'bool', name = 'reverse', description = 'If the path should be reversed, if possible.'},

  {dir = 'out', type = 'table', name = 'pathData', tableType = 'pathData', description = 'RacePath data.'},
  {dir = 'out', type = 'string', name = 'name', description = 'Name of the Rally'},
  {dir = 'out', type = 'string', name = 'desc', description = 'Description of the Rally'},
  {dir = 'out', type = 'bool', name = 'branching', hidden= true, description = 'If the path is branching.'},
  {dir = 'out', type = 'bool', name = 'closed', hidden= true, description = 'If the path is closed.'},
  {dir = 'out', type = 'number', name = 'laps', hidden= true,  description = 'Default number of laps.'},
  {dir = 'out', type = 'number', name = 'checkpointCount', hidden= true,  description = 'Number of checkpoints in total (does nto work for branching)'},
  {dir = 'out', type = 'number', name = 'recoveryCount', hidden= true,  description = 'Number of checkpoints that have a recovery point set up'},

  {dir = 'out', type = 'table', name = 'aipSettings', tableType = 'aipSettings', description = "The loaded mission.settings.json file."},
}

C.tags = {'scenario', 'aipacenotes'}

function C:init(mgr, ...)
  self.missionId = nil
  self.missionDir = nil

  self.pathRace = nil
  self.pathMissionSettings = nil
  self.pathNotebook = nil

  self.codriver = nil

  self.clearOutPinsOnStart = false
end

function C:postInit()
  -- self.pinInLocal.file.allowFiles = {
  --   {"Rally Files",".notebook.json"},
  -- }
end

local function fileExists(filename)
  -- log('D', logTag, 'checking file exists: '..filename)
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

  if theMissionId then
    self.missionId = theMissionId
    self.missionDir = '/gameplay/missions/'..theMissionId
  else
    log('E', logTag, 'couldnt detect missionId')
    error('missionId was not detected')
  end
end

function C:getRaceFile()
  if not self.missionDir then
    self:detectMissionId()
  end

  local raceFname = self.missionDir..'/'..self.pinIn.raceFname.value
  if not fileExists(raceFname) then
    log('E', logTag, 'race file doesnt exist: ' .. raceFname)
    return nil
  end

  local json = jsonReadFile(raceFname)
  if not json then
    log('E', logTag, 'unable to read race file at: ' .. raceFname)
    return nil
  end

  local racePath = require('/lua/ge/extensions/gameplay/race/path')('New Race')
  racePath:onDeserialized(json)

  return racePath
end

function C:getMissionSpecificSettings()
  if not self.missionDir then
    self:detectMissionId()
  end
  local settingsFname = self.missionDir..'/aipacenotes/mission.settings.json'
  log('D', logTag, 'reading settings file: ' .. tostring(settingsFname))
  local json = jsonReadFile(settingsFname)
  if not json then
    log('E', logTag, 'unable to read settings file at: ' .. tostring(settingsFname))
    return nil
  end
  local settings = require('/lua/ge/extensions/gameplay/notebook/path_mission_settings')(settingsFname)
  settings:onDeserialized(json)
  return settings
end

function C:getNotebookFile()
  if not self.missionDir then
    self:detectMissionId()
  end
  local notebookFname = self.missionDir..'/'..re_util.notebooksPath..self.pathMissionSettings.notebook.filename
  log('D', logTag, 'reading notebook file: ' .. notebookFname)
  local json = jsonReadFile(notebookFname)
  if not json then
    log('E', logTag, 'unable to read notebook file at: ' .. notebookFname)
    return nil
  end
  local notebook = require('/lua/ge/extensions/gameplay/notebook/path')("New Path")
  notebook:onDeserialized(json)
  return notebook
end

function C:drawCustomProperties()
  if im.Button("Open Rally Editor") then
    if editor_rallyEditor then
      editor_rallyEditor.show()
    end
  end
  if editor_rallyEditor then
    local fn = editor_rallyEditor.getCurrentFilename()
    if fn then
      im.Text("Currently open file in RallyEditor:")
      im.Text(fn)
  --     if im.Button("Hardcode to File Pin") then
  --       self:_setHardcodedDummyInputPin(self.pinInLocal.file, fn)
  --     end
    end
  end
end

function C:onNodeReset()
  self.pathRace = nil
  self.pathMissionSettings = nil
  self.pathNotebook = nil
end

function C:_executionStopped()
  self.pathRace = nil
  self.pathMissionSettings = nil
  self.pathNotebook = nil
end

local function setupRaceFromNotebook(race, notebook, settings)
  local codriver_name = settings.notebook.codriver
  local codriver = nil
  for i,cd in ipairs(notebook.codrivers.sorted) do
    if cd.name == codriver_name then
      codriver = cd
    end
  end

  if not codriver then
    log('E', logTag, 'codriver with name of "'..codriver_name..'" was not found. double-check <mission_dir>/aipacenotes/mission.settings.json')
    return nil
  end

  local lang = codriver.language

  for i,pn in ipairs(notebook.pacenotes.sorted) do
    pn:setFieldsForFlowgraph(lang)
  end

  race.pacenotes = notebook.pacenotes
  return codriver
end

function C:work(args)
  if not self.missionDir then
    self:detectMissionId()
  end

  -- self.pinOut.flow.value = self.pinIn.flow.value

  if not self.pathMissionSettings then
    self.pathMissionSettings = self:getMissionSpecificSettings()
    -- log('D', 'wtf', dumps(self.pathMissionSettings))
    if not self.pathMissionSettings then
      self:__setNodeError('file', 'unable to find mission.settings.json file')
    end
    -- log('D', 'wtf', self.missionDir)
    self.pathMissionSettings.missionDir = self.missionDir
  end


  if not self.pathNotebook then
    self.pathNotebook = self:getNotebookFile()
    if not self.pathNotebook then
      self:__setNodeError('file', 'unable to find *.notebook.json file')
    end
    self.pathMissionSettings.notebookName = self.pathNotebook.name
    -- log('D', 'wtf', self.pathNotebook.name)
  end

  local codriver = nil
  if not self.pathRace then
    self.pathRace = self:getRaceFile()
    if not self.pathRace then
      self:__setNodeError('file', 'unable to find *.race.json file')
    end
    codriver = setupRaceFromNotebook(self.pathRace, self.pathNotebook, self.pathMissionSettings)
    if not codriver then
      self:__setNodeError('file', 'unable to update pacenotes from notebook')
    end
  end

  self.pathMissionSettings.language = codriver.language
  self.pathMissionSettings.voice = codriver.voice

  self.pinOut.aipSettings.value = self.pathMissionSettings

  if self.pinIn.reverse.value then
    self.pathRace:reverse()
  end
  self.pathRace:autoConfig()
  self.pinOut.pathData.value = self.pathRace
  self.pinOut.desc.value = self.pathRace.description
  self.pinOut.name.value = self.pathRace.name
  self.pinOut.branching.value = self.pathRace.config.branching
  self.pinOut.closed.value = self.pathRace.config.closed
  self.pinOut.laps.value = self.pathRace.defaultLaps
  self.pinOut.checkpointCount.value = #(self.pathRace.pathnodes.sorted)
  local rCount = 0
  for _, pn in ipairs(self.pathRace.pathnodes.sorted) do
    if self.pinIn.reverse.value then
      if not pn:getReverseRecovery().missing then
        rCount = rCount + 1
      end
    else
      if not pn:getRecovery().missing then
        rCount = rCount + 1
      end
    end
  end

  self.pinOut.recoveryCount.value = rCount
end

return _flowgraph_createNode(C)
