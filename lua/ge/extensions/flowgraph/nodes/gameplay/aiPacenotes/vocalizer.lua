-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes-fg'

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenotes Vocalizer'
C.description = 'Plays pacenotes from a notebook.'

-- C.category = 'once_p_duration'
C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  { dir = 'in', type = 'flow',   name = 'flow',  description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow',   name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  { dir = 'in', type = 'bool', name = 'recce', description = 'Is any resetting of the car going on like in freeroam?', default = false},

  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
}

C.tags = {'aipacenotes'}

function C:init(mgr, ...)
  -- self.mgr = mgr
  self.audioManager = require('/lua/ge/extensions/gameplay/rally/audioManager')()
  self:resetState()
end

function C:resetState()
  self.setupDone = false
  self.missionId = nil
  self.missionDir = nil
  self.missionSettings = nil
  self.notebook = nil
  self.codriver = nil
  self.pacenoteState = {
    nextId = nil, -- this is the id of the pacenote we are looking for every dt.
  }
  self.vehicleTracker = nil
  self.audioManager:resetAudioQueue()
  self.closestPacenotes = nil
end

-- function C:postInit()
  -- self.pinInLocal.file.allowFiles = {
  --   {"Rally Files",".notebook.json"},
  -- }
-- end

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

  if not theMissionId then
    log('E', logTag, 'couldnt detect missionId')
    self:__setNodeError('setup', 'missionId could not be detected')
  end

  self.missionId = theMissionId
  self.missionDir = '/gameplay/missions/'..theMissionId
end

function C:getMissionSettings()
  local settingsFname = self.missionDir..'/aipacenotes/mission.settings.json'
  if not FS:fileExists(settingsFname) then
    self:__setNodeError('setup', "mission settings file not found: "..settingsFname)
  end

  log('I', logTag, 'reading settings file: ' .. tostring(settingsFname))
  local json = jsonReadFile(settingsFname)
  if not json then
    self:__setNodeError('setup', 'unable to read settings file at: ' .. tostring(settingsFname))
  end

  local settings = require('/lua/ge/extensions/gameplay/notebook/path_mission_settings')(settingsFname)
  settings:onDeserialized(json)
  self.missionSettings = settings
end

function C:getNotebook()
  local notebookFname = self.missionDir..'/'..re_util.notebooksPath..self.missionSettings.notebook.filename
  if not FS:fileExists(notebookFname) then
    self:__setNodeError('setup', "notebook file not found: "..notebookFname)
  end

  log('D', logTag, 'reading notebook file: ' .. notebookFname)
  local json = jsonReadFile(notebookFname)
  if not json then
    self:__setNodeError('setup', 'unable to read notebook file at: ' .. notebookFname)
  end

  local notebook = require('/lua/ge/extensions/gameplay/notebook/path')("New Path")
  notebook:onDeserialized(json)
  self.notebook = notebook
end

-- function C:drawCustomProperties()
--   if im.Button("Open Rally Editor") then
--     if editor_rallyEditor then
--       editor_rallyEditor.show()
--     end
--   end
--   if editor_rallyEditor then
--     local fn = editor_rallyEditor.getCurrentFilename()
--     if fn then
--       im.Text("Currently open file in RallyEditor:")
--       im.Text(fn)
--     end
--   end
-- end

function C:onNodeReset()
  self:resetState()
end

-- 1. get mission dir
-- 2. get aipacenotes/mission.settings.json
-- 3. get notebook from settings
-- 4. get codriver from notebook+settings
-- 5. generate list of flowgraph data from the notebook's pacenotes
function C:initialSetup()
  log('I', logTag, 'setting up AI Pacenotes flowgraph node')

  self:detectMissionId()
  self:getMissionSettings()
  self:getNotebook()

  self.missionSettings.fgNode = { missionDir = self.missionDir }

  self.codriver = self.notebook:getCodriverByName(self.missionSettings.notebook.codriver)
  if not self.codriver then
    self:__setNodeError('setup', 'couldnt load codriver: '..self.missionSettings.notebook.codriver)
  end

  self.fgPacenotes = self.notebook:getFlowgraphPacenotes(self.missionSettings, self.codriver)

  local damageThresh = 1000
  self.vehicleTracker = require('/lua/ge/extensions/gameplay/rally/vehicleTracker')(
    self.pinIn.vehId.value,
    damageThresh,
    self.pinIn.raceData.value
  )

  if self.pinIn.recce.value then
    self.closestPacenotes = self.notebook:findNClosestPacenotes(self.vehicleTracker:pos(), 2)
  else
    self.pacenoteState.nextId = 1
  end

  self.setupDone = true
end

function C:isRace()
  return not not self.pinIn.raceData.value
end

function C:intersectCorners(pacenote)
  if not pacenote then return false end
  -- local prevCorners = nil
  -- local currCorners = nil
  -- if self:isRace() then
    -- local state = self.pinIn.raceData.value.states[self.pinIn.vehId.value]
    -- prevCorners = state.previousCorners
    -- currCorners = state.currentCorners
  -- else
  local prevCorners = self.vehicleTracker:getPreviousCorners()
  local currCorners = self.vehicleTracker:getCurrentCorners()
  -- end
  if prevCorners and currCorners then
    return pacenote.pacenote:intersectCorners(prevCorners, currCorners)
  else
    return false
  end
end

function C:handleWork()
  if self.vehicleTracker then
    self.vehicleTracker:onUpdate(self.mgr.dtSim, self.pinIn.raceData.value)
  end

  if self.closestPacenotes then
    for _,pacenote in ipairs(self.closestPacenotes) do
      if self:intersectCorners(pacenote._cached_fgData) then
        self.audioManager:enqueuePacenote(pacenote._cached_fgData)
        -- its not the pacenote id, its the index in the ordered list of pacenotes.
        for i,pnData in ipairs(self.fgPacenotes) do
          if pnData.id == pacenote.id then
            self.pacenoteState.nextId = i+1
            break
          end
        end
        self.closestPacenotes = nil
        break
      end
    end
  else
    local nextId = self.pacenoteState.nextId
    local pacenote = self.fgPacenotes[nextId]
    if self:intersectCorners(pacenote) then
      self.audioManager:enqueuePacenote(pacenote)
      self.pacenoteState.nextId = self.pacenoteState.nextId + 1
    end
  end

  if self.vehicleTracker:didJustHaveDamage() then
    self.audioManager:resetAudioQueue()
    self.audioManager:playDamageSfx()
  else
    self.audioManager:playNextInQueue()
  end
end

function C:work(args)
  if self.pinIn.reset.value then
    self:resetState()
    self.pinOut.flow.value = false
  end

  if self.pinIn.flow.value then
    if not self.setupDone then
      self:initialSetup()
    else
      self:handleWork()
    end
  end

  if editor_rallyEditor then
    editor_rallyEditor.showWaypoints(not simTimeAuthority.getPause())
  end
end

return _flowgraph_createNode(C)
